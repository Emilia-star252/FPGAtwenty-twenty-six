"""生成带标注的 DC-DC 工况训练集。

用法:
    python gen_dataset.py --trials 2000 --out out/dataset.csv --seed 20261026

输出 CSV 列见 dcdc_sim.CSV_HEADER。真实数据到位后，只要把列名对齐
(v_mean / i_mean / d_mean / label / trial_id)，train.py 可以直接吃真实数据。
"""

from __future__ import annotations

import argparse
import csv
import os
import random
import statistics
import sys

import dcdc_sim as sim


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="DR1M90 DC-DC 工况数据集生成（物理仿真）")
    ap.add_argument("--trials", type=int, default=2000, help="试验条数（每条约 420 ms 仿真）")
    ap.add_argument("--out", default=os.path.join("out", "dataset.csv"))
    ap.add_argument("--seed", type=int, default=20261026)
    args = ap.parse_args(argv)

    rng = random.Random(args.seed)
    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)

    trials = [sim.make_trial(i, rng) for i in range(args.trials)]

    with open(args.out, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(sim.CSV_HEADER.split(","))
        for t in trials:
            w.writerow(sim.row_of(t).split(","))

    counts = [0, 0, 0, 0]
    faults = {}
    for t in trials:
        counts[t.label] += 1
        if t.fault_code != "none":
            faults[t.fault_code] = faults.get(t.fault_code, 0) + 1

    print(f"[gen] 写出 {len(trials)} 条 -> {args.out}")
    for i, name in enumerate(sim.CLASS_NAMES):
        print(f"  class {i} {name:<12} {counts[i]:5d}")
    print(f"  故障类型分布: {faults}")
    print(f"  电压范围 {min(t.v_mean for t in trials):.2f}..{max(t.v_mean for t in trials):.2f} V")
    print(f"  电流范围 {min(t.i_mean for t in trials):.3f}..{max(t.i_mean for t in trials):.3f} A")
    print(f"  占空比范围 {min(t.d_mean for t in trials):.2f}..{max(t.d_mean for t in trials):.2f} %")

    # 规则基线：只用 I 阈值就能分对多少（说明合成数据的可分性，避免误读模型精度）
    hits = sum(1 for t in trials if t.label != 3 and
               ((t.i_mean <= 0.35 * sim.I_LIM and t.label == 0) or
                (0.35 * sim.I_LIM < t.i_mean <= 0.90 * sim.I_LIM and t.label == 1) or
                (t.i_mean > 0.90 * sim.I_LIM and t.label == 2)))
    print(f"  参考：I 阈值规则在非故障类上的命中率 {hits / max(1, sum(1 for t in trials if t.label != 3)) * 100:.1f}%")
    return 0


if __name__ == "__main__":
    sys.exit(main())
