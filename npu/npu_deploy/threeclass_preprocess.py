"""复现他们的三分类预处理，并用他们自己的向量验证（必须逐位一致）。

契约（src/threeclass_preprocess.hpp）：
    relative = (physical[t][c] - baseline[c]) / max(|baseline[c]|, floor[c])
    out[c*256+t] = (relative - mean[c]) / stddev[c]
    floors = [1.0, 0.05, 0.05]；physical 是 T,C 顺序（256 帧 × 3 通道）；baseline 是该 run 的“过去均值”

用法: python threeclass_preprocess.py <package_root>
"""

import os
import struct
import sys

import numpy as np

MEAN = np.array([-0.00164139201, 0.00973002799, -0.000640165294], dtype=np.float32)
STD = np.array([0.356568277, 0.371016115, 0.0256481692], dtype=np.float32)
FLOORS = np.array([1.0, 0.05, 0.05], dtype=np.float64)


def preprocess(physical_tc: np.ndarray, baseline: np.ndarray) -> np.ndarray:
    """physical_tc: (256,3) float32；baseline: (3,) float64 -> (3,256) float32。"""
    out = np.zeros((3, 256), dtype=np.float32)
    for c in range(3):
        denom = max(abs(baseline[c]), FLOORS[c])
        for t in range(256):
            value = np.float32(physical_tc[t, c])
            rel = np.float32((np.float64(value) - np.float64(baseline[c])) / denom)
            out[c, t] = np.float32((rel - MEAN[c]) / STD[c])
    return out


def main():
    pkg = sys.argv[1] if len(sys.argv) > 1 else r"D:\deepseek\work\_incoming\dcdc_npu_threeclass_image_20261027_v2"
    vec = os.path.join(pkg, "rootfs_overlay", "opt", "dcdc_npu_threeclass", "vectors")
    cases = [l.split()[0] for l in open(os.path.join(vec, "cases.txt"), encoding="utf-8") if l.strip()]

    exact = total = 0
    worst = 0.0
    for name in cases:
        phys = os.path.join(vec, f"{name}.physical_f32.bin")
        base = os.path.join(vec, f"{name}.baseline_f64.bin")
        ref = os.path.join(vec, f"{name}.input_f32.bin")
        if not (os.path.exists(phys) and os.path.exists(base) and os.path.exists(ref)):
            continue
        physical = np.frombuffer(open(phys, "rb").read(), dtype="<f4").reshape(256, 3)
        baseline = np.array(struct.unpack("<3d", open(base, "rb").read()))
        mine = preprocess(physical, baseline)
        theirs = np.frombuffer(open(ref, "rb").read(), dtype="<f4").reshape(3, 256)
        d = float(np.abs(mine.astype(np.float64) - theirs.astype(np.float64)).max())
        worst = max(worst, d)
        total += 1
        if np.array_equal(mine, theirs):
            exact += 1
    print(f"[pre] 复现 {total} 例：逐位一致 {exact}/{total}，最大绝对误差 {worst:.3e}")
    if exact == total:
        print("[pre] 结论：预处理契约已被复现，可以用真实采样生成模型输入")
    else:
        print("[pre] 结论：有偏差，需要检查 float32 舍入顺序")


if __name__ == "__main__":
    main()
