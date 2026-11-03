"""Demo capture (128 Hz): steady -> load step -> ring. Synthetic, for pipeline check only.
Used by scan_threeclass.py to show a class timeline.
"""

import math
import os
import random

FS = 128.0
PHASE = (0.0, 4.0, 8.0, 12.0)   # 稳态 / 阶跃 / 振荡 / 恢复
V_SET, V_BUS, I_LIM = 24.0, 24.0, 2.0


def main():
    rng = random.Random(11)
    v = d = 0.0
    rows = []
    n = int(PHASE[-1] * FS)
    for k in range(n):
        t = k / FS
        if t < PHASE[1]:
            r = 12.0
        elif t < PHASE[2]:
            r = 3.0            # 负载阶跃
        elif t < PHASE[3]:
            r = 3.0
        else:
            r = 12.0
        want = V_SET / r
        v_target = I_LIM * r if want > I_LIM else V_SET
        v += (v_target - v) * (1 - math.exp(-1 / FS / 0.004))
        d += (v / (V_BUS + v) * 100.0 - d) * (1 - math.exp(-1 / FS / 0.006))
        if PHASE[2] <= t < PHASE[3]:     # 8~12 s 人为加一段持续振荡
            v += 1.8 * math.sin(2 * math.pi * 7.0 * (t - PHASE[2]))
        i = v / r
        rows.append((t, v * (1 + rng.uniform(-0.002, 0.002)), i * (1 + rng.uniform(-0.002, 0.002)), d))

    outdir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")
    os.makedirs(outdir, exist_ok=True)
    path = os.path.join(outdir, "cap_phases.csv")
    with open(path, "w", encoding="utf-8") as f:
        f.write("uptime_s,v_out,i_out,duty\n")
        for t, vv, ii, dd in rows:
            f.write(f"{t:.4f},{vv:.4f},{ii:.5f},{dd:.3f}\n")
    print(f"[gen] {path}  {len(rows)} rows @ {FS:.0f} Hz (steady 4s -> step 4s -> ring 4s)")


if __name__ == "__main__":
    main()
