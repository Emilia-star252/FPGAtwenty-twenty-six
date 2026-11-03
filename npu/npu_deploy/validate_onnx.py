"""对导出的 ONNX 做结构自检（不能替代 onnxruntime/armnn，但能挡住写文件时的低级错误）。

检查项：
  1. ir_version / opset / 图输入输出是否齐全
  2. 每个初始张量：dtype 合法、量化张量的 dtype 正确
  3. 拓扑序：每个节点的输入都能由「图输入 / 初始张量 / 前面节点的输出」提供
  4. Gemm：权重 [out, in] 与输入维数一致（transB=1），bias 长度 = out
  5. Conv：权重 4 维 [M, C/g, kH, kW]，bias 长度 = M
  6. QDQ：scale 单元素且为正，zero_point 的 dtype 与量化类型匹配
  7. Softmax：axis 合法

形状是沿图传播算出来的（权重可能经过 DequantizeLinear 才进 Conv，所以要顺着找）。

用法：python validate_onnx.py out/dcdc_npu.onnx out/dcdc_npu_qdq.onnx
"""

from __future__ import annotations

import sys

import numpy as np

import onnx_min as om

KNOWN_OPS = {"Gemm", "Relu", "Softmax", "Conv", "QuantizeLinear", "DequantizeLinear"}


