"""极简 ONNX 读写器（只依赖 numpy）。

为什么自己写：这台机器不能连 PyPI（pip 装 onnx/torch 会卡住），但板上推理链要的是
一个能被 armnnOnnxParser 解析的 .onnx。这里按 onnx.proto 的字段号手写 protobuf 编码，
只覆盖一个 Gemm/Relu/Softmax 小图需要的字段；同时提供一个最小解析器，
用来把写出的文件再读回来做数值验证（不能替代 onnxruntime，但能证明文件结构自洽）。

支持:
    写   : ModelProto / GraphProto / NodeProto / AttributeProto / TensorProto / ValueInfoProto
    算子 : Gemm(transB=1) / Relu / Softmax(axis)
"""

from __future__ import annotations

import struct

import numpy as np

# ---------------------------------------------------------------- protobuf 编码
WT_VARINT, WT_I64, WT_LEN, WT_I32 = 0, 1, 2, 5


def _varint(v: int) -> bytes:
    if v < 0:
        v += 1 << 64
    out = bytearray()
    while True:
        b = v & 0x7F
        v >>= 7
        if v:
            out.append(b | 0x80)
        else:
            out.append(b)
            return bytes(out)


def _key(field: int, wt: int) -> bytes:
    return _varint((field << 3) | wt)


def f_varint(field: int, v: int) -> bytes:
    return _key(field, WT_VARINT) + _varint(int(v))


def f_float(field: int, v: float) -> bytes:
    return _key(field, WT_I32) + struct.pack("<f", float(v))


def f_bytes(field: int, payload: bytes) -> bytes:
    return _key(field, WT_LEN) + _varint(len(payload)) + payload


def f_str(field: int, s: str) -> bytes:
    return f_bytes(field, s.encode("utf-8"))


def f_msg(field: int, payload: bytes) -> bytes:
    return f_bytes(field, payload)


def f_packed_f32(field: int, arr) -> bytes:
    a = np.asarray(arr, dtype="<f4").ravel()
    return f_bytes(field, a.tobytes())


def f_packed_i64(field: int, arr) -> bytes:
    payload = b"".join(_varint(int(x)) for x in np.asarray(arr).ravel())
    return f_bytes(field, payload)


# ---------------------------------------------------------------- 结构构造
DT_FLOAT = 1
AT_FLOAT, AT_INT = 1, 2

_ONNX_DTYPEOF = {"<f4": 1, "|u1": 2, "|i1": 3, "<i4": 6, "<i8": 7, "<f8": 11}


def tensor(name: str, arr) -> bytes:
    """float32 用 float_data；uint8/int32/int64 用 raw_data。

    踩过的坑（都以 armnn parser 报错/段错误的形式出现）：
      1. uint8 写 int32_data → "There is no raw data for TensorProto ... uint8_t"，armnn 只认 raw_data；
      2. 中间张量没有 value_info → 解析 Q/DQ 时段错误（厂商模型里每个中间张量都有 field 13）；
      3. scale/zero_point 写成 shape [1] → 也崩；厂商写的是 rank-0 标量（不写 dims）。
    """
    a = np.asarray(arr)
    if a.dtype == np.float64:      # ONNX 的 float 就是 float32，不要意外写成 double
        a = a.astype(np.float32)
    dt = _ONNX_DTYPEOF.get(a.dtype.str)
    if dt is None:
        raise TypeError(f"不支持的 dtype: {a.dtype}")
    out = b""
    if a.size > 1:                 # 标量（scale/zp）不写 dims，与厂商导出格式一致
        out += f_packed_i64(1, a.shape if a.ndim else (1,))
    out += f_varint(2, dt)
    if dt == DT_FLOAT:
        out += f_packed_f32(4, a.ravel())
    else:
        out += f_bytes(9, a.astype(a.dtype.newbyteorder("<")).tobytes())   # raw_data
    out += f_str(8, name)
    return out


def attr_float(name: str, v: float) -> bytes:
    return f_str(1, name) + f_float(2, v) + f_varint(20, AT_FLOAT)


def attr_int(name: str, v: int) -> bytes:
    return f_str(1, name) + f_varint(3, int(v)) + f_varint(20, AT_INT)


def attr_ints(name: str, vals) -> bytes:
    """整型数组属性（pads/strides/kernel_shape 用）。"""
    payload = b"".join(_varint(int(v)) for v in vals)
    return f_str(1, name) + f_bytes(8, payload) + f_varint(20, 7)   # 7 = INTS


