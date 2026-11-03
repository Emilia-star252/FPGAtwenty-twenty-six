"""生成一段「像板卡采样」的演示 CSV（128 Hz，带负载阶跃 + 轻微振荡），用来验证
   CSV -> 模型输入 -> 板上推理 这条链路。**不是真实测量数据**，只用于跑通流程。
"""

import math
import random

FS = 128.0
T = 3.0
V_SET = 24.0
V_BUS = 24.0
R0, R1 = 12.0, 3.0
I_LIM = 2.0


def main():
    rng = random.Random(7)
    v = 0.0
    d = 0.0
    rows = []
    n = int(T * FS)
    for k in range(n):
        t = k / FS
        r = R0 if t < 1.5 else R1
        want = V_SET / r
        v_target = I_LIM * r if want > I_LIM else V_SET
        v += (v_target - v) * (1 - math.exp(-1 / FS / 0.004))
        d += (v / (V_BUS + v) * 100.0 - d) * (1 - math.exp(-1 / FS / 0.006))
        # 阶跃后的衰减振荡（模拟环路响应），只在 1.5 s 之后
        if t >= 1.5:
            v += 0.35 * math.sin(2 * math.pi * 6.0 * (t - 1.5)) * math.exp(-(t - 1.5) / 0.4)
        i = v / r
        rows.append((t, v * (1 + rng.uniform(-0.002, 0.002)), i * (1 + rng.uniform(-0.002, 0.002)), d))

    with open("out/cap_step.csv", "w", encoding="utf-8") as f:
        f.write("uptime_s,v_out,i_out,duty\n")
        for t, vv, ii, dd in rows:
            f.write(f"{t:.4f},{vv:.4f},{ii:.5f},{dd:.3f}\n")
    print(f"[gen] out/cap_step.csv  {len(rows)} 行 @ {FS:.0f} Hz（合成信号，仅用于链路验证）")


if __name__ == "__main__":
    main()
