"""直接给板上 power_svc 发一帧 SET_SETPOINT（绕开 HMI，最省事）。

用法: python send_setpoint.py 24.0 [0.0]
"""

import socket
import sys

sys.path.insert(0, r"D:\deepseek\dcdc_hmi")
import protocol as P

BOARD = ("192.168.137.101", 5000)


def main():
    v = float(sys.argv[1]) if len(sys.argv) > 1 else 24.0
    i = float(sys.argv[2]) if len(sys.argv) > 2 else 0.0
    payload = P.pack_setpoint(v, i) if hasattr(P, "pack_setpoint") else None
    if payload is None:
        # protocol.py 没有 pack_setpoint 时，按 C 端结构手拼：float32 v_set, float32 i_set
        import struct
        payload = struct.pack("<ff", v, i)
    frame = P.build_frame(P.CMD_SET_SETPOINT, payload)
    s = socket.create_connection(BOARD, timeout=3.0)
    s.sendall(frame)
    print(f"[set] 发送 Vset={v:.2f} Iset={i:.2f} frame={frame.hex()}")
    s.close()


if __name__ == "__main__":
    main()
