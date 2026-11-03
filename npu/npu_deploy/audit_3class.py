"""看交付包的三分类模型：u8 量化 vs FP32 的偏差到底有多大、翻转的样本是不是都在边界上。

结论用于判断「量化后 15/46 与 FP32 argmax 不一致」是良性边界还是真退化。
"""

import json
import os
import struct
import sys

import numpy as np

sys.path.insert(0, r"D:\deepseek\work\npu_train")
import onnx_min as om

PKG = r"D:\deepseek\work\_incoming\dcdc_npu_threeclass_image_20261027_v2"
APP = os.path.join(PKG, "rootfs_overlay", "opt", "dcdc_npu_threeclass")
VEC = os.path.join(APP, "vectors")
MODEL = os.path.join(APP, "models", "condition_threeclass_uint8.onnx")


def main():
    m = om.read_model(open(MODEL, "rb").read())
    cases = [l.split() for l in open(os.path.join(VEC, "cases.txt"), encoding="utf-8") if l.strip()]

    rows = []
    for parts in cases:
        name, label = parts[0], int(parts[1])
        u8 = os.path.join(VEC, f"{name}.input_u8.bin")
        base = os.path.join(VEC, f"{name}.baseline_f64.bin")
        if not (os.path.exists(u8) and os.path.exists(base)):
            continue
        x = np.frombuffer(open(u8, "rb").read(), dtype=np.uint8).reshape(1, 3, 16, 16)
        logits = np.asarray(om.run_model(m, {"input": x.astype(np.float64)})["logits"]).reshape(16, 8, 8).astype(np.uint8)
        u8_scores = logits[:3].reshape(3, -1).max(axis=1).astype(float)
        f32 = np.array(struct.unpack("<3d", open(base, "rb").read()))
        rows.append({"name": name, "label": label, "u8": u8_scores, "f32": f32,
                     "pu": int(np.argmax(u8_scores)), "pf": int(np.argmax(f32))})

    n = len(rows)
    acc_u8 = sum(r["pu"] == r["label"] for r in rows) / n
    acc_f32 = sum(r["pf"] == r["label"] for r in rows) / n
    flips = [r for r in rows if r["pu"] != r["pf"]]
    print(f"[audit] 用例 {n}；FP32 准确率 {acc_f32:.1%}；UINT8 准确率 {acc_u8:.1%}；argmax 翻转 {len(flips)}/{n}")

    margins = []
    for r in flips:
        s = np.sort(r["f32"])[::-1]
        margins.append(float(s[0] - s[1]))
    if margins:
        margins.sort()
        print(f"[audit] 翻转样本的 FP32 top1-top2 间隔: 中位 {np.median(margins):.4f}，"
              f"最大 {max(margins):.4f}，>0.1 的有 {sum(m > 0.1 for m in margins)} 个")
        for r in sorted(flips, key=lambda r: -(np.sort(r["f32"])[::-1][0] - np.sort(r["f32"])[::-1][1]))[:5]:
            s = np.sort(r["f32"])[::-1]
            print(f"   {r['name']}: FP32 {np.round(r['f32'],3)} (间隔 {s[0]-s[1]:.4f}) -> u8 {r['u8']} "
                  f"u8类={r['pu']} f32类={r['pf']} 标签={r['label']}")

    # 各类别的 FP32 间隔分布（看模型本身有多自信）
    print("[audit] 每个样本的 FP32 间隔中位数: "
          f"{np.median([np.sort(r['f32'])[::-1][0] - np.sort(r['f32'])[::-1][1] for r in rows]):.4f}")
    # 类别分布
    from collections import Counter
    print("[audit] 标签分布:", dict(Counter(r["label"] for r in rows)))


if __name__ == "__main__":
    main()
