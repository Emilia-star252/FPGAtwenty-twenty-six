#!/usr/bin/env python3
"""Train a small DCDC binary CNN on prepared, run-disjoint P481 windows.

Run --check-data without PyTorch. Training needs numpy and torch. No ONNX
export, quantization, NPU inference, or board access is performed here.
"""
import argparse
import csv
import hashlib
import json
import os
from pathlib import Path
import random
import shutil
import sys
import time

import numpy as np

from causal_features import DENOMINATOR_FLOORS, baselines_for_part, relative_values

FEATURES = ["vout_v", "iout_a", "duty"]
CLASSES = ["normal", "load_transient"]


def file_sha(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1048576), b""):
            digest.update(block)
    return digest.hexdigest()


def save_json(path, data):
    with path.open("x", encoding="utf-8") as stream:
        json.dump(data, stream, ensure_ascii=False, indent=2, allow_nan=False)
        stream.write("\n")


def load_dataset(root):
    manifest = json.loads((root / "manifest.json").read_text(encoding="utf-8"))
    validation = json.loads((root / "validation.json").read_text(encoding="utf-8"))
    checksums = json.loads((root / "checksums.json").read_text(encoding="utf-8"))
    if validation["status"] != "PASS" or not validation["run_sets_disjoint"]:
        raise ValueError("dataset validation is not PASS with disjoint runs")
    if manifest["features"] != FEATURES or manifest["tensor_layout"] != "N,T,C":
        raise ValueError("unsupported feature order or dataset tensor layout")
    if manifest["window_samples"] != 256 or manifest["normalization"].split(";")[0] != "none":
        raise ValueError("this baseline expects 256 raw samples per window")
    if manifest["classes"] != {"0": "normal", "1": "load_transient"}:
        raise ValueError("only the current binary classification is supported")
    for name in ("manifest.json", "config.json", "windows/train.npz", "windows/validation.npz", "windows/test.npz"):
        if file_sha(root / name) != checksums[name]:
            raise ValueError(f"dataset changed since audit: {name}")
    parts, assigned = {}, set()
    for split in ("train", "validation", "test"):
        with np.load(root / "windows" / f"{split}.npz", allow_pickle=False) as archive:
            part = {key: archive[key] for key in ("X", "y", "run_id", "start_sample", "end_sample", "feature_names", "sample_rate_hz")}
        x, y = part["X"], part["y"]
        if x.dtype != np.float32 or x.shape != (len(y), 256, 3) or not np.isfinite(x).all():
            raise ValueError(f"invalid input shape/dtype/values in {split}")
        if y.dtype != np.int64 or set(np.unique(y)) != {0, 1}:
            raise ValueError(f"both binary labels are required in {split}")
        runs = set(part["run_id"].tolist())
        if assigned & runs or runs != set(manifest["splits"][split]["runs"]):
            raise ValueError("run leakage or mismatched grouping")
        assigned |= runs
        if part["feature_names"].tolist() != FEATURES or int(part["sample_rate_hz"]) != 25000:
            raise ValueError("unexpected channels or sample rate")
        if any(len(part[key]) != len(y) for key in ("run_id", "start_sample", "end_sample")):
            raise ValueError("window metadata length mismatch")
        parts[split] = part
    source_hashes = [row["payload_sha256"] for row in manifest["runs"]]
    if len(set(source_hashes)) != len(source_hashes):
        raise ValueError("duplicate source payload")
    return parts, manifest


def fit_preprocessing(train_x, train_y, baselines=None, context_seconds=2.0):
    transform = {"mode": "global", "input_units": ["V", "A", "duty_fraction"]}
    if baselines is not None:
        train_x = relative_values(train_x, baselines)
        transform = {"mode": "causal-relative", "context_seconds": context_seconds,
                     "history_interval": "[max(0,window_start-history_samples),window_start)",
                     "history_statistic": "arithmetic mean, same run only, no labels or future samples",
                     "denominator_floors": DENOMINATOR_FLOORS,
                     "formula": "(physical_value - past_mean) / max(abs(past_mean), floor[channel])",
                     "input_units": ["V", "A", "duty_fraction"], "output_units": "dimensionless"}
    mean = train_x.mean(axis=(0, 1), dtype=np.float64)
    std = train_x.std(axis=(0, 1), dtype=np.float64)
    std = np.maximum(std, 1e-6)
    counts = np.bincount(train_y, minlength=2)
    if np.any(counts == 0):
        raise ValueError("training set lacks a class")
    weights = len(train_y) / (2.0 * counts)
    return {"feature_order": FEATURES, "mean": mean.tolist(), "std": std.tolist(),
            "feature_transform": transform,
            "formula": "(transformed_value - mean[channel]) / std[channel]",
            "fit_split": "train", "fit_axes": "all training windows and time samples; overlapping samples included",
            "model_input_layout": "N,C,H,T", "model_input_shape": [1, 3, 1, 256],
            "training_class_counts": counts.tolist(), "class_weights": weights.tolist(),
            "class_weight_formula": "N_train / (2 * class_count)", "class_order": CLASSES}


