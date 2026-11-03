"""导出「QDQ + 1x1 Conv」版本 ONNX —— 目标是让 Alnpu 后端能接。

为什么另出一版
--------------
官方 SDK 里两个现成模型（yolo_face_uint8_15 / fire_detect_sim_quant_uint8）结构是：
    输入 float32 [1,3,H,W]（值域 0..255）
    → QuantizeLinear(uint8, scale=1/255, zp=0) → DequantizeLinear
    → Conv(权重 uint8 + DequantizeLinear, bias int32 + DequantizeLinear)
也就是说硬 NPU 走的是 QDQ + Conv 这条路。我们原来的 float32 `Gemm` 图大概率不进 NPU。

所以这里把同一个 MLP 等价改写成 1x1 卷积（数学完全等价：Conv1x1 = 全连接），
并按官方模型的写法加 QDQ：输入量化、每层权重量化、每层激活量化、bias 用 int32。

量化方案（与 quantize_sim.py 的结论一致：精度损失可忽略）
    input : u∈[0,1]，scale = 1/255, zp = 0
    weight: uint8 非对称，scale=(max-min)/255, zp=round(-min/scale)
    bias  : int32，scale = s_input * s_weight, zp = 0
    act   : uint8 非对称，scale = (校准 max)/255（ReLU 后 min=0 → zp=0）
"""

from __future__ import annotations

import argparse
import json
import os
import sys

import numpy as np

import onnx_min as om
import train as tr
from export_onnx import CLASS_NAMES, INPUT_DIV, fold_standardization

def conv_attrs(kernel):
    """1x1 时只写 group（与官方模型一致）；3x3 时补 pads/kernel_shape。"""
    if kernel == 3:
        return [om.attr_int("group", 1), om.attr_int("kernel_shape", 3),
                om.attr_ints("pads", [1, 1, 1, 1]),
                om.attr_ints("strides", [1, 1]),
                om.attr_ints("dilations", [1, 1])]
    return [om.attr_int("group", 1)]


CONV_ATTRS = conv_attrs(1)     # 兼容旧代码路径

# build() 里算好的量化数组，留给 write_header() 用（ONNX 那条路不需要，手工搭网络需要）
LAST_LAYERS = []
LAST_META = {}


def asym_uint8(a):
    """非对称 uint8 量化，返回 (q, scale, zp)。"""
    lo, hi = float(a.min()), float(a.max())
    if hi - lo < 1e-9:
        hi = lo + 1e-6
    s = np.float32((hi - lo) / 255.0)
    zp = int(round(-lo / float(s)))
    zp = max(0, min(255, zp))
    q = np.clip(np.rint(a / float(s)) + zp, 0, 255).astype(np.uint8)
    return q, s, np.uint8(zp)


def doconv(x, w, b):
    """1x1 卷积（在 [N,C,1,1] 上就是矩阵乘）。"""
    n = x.shape[0]
    y = x.reshape(n, -1) @ w.reshape(w.shape[0], -1).T
    if b is not None:
        y = y + np.asarray(b).reshape(1, -1)
    return y.reshape(n, w.shape[0], 1, 1)


def fold_weights(p, pad_c=3):
    """第一层权重（含标准化/除数折叠 + 可选的通道补零）。"""
    W1f, b1f = fold_standardization(p)
    if pad_c > W1f.shape[1]:
        W1f = np.concatenate([W1f, np.zeros((W1f.shape[0], pad_c - W1f.shape[1]))], axis=1)
    return W1f, b1f


def pad_input(u, pad_c):
    """把 [N,3] 补到 [N,pad_c]，补的通道恒 0。"""
    if pad_c <= u.shape[1]:
        return u
    return np.concatenate([u, np.zeros((u.shape[0], pad_c - u.shape[1]))], axis=1)


