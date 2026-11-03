"""探针 D：把卷积换成 3x3（pad=1），看 armnn parser 的崩溃是不是和 1x1 kernel 有关。

背景：我们的 QDQ 图（1x1 conv）会让 parser 段错误；厂商模型是 3x3 conv 且能正常解析。
"""

import numpy as np

import onnx_min as om


def build(path):
    C, H, W, OUT = 3, 4, 4, 4
    Wt = np.random.default_rng(1).normal(0, 0.1, (OUT, C, 3, 3)).astype(np.float32)
    b = np.zeros(OUT, np.float32)
    wq = np.clip(np.rint(Wt / 0.02) + 128, 0, 255).astype(np.uint8)
    bq = np.rint(b / (0.02 / 255.0)).astype(np.int32)

    inits = [
        om.tensor("in_scale", np.asarray([1 / 255.0], np.float32)),
        om.tensor("in_zp", np.asarray([0], np.uint8)),
        om.tensor("w_q", wq),
        om.tensor("w_scale", np.asarray([0.02], np.float32)),
        om.tensor("w_zp", np.asarray([128], np.uint8)),
        om.tensor("b_q", bq),
        om.tensor("b_scale", np.asarray([0.02 / 255.0], np.float32)),
        om.tensor("b_zp", np.asarray([0], np.int32)),
    ]
    nodes = [
        om.node("QuantizeLinear", ["input", "in_scale", "in_zp"], ["in_q"], "in.q"),
        om.node("DequantizeLinear", ["in_q", "in_scale", "in_zp"], ["in_dq"], "in.dq"),
        om.node("DequantizeLinear", ["w_q", "w_scale", "w_zp"], ["w_dq"], "dq_w"),
        om.node("DequantizeLinear", ["b_q", "b_scale", "b_zp"], ["b_dq"], "dq_b"),
        om.node("Conv", ["in_dq", "w_dq", "b_dq"], ["conv"], "conv",
                [om.attr_int("group", 1), om.attr_int("kernel_shape", 3)]),
        om.node("Relu", ["conv"], ["relu"], "relu"),
        om.node("Softmax", ["relu"], ["probs"], "softmax", [om.attr_int("axis", 1)]),
    ]
    model = om.make_model(nodes, inits,
                          inputs=[om.value_info("input", [1, C, H, W])],
                          outputs=[om.value_info("probs", [1, OUT, H, W])],
                          graph_name="probe_D")
    with open(path, "wb") as f:
        f.write(model)
    print(f"[probe] D -> {path} ({len(model)} B)")


if __name__ == "__main__":
    build("out/probe_D.onnx")
