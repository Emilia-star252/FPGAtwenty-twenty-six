"""真实电压阶跃实验：采集(peek) + 改给定 + 扫描类别。

流程：
  1. restart power_svc（清掉可能残留的半开连接，它只接受一个客户端）
  2. 板上后台起 fdma_capture --peek（不抢 FDMA 消费权），采集 28 s
  3. 第 8 秒把给定 24 V -> 12 V，第 18 秒恢复 24 V
  4. 拉回 CSV，扫类别时间线

用法: python vstep_experiment.py [--dur 28] [--v1 24] [--v2 12]
"""

import argparse
import socket
import subprocess
import sys
import time

sys.path.insert(0, r"D:\deepseek\dcdc_hmi")
import protocol as P   # noqa: E402

PLINK = r"D:\FPGA\PuTTY\plink.exe"
PSCP = r"D:\FPGA\PuTTY\pscp.exe"
PY = sys.executable
BOARD = "192.168.137.101"


def sh(cmd, timeout=90):
    return subprocess.run([PLINK, "-ssh", "-batch", "-pw", "root", f"root@{BOARD}", cmd],
                          capture_output=True, text=True, encoding="utf-8", errors="replace",
                          timeout=timeout)


def set_point(v_set, i_set=0.0, retries=3):
    frame = P.build_frame(P.CMD_SET_SETPOINT, P.pack_setpoint(v_set, i_set))
    for k in range(retries):
        try:
            s = socket.create_connection((BOARD, 5000), timeout=3.0)
            s.sendall(frame)
            s.close()
            print(f"[exp] setpoint -> Vset={v_set:.2f} V  Iset={i_set:.2f} A")
            return True
        except OSError as e:
            print(f"[exp] 连接失败（{e}），{k+1}/{retries}")
            time.sleep(1.0)
    return False


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dur", type=float, default=28)
    ap.add_argument("--v1", type=float, default=24)
    ap.add_argument("--v2", type=float, default=12)
    ap.add_argument("--out", default="/root/data/cap_vstep.csv")
    args = ap.parse_args()

    print(sh("/etc/init.d/S99power restart; sleep 2; echo restarted").stdout.strip())
    time.sleep(1.0)
    set_point(args.v1)
    time.sleep(1.0)

    cmd = (f"nohup /opt/npu/tc/fdma_capture --out {args.out} --hz 128 "
           f"--duration {args.dur:.0f} --peek 256 > /tmp/cap_exp.log 2>&1 &")
    sh(cmd, timeout=10)
    print("[exp] capture started on board (peek mode)")
    time.sleep(8.0)

    set_point(args.v2)
    time.sleep(10.0)
    set_point(args.v1)
    time.sleep(max(2.0, args.dur - 19.0))

    print(sh("tail -2 /tmp/cap_exp.log").stdout.strip())
    print(sh(f"wc -l {args.out}").stdout.strip())

    local = r"D:\deepseek\work\npu_train\out\cap_vstep.csv"
    subprocess.run([PSCP, "-pw", "root", "-batch", f"root@{BOARD}:{args.out}", local], check=False)
    print("[exp] pulled:", local)
    subprocess.run([PY, r"D:\deepseek\work\npu_train\scan_threeclass.py",
                    "--csv", local, "--rate", "98", "--hop", "0.5"], check=False)


if __name__ == "__main__":
    main()
