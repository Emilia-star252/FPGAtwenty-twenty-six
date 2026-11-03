"""从官方 armnn 库里捞字符串，尽量反推 Alnpu 后端支持哪些算子/有什么约束。

背景：SDK 没有 NPU 文档，但 `libarmnn.so.32.1` 里 Alnpu 后端是编译进去的，
类名/错误信息/注册表字符串会残留下来。只做只读分析，不改库。

用法: python inspect_alnpu.py [--lib path]
"""

from __future__ import annotations

import argparse
import os
import re
import sys

DEFAULT_LIB = os.path.join("_sdk", "app", "face_detection", "libs", "armnn_lib", "lib", "libarmnn.so.32.1")

LAYER_HINTS = [
    "Convolution", "DepthwiseConvolution", "FullyConnected", "Pooling", "Softmax",
    "Activation", "BatchNormalization", "Addition", "Multiplication", "Concat",
    "Resize", "Pad", "Permute", "Transpose", "Splitter", "Slice", "Merge",
    "Dequantize", "Quantize", "Mean", "Lstm", "Detection", "Constant",
]

INTEREST = re.compile(
    r"(alnpu|npu|unsupport|not support|support|fallback|fall back|layer|tensor|"
    r"quant|scale|zero.?point|shape|channel|align|wino|conv|gemm|matmul|fc\b|"
    r"cma|dma|irq|backend|fail|error)", re.I)


def strings(path, min_len=4):
    """粗暴版 strings：连续的可见 ASCII 就算一个字符串。"""
    out = []
    with open(path, "rb") as f:
        buf = f.read()
    cur = bytearray()
    for b in buf:
        if 32 <= b < 127:
            cur.append(b)
        else:
            if len(cur) >= min_len:
                out.append(cur.decode("ascii", "ignore"))
            cur.clear()
    if len(cur) >= min_len:
        out.append(cur.decode("ascii", "ignore"))
    return out


def main(argv=None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--lib", default=DEFAULT_LIB)
    ap.add_argument("--max-print", type=int, default=60)
    args = ap.parse_args(argv)

    if not os.path.exists(args.lib):
        print(f"[npu] 找不到 {args.lib}（先从 SDK tar 里解出来）", file=sys.stderr)
        return 2
    ss = strings(args.lib)
    print(f"[npu] {args.lib}: {os.path.getsize(args.lib)} B, 提取出 {len(ss)} 个字符串")

    # 1) Alnpu 相关
    aln = [s for s in ss if re.search(r"alnpu", s, re.I)]
    print(f"\n=== 含 'alnpu' 的字符串 {len(aln)} 条 ===")
    for s in aln[:args.max_print]:
        print("  ", s[:160])

    # 2) 各层类型出现次数
    print("\n=== 层类型字符串出现次数（说明这些层在库里有实现代码） ===")
    for hint in LAYER_HINTS:
        n = sum(1 for s in ss if s.strip() == hint)
        n2 = sum(1 for s in ss if hint.lower() in s.lower())
        print(f"  {hint:<24} 精确 {n:3d}   包含 {n2:4d}")

    # 3) 带 "support" 的判定/告警信息
    sup = [s for s in ss if re.search(r"support", s, re.I)]
    print(f"\n=== 含 'support' 的字符串 {len(sup)} 条（前 {args.max_print} 条） ===")
    for s in sup[:args.max_print]:
        print("  ", s[:170])

    # 4) 量化/形状约束相关的线索
    quant = [s for s in ss if re.search(r"(per.?channel|per.?tensor|zero.?point|scale.*factor|"
                                        r"quantiz)", s, re.I) and len(s) < 200]
    print(f"\n=== 量化相关 {len(quant)} 条（前 30 条） ===")
    for s in quant[:30]:
        print("  ", s[:170])
    return 0


if __name__ == "__main__":
    sys.exit(main())