def node(op: str, inputs, outputs, name: str, attrs=()) -> bytes:
    out = b"".join(f_str(1, i) for i in inputs)
    out += b"".join(f_str(2, o) for o in outputs)
    out += f_str(3, name) + f_str(4, op)
    out += b"".join(f_msg(5, a) for a in attrs)
    return out


def value_info(name: str, shape, elem_type: int = DT_FLOAT) -> bytes:
    # TypeProto{ tensor_type{ elem_type, shape{ dim*{dim_value} } } }
    dims = b"".join(f_msg(1, f_varint(1, d)) for d in (shape or []))
    shape_msg = f_msg(2, dims)
    ttype = f_varint(1, elem_type) + shape_msg
    type_proto = f_msg(1, ttype)
    return f_str(1, name) + f_msg(2, type_proto)


def make_model(nodes, initializers, inputs, outputs, opset=13, producer="dcdc_npu_train",
               graph_name="dcdc_condition_mlp", value_infos=()) -> bytes:
    graph = b"".join(f_msg(1, n) for n in nodes)
    graph += f_str(2, graph_name)
    graph += b"".join(f_msg(5, t) for t in initializers)
    graph += b"".join(f_msg(11, v) for v in inputs)
    graph += b"".join(f_msg(12, v) for v in outputs)
    # 中间张量的类型/形状（field 13）。厂商导出的 QDQ 模型里每个中间张量都有 value_info，
    # 缺了它 armnn 的 parser 会在解析 QuantizeLinear/DequantizeLinear 时段错误。
    graph += b"".join(f_msg(13, v) for v in value_infos)

    model = f_varint(1, 8)                       # ir_version
    model += f_str(2, producer)                  # producer_name
    model += f_str(3, "1.0")                     # producer_version
    # opset_import = 8 是 OperatorSetIdProto 消息（不是裸整数！）
    model += f_msg(8, f_str(1, "") + f_varint(2, opset))
    model += f_msg(7, graph)                     # graph
    return model


# ---------------------------------------------------------------- protobuf 解码
def _read_varint(buf: bytes, i: int):
    shift = 0
    val = 0
    while True:
        b = buf[i]
        i += 1
        val |= (b & 0x7F) << shift
        if not b & 0x80:
            return val, i
        shift += 7


def parse_fields(buf: bytes):
    """把一段 protobuf 拆成 [(field, wire, value)]，value 为 int / bytes。"""
    out = []
    i = 0
    n = len(buf)
    while i < n:
        key, i = _read_varint(buf, i)
        field, wt = key >> 3, key & 7
        if wt == WT_VARINT:
            v, i = _read_varint(buf, i)
        elif wt == WT_I64:
            v = struct.unpack_from("<q", buf, i)[0]
            i += 8
        elif wt == WT_I32:
            v = buf[i:i + 4]
            i += 4
        elif wt == WT_LEN:
            ln, i = _read_varint(buf, i)
            v = buf[i:i + ln]
            i += ln
        else:
            raise ValueError(f"unsupported wire type {wt}")
        out.append((field, wt, v))
    return out


def _get(fields, field, default=None):
    for f, _wt, v in fields:
        if f == field:
            return v
    return default


def _all(fields, field):
    return [v for f, _wt, v in fields if f == field]


_DTYPES = {1: "<f4", 2: "u1", 3: "i1", 4: "<u2", 5: "<i2", 6: "<i4", 7: "<i8",
           9: "?", 10: "<f2", 11: "<f8", 12: "<u4", 13: "<u8"}


def read_tensor(buf: bytes):
    fs = parse_fields(buf)
    dims = []
    for raw in _all(fs, 1):          # 兼容 packed 与 unpacked 两种写法
        if isinstance(raw, int):
            dims.append(raw)
        else:
            j = 0
            while j < len(raw):
                v, j = _read_varint(raw, j)
                dims.append(v)
    dt = _get(fs, 2, 1)
    np_dt = _DTYPES.get(dt, "<f4")
    data_raw = _get(fs, 9)
    if data_raw:
        arr = np.frombuffer(data_raw, dtype=np_dt).copy()
    elif dt == 1:
        chunks = _all(fs, 4)          # float_data：packed 时是一段字节，unpacked 时是多个 4 字节
        if not chunks:
            arr = np.zeros(0, dtype="<f4")
        elif len(chunks) == 1:
            arr = np.frombuffer(chunks[0], dtype="<f4").copy()
        else:
            arr = np.asarray([struct.unpack("<f", c)[0] for c in chunks if len(c) == 4], dtype="<f4")
    else:
        field = 5 if dt in (2, 3, 4, 5, 6) else 7
        vals = []
        for packed in _all(fs, field):
            if isinstance(packed, int):
                vals.append(packed)
                continue
            j = 0
            while j < len(packed):
                v, j = _read_varint(packed, j)
                if dt in (3, 6, 7) and v >= 1 << 63:
                    v -= 1 << 64
                vals.append(v)
        arr = np.asarray(vals if vals else [0], dtype=np_dt)
    return {"name": _get(fs, 8, b"").decode(), "dims": dims, "data": arr.reshape(dims) if dims else arr}


