#!/usr/bin/env python3
"""Integrity-check P481 captures, derive reviewable labels, group, then window.

Dependencies: numpy. Reuses the adjacent capture decoder. No model training.
All derived outputs go to a new directory; source recordings are read only.
"""
import argparse
import csv
import hashlib
import html
import json
from pathlib import Path
import sys

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "adc_fdma_capture"))
import decode_capture as decoder

FEATURES = ["vout_v", "iout_a", "duty"]
CLASSES = {0: "normal", 1: "load_transient"}


def write_json(path, value):
    with Path(path).open("x", encoding="utf-8") as stream:
        json.dump(value, stream, ensure_ascii=False, indent=2)
        stream.write("\n")


def load_signal(binary, info):
    sha = decoder.verify_payload(binary, info)
    raw = np.frombuffer(binary.read_bytes(), dtype=np.uint8).reshape(-1, 16)
    channels = []
    for offset in (0, 6):
        unsigned = sum(raw[:, offset + k].astype(np.int64) << (8 * k) for k in range(6))
        channels.append(((unsigned ^ (1 << 47)) - (1 << 47)) / 65536.0)
    channels.append(sum(raw[:, 12 + k].astype(np.int64) << (8 * k) for k in range(4)) / 65536.0)
    signal = np.column_stack(channels)
    if not np.isfinite(signal).all() or np.any((signal[:, 2] < 0) | (signal[:, 2] > 1)):
        raise ValueError(f"invalid physical duty or non-finite input: {binary.name}")
    if decoder.verify_payload(binary, info) != sha:
        raise ValueError("source changed while decoding")
    return signal, sha


def clusters(indices, maximum_gap_bins):
    """Return half-open ranges joining threshold excursions across short gaps."""
    if len(indices) == 0:
        return []
    breaks = np.flatnonzero(np.diff(indices) > maximum_gap_bins + 1) + 1
    return [(int(group[0]), int(group[-1]) + 1) for group in np.split(indices, breaks)]


