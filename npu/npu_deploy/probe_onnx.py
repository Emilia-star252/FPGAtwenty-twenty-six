"""生成 3 个探针模型，用来定位 armnn parser 在哪一步崩。

A: Conv(float 权重) + Relu + Softmax            —— 只有 Conv
B: 输入 QDQ + Conv(float 权重) + Relu + Softmax —— 输入量化
C: 完整 QDQ（输入、权重、bias、激活）但没有 Softmax —— 去掉 Softmax 看是不是它
"""

import numpy as np

import onnx_min as om

CONV = [om.attr_int("group", 1)]
H = 32
OUT = 4


def qdq(name, src, dtype, zp_dtype, scale, zp):
    q = om.node("QuantizeLinear", [src, f"{name}_scale", f"{name}_zp"], [f"{name}_q"], f"{name}.q")
    d = om.node("DequantizeLinear", [f"{name}_q", f"{name}_scale", f"{name}_zp"], [f"{name}_dq"], f"{name}.dq")
    inits = [om.tensor(f"{name}_scale", np.asarray([scale], np.float32)),
             om.tensor(f"{name}_zp", np.asarray([zp], dtype))]
    return q, d, inits


def build(variant, path):
    W = (np.random.default_rng(0).normal(0, 0.1, (OUT, 3, 1, 1))).astype(np.float32)
    b = np.zeros(OUT, np.float32)
    nodes, inits = [], []
    prev = "input"

    if variant in ("B", "C"):
        q, d, i = qdq("in", "input", np.uint8, np.uint8, 1.0 / 255, 0)
        nodes += [q, d]
        inits += i
        prev = "in_dq"

    if variant == "C":
        wq = np.clip(np.rint(W / 0.02) + 128, 0, 255).astype(np.uint8)
        bq = np.rint(b / (0.02 * (1 / 255.0))).astype(np.int32)
        inits += [om.tensor("w_q", wq), om.tensor("w_scale", np.asarray([0.02], np.float32)),
                  om.tensor("w_zp", np.asarray([128], np.uint8)),
                  om.tensor("b_q", bq), om.tensor("b_scale", np.asarray([0.02 / 255.0], np.float32)),
                  om.tensor("b_zp", np.asarray([0], np.int32))]
        nodes += [
            om.node("DequantizeLinear", ["w_q", "w_scale", "w_zp"], ["w_dq"], "dq_w"),
            om.node("DequantizeLinear", ["b_q", "b_scale", "b_zp"], ["b_dq"], "dq_b"),
            om.node("Conv", [prev, "w_dq", "b_dq"], ["conv"], "conv", CONV),
        ]
    else:
        inits += [om.tensor("w", W), om.tensor("b", b)]
        nodes += [om.node("Conv", [prev, "w", "b"], ["conv"], "conv", CONV)]

    nodes += [om.node("Relu", ["conv"], ["relu"], "relu")]
    out = "relu"
    if variant != "C":
        nodes += [om.node("Softmax", ["relu"], ["probs"], "softmax", [om.attr_int("axis", 1)])]
        out = "probs"

    model = om.make_model(nodes, inits,
                          inputs=[om.value_info("input", [1, 3, 1, 1])],
                          outputs=[om.value_info(out, [1, OUT, 1, 1])],
                          graph_name=f"probe_{variant}")
    with open(path, "wb") as f:
        f.write(model)
    print(f"[probe] {variant} -> {path} ({len(model)} B)")


if __name__ == "__main__":
    for v in ("A", "B", "C"):
        build(v, f"out/probe_{v}.onnx")