def build(x_calib, p, verbose=True, pad_c=3, pad_hw=1, u8_logits=False, q_after_conv=False,
          kernel=1, no_relu=False, relu_on_quant=False):
    """返回 (onnx_bytes, meta)。x_calib 是已归一化的训练特征 [N,3]。

    pad_c / pad_hw 是「形状友好化」开关：NPU 对通道数/空间尺寸可能有对齐要求
    （从 libarmnn 里捞到的约束见 out/alnpu_capabilities.md）。把 3 通道补到 8、
    把空间 1×1 补到 4×4，数学上完全等价（补的通道输入恒 0、权重也补 0），
    但能在板子上多试几种形状而不用重新训练。
    """
    W1f, b1f = fold_weights(p, pad_c)
    x_calib = pad_input(np.asarray(x_calib, dtype=np.float64), pad_c)
    W2 = p["W2"].astype(np.float64)
    W3 = p["W3"].astype(np.float64)
    b2 = p["b2"].astype(np.float64)
    b3 = p["b3"].astype(np.float64)

    s_in, zp_in = np.float32(1.0 / 255.0), np.uint8(0)
    layers = []
    xq = np.clip(np.rint(x_calib / float(s_in)), 0, 255) * float(s_in)   # 校准用的量化输入

    for idx, (W, b) in enumerate([(W1f, b1f), (W2, b2), (W3, b3)], start=1):
        Wk = W.reshape(W.shape[0], W.shape[1], 1, 1)
        if kernel == 3:
            # 3x3 卷积，但只有中心权重非零 -> 数学上和 1x1 完全等价，
            # 目的只是让 Alnpu 的融合 pass 把它当「真正的卷积」而不是 FC。
            W3 = np.zeros((W.shape[0], W.shape[1], 3, 3), dtype=np.float64)
            W3[:, :, 1, 1] = W
            Wk = W3
            global_attrs = conv_attrs(3)
        else:
            global_attrs = conv_attrs(1)
        wq, sw, zw = asym_uint8(Wk)
        sb = np.float32(float(s_in if idx == 1 else s_prev) * float(sw))
        bq = np.rint(b / float(sb)).astype(np.int32)
        w_dq = (wq.astype(np.float64) - float(zw)) * float(sw)
        b_dq = bq.astype(np.float64) * float(sb)
        # 校准只看中心那一路（3x3 的邻域权重全是 0，等价于 1x1）
        kc = kernel // 2      # 1x1 -> 0，3x3 -> 1（只有中心权重非零）
        w_eff = w_dq[:, :, kc, kc].reshape(w_dq.shape[0], w_dq.shape[1]) if w_dq.ndim == 4 else w_dq.reshape(w_dq.shape[0], -1)
        y = np.maximum(doconv(xq.reshape(-1, xq.shape[1], 1, 1), w_eff.reshape(w_eff.shape[0], w_eff.shape[1], 1, 1), b_dq), 0.0)

        if idx < 3:
            amax = float(y.max())
            s_a = np.float32(max(amax, 1e-3) / 255.0)
            zp_a = np.uint8(0)                      # ReLU 后 min=0
            o_scale, o_zp = None, None
            xq = np.clip(np.rint(y / float(s_a)), 0, 255) * float(s_a)
            s_prev = s_a
        else:
            s_a, zp_a = None, None                  # 最后一层只做 DQ 再 softmax
            # 手工搭量化网络时，最后一层 Conv 的输出必须是 QAsymm8，需要一组覆盖 logits 范围的参数
            lo, hi = float(y.min()), float(y.max())
            o_scale = np.float32(max(hi - lo, 1e-3) / 255.0)
            o_zp = int(max(0, min(255, round(-lo / float(o_scale)))))
            s_prev = None
        layers.append({"w": wq, "w_scale": sw, "w_zp": zw, "b": bq, "b_scale": sb,
                       "a_scale": s_a, "a_zp": zp_a, "o_scale": o_scale, "o_zp": o_zp})
        if verbose:
            print(f"[qdq] conv{idx}: w{wq.shape} sw={float(sw):.4e} zw={int(zw)} "
                  f"sb={float(sb):.4e} " + (f"sa={float(s_a):.4e}" if s_a is not None else ""))

    nodes, inits = [], []
    inits += [om.tensor("input_scale", np.asarray([s_in], np.float32)),
              om.tensor("input_zero_point", np.asarray([zp_in], np.uint8))]
    nodes += [
        om.node("QuantizeLinear", ["input", "input_scale", "input_zero_point"], ["input_q"], "input.q"),
        om.node("DequantizeLinear", ["input_q", "input_scale", "input_zero_point"], ["input_dq"], "input.dq"),
    ]

    prev = "input_dq"
    for idx, L in enumerate(layers, start=1):
        n = f"conv{idx}"
        inits += [
            om.tensor(f"{n}.weight_quantized", L["w"]),
            om.tensor(f"{n}.weight_scale", np.asarray([L["w_scale"]], np.float32)),
            om.tensor(f"{n}.weight_zero_point", np.asarray([L["w_zp"]], np.uint8)),
            om.tensor(f"{n}.bias_quantized", L["b"]),
            om.tensor(f"{n}.bias_scale", np.asarray([L["b_scale"]], np.float32)),
            om.tensor(f"{n}.bias_zero_point", np.asarray([0], np.int32)),
        ]
        nodes += [
            om.node("DequantizeLinear",
                    [f"{n}.weight_quantized", f"{n}.weight_scale", f"{n}.weight_zero_point"],
                    [f"{n}.weight"], f"{n}.dq_w"),
            om.node("DequantizeLinear",
                    [f"{n}.bias_quantized", f"{n}.bias_scale", f"{n}.bias_zero_point"],
                    [f"{n}.bias"], f"{n}.dq_b"),
            om.node("Conv", [prev, f"{n}.weight", f"{n}.bias"], [f"{n}.out"], n, global_attrs),
        ]
        prev = f"{n}.out"
        # 激活量化（最后一层不做 ReLU/Q，留给 Softmax）
        if L["a_scale"] is not None:
            if q_after_conv:
                # Conv → Q → DQ → Relu：量化边界紧贴卷积
                if relu_on_quant:
                    # Q → Relu(u8) → DQ：让 NPU 的 ACT 单元顺带做 ReLU，量化边界不断开
                    qnodes = [
                        om.node("QuantizeLinear", [prev, f"{n}.a_scale", f"{n}.a_zp"],
                                [f"{n}.out_q"], f"{n}.q"),
                        om.node("Relu", [f"{n}.out_q"], [f"{n}.relu_q"], f"{n}.relu"),
                        om.node("DequantizeLinear", [f"{n}.relu_q", f"{n}.a_scale", f"{n}.a_zp"],
                                [f"{n}.out_dq"], f"{n}.dq"),
                    ]
                else:
                    qnodes = [
                        om.node("QuantizeLinear", [prev, f"{n}.a_scale", f"{n}.a_zp"],
                                [f"{n}.out_q"], f"{n}.q"),
                        om.node("DequantizeLinear", [f"{n}.out_q", f"{n}.a_scale", f"{n}.a_zp"],
                                [f"{n}.out_dq"], f"{n}.dq"),
                    ]
                    if not no_relu:
                        qnodes.append(om.node("Relu", [f"{n}.out_dq"], [f"{n}.relu"], f"{n}.relu"))
                nodes += qnodes
                inits += [om.tensor(f"{n}.a_scale", np.asarray([L["a_scale"]], np.float32)),
                          om.tensor(f"{n}.a_zp", np.asarray([L["a_zp"]], np.uint8))]
                prev = f"{n}.out_dq"   # 下一层 Conv 必须吃反量化后的 float
            else:
                qin = prev
                if not no_relu:
                    nodes += [om.node("Relu", [prev], [f"{n}.relu"], f"{n}.relu")]
                    qin = f"{n}.relu"
                nodes += [
                    om.node("QuantizeLinear", [qin, f"{n}.a_scale", f"{n}.a_zp"],
                            [f"{n}.relu_q"], f"{n}.q"),
                    om.node("DequantizeLinear", [f"{n}.relu_q", f"{n}.a_scale", f"{n}.a_zp"],
                            [f"{n}.relu_dq"], f"{n}.dq"),
                ]
                inits += [om.tensor(f"{n}.a_scale", np.asarray([L["a_scale"]], np.float32)),
                          om.tensor(f"{n}.a_zp", np.asarray([L["a_zp"]], np.uint8))]
                prev = f"{n}.relu_dq"
        else:
            # 最后一层补 QuantizeLinear：让每个 Conv 的输出都有量化参数。
            # u8_logits=True 时**不**再 DequantizeLinear——ALHardNPU 的输出必须是 QAsymmU8，
            # 接一个 float 的 DQ 会让融合后的节点被判定为「output is not a supported type」。
            q_out = "logits" if u8_logits else f"{n}.out_q"
            nodes += [
                om.node("QuantizeLinear", [prev, f"{n}.o_scale", f"{n}.o_zp"],
                        [q_out], f"{n}.oq"),
            ]
            inits += [om.tensor(f"{n}.o_scale", np.asarray([L["o_scale"]], np.float32)),
                      om.tensor(f"{n}.o_zp", np.asarray([L["o_zp"]], np.uint8))]
            if not u8_logits:
                nodes += [om.node("DequantizeLinear", [f"{n}.out_q", f"{n}.o_scale", f"{n}.o_zp"],
                                  [f"{n}.out_dq"], f"{n}.odq")]
                prev = f"{n}.out_dq"
            else:
                prev = q_out

    # 末尾 softmax：u8_logits 时不做，直接把 uint8 logits 作为图输出（host 侧再 softmax）
    if not u8_logits:
        nodes += [om.node("Softmax", [prev], ["probs"], "softmax", [om.attr_int("axis", 1)])]

    # 中间张量的 value_info：厂商导出的 QDQ 模型里每个中间张量都有，缺了 armnn parser 会崩
    dims_in = [1, pad_c, pad_hw, pad_hw]
    vinfo = [om.value_info("input_q", dims_in, 2), om.value_info("input_dq", dims_in, 1)]
    for idx, L in enumerate(layers, start=1):
        oc = int(L["w"].shape[0])
        dims = [1, oc, pad_hw, pad_hw]
        vinfo += [om.value_info(f"conv{idx}.weight", list(L["w"].shape), 1),
                  om.value_info(f"conv{idx}.bias", [oc], 1),
                  om.value_info(f"conv{idx}.out", dims, 1)]
        if idx < 3:
            if q_after_conv:
                if relu_on_quant:
                    vinfo += [om.value_info(f"conv{idx}.out_q", dims, 2),
                              om.value_info(f"conv{idx}.relu_q", dims, 2),
                              om.value_info(f"conv{idx}.out_dq", dims, 1)]
                else:
                    vinfo += [om.value_info(f"conv{idx}.out_q", dims, 2),
                              om.value_info(f"conv{idx}.out_dq", dims, 1),
                              om.value_info(f"conv{idx}.relu", dims, 1)]
            else:
                vinfo += [om.value_info(f"conv{idx}.relu", dims, 1),
                          om.value_info(f"conv{idx}.relu_q", dims, 2),
                          om.value_info(f"conv{idx}.relu_dq", dims, 1)]
        else:
            # 最后一层的输出张量也要声明，否则 parser 又会在 Q/DQ 上崩
            if u8_logits:
                vinfo += [om.value_info("logits", dims, 2)]
            else:
                vinfo += [om.value_info(f"conv{idx}.out_q", dims, 2),
                          om.value_info(f"conv{idx}.out_dq", dims, 1)]
    out_name = "logits" if u8_logits else "probs"
    if u8_logits:
        vinfo.append(om.value_info("logits", [1, 4, pad_hw, pad_hw], 2))
    else:
        vinfo.append(om.value_info("probs", [1, 4, pad_hw, pad_hw], 1))

    model = om.make_model(
        nodes, inits,
        inputs=[om.value_info("input", dims_in)],
        outputs=[om.value_info(out_name, [1, 4, pad_hw, pad_hw], 2 if u8_logits else 1)],
        graph_name="dcdc_condition_conv1x1_qdq",
        value_infos=vinfo,
    )
    meta = {"input_scale": float(s_in), "pad_c": int(pad_c), "pad_hw": int(pad_hw),
            "input_layout": "NCHW，只有 [0:3, 0, 0] 是有效值，其余补 0",
            "layers": [
        {k: (float(v) if isinstance(v, (float, np.floating)) else (int(v) if isinstance(v, (int, np.integer)) else None))
         for k, v in L.items() if k in ("w_scale", "w_zp", "b_scale", "a_scale", "a_zp", "o_scale", "o_zp")}
        for L in layers]}
    global LAST_LAYERS, LAST_META
    LAST_LAYERS, LAST_META = layers, meta
    return model, meta