def derive_labels(signal, experiment, fs, rules):
    n = len(signal)
    bin_n = rules["mean_bin_samples"]
    means = signal[:n // bin_n * bin_n].reshape(-1, bin_n, 3).mean(axis=1)
    dt = bin_n / fs
    pre = np.median(means[round(rules["baseline_start_s"] / dt):
                               round(rules["baseline_end_s"] / dt)], axis=0)
    final_n = round(rules["final_baseline_duration_s"] / dt)
    post = np.median(means[-final_n:], axis=0)
    edge = round(rules["capture_edge_guard_s"] * fs)
    if n <= 2 * edge or abs(pre[0]) < 1:
        raise ValueError("recording too short or baseline voltage invalid")
    hits = np.flatnonzero(np.abs(means[:, 0] - pre[0]) > abs(pre[0]) * rules["voltage_deviation_fraction"])
    groups = clusters(hits, round(rules["bridge_gap_s"] / dt))
    evidence = {
        "baseline_median_10ms": dict(zip(FEATURES, pre.tolist())),
        "final_median_10ms": dict(zip(FEATURES, post.tolist())),
        "voltage_excursion_clusters_s": [[a * dt, b * dt] for a, b in groups],
        "mean_voltage_range_v": [float(means[:, 0].min()), float(means[:, 0].max())],
        "raw_voltage_range_v": [float(signal[:, 0].min()), float(signal[:, 0].max())],
        "annotation_status": "waveform_rule_v1_provisional",
        "experiment_origin": "user_confirmed_three_load_step_recordings; other_six_steady_records",
        "time_basis": "sample index / nominal CAP1 rate; external command edge unavailable"
    }
    if experiment == "steady":
        tolerance = np.array([abs(pre[0]) * .02, max(abs(pre[1]) * .03, .01),
                              max(abs(pre[2]) * .01, .001)])
        if np.any(np.abs(means - pre) > tolerance):
            raise ValueError("steady record failed stability screen; review before labeling")
        intervals = [{"start": edge, "end": n - edge, "class_id": 0}]
    elif experiment == "load_step":
        if not groups or abs(post[1] - pre[1]) < .1:
            raise ValueError("confirmed step lacks a clear voltage response/current change")
        onset, recovery = groups[0]
        if onset * dt <= rules["baseline_end_s"] or (recovery - onset) * dt < .10:
            raise ValueError("invalid primary event; manual review required")
        inner = round(rules["transient_inner_guard_s"] * fs)
        pre_end = onset * bin_n - round(rules["pre_event_guard_s"] * fs)
        class1_start, class1_end = onset * bin_n + inner, recovery * bin_n - inner
        # Only resume normal labeling after the LAST departure from final V/I/duty.
        # This leaves recovery tails and later unconfirmed disturbances unlabeled.
        tol = np.array([abs(post[0]) * rules["final_voltage_tolerance_fraction"],
                        max(abs(post[1]) * rules["final_current_tolerance_fraction"],
                            rules["final_current_tolerance_floor_a"]),
                        max(abs(post[2]) * rules["final_duty_tolerance_fraction"],
                            rules["final_duty_tolerance_floor"])])
        bad = np.flatnonzero(np.any(np.abs(means - post) > tol, axis=1))
        last_bad_end = max(recovery * bin_n, (int(bad[-1]) + 1) * bin_n if len(bad) else 0)
        post_start = last_bad_end + round(rules["final_settling_guard_s"] * fs)
        intervals = [{"start": edge, "end": pre_end, "class_id": 0},
                     {"start": class1_start, "end": class1_end, "class_id": 1},
                     {"start": post_start, "end": n - edge, "class_id": 0}]
        evidence.update({
            "primary_response_envelope_s": [onset * dt, recovery * dt],
            "class1_inner_interval_s": [class1_start / fs, class1_end / fs],
            "normal_resume_s": post_start / fs,
            "later_voltage_excursions_left_unlabeled": len(groups) > 1,
            "meaning_of_class1": "clear interior of load-step voltage-response episode; not command-edge ground truth",
            "final_tolerances": dict(zip(FEATURES, tol.tolist()))
        })
    else:
        raise ValueError("unknown experiment")
    labels = np.full(n, -1, dtype=np.int8)
    end = 0
    for interval in intervals:
        a, b, c = interval["start"], interval["end"], interval["class_id"]
        if not end <= a < b <= n or c not in CLASSES:
            raise ValueError("label rules produced invalid/overlapping intervals")
        labels[a:b] = c
        end = b
    evidence["sample_counts"] = {str(c): int(np.count_nonzero(labels == c)) for c in (-1, 0, 1)}
    return intervals, labels, means, evidence


def make_windows(signal, labels, window, stride):
    if window <= 0 or stride <= 0 or len(signal) != len(labels):
        raise ValueError("invalid window parameters")
    starts, targets = [], []
    rejected = 0
    for start in range(0, len(labels) - window + 1, stride):
        segment = labels[start:start + window]
        if segment[0] >= 0 and np.all(segment == segment[0]):
            starts.append(start)
            targets.append(segment[0])
        else:
            rejected += 1
    starts = np.array(starts, dtype=np.int64)
    indices = starts[:, None] + np.arange(window)[None, :]
    return signal[indices].astype(np.float32), np.array(targets, dtype=np.int64), starts, rejected


def validate_config(config):
    seen = set()
    for row in config["runs"]:
        run = row["run_id"]
        if run in seen or Path(run).name != run or "/" in run or "\\" in run:
            raise ValueError("duplicate or invalid run_id")
        if row["split"] not in ("train", "validation", "test"):
            raise ValueError("invalid split")
        seen.add(run)
    if config["schema"] != "DCDC_DATASET_CONFIG_V1":
        raise ValueError("unsupported configuration")


def plot_svg(path, run, means, intervals, fs, bin_n, duration):
    width, height, left, right = 1280, 700, 85, 1240
    esc = html.escape
    chunks = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
              '<rect width="100%" height="100%" fill="white"/>',
              f'<text x="85" y="30" font-family="sans-serif" font-size="19">{esc(run)}</text>',
              '<text x="85" y="54" font-family="sans-serif" font-size="13">10 ms means for display only; windows retain raw 25 kHz samples. Green=0, red=1, gray=-1.</text>']
    def px(t):
        return left + (right - left) * t / duration
    for channel, name in enumerate(FEATURES):
        top, bottom = 85 + channel * 195, 235 + channel * 195
        lo, hi = float(means[:, channel].min()), float(means[:, channel].max())
        pad = max((hi - lo) * .12, abs((hi + lo) / 2) * .0005, .00001)
        lo, hi = lo - pad, hi + pad
        chunks.append(f'<rect x="{left}" y="{top}" width="{right-left}" height="{bottom-top}" fill="#eceff2"/>')
        for interval in intervals:
            a, b = px(interval["start"] / fs), px(interval["end"] / fs)
            color = "#dcf5e3" if interval["class_id"] == 0 else "#ffd9d5"
            chunks.append(f'<rect x="{a:.2f}" y="{top}" width="{b-a:.2f}" height="{bottom-top}" fill="{color}"/>')
        for fraction in (0, .5, 1):
            y = bottom - fraction * (bottom - top)
            value = lo + fraction * (hi - lo)
            chunks.append(f'<path d="M {left} {y} H {right}" stroke="#cbd2d9"/><text x="78" y="{y+4}" text-anchor="end" font-family="sans-serif" font-size="11">{value:.5g}</text>')
        points = " ".join(f'{px((k+.5)*bin_n/fs):.2f},{bottom-(float(v)-lo)/(hi-lo)*(bottom-top):.2f}' for k, v in enumerate(means[:, channel]))
        chunks.append(f'<polyline fill="none" stroke="#176f9b" stroke-width="1.2" points="{points}"/>')
        chunks.append(f'<text x="{left}" y="{top-8}" font-family="sans-serif" font-size="14">{name}</text>')
        for t in range(int(duration) + 1):
            chunks.append(f'<text x="{px(t):.2f}" y="{bottom+18}" text-anchor="middle" font-family="sans-serif" font-size="11">{t}</text>')
    chunks.append('<text x="650" y="687" text-anchor="middle" font-family="sans-serif" font-size="13">Nominal time from capture start (s); provisional waveform-derived labels</text></svg>')
    path.write_text("\n".join(chunks), encoding="utf-8")


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1048576), b""):
            h.update(chunk)
    return h.hexdigest()


