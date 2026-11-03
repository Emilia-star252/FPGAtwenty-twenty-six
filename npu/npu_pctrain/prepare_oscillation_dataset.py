#!/usr/bin/env python3
"""Prepare one confirmed PLECS oscillation run plus the existing physical bank.

Data preparation only. Preserve original records, models and run-level splits.
"""
import argparse
import csv
import hashlib
import json
from pathlib import Path
import shutil

import numpy as np

from causal_features import prefix_baselines
from train_condition import load_dataset
from causal_features import baselines_for_part

FEATURES = ["vout_v", "iout_a", "duty"]
CLASSES = {"0": "normal", "1": "load_transient", "2": "oscillation"}


def sha(path):
    h = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for block in iter(lambda: stream.read(1048576), b""):
            h.update(block)
    return h.hexdigest()


def write_json(path, value):
    with Path(path).open("x", encoding="utf-8") as stream:
        json.dump(value, stream, ensure_ascii=False, indent=2, allow_nan=False)
        stream.write("\n")


def waveform_evidence(a, start, end):
    t, x = a[:, 0], a[:, 1:]
    active = x[(t >= start) & (t < end)]
    v = active[:, 0]
    n = len(v)
    f = np.fft.rfftfreq(n, 1 / 25000)
    spectrum = abs(np.fft.rfft((v - v.mean()) * np.hanning(n)))
    spectrum[f < 1] = 0
    peak = int(spectrum.argmax())
    return {
        "annotation": "user-confirmed oscillation simulation; constant PI settings throughout run",
        "channel_confirmation": "user confirms C-Script is applied duty fraction 0..1",
        "switching_event": "no PI parameter switch; onset inferred from waveform only",
        "sample_count": len(t), "time_first_s": float(t[0]), "time_last_s": float(t[-1]),
        "sample_rate_hz": 25000, "dt_min_s": float(np.diff(t).min()),
        "dt_max_s": float(np.diff(t).max()),
        "labeled_interval_s": [start, end],
        "interval_min": active.min(0).tolist(), "interval_max": active.max(0).tolist(),
        "interval_mean": active.mean(0).tolist(), "interval_std": active.std(0).tolist(),
        "dominant_voltage_fft_bin_hz": float(f[peak]),
        "fft_resolution_hz": float(f[1]),
        "fft_method": "demeaned voltage, Hann window, largest magnitude bin above 1 Hz; descriptive only",
        "excluded_intervals": "before 3s: startup and growing oscillation; last 0.1s: capture edge guard",
        "label_ground_truth_scope": "conservative sustained-oscillation interior, not exact instability onset",
        "source_kind": "PLECS simulation; not physical-board oscillation evidence",
    }


def make_review(root, a, evidence):
    # 1 ms min/max envelopes retain high-amplitude excursions in the overview.
    t, x = a[:, 0], a[:, 1:]
    n = len(t) // 25
    blocks = x[:n * 25].reshape(n, 25, 3)
    overview = np.column_stack([t[:n * 25:25], blocks.min(1), blocks.max(1)]).tolist()
    zoom = a[(t >= 4) & (t < 4.1)].tolist()
    page = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8">
