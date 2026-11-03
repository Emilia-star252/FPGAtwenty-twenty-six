"""把 model.npz 导出成板端可用的产物：

1. out/dcdc_npu.onnx          —— armnnOnnxParser 直接吃（Gemm/Relu/Softmax，opset 13）
2. out/dcdc_npu_weights.h     —— 不走 ONNX 时的备选：C 数组，可在 C++ 里用 armnn API 直接搭层
3. out/dcdc_npu_model.json    —— 归一化参数、类别名、输入顺序，给板上程序和文档用

标准化（x-mu)/sd 已经折进第一层 Gemm 的权重里，所以板上程序直接喂原始
Vout(V) / Iout(A) / duty(%)，不需要在上位机或板端再做归一化。
"""

from __future__ import annotations

import argparse
import json
import os
import sys

import numpy as np

import onnx_min as om

CLASS_NAMES = ["正常-轻载", "正常-额定", "重载-近限流", "保护故障"]

# 输入归一化的固定除数：Vout/48, Iout/2.2, duty/95 -> 0..1
# 折进第一层后，模型输入就是一个 0..1 的 3 维向量，正好适合 uint8 量化（scale=1/255）
INPUT_DIV = [48.0, 2.2, 95.0]
INPUT_DIV_NOTE = "板上喂 u = [Vout/48, Iout/2.2, duty/95]，均在 0..1"


def fold_standardization(p):
    """把 (x-mu)/sd 和固定除数一起折进第一层：u = raw/div，z1 = W1'u + b1'。"""
    W1 = p["W1"].astype(np.float64)
    b1 = p["b1"].astype(np.float64)
    mu = p["x_mean"].astype(np.float64)
    sd = p["x_std"].astype(np.float64)
    div = np.asarray(INPUT_DIV, dtype=np.float64)
    W1f = W1 * (div / sd)[None, :]
    b1f = b1 - (W1 / sd[None, :]) @ mu
    return W1f, b1f


def build_onnx(p) -> bytes:
    W1, b1 = fold_standardization(p)
    W2, b2 = p["W2"].astype(np.float64), p["b2"].astype(np.float64)
    W3, b3 = p["W3"].astype(np.float64), p["b3"].astype(np.float64)

    inits = [
        om.tensor("fc1.weight", W1), om.tensor("fc1.bias", b1),
        om.tensor("fc2.weight", W2), om.tensor("fc2.bias", b2),
        om.tensor("fc3.weight", W3), om.tensor("fc3.bias", b3),
    ]
    gemm_attrs = [om.attr_float("alpha", 1.0), om.attr_float("beta", 1.0),
                  om.attr_int("transA", 0), om.attr_int("transB", 1)]
    nodes = [
        om.node("Gemm", ["input", "fc1.weight", "fc1.bias"], ["fc1"], "fc1", gemm_attrs),
        om.node("Relu", ["fc1"], ["relu1"], "relu1"),
        om.node("Gemm", ["relu1", "fc2.weight", "fc2.bias"], ["fc2"], "fc2", gemm_attrs),
        om.node("Relu", ["fc2"], ["relu2"], "relu2"),
        om.node("Gemm", ["relu2", "fc3.weight", "fc3.bias"], ["logits"], "fc3", gemm_attrs),
        om.node("Softmax", ["logits"], ["probs"], "softmax", [om.attr_int("axis", 1)]),
    ]
    return om.make_model(
        nodes, inits,
        inputs=[om.value_info("input", [1, 3])],
        outputs=[om.value_info("probs", [1, 4])],
    )


def write_header(path: str, W1, b1, W2, b2, W3, b3, meta: dict):
    def arr(name, a, fmt="{:+.8e}f"):
        flat = np.asarray(a, dtype=np.float64).ravel()
        body = ", ".join(fmt.format(x) for x in flat)
        return f"static const float {name}[{flat.size}] = {{{body}}};\n\n"

    lines = [
        f"/* 由 export_onnx.py 自动生成，勿手改。",
        " * 输入: u = {Vout/48, Iout/2.2, duty/95}（0..1）；输出: 4 类概率（softmax）。",
        " * 归一化与除数已折进第 1 层权重。",
        " */",
        "#ifndef DCDC_NPU_WEIGHTS_H",
        "#define DCDC_NPU_WEIGHTS_H",
        "",
        f"#define DCDC_IN {W1.shape[1]}",
        f"#define DCDC_H1 {W1.shape[0]}",
        f"#define DCDC_H2 {W2.shape[0]}",
        f"#define DCDC_OUT {W3.shape[0]}",
        "",
        arr("DCDC_W1", W1), arr("DCDC_B1", b1),
        arr("DCDC_W2", W2), arr("DCDC_B2", b2),
        arr("DCDC_W3", W3), arr("DCDC_B3", b3),
        f'static const char *DCDC_CLASSES[{len(meta["classes"])}] = {{'
        + ", ".join('"%s"' % c for c in meta["classes"]) + "};",
        "",
        "#endif",
        "",
    ]
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))


