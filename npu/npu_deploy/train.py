"""训练 DC-DC 工况分类小模型（纯 numpy，无需 torch/onnxruntime）。

网络: 3 -> 32 -> 16 -> 4 (ReLU)，输入是窗口均值的标准化值，输出 4 类 logits。
选择全连接而不是 CNN，是因为输入只有 3 个标量；部署时映射成一个极小的
MatMul 图（ONNX Gemm），便于 armnn / Alnpu 后端解析。

用法:
    python train.py --csv out/dataset.csv --out out/model.npz --epochs 600
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import sys

import numpy as np

FEATURES = ["v_mean", "i_mean", "d_mean"]
CLASS_NAMES = ["正常-轻载", "正常-额定", "重载-近限流", "保护故障"]
N_CLASSES = 4


# ------------------------------------------------------------------ 数据
def load_dataset(path: str):
    xs, ys, groups = [], [], []
    with open(path, newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            xs.append([float(row[k]) for k in FEATURES])
            ys.append(int(row["label"]))
            groups.append(int(row["trial_id"]))
    return np.asarray(xs, dtype=np.float64), np.asarray(ys, dtype=np.int64), np.asarray(groups)


def split_by_trial(x, y, g, val_frac=0.15, test_frac=0.15, seed=1234):
    """按试验号分组划分：同一次试验的样本只出现在一个集合里，避免泄漏。"""
    rng = np.random.default_rng(seed)
    ids = np.unique(g)
    rng.shuffle(ids)
    n = len(ids)
    n_test = max(1, int(round(n * test_frac)))
    n_val = max(1, int(round(n * val_frac)))
    test_ids, val_ids = set(ids[:n_test]), set(ids[n_test:n_test + n_val])
    mask_t = np.isin(g, list(test_ids))
    mask_v = np.isin(g, list(val_ids))
    mask_tr = ~(mask_t | mask_v)
    return ((x[mask_tr], y[mask_tr]), (x[mask_v], y[mask_v]), (x[mask_t], y[mask_t]))


# ------------------------------------------------------------------ 网络
def init_params(n_in: int, hidden=(32, 16), n_out=N_CLASSES, seed=0):
    rng = np.random.default_rng(seed)
    shapes = [n_in, *hidden, n_out]
    p = {}
    for i in range(len(shapes) - 1):
        fan_in = shapes[i]
        p[f"W{i + 1}"] = rng.normal(0, np.sqrt(2.0 / fan_in), (shapes[i + 1], shapes[i]))
        p[f"b{i + 1}"] = np.zeros(shapes[i + 1])
    return p


def forward(p, x, act=True):
    """返回 logits 和缓存（用于反向）。"""
    a = x
    cache = []
    n_layers = len(p) // 2
    for i in range(1, n_layers + 1):
        z = a @ p[f"W{i}"].T + p[f"b{i}"]
        cache.append((a, z))
        a = (np.maximum(z, 0.0) if act else z) if i < n_layers else z
    return a, cache


def softmax(z):
    z = z - z.max(axis=1, keepdims=True)
    e = np.exp(z)
    return e / e.sum(axis=1, keepdims=True)


def loss_and_grad(p, x, y, act=True):
    logits, cache = forward(p, x, act)
    probs = softmax(logits)
    n = len(y)
    eps = 1e-9
    loss = -np.log(probs[np.arange(n), y] + eps).mean()
    grad = probs.copy()
    grad[np.arange(n), y] -= 1.0
    grad /= n

    n_layers = len(p) // 2
    g = {}
    for i in range(n_layers, 0, -1):
        a_in, _z_i = cache[i - 1]
        g[f"W{i}"] = grad.T @ a_in
        g[f"b{i}"] = grad.sum(axis=0)
        if i > 1:
            grad = grad @ p[f"W{i}"]          # dL/da_{i-1}
            z_prev = cache[i - 2][1]          # 第 i-1 层的预激活
            if act:
                grad = grad * (z_prev > 0.0)  # dL/dz_{i-1}
    return loss, g


def train(x, y, x_val, y_val, epochs=600, lr=3e-3, l2=1e-5, seed=0, verbose=True, act=True):
    p = init_params(x.shape[1], seed=seed)
    m = {k: np.zeros_like(v) for k, v in p.items()}
    v2 = {k: np.zeros_like(v) for k, v in p.items()}
    b1, b2, eps = 0.9, 0.999, 1e-8
    best = (float("inf"), {k: v.copy() for k, v in p.items()}, 0)
    rng = np.random.default_rng(seed + 1)
    for ep in range(1, epochs + 1):
        idx = rng.permutation(len(x))
        for start in range(0, len(x), 64):
            batch = idx[start:start + 64]
            _, g = loss_and_grad(p, x[batch], y[batch], act)
            for k in p:
                if k.startswith("W"):
                    g[k] = g[k] + l2 * p[k]
                m[k] = b1 * m[k] + (1 - b1) * g[k]
                v2[k] = b2 * v2[k] + (1 - b2) * g[k] ** 2
                mhat = m[k] / (1 - b1 ** ep)
                vhat = v2[k] / (1 - b2 ** ep)
                p[k] = p[k] - lr * mhat / (np.sqrt(vhat) + eps)
        if x_val is not None and ep % 10 == 0:
            vl = -np.log(softmax(forward(p, x_val, act)[0])[np.arange(len(y_val)), y_val] + 1e-9).mean()
            if vl < best[0]:
                best = (vl, {k: v.copy() for k, v in p.items()}, ep)
            if verbose and ep % 100 == 0:
                tr = -np.log(softmax(forward(p, x, act)[0])[np.arange(len(y)), y] + 1e-9).mean()
                print(f"  epoch {ep:4d}  train_loss={tr:.4f}  val_loss={vl:.4f}  best_ep={best[2]}")
    return (best[1] if x_val is not None else p), best[2]


# ------------------------------------------------------------------ 评估
def evaluate(p, x, y):
    probs = softmax(forward(p, x)[0])
    pred = probs.argmax(axis=1)
    acc = float((pred == y).mean())
    cm = np.zeros((N_CLASSES, N_CLASSES), dtype=np.int64)
    for t, q in zip(y, pred):
        cm[t, q] += 1
    per_class = []
    for c in range(N_CLASSES):
        tp = cm[c, c]
        fp = cm[:, c].sum() - tp
        fn = cm[c, :].sum() - tp
        prec = tp / (tp + fp) if tp + fp else 0.0
        rec = tp / (tp + fn) if tp + fn else 0.0
        f1 = 2 * prec * rec / (prec + rec) if prec + rec else 0.0
        per_class.append({"class": c, "name": CLASS_NAMES[c], "support": int(cm[c, :].sum()),
                          "precision": round(float(prec), 4), "recall": round(float(rec), 4),
                          "f1": round(float(f1), 4)})
    return acc, cm, per_class


def rule_baseline(x_raw, y):
    """只用 I 阈值的规则（非故障类）；故障类用 V<1V 且 I<0.05A 判断。"""
    i = x_raw[:, 1]
    v = x_raw[:, 0]
    pred = np.where(i > 0.9 * 2.0, 2, np.where(i > 0.35 * 2.0, 1, 0))
    pred = np.where((v < 1.0) & (i < 0.05), 3, pred)
    return float((pred == y).mean())


def save_confusion_png(cm, path):
    try:
        from PIL import Image, ImageDraw
    except Exception:
        return False
    labels = ["light", "rated", "heavy", "fault"]
    cell = 90
    margin = 70
    w = margin + cell * N_CLASSES + 20
    img = Image.new("RGB", (w, w), "white")
    d = ImageDraw.Draw(img)
    mx = max(1, int(cm.max()))
    for r in range(N_CLASSES):
        for c in range(N_CLASSES):
            v = int(cm[r, c])
            shade = int(255 - 200 * v / mx)
            x0, y0 = margin + c * cell, margin + r * cell
            d.rectangle([x0, y0, x0 + cell - 2, y0 + cell - 2], fill=(shade, shade, 255))
            d.text((x0 + cell // 3, y0 + cell // 3), str(v), fill="black")
    for r in range(N_CLASSES):
        d.text((6, margin + r * cell + cell // 3), labels[r], fill="black")
        d.text((margin + r * cell + 6, 6), labels[r], fill="black")
    img.save(path)
    return True


def main(argv=None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv", default=os.path.join("out", "dataset.csv"))
    ap.add_argument("--out", default=os.path.join("out", "model.npz"))
    ap.add_argument("--epochs", type=int, default=600)
    ap.add_argument("--lr", type=float, default=3e-3)
    ap.add_argument("--seed", type=int, default=0)
    ap.add_argument("--no-activation", action="store_true",
                    help="训练线性模型（去掉 ReLU），便于让 Alnpu 融合时量化边界不断开")
    ap.add_argument("--min-per-class", type=int, default=20,
                    help="每个类别少于这个数量就告警（真实数据重训时用）")
    args = ap.parse_args(argv)

    x_raw, y, g = load_dataset(args.csv)
    (xt, yt), (xv, yv), (xs, ys) = split_by_trial(x_raw, y, g)
    print(f"[data] train={len(yt)} val={len(yv)} test={len(ys)}  特征={FEATURES}")

    # 真实数据重训时最容易踩的坑：某些类根本没采到 / 太少。这里明确告警，
    # 不然「某类 support=0、准确率 100%」会被误读成模型好用。
    counts = np.bincount(y, minlength=N_CLASSES)
    print("[data] 类别分布: " + ", ".join(f"{CLASS_NAMES[i]}={int(c)}" for i, c in enumerate(counts)))
    missing = [CLASS_NAMES[i] for i, c in enumerate(counts) if c == 0]
    thin = [f"{CLASS_NAMES[i]}({int(c)})" for i, c in enumerate(counts) if 0 < c < args.min_per_class]
    if missing:
        print(f"[warn] 缺少这些类别: {', '.join(missing)} —— 模型永远不会输出它们，"
              f"这批数据只能验证流程，不能当正式模型")
    if thin:
        print(f"[warn] 样本过少的类别: {', '.join(thin)}（< {args.min_per_class}），该类指标不可信")
    if len(np.unique(g)) < 4:
        print(f"[warn] 只有 {len(np.unique(g))} 个试验组，分组划分的意义有限")

    mu = xt.mean(axis=0)
    sd = xt.std(axis=0) + 1e-9
    nz = lambda a: (a - mu) / sd

    print("[train] MLP 3-32-16-4, Adam")
    act = not args.no_activation
    p, best_ep = train(nz(xt), yt, nz(xv), yv, epochs=args.epochs, lr=args.lr, seed=args.seed, act=act)

    acc_val, cm_val, _ = evaluate(p, nz(xv), yv)
    acc_test, cm_test, per_class = evaluate(p, nz(xs), ys)
    acc_tr, _, _ = evaluate(p, nz(xt), yt)
    print(f"[eval] train={acc_tr * 100:.2f}%  val={acc_val * 100:.2f}%  test={acc_test * 100:.2f}%  (best_ep={best_ep})")
    print("[eval] 混淆矩阵（行=真值, 列=预测）:")
    for r in range(N_CLASSES):
        print("   ", " ".join(f"{int(v):4d}" for v in cm_test[r]))
    print("[eval] 各类:")
    for pc in per_class:
        print(f"    {pc['name']:<10} support={pc['support']:4d} P={pc['precision']:.3f} R={pc['recall']:.3f} F1={pc['f1']:.3f}")

    rb = rule_baseline(xs, ys)
    print(f"[baseline] I/V 阈值规则 test acc = {rb * 100:.2f}%  (合成数据可分性参考)")

    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    np.savez(args.out, **{k: v for k, v in p.items()},
             x_mean=mu, x_std=sd, features=np.array(FEATURES), classes=np.array(CLASS_NAMES))
    print(f"[save] {args.out}")

    meta = {
        "features": FEATURES, "classes": CLASS_NAMES,
        "acc": {"train": acc_tr, "val": acc_val, "test": acc_test},
        "rule_baseline_test": rb,
        "confusion_test": cm_test.tolist(),
        "per_class": per_class,
        "class_counts": [int(c) for c in counts],
        "missing_classes": missing,
        "n": {"train": int(len(yt)), "val": int(len(yv)), "test": int(len(ys))},
        "epochs": args.epochs, "best_epoch": int(best_ep), "activation": bool(act),
        "csv": os.path.abspath(args.csv),
    }
    with open(os.path.splitext(args.out)[0] + "_metrics.json", "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False, indent=2)
    save_confusion_png(cm_test, os.path.splitext(args.out)[0] + "_confusion.png")
    return 0


if __name__ == "__main__":
    sys.exit(main())
