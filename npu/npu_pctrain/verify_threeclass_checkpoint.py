#!/usr/bin/env python3
"""Reload the saved checkpoint on CPU and audit predictions and NPU/PS split."""
import argparse
import csv
import hashlib
import json
from pathlib import Path

import numpy as np
import torch

from threeclass_data import load_split
from train_threeclass_npu import build_feature_model, metrics


def verify(root):
    root = Path(root)
    torch.set_num_threads(4)
    config = json.loads((root / "training_config.json").read_text(encoding="utf-8"))
    result = json.loads((root / "metrics.json").read_text(encoding="utf-8"))
    pre = json.loads((root / "preprocessing.json").read_text(encoding="utf-8"))
    for name, want in config["data_sha256"].items():
        assert hashlib.sha256((Path(config["dataset"])/name).read_bytes()).hexdigest() == want
    checkpoint = torch.load(root / "best.pt", map_location="cpu", weights_only=True)
    assert checkpoint["class_order"] == ["normal", "load_transient", "oscillation"]
    assert checkpoint["epoch"] == result["best_epoch"]
    assert checkpoint["preprocessing"] == pre
    model = build_feature_model().eval()
    model.load_state_dict(checkpoint["state_dict"], strict=True)
    assert not torch.count_nonzero(model[0].weight[3:])
    assert not torch.count_nonzero(model[0].bias[3:])
    summary = {}
    for split in ("train", "validation", "test"):
        x, y, meta = load_split(config["dataset"], split, pre)
        with torch.no_grad():
            outputs = []
            for start in range(0, len(y), 256):
                features = model(torch.from_numpy(x[start:start+256]))
                assert tuple(features.shape[1:]) == (16, 8, 8)
                reduced = features.amax((2, 3))
                # Remaining three 2x2 max pools are exactly equivalent to PS
                # spatial max in float32, for these actual trained activations.
                four_pool = features
                for _ in range(3):
                    four_pool = torch.nn.functional.max_pool2d(four_pool, 2, 2)
                assert torch.equal(reduced, four_pool[:, :, 0, 0])
                outputs.append(reduced[:, :3].numpy())
        actual = np.concatenate(outputs)
        with (root / (split+"_predictions.csv")).open(encoding="utf-8", newline="") as stream:
            rows = list(csv.DictReader(stream))
        reference = np.array([[float(r["logit"+str(c)]) for c in range(3)] for r in rows])
        predicted = np.array([int(r["predicted"]) for r in rows])
        assert np.array_equal(actual.argmax(1), predicted)
        assert np.allclose(actual, reference, rtol=1e-5, atol=1e-5)
        assert np.array_equal(y, [int(r["class_id"]) for r in rows])
        for key in ("run_id", "source_kind", "start_sample"):
            assert [str(v) for v in meta[key]] == [r[key] for r in rows]
        report = metrics(y, actual.argmax(1))
        assert report["confusion_matrix_true_rows_predicted_columns"] == result[split]["confusion_matrix_true_rows_predicted_columns"]
        sorted_scores = np.sort(actual, axis=1)
        margins = sorted_scores[:, -1]-sorted_scores[:, -2]
        k = int(margins.argmin())
        summary[split] = {"windows_checked": len(y), "cpu_gpu_argmax_agrees": True,
                          "max_abs_cpu_gpu_logit_difference": float(abs(actual-reference).max()),
                          "min_argmax_margin_fp32": float(margins.min()),
                          "median_argmax_margin_fp32": float(np.median(margins)),
                          "minimum_margin_case": {"run_id": str(meta["run_id"][k]), "start_sample": int(meta["start_sample"][k]), "class_id": int(y[k])},
                          "accuracy": report["accuracy"],
                          "missing_ground_truth_class_ids": report["missing_ground_truth_class_ids"]}
    audit = {"status": "PASS", "checkpoint_sha256": hashlib.sha256((root / "best.pt").read_bytes()).hexdigest(),
             "cpu_reload_checked": True, "unused_output_channels_zero": True,
             "ps_global_max_equivalent_to_four_pool_reduction": True,
             "splits": summary, "quantization_status": "NOT_RUN",
             "quantization_followup": "smallest validation margin is close to zero; retest after quantization",
             "oscillation_scope": "training run only; independent validation and test unavailable"}
    destination = root / "checkpoint_validation.json"
    with destination.open("x", encoding="utf-8") as stream:
        json.dump(audit, stream, ensure_ascii=False, indent=2)
        stream.write("\n")
    print("THREECLASS_CHECKPOINT_RELOAD_PASS", json.dumps(audit), flush=True)


if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("training_output", type=Path)
    verify(p.parse_args().training_output)
