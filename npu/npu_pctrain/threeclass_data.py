"""Portable data-only loader. No training, quantization or inference side effects."""
import json
from pathlib import Path

import numpy as np
from causal_features import relative_values


def load_raw(root, split):
    if split not in ("train", "validation", "test"):
        raise ValueError("unknown split")
    root = Path(root)
    manifest = json.loads((root / "manifest.json").read_text(encoding="utf-8"))
    if manifest["schema"] != "DCDC_THREECLASS_MIXED_SOURCE_V1":
        raise ValueError("unsupported manifest")
    with np.load(root / "windows" / (split + ".npz"), allow_pickle=False) as z:
        part = {k: z[k] for k in z.files}
    x, y = part["X"], part["y"]
    if x.dtype != np.float32 or x.shape != (len(y), 256, 3) or not np.isfinite(x).all():
        raise ValueError("invalid physical windows")
    if y.dtype != np.int64 or not set(np.unique(y)).issubset({0, 1, 2}):
        raise ValueError("invalid targets")
    if part["feature_names"].tolist() != ["vout_v", "iout_a", "duty"] or int(part["sample_rate_hz"]) != 25000:
        raise ValueError("feature/rate mismatch")
    return part


def fit_preprocessing(root):
    part = load_raw(root, "train")
    relative = relative_values(part["X"], part["baseline"])
    counts = np.bincount(part["y"], minlength=3)
    if np.any(counts == 0):
        raise ValueError("combined train must contain all three classes")
    return {"mode": "causal-relative", "fit_split": "train", "feature_order": ["vout_v", "iout_a", "duty"],
            "class_order": ["normal", "load_transient", "oscillation"],
            "mean": relative.mean(axis=(0, 1), dtype=np.float64).tolist(),
            "std": np.maximum(relative.std(axis=(0, 1), dtype=np.float64), 1e-6).tolist(),
            "denominator_floors": [1.0, .05, .05], "context_seconds": 2.0,
            "training_class_counts": counts.tolist(), "class_weights": (len(part["y"]) / (3 * counts)).tolist(),
            "model_input_shape": [1, 3, 16, 16], "effective_class_channels": [0, 1, 2]}


def load_split(root, split, preprocessing):
    if preprocessing["fit_split"] != "train" or preprocessing["class_order"] != ["normal", "load_transient", "oscillation"]:
        raise ValueError("three-class train-fitted preprocessing is required")
    part = load_raw(root, split)
    x = relative_values(part["X"], part["baseline"], preprocessing["denominator_floors"])
    mean = np.asarray(preprocessing["mean"], np.float32)
    std = np.asarray(preprocessing["std"], np.float32)
    if mean.shape != (3,) or std.shape != (3,) or not np.isfinite(mean).all() or not np.isfinite(std).all() or np.any(std <= 0):
        raise ValueError("invalid normalization")
    x = np.ascontiguousarray(((x - mean) / std).transpose(0, 2, 1).reshape(-1, 3, 16, 16))
    if not np.isfinite(x).all():
        raise ValueError("non-finite normalized input")
    return x, part["y"], {k: part[k] for k in ("run_id", "start_sample", "end_sample", "source_kind")}
