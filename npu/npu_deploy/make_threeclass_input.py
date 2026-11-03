"""把板卡采样（CSV）转成他们三分类模型要的输入文件。

输出两个文件（直接喂 `dcdc_npu_threeclass_infer --physical-input ... --baseline ...`）：
  <name>.physical_f32.bin   256 帧 × 3 通道，T,C 顺序，float32
  <name>.baseline_f64.bin   3 个 float64：窗口**之前**的过去均值（causal-relative 的 baseline）

关键点（都来自他们的契约，已用他们 46 个向量逐位复现过）：
  * 每一帧按 T,C 排列：值 = [vout, iout, duty]，duty 必须是 0..1
  * 窗口 256 帧；训练时约 2 s → 等效 128 Hz
  * baseline = 窗口起点之前的过去均值（最多 50000 个采样）

采样率不一致是**真实风险**：1 Hz 日志喂给按 128 Hz 训练的窗口，时间尺度完全不同。
所以本工具会显式报告源采样率、是否做过重采样，并在速率过低时告警（不给假象）。

用法：
  python make_threeclass_input.py --csv board.csv --end 12.5 --out out/case1
  python make_threeclass_input.py --csv board.csv --end 12.5 --rate 10 --out out/case1
"""

from __future__ import annotations

import argparse
import os
import struct
import sys

import numpy as np

WINDOW = 256
TRAIN_RATE = 128.0     # 256 帧 / 2 s
BASELINE_MAX = 50000


def read_csv(path):
    """读板卡/上位机日志。支持两种表头：
       timestamp,uptime_s,v_out,i_out,duty,...      （host.py / sim_board.py）
       t,vout,iout,duty 或 time,v,i,d               （自定义）
    duty 允许是 0..100 的百分数（会自动除以 100）。
    """
    rows = []
    if not os.path.exists(path):
        raise SystemExit(
            f"CSV not found: {path}\n"
            f"  hint 1: use an absolute path, or run from the folder that contains it\n"
            f"  hint 2: no real capture yet? try the bundled demo:\n"
            f"          D:\\deepseek\\work\\npu_train\\tc.cmd demo")
    with open(path, encoding="utf-8-sig") as f:
        header = None
        for line in f:
            line = line.strip()
            if not line:
                continue
            parts = [p.strip() for p in line.split(",")]
            if header is None:
                low = [p.lower() for p in parts]
                if any("v" == p or "v_out" == p or "vout" == p for p in low):
                    header = low
                    continue
                header = []          # 无表头，按 t,v,i,d 处理
            try:
                vals = [float(p) for p in parts]
            except ValueError:
                continue
            rows.append(vals)
    if not rows:
        raise SystemExit(f"no data rows in {path}")
    n = min(len(r) for r in rows)
    data = np.array([r[:n] for r in rows], dtype=np.float64)
    return data, header


def pick_columns(data, header):
    """返回 (time, vout, iout, duty) 四个列索引。"""
    if header:
        def find(*names):
            for i, h in enumerate(header):
                if h in names:
                    return i
            return None
        ti = find("uptime_s", "t", "time", "timestamp")
        vi = find("v_out", "vout", "v")
        ii = find("i_out", "iout", "i")
        di = find("duty", "d")
        if None not in (vi, ii, di):
            return (ti if ti is not None else 0), vi, ii, di
    # 无表头：t, v, i, d
    if data.shape[1] >= 4:
        return 0, 1, 2, 3
    raise SystemExit("CSV needs at least 4 columns: time, vout, iout, duty")


def resample(series, src_rate, dst_rate):
    """线性重采样到 dst_rate（用归一化时间轴，避免依赖绝对时间戳）。"""
    if abs(src_rate - dst_rate) < 1e-9:
        return series
    n_out = max(2, int(round(len(series) * dst_rate / src_rate)))
    src_x = np.linspace(0.0, 1.0, len(series))
    dst_x = np.linspace(0.0, 1.0, n_out)
    return np.stack([np.interp(dst_x, src_x, series[:, c]) for c in range(series.shape[1])], axis=1)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv", required=True)
    ap.add_argument("--end", type=float, default=None, help="窗口结束时间（秒）；默认用最后 256*2 秒")
    ap.add_argument("--rate", type=float, default=None, help="源采样率 Hz；不给就按时间列估计")
    ap.add_argument("--out", required=True, help="输出前缀，例如 out/case1")
    args = ap.parse_args(argv)

    data, header = read_csv(args.csv)
    ti, vi, ii, di = pick_columns(data, header)
    t = data[:, ti]
    feat = np.stack([data[:, vi], data[:, ii], data[:, di]], axis=1)

    # duty: 百分数 -> 0..1
    if np.nanmax(feat[:, 2]) > 1.5:
        feat[:, 2] /= 100.0
        duty_scaled = True
    else:
        duty_scaled = False

    # 采样率
    if args.rate:
        rate = args.rate
        rate_src = "手动指定"
    else:
        dt = np.diff(t)
        dt = dt[dt > 0]
        if len(dt) == 0:
            raise SystemExit("time column not increasing; pass --rate explicitly")
        rate = 1.0 / float(np.median(dt))
        rate_src = "按时间列估计"

    # 窗口起点：默认最后 2 秒
    t_end = t[-1] if args.end is None else args.end
    span = WINDOW / TRAIN_RATE
    t_start = t_end - span
    mask = (t > t_start) & (t <= t_end)
    win = feat[mask]
    past = feat[t <= t_start]
    if past.size == 0:
        raise SystemExit("no samples before the window; increase --end")
    if len(win) < 8:
        raise SystemExit(f"only {len(win)} samples in window; check --end / --rate")

    baseline = np.mean(past[-BASELINE_MAX:], axis=0)      # 过去均值（causal）
    resampled = resample(win, rate, TRAIN_RATE) if abs(rate - TRAIN_RATE) > 1e-6 else win
    # 严格取 256 帧（多了取尾部，少了线性补齐）
    if len(resampled) > WINDOW:
        resampled = resampled[-WINDOW:]
    elif len(resampled) < WINDOW:
        idx = np.linspace(0, len(resampled) - 1, WINDOW)
        resampled = np.stack([np.interp(idx, np.arange(len(resampled)), resampled[:, c]) for c in range(3)], axis=1)

    os.makedirs(os.path.dirname(os.path.abspath(args.out)) or ".", exist_ok=True)
    with open(args.out + ".physical_f32.bin", "wb") as f:
        f.write(resampled.astype("<f4").tobytes())
    with open(args.out + ".baseline_f64.bin", "wb") as f:
        f.write(struct.pack("<3d", *baseline))

    duty_note = " (duty scaled from % to 0..1)" if duty_scaled else ""
    print(f"[mk] source rate ~{rate:.2f} Hz, window {len(win)} samples, "
          f"resampled to {TRAIN_RATE:.0f} Hz x {WINDOW}{duty_note}")
    print("[mk] baseline (past mean) = " + ", ".join(
        f"{name}={v:.4f}" for name, v in zip(["vout", "iout", "duty"], baseline)))
    print(f"[mk] wrote {args.out}.physical_f32.bin ({resampled.size * 4} B) and {args.out}.baseline_f64.bin")
    if rate < 32:
        print(f"[warn] source rate {rate:.1f} Hz is far below the training rate {TRAIN_RATE:.0f} Hz; "
              f"resampling is interpolation only -- pipeline check, not accuracy")
    return 0


if __name__ == "__main__":
    sys.exit(main())