def preprocess(x, preprocessing, baselines=None):
    if preprocessing.get("feature_transform", {}).get("mode") == "causal-relative":
        if baselines is None:
            raise ValueError("causal-relative model requires past-only history baselines")
        x = relative_values(x, baselines, preprocessing["feature_transform"]["denominator_floors"])
    mean = np.array(preprocessing["mean"], dtype=np.float32)
    std = np.array(preprocessing["std"], dtype=np.float32)
    normalized = (x - mean) / std
    return np.ascontiguousarray(normalized.transpose(0, 2, 1)[:, :, None, :])


def inputs_for_part(part, preprocessing, dataset, manifest):
    transform = preprocessing.get("feature_transform", {})
    baseline = None
    if transform.get("mode") == "causal-relative":
        if "_baseline" not in part:
            part["_baseline"] = baselines_for_part(part, dataset, manifest, transform["context_seconds"])
        baseline = part["_baseline"]
    return preprocess(part["X"], preprocessing, baseline)


def classification_metrics(target, prediction):
    target, prediction = np.asarray(target), np.asarray(prediction)
    confusion = np.bincount(target * 2 + prediction, minlength=4).reshape(2, 2)
    per_class = []
    for c, name in enumerate(CLASSES):
        tp = int(confusion[c, c])
        support = int(confusion[c, :].sum())
        predicted = int(confusion[:, c].sum())
        precision = tp / predicted if predicted else 0.0
        recall = tp / support if support else 0.0
        f1 = 2 * precision * recall / (precision + recall) if precision + recall else 0.0
        per_class.append({"class_id": c, "name": name, "precision": precision,
                          "recall": recall, "f1": f1, "support": support})
    return {"confusion_matrix_true_rows_predicted_columns": confusion.tolist(),
            "accuracy": float(np.trace(confusion) / confusion.sum()),
            "macro_f1": float(np.mean([c["f1"] for c in per_class])),
            "balanced_accuracy": float(np.mean([c["recall"] for c in per_class])),
            "transient_recall": per_class[1]["recall"],
            "normal_false_positive_rate": float(confusion[0, 1] / confusion[0].sum()),
            "per_class": per_class}


def build_model(torch):
    nn = torch.nn
    # Conventional 2D Conv/Relu/AvgPool/Linear nodes; backend support still
    # requires later exported-graph and strict Alnpu verification.
    return nn.Sequential(
        nn.Conv2d(3, 16, kernel_size=(1, 5), padding=(0, 2)),
        nn.ReLU(), nn.AvgPool2d(kernel_size=(1, 4)),
        nn.Conv2d(16, 32, kernel_size=(1, 5), padding=(0, 2)),
        nn.ReLU(), nn.AvgPool2d(kernel_size=(1, 64)),
        nn.Flatten(), nn.Linear(32, 2))


def evaluate(torch, model, inputs, targets, device, batch_size):
    model.eval()
    logits_list, total_loss = [], 0.0
    with torch.no_grad():
        for begin in range(0, len(targets), batch_size):
            x = inputs[begin:begin + batch_size].to(device)
            y = targets[begin:begin + batch_size].to(device)
            logits = model(x)
            total_loss += float(torch.nn.functional.cross_entropy(logits, y, reduction="sum").item())
            logits_list.append(logits.cpu().numpy())
    logits = np.concatenate(logits_list)
    result = classification_metrics(targets.numpy(), logits.argmax(axis=1))
    result["cross_entropy_unweighted"] = total_loss / len(targets)
    return result, logits


