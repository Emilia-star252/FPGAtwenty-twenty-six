#!/usr/bin/env python3
"""Train three classes with the existing Conv/Relu/one-pool + PS-max split."""
import argparse
import csv
import hashlib
import json
import os
from pathlib import Path
import random
import shutil
import time

os.environ.setdefault("CUBLAS_WORKSPACE_CONFIG", ":4096:8")
import numpy as np
import torch

from threeclass_data import fit_preprocessing, load_split

CLASSES = ["normal", "load_transient", "oscillation"]


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def save_json(path, obj):
    with Path(path).open("x", encoding="utf-8") as stream:
        json.dump(obj, stream, ensure_ascii=False, indent=2, allow_nan=False)
        stream.write("\n")


def build_feature_model():
    # NPU portion only. Global spatial max is explicit PS postprocessing.
    return torch.nn.Sequential(torch.nn.Conv2d(3, 16, 3, padding=1),
                               torch.nn.ReLU(), torch.nn.MaxPool2d(2, 2))


def class_logits(model, x):
    return model(x).amax(dim=(2, 3))[:, :3]


def metrics(target, prediction):
    target = np.asarray(target, dtype=np.int64)
    prediction = np.asarray(prediction, dtype=np.int64)
    if target.shape != prediction.shape or not len(target) or np.any((target < 0) | (target > 2)) or np.any((prediction < 0) | (prediction > 2)):
        raise ValueError("invalid three-class predictions")
    cm = np.bincount(target * 3 + prediction, minlength=9).reshape(3, 3)
    per_class = []
    for c, name in enumerate(CLASSES):
        tp, support, predicted = int(cm[c, c]), int(cm[c].sum()), int(cm[:, c].sum())
        recall = tp / support if support else None
        precision = tp / predicted if predicted else None
        f1 = 2 * tp / (support + predicted) if support else None
        per_class.append({"class_id": c, "name": name, "support": support,
                          "predicted_count": predicted, "precision": precision, "recall": recall, "f1": f1})
    present = [r for r in per_class if r["support"]]
    return {"accuracy": float(np.trace(cm) / cm.sum()),
            "confusion_matrix_true_rows_predicted_columns": cm.tolist(), "per_class": per_class,
            "macro_f1_supported_classes": float(np.mean([r["f1"] for r in present])),
            "supported_class_ids": [r["class_id"] for r in present],
            "missing_ground_truth_class_ids": [r["class_id"] for r in per_class if not r["support"]],
            "full_threeclass_evaluation_available": len(present) == 3,
            "normal_false_alarm_rate_any_abnormal": float((cm[0, 1]+cm[0, 2])/cm[0].sum()) if cm[0].sum() else None,
            "false_oscillation_predictions_on_nonoscillation": int(cm[:2, 2].sum())}