def reference_forward(p, u, meta):
    """独立实现：按同一量化方案逐层算，用来和 ONNX 解析结果对拍。"""
    pad_c = int(meta.get("pad_c", 3))
    W1f, b1f = fold_weights(p, pad_c)
    up = pad_input(u, pad_c)
    Ws = [W1f, p["W2"].astype(np.float64), p["W3"].astype(np.float64)]
    bs = [b1f, p["b2"].astype(np.float64), p["b3"].astype(np.float64)]
    s_in = meta["input_scale"]
    x = np.clip(np.rint(up / s_in), 0, 255) * s_in
    for i, (W, b, L) in enumerate(zip(Ws, bs, meta["layers"])):
        # 用导出的 float32 scale/zp 重建反量化权重（不要用 float64 重算，否则舍入不同）
        s = float(L["w_scale"])
        zp = int(L["w_zp"])
        wq = np.clip(np.rint(W / s) + zp, 0, 255)
        w_dq = (wq - zp) * s
        b_dq = np.rint(b / L["b_scale"]) * L["b_scale"]
        y = x @ w_dq.T + b_dq
        if i < 2:
            y = np.maximum(y, 0.0)
            x = np.clip(np.rint(y / L["a_scale"]), 0, 255) * L["a_scale"]
        else:
            # 最后一层也做一次量化/反量化，和导出的 Q/DQ 对齐
            logits = (np.clip(np.rint(y / L["o_scale"]) + L["o_zp"], 0, 255) - L["o_zp"]) * L["o_scale"]
    z = logits - logits.max(axis=1, keepdims=True)
    e = np.exp(z)
    return e / e.sum(axis=1, keepdims=True)


