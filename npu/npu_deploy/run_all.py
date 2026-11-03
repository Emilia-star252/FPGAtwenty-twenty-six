"""一条命令重跑整条 PC 侧链路：仿真数据 -> 训练 -> ONNX 导出 -> 板端自测 CSV -> 报告。

    python run_all.py --trials 2400 --epochs 600
"""

from __future__ import annotations

import argparse
import subprocess
import sys
import time

import gen_dataset
import export_onnx
import export_onnx_qdq
import make_board_test
import make_report
import quantize_sim
import robustness_test
import train
import validate_onnx


def main(argv=None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--trials", type=int, default=2400)
    ap.add_argument("--epochs", type=int, default=600)
    ap.add_argument("--seed", type=int, default=20261026)
    ap.add_argument("--skip-gen", action="store_true", help="复用已有 out/dataset.csv")
    args = ap.parse_args(argv)

    steps = []
    if not args.skip_gen:
        steps.append(("生成数据集", lambda: gen_dataset.main(["--trials", str(args.trials),
                                                             "--out", "out/dataset.csv",
                                                             "--seed", str(args.seed)])))
    steps += [
        ("训练", lambda: train.main(["--csv", "out/dataset.csv", "--out", "out/model.npz",
                                     "--epochs", str(args.epochs)])),
        ("导出 ONNX", lambda: export_onnx.main(["--model", "out/model.npz", "--outdir", "out"])),
        ("导出 QDQ(1x1 Conv)", lambda: export_onnx_qdq.main(["--model", "out/model.npz",
                                                             "--csv", "out/dataset.csv",
                                                             "--outdir", "out"])),
        ("导出 QDQ 补零变体 8x4", lambda: export_onnx_qdq.main(["--model", "out/model.npz",
                                                               "--csv", "out/dataset.csv",
                                                               "--outdir", "out",
                                                               "--name", "dcdc_npu_qdq_8x4",
                                                               "--pad-c", "8", "--pad-hw", "4"])),
        # 板上硬 NPU 实际跑通的那一版（见 out/BOARD_EVIDENCE.md）
        ("导出 NPU 版 (8ch/4x4/3x3/ReLU-on-quant)", lambda: export_onnx_qdq.main([
            "--model", "out/model.npz", "--csv", "out/dataset.csv", "--outdir", "out",
            "--name", "dcdc_rq", "--pad-c", "8", "--pad-hw", "4", "--kernel", "3",
            "--q-after-conv", "--relu-on-quant", "--u8-logits"])),
        ("量化仿真", lambda: quantize_sim.main(["--model", "out/model.npz", "--csv", "out/dataset.csv",
                                                "--out", "out/quant_report.json"])),
        ("ONNX 结构自检", lambda: validate_onnx.main(["out/dcdc_npu.onnx", "out/dcdc_npu_qdq.onnx",
                                                     "out/dcdc_npu_qdq_8x4.onnx", "out/dcdc_rq.onnx"])),
        ("鲁棒性测试", lambda: robustness_test.main(["--model", "out/model.npz", "--csv", "out/dataset.csv",
                                                    "--out", "out/robustness.json"])),
        ("生成板端自测集", lambda: make_board_test.main(["--dataset", "out/dataset.csv",
                                                         "--n", "200", "--out", "out/dcdc_board_test.csv"])),
        ("汇总报告", lambda: make_report.main([])),
    ]

    t_all = time.time()
    for name, fn in steps:
        t0 = time.time()
        print(f"\n=== {name} ===")
        rc = fn()
        print(f"--- {name}: {'OK' if rc == 0 else 'FAIL(%d)' % rc}  {time.time() - t0:.1f}s")
        if rc != 0:
            return rc
    print(f"\n[all] 完成，总耗时 {time.time() - t_all:.1f}s；看 out/RESULTS.md")
    return 0


if __name__ == "__main__":
    sys.exit(main())
