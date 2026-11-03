"""在一段板卡采样上滑动窗口跑三分类模型，输出类别时间线（PC 侧，不需要板子）。

为什么 PC 侧也能算：我用 numpy 复现了他们的 ONNX（Conv3x3+Relu+MaxPool），
并验证过它与他们 `features_u8` **逐位一致（46/46，0 码差）**，所以这里的结果
和板上 NPU 的差别只在 NPU 实现的舍入（他们实测 ≤2 码）。

用法:
  python scan_threeclass.py --csv logs/run1.csv --rate 128 --hop 1.0
"""

from __future__ import annotations

import argparse
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import onnx_min as om
from make_threeclass_input import read_csv, pick_columns
from threeclass_preprocess import preprocess

PKG = r"D:\deepseek\work\_incoming\dcdc_npu_threeclass_image_20261027_v2"
MODEL = os.path.join(PKG, "rootfs_overlay", "opt", "dcdc_npu_threeclass", "models", "condition_threeclass_uint8.onnx")
CLASSES = ["normal", "load_transient", "oscillation"]
WINDOW = 256
TRAIN_RATE = 128.0
S_IN, Z_IN = 0.04059445858001709, 163
BASELINE_MAX = 50000


def classify(m, physical_tc, baseline):
    norm = preprocess(physical_tc, baseline)                     # (3,256) float32
    u8 = np.clip(np.rint(norm / S_IN) + Z_IN, 0, 255).astype(np.uint8).reshape(1, 3, 16, 16)
    out = np.asarray(om.run_model(m, {"input": u8.astype(np.float64)})["logits"]).reshape(16, 8, 8)
    scores = out[:3].reshape(3, -1).max(axis=1).astype(float)
    return int(np.argmax(scores)), scores


def main(argv=None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv", required=True)
    ap.add_argument("--rate", type=float, default=128.0, help="CSV 采样率（Hz）")
    ap.add_argument("--hop", type=float, default=1.0, help="滑窗步长（秒）")
    ap.add_argument("--model", default=MODEL)
    args = ap.parse_args(argv)

    m = om.read_model(open(args.model, "rb").read())
    data, header = read_csv(args.csv)
    ti, vi, ii, di = pick_columns(data, header)
    t = data[:, ti]
    feat = np.stack([data[:, vi], data[:, ii], data[:, di]], axis=1)
    if np.nanmax(feat[:, 2]) > 1.5:
        feat[:, 2] /= 100.0

    span = WINDOW / TRAIN_RATE
    starts = np.arange(t[0] + span, t[-1] + 1e-9, args.hop)
    rows = []
    for t_end in starts:
        t_start = t_end - span
        sel = (t > t_start) & (t <= t_end)
        win = feat[sel]
        if len(win) < 8:
            continue
        idx = np.linspace(0, len(win) - 1, WINDOW) if len(win) != WINDOW else None
        if idx is not None:
            win = np.stack([np.interp(idx, np.arange(len(win)), win[:, c]) for c in range(3)], axis=1)
        past = feat[t <= t_start]
        if len(past) == 0:
            continue
        baseline = np.mean(past[-BASELINE_MAX:], axis=0)
        cls, scores = classify(m, win, baseline)
        rows.append((t_end, cls, scores))

    if not rows:
        print("[scan] no usable window (data too short?)")
        return 1

    print(f"[scan] {os.path.basename(args.csv)}: {len(rows)} windows, hop {args.hop}s, "
          f"model {os.path.basename(args.model)}")
    print("  t_end(s)  class             scores(u8)")
    for t_end, cls, sc in rows:
        print(f"  {t_end:7.2f}  {CLASSES[cls]:<16} {sc.astype(int).tolist()}")

    counts = np.bincount([r[1] for r in rows], minlength=3)
    print("[scan] counts: " + ", ".join(f"{CLASSES[i]} {counts[i]}" for i in range(3)))
    # 简单变化点
    changes = [(rows[i][0], CLASSES[rows[i - 1][1]], CLASSES[rows[i][1]])
               for i in range(1, len(rows)) if rows[i][1] != rows[i - 1][1]]
    if changes:
        print("[scan] switches: " + "; ".join(f"t={t:.2f}s {a}->{b}" for t, a, b in changes))
    return 0


if __name__ == "__main__":
    sys.exit(main())