class Checker:
    def __init__(self, path):
        self.path = path
        self.errors, self.warns, self.notes = [], [], []

    def err(self, msg):
        self.errors.append(msg)

    def warn(self, msg):
        self.warns.append(msg)

    def run(self) -> bool:
        m = om.read_model(open(self.path, "rb").read())
        self.m, self.inits = m, m["initializers"]

        if not m.get("ir_version"):
            self.err("缺 ir_version")
        if m.get("opset") != 13:
            self.warn(f"opset={m.get('opset')}（本工程按 13 生成）")
        if not m["inputs"]:
            self.err("图没有输入")
        if not m["outputs"]:
            self.err("图没有输出")
        self.notes.append(f"opset={m['opset']} 输入={m['inputs']} 输出={m['outputs']} 节点={len(m['nodes'])}")

        for name, arr in self.inits.items():
            if arr is None:
                self.err(f"初始张量 {name} 读不出来")
                continue
            if arr.dtype.kind not in "fui":
                self.err(f"初始张量 {name} dtype 异常: {arr.dtype}")
            if name.endswith("weight_quantized") and arr.dtype != np.uint8:
                self.err(f"{name} 应为 uint8，实际 {arr.dtype}")
            if name.endswith("bias_quantized") and arr.dtype != np.int32:
                self.err(f"{name} 应为 int32，实际 {arr.dtype}")
        self.notes.append(f"初始张量 {len(self.inits)} 个")

        # 形状/来源表：name -> {"shape": tuple, "qsrc": 量化源名字}
        self.st = {}
        for vi in m["input_info"]:
            self.st[vi["name"]] = {"shape": tuple(vi["dims"] or (1,)), "qsrc": None}
        for name, arr in self.inits.items():
            self.st[name] = {"shape": tuple(arr.shape), "qsrc": name}

        available = set(m["inputs"]) | set(self.inits)
        for n in m["nodes"]:
            if n["op"] not in KNOWN_OPS:
                self.err(f"未知算子 {n['op']}（{n['name']}）")
            for i in n["inputs"]:
                if i and i not in available:
                    self.err(f"{n['name']}({n['op']}) 的输入 {i} 还没定义")
            if len(n["outputs"]) != 1:
                self.err(f"{n['name']} 输出数量 {len(n['outputs'])}（本工程的图都是 1）")
            self._propagate(n)
            for o in n["outputs"]:
                available.add(o)

        for n in m["nodes"]:
            op = n["op"]
            if op == "Gemm":
                self._check_gemm(n)
            elif op == "Conv":
                self._check_conv(n)
            elif op in ("QuantizeLinear", "DequantizeLinear"):
                self._check_q(n)
            elif op == "Softmax":
                axis = int(n["attrs"].get("axis", 1))
                if axis not in (-1, 1, 3):
                    self.warn(f"Softmax axis={axis}")
        self.notes.append("算子统计: " + ", ".join(
            f"{op}×{sum(1 for x in m['nodes'] if x['op'] == op)}"
            for op in sorted({x['op'] for x in m['nodes']})))
        return not self.errors

    def _shape(self, name):
        s = self.st.get(name)
        return s["shape"] if s else None

    def _propagate(self, n):
        op, ins, outs = n["op"], n["inputs"], n["outputs"][0]
        a = n["attrs"]
        shp_in = self._shape(ins[0]) if ins else None
        if op == "Gemm":
            B = self._shape(ins[1]) if len(ins) > 1 else None
            out_dim = B[0] if B else None
            batch = shp_in[0] if shp_in else 1
            self.st[outs] = {"shape": (batch, out_dim), "qsrc": None}
        elif op == "Conv":
            W = self._shape(ins[1])
            if shp_in and W and len(shp_in) == 4:
                N, _, H, Wd = shp_in
                M, _, kH, kW = W
                sy, sx = tuple(a.get("strides", (1, 1)))
                pt, pl, pb, pr = tuple(a.get("pads", (0, 0, 0, 0)))
                self.st[outs] = {"shape": (N, M, (H + pt + pb - kH) // sy + 1,
                                           (Wd + pl + pr - kW) // sx + 1), "qsrc": None}
            else:
                self.st[outs] = {"shape": None, "qsrc": None}
        elif op == "DequantizeLinear":
            src = ins[0]
            self.st[outs] = {"shape": shp_in, "qsrc": src}
        else:  # Relu / Softmax / QuantizeLinear
            self.st[outs] = {"shape": shp_in, "qsrc": None}

    def _check_gemm(self, n):
        ins = n["inputs"]
        if len(ins) < 2:
            self.err(f"{n['name']}: Gemm 缺输入")
            return
        A, B = self._shape(ins[0]), self._shape(ins[1])
        if B is None or len(B) != 2:
            self.err(f"{n['name']}: 权重形状 {B}")
            return
        out_dim, in_dim = B
        if int(n["attrs"].get("transB", 0)) != 1:
            self.warn(f"{n['name']}: transB != 1")
        if A and A[-1] != in_dim:
            self.err(f"{n['name']}: 输入 {A[-1]} 维 ≠ 权重输入 {in_dim}")
        if len(ins) > 2 and ins[2]:
            C = self._shape(ins[2])
            if C and int(np.prod(C)) != out_dim:
                self.err(f"{n['name']}: bias {C} ≠ 输出 {out_dim}")
        self.notes.append(f"Gemm {n['name']}: {in_dim}→{out_dim}")

    def _check_conv(self, n):
        ins = n["inputs"]
        if len(ins) < 2:
            self.err(f"{n['name']}: Conv 缺输入")
            return
        W = self._shape(ins[1])
        if W is None or len(W) != 4:
            self.err(f"{n['name']}: 卷积权重形状 {W}")
            return
        M, Cg, kH, kW = W
        q = self.st.get(ins[1], {}).get("qsrc")
        if q and q in self.inits and self.inits[q].dtype != np.uint8:
            self.err(f"{n['name']}: 量化权重 {q} dtype {self.inits[q].dtype}（应 uint8）")
        X = self._shape(ins[0])
        group = int(n["attrs"].get("group", 1))
        if X and len(X) == 4 and X[1] != Cg * group:
            self.err(f"{n['name']}: 输入通道 {X[1]} ≠ 权重 {Cg}×group {group}")
        if len(ins) > 2 and ins[2]:
            B = self._shape(ins[2])
            if B and int(np.prod(B)) != M:
                self.err(f"{n['name']}: bias {B} ≠ 输出通道 {M}")
        self.notes.append(f"Conv {n['name']}: 权重 {M}×{Cg}×{kH}×{kW} group={group} "
                          f"输出 {self._shape(n['outputs'][0])}")

    def _check_q(self, n):
        ins = n["inputs"]
        if len(ins) < 2:
            self.err(f"{n['name']}: {n['op']} 缺输入")
            return
        s = self.inits.get(ins[1])
        z = self.inits.get(ins[2]) if len(ins) > 2 else None
        if s is None:
            self.err(f"{n['name']}: 找不到 scale")
        else:
            if s.size != 1:
                self.err(f"{n['name']}: scale 非单元素 {s.shape}（本工程用 per-tensor）")
            if s.dtype != np.float32:
                self.err(f"{n['name']}: scale dtype {s.dtype}（应 float32）")
            if float(s.ravel()[0]) <= 0:
                self.err(f"{n['name']}: scale 非正")
        if z is not None and z.dtype not in (np.uint8, np.int32):
            self.err(f"{n['name']}: zero_point dtype {z.dtype}")


def main(argv=None) -> int:
    paths = argv if argv else sys.argv[1:]
    if not paths:
        paths = ["out/dcdc_npu.onnx", "out/dcdc_npu_qdq.onnx"]
    ok_all = True
    for p in paths:
        c = Checker(p)
        ok = c.run()
        ok_all &= ok
        print(f"[check] {p}: {'通过' if ok else '失败'}")
        for n in c.notes:
            print(f"    · {n}")
        for w in c.warns:
            print(f"    ! {w}")
        for e in c.errors:
            print(f"    × {e}")
    print(f"[check] 结论: {'全部通过' if ok_all else '有错误'}")
    return 0 if ok_all else 1


if __name__ == "__main__":
    sys.exit(main())