def main(argv=None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", default=os.path.join("out", "model.npz"))
    ap.add_argument("--outdir", default="out")
    ap.add_argument("--name", default="dcdc_npu")
    args = ap.parse_args(argv)

    p = dict(np.load(args.model, allow_pickle=True))
    os.makedirs(args.outdir, exist_ok=True)

    onnx_bytes = build_onnx(p)
    onnx_path = os.path.join(args.outdir, args.name + ".onnx")
    with open(onnx_path, "wb") as f:
        f.write(onnx_bytes)

    # --- 读回来，用最小执行器跑一遍，和 numpy 前向对拍 ---
    m = om.read_model(onnx_bytes)
    W1, b1 = fold_standardization(p)

    rng = np.random.default_rng(0)
    raw = np.column_stack([
        rng.uniform(0.0, 48.0, 256),     # V
        rng.uniform(0.0, 2.2, 256),      # I
        rng.uniform(0.0, 95.0, 256),     # duty %
    ])
    u = raw / np.asarray(INPUT_DIV)[None, :]
    outs = om.run_model(m, {"input": u})
    probs_onnx = outs["probs"]

    # numpy 参考实现（与 train.py 的 forward 等价，输入 u = raw/div）
    z1 = np.maximum(u @ W1.T + b1, 0.0)
    z2 = np.maximum(z1 @ p["W2"].T + p["b2"], 0.0)
    logits = z2 @ p["W3"].T + p["b3"]
    logits = logits - logits.max(axis=1, keepdims=True)
    e = np.exp(logits)
    probs_ref = e / e.sum(axis=1, keepdims=True)

    diff = float(np.abs(probs_onnx - probs_ref).max())
    print(f"[onnx] 写出 {onnx_path}  ({len(onnx_bytes)} B)")
    print(f"[onnx] 结构: opset={m['opset']} inputs={m['inputs']} outputs={m['outputs']} "
          f"nodes={[n['op'] for n in m['nodes']]}")
    print(f"[onnx] 初始张量: " + ", ".join(f"{k}{tuple(v.shape)}" for k, v in m["initializers"].items()))
    print(f"[onnx] 与 numpy 参考的最大概率偏差 = {diff:.3e}")
    if diff > 1e-5:
        print("[onnx] 数值对拍失败", file=sys.stderr)
        return 1

    meta = {
        "name": args.name,
        "input": {"order": ["v_out_V", "i_out_A", "duty_pct"], "shape": [1, 3],
                  "divisors": INPUT_DIV, "note": INPUT_DIV_NOTE},
        "output": {"classes": CLASS_NAMES, "shape": [1, 4], "activation": "softmax"},
        "hidden": [int(p["W1"].shape[0]), int(p["W2"].shape[0])],
        "weights_header": args.name + "_weights.h",
        "onnx": args.name + ".onnx",
        "note": "标准化 + 除数已折进 fc1；板上先做 u=raw/div 再喂模型",
    }
    with open(os.path.join(args.outdir, args.name + "_model.json"), "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False, indent=2)

    write_header(os.path.join(args.outdir, args.name + "_weights.h"),
                 W1, b1, p["W2"], p["b2"], p["W3"], p["b3"], {"classes": CLASS_NAMES})
    print(f"[onnx] 写出 C 权重头 {os.path.join(args.outdir, args.name + '_weights.h')}")

    # 抽查几个物理上有意义的点
    cases = [
        ("轻载 12V/0.5A", [12.0, 0.5, 50.0]),
        ("额定 24V/1.5A", [24.0, 1.5, 50.0]),
        ("恒流 2V/2.0A", [2.0, 2.0, 45.0]),
        ("停机 0V/0A", [0.0, 0.0, 0.0]),
    ]
    print("[onnx] 抽查:")
    for name, x in cases:
        uu = np.asarray([x], dtype=np.float64) / np.asarray(INPUT_DIV)[None, :]
        pr = om.run_model(m, {"input": uu})["probs"][0]
        k = int(np.argmax(pr))
        print(f"    {name:<16} -> {CLASS_NAMES[k]}  probs={np.round(pr, 4).tolist()}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
