#!/usr/bin/env python3
"""Preserve a new simulation run as held-out data; evaluate frozen FP32 weights.

No fitting, training, quantization or modification to the existing dataset.
"""
import argparse
import csv
import hashlib
import json
from pathlib import Path
import shutil

import numpy as np
import torch

from causal_features import prefix_baselines, relative_values
from train_threeclass_npu import build_feature_model


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def save_json(path, value):
    with Path(path).open("x", encoding="utf-8") as stream:
        json.dump(value, stream, ensure_ascii=False, indent=2, allow_nan=False)
        stream.write("\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--csv", type=Path, required=True)
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    source, model_root, out = args.csv.resolve(), args.model.resolve(), args.output.resolve()
    if out.exists():
        raise ValueError("use a new output directory")
    source_hash = sha(source)
    model_hash = sha(model_root / "best.pt")
    model_audit = json.loads((model_root / "checkpoint_validation.json").read_text(encoding="utf-8"))
    if model_audit["status"] != "PASS" or model_audit["checkpoint_sha256"] != model_hash:
        raise ValueError("checkpoint does not match prior reload audit")
    config = json.loads((model_root / "training_config.json").read_text(encoding="utf-8"))
    dataset = Path(config["dataset"])
    manifest = json.loads((dataset / "manifest.json").read_text(encoding="utf-8"))
    for name, expected in config["data_sha256"].items():
        if sha(dataset / name) != expected:
            raise ValueError("training dataset identity changed: " + name)
    if source_hash == manifest["source_simulation"]["csv_sha256"]:
        raise ValueError("new source duplicates training CSV")
    with source.open(encoding="utf-8-sig", newline="") as stream:
        if next(csv.reader(stream)) != ["Time", "Vm1:Measured voltage", "Am1:Measured current", "C-Script"]:
            raise ValueError("unexpected signal columns")
    a = np.loadtxt(source, delimiter=",", skiprows=1, dtype=np.float64)
    if a.ndim != 2 or a.shape[1] != 4 or not np.isfinite(a).all():
        raise ValueError("non-finite/malformed CSV")
    t, signal = a[:, 0], a[:, 1:]
    if not np.allclose(np.diff(t), 1/25000, rtol=1e-7, atol=1e-12):
        raise ValueError("expected uniform 25kHz sampling")
    if np.any((signal[:, 2] < 0) | (signal[:, 2] > 1)):
        raise ValueError("invalid duty fraction")
    run = source.stem
    for split in ("train", "validation", "test"):
        if run in manifest["splits"][split]["runs"]:
            raise ValueError("source run already assigned in existing dataset")
    labels = np.full(len(t), -1, dtype=np.int8)
    labels[(t >= 3) & (t < 9.9)] = 2
    grid = np.arange(0, len(t)-255, 128, dtype=np.int64)
    starts = grid[np.all(labels[grid[:, None]+np.arange(256)] == 2, axis=1)]
    if not len(starts):
        raise ValueError("no complete labeled windows")
    x = signal[starts[:, None]+np.arange(256)].astype(np.float32)
    baseline = prefix_baselines(signal, starts, 50000)
    pre = json.loads((model_root / "preprocessing.json").read_text(encoding="utf-8"))
    pre_hash = sha(model_root / "preprocessing.json")
    ck = torch.load(model_root / "best.pt", map_location="cpu", weights_only=True)
    if ck["preprocessing"] != pre or ck["class_order"] != ["normal", "load_transient", "oscillation"]:
        raise ValueError("checkpoint class order or preprocessing mismatch")
    relative = relative_values(x, baseline, pre["denominator_floors"])
    packed = np.ascontiguousarray(((relative-np.asarray(pre["mean"], np.float32)) /
                                  np.asarray(pre["std"], np.float32)).transpose(0, 2, 1).reshape(-1, 3, 16, 16))
    torch.set_num_threads(4)
    model = build_feature_model().eval()
    model.load_state_dict(ck["state_dict"], strict=True)
    with torch.no_grad():
        logits = np.concatenate([model(torch.from_numpy(packed[k:k+256])).amax((2, 3))[:, :3].numpy()
                                 for k in range(0, len(x), 256)])
    predicted = logits.argmax(1)
    y = np.full(len(x), 2, dtype=np.int64)
    margin = logits[:, 2]-logits[:, :2].max(1)
    counts = np.bincount(predicted, minlength=3)
    out.mkdir(parents=True)
    for sub in ("source", "windows", "tools"):
        (out / sub).mkdir()
    shutil.copyfile(source, out / "source" / source.name)
    shutil.copyfile(model_root / "preprocessing.json", out / "preprocessing_frozen.json")
    np.savez_compressed(out / "source" / "signal.npz", time_s=t, signal=signal, labels=labels)
    np.savez_compressed(out / "windows" / "oscillation_test.npz", X=x, y=y, baseline=baseline,
                        run_id=np.full(len(x), run), start_sample=starts, end_sample=starts+256,
                        feature_names=np.array(["vout_v", "iout_a", "duty"]), sample_rate_hz=np.array(25000),
                        source_kind=np.full(len(x), "simulation"))
    with (out / "predictions.csv").open("x", encoding="utf-8", newline="") as stream:
        writer = csv.writer(stream)
        writer.writerow(["run_id", "start_sample", "start_time_s", "end_sample_exclusive", "class_id", "predicted", "logit0", "logit1", "logit2", "class2_margin"])
        for k, start in enumerate(starts):
            writer.writerow([run, int(start), float(t[start]), int(start+256), 2, int(predicted[k]), *logits[k].tolist(), float(margin[k])])
    active = signal[(t >= 3) & (t < 9.9)]
    v = active[:, 0]
    frequency = np.fft.rfftfreq(len(v), 1/25000)
    spectrum = abs(np.fft.rfft((v-v.mean())*np.hanning(len(v))))
    spectrum[frequency < 1] = 0
    evidence = {"sample_count": len(t), "sample_rate_hz": 25000,
                "time_range_s": [float(t[0]), float(t[-1])],
                "annotation_policy": "same conservative [3.0,9.9)s sustained-oscillation interior as training simulation",
                "outside_interval": "unlabeled; no startup or event-onset accuracy claimed",
                "label_basis": "user identifies a new oscillation simulation; sustained waveform agrees",
                "duty_semantics": "same export schema as previous user-confirmed applied-duty column; numerical range checked",
                "pi_parameter_switch_for_this_run": "not separately supplied; no switch timing assumed",
                "interval_min": active.min(0).tolist(), "interval_max": active.max(0).tolist(),
                "interval_mean": active.mean(0).tolist(), "interval_std": active.std(0).tolist(),
                "dominant_voltage_fft_bin_hz": float(frequency[spectrum.argmax()]),
                "fft_resolution_hz": float(frequency[1]),
                "fft_method": "demeaned Hann-windowed voltage spectrum, largest bin above 1Hz; descriptive only"}
    save_json(out / "waveform_evidence.json", evidence)
    spec = {"schema": "DCDC_FROZEN_MODEL_OSCILLATION_HOLDOUT_V1", "run_id": run,
            "source_kind": "PLECS simulation", "source_original_path": str(source), "source_csv_sha256": source_hash,
            "source_csv_preserved": "source/"+source.name,
            "assigned_split": "test", "included_in_training": False,
            "existing_training_dataset": str(dataset), "model_root": str(model_root), "model_sha256": model_hash,
            "preprocessing_sha256": pre_hash, "normalization_refitted": False,
            "sample_rate_hz": 25000, "features": ["vout_v", "iout_a", "duty"], "units": ["V", "A", "fraction_0_to_1"],
            "tensor_layout": "N,T,C", "window_samples": 256, "stride_samples": 128,
            "class_order": ["normal", "load_transient", "oscillation"],
            "shape": list(x.shape), "class_counts": {"0": 0, "1": 0, "2": len(y)},
            "window_start_grid": "anchored to full recording sample 0",
            "source_independence_scope": "different CSV/run and parameter configuration; same simulation domain, not a new physical experiment",
            "limitations": ["one new simulation run; overlapping windows are not independent experiments",
                            "only sustained interior is labeled/evaluated, not growing oscillation or startup",
                            "first per-run holdout result for this checkpoint; future reuse is exploratory",
                            "no normal samples in this new run, so this run alone cannot measure false alarms",
                            "FP32 CPU inference only, no quantization or board arithmetic validation",
                            "do not include this run in training and continue to report it as held out"]}
    save_json(out / "manifest.json", spec)
    evaluation = {"model_sha256": model_hash, "model_epoch": ck["epoch"], "inference": "FP32 CPU",
                  "windows": len(y), "correct": int((predicted == y).sum()),
                  "oscillation_recall": float((predicted == 2).mean()), "predicted_counts_0_1_2": counts.tolist(),
                  "confusion_matrix_true_rows_predicted_columns": [[0, 0, 0], [0, 0, 0], counts.tolist()],
                  "minimum_class2_margin_fp32": float(margin.min()), "median_class2_margin_fp32": float(np.median(margin)),
                  "data_used_for_training": False, "model_weights_changed": False, "normalization_refitted": False}
    save_json(out / "evaluation.json", evaluation)
    previous = json.loads((model_root / "metrics.json").read_text(encoding="utf-8"))["test"]
    combined = np.asarray(previous["confusion_matrix_true_rows_predicted_columns"]) + np.asarray(evaluation["confusion_matrix_true_rows_predicted_columns"])
    save_json(out / "combined_exploratory_test_report.json", {
        "confusion_matrix_true_rows_predicted_columns": combined.tolist(), "samples": int(combined.sum()),
        "accuracy": float(combined.trace()/combined.sum()), "ground_truth_support": combined.sum(1).tolist(),
        "scope": "existing reused physical normal/transient test bank plus one new held-out oscillation simulation; not a fully physical three-class benchmark",
        "model_sha256": model_hash, "training_unchanged": True})
    # Verify saved tensors against the raw CSV, with an independent direct
    # summation of every window's history. Check run and source identity too.
    with np.load(out / "windows" / "oscillation_test.npz", allow_pickle=False) as z:
        assert np.array_equal(z["X"], signal[starts[:, None]+np.arange(256)].astype(np.float32))
        assert np.array_equal(z["y"], y) and np.array_equal(z["start_sample"], starts)
        direct = np.array([signal[max(0, int(s)-50000):s].mean(0) for s in starts])
        assert np.allclose(z["baseline"], direct, rtol=1e-10, atol=1e-10)
        assert np.all(labels[starts[:, None]+np.arange(256)] == 2)
    assert sha(source) == sha(out / "source" / source.name) == source_hash
    assert sha(model_root / "best.pt") == model_hash
    assert sha(model_root / "preprocessing.json") == sha(out / "preprocessing_frozen.json") == pre_hash
    with (out / "predictions.csv").open(encoding="utf-8", newline="") as stream:
        records = list(csv.DictReader(stream))
    assert len(records) == len(y)
    assert np.array_equal([int(r["predicted"]) for r in records], predicted)
    assert np.array_equal([int(r["start_sample"]) for r in records], starts)
    save_json(out / "validation.json", {"status": "PASS", "source_rows_checked": len(t),
              "all_window_values_and_labels_checked": len(y), "all_past_only_baselines_checked": len(y),
              "run_disjoint_from_existing_splits": True, "source_hash_differs_from_training": True,
              "model_and_preprocessing_hashes_unchanged": True, "prediction_records_verified": len(y),
              "scope": "data and frozen-model evaluation audit, not physical NPU validation"})
    readme = f'''# 新增振荡仿真：冻结模型测试

来源：`{source.name}`。25 kHz，250000 点，约 10 秒。
仅取原始时间 [3.0,9.9) 秒的持续振荡段，按 256 点窗口、128 点步长得到 {len(y)} 个窗口。
主振荡频率的 FFT 最大谱线约为 {evidence['dominant_voltage_fft_bin_hz']:.3f} Hz。

使用既有三分类模型 best.pt（第 {ck['epoch']} 轮），未重新训练，未重拟合预处理，原数据集未改变。
模型 SHA256：{model_hash}

- 新 run 振荡识别：{evaluation['correct']}/{len(y)}，召回率 {evaluation['oscillation_recall']:.2%}。
- 预测数量（正常、负载瞬态、振荡）：{counts.tolist()}。
- 类别 2 与其他两类的最小分数间隔：{margin.min():.6f}（FP32，非校准概率）。

`windows/oscillation_test.npz` 保存 X(float32 [N,256,3])、y(int64)、baseline(float64 [N,3])、run_id 和起止采样点。
通道为 Vout(V)、Iout(A)、实际占空比(0～1)。每窗的 baseline 只含窗口开始之前最多 2 秒，同一 run 的均值。
`source/` 保留原 CSV 和完整精度信号，`preprocessing_frozen.json` 是原模型预处理参数。
`predictions.csv` 是逐窗口预测；`evaluation.json` 是本 run 结果；`combined_exploratory_test_report.json` 是与既有正常/瞬态测试结果合并的统计。

本 run 分配 test，尚未参与训练。后续如果拿它训练，必须撤销此 run 的 held-out 测试身份，另留新 run 测试。
这是一个新仿真工况对冻结模型的测试，不等于实板振荡泛化验证。重叠窗口不是 {len(y)} 次独立实验。
还没有 UINT8 量化或板端执行验证；启动、振荡增长过程没有在本次标注中测试。

复现代码保存在 tools/，只做数据整理和冻结模型测试，不拟合或更新权重。
'''
    (out / "README.md").write_text(readme, encoding="utf-8")
    for name in (Path(__file__).name, "train_threeclass_npu.py", "threeclass_data.py", "causal_features.py"):
        shutil.copyfile(Path(__file__).with_name(name), out / "tools" / name)
    save_json(out / "checksums.json", {p.relative_to(out).as_posix(): sha(p) for p in sorted(out.rglob("*")) if p.is_file()})
    print("OSCILLATION_HOLDOUT_AUDIT_PASS", json.dumps(evaluation), flush=True)


if __name__ == "__main__":
    main()
