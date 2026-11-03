"""Past-only physical context for cross-operating-point waveform inputs."""
import csv
import hashlib
import json

import numpy as np

DENOMINATOR_FLOORS = [1.0, 0.05, 0.05]  # V, A, duty fraction


def relative_values(x, baselines, floors=DENOMINATOR_FLOORS):
    baseline = np.asarray(baselines, dtype=np.float64)
    if baseline.shape != (len(x), 3) or not np.isfinite(baseline).all():
        raise ValueError("one finite three-channel history baseline is required per window")
    denominator = np.maximum(np.abs(baseline), np.asarray(floors))
    return ((x.astype(np.float64) - baseline[:, None, :]) / denominator[:, None, :]).astype(np.float32)


def prefix_baselines(signal, starts, history_samples):
    """Mean over [max(0,start-history),start); excludes the input window."""
    signal = np.asarray(signal, dtype=np.float64)
    starts = np.asarray(starts, dtype=np.int64)
    if history_samples < 1 or np.any(starts < 1) or np.any(starts > len(signal)):
        raise ValueError("nonempty past context required")
    prefix = np.vstack([np.zeros((1, 3)), np.cumsum(signal, axis=0, dtype=np.float64)])
    left = np.maximum(0, starts - history_samples)
    return (prefix[starts] - prefix[left]) / (starts - left)[:, None]


def baselines_for_part(part, dataset, manifest, seconds):
    checksums = json.loads((dataset / "checksums.json").read_text(encoding="utf-8"))
    result = np.empty((len(part["y"]), 3), dtype=np.float64)
    fs = int(part["sample_rate_hz"])
    history = round(seconds * fs)
    source_lengths = {r["run_id"]: r["samples"] for r in manifest["runs"]}
    for run in np.unique(part["run_id"]):
        name = f"csv/{run}.csv"
        path = dataset / name
        h = hashlib.sha256()
        with path.open("rb") as stream:
            for block in iter(lambda: stream.read(1048576), b""):
                h.update(block)
        if h.hexdigest() != checksums[name]:
            raise ValueError(f"context CSV changed since audit: {name}")
        with path.open(encoding="utf-8", newline="") as stream:
            if next(csv.reader(stream)) != ["run_id", "sample_index", "time_s", "vout_v", "iout_a", "duty", "class_id"]:
                raise ValueError("unexpected context CSV columns")
        # Only signal columns are read. Labels and event intervals are not inputs.
        signal = np.loadtxt(path, delimiter=",", skiprows=1, usecols=(3, 4, 5), dtype=np.float64)
        if signal.shape != (source_lengths[str(run)], 3) or not np.isfinite(signal).all():
            raise ValueError("invalid source history shape or values")
        mask = part["run_id"] == run
        result[mask] = prefix_baselines(signal, part["start_sample"][mask], history)
    return result
