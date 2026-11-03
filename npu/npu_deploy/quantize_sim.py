"""量化仿真：把训练好的 float 模型按「权重 int8 + 激活 uint8」量化后再推理，看精度损失。

为什么需要这一步
----------------
官方 Alnpu 后端的两个现成模型（yolo_face_uint8_15.onnx、fire_detect_sim_quant_uint8.onnx）
都是 **QDQ 结构**：输入是 uint8 值域的 float 张量，紧跟 QuantizeLinear；卷积权重是 uint8。
也就是说硬 NPU 大概率只吃量化图。先用 numpy 把量化误差算出来，再决定要不要走这条路，
避免在板上反复试错。

量化方案（每张量、对称/零点 0，与 QDQ 的纯 scale 形式一致）
    input : u 已归一化到 0..1，scale = 1/255
    weight: s = max|W| / 127，int8
    act   : s = 校准集上的 max / 255，uint8
"""

from __future__ import annotations

import argparse
import json
import os
import sys

import numpy as np

import train as tr
from export_onnx import INPUT_DIV, fold_standardization


def q_sym(w, bits=8):
    """对称量化：返回 (量化值, scale)。"""
    qmax = 2 ** (bits - 1) - 1
    s = float(np.abs(w).max()) / qmax if np.abs(w).max() > 0 else 1.0
    return np.round(w / s).clip(-qmax, qmax), s


def q_uint(x, s):
    return np.clip(np.round(x / s), 0, 255)


def forward_quant(p, u, calib=None):
    """u: [N,3] 已归一化。calib 为 None 时用 u 自身的 max 当激活 scale（校准）。"""
    W1, b1 = fold_standardization(p)
    W2, b2 = p["W2"].astype(np.float64), p["b2"].astype(np.float64)
    W3, b3 = p["W3"].astype(np.float64), p["b3"].astype(np.float64)

    s_in = 1.0 / 255.0
    uq = q_uint(u, s_in) * s_in

    W1q, s1 = q_sym(W1)
    h1 = np.maximum(uq @ (W1q * s1).T + b1, 0.0)
    ref = calib["a1"] if calib else h1.max(axis=0, keepdims=True)
    s_a1 = np.maximum(ref, 1e-6) / 255.0
    h1q = q_uint(h1, s_a1) * s_a1

    W2q, s2 = q_sym(W2)
    h2 = np.maximum(h1q @ (W2q * s2).T + b2, 0.0)
    ref = calib["a2"] if calib else h2.max(axis=0, keepdims=True)
    s_a2 = np.maximum(ref, 1e-6) / 255.0
    h2q = q_uint(h2, s_a2) * s_a2

    W3q, s3 = q_sym(W3)
    logits = h2q @ (W3q * s3).T + b3
    logits = logits - logits.max(axis=1, keepdims=True)
    e = np.exp(logits)
    probs = e / e.sum(axis=1, keepdims=True)

    scales = {"input": s_in, "w1": s1, "a1": s_a1.tolist(), "w2": s2,
              "a2": s_a2.tolist(), "w3": s3}
    return probs, scales


def main(argv=None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", default=os.path.join("out", "model.npz"))
    ap.add_argument("--csv", default=os.path.join("out", "dataset.csv"))
    ap.add_argument("--out", default=os.path.join("out", "quant_report.json"))
    args = ap.parse_args(argv)

    p = dict(np.load(args.model, allow_pickle=True))
    x_raw, y, g = tr.load_dataset(args.csv)
    (xt, yt), (xv, yv), (xs, ys) = tr.split_by_trial(x_raw, y, g)
    div = np.asarray(INPUT_DIV)[None, :]
    ut, us = xt / div, xs / div

    # 用训练集做校准（取每层激活在训练集上的最大值）
    probs_t, _ = forward_quant(p, ut)
    W1, b1 = fold_standardization(p)
    h1 = np.maximum(ut @ W1.T + b1, 0.0)
    calib = {"a1": h1.max(axis=0, keepdims=True)}
    h1q = np.round(h1 * 255.0 / np.maximum(calib["a1"], 1e-6)) * (calib["a1"] / 255.0)
    h2 = np.maximum(h1q @ p["W2"].T + p["b2"], 0.0)
    calib["a2"] = h2.max(axis=0, keepdims=True)

    probs_q, scales = forward_quant(p, us, calib)

    # float 参考
    z1 = np.maximum(us @ W1.T + b1, 0.0)
    z2 = np.maximum(z1 @ p["W2"].T + p["b2"], 0.0)
    logits = z2 @ p["W3"].T + p["b3"]
    logits -= logits.max(axis=1, keepdims=True)
    e = np.exp(logits)
    probs_f = e / e.sum(axis=1, keepdims=True)

    acc_f = float((probs_f.argmax(1) == ys).mean())
    acc_q = float((probs_q.argmax(1) == ys).mean())
    flip = int((probs_f.argmax(1) != probs_q.argmax(1)).sum())
    max_dev = float(np.abs(probs_f - probs_q).max())

    n_params = sum(p[k].size for k in ("W1", "b1", "W2", "b2", "W3", "b3"))
    w_params = sum(p[k].size for k in ("W1", "W2", "W3"))

    print(f"[quant] float test acc = {acc_f * 100:.2f}%")
    print(f"[quant] int8/uint8 仿真 acc = {acc_q * 100:.2f}%   预测翻转 {flip}/{len(ys)}   最大概率偏差 {max_dev:.4f}")
    print(f"[quant] 参数量 {n_params}（权重 {w_params}）：float32 = {n_params * 4} B，int8 权重 = {w_params} B")
    print("[quant] 每张量 scale：input=%.6f  w1=%.3e  w2=%.3e  w3=%.3e"
          % (scales["input"], scales["w1"], scales["w2"], scales["w3"]))

    rep = {
        "acc_float": acc_f, "acc_quant": acc_q, "flipped": flip, "n_test": int(len(ys)),
        "max_prob_dev": max_dev, "params": n_params, "weight_params": w_params,
        "bytes_float32": n_params * 4, "bytes_int8_weights": w_params,
        "scales": {k: (v if not isinstance(v, list) else v) for k, v in scales.items()},
        "calib_a1_max": calib["a1"].ravel().tolist(),
        "calib_a2_max": calib["a2"].ravel().tolist(),
    }
    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(rep, f, ensure_ascii=False, indent=2)
    print(f"[quant] 写出 {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
