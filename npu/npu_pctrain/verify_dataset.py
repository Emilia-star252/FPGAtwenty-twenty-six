#!/usr/bin/env python3
"""Audit CSV/source agreement, complete window contents, labels and grouping."""
import argparse
import csv
import hashlib
import json
from pathlib import Path
import sys

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "adc_fdma_capture"))
import decode_capture as decoder


def verify(root):
    manifest = json.loads((root / "manifest.json").read_text(encoding="utf-8"))
    source = Path(manifest["source_records"])
    references = {}
    payloads = set()
    total_rows = 0
    for run in manifest["runs"]:
        name = run["run_id"]
        binary = source / f"{name}.bin"
        info_path = source / f"{name}.info.bin"
        info = decoder.read_info(info_path)
        assert hashlib.sha256(info_path.read_bytes()).hexdigest() == run["info_sha256"]
        digest = decoder.verify_payload(binary, info)
        assert digest == run["payload_sha256"] and digest not in payloads
        payloads.add(digest)
        raw = binary.read_bytes()
        intervals = json.loads((root / "labels" / f"{name}.labels.json").read_text())
        assert intervals == run["label_intervals_end_exclusive"]
        labels = np.full(run["samples"], -1, dtype=np.int8)
        previous_end = 0
        for it in intervals:
            a, b, c = it["start"], it["end"], it["class_id"]
            assert previous_end <= a < b <= len(labels) and c in (0, 1)
            labels[a:b] = c
            previous_end = b
        signal = np.empty((len(labels), 3), dtype=np.float32)
        with (root / "csv" / f"{name}.csv").open(newline="", encoding="utf-8") as stream:
            reader = csv.DictReader(stream)
            count = 0
            for k, row in enumerate(reader):
                assert row["run_id"] == name and int(row["sample_index"]) == k
                assert abs(float(row["time_s"]) - k / info["sample_rate_hz"]) <= 5.1e-10
                assert int(row["class_id"]) == labels[k]
                actual = np.array([float(row[f]) for f in manifest["features"]])
                expected = np.array(decoder.decode_frame(raw[k * 16:(k + 1) * 16]))
                assert np.all(np.abs(actual - expected) <= 5.1e-10), (name, k)
                signal[k] = actual
                count += 1
            assert count == len(labels)
        references[name] = (signal, labels, run["split"])
        total_rows += count
        print(f"CSV_SOURCE_PASS {name} rows={count}", flush=True)
    seen_runs, window_count = set(), 0
    index_rows = []
    for split, summary in manifest["splits"].items():
        with np.load(root / "windows" / f"{split}.npz", allow_pickle=False) as archive:
            arrays = {k: archive[k] for k in archive.files}
        X, y, run_ids, starts, ends = [arrays[k] for k in ("X", "y", "run_id", "start_sample", "end_sample")]
        assert X.dtype == np.float32 and y.dtype == np.int64
        assert list(X.shape) == summary["shape"] and np.isfinite(X).all()
        assert arrays["feature_names"].tolist() == manifest["features"]
        assert set(np.unique(y)) == {0, 1}
        present_runs = set(run_ids.tolist())
        assert not seen_runs & present_runs
        assert present_runs == set(summary["runs"])
        seen_runs |= present_runs
        expected_pairs = set()
        for name in present_runs:
            signal, labels, assigned = references[name]
            assert assigned == split
            for start in range(0, len(labels) - manifest["window_samples"] + 1, manifest["stride_samples"]):
                target = labels[start:start + manifest["window_samples"]]
                if target[0] in (0, 1) and np.all(target == target[0]):
                    expected_pairs.add((name, start))
        assert len(y) == len(expected_pairs)
        actual_pairs = set()
        for row, (name, start, end, target) in enumerate(zip(run_ids, starts, ends, y)):
            signal, labels, assigned = references[str(name)]
            assert end - start == manifest["window_samples"]
            assert start % manifest["stride_samples"] == 0
            assert np.all(labels[start:end] == target)
            assert np.array_equal(X[row], signal[start:end]), (split, row)
            assert (str(name), int(start)) not in actual_pairs
            actual_pairs.add((str(name), int(start)))
            index_rows.append([split, str(row), str(name), str(start), str(end), str(target)])
        assert actual_pairs == expected_pairs
        counts = {str(c): int(np.count_nonzero(y == c)) for c in (0, 1)}
        assert counts == summary["class_counts"]
        window_count += len(y)
        print(f"NPZ_WINDOW_PASS {split} windows={len(y)} all_values_and_labels_checked", flush=True)
    assert seen_runs == set(references)
    with (root / "window_index.csv").open(newline="", encoding="utf-8") as stream:
        reader = csv.reader(stream)
        assert next(reader) == ["split", "row_in_npz", "run_id", "start_sample", "end_sample_exclusive", "class_id"]
        assert list(reader) == index_rows
    result = {"status": "PASS", "source_recordings": len(references), "csv_rows_checked_against_raw_frames": total_rows,
              "windows_all_values_checked": window_count, "run_sets_disjoint": True,
              "duplicate_payloads": False, "window_index_agrees": True,
              "label_validation_scope": "rule consistency only; not independent human ground truth"}
    files = [p for p in root.rglob("*") if p.is_file() and p.name not in ("validation.json", "checksums.json")]
    checksums = {p.relative_to(root).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
    (root / "checksums.json").write_text(json.dumps(checksums, indent=2) + "\n", encoding="utf-8")
    (root / "validation.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2), flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("dataset", type=Path)
    args = parser.parse_args()
    verify(args.dataset.resolve())
