"""把板上跑出来的 CSV 和 PC 侧期望结果对拍，判断部署是否「数值正确」。

板上输出（`dcdc_npu_demo -c ...` 的 stdout）：
    v_out,i_out,duty,class,p0,p1,p2,p3,ms

PC 期望（`make_board_test.py` 生成的 dcdc_board_test_expected.csv）：
    v_out,i_out,duty,label,p0,p1,p2,p3

判定标准：
    * 类别必须逐条一致（不一致就是接线/归一化/通道顺序错了）
    * 概率最大偏差：float32 模型对拍应 < 1e-4；量化模型（QDQ）会差千分之几，放宽到 5e-2
    * 时延统计只做记录，不设门槛（3 层小图，NPU 可能启动开销占主导）

用法:
    python compare_board_output.py board_out.csv out/dcdc_board_test_expected.csv [--tol 1e-4]
"""

from __future__ import annotations

import argparse
import csv
import sys


def read_rows(path, has_class_col=True):
    rows = []
    with open(path, newline="", encoding="utf-8-sig") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split(",")
            # 演示程序会多输出一列类别名（light/rated/...），逐列尝试转 float 并跳过非数字列
            vals = []
            for tok in parts:
                tok = tok.strip()
                try:
                    vals.append(float(tok))
                except ValueError:
                    continue
            if len(vals) < 8:
                continue          # 表头或日志行
            rows.append({"v": vals[0], "i": vals[1], "d": vals[2], "cls": int(vals[3]),
                         "p": vals[4:8], "ms": vals[8] if len(vals) > 8 else None})
    return rows


def main(argv=None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("board_csv")
    ap.add_argument("expected_csv")
    ap.add_argument("--tol", type=float, default=1e-4, help="概率最大允许偏差（QDQ 模型用 5e-2）")
    args = ap.parse_args(argv)

    board = read_rows(args.board_csv, has_class_col=True)
    exp = read_rows(args.expected_csv, has_class_col=False)
    if not board:
        print(f"[cmp] 没从 {args.board_csv} 读到样本行", file=sys.stderr)
        return 2
    n = min(len(board), len(exp))
    if len(board) != len(exp):
        print(f"[cmp] 行数不一致：板上 {len(board)} vs 期望 {len(exp)}，只比较前 {n} 行")

    cls_bad, max_dev, worst = 0, 0.0, -1
    lat = []
    for k in range(n):
        b, e = board[k], exp[k]
        dev = max(abs(b["p"][c] - e["p"][c]) for c in range(4))
        if dev > max_dev:
            max_dev, worst = dev, k
        if b["cls"] != e["cls"]:
            cls_bad += 1
            if cls_bad <= 5:
                print(f"[cmp] 类别不一致 行{k+1}: 板上 {b['cls']} vs 期望 {e['cls']} "
                      f"(V={b['v']:.3f} I={b['i']:.3f} D={b['d']:.2f})")
        if b["ms"] is not None:
            lat.append(b["ms"])

    print(f"[cmp] 比较 {n} 行：类别不一致 {cls_bad} 条，概率最大偏差 {max_dev:.3e}（行 {worst+1}）")
    if lat:
        lat.sort()
        print(f"[cmp] 板上单次推理时延: mean={sum(lat)/len(lat):.3f} ms  p50={lat[len(lat)//2]:.3f} ms  "
              f"min={lat[0]:.3f}  max={lat[-1]:.3f}")

    ok = (cls_bad == 0) and (max_dev <= args.tol)
    if not ok:
        if cls_bad:
            print("[cmp] 结论：类别有出入 —— 先查归一化除数（48/2.2/95）、输入顺序、模型是否换过")
        if max_dev > args.tol:
            print(f"[cmp] 结论：概率偏差超过阈值 {args.tol:g} —— 若用的是 QDQ 模型，先试 --tol 5e-2")
        return 1
    print("[cmp] 结论：通过（部署数值与 PC 一致）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