def read_value_info(buf: bytes):
    """返回 {name, dtype, dims}，dims 中 0 表示动态维。"""
    fs = parse_fields(buf)
    name = _get(fs, 1, b"").decode()
    dtype, dims = None, []
    t = _get(fs, 2)
    if t:
        tt = _get(parse_fields(t), 1)
        if tt:
            ttf = parse_fields(tt)
            dtype = _get(ttf, 1)
            shp = _get(ttf, 2)
            if shp:
                for db in _all(parse_fields(shp), 1):
                    df = parse_fields(db)
                    dims.append(_get(df, 1, 0))
    return {"name": name, "dtype": dtype, "dims": dims}


def read_model(buf: bytes):
    fs = parse_fields(buf)
    graph = parse_fields(_get(fs, 7))
    nodes = []
    for nb in _all(graph, 1):
        nf = parse_fields(nb)
        attrs = {}
        for ab in _all(nf, 5):
            af = parse_fields(ab)
            name = _get(af, 1, b"").decode()
            if _get(af, 2) is not None:
                attrs[name] = struct.unpack("<f", _get(af, 2))[0]
            elif _get(af, 3) is not None:
                attrs[name] = _get(af, 3)
            elif _all(af, 8):
                # INTS 属性（pads/strides/dilations/kernel_shape 等）；packed 与 unpacked 都要吃
                vals = []
                for raw in _all(af, 8):
                    if isinstance(raw, int):
                        vals.append(raw)
                        continue
                    j = 0
                    while j < len(raw):
                        v, j = _read_varint(raw, j)
                        vals.append(v)
                attrs[name] = vals
        nodes.append({
            "op": _get(nf, 4, b"").decode(),
            "inputs": [x.decode() for x in _all(nf, 1)],
            "outputs": [x.decode() for x in _all(nf, 2)],
            "name": _get(nf, 3, b"").decode(),
            "attrs": attrs,
        })
    inits = {t["name"]: t["data"] for t in (read_tensor(b) for b in _all(graph, 5))}
    ins_vi = [read_value_info(b) for b in _all(graph, 11)]
    outs_vi = [read_value_info(b) for b in _all(graph, 12)]
    opset = None
    opset_msg = _get(fs, 8)
    if opset_msg:
        opset = _get(parse_fields(opset_msg), 2)
    return {"ir_version": _get(fs, 1), "opset": opset, "nodes": nodes,
            "initializers": inits,
            "inputs": [v["name"] for v in ins_vi], "outputs": [v["name"] for v in outs_vi],
            "input_info": ins_vi, "output_info": outs_vi}


# ---------------------------------------------------------------- 参考执行器
def _conv2d(x, w, b, strides=(1, 1), pads=(0, 0, 0, 0), dilations=(1, 1), group=1):
    """朴素 NCHW 卷积（只用于小图对拍，性能不重要）。"""
    N, C, H, W = x.shape
    M, Cg, kH, kW = w.shape
    (sy, sx), (dy, dx), group = strides, dilations, int(group)
    pt, pl, pb, pr = pads
    Ho = (H + pt + pb - dy * (kH - 1) - 1) // sy + 1
    Wo = (W + pl + pr - dx * (kW - 1) - 1) // sx + 1
    xp = np.pad(x, ((0, 0), (0, 0), (pt, pb), (pl, pr)))
    out = np.zeros((N, M, Ho, Wo), dtype=np.float64)
    mg = M // group
    for g in range(group):
        xg = xp[:, g * Cg:(g + 1) * Cg]
        wg = w[g * mg:(g + 1) * mg]
        for i in range(Ho):
            for j in range(Wo):
                patch = xg[:, :, i * sy:i * sy + dy * (kH - 1) + 1:dy,
                            j * sx:j * sx + dx * (kW - 1) + 1:dx]
                out[:, g * mg:(g + 1) * mg, i, j] = np.einsum("nckl,mckl->nm", patch, wg)
    if b is not None:
        out += np.asarray(b).reshape(1, -1, 1, 1)
    return out