def write_header(path, name_prefix="DCDC_Q"):
    """把量化参数写成 C 头，供 dcdc_npu_demo --qconv 用 armnn API 直接搭量化网络。

    为什么需要这条兜底路：armnnOnnxParser 解析我们自己写的 QDQ 图会段错误（见 BOARD_FINDINGS.md），
    但用 API 直接搭 Conv(QAsymm8) 不经过 parser，能绕过去。
    """
    layers, meta = LAST_LAYERS, LAST_META
    L = []
    L.append("/* 由 export_onnx_qdq.py --emit-header 生成，勿手改。")
    L.append(" * 输入: u = {Vout/48, Iout/2.2, duty/95}，QAsymmU8，scale/zp 见下；")
    L.append(" * 输出: 4 个 uint8 logits，需 (q - zp) * scale 后用 softmax 还原概率。 */")
    L.append("#ifndef DCDC_Q_WEIGHTS_H")
    L.append("#define DCDC_Q_WEIGHTS_H")
    L.append("")
    L.append(f"#define DCDC_Q_IN_SCALE {meta['input_scale']:.9e}f")
    L.append("#define DCDC_Q_IN_ZP 0")
    L.append(f"#define DCDC_Q_H1 {layers[0]['w'].shape[0]}")
    L.append(f"#define DCDC_Q_H2 {layers[1]['w'].shape[0]}")
    L.append(f"#define DCDC_Q_OUT {layers[2]['w'].shape[0]}")
    L.append("")

    def arr(ctype, name, a):
        flat = [int(x) for x in np.asarray(a).ravel()]
        body = ", ".join(str(x) for x in flat)
        return f"static const {ctype} {name}[{len(flat)}] = {{{body}}};\n"

    for i, lay in enumerate(layers, start=1):
        L.append(arr("unsigned char", f"DCDC_Q_W{i}", lay["w"]))
        L.append(arr("int", f"DCDC_Q_B{i}", lay["b"]))
        L.append(f"#define DCDC_Q_W{i}_SCALE {float(lay['w_scale']):.9e}f")
        L.append(f"#define DCDC_Q_W{i}_ZP {int(lay['w_zp'])}")
        L.append(f"#define DCDC_Q_B{i}_SCALE {float(lay['b_scale']):.9e}f")
        if lay["a_scale"] is not None:
            L.append(f"#define DCDC_Q_A{i}_SCALE {float(lay['a_scale']):.9e}f")
            L.append(f"#define DCDC_Q_A{i}_ZP {int(lay['a_zp'])}")
        else:
            L.append(f"#define DCDC_Q_O_SCALE {float(lay['o_scale']):.9e}f")
            L.append(f"#define DCDC_Q_O_ZP {int(lay['o_zp'])}")
        L.append("")
    L.append("#endif")
    L.append("")
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(L))
    print(f"[qdq] 写出 C 量化权重头 {path}")


