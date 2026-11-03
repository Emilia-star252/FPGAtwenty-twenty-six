"""从测试集抽一批样本，生成板端自测 CSV（V,I,D,label）并附期望结果。

用法: python make_board_test.py --dataset out/dataset.csv --n 200 --out out/dcdc_board_test.csv
"""

import argparse
import csv
import os
import sys

import numpy as np

import train as tr


def main(argv=None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dataset", default=os.path.join("out", "dataset.csv"))
    ap.add_argument("--n", type=int, default=200)
    ap.add_argument("--out", default=os.path.join("out", "dcdc_board_test.csv"))
    ap.add_argument("--probs", default=os.path.join("out", "model.npz"),
                    help="用这个模型在 PC 侧算期望概率；传空字符串则跳过")
    ap.add_argument("--seed", type=int, default=99)
    args = ap.parse_args(argv)

    x, y, g = tr.load_dataset(args.dataset)
    _, _, (xs, ys) = tr.split_by_trial(x, y, g)
    rng = np.random.default_rng(args.seed)
    idx = rng.choice(len(ys), size=min(args.n, len(ys)), replace=False)

    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    with open(args.out, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["v_out", "i_out", "duty", "label"])
        for i in idx:
            w.writerow([f"{xs[i, 0]:.4f}", f"{xs[i, 1]:.5f}", f"{xs[i, 2]:.4f}", int(ys[i])])
    print(f"[board-test] {args.out}  {len(idx)} 行（含 label 列，给 --check 用）")
    counts = np.bincount(ys[idx], minlength=4)
    print("[board-test] 类别分布:", {tr.CLASS_NAMES[i]: int(c) for i, c in enumerate(counts)})

    # 同时导出 PC 侧概率，板上跑完用 compare_board_output.py 对拍（比只看类别更严格：
    # 归一化/通道顺序/量化错位都会在概率上立刻暴露出来）
    if args.probs:
        from export_onnx import INPUT_DIV, fold_standardization
        p = dict(np.load(args.probs, allow_pickle=True))
        W1, b1 = fold_standardization(p)
        u = xs[idx] / np.asarray(INPUT_DIV)[None, :]
        h = np.maximum(u @ W1.T + b1, 0.0)
        h = np.maximum(h @ p["W2"].T + p["b2"], 0.0)
        logits = h @ p["W3"].T + p["b3"]
        e = np.exp(logits - logits.max(axis=1, keepdims=True))
        probs = e / e.sum(axis=1, keepdims=True)
        exp_path = os.path.splitext(args.out)[0] + "_expected.csv"
        with open(exp_path, "w", newline="", encoding="utf-8") as f:
            w = csv.writer(f)
            w.writerow(["v_out", "i_out", "duty", "label", "p0", "p1", "p2", "p3"])
            for k, i in enumerate(idx):
                w.writerow([f"{xs[i, 0]:.4f}", f"{xs[i, 1]:.5f}", f"{xs[i, 2]:.4f}", int(ys[i])]
                           + [f"{v:.6f}" for v in probs[k]])
        print(f"[board-test] {exp_path}  含 PC 侧概率（对拍用）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