def train(args, parts, manifest, preprocessing):
    if args.device == "cuda":
        # Must precede CUDA/cuBLAS initialization for deterministic training.
        os.environ.setdefault("CUBLAS_WORKSPACE_CONFIG", ":4096:8")
    try:
        import torch
    except ImportError as exc:
        raise SystemExit("PyTorch is missing. Follow TRAINING.md to create a venv and install CPU torch.") from exc
    if args.output.exists():
        raise ValueError("output directory already exists; use a new run directory")
    if args.device == "cuda" and not torch.cuda.is_available():
        raise ValueError("CUDA requested but this torch runtime cannot access CUDA")
    torch.set_num_threads(args.threads)
    torch.manual_seed(args.seed)
    np.random.seed(args.seed)
    random.seed(args.seed)
    if torch.cuda.is_available():
        torch.cuda.manual_seed_all(args.seed)
    torch.use_deterministic_algorithms(True)
    device = torch.device(args.device)
    gpu_name = None
    if device.type == "cuda":
        torch.backends.cudnn.benchmark = False
        torch.backends.cudnn.deterministic = True
        gpu_name = torch.cuda.get_device_name(device)
        torch.cuda.reset_peak_memory_stats(device)
        print(f"CUDA_READY gpu={gpu_name} runtime={torch.version.cuda}", flush=True)
    args.output.mkdir(parents=True)
    dataset_hashes = {name: file_sha(args.dataset / name) for name in
                      ("manifest.json", "validation.json", "windows/train.npz", "windows/validation.npz", "windows/test.npz")}
    save_json(args.output / "preprocessing.json", preprocessing)
    config = {key: str(value) if isinstance(value, Path) else value for key, value in vars(args).items()}
    config.update({"model": "tiny_conv2d_binary_v1", "torch_version": torch.__version__,
                   "cuda_runtime": torch.version.cuda, "gpu_name": gpu_name,
                   "cublas_workspace_config": os.environ.get("CUBLAS_WORKSPACE_CONFIG") if gpu_name else None,
                   "numpy_version": np.__version__, "python_version": sys.version,
                   "source_dataset_sha256": dataset_hashes,
                   "model_selection": "validation macro_f1, then lower validation unweighted cross entropy",
                   "decision": "argmax of two raw logits; no threshold tuning",
                   "test_use": "skipped for development" if args.skip_test else "once, after best checkpoint selected and loaded",
                   "annotation_status": manifest["annotation_status"]})
    save_json(args.output / "training_config.json", config)
    shutil.copyfile(Path(__file__), args.output / "train_condition.py")
    shutil.copyfile(Path(__file__).with_name("causal_features.py"), args.output / "causal_features.py")
    model = build_model(torch).to(device)
    print(f"MODEL parameters={sum(p.numel() for p in model.parameters())} device={device}", flush=True)
    # Test windows remain untouched by normalization/inference until selection ends.
    tensors = {}
    for split in ("train", "validation"):
        tensors[split] = (torch.from_numpy(inputs_for_part(parts[split], preprocessing, args.dataset, manifest)),
                          torch.from_numpy(parts[split]["y"]))
    generator = torch.Generator().manual_seed(args.seed)
    loader = torch.utils.data.DataLoader(torch.utils.data.TensorDataset(*tensors["train"]),
                                        batch_size=args.batch_size, shuffle=True, num_workers=0,
                                        generator=generator, pin_memory=device.type == "cuda")
    criterion = torch.nn.CrossEntropyLoss(weight=torch.tensor(preprocessing["class_weights"], dtype=torch.float32, device=device))
    optimizer = torch.optim.Adam(model.parameters(), lr=args.learning_rate, weight_decay=1e-4)
    best_score, best_loss, best_epoch, stale = -1.0, float("inf"), 0, 0
    started = time.perf_counter()
    history = []
    columns = ["epoch", "train_weighted_cross_entropy", "validation_cross_entropy", "validation_macro_f1",
               "validation_transient_recall", "validation_normal_false_positive_rate", "selected"]
    with (args.output / "history.csv").open("x", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=columns)
        writer.writeheader()
        for epoch in range(1, args.epochs + 1):
            model.train()
            loss_total, weight_total = 0.0, 0.0
            for x, y in loader:
                x = x.to(device, non_blocking=device.type == "cuda")
                y = y.to(device, non_blocking=device.type == "cuda")
                optimizer.zero_grad(set_to_none=True)
                loss = criterion(model(x), y)
                loss.backward()
                optimizer.step()
                batch_weight = float(criterion.weight[y].sum().item())
                loss_total += float(loss.item()) * batch_weight
                weight_total += batch_weight
            metrics, _ = evaluate(torch, model, *tensors["validation"], device, args.batch_size)
            score, val_loss = metrics["macro_f1"], metrics["cross_entropy_unweighted"]
            better = score > best_score + 1e-6 or (abs(score - best_score) <= 1e-6 and val_loss < best_loss - 1e-5)
            if better:
                best_score, best_loss, best_epoch, stale = score, val_loss, epoch, 0
                torch.save({"state_dict": {key: val.detach().cpu() for key, val in model.state_dict().items()},
                            "model": "tiny_conv2d_binary_v1", "epoch": epoch, "preprocessing": preprocessing,
                            "class_order": CLASSES, "validation_metrics": metrics}, args.output / "best.pt")
            else:
                stale += 1
            row = {"epoch": epoch, "train_weighted_cross_entropy": loss_total / weight_total,
                   "validation_cross_entropy": val_loss, "validation_macro_f1": score,
                   "validation_transient_recall": metrics["transient_recall"],
                   "validation_normal_false_positive_rate": metrics["normal_false_positive_rate"], "selected": int(better)}
            writer.writerow(row)
            stream.flush()
            history.append(row)
            print(f"epoch={epoch:03d} val_macro_f1={score:.4f} transient_recall={metrics['transient_recall']:.4f} normal_false_positive_rate={metrics['normal_false_positive_rate']:.4f} best={int(better)}", flush=True)
            if stale >= args.patience:
                print(f"EARLY_STOP epoch={epoch} best_epoch={best_epoch}", flush=True)
                break
    checkpoint = torch.load(args.output / "best.pt", map_location="cpu", weights_only=True)
    model.load_state_dict(checkpoint["state_dict"])
    model.to(device)
    results = {}
    evaluated_splits = ["train", "validation"]
    if not args.skip_test:
        tensors["test"] = (torch.from_numpy(inputs_for_part(parts["test"], preprocessing, args.dataset, manifest)), torch.from_numpy(parts["test"]["y"]))
        evaluated_splits.append("test")
    for split in evaluated_splits:
        metrics, logits = evaluate(torch, model, *tensors[split], device, args.batch_size)
        metrics["always_normal_baseline"] = classification_metrics(parts[split]["y"], np.zeros(len(parts[split]["y"]), dtype=np.int64))
        results[split] = metrics
        with (args.output / f"{split}_predictions.csv").open("x", encoding="utf-8", newline="") as stream:
            writer = csv.writer(stream)
            writer.writerow(["run_id", "start_sample", "end_sample_exclusive", "true_class", "predicted_class", "logit_normal", "logit_load_transient"])
            for k, values in enumerate(logits):
                part = parts[split]
                writer.writerow([str(part["run_id"][k]), int(part["start_sample"][k]), int(part["end_sample"][k]),
                                 int(part["y"][k]), int(values.argmax()), float(values[0]), float(values[1])])
    results.update({"best_epoch": best_epoch, "epochs_run": len(history), "elapsed_s": time.perf_counter() - started,
                    "training_device": str(device), "gpu_name": gpu_name,
                    "peak_cuda_allocated_bytes": torch.cuda.max_memory_allocated(device) if gpu_name else 0,
                    "parameter_count": sum(p.numel() for p in model.parameters()),
                    "evidence_level": "PC float training and held-out window evaluation only; no NPU execution",
                    "test_evaluated": not args.skip_test, "limitations": manifest["limitations"]})
    save_json(args.output / "metrics.json", results)
    save_json(args.output / "artifact_checksums.json", {p.name: file_sha(p) for p in args.output.iterdir() if p.is_file()})
    print("TRAIN_COMPLETE", json.dumps({"best_epoch": best_epoch, "validation": results["validation"], "test_evaluated": not args.skip_test}, ensure_ascii=False), flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dataset", type=Path, default=Path("fpga_prj/output/npu_dataset_20261026"))
    parser.add_argument("--output", type=Path, default=None)
    parser.add_argument("--check-data", action="store_true")
    parser.add_argument("--preprocessing", choices=["global", "causal-relative"], default="global")
    parser.add_argument("--context-seconds", type=float, default=2.0)
    parser.add_argument("--skip-test", action="store_true", help="develop using train/validation only")
    parser.add_argument("--epochs", type=int, default=50)
    parser.add_argument("--batch-size", type=int, default=64)
    parser.add_argument("--learning-rate", type=float, default=1e-3)
    parser.add_argument("--patience", type=int, default=10)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--threads", type=int, default=4)
    parser.add_argument("--device", choices=["cpu", "cuda"], default="cuda")
    args = parser.parse_args()
    if min(args.epochs, args.batch_size, args.patience, args.threads) <= 0 or args.learning_rate <= 0:
        parser.error("training counts and learning rate must be positive")
    if not np.isfinite(args.context_seconds) or args.context_seconds <= 0:
        parser.error("context duration must be finite and positive")
    if args.output is None:
        suffix = "gpu_v1" if args.device == "cuda" else "v1"
        if args.preprocessing == "causal-relative":
            suffix += "_context"
        args.output = Path(f"fpga_prj/output/npu_train_20261026_{suffix}")
    args.dataset, args.output = args.dataset.resolve(), args.output.resolve()
    parts, manifest = load_dataset(args.dataset)
    baseline = None
    if args.preprocessing == "causal-relative":
        baseline = baselines_for_part(parts["train"], args.dataset, manifest, args.context_seconds)
        parts["train"]["_baseline"] = baseline
    preprocessing = fit_preprocessing(parts["train"]["X"], parts["train"]["y"], baseline, args.context_seconds)
    summary = {split: {"shape": list(part["X"].shape), "classes": np.bincount(part["y"]).tolist()} for split, part in parts.items()}
    print("DATA_CHECK_PASS", json.dumps(summary), flush=True)
    print("TRAIN_ONLY_PREPROCESSING", json.dumps(preprocessing), flush=True)
    if not args.check_data:
        train(args, parts, manifest, preprocessing)


if __name__ == "__main__":
    main()