def _qlinear(x, scale, zp, axis, out_max, quantize):
    s = np.asarray(scale)
    z = np.asarray(zp)
    if s.size == 1:
        s, z = float(s.ravel()[0]), int(np.rint(z.ravel()[0]))
        if quantize:
            return np.clip(np.rint(np.asarray(x) / s) + z, 0, out_max).astype(np.float64)
        return (np.asarray(x, dtype=np.float64) - z) * s
    shape = [1] * np.asarray(x).ndim
    shape[axis] = s.size
    s, z = s.reshape(shape), z.reshape(shape)
    if quantize:
        return np.clip(np.rint(np.asarray(x) / s) + z, 0, out_max).astype(np.float64)
    return (np.asarray(x, dtype=np.float64) - z) * s


def run_model(model: dict, feed: dict):
    """按 ONNX 语义执行（只支持本工程用到的算子），用于数值对拍。"""
    inits = model["initializers"]
    vals = dict(feed)
    for n in model["nodes"]:
        op = n["op"]
        a = n["attrs"]
        args = [vals.get(i, inits.get(i)) for i in n["inputs"]]
        if op == "Gemm":
            A = np.asarray(args[0], dtype=np.float64)
            B = np.asarray(args[1], dtype=np.float64)
            C = None if len(args) < 3 or args[2] is None else np.asarray(args[2], dtype=np.float64)
            alpha = float(a.get("alpha", 1.0))
            beta = float(a.get("beta", 1.0))
            if int(a.get("transA", 0)):
                A = A.T
            if int(a.get("transB", 0)):
                B = B.T
            Y = alpha * (A @ B)
            if C is not None:
                Y = Y + beta * C
        elif op == "Relu":
            Y = np.maximum(np.asarray(args[0], dtype=np.float64), 0.0)
        elif op == "Softmax":
            x = np.asarray(args[0], dtype=np.float64)
            axis = int(a.get("axis", 1))
            x = x - x.max(axis=axis, keepdims=True)
            e = np.exp(x)
            Y = e / e.sum(axis=axis, keepdims=True)
        elif op == "Conv":
            Y = _conv2d(np.asarray(args[0], dtype=np.float64), np.asarray(args[1], dtype=np.float64),
                        None if len(args) < 3 or args[2] is None else args[2],
                        strides=tuple(a.get("strides", (1, 1))), pads=tuple(a.get("pads", (0, 0, 0, 0))),
                        dilations=tuple(a.get("dilations", (1, 1))), group=int(a.get("group", 1)))
        elif op == "MaxPool":
            x = np.asarray(args[0], dtype=np.float64)
            a = n["attrs"]
            kH, kW = tuple(a.get("kernel_shape", (2, 2)))
            sy, sx = tuple(a.get("strides", (kH, kW)))
            pt, pl, pb, pr = tuple(a.get("pads", (0, 0, 0, 0)))
            N, C, H, W = x.shape
            Ho = (H + pt + pb - kH) // sy + 1
            Wo = (W + pl + pr - kW) // sx + 1
            out = np.empty((N, C, Ho, Wo), dtype=np.float64)
            for i in range(Ho):
                for j in range(Wo):
                    patch = x[:, :, i * sy:i * sy + kH, j * sx:j * sx + kW]
                    out[:, :, i, j] = patch.max(axis=(2, 3))
            Y = out
        elif op == "QuantizeLinear":
            z = np.asarray(args[2]) if len(args) > 2 and args[2] is not None else np.zeros(1, np.uint8)
            qmax = 255 if z.ravel()[0] >= 0 else 127
            Y = _qlinear(args[0], args[1], z, int(a.get("axis", 1)), qmax, True)
        elif op == "DequantizeLinear":
            z = np.asarray(args[2]) if len(args) > 2 and args[2] is not None else np.zeros(1, np.uint8)
            Y = _qlinear(args[0], args[1], z, int(a.get("axis", 1)), 255, False)
        else:
            raise NotImplementedError(op)
        vals[n["outputs"][0]] = Y
    return {k: vals[k] for k in model["outputs"]}