def main(argv=None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", default=os.path.join("out", "model.npz"))
    ap.add_argument("--csv", default=os.path.join("out", "dataset.csv"))
    ap.add_argument("--outdir", default="out")
    ap.add_argument("--name", default="dcdc_npu_qdq")
    ap.add_argument("--pad-c", type=int, default=3,
                    help="输入通道数（>3 时补 0 通道，权重也补 0，数学等价）")
    ap.add_argument("--relu-on-quant", action="store_true",
                    help="配合 --q-after-conv：ReLU 放在 Q 之后 DQ 之前（作用在 uint8 上）")
    ap.add_argument("--no-relu", action="store_true",
                    help="不输出 Relu 节点（配合线性模型），让量化边界连续，便于 Alnpu 融合")
    ap.add_argument("--kernel", type=int, default=1, choices=(1, 3),
                    help="1=1x1 卷积；3=3x3 但只有中心非零（等价于 1x1，只为讨好融合 pass）")
    ap.add_argument("--q-after-conv", action="store_true",
                    help="Q/DQ 紧贴 Conv（Conv→Q→DQ→Relu），用于试探融合 pass 的期望顺序")
    ap.add_argument("--u8-logits", action="store_true",
                    help="图输出 uint8 logits（ALHardNPU 只接受 QAsymmU8 输出）")
    ap.add_argument("--pad-hw", type=int, default=1,
                    help="输入空间尺寸 H=W（>1 时补 0，只在 [0,0] 位置有数据）")
    args = ap.parse_args(argv)

    p = dict(np.load(args.model, allow_pickle=True))
    x_raw, y, g = tr.load_dataset(args.csv)
    (xt, yt), (xv, yv), (xs, ys) = tr.split_by_trial(x_raw, y, g)
    div = np.asarray(INPUT_DIV)[None, :]
    ut, us = xt / div, xs / div

    model_bytes, meta = build(ut, p, pad_c=args.pad_c, pad_hw=args.pad_hw,
                            u8_logits=args.u8_logits, q_after_conv=args.q_after_conv,
                            kernel=args.kernel, no_relu=args.no_relu,
                            relu_on_quant=args.relu_on_quant)
    write_header(os.path.join(args.outdir, args.name + "_weights.h"))
    path = os.path.join(args.outdir, args.name + ".onnx")
    with open(path, "wb") as f:
        f.write(model_bytes)

    m = om.read_model(model_bytes)
    from collections import Counter
    ops = Counter(n["op"] for n in m["nodes"])
    print(f"[qdq] 写出 {path} ({len(model_bytes)} B)")
    print(f"[qdq] opset={m['opset']} 输入={m['inputs']} 输出={m['outputs']} 节点={dict(ops)}")

    # 1) ONNX 解析器 vs 独立实现（按 pad 后的形状喂数据）
    n = us.shape[0]
    feed_arr = np.zeros((n, args.pad_c, args.pad_hw, args.pad_hw), dtype=np.float64)
    feed_arr[:, :3, 0, 0] = us
    raw_out = om.run_model(m, {"input": feed_arr})
    if args.u8_logits:
        q = raw_out["logits"]
        lz = (q.astype(np.float64) - float(meta["layers"][2]["o_zp"])) * float(meta["layers"][2]["o_scale"])
        lz = lz - lz.max(axis=1, keepdims=True)
        e = np.exp(lz)
        probs_all = (e / e.sum(axis=1, keepdims=True)).transpose(0, 1, 2, 3)
    else:
        probs_all = raw_out["probs"]
    # 1x1 卷积保持空间尺寸；只有 (0,0) 位置有真实数据，其余是补零算出来的
    probs_onnx = probs_all[:, :, 0, 0]
    probs_ref = reference_forward(p, us, meta)
    dev = float(np.abs(probs_onnx - probs_ref).max())

    # 2) 与 float 模型的类别一致性 + 对这个测试集的准确率
    W1f, b1f = fold_standardization(p)
    z1 = np.maximum(us @ W1f.T + b1f, 0.0)
    z2 = np.maximum(z1 @ p["W2"].T + p["b2"], 0.0)
    lg = z2 @ p["W3"].T + p["b3"]
    lg -= lg.max(axis=1, keepdims=True)
    e = np.exp(lg)
    probs_f = e / e.sum(axis=1, keepdims=True)
    agree = float((probs_f.argmax(1) == probs_onnx.argmax(1)).mean())
    acc_q = float((probs_onnx.argmax(1) == ys).mean())

    print(f"[qdq] 与独立实现对拍最大偏差 = {dev:.3e}")
    print(f"[qdq] 与 float 模型类别一致率 = {agree * 100:.2f}%   QDQ 测试集准确率 = {acc_q * 100:.2f}%")
    if dev > 1e-5:
        print("[qdq] 数值对拍失败", file=sys.stderr)
        return 1

    # 3) 结构对照官方模型
    print("[qdq] 算子统计与官方 fire_detect_sim_quant_uint8 对照：")
    print("      官方: QuantizeLinear/DequantizeLinear/Conv/Relu/... 同一套 QDQ 结构")
    print(f"      本模型: {dict(ops)}，Conv 权重 uint8、bias int32、输入 scale={meta['input_scale']:.6f}")

    with open(os.path.join(args.outdir, args.name + "_model.json"), "w", encoding="utf-8") as f:
        json.dump({"name": args.name,
                   "input": {"order": ["v", "i", "duty"], "shape": [1, args.pad_c, args.pad_hw, args.pad_hw],
                             "divisors": INPUT_DIV,
                             "layout": "NCHW；数据只放 [0:3, 0, 0]，其余补 0"},
                   "output": {"classes": CLASS_NAMES, "shape": [1, 4, 1, 1], "activation": "softmax"},
                   "quant": meta, "acc_test": acc_q, "agree_with_float": agree,
                   "max_dev_vs_reference": dev}, f, ensure_ascii=False, indent=2)
    print(f"[qdq] 写出 {os.path.join(args.outdir, args.name + '_model.json')}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