<title>振荡数据标注复核</title><style>body{font:16px system-ui;margin:30px;max-width:1250px}canvas{width:100%;height:540px;border:1px solid #ddd}pre{white-space:pre-wrap}button{padding:8px;margin:8px}</style>
<h1>PLECS 振荡数据：训练候选标注</h1>
<p>0=正常，1=负载瞬态，2=振荡。本 run 仅取 3.0～9.9 秒为振荡；灰色区不参与训练。全程 PI 参数未切换。仅分配 train，禁止同一 run 随机跨集合。</p>
<button onclick="draw(false)">全程：1 ms 最小/最大包络</button><button onclick="draw(true)">4.0～4.1 秒：原始采样</button>
<canvas id="plot" width="1200" height="540"></canvas><p>通道依次为 Vout (V)、Iout (A)、实际占空比 (0～1)。原始 CSV 与张量保留全部采样，图形不参与特征计算。</p>
<p>此仿真 run 是目前唯一的第三类来源。验证/测试集没有第三类，不能据此宣布三分类验证通过。还需要独立振荡 run，以及仿真正常/瞬态或实测振荡数据，排除来源差异造成的捷径。</p>
<pre id="evidence"></pre><script>const overview=__OVERVIEW__,zoom=__ZOOM__,ev=__EVIDENCE__;
document.getElementById('evidence').textContent=JSON.stringify(ev,null,2);
function draw(detail){const c=document.getElementById('plot'),g=c.getContext('2d');g.clearRect(0,0,1200,540);g.font='13px sans-serif';let data=detail?zoom:overview;const ta=detail?4:0,tb=detail?4.1:10,px=t=>85+1090*(t-ta)/(tb-ta);for(let k=0;k<3;k++){let vals=detail?data.map(r=>r[k+1]):data.flatMap(r=>[r[k+1],r[k+4]]),lo=Math.min(...vals),hi=Math.max(...vals),pad=Math.max((hi-lo)*.07,.00001);lo-=pad;hi+=pad;const top=20+k*175,bot=top+135,py=v=>bot-(v-lo)/(hi-lo)*135;g.fillStyle='#edf0f3';g.fillRect(85,top,1090,135);g.fillStyle='#dcf5e3';g.fillRect(px(Math.max(ta,3)),top,Math.max(0,px(Math.min(tb,9.9))-px(Math.max(ta,3))),135);g.fillStyle='#222';g.fillText(['Vout (V)','Iout (A)','Duty'][k],5,top+14);g.fillText(hi.toPrecision(5),5,top+37);g.fillText(lo.toPrecision(5),5,bot);g.strokeStyle='#1769aa';g.beginPath();data.forEach((r,i)=>{if(detail){if(i===0)g.moveTo(px(r[0]),py(r[k+1]));else g.lineTo(px(r[0]),py(r[k+1]));}else{g.moveTo(px(r[0]),py(r[k+1]));g.lineTo(px(r[0]),py(r[k+4]));}});g.stroke();for(let j=0;j<=5;j++){let tt=ta+(tb-ta)*j/5;g.fillText(tt.toFixed(detail?2:1)+' s',px(tt)-12,bot+21);}}}draw(false);</script></html>'''
    page = page.replace("__OVERVIEW__", json.dumps(overview)).replace("__ZOOM__", json.dumps(zoom)).replace("__EVIDENCE__", json.dumps(evidence, ensure_ascii=False))
    (root / "review.html").write_text(page, encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--csv", type=Path, required=True)
    parser.add_argument("--base", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--duty-confirmed", action="store_true", required=True)
    args = parser.parse_args()
    source, base, out = args.csv.resolve(), args.base.resolve(), args.output.resolve()
    if out.exists():
        raise ValueError("output exists; choose a new directory")
    source_hash = sha(source)
    with source.open(encoding="utf-8-sig", newline="") as stream:
        header = next(csv.reader(stream))
    if header != ["Time", "Vm1:Measured voltage", "Am1:Measured current", "C-Script"]:
        raise ValueError("unexpected CSV columns")
    a = np.loadtxt(source, delimiter=",", skiprows=1, dtype=np.float64)
    if a.ndim != 2 or a.shape[1] != 4 or not np.isfinite(a).all():
        raise ValueError("invalid shape/non-finite CSV")
    t, signal = a[:, 0], a[:, 1:]
    if not np.allclose(np.diff(t), 1 / 25000, rtol=1e-7, atol=1e-12):
        raise ValueError("CSV must have uniform 25kHz sampling; no automatic resampling")
    if np.any((signal[:, 2] < 0) | (signal[:, 2] > 1)):
        raise ValueError("duty outside 0..1")
    parts, old = load_dataset(base)
    run = source.stem
    if run in {r["run_id"] for r in old["runs"]}:
        raise ValueError("duplicate run ID")
    labels = np.full(len(t), -1, dtype=np.int8)
    labels[(t >= 3.0) & (t < 9.9)] = 2
    begins = np.arange(0, len(t) - 255, 128, dtype=np.int64)
    starts = begins[np.all(labels[begins[:, None] + np.arange(256)] == 2, axis=1)]
    x = signal[starts[:, None] + np.arange(256)].astype(np.float32)
    baselines = prefix_baselines(signal, starts, 50000)
    evidence = waveform_evidence(a, 3.0, 9.9)
    out.mkdir(parents=True)
    for name in ("source", "csv", "windows", "tools"):
        (out / name).mkdir()
    copy = out / "source" / source.name
    shutil.copyfile(source, copy)
    if sha(copy) != source_hash or sha(source) != source_hash:
        raise ValueError("CSV changed during preparation")
    np.savez_compressed(out / "source" / "simulation_signal.npz", time_s=t, signal=signal, labels=labels)
    # Canonical context CSV uses sample-relative time; original solver time is
    # preserved above and its constant offset is recorded in the manifest.
    with (out / "csv" / f"{run}.csv").open("x", encoding="utf-8", newline="") as stream:
        writer = csv.writer(stream)
        writer.writerow(["run_id", "sample_index", "time_s", *FEATURES, "class_id"])
        for k, row in enumerate(signal):
            writer.writerow([run, k, format(k / 25000, ".9f"), *[format(float(v), ".17g") for v in row], int(labels[k])])
    np.savez_compressed(out / "windows" / "oscillation_train.npz", X=x,
                        y=np.full(len(x), 2, np.int64), baseline=baselines,
                        run_id=np.full(len(x), run), start_sample=starts,
                        end_sample=starts+256, feature_names=np.array(FEATURES),
                        sample_rate_hz=np.array(25000), source_kind=np.full(len(x), "simulation"))
    summaries = {}
    for split, part in parts.items():
        print("PREPARE", split, "original_windows", len(part["y"]), flush=True)
        history = baselines_for_part(part, base, old, 2.0)
        arrays = {k: part[k] for k in ("X", "y", "run_id", "start_sample", "end_sample", "feature_names", "sample_rate_hz")}
        arrays["baseline"] = history
        arrays["source_kind"] = np.full(len(part["y"]), "physical_board")
        if split == "train":
            for key, addon in {"X": x, "y": np.full(len(x), 2, np.int64), "run_id": np.full(len(x), run),
                               "start_sample": starts, "end_sample": starts+256, "baseline": baselines,
                               "source_kind": np.full(len(x), "simulation")}.items():
                arrays[key] = np.concatenate([arrays[key], addon])
        # Physical values + exact past-only means are portable. No fixed
        # normalization/quantization from the older binary model is reused.
        np.savez_compressed(out / "windows" / f"{split}.npz", **arrays)
        summaries[split] = {"shape": list(arrays["X"].shape),
                            "runs": sorted(set(arrays["run_id"].tolist())),
                            "class_counts": {str(c): int((arrays["y"] == c).sum()) for c in range(3)}}
    manifest = {
        "schema": "DCDC_THREECLASS_MIXED_SOURCE_V1", "classes": CLASSES,
        "features": FEATURES, "units": ["V", "A", "fraction_0_to_1"],
        "tensor_layout": "N,T,C", "dtype": "float32", "window_samples": 256,
        "stride_samples": 128, "sample_rate_hz": 25000, "window_duration_s": .01024,
        "intended_npu_input_shape": [1, 3, 16, 16],
        "causal_context": {"seconds": 2.0, "baseline_key": "baseline", "dtype": "float64",
                           "interval": "[max(0,start-50000),start)", "floors": [1.0, .05, .05]},
        "normalization": "not fitted; fit causal-relative mean/std on combined train only in later training",
        "source_base": str(base), "source_base_manifest_sha256": sha(base / "manifest.json"),
        "source_simulation": {"run_id": run, "csv_sha256": source_hash, "samples": len(t),
                              "source_kind": "PLECS simulation", "original_path": str(source),
                              "preserved_path": "source/" + source.name,
                              "original_time_offset_s": float(t[0]), "assigned_split": "train",
                              "class2_interval_start_sample": int(np.flatnonzero(labels == 2)[0]),
                              "class2_interval_end_sample_exclusive": int(np.flatnonzero(labels == 2)[-1] + 1),
                              "label_interval_original_time_s": [3.0, 9.9],
                              "annotation_status": "conservative waveform-derived sustained interior; user confirms oscillation and duty"},
        "splits": summaries,
        "split_policy": "all previous physical run assignments preserved; only new simulation run assigned train; no random window split",
        "training_readiness": "prepared for three-class training development; third-class independent validation/test unavailable",
        "limitations": ["one independent oscillation simulation run only; no held-out oscillation run",
                        "class 2 appears only in simulation and train: source-domain shortcut is possible",
                        "normal and load transient remain physical recordings; add matching-domain controls and physical oscillation data",
                        "79Hz oscillation period about 12.7ms exceeds 10.24ms window; a window may show less than one cycle",
                        "overlapping windows are not independent experiments",
                        "existing binary trainer, exported model, output mapping and quantization must be adapted/retrained for 3 classes",
                        "no model training, ONNX export, quantization or board validation performed by this preparation"],
    }
    write_json(out / "manifest.json", manifest)
    write_json(out / "waveform_evidence.json", evidence)
    make_review(out, a, evidence)
    for name in (Path(__file__).name, "verify_oscillation_dataset.py", "threeclass_data.py", "causal_features.py", "train_condition.py"):
        shutil.copyfile(Path(__file__).with_name(name), out / "tools" / name)
    readme = '''# 三分类训练数据（加入一个 PLECS 振荡 run）

此目录完成数据整理，没有重新训练模型，也没有替换旧的二分类模型。

类别：0=normal，1=load_transient，2=oscillation。通道依次为 Vout(V)、Iout(A)、实际占空比(0～1)。
采样率 25 kHz，窗口 256 点=10.24 ms，步长 128 点=5.12 ms。X 为 float32 [N,256,3] 物理量。
baseline 为 float64 [N,3]，只取同一 run 当前窗口之前最多 2 秒的均值。
原仿真 CSV 原样保存在 source/，完整数值和时间/标注在 source/simulation_signal.npz。

振荡只使用原始时间 [3.0,9.9) 秒。前段包含启动和振荡发展过程，最后 0.1 秒作为边界保护，均不参与训练。
用户确认 C-Script 是占空比，全程未切换 PI 参数。标注是持续振荡内部区间，不是精确失稳时刻。
唯一仿真 run 全部属于 train，禁止把重叠窗口随机分到验证/测试集。
原来 9 个实测 run 的划分与全部物理量窗口保持一致。

## 使用

windows/train.npz、validation.npz、test.npz 是合并后的完整集合；oscillation_train.npz 是振荡增量，不能再次追加造成重复。
用 tools/threeclass_data.py 的 fit_preprocessing(root) 只在 train 拟合均值/标准差；
用 load_split(root, split, preprocessing) 得到 NCHW [N,3,16,16] 的 float32 输入、int64 标签和元数据。
preprocessing_candidate.json 已按上述方法只在 train 拟合，是数据准备参数，不是已训练的模型参数。
保留 0/1/2 三个有效输出类别；旧代码只训练通道 0/1，不能直接用于本数据。
后续三分类训练需重新计算类别权重、标准化和 INT8/UINT8 量化参数；不能沿用二分类量化 scale/zero point。

## 当前验证边界

只有一个振荡仿真 run，因此 validation/test 没有 class 2。
可开始训练开发，但不能报告独立三分类准确率、振荡召回率或实测振荡识别能力。
还应采集不同 PI、工况、负载、初值的独立振荡 run，并补充仿真正常/瞬态对照或实测振荡，避免学习仿真/实测来源差异。
当前约 79 Hz 振荡周期约 12.7 ms，长于 10.24 ms 输入窗口；未来要独立评估更长时间上下文。

review.html 可复核波形、保留区间与原始采样局部；waveform_evidence.json 记录范围与频谱估计。
validation.json 只证明文件、窗口、标签、历史上下文及集合划分一致，不证明模型或硬件性能。
'''
    (out / "README.md").write_text(readme, encoding="utf-8")
    from threeclass_data import fit_preprocessing
    write_json(out / "preprocessing_candidate.json", fit_preprocessing(out))
    from verify_oscillation_dataset import verify
    verify(out)
    write_json(out / "checksums.json", {p.relative_to(out).as_posix(): sha(p) for p in sorted(out.rglob("*")) if p.is_file()})
    print("OSCILLATION_DATASET_PREPARED", json.dumps(summaries), flush=True)


if __name__ == "__main__":
    main()
