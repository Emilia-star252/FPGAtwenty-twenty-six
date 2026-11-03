"""探针 E：没有 ReLU 的纯卷积链（DQ→Conv→Q→DQ→Conv→Q），8 通道 / 4×4。

目的：验证「ALHardNPU 融合失败是因为 Conv→Relu→Q 里的 Relu 把量化边界截断了」这个假设。
若 E 能被 Alnpu 接受，就把分类模型改成线性（无激活）版本重训。
"""

import numpy as np

import onnx_min as om

C, H, W, H1, OUT = 8, 4, 4, 16, 4


def tq(name, scale, zp, dtype):
    return om.tensor(name, np.asarray([scale], np.float32)) if dtype == np.float32 else \
        om.tensor(name, np.asarray([zp], np.uint8))


def conv_block(inits, nodes, prev, name, cin, cout, out_prev_scale):
    k = 3
    Wt = np.random.default_rng(hash(name) % 1000).normal(0, 0.1, (cout, cin, k, k)).astype(np.float32)
    Wt[:, :, 1, 1] = np.random.default_rng(7).normal(0, 0.3, (cout, cin))   # 只让中心有效，接近 1x1
    b = np.zeros(cout, np.float32)
    wq = np.clip(np.rint(Wt / 0.02) + 128, 0, 255).astype(np.uint8)
    bq = np.rint(b / (0.02 * out_prev_scale)).astype(np.int32)
    inits += [om.tensor(f"{name}.w_q", wq), om.tensor(f"{name}.w_s", np.asarray([0.02], np.float32)),
              om.tensor(f"{name}.w_z", np.asarray([128], np.uint8)),
              om.tensor(f"{name}.b_q", bq), om.tensor(f"{name}.b_s", np.asarray([0.02 * out_prev_scale], np.float32)),
              om.tensor(f"{name}.b_z", np.asarray([0], np.int32)),
              om.tensor(f"{name}.o_s", np.asarray([0.02], np.float32)),
              om.tensor(f"{name}.o_z", np.asarray([128], np.uint8))]
    nodes += [
        om.node("DequantizeLinear", [f"{name}.w_q", f"{name}.w_s", f"{name}.w_z"], [f"{name}.w"], f"{name}.dw"),
        om.node("DequantizeLinear", [f"{name}.b_q", f"{name}.b_s", f"{name}.b_z"], [f"{name}.b"], f"{name}.db"),
        om.node("Conv", [prev, f"{name}.w", f"{name}.b"], [f"{name}.conv"], name,
                [om.attr_int("group", 1), om.attr_int("kernel_shape", k),
                 om.attr_ints("pads", [1, 1, 1, 1]), om.attr_ints("strides", [1, 1]),
                 om.attr_ints("dilations", [1, 1])]),
        om.node("QuantizeLinear", [f"{name}.conv", f"{name}.o_s", f"{name}.o_z"], [f"{name}.q"], f"{name}.q"),
    ]
    return f"{name}.q"


def build(path):
    inits, nodes = [], []
    inits += [om.tensor("in_s", np.asarray([1 / 255.0], np.float32)),
              om.tensor("in_z", np.asarray([0], np.uint8))]
    nodes += [om.node("QuantizeLinear", ["input", "in_s", "in_z"], ["in_q"], "in.q")]

    prev = "in_q"
    prev = conv_block(inits, nodes, prev, "c1", C, H1, 1 / 255.0)
    # 第二层直接吃上一层 uint8 输出，不再插 DQ
    prev = conv_block(inits, nodes, prev, "c2", H1, OUT, 0.02)

    model = om.make_model(
        nodes, inits,
        inputs=[om.value_info("input", [1, C, H, W])],
        outputs=[om.value_info(prev, [1, OUT, H, W], 2)],
        graph_name="probe_E",
    )
    open(path, "wb").write(model)
    print(f"[probe] E -> {path} ({len(model)} B)")


if __name__ == "__main__":
    build("out/probe_E.onnx")