def prepare(records, output, config_path):
    config = json.loads(config_path.read_text(encoding="utf-8"))
    validate_config(config)
    if output.exists():
        raise ValueError("output already exists; choose a new directory")
    source_set = {p.stem for p in records.glob("*.bin") if not p.name.endswith(".info.bin")}
    if source_set != {r["run_id"] for r in config["runs"]}:
        raise ValueError("source recording list differs from explicit configuration")
    output.mkdir(parents=True)
    for name in ("csv", "labels", "evidence", "plots", "windows"):
        (output / name).mkdir()
    write_json(output / "config.json", config)
    window, stride = config["window_samples"], config["stride_samples"]
    splits = {s: {"X": [], "y": [], "run_id": [], "start_sample": [], "runs": []}
              for s in ("train", "validation", "test")}
    report, seen_hashes = [], set()
    for row in config["runs"]:
        run, split = row["run_id"], row["split"]
        binary = records / f"{run}.bin"
        info_path = records / f"{run}.info.bin"
        info = decoder.read_info(info_path)
        if info["sample_rate_hz"] != config["sample_rate_hz"]:
            raise ValueError("sample rates differ; no implicit resampling")
        signal, payload_sha = load_signal(binary, info)
        if payload_sha in seen_hashes:
            raise ValueError("duplicate payload under different run IDs")
        seen_hashes.add(payload_sha)
        intervals, labels, means, evidence = derive_labels(signal, row["experiment"], info["sample_rate_hz"], config["rules"])
        label_path = output / "labels" / f"{run}.labels.json"
        write_json(label_path, intervals)
        csv_path = output / "csv" / f"{run}.csv"
        summary = decoder.convert(binary, info_path, csv_path, run, labels_path=label_path)
        if summary["sha256"] != payload_sha:
            raise ValueError("payload changed before CSV export")
        X, y, starts, rejected = make_windows(signal, labels, window, stride)
        part = splits[split]
        part["X"].append(X)
        part["y"].append(y)
        part["start_sample"].append(starts)
        part["run_id"].append(np.full(len(y), run, dtype=f"<U{len(run)}"))
        part["runs"].append(run)
        evidence.update({"run_id": run, "split": split, "experiment": row["experiment"],
                         "payload_sha256": payload_sha, "info_sha256": sha256(info_path),
                         "capture_info": info, "samples": len(signal),
                         "label_intervals_end_exclusive": intervals,
                         "accepted_windows": len(y), "rejected_windows": rejected,
                         "window_counts": {str(c): int(np.count_nonzero(y == c)) for c in CLASSES}})
        write_json(output / "evidence" / f"{run}.json", evidence)
        plot_svg(output / "plots" / f"{run}.svg", run, means, intervals, info["sample_rate_hz"], config["rules"]["mean_bin_samples"], len(signal) / info["sample_rate_hz"])
        report.append(evidence)
        print(f"RUN_PASS {run} split={split} normal={np.count_nonzero(y==0)} transient={np.count_nonzero(y==1)} excluded={rejected}", flush=True)
    split_report = {}
    for split, part in splits.items():
        arrays = {k: np.concatenate(part[k], axis=0) for k in ("X", "y", "run_id", "start_sample")}
        if set(np.unique(arrays["y"])) != set(CLASSES):
            raise ValueError(f"{split} lacks one of the two classes")
        if arrays["X"].shape != (len(arrays["y"]), window, 3):
            raise ValueError("unexpected tensor shape")
        np.savez_compressed(output / "windows" / f"{split}.npz", **arrays,
                            end_sample=arrays["start_sample"] + window,
                            sample_rate_hz=np.array(config["sample_rate_hz"], dtype=np.int64),
                            feature_names=np.array(FEATURES))
        counts = {str(c): int(np.count_nonzero(arrays["y"] == c)) for c in CLASSES}
        split_report[split] = {"runs": part["runs"], "shape": list(arrays["X"].shape), "class_counts": counts}
    manifest = {
        "schema": "DCDC_WINDOW_DATASET_V1", "classes": CLASSES, "missing_classes": {2: "oscillation"},
        "features": FEATURES, "tensor_layout": "N,T,C", "dtype": "float32",
        "units": ["V", "A", "fraction_0_to_1"], "normalization": "none; fit only on training data in a later training step",
        "window_samples": window, "stride_samples": stride, "window_duration_s": window / config["sample_rate_hz"],
        "window_label_policy": "all samples same known class; unknown or mixed windows excluded; grid anchored to run sample 0",
        "annotation_status": "provisional waveform-derived response labels, not independently verified command timing",
        "split_policy": "explicit run groups assigned before window extraction; unique payload hashes; no run crosses a split",
        "split_rationale": "5/2/2 runs; 24V step train, 36V step validation, 48V step test; each has steady recordings too",
        "limitations": ["only three independent step experiments; results cannot establish generalization",
                       "10.24 ms windows may learn voltage sag rather than event dynamics; compare longer windows later",
                       "no oscillation data or third-class training", "nominal timing without per-frame hardware timestamps",
                       "threshold-derived labels are a first dataset version and require domain review"],
        "source_records": str(records.resolve()), "splits": split_report, "runs": report
    }
    write_json(output / "manifest.json", manifest)
    with (output / "window_index.csv").open("x", encoding="utf-8", newline="") as stream:
        writer = csv.writer(stream)
        writer.writerow(["split", "row_in_npz", "run_id", "start_sample", "end_sample_exclusive", "class_id"])
        for split in splits:
            with np.load(output / "windows" / f"{split}.npz", allow_pickle=False) as data:
                columns = {key: data[key] for key in ("y", "run_id", "start_sample", "end_sample")}
                for k in range(len(columns["y"])):
                    writer.writerow([split, k, str(columns["run_id"][k]), int(columns["start_sample"][k]), int(columns["end_sample"][k]), int(columns["y"][k])])
    rows = []
    for run in report:
        timing = run.get("class1_inner_interval_s")
        times = "—" if timing is None else f"{timing[0]:.3f}–{timing[1]:.3f} s"
        rows.append(f'<tr><td>{html.escape(run["run_id"])}</td><td>{run["split"]}</td><td>{times}</td><td>{run["window_counts"]["0"]}</td><td>{run["window_counts"]["1"]}</td><td><a href="plots/{run["run_id"]}.svg">波形及标签</a></td></tr>')
    html_text = '<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>DCDC 数据集标注与分组</title><style>body{font:16px/1.6 system-ui;max-width:1250px;margin:32px auto;padding:0 24px;color:#172d40}table{border-collapse:collapse;width:100%;font-size:14px}td,th{padding:10px;border:1px solid #d9e0e5;text-align:left}code{background:#edf2f5;padding:3px}img{width:100%}.note{padding:16px;background:#fff0ce;border-left:4px solid #be8a1b}</style><h1>DCDC 二分类数据准备 · 2026-10-26</h1><p>输入顺序：输出电压 V、输出电流 A、实际占空比 0–1。原始文件只读。9 次采集经 CAP1、长度和 CRC 检查。</p><p class="note">类别 0=正常，1=负载突变响应，-1=未标注/排除。标签由波形规则推导，尚非逐段人工确认。没有外部负载命令时间戳，不能用来证明精确检测延迟。36 V 后段额外扰动不自动赋予类别。当前没有振荡类别。</p><p>先按 run 分组，再以 256 点窗口、128 点步长切片；仅保留整个窗口同一已知类别。SVG 使用 10 ms 均值便于查看；CSV 和 NPZ 保留原始采样，无滤波、归一化或量化。</p><table><tr><th>采集记录</th><th>集合</th><th>类别1区间</th><th>正常窗口</th><th>突变窗口</th><th>查看</th></tr>' + ''.join(rows) + '</table><h2>标注规则与限制</h2><p>固定使用 0.25–1.25 s 的三路 10 ms 均值中位数作为事件前基线；电压偏差超过 2% 的首次响应簇作为主事件，桥接不超过 100 ms 的短间断，并在内部两端各缩进 20 ms。事件前额外排除 200 ms。事件后只有当电压、电流、占空比均持续接近最终水平，且留出 250 ms 余量后，才恢复正常标签。每次采集头尾各排除 100 ms。完整参数见 config.json。</p><p>固定训练/验证/测试分组为 5/2/2 次独立采集；三次阶跃分别放入三个集合。验证和测试使用不同电压的阶跃，训练结果可能受工况差异影响。仅三次阶跃不足以建立稳定的泛化评估；大量重叠窗口不等于大量独立实验。正常窗口占多数，后续训练需处理类别不平衡。</p><h2>波形与标签</h2>'
    for run in report:
        html_text += f'<h3>{html.escape(run["run_id"])}</h3><img src="plots/{run["run_id"]}.svg" alt="waveforms and provisional labels">'
    (output / "review.html").write_text(html_text + '</html>', encoding="utf-8")
    print(json.dumps(split_report, ensure_ascii=False, indent=2), flush=True)
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--records", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--config", type=Path, default=HERE / "dataset_config.json")
    args = parser.parse_args()
    prepare(args.records.resolve(), args.output.resolve(), args.config.resolve())


if __name__ == "__main__":
    main()