def evaluate(model, x, y, device):
    model.eval()
    with torch.no_grad():
        values = [class_logits(model, x[k:k+256].to(device)).cpu() for k in range(0, len(y), 256)]
    logits = torch.cat(values)
    result = metrics(y.numpy(), logits.argmax(1).numpy())
    result["cross_entropy_unweighted"] = float(torch.nn.functional.cross_entropy(logits, y))
    return result, logits.numpy()


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--dataset", type=Path, default=Path("fpga_prj/output/npu_dataset_20261027_threeclass_sim_v1"))
    p.add_argument("--output", type=Path, default=Path("fpga_prj/output/npu_train_20261027_threeclass_v1"))
    p.add_argument("--epochs", type=int, default=100)
    p.add_argument("--patience", type=int, default=25)
    p.add_argument("--seed", type=int, default=43)
    args = p.parse_args()
    if args.output.exists() or args.epochs < 1 or args.patience < 1:
        raise ValueError("use a new output and positive epochs/patience")
    if not torch.cuda.is_available():
        raise ValueError("CUDA unavailable")
    root, out = args.dataset.resolve(), args.output.resolve()
    checksums = json.loads((root / "checksums.json").read_text(encoding="utf-8"))
    for name, expected in checksums.items():
        if sha(root / name) != expected:
            raise ValueError("dataset integrity failure: " + name)
    audit = json.loads((root / "validation.json").read_text(encoding="utf-8"))
    manifest = json.loads((root / "manifest.json").read_text(encoding="utf-8"))
    if audit["status"] != "PASS" or not audit["run_sets_disjoint"]:
        raise ValueError("dataset split/integrity audit must pass")
    pre = fit_preprocessing(root)
    if pre != json.loads((root / "preprocessing_candidate.json").read_text(encoding="utf-8")):
        raise ValueError("train-only preprocessing changed")
    pre.update({"model_input_layout": "N,C,H,W", "npu_output_shape": [1, 16, 8, 8],
                "class_channels": [0, 1, 2], "unused_channels_fixed_zero": list(range(3, 16)),
                "ps_postprocess": "NCHW spatial maximum over 8x8, then argmax over channels 0/1/2",
                "packing": "channel-major; chronological sample t -> row=t//16,col=t%16"})
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
    tensors, metadata = {}, {}
    # Load test only AFTER model selection. It cannot influence optimization.
    for split in ("train", "validation"):
        x, y, meta = load_split(root, split, pre)
        tensors[split] = (torch.from_numpy(x), torch.from_numpy(y))
        metadata[split] = meta
    if not set(metadata["train"]["run_id"]).isdisjoint(set(metadata["validation"]["run_id"])):
        raise ValueError("run leakage")
    out.mkdir(parents=True)
    config = {"model": "square_psmax_threeclass_v1", "epochs_max": args.epochs, "patience": args.patience,
              "seed": args.seed, "batch_size": 64, "learning_rate": .001, "weight_decay": 1e-4,
              "optimizer": "Adam", "criterion": "3-class inverse-frequency weighted cross entropy",
              "device": "cuda", "gpu_name": torch.cuda.get_device_name(), "torch": str(torch.__version__),
              "selection": "validation F1 over supported classes 0/1, then validation unweighted CE; train oscillation recall must be >=0.99",
              "selection_limitation": "no held-out oscillation; training oscillation recall guard is not validation",
              "dataset": str(root), "data_sha256": {n: sha(root / n) for n in ("manifest.json", "checksums.json", "windows/train.npz", "windows/validation.npz", "windows/test.npz")},
              "class_order": CLASSES, "parameter_count": 448, "effective_trainable_parameter_count": 84,
              "npu_operations": ["Conv3x3_pad1", "Relu", "MaxPool2x2_stride2"],
              "physical_board_status": "NOT_RUN for this newly trained checkpoint",
              "test_scope": "reused exploratory physical bank, only classes 0/1; no test-based model selection"}
    save_json(out / "training_config.json", config)
    save_json(out / "preprocessing.json", pre)
    for name in (Path(__file__).name, "threeclass_data.py", "causal_features.py"):
        shutil.copyfile(Path(__file__).with_name(name), out / name)
    model = build_feature_model().to(device)
    with torch.no_grad():
        model[0].weight[3:].zero_()
        model[0].bias[3:].zero_()
    optimizer = torch.optim.Adam(model.parameters(), lr=.001, weight_decay=1e-4)
    criterion = torch.nn.CrossEntropyLoss(weight=torch.tensor(pre["class_weights"], device=device, dtype=torch.float32))
    loader = torch.utils.data.DataLoader(torch.utils.data.TensorDataset(*tensors["train"]), batch_size=64,
                                        shuffle=True, num_workers=0, pin_memory=True,
                                        generator=torch.Generator().manual_seed(args.seed))
    best_key, best_epoch, stale = None, 0, 0
    started = time.perf_counter()
    print("CUDA_THREECLASS_TRAIN", config["gpu_name"], "train", len(tensors["train"][1]), "class_counts", pre["training_class_counts"], flush=True)
    with (out / "history.csv").open("x", encoding="utf-8", newline="") as stream:
        writer = csv.writer(stream)
        writer.writerow(["epoch", "train_accuracy", "train_macro_f1", "train_oscillation_recall", "validation_accuracy", "validation_supported_macro_f1", "validation_ce", "validation_false_oscillation_count", "selected"])
        for epoch in range(1, args.epochs+1):
            model.train()
            for x, y in loader:
                x, y = x.to(device, non_blocking=True), y.to(device, non_blocking=True)
                optimizer.zero_grad(set_to_none=True)
                loss = criterion(class_logits(model, x), y)
                if not torch.isfinite(loss):
                    raise ValueError("non-finite training loss")
                loss.backward()
                model[0].weight.grad[3:].zero_()
                model[0].bias.grad[3:].zero_()
                optimizer.step()
            tr, _ = evaluate(model, *tensors["train"], device)
            val, _ = evaluate(model, *tensors["validation"], device)
            osc_recall = tr["per_class"][2]["recall"]
            # Eligibility is explicit: it prevents saving a model which ignores
            # the new class while doing well on a two-class-only validation bank.
            key = (int(osc_recall >= .99), val["macro_f1_supported_classes"], -val["cross_entropy_unweighted"])
            better = best_key is None or key[0] > best_key[0] or (key[0] == best_key[0] and (key[1] > best_key[1]+1e-6 or (abs(key[1]-best_key[1]) <= 1e-6 and key[2] > best_key[2]+1e-5)))
            if better:
                best_key, best_epoch, stale = key, epoch, 0
                torch.save({"model": config["model"], "state_dict": {k: v.detach().cpu() for k, v in model.state_dict().items()},
                            "epoch": epoch, "preprocessing": pre, "validation": val,
                            "training_oscillation_recall_at_selection": osc_recall,
                            "training_oscillation_guard_satisfied": bool(key[0]),
                            "class_order": CLASSES, "npu_output_shape": [1, 16, 8, 8]}, out / "best.pt")
            else:
                stale += 1
            writer.writerow([epoch, tr["accuracy"], tr["macro_f1_supported_classes"], osc_recall, val["accuracy"], val["macro_f1_supported_classes"], val["cross_entropy_unweighted"], val["false_oscillation_predictions_on_nonoscillation"], int(better)])
            stream.flush()
            if epoch == 1 or epoch % 5 == 0 or stale >= args.patience:
                print(f"epoch={epoch} train_acc={tr['accuracy']:.5f} train_osc_recall={osc_recall:.5f} val_acc={val['accuracy']:.5f} val_f1_classes01={val['macro_f1_supported_classes']:.5f} val_ce={val['cross_entropy_unweighted']:.5f} best_epoch={best_epoch}", flush=True)
            if stale >= args.patience and best_key[0]:
                break
    checkpoint = torch.load(out / "best.pt", map_location="cpu", weights_only=True)
    model.load_state_dict(checkpoint["state_dict"])
    assert torch.count_nonzero(model[0].weight[3:]) == 0 and torch.count_nonzero(model[0].bias[3:]) == 0
    x, y, metadata["test"] = load_split(root, "test", pre)
    tensors["test"] = torch.from_numpy(x), torch.from_numpy(y)
    for split in ("train", "validation"):
        assert set(metadata["test"]["run_id"]).isdisjoint(set(metadata[split]["run_id"]))
    result = {"best_epoch": best_epoch, "epochs_run": epoch, "elapsed_s": time.perf_counter()-started,
              "gpu_name": config["gpu_name"], "peak_cuda_allocated_bytes": torch.cuda.max_memory_allocated(),
              "class_order": CLASSES, "npu_output_shape": [1, 16, 8, 8], "class_channels": [0, 1, 2],
              "unused_channels_fixed_zero": True, "training_oscillation_guard_satisfied": checkpoint["training_oscillation_guard_satisfied"],
              "selection_limitation": config["selection_limitation"], "limitations": manifest["limitations"],
              "onnx_export": "NOT_RUN", "quantization": "NOT_RUN", "board_numeric_inference": "NOT_RUN"}
    for split in ("train", "validation", "test"):
        result[split], logits = evaluate(model, *tensors[split], device)
        with (out / f"{split}_predictions.csv").open("x", encoding="utf-8", newline="") as stream:
            writer = csv.writer(stream)
            writer.writerow(["run_id", "source_kind", "start_sample", "class_id", "predicted", "logit0", "logit1", "logit2"])
            for k, scores in enumerate(logits):
                meta = metadata[split]
                writer.writerow([str(meta["run_id"][k]), str(meta["source_kind"][k]), int(meta["start_sample"][k]), int(tensors[split][1][k]), int(scores.argmax()), *scores.tolist()])
        print("RESULT", split, json.dumps(result[split]), flush=True)
    save_json(out / "metrics.json", result)
    save_json(out / "artifact_checksums.json", {p.name: sha(p) for p in out.iterdir() if p.is_file()})
    print("THREECLASS_TRAIN_COMPLETE", "best_epoch", best_epoch, "elapsed_s", round(result["elapsed_s"], 2), flush=True)


if __name__ == "__main__":
    main()
