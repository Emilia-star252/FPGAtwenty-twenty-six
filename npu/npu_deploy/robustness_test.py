"""鲁棒性冒烟测试：训练好的模型在「传感器有误差」时还准不准。

做法很直接：不动模型，只改喂进去的三个量（这等价于板上的增益误差/零点漂移/量化变粗），
看准确率怎么掉、哪一类先崩。用的是仿真测试集，所以结论只能说明「敏感度量级」，
不能替代真实板上的标定实验。

用法: python robustness_test.py --model out/model.npz --csv out/dataset.csv
"""

from __future__ import annotations

import argparse
import json
import os
import sys

import numpy as np

import train as tr
from export_onnx import INPUT_DIV, fold_standardization

CASES = [
    ("基线（无误差）", lambda x: x),
    ("电压增益 +2%", lambda x: x * np.array([1.02, 1.0, 1.0])),
    ("电压增益 -2%", lambda x: x * np.array([0.98, 1.0, 1.0])),
    ("电流增益 +2%", lambda x: x * np.array([1.0, 1.02, 1.0])),
    ("电流增益 -2%", lambda x: x * np.array([1.0, 0.98, 1.0])),
    ("电流增益 +5%", lambda x: x * np.array([1.0, 1.05, 1.0])),
    ("电流零点 +20mA", lambda x: x + np.array([0.0, 0.02, 0.0])),
    ("占空比增益 +2%", lambda x: x * np.array([1.0, 1.0, 1.02])),
    ("全通道 +5%", lambda x: x * 1.05),
    ("量化变粗（V 0.1V / I 10mA / D 1%）",
     lambda x: np.stack([np.round(x[:, 0] / 0.1) * 0.1,
                         np.round(x[:, 1] / 0.01) * 0.01,
                         np.round(x[:, 2] / 1.0) * 1.0], axis=1)),
    ("测量噪声 σ=2%", None),      # 随机，单独处理
    ("测量噪声 σ=5%", None),
]


def forward(p, raw):
    W1, b1 = fold_standardization(p)
    u = raw / np.asarray(INPUT_DIV)[None, :]
    h = np.maximum(u @ W1.T + b1, 0.0)
    h = np.maximum(h @ p["W2"].T + p["b2"], 0.0)
    return h @ p["W3"].T + p["b3"]


def main(argv=None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", default=os.path.join("out", "model.npz"))
    ap.add_argument("--csv", default=os.path.join("out", "dataset.csv"))
    ap.add_argument("--out", default=os.path.join("out", "robustness.json"))
    ap.add_argument("--seed", type=int, default=7)
    args = ap.parse_args(argv)

    p = dict(np.load(args.model, allow_pickle=True))
    x_raw, y, g = tr.load_dataset(args.csv)
    _, _, (xs, ys) = tr.split_by_trial(x_raw, y, g)
    base_pred = forward(p, xs).argmax(1)
    base_acc = float((base_pred == ys).mean())
    rng = np.random.default_rng(args.seed)

    print(f"[robust] 测试集 {len(ys)} 条，基线准确率 {base_acc * 100:.2f}%")
    print(f"{'场景':<34}{'准确率':>8}{'相对基线':>10}{'与基线预测一致':>14}")
    rows = []
    for name, fn in CASES:
        if fn is None:
            sigma = 0.02 if "2%" in name else 0.05
            xp = xs * (1.0 + rng.normal(0.0, sigma, xs.shape))
        else:
            xp = fn(xs)
        pred = forward(p, xp).argmax(1)
        acc = float((pred == ys).mean())
        same = float((pred == base_pred).mean())
        rows.append({"case": name, "acc": acc, "delta": acc - base_acc, "same_as_base": same,
                     "per_class": [int(((ys == c) & (pred == c)).sum()) for c in range(4)],
                     "support": [int((ys == c).sum()) for c in range(4)]})
        print(f"{name:<34}{acc * 100:7.2f}%{(acc - base_acc) * 100:+9.2f}pp{same * 100:13.2f}%")

    worst = min(rows, key=lambda r: r["acc"])
    print(f"\n[robust] 最差场景: {worst['case']}（{worst['acc'] * 100:.2f}%，"
          f"{(worst['acc'] - base_acc) * 100:+.2f}pp）")
    for r in rows:
        if r["delta"] < -0.01:
            drops = [(tr.CLASS_NAMES[c], r["per_class"][c], r["support"][c])
                     for c in range(4) if r["per_class"][c] < r["support"][c] * 0.98]
            if drops:
                print(f"  {r['case']}: " + "，".join(f"{n} {ok}/{tot}" for n, ok, tot in drops))

    with open(args.out, "w", encoding="utf-8") as f:
        json.dump({"baseline_acc": base_acc, "cases": rows}, f, ensure_ascii=False, indent=2)
    print(f"[robust] 写出 {args.out}")
    print("[robust] 注意：这是仿真数据上的敏感度，不是真实标定误差下的保证；"
          "真实板子要按同样的场景做一次实测。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
