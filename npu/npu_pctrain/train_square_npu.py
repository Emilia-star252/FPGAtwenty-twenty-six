#!/usr/bin/env python3
"""Train the square Conv/Relu/4xMaxPool topology accepted by board probe 09."""
import argparse
import csv
import json
import os
from pathlib import Path
import random
import shutil
import time

os.environ.setdefault("CUBLAS_WORKSPACE_CONFIG", ":4096:8")
import numpy as np
import torch

from causal_features import baselines_for_part
from train_condition import (classification_metrics, file_sha, fit_preprocessing,
                             inputs_for_part, load_dataset, save_json)


def build_square_model():
    return torch.nn.Sequential(
        torch.nn.Conv2d(3, 16, 3, padding=1), torch.nn.ReLU(),
        torch.nn.MaxPool2d(2, 2), torch.nn.MaxPool2d(2, 2),
        torch.nn.MaxPool2d(2, 2), torch.nn.MaxPool2d(2, 2))


def square_inputs(part, pre, dataset, manifest):
    # Physical feature order is unchanged. Each channel's 256 chronological
    # samples are folded row-major into 16 rows of 16, not an acquired image.
    return inputs_for_part(part, pre, dataset, manifest).reshape(-1, 3, 16, 16)


def evaluate(model, x, y, device):
    model.eval()
    values = []
    with torch.no_grad():
        for begin in range(0, len(y), 128):
            values.append(model(x[begin:begin + 128].to(device))[:, :2, 0, 0].cpu().numpy())
    logits = np.concatenate(values)
    metrics = classification_metrics(y.numpy(), logits.argmax(1))
    metrics["cross_entropy_unweighted"] = float(torch.nn.functional.cross_entropy(torch.from_numpy(logits), y))
    return metrics, logits


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dataset", type=Path, default=Path("fpga_prj/output/npu_dataset_20261026"))
    parser.add_argument("--output", type=Path, default=Path("fpga_prj/output/npu_train_20261026_square_v1"))
    parser.add_argument("--epochs", type=int, default=100)
    parser.add_argument("--patience", type=int, default=20)
    parser.add_argument("--seed", type=int, default=43)
    args = parser.parse_args()
    if args.output.exists():
        raise ValueError("output exists; preserve previous training")
    if not torch.cuda.is_available():
        raise ValueError("CUDA is required for this run")
    parts, manifest = load_dataset(args.dataset)
    baseline = baselines_for_part(parts["train"], args.dataset, manifest, 2.0)
    parts["train"]["_baseline"] = baseline
    pre = fit_preprocessing(parts["train"]["X"], parts["train"]["y"], baseline, 2.0)
    pre.update({"model_input_layout": "N,C,H,W", "model_input_shape": [1, 3, 16, 16],
                "model_output_shape": [1, 16, 1, 1], "class_channels": [0, 1],
                "unused_output_channels": list(range(2, 16)),
                "packing": "per channel, sample t maps to row=t//16, col=t%16; same 768 floats as old N,3,1,256 input"})
    torch.set_num_threads(4)
    torch.manual_seed(args.seed)
    torch.cuda.manual_seed_all(args.seed)
    random.seed(args.seed)
    np.random.seed(args.seed)
    torch.use_deterministic_algorithms(True)
    torch.backends.cudnn.deterministic = True
    torch.backends.cudnn.benchmark = False
    torch.cuda.reset_peak_memory_stats()
    device = torch.device("cuda")
    args.output.mkdir(parents=True)
    save_json(args.output / "preprocessing.json", pre)
    config = {"model": "square_conv3x3_relu_maxpool4_16ch_v1", "seed": args.seed,
              "epochs": args.epochs, "patience": args.patience, "batch_size": 64,
              "learning_rate": 0.001, "class_loss": "only output channels 0 and 1; channels 2..15 fixed zero",
              "device": "cuda", "gpu_name": torch.cuda.get_device_name(), "torch": torch.__version__,
              "selection": "validation macro_f1, then unweighted cross entropy",
              "data_sha256": {f: file_sha(args.dataset / f) for f in ("manifest.json", "windows/train.npz", "windows/validation.npz", "windows/test.npz")},
              "test_scope": "exploratory reused held-out set; no training or model selection on test",
              "hardware_evidence": "user probe 09 assigns and loads this operator/shape pattern; trained numeric inference remains untested"}
    save_json(args.output / "training_config.json", config)
    for name in ("train_square_npu.py", "train_condition.py", "causal_features.py"):
        shutil.copyfile(Path(__file__).with_name(name), args.output / name)
    tensors = {}
    for split in ("train", "validation"):
        tensors[split] = (torch.from_numpy(square_inputs(parts[split], pre, args.dataset, manifest)), torch.from_numpy(parts[split]["y"]))
    model = build_square_model().to(device)
    with torch.no_grad():
        model[0].weight[2:].zero_()
        model[0].bias[2:].zero_()
    optimizer = torch.optim.Adam(model.parameters(), lr=.001, weight_decay=1e-4)
    criterion = torch.nn.CrossEntropyLoss(weight=torch.tensor(pre["class_weights"], dtype=torch.float32, device=device))
    loader = torch.utils.data.DataLoader(torch.utils.data.TensorDataset(*tensors["train"]), batch_size=64,
                                        shuffle=True, num_workers=0, pin_memory=True,
                                        generator=torch.Generator().manual_seed(args.seed))
    best_f1, best_loss, stale, best_epoch = -1., float("inf"), 0, 0
    started = time.perf_counter()
    print("CUDA_SQUARE_TRAIN", config["gpu_name"], "parameters", sum(p.numel() for p in model.parameters()), flush=True)
    with (args.output / "history.csv").open("x", newline="", encoding="utf-8") as stream:
        writer = csv.writer(stream)
        writer.writerow(["epoch", "validation_macro_f1", "validation_cross_entropy", "transient_recall", "normal_false_positive_rate", "selected"])
        for epoch in range(1, args.epochs + 1):
            model.train()
            for x, y in loader:
                x, y = x.to(device, non_blocking=True), y.to(device, non_blocking=True)
                optimizer.zero_grad(set_to_none=True)
                loss = criterion(model(x)[:, :2, 0, 0], y)
                loss.backward()
                # Keep unused hardware output lanes exactly zero in weights,
                # bias, gradients and optimizer state; no extra exported nodes.
                model[0].weight.grad[2:].zero_()
                model[0].bias.grad[2:].zero_()
                optimizer.step()
            metrics, _ = evaluate(model, *tensors["validation"], device)
            f1, val_loss = metrics["macro_f1"], metrics["cross_entropy_unweighted"]
            better = f1 > best_f1 + 1e-6 or (abs(f1 - best_f1) <= 1e-6 and val_loss < best_loss - 1e-5)
            if better:
                best_f1, best_loss, stale, best_epoch = f1, val_loss, 0, epoch
                torch.save({"model": config["model"], "state_dict": {k: v.detach().cpu() for k, v in model.state_dict().items()},
                            "epoch": epoch, "preprocessing": pre, "validation": metrics}, args.output / "best.pt")
            else:
                stale += 1
            writer.writerow([epoch, f1, val_loss, metrics["transient_recall"], metrics["normal_false_positive_rate"], int(better)])
            stream.flush()
            if epoch == 1 or epoch % 5 == 0 or stale >= args.patience:
                print(f"epoch={epoch} val_f1={f1:.5f} transient_recall={metrics['transient_recall']:.5f} normal_fpr={metrics['normal_false_positive_rate']:.5f} best_epoch={best_epoch}", flush=True)
            if stale >= args.patience:
                break
    checkpoint = torch.load(args.output / "best.pt", map_location="cpu", weights_only=True)
    model.load_state_dict(checkpoint["state_dict"])
    assert torch.count_nonzero(model[0].weight[2:]) == 0 and torch.count_nonzero(model[0].bias[2:]) == 0
    tensors["test"] = (torch.from_numpy(square_inputs(parts["test"], pre, args.dataset, manifest)), torch.from_numpy(parts["test"]["y"]))
    results = {"best_epoch": best_epoch, "epochs_run": epoch, "elapsed_s": time.perf_counter() - started,
               "gpu_name": config["gpu_name"], "peak_cuda_allocated_bytes": torch.cuda.max_memory_allocated(),
               "output_channels": 16, "class_channels": [0, 1], "unused_channels_fixed_zero": True,
               "limitations": manifest["limitations"], "board_numeric_inference": "NOT_RUN"}
    for split in ("train", "validation", "test"):
        results[split], logits = evaluate(model, *tensors[split], device)
        with (args.output / f"{split}_predictions.csv").open("x", newline="", encoding="utf-8") as stream:
            writer = csv.writer(stream)
            writer.writerow(["run_id", "start_sample", "class_id", "predicted", "logit0", "logit1"])
            for k, score in enumerate(logits):
                writer.writerow([str(parts[split]["run_id"][k]), int(parts[split]["start_sample"][k]), int(parts[split]["y"][k]), int(score.argmax()), *score.tolist()])
    save_json(args.output / "metrics.json", results)
    save_json(args.output / "artifact_checksums.json", {p.name: file_sha(p) for p in args.output.iterdir() if p.is_file()})
    print("SQUARE_TRAIN_COMPLETE", json.dumps(results, ensure_ascii=False), flush=True)


if __name__ == "__main__":
    main()
