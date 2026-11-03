"""独立核验别人交付的三分类 NPU 模型包（不依赖他们的脚本/证据）。

做三件事：
  1. 用我们自己的 numpy ONNX 解释器跑他们的 `condition_threeclass_uint8.onnx`；
  2. 拿他们的 `*.input_u8.bin` 当输入，和 `*.features_u8.bin` / `*.baseline_f64.bin` 对比；
  3. 检查模型契约里的 scale/zp 是否真能复现他们的 baseline。

用法: python verify_package.py <package_root>
"""

import json
import os
import struct
import sys

import numpy as np

sys.path.insert(0, r"D:\deepseek\work\npu_train")
import onnx_min as om

PKG = sys.argv[1] if len(sys.argv) > 1 else r"D:\deepseek\work\_incoming\dcdc_npu_threeclass_image_20261027_v2"
APP = os.path.join(PKG, "rootfs_overlay", "opt", "dcdc_npu_threeclass")
MODEL = os.path.join(APP, "models", "condition_threeclass_uint8.onnx")
VEC = os.path.join(APP, "vectors")


def load_cases():
    out = []
    with open(os.path.join(VEC, "cases.txt"), encoding="utf-8") as f:
        for line in f:
            parts = line.split()
            if len(parts) >= 4:
                out.append({"name": parts[0], "label": int(parts[1]), "split": parts[2]})
    return out


def main():
    m = om.read_model(open(MODEL, "rb").read())
    contract = json.load(open(os.path.join(APP, "models", "model_contract.json"), encoding="utf-8"))
    cases = load_cases()
    print(f"[verify] nodes={len(m['nodes'])} input={m['input_info'][0]['dims']} cases={len(cases)}")
    print(f"[verify] contract: input scale={contract['input']['scale']:.10f} zp={contract['input']['zero_point']}")

    # 契约里的输入量化参数 vs 图上 s0/z0 初始化器
    s0 = float(np.asarray(m["initializers"]["s0"]).ravel()[0])
    z0 = int(np.asarray(m["initializers"]["z0"]).ravel()[0])
    print(f"[verify] graph s0={s0:.10f} z0={z0} -> {'MATCH' if abs(s0 - contract['input']['scale']) < 1e-9 and z0 == contract['input']['zero_point'] else 'MISMATCH'}")

    n_feat_ok = n_cls_ok = n_run = 0
    n_base_ok = n_quant_ok = 0
    qmiss = []
    worst_feat = 0
    worst_score = 0.0
    misses = []
    for c in cases:
        u8_path = os.path.join(VEC, f"{c['name']}.input_u8.bin")
        feat_path = os.path.join(VEC, f"{c['name']}.features_u8.bin")
        base_path = os.path.join(VEC, f"{c['name']}.baseline_f64.bin")
        if not os.path.exists(u8_path):
            continue
        x = np.frombuffer(open(u8_path, "rb").read(), dtype=np.uint8).reshape(1, 3, 16, 16)
        y = om.run_model(m, {"input": x.astype(np.float64)})["logits"]
        logits = np.asarray(y).reshape(1, 16, 8, 8).astype(np.uint8)
        n_run += 1

        if os.path.exists(feat_path):
            ref = np.frombuffer(open(feat_path, "rb").read(), dtype=np.uint8).reshape(1, 16, 8, 8)
            d = int(np.abs(logits.astype(np.int16) - ref.astype(np.int16)).max())
            worst_feat = max(worst_feat, d)
            if d <= 2:
                n_feat_ok += 1

        # 类别：前 3 通道做 spatial max 再 argmax（契约里的 PS 后处理）
        scores = logits[0, :3].reshape(3, -1).max(axis=1).astype(float)
        pred = int(np.argmax(scores))

        # (a) 与标签比
        if pred == c["label"]:
            n_cls_ok += 1
        elif len(misses) < 6:
            misses.append((c["name"], f"pred={pred} label={c['label']}", scores.round(1).tolist()))

        # (b) 与 FP32 baseline 的 argmax 比（近似值，仅看是否翻转）
        if os.path.exists(base_path):
            ref_scores = struct.unpack("<3d", open(base_path, "rb").read())
            if pred == int(np.argmax(ref_scores)):
                n_base_ok += 1

        # (c) physical_f32 -> 按契约量化，是否等于 input_u8
        phys_path = os.path.join(VEC, f"{c['name']}.input_f32.bin")   # 归一化之后、量化之前的模型输入
        if os.path.exists(phys_path):
            phys = np.frombuffer(open(phys_path, "rb").read(), dtype="<f4").reshape(3, 16, 16)
            q = np.clip(np.rint(phys / s0) + z0, 0, 255).astype(np.uint8)
            if np.array_equal(q, x[0]):
                n_quant_ok += 1
            elif len(qmiss) < 4:
                qmiss.append((c["name"], int(np.abs(q.astype(int) - x[0].astype(int)).max())))

    print(f"[verify] ran {n_run} cases")
    print(f"[verify] (1) vs their features_u8: within 2 codes {n_feat_ok}/{n_run} (max {worst_feat})")
    print(f"[verify] (2) vs labels: {n_cls_ok}/{n_run} correct")
    print(f"[verify] (3) agree with FP32 baseline argmax: {n_base_ok}/{n_run} (borderline flips expected)")
    print(f"[verify] (4) quantize(input_f32) == input_u8: {n_quant_ok}/{n_run}"
          + (f", mismatches {qmiss}" if qmiss else ""))
    for x in misses:
        print("   differ:", x)
    print("[verify] note: independent recompute with our own interpreter; their binaries not used.")


if __name__ == "__main__":
    main()
