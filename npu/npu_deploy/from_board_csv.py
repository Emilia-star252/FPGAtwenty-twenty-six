"""把上位机/板卡的运行日志 CSV 转成训练集格式（真实数据到位后用这个）。

输入表头（host.py / sim_board.py 的日志）：
    timestamp,uptime_s,v_out,i_out,duty,v_set,i_set,flags,fault

输出表头（与 gen_dataset.py 一致，train.py 直接吃）：
    trial_id,vin,vset,r_mean,v_mean,i_mean,d_mean,v_std,i_std,d_std,
    v_last,i_last,d_last,fault_code,label,class_name

标注规则与仿真脚本相同（只看真值/日志字段，不看模型输入）：
    fault != 0                      -> 3 保护故障
    i_mean > 0.90 * I_LIM           -> 2 重载/近限流
    i_mean > 0.35 * I_LIM           -> 1 正常-额定
    其他                            -> 0 正常-轻载

注意：
* 日志采样率是 1 Hz 时，窗口默认 10 点 = 10 s，与仿真的 100 ms 窗口在时间尺度上不同，
  真实模型要按日志采样率重新训练（脚本会自动把窗口长度写进 meta）。
* 输出关闭（v_set<1 且无故障）的行会被跳过，因为它们既不是工况也不是故障。
"""

from __future__ import annotations

import argparse
import csv
import glob
import math
import os
import sys

I_LIM = 2.0
CLASS_NAMES = ["正常-轻载", "正常-额定", "重载-近限流", "保护故障"]
OUT_HEADER = ("trial_id,vin,vset,r_mean,v_mean,i_mean,d_mean,v_std,i_std,d_std,"
              "v_last,i_last,d_last,fault_code,label,class_name").split(",")
FAULT_TEXT = {0: "none", 1: "OVP", 2: "OCP", 3: "OTP", 4: "ADC", 5: "OVERRUN"}


def label_of(i_mean: float, fault: int) -> int:
    if fault:
        return 3
    if i_mean > 0.90 * I_LIM:
        return 2
    if i_mean > 0.35 * I_LIM:
        return 1
    return 0


def rows_of(path: str):
    with open(path, newline="", encoding="utf-8-sig") as f:
        for row in csv.DictReader(f):
            try:
                yield (float(row["v_out"]), float(row["i_out"]), float(row["duty"]),
                       float(row.get("v_set") or 0.0), int(float(row.get("fault") or 0)))
            except (KeyError, ValueError):
                continue


def convert(path: str, trial_base: int, window: int, block: int = 20):
    """一个日志文件切成若干「试验组」（每 block 个窗口一组），供按组划分训练/测试。"""
    out = []
    buf = []
    for v, i, d, vset, fault in rows_of(path):
        if vset < 1.0 and fault == 0:      # 输出关断，不是工况样本
            continue
        buf.append((v, i, d, vset, fault))
        if len(buf) < window:
            continue
        w = buf[-window:]
        vs = [x[0] for x in w]
        iss = [x[1] for x in w]
        ds = [x[2] for x in w]
        v_mean = sum(vs) / len(vs)
        i_mean = sum(iss) / len(iss)
        d_mean = sum(ds) / len(ds)
        f = w[-1][4]
        lab = label_of(i_mean, f)
        std = lambda a, m: math.sqrt(sum((x - m) ** 2 for x in a) / len(a))
        group = trial_base + len(out) // max(1, block)
        out.append([group, 0.0, w[-1][3], v_mean / max(i_mean, 1e-6),
                    v_mean, i_mean, d_mean, std(vs, v_mean), std(iss, i_mean), std(ds, d_mean),
                    vs[-1], iss[-1], ds[-1], FAULT_TEXT.get(f, str(f)), lab,
                    CLASS_NAMES[lab].replace(",", " ")])
    return out


def main(argv=None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("inputs", nargs="+", help="日志 CSV（支持通配符），如 'logs/*.csv'")
    ap.add_argument("--out", default=os.path.join("out", "dataset_board.csv"))
    ap.add_argument("--window", type=int, default=10, help="窗口点数；1 Hz 日志默认 10 点 = 10 s")
    args = ap.parse_args(argv)

    paths = []
    for pat in args.inputs:
        paths.extend(sorted(glob.glob(pat)) or [pat])
    rows, base = [], 0
    for p in paths:
        if not os.path.exists(p):
            print(f"[board-csv] 跳过不存在的文件: {p}")
            continue
        r = convert(p, base, args.window)
        base += len(r)
        print(f"[board-csv] {p}: {len(r)} 个窗口")
        rows.extend(r)

    if not rows:
        print("[board-csv] 没有产生样本：日志里可能全是输出关断状态，或表头不匹配", file=sys.stderr)
        return 1

    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    with open(args.out, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(OUT_HEADER)
        w.writerows(rows)

    counts = [0, 0, 0, 0]
    for r in rows:
        counts[r[14]] += 1
    print(f"[board-csv] 写出 {args.out}  共 {len(rows)} 条（窗口 {args.window} 点）")
    for c, n in enumerate(counts):
        print(f"   class {c} {CLASS_NAMES[c]:<10} {n}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
