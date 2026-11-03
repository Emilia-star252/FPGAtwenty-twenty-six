"""Verify complete simulation/old-bank windows, grouping and causal means."""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from causal_features import prefix_baselines
from threeclass_data import fit_preprocessing, load_split, load_raw


def verify(root):
    root = Path(root)
    m = json.loads((root / "manifest.json").read_text(encoding="utf-8"))
    source = m["source_simulation"]
    csv_path = root / source["preserved_path"]
    assert hashlib.sha256(csv_path.read_bytes()).hexdigest() == source["csv_sha256"]
    a = np.loadtxt(csv_path, delimiter=",", skiprows=1)
    with np.load(root / "source" / "simulation_signal.npz", allow_pickle=False) as z:
        t, signal, labels = z["time_s"], z["signal"], z["labels"]
    assert np.array_equal(a[:, 0], t) and np.array_equal(a[:, 1:], signal)
    assert np.isfinite(a).all() and np.allclose(np.diff(t), 1 / 25000, rtol=1e-7, atol=1e-12)
    assert np.all((signal[:, 2] >= 0) & (signal[:, 2] <= 1))
    expected_labels = np.where((t >= 3) & (t < 9.9), 2, -1)
    assert np.array_equal(labels, expected_labels)
    # Canonical context has source-equivalent physical values and relative time.
    canonical = np.loadtxt(root / "csv" / (source["run_id"] + ".csv"), delimiter=",", skiprows=1, usecols=(1, 2, 3, 4, 5, 6))
    assert np.array_equal(canonical[:, 0], np.arange(len(t)))
    assert np.allclose(canonical[:, 1], np.arange(len(t)) / 25000, atol=5e-10, rtol=0)
    assert np.array_equal(canonical[:, 2:5], signal) and np.array_equal(canonical[:, 5], labels)
    base = Path(m["source_base"])
    assert hashlib.sha256((base / "manifest.json").read_bytes()).hexdigest() == m["source_base_manifest_sha256"]
    seen = set()
    total = 0
    for split in ("train", "validation", "test"):
        with np.load(root / "windows" / (split + ".npz"), allow_pickle=False) as z:
            part = {k: z[k] for k in z.files}
        with np.load(base / "windows" / (split + ".npz"), allow_pickle=False) as z:
            old = {k: z[k] for k in z.files}
        n = len(old["y"])
        for key in ("X", "y", "run_id", "start_sample", "end_sample"):
            assert np.array_equal(part[key][:n], old[key]), (split, key)
        assert np.all(part["source_kind"][:n] == "physical_board")
        assert np.isfinite(part["baseline"]).all() and part["baseline"].shape == (len(part["y"]), 3)
        assert np.isfinite(part["X"]).all() and part["X"].dtype == np.float32
        runs = set(part["run_id"].tolist())
        assert not seen & runs
        seen |= runs
        assert sorted(runs) == m["splits"][split]["runs"]
        assert {str(c): int((part["y"] == c).sum()) for c in range(3)} == m["splits"][split]["class_counts"]
        sim = part["source_kind"] == "simulation"
        if split == "train":
            grid = np.arange(0, len(t) - 255, 128)
            starts = grid[np.all(labels[grid[:, None] + np.arange(256)] == 2, axis=1)]
            assert np.array_equal(part["start_sample"][sim], starts)
            assert np.all(part["run_id"][sim] == source["run_id"]) and np.all(part["y"][sim] == 2)
            assert np.array_equal(part["X"][sim], signal[starts[:, None]+np.arange(256)].astype(np.float32))
            assert np.array_equal(part["end_sample"][sim], starts + 256)
            # Independent direct slices check each stored past mean.
            direct = np.array([signal[max(0, int(s)-50000):s].mean(0) for s in starts])
            assert np.allclose(part["baseline"][sim], direct, rtol=1e-10, atol=1e-10)
            assert np.array_equal(part["baseline"][sim], prefix_baselines(signal, starts, 50000))
            with np.load(root / "windows" / "oscillation_train.npz", allow_pickle=False) as z:
                for key in ("X", "y", "baseline", "run_id", "start_sample", "end_sample", "source_kind"):
                    assert np.array_equal(part[key][sim], z[key])
            sim_n = int(sim.sum())
        else:
            assert not sim.any() and len(part["y"]) == n and not (part["y"] == 2).any()
        assert list(part["X"].shape) == m["splits"][split]["shape"]
        total += len(part["y"])
    pre = json.loads((root / "preprocessing_candidate.json").read_text(encoding="utf-8"))
    assert pre == fit_preprocessing(root)
    packed_shapes = {}
    for split in ("train", "validation", "test"):
        packed, y, metadata = load_split(root, split, pre)
        raw = load_raw(root, split)
        assert packed.dtype == np.float32 and packed.flags["C_CONTIGUOUS"]
        assert packed.shape == (len(y), 3, 16, 16) and np.isfinite(packed).all()
        # Independently evaluate physical units -> past-relative -> normalized
        # -> 16x16 coordinates, at each collection boundary and all channels.
        for k in sorted({0, len(y)-1, min(9648, len(y)-1)}):
            for c, j in ((0, 0), (1, 129), (2, 255)):
                value = float(raw["X"][k, j, c])
                baseline = float(raw["baseline"][k, c])
                relative = np.float32((value-baseline) / max(abs(baseline), [1, .05, .05][c]))
                expected = (relative-np.float32(pre["mean"][c])) / np.float32(pre["std"][c])
                assert packed[k, c, j//16, j%16] == expected
        packed_shapes[split] = list(packed.shape)
    # A future-only perturbation must not alter an earlier causal baseline.
    s = 75008
    changed = signal.copy()
    changed[s:] += 100
    assert np.array_equal(prefix_baselines(signal, [s], 50000), prefix_baselines(changed, [s], 50000))
    result = {"status": "PASS", "source_simulation_rows_checked": len(t), "simulation_windows_checked": sim_n,
              "old_windows_unchanged_checked": total-sim_n, "merged_windows_checked": total,
              "run_sets_disjoint": True, "simulation_assigned_train_only": True,
              "all_simulation_window_values_labels_and_past_baselines_checked": True,
              "npu_input_packing_checked": packed_shapes, "preprocessing_fitted_on_train_only": True,
              "future_perturbation_causal_baseline_check": "PASS",
              "third_class_validation_available": False, "third_class_test_available": False,
              "scope": "data integrity and split audit only; no training or physical inference validation"}
    (root / "validation.json").write_text(json.dumps(result, indent=2)+"\n", encoding="utf-8")
    print("OSCILLATION_DATA_AUDIT_PASS", json.dumps(result), flush=True)
    return result


if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("dataset", type=Path)
    verify(p.parse_args().dataset)
