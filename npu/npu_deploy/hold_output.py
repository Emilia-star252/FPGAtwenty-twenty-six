"""保持一个 TCP 连接不短，持续下发 输出开 + 24V，期间打印服务回帧。

用途：验证 power_svc 是否在「上位机断开」或「无心跳」时把输出关掉。
用法: python hold_output.py [秒数] [电压]
"""

import socket
import sys
import time

sys.path.insert(0, r"D:\deepseek\dcdc_hmi")
import protocol as P

BOARD = ("192.168.137.101", 5000)


def main():
    dur = float(sys.argv[1]) if len(sys.argv) > 1 else 10.0
    v = float(sys.argv[2]) if len(sys.argv) > 2 else 24.0
    try:
        s = socket.create_connection(BOARD, timeout=3.0)
    except OSError as e:
        print("connect failed:", e)
        return 1
    s.setblocking(False)
    parser = P.FrameParser()

    def send(cmd, payload, tag):
        s.sendall(P.build_frame(cmd, payload))
        print("->", tag)

    send(P.CMD_SET_OUTPUT, P.pack_byte(1), "output=on")
    send(P.CMD_SET_SETPOINT, P.pack_setpoint(v, 2.0), f"setpoint {v}V")

    t0 = time.time()
    n = 0
    frames = 0
    while time.time() - t0 < dur:
        if int(time.time() - t0) != n:
            n = int(time.time() - t0)
            send(P.CMD_HEARTBEAT, b"", f"heartbeat {n}s")
            send(P.CMD_READ_STATUS, b"", "read_status")
        try:
            d = s.recv(512)
            if d:
                parser.push(d) if hasattr(parser, "push") else None
                frames += len(d)
        except BlockingIOError:
            pass
        except OSError:
            break
        time.sleep(0.05)
    print(f"held {dur:.0f}s, received {frames} bytes")
    s.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
