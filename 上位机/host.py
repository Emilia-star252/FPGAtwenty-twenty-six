# -*- coding: utf-8 -*-
"""
host.py —— DC-DC 电源控制板【PC 上位机】

同一套界面/逻辑，三种传输方式（都实现 open/close/write/read 四个方法）：
    SerialTransport  真实串口（pyserial），以后接真实板卡用
    TcpTransport     网络透传，连 sim_board.py 的 TCP 服务端，或以后的串口服务器
    SimTransport     进程内嵌模拟板卡，一条命令就能演完整套（默认）

用法示例
--------------------------------------------------------------------------
    python host.py --sim                      # 图形界面 + 进程内模拟板卡（默认）
    python host.py --sim --cli --duration 6   # 命令行模式，跑 6 秒自动退出
    python host.py --tcp 127.0.0.1:5560       # 连另一台机器/另一个进程里的模拟板卡
    python host.py --port COM7 --baud 115200  # 接真实串口板卡
    python host.py --list-ports               # 列出本机串口
    python host.py --sim --gui-selftest       # 无头自检：建窗口->刷新几次->销毁

设计要点
--------------------------------------------------------------------------
* 界面永不阻塞：串口/TCP 读取在独立线程里做，写命令走发送队列由该线程统一写出，
  这样 GUI 线程只管画界面，卡住的串口不会让窗口假死
* GUI 用 after() 定时轮询：默认 5Hz 发 READ_STATUS，1Hz 发 HEARTBEAT
* 断开/重连自动处理：链路断了会在界面上显示"连接断开"，读线程按退避策略自动重连，
  也可以点"重连"按钮手动触发
* 上位机侧也存一份 CSV 日志（默认开，文件名带时间戳）
"""

from __future__ import annotations

import argparse
import socket
import sys
import threading
import time
from collections import deque
from datetime import datetime

from protocol import (
    ACK_TEXTS, CMD_ACK, CMD_CLEAR_FAULT, CMD_HEARTBEAT, CMD_NACK, CMD_NAMES,
    CMD_READ_STATUS, CMD_SET_OUTPUT, CMD_SET_SETPOINT, CMD_SET_TIME, CMD_STATUS,
    CMD_TEXT, FAULT_NONE, FLAG_HOST_ONLINE, FLAG_LOG_OK, FLAG_OUTPUT_EN, FLAG_OVP,
    FLAG_OCP, FLAG_OTP, FrameParser, ProtocolError, build_frame,
    decode_status, decode_text, pack_byte, pack_setpoint, pack_time, unpack_byte,
)
from sim_board import CsvLogger, SimBoard

# pyserial 是可选的：没装也能跑 --sim / --tcp，只是不能用真实串口
try:
    import serial                                   # type: ignore
    from serial.tools import list_ports as _list_ports   # type: ignore
    SERIAL_AVAILABLE = True
    SERIAL_IMPORT_ERROR = ""
except Exception as _exc:                           # noqa: BLE001
    serial = None
    _list_ports = None
    SERIAL_AVAILABLE = False
    SERIAL_IMPORT_ERROR = str(_exc)

SERIAL_MISSING_HINT = ("未安装 pyserial，无法使用串口：请先 pip install pyserial，"
                       "或改用 --sim / --tcp。")

__all__ = ["SerialTransport", "TcpTransport", "SimTransport", "HostCore",
           "main", "SERIAL_AVAILABLE"]


# ===========================================================================
# 传输层：三种实现，接口一致 open/close/write/read
# ===========================================================================

class TransportError(Exception):
    """传输层错误（打开失败、链路断开等）。"""


class BaseTransport:
    """传输接口约定。子类必须实现 open/close/write/read。"""

    name = "base"

    def __init__(self) -> None:
        self.is_open = False

    def open(self) -> None:
        raise NotImplementedError

    def close(self) -> None:
        raise NotImplementedError

    def write(self, data: bytes) -> None:
        raise NotImplementedError

    def read(self, max_n: int = 4096) -> bytes:
        """返回收到的字节；没有数据时返回 b""（不要长时间阻塞）。"""
        raise NotImplementedError

    def describe(self) -> str:
        return self.name


# ---------------------------------------------------------------------------
class SerialTransport(BaseTransport):
    """真实串口（需要 pyserial）。"""

    name = "串口"

    def __init__(self, port: str, baud: int = 115200, timeout: float = 0.05) -> None:
        super().__init__()
        self.port = port
        self.baud = int(baud)
        self.timeout = float(timeout)
        self._ser = None

    def describe(self) -> str:
        return "串口 %s @ %d" % (self.port, self.baud)

    def open(self) -> None:
        if not SERIAL_AVAILABLE:
            raise TransportError(SERIAL_MISSING_HINT)
        try:
            self._ser = serial.Serial(self.port, self.baud,
                                      timeout=self.timeout, write_timeout=1.0)
        except Exception as exc:                     # noqa: BLE001
            raise TransportError("打开串口 %s 失败：%s\n（串口可能不存在、被其他程序占用，"
                                 "或没有权限）" % (self.port, exc))
        self.is_open = True

    def close(self) -> None:
        self.is_open = False
        if self._ser is not None:
            try:
                self._ser.close()
            except Exception:
                pass
            self._ser = None

    def write(self, data: bytes) -> None:
        if self._ser is None:
            raise TransportError("串口未打开")
        try:
            self._ser.write(data)
        except Exception as exc:                     # noqa: BLE001
            self.is_open = False
            raise TransportError("串口写入失败：%s" % exc)

    def read(self, max_n: int = 4096) -> bytes:
        if self._ser is None:
            raise TransportError("串口未打开")
        try:
            # timeout 已设成 50ms，所以最多阻塞 50ms 就返回，不会卡住读线程
            buf = self._ser.read(min(max_n, 512))
        except Exception as exc:                     # noqa: BLE001
            self.is_open = False
            raise TransportError("串口读取失败（可能已被拔出）：%s" % exc)
        # 把缓冲区里已有的数据一次取完，减少帧被拆开的机会
        try:
            waiting = self._ser.in_waiting
        except Exception:
            waiting = 0
        if waiting:
            try:
                buf += self._ser.read(min(waiting, max_n - len(buf)))
            except Exception as exc:                 # noqa: BLE001
                self.is_open = False
                raise TransportError("串口读取失败：%s" % exc)
        return buf


# ---------------------------------------------------------------------------
class TcpTransport(BaseTransport):
    """TCP 客户端：连模拟板卡，或以后的串口服务器/网络透传模块。"""

    name = "TCP"

    def __init__(self, host: str, port: int, connect_timeout: float = 3.0,
                 read_timeout: float = 0.05) -> None:
        super().__init__()
        self.host = host
        self.port = int(port)
        self.connect_timeout = float(connect_timeout)
        self.read_timeout = float(read_timeout)
        self._sock = None

    def describe(self) -> str:
        return "TCP %s:%d" % (self.host, self.port)

    def open(self) -> None:
        try:
            self._sock = socket.create_connection((self.host, self.port),
                                                  timeout=self.connect_timeout)
            self._sock.settimeout(self.read_timeout)
            self._sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        except OSError as exc:
            self._sock = None
            raise TransportError("连接 %s:%d 失败：%s" % (self.host, self.port, exc))
        self.is_open = True

    def close(self) -> None:
        self.is_open = False
        if self._sock is not None:
            try:
                self._sock.close()
            except OSError:
                pass
            self._sock = None

    def write(self, data: bytes) -> None:
        if self._sock is None:
            raise TransportError("TCP 未连接")
        try:
            self._sock.sendall(data)
        except OSError as exc:
            self.is_open = False
            raise TransportError("TCP 发送失败：%s" % exc)

    def read(self, max_n: int = 4096) -> bytes:
        if self._sock is None:
            raise TransportError("TCP 未连接")
        try:
            data = self._sock.recv(max_n)
        except socket.timeout:
            return b""                               # 读超时属于正常情况
        except OSError as exc:
            self.is_open = False
            raise TransportError("TCP 接收失败：%s" % exc)
        if not data:
            self.is_open = False
            raise TransportError("TCP 连接已被对端关闭")
        return data


# ---------------------------------------------------------------------------
class SimTransport(BaseTransport):
    """进程内嵌模拟板卡：不需要串口、不需要第二个窗口，一条命令演完整套。

    write() 把字节喂给 SimBoard，read() 先按真实时间推进物理模型，
    再把"应答 + 板卡主动推送"一起返回。
    """

    name = "内置模拟"

    def __init__(self, v_set: float = 12.0, i_set: float = 5.0,
                 board_csv: str = None, push_period: float = 1.0,
                 seed: int = None) -> None:
        super().__init__()
        self.v_set = v_set
        self.i_set = i_set
        self.board_csv = board_csv
        self.push_period = push_period
        self.seed = seed
        self.board = None
        self._inbox = bytearray()
        self._pending = bytearray()
        self._last_tick = time.monotonic()

    def describe(self) -> str:
        extra = ""
        if self.board is not None:
            extra = "（母线 %.0fV，负载 %.0fΩ）" % (self.board.v_bus, self.board.r_load_base)
        return "内置模拟板卡" + extra

    def open(self) -> None:
        # 重连时保留板卡状态（模拟"板卡一直在跑，只是上位机重连"）
        if self.board is None:
            logger = None
            if self.board_csv:
                logger = CsvLogger(self.board_csv)
            self.board = SimBoard(v_set=self.v_set, i_set=self.i_set,
                                  push_period=self.push_period, csv_logger=logger,
                                  seed=self.seed)
        self._last_tick = time.monotonic()
        self.is_open = True

    def close(self) -> None:
        self.is_open = False
        self._inbox.clear()
        self._pending.clear()

    def write(self, data: bytes) -> None:
        if self.board is None:
            raise TransportError("模拟板卡未初始化")
        self._inbox += self.board.feed(data)

    def read(self, max_n: int = 4096) -> bytes:
        if self.board is None:
            raise TransportError("模拟板卡未初始化")
        now = time.monotonic()
        dt = now - self._last_tick
        self._last_tick = now
        if dt > 0.2:                                 # 线程被饿久了也不让物理模型跳变
            dt = 0.2
        self.board.tick(dt)
        self.board.maybe_push_status(now)
        self._pending += self._inbox
        self._inbox.clear()
        self._pending += self.board.take_async()
        if not self._pending:
            return b""
        if len(self._pending) <= max_n:
            out = bytes(self._pending)
            self._pending.clear()
            return out
        out = bytes(self._pending[:max_n])
        del self._pending[:max_n]
        return out

    def board_summary(self) -> str:
        return self.board.summary() if self.board is not None else ""


# ===========================================================================
# 上位机核心：收发线程 + 帧解析 + 事件队列
# ===========================================================================

class HostCore:
    """协议收发核心。界面（GUI/CLI）只跟它打交道，不直接碰 socket/串口。

    线程模型：
        读线程  ---- 负责 write() 发送队列 + read() 收数据 + 解析 + 入事件队列
        界面线程 ---- 调用 send_xxx() 往队列里放命令；drain_events() 取事件更新界面
    """

    def __init__(self, transport: BaseTransport, csv_logger: CsvLogger = None,
                 auto_reconnect: bool = True) -> None:
        self.transport = transport
        self.csv = csv_logger
        self.auto_reconnect = auto_reconnect

        self.parser = FrameParser()

        self.events = deque()
        self.stats = {"tx": 0, "rx": 0, "status": 0, "text": 0, "ack": 0,
                      "nack": 0, "other": 0, "reconnects": 0, "errors": 0}
        self.status = None                            # 最近一帧 Status
        self.status_time = None                       # 收到该帧的 monotonic
        self.history = deque(maxlen=300)              # (elapsed, v_out, i_out) 供画曲线
        self.link = False
        self.link_error = ""
        self.seq = 0
        self.start_time = time.monotonic()

        self._txq = deque()
        self._lock = threading.Lock()
        self._stop = threading.Event()
        self._thread = None
        self._link_reported = None

    # -- 生命周期 -----------------------------------------------------------
    def start(self) -> None:
        if self._thread is not None and self._thread.is_alive():
            return
        self._stop.clear()
        self._thread = threading.Thread(target=self._reader_loop,
                                        name="host-reader", daemon=True)
        self._thread.start()

    def stop(self, timeout: float = 2.0) -> None:
        self._stop.set()
        if self._thread is not None:
            self._thread.join(timeout=timeout)
            self._thread = None

    def reconnect(self) -> None:
        """手动触发重连：关掉当前链路，读线程会自己重新打开。"""
        try:
            self.transport.close()
        except Exception:
            pass
        self.link = False
        self.link_error = "正在重连…"
        self._emit("link", False, "正在重连…")
        self.parser.reset()

    # -- 发送 ---------------------------------------------------------------
    def write_frame(self, cmd: int, payload: bytes = b"") -> int:
        with self._lock:
            self.seq = (self.seq + 1) & 0xFF
            seq = self.seq
        self._txq.append((build_frame(cmd, payload, seq), cmd, seq))
        return seq

    def send_read_status(self) -> int:
        return self.write_frame(CMD_READ_STATUS)

    def send_heartbeat(self) -> int:
        return self.write_frame(CMD_HEARTBEAT)

    def send_setpoint(self, v_set: float, i_set: float) -> int:
        return self.write_frame(CMD_SET_SETPOINT, pack_setpoint(v_set, i_set))

    def send_output(self, enable) -> int:
        return self.write_frame(CMD_SET_OUTPUT, pack_byte(1 if enable else 0))

    def send_clear_fault(self) -> int:
        return self.write_frame(CMD_CLEAR_FAULT)

    def send_time(self, unix_seconds=None) -> int:
        """把本机时间同步给板卡（板卡用它给 CSV 打时间戳 / 命名日志文件）。"""
        if unix_seconds is None:
            unix_seconds = int(time.time())
        return self.write_frame(CMD_SET_TIME, pack_time(unix_seconds))

    # -- 事件 ---------------------------------------------------------------
    def _emit(self, kind: str, *args) -> None:
        self.events.append((kind,) + args)

    def drain_events(self) -> list:
        out = []
        while True:
            try:
                out.append(self.events.popleft())
            except IndexError:
                break
        return out

    def elapsed(self) -> float:
        return time.monotonic() - self.start_time

    def stats_text(self) -> str:
        p = self.parser
        return ("收发 发%d/收%d  STATUS %d  TEXT %d  ACK %d  NACK %d  "
                "CRC错 %d  重同步 %d  重连 %d"
                % (self.stats["tx"], self.stats["rx"], self.stats["status"],
                   self.stats["text"], self.stats["ack"], self.stats["nack"],
                   p.crc_errors, p.resyncs, self.stats["reconnects"]))

    # -- 读线程 -------------------------------------------------------------
    def _reader_loop(self) -> None:
        backoff = 0.5
        while not self._stop.is_set():
            # 1) 链路不在就（按退避策略）尝试打开
            if not self.transport.is_open:
                if not self.auto_reconnect:
                    break
                try:
                    self.transport.open()
                except TransportError as exc:
                    self.link = False
                    self.link_error = str(exc)
                    self._report_link(False, str(exc).splitlines()[0] if str(exc) else "")
                    self._stop.wait(backoff)
                    backoff = min(3.0, backoff * 1.6)
                    continue
                self.parser.reset()
                self.link = True
                self.link_error = ""
                self.stats["reconnects"] += 1
                backoff = 0.5
                self._report_link(True, "已连接 %s" % self.transport.describe())

            # 2) 把待发命令写出去
            while self._txq and not self._stop.is_set():
                data, cmd, seq = self._txq.popleft()
                try:
                    self.transport.write(data)
                except TransportError as exc:
                    self._down(str(exc))
                    break
                self.stats["tx"] += 1
                # 周期性轮询不进日志（太吵），只记有意义的命令
                if cmd not in (CMD_READ_STATUS, CMD_HEARTBEAT):
                    self._emit("sent", cmd, seq, len(data))

            if not self.transport.is_open:
                continue

            # 3) 收数据
            try:
                data = self.transport.read(4096)
            except TransportError as exc:
                self._down(str(exc))
                continue
            except Exception as exc:                  # noqa: BLE001 - 读线程绝不能死
                self._down("读取异常：%s" % exc)
                continue

            if data:
                for fr in self.parser.feed(data):
                    self._handle_frame(fr)
            else:
                self._stop.wait(0.005)

        try:
            self.transport.close()
        except Exception:
            pass

    def _down(self, reason: str) -> None:
        self.stats["errors"] += 1
        try:
            self.transport.close()
        except Exception:
            pass
        self.link = False
        self.link_error = reason
        self._report_link(False, reason)

    def _report_link(self, ok: bool, msg: str) -> None:
        if self._link_reported == ok:
            return
        self._link_reported = ok
        self._emit("link", ok, msg)

    def _handle_frame(self, fr) -> None:
        self.stats["rx"] += 1
        if fr.cmd == CMD_STATUS:
            try:
                st = decode_status(fr.payload)
            except ProtocolError as exc:
                self._emit("err", "STATUS 负载异常：%s" % exc)
                return
            self.stats["status"] += 1
            self.status = st
            self.status_time = time.monotonic()
            self.history.append((self.elapsed(), st.v_out, st.i_out))
            self._emit("status", st)
        elif fr.cmd == CMD_TEXT:
            self.stats["text"] += 1
            self._emit("text", decode_text(fr.payload))
        elif fr.cmd == CMD_ACK:
            self.stats["ack"] += 1
            try:
                code = unpack_byte(fr.payload)
            except ProtocolError:
                code = -1
            self._emit("ack", code, fr.seq, ACK_TEXTS.get(code, "结果码 %d" % code))
        elif fr.cmd == CMD_NACK:
            self.stats["nack"] += 1
            cmd = fr.payload[0] if fr.payload else -1
            self._emit("nack", cmd)
        else:
            self.stats["other"] += 1
            self._emit("other", fr)


# ===========================================================================
# 图形界面
# ===========================================================================

# 状态灯配色
COLOR_ON = "#2e7d32"        # 绿：正常/在线
COLOR_OFF = "#9e9e9e"       # 灰：关闭/未知
COLOR_FAULT = "#c62828"     # 红：故障
COLOR_OK = "#2e7d32"
COLOR_WARN = "#ef6c00"      # 橙：注意
COLOR_V = "#1e88e5"         # 电压曲线蓝
COLOR_I = "#e53935"         # 电流曲线红
COLOR_SET = "#9e9e9e"       # 给定虚线灰

# 界面字体：按优先级挑本机装了的，Windows 用雅黑/Consolas，Linux 用 Noto/文泉驿等
UI_FONT_CANDIDATES = ("Microsoft YaHei", "微软雅黑", "Noto Sans CJK SC",
                      "Source Han Sans SC", "WenQuanYi Micro Hei", "SimHei",
                      "PingFang SC", "DejaVu Sans", "TkDefaultFont")
MONO_FONT_CANDIDATES = ("Consolas", "DejaVu Sans Mono", "Noto Sans Mono",
                        "Liberation Mono", "Courier New", "TkFixedFont")


def _pick_family(candidates) -> str:
    """在候选字体里挑一个本机可用的；都不可用就用 Tk 默认字体。"""
    try:
        import tkinter.font as tkfont
        available = set(tkfont.families())
    except Exception:                                 # noqa: BLE001
        return candidates[0]
    for name in candidates:
        if name in available:
            return name
    return candidates[-1]


class HostGui:
    """tkinter 界面。所有协议操作都通过 HostCore，界面线程不阻塞。"""

    POLL_MS = 100               # 界面轮询周期
    POLL_HZ = 5.0               # READ_STATUS 频率
    HB_HZ = 1.0                 # HEARTBEAT 频率
    CSV_HZ = 1.0                # 上位机侧 CSV 记录频率
    PLOT_POINTS = 300           # 曲线点数

    def __init__(self, root, core: HostCore, csv_logger: CsvLogger = None,
                 v_set: float = 12.0, i_set: float = 5.0,
                 output_on: bool = True, duration: float = None) -> None:
        import tkinter as tk
        self.tk = tk
        self.root = root
        self.core = core
        self.csv = csv_logger
        self.duration = duration

        self._last_req = 0.0
        self._last_hb = 0.0
        self._last_csv = 0.0
        self._last_status_seen = -1
        self._log_lines = 0
        self._closing = False

        self.hist_v = deque(maxlen=self.PLOT_POINTS)
        self.hist_i = deque(maxlen=self.PLOT_POINTS)

        self._build_ui(v_set, i_set)
        self.core.start()

        # 先下发给定值，再开输出（顺序很重要：先有给定才不会误触发保护）
        self.root.after(300, lambda: self._bootstrap(v_set, i_set, output_on))
        self.root.after(self.POLL_MS, self._poll)
        if duration:
            self.root.after(int(duration * 1000), self._on_close)
        self.root.protocol("WM_DELETE_WINDOW", self._on_close)

    # ------------------------------------------------------------------
    # 界面搭建
    # ------------------------------------------------------------------
    def _build_ui(self, v_set: float, i_set: float) -> None:
        tk = self.tk
        # 字体按本机实际安装的挑，Windows 用雅黑/Consolas，Linux 用 Noto/文泉驿等
        ui = _pick_family(UI_FONT_CANDIDATES)
        mono = _pick_family(MONO_FONT_CANDIDATES)
        self.f_ui = (ui, 9)
        self.f_ui_s = (ui, 8)
        self.f_ui_b = (ui, 10, "bold")
        self.f_mono = (mono, 9)
        self.f_mono_s = (mono, 8)
        self.root.title("DC-DC 电源控制板上位机")
        self.root.geometry("1000x760")
        self.root.minsize(860, 640)

        # --- 顶部连接条 ---
        top = tk.Frame(self.root)
        top.pack(fill="x", padx=8, pady=(8, 2))
        self.lbl_conn = tk.Label(top, text="连接中…", fg="white", bg=COLOR_WARN,
                                 font=self.f_ui_b, padx=10, pady=3)
        self.lbl_conn.pack(side="left")
        self.lbl_transport = tk.Label(top, text=self.core.transport.describe(),
                                      font=(self.f_ui[0], 10))
        self.lbl_transport.pack(side="left", padx=10)
        tk.Button(top, text="重连", width=6, command=self._on_reconnect).pack(side="right", padx=2)
        tk.Button(top, text="清故障", width=8, command=self._on_clear_fault).pack(side="right", padx=2)

        # --- 大字显示 ---
        big = tk.Frame(self.root)
        big.pack(fill="x", padx=8, pady=4)
        self.big_vals = {}
        cards = (("v", "输出电压", "V", COLOR_V), ("i", "输出电流", "A", COLOR_I),
                 ("d", "占空比", "%", "#6a1b9a"), ("o", "输出状态", "", "#00838f"))
        for idx, (key, title, unit, color) in enumerate(cards):
            card = tk.Frame(big, bd=1, relief="groove")
            card.grid(row=0, column=idx, sticky="nsew", padx=4)
            big.columnconfigure(idx, weight=1)
            tk.Label(card, text=title, font=(self.f_ui[0], 10)).pack(pady=(6, 0))
            lbl = tk.Label(card, text="--", font=(self.f_mono[0], 30, "bold"), fg=color)
            lbl.pack()
            tk.Label(card, text=unit, font=self.f_ui, fg="#666").pack(pady=(0, 6))
            self.big_vals[key] = lbl

        # --- 状态灯 + 故障文字 ---
        lamp_row = tk.Frame(self.root)
        lamp_row.pack(fill="x", padx=12, pady=2)
        self.lamps = {}
        for key, text in (("output", "输出"), ("fault", "故障"),
                          ("host", "上位机在线"), ("log", "本地日志")):
            box = tk.Frame(lamp_row)
            box.pack(side="left", padx=(0, 18))
            cv = tk.Canvas(box, width=18, height=18, highlightthickness=0)
            cv.pack(side="left")
            dot = cv.create_oval(2, 2, 16, 16, fill=COLOR_OFF, outline="#555")
            tk.Label(box, text=text, font=self.f_ui).pack(side="left", padx=3)
            self.lamps[key] = (cv, dot)
        self.lbl_fault = tk.Label(lamp_row, text="故障：无", font=self.f_ui_b,
                                  fg=COLOR_OK)
        self.lbl_fault.pack(side="left", padx=10)
        self.lbl_stats = tk.Label(lamp_row, text="统计：--", font=self.f_mono, fg="#555")
        self.lbl_stats.pack(side="right")

        # --- 设定与操作 ---
        sp = tk.LabelFrame(self.root, text="设定与操作", font=self.f_ui)
        sp.pack(fill="x", padx=8, pady=6)
        tk.Label(sp, text="电压给定 (V)", font=self.f_ui).grid(row=0, column=0, padx=6, pady=6)
        self.ent_v = tk.Entry(sp, width=10, font=(self.f_mono[0], 11))
        self.ent_v.insert(0, "%.2f" % v_set)
        self.ent_v.grid(row=0, column=1, padx=2)
        tk.Label(sp, text="电流给定 (A) — 未实现", font=self.f_ui, fg="#999").grid(row=0, column=2, padx=6)
        self.ent_i = tk.Entry(sp, width=10, font=(self.f_mono[0], 11),
                              state="disabled", disabledbackground="#eeeeee", disabledforeground="#999")
        self.ent_i.configure(state="normal")
        self.ent_i.insert(0, "0.00")
        self.ent_i.configure(state="disabled")
        self.ent_i.grid(row=0, column=3, padx=2)
        tk.Button(sp, text="下发", width=8, command=self._on_apply).grid(row=0, column=4, padx=8)
        tk.Button(sp, text="输出开", width=8, command=lambda: self._on_output(True)).grid(row=0, column=5, padx=4)
        tk.Button(sp, text="输出关", width=8, command=lambda: self._on_output(False)).grid(row=0, column=6, padx=4)
        tk.Button(sp, text="清故障", width=8, command=self._on_clear_fault).grid(row=0, column=7, padx=4)
        self.lbl_setpoint = tk.Label(sp, text="板卡当前给定：--", font=(self.f_mono[0], 10), fg="#555")
        self.lbl_setpoint.grid(row=0, column=8, padx=12, sticky="w")

        # --- 实时曲线 ---
        pf = tk.LabelFrame(self.root, text="实时曲线（最近 %d 点，自动缩放）" % self.PLOT_POINTS,
                           font=self.f_ui)
        pf.pack(fill="both", expand=True, padx=8, pady=4)
        self.canvas = tk.Canvas(pf, height=230, bg="white", highlightthickness=0)
        self.canvas.pack(fill="both", expand=True, padx=4, pady=4)
        self.canvas.bind("<Configure>", lambda _e: self._draw_plot())

        # --- 日志 ---
        lf = tk.LabelFrame(self.root, text="帧日志（收发摘要 / CRC 统计）", font=self.f_ui)
        lf.pack(fill="both", expand=False, padx=8, pady=(4, 8))
        self.txt = tk.Text(lf, height=9, font=self.f_mono, wrap="none")
        sb = tk.Scrollbar(lf, command=self.txt.yview)
        self.txt.configure(yscrollcommand=sb.set)
        sb.pack(side="right", fill="y")
        self.txt.pack(side="left", fill="both", expand=True, padx=4, pady=4)
        self.log("上位机启动，传输方式：%s" % self.core.transport.describe())

    # ------------------------------------------------------------------
    # 日志
    # ------------------------------------------------------------------
    def log(self, line: str) -> None:
        stamp = datetime.now().strftime("%H:%M:%S")
        self.txt.insert("end", "[%s] %s\n" % (stamp, line))
        self._log_lines += 1
        if self._log_lines > 600:                     # 控制内存占用
            self.txt.delete("1.0", "101.0")
            self._log_lines -= 100
        self.txt.see("end")

    # ------------------------------------------------------------------
    # 启动动作 / 按钮
    # ------------------------------------------------------------------
    def _bootstrap(self, v_set: float, i_set: float, output_on: bool) -> None:
        self.core.send_time()                       # 先把本机时间同步给板卡（CSV 时间戳用）
        self.log("已下发时间同步（板卡日志文件按当天命名）")
        self.core.send_setpoint(v_set, 0.0)         # 电流给定未实现 → 恒发 0
        if output_on:
            self.core.send_output(True)
        else:
            self.core.send_output(False)

    def _on_apply(self) -> None:
        try:
            v = float(self.ent_v.get().strip())
        except ValueError:
            self.log("输入不合法：给定值必须是数字")
            return
        if not (0.0 <= v <= 48.0):
            self.log("输入越界：电压给定 0~48V（板卡 0x58 寄存器上限）")
            return
        self.core.send_setpoint(v, 0.0)
        self.log("下发给定 Vset=%.2fV（电流给定未实现，恒 0）" % v)

    def _on_output(self, enable: bool) -> None:
        self.core.send_output(enable)
        self.log("下发 %s 输出" % ("开启" if enable else "关闭"))

    def _on_clear_fault(self) -> None:
        self.core.send_clear_fault()
        self.log("下发 清故障（成功后会关闭输出并清零给定，需重设给定再开启）")

    def _on_reconnect(self) -> None:
        self.core.reconnect()
        self.log("手动重连…")

    # ------------------------------------------------------------------
    # 定时轮询
    # ------------------------------------------------------------------
    def _poll(self) -> None:
        if self._closing:
            return
        now = time.monotonic()

        if self.core.link:
            if now - self._last_req >= 1.0 / self.POLL_HZ:
                self._last_req = now
                self.core.send_read_status()
            if now - self._last_hb >= 1.0 / self.HB_HZ:
                self._last_hb = now
                self.core.send_heartbeat()

        status_seen = False
        for ev in self.core.drain_events():
            if self._on_event(ev):
                status_seen = True

        self._refresh_link()
        if status_seen or self.core.status is not None:
            self._refresh_values()

        # 上位机侧 CSV：1Hz 记一行
        st = self.core.status
        if self.csv is not None and st is not None and now - self._last_csv >= 1.0 / self.CSV_HZ:
            self._last_csv = now
            self.csv.log(self.core.elapsed(), st)

        self.lbl_stats.configure(text="统计：" + self.core.stats_text())
        self.root.after(self.POLL_MS, self._poll)

    def _on_event(self, ev) -> bool:
        """处理一条事件，返回是否收到 STATUS。"""
        kind = ev[0]
        if kind == "status":
            st = ev[1]
            self.hist_v.append(st.v_out)
            self.hist_i.append(st.i_out)
            self._draw_plot()
            if self.core.stats["status"] % 5 == 1:    # 1Hz 左右打一条状态摘要
                self.log("RX STATUS %s" % st.one_line())
            return True
        if kind == "text":
            self.log("板卡日志：%s" % ev[1])
        elif kind == "sent":
            self.log("TX %s seq=%d (%dB)" % (CMD_NAMES.get(ev[1], hex(ev[1])), ev[2], ev[3]))
        elif kind == "ack":
            self.log("RX ACK seq=%d %s" % (ev[2], ev[3]))
        elif kind == "nack":
            self.log("RX NACK 被拒命令=0x%02X" % (ev[1] & 0xFF))
        elif kind == "link":
            self.log("链路%s：%s" % ("已连接" if ev[1] else "断开", ev[2]))
            self._refresh_link()
        elif kind == "err":
            self.log("错误：%s" % ev[1])
        return False

    def _refresh_link(self) -> None:
        if self.core.link:
            self.lbl_conn.configure(text="连接正常", bg=COLOR_ON)
        else:
            reason = (self.core.link_error or "").strip()
            if len(reason) > 40:
                reason = reason[:40] + "…"
            self.lbl_conn.configure(text="连接断开 %s" % reason, bg=COLOR_FAULT)

    def _refresh_values(self) -> None:
        st = self.core.status
        if st is None:
            return
        self.big_vals["v"].configure(text="%6.2f" % st.v_out)
        self.big_vals["i"].configure(text="%6.2f" % st.i_out)
        self.big_vals["d"].configure(text="%6.1f" % st.duty)
        self.big_vals["o"].configure(text="输出开" if st.has_flag(FLAG_OUTPUT_EN) else "输出关",
                                     fg=COLOR_ON if st.has_flag(FLAG_OUTPUT_EN) else COLOR_OFF)

        self._set_lamp("output", st.has_flag(FLAG_OUTPUT_EN), COLOR_ON)
        self._set_lamp("fault", st.fault != FAULT_NONE, COLOR_FAULT)
        self._set_lamp("host", st.has_flag(FLAG_HOST_ONLINE), COLOR_WARN)
        self._set_lamp("log", st.has_flag(FLAG_LOG_OK), COLOR_ON)

        if st.fault == FAULT_NONE:
            self.lbl_fault.configure(text="故障：无", fg=COLOR_OK)
        else:
            bits = []
            if st.has_flag(FLAG_OVP):
                bits.append("OVP")
            if st.has_flag(FLAG_OCP):
                bits.append("OCP")
            if st.has_flag(FLAG_OTP):
                bits.append("OTP")
            self.lbl_fault.configure(text="故障：%s %s" % (st.fault_text(), "/".join(bits)),
                                     fg=COLOR_FAULT)
        self.lbl_setpoint.configure(
            text="板卡当前给定：%.2fV（电流未实现）  PL：%s"
                 % (st.v_set, st.pl_status_short()))

    def _set_lamp(self, key: str, on: bool, color: str) -> None:
        cv, dot = self.lamps[key]
        cv.itemconfigure(dot, fill=color if on else COLOR_OFF)

    # ------------------------------------------------------------------
    # 曲线
    # ------------------------------------------------------------------
    def _draw_plot(self) -> None:
        cv = self.canvas
        w = max(cv.winfo_width(), 100)
        h = max(cv.winfo_height(), 80)
        cv.delete("all")

        pad_l, pad_r, pad_t, pad_b = 46, 50, 12, 22
        x0, y0 = pad_l, pad_t
        x1, y1 = w - pad_r, h - pad_b
        if x1 <= x0 + 10 or y1 <= y0 + 10:
            return

        vs = list(self.hist_v)
        iss = list(self.hist_i)
        st = self.core.status
        v_set = st.v_set if st else 0.0

        v_hi = max(vs + [v_set, 1.0]) * 1.10
        i_hi = max(iss + [st.i_set if st else 0.0, 0.5]) * 1.10
        v_hi = max(v_hi, 0.1)
        i_hi = max(i_hi, 0.1)

        # 网格 + 坐标
        for k in range(5):
            y = y0 + (y1 - y0) * k / 4.0
            cv.create_line(x0, y, x1, y, fill="#eeeeee")
            cv.create_text(x0 - 5, y, anchor="e", font=self.f_mono_s, fill=COLOR_V,
                           text="%.1f" % (v_hi * (1 - k / 4.0)))
            cv.create_text(x1 + 5, y, anchor="w", font=self.f_mono_s, fill=COLOR_I,
                           text="%.2f" % (i_hi * (1 - k / 4.0)))
        cv.create_rectangle(x0, y0, x1, y1, outline="#bbbbbb")
        cv.create_text(x0 + 4, y0 + 8, anchor="w", font=self.f_ui_s,
                       fill="#444", text="V / A")
        cv.create_text(x1 - 4, y0 + 8, anchor="e", font=self.f_ui_s,
                       fill="#444", text="最近 %d 点（左轴电压，右轴电流）" % self.PLOT_POINTS)

        n = self.PLOT_POINTS
        if len(vs) < 2:
            cv.create_text((x0 + x1) / 2, (y0 + y1) / 2, text="等待数据…",
                           font=(self.f_ui[0], 11), fill="#999")
            return

        def px(idx):
            return x0 + (x1 - x0) * (idx / float(n - 1))

        def py(val, hi):
            return y1 - (y1 - y0) * min(max(val / hi, 0.0), 1.0)

        # 电压给定虚线（方便看收敛）
        if st is not None and v_set > 0:
            yset = py(v_set, v_hi)
            cv.create_line(x0, yset, x1, yset, fill=COLOR_SET, dash=(4, 3))
            cv.create_text(x1 - 4, yset - 7, anchor="e", font=self.f_ui_s,
                           fill="#777", text="给定 %.2fV" % v_set)

        cv.create_line(*[c for i, v in enumerate(vs) for c in (px(i), py(v, v_hi))],
                       fill=COLOR_V, width=2, smooth=False)
        cv.create_line(*[c for i, v in enumerate(iss) for c in (px(i), py(v, i_hi))],
                       fill=COLOR_I, width=2, smooth=False)

    # ------------------------------------------------------------------
    def _on_close(self) -> None:
        if self._closing:
            return
        self._closing = True
        try:
            self.core.send_output(False)              # 退出前礼貌地关掉输出
            time.sleep(0.05)
        except Exception:
            pass
        self.core.stop()
        if self.csv is not None:
            self.csv.close()
        try:
            self.root.destroy()
        except Exception:
            pass


# ===========================================================================
# 命令行界面
# ===========================================================================

class HostCli:
    """无界面模式：每秒打印一行对齐的状态表格，适合自动化测试与远程 SSH。"""

    POLL_HZ = 5.0
    HB_HZ = 1.0
    PRINT_HZ = 1.0
    CSV_HZ = 1.0

    def __init__(self, core: HostCore, csv_logger: CsvLogger = None,
                 v_set: float = 12.0, i_set: float = 5.0, output_on: bool = True,
                 duration: float = None, demo_step: bool = False,
                 demo_fault: bool = False) -> None:
        self.core = core
        self.csv = csv_logger
        self.v_set = v_set
        self.i_set = i_set
        self.output_on = output_on
        self.duration = duration
        self.demo_step = demo_step
        self.demo_fault = demo_fault
        self._last_req = 0.0
        self._last_hb = 0.0
        self._last_print = 0.0
        self._last_csv = 0.0
        self._stepped = False
        self._fault_stage = 0

    def run(self) -> int:
        core = self.core
        core.start()
        print("[上位机] 传输方式：%s" % core.transport.describe())
        print("[上位机] 已下发给定 Vset=%.2fV Iset=%.2fA，输出%s"
              % (self.v_set, self.i_set, "开启" if self.output_on else "保持关闭"))

        t0 = time.monotonic()
        sent_bootstrap = False
        try:
            while True:
                now = time.monotonic()
                elapsed = now - t0
                if self.duration is not None and elapsed >= self.duration:
                    break

                if core.link:
                    if not sent_bootstrap:
                        sent_bootstrap = True
                        core.send_setpoint(self.v_set, self.i_set)
                        core.send_output(self.output_on)
                    if now - self._last_req >= 1.0 / self.POLL_HZ:
                        self._last_req = now
                        core.send_read_status()
                    if now - self._last_hb >= 1.0 / self.HB_HZ:
                        self._last_hb = now
                        core.send_heartbeat()

                for ev in core.drain_events():
                    self._on_event(ev)

                # 演示 A：跑到一半把给定值调高 20%，看输出电压跟着往上走
                if (self.demo_step and not self._stepped and self.duration
                        and elapsed >= self.duration * 0.5):
                    self._stepped = True
                    new_v = min(self.v_set * 1.2, 20.0)
                    print("[上位机] >>> 演示：电压给定 %.2fV -> %.2fV <<<" % (self.v_set, new_v))
                    core.send_setpoint(new_v, self.i_set)

                # 演示 B：把给定值突然砍半 -> 触发 OVP -> 清故障 -> 重新开输出
                if self.demo_fault and self.duration:
                    frac = elapsed / self.duration
                    if self._fault_stage == 0 and frac >= 0.30:
                        self._fault_stage = 1
                        print("[上位机] >>> 演示故障：给定突然砍半到 %.2fV，"
                              "预期模拟板卡触发 OVP 并自动关输出 <<<" % (self.v_set / 2.0))
                        core.send_setpoint(self.v_set / 2.0, self.i_set)
                    elif self._fault_stage == 1 and frac >= 0.55:
                        self._fault_stage = 2
                        print("[上位机] >>> 演示恢复：下发 CLEAR_FAULT <<<")
                        core.send_clear_fault()
                    elif self._fault_stage == 2 and frac >= 0.72:
                        self._fault_stage = 3
                        print("[上位机] >>> 演示恢复：恢复给定 %.2fV 并重新开输出 <<<" % self.v_set)
                        core.send_setpoint(self.v_set, self.i_set)
                        core.send_output(True)

                st = core.status
                if st is not None and now - self._last_print >= 1.0 / self.PRINT_HZ:
                    self._last_print = now
                    print("[%6.1fs] %s" % (core.elapsed(), st.one_line()))
                    if self.csv is not None and now - self._last_csv >= 1.0 / self.CSV_HZ:
                        self._last_csv = now
                        self.csv.log(core.elapsed(), st)

                time.sleep(0.01)
        except KeyboardInterrupt:
            print("\n[上位机] 收到 Ctrl+C，正在退出…")
        finally:
            # 退出前先记下"稳态"状态，再看最后一帧（关输出后电压会往下掉，不算跟随误差）
            self._steady_status = core.status
            try:
                core.send_output(False)
                time.sleep(0.08)
            except Exception:
                pass
            core.stop()

        self._print_summary()
        # 一帧 STATUS 都没收到说明链路没通，返回非 0 让自动化脚本能发现
        return 0 if self.core.stats["status"] > 0 else 1

    def _on_event(self, ev) -> None:
        kind = ev[0]
        if kind == "text":
            print("[%6.1fs] 板卡日志：%s" % (self.core.elapsed(), ev[1]))
        elif kind == "ack":
            if ev[1] != 0:
                print("[%6.1fs] 板卡拒绝：%s（seq=%d）" % (self.core.elapsed(), ev[3], ev[2]))
        elif kind == "nack":
            print("[%6.1fs] 板卡返回 NACK：被拒命令 0x%02X" % (self.core.elapsed(), ev[1] & 0xFF))
        elif kind == "link":
            print("[%6.1fs] 链路%s：%s"
                  % (self.core.elapsed(), "已连接" if ev[1] else "断开", ev[2]))
        elif kind == "err":
            print("[%6.1fs] 错误：%s" % (self.core.elapsed(), ev[1]))

    def _print_summary(self) -> None:
        core = self.core
        s = core.stats
        print("-" * 78)
        print("[上位机] 汇总：收到帧 %d（STATUS %d / TEXT %d / ACK %d / NACK %d / 其它 %d），发出帧 %d"
              % (s["rx"], s["status"], s["text"], s["ack"], s["nack"], s["other"], s["tx"]))
        print("[上位机] CRC 错误 %d 次，重新同步 %d 次，链路建立/重连 %d 次"
              % (core.parser.crc_errors, core.parser.resyncs, s["reconnects"]))
        st = getattr(self, "_steady_status", None) or core.status
        if st is not None:
            dev = st.v_out - st.v_set
            ratio = abs(dev) / st.v_set * 100.0 if st.v_set else 0.0
            print("[上位机] 跟随检查：稳态 Vout=%.3fV，给定 %.3fV，偏差 %+.3fV（%.2f%%）"
                  % (st.v_out, st.v_set, dev, ratio))
            print("[上位机] 稳态状态：%s" % st.one_line())
        else:
            print("[上位机] 未收到任何 STATUS 帧！")
        if self.csv is not None:
            print("[上位机] CSV：%s（%d 行）" % (self.csv.path, self.csv.rows))
        else:
            print("[上位机] CSV：未启用")
        extra = getattr(core.transport, "board_summary", None)
        if callable(extra):
            text = extra()
            if text:
                print(text)


# ===========================================================================
# 命令行参数 / 入口
# ===========================================================================

def _parse_hostport(text: str, default_port: int = 5560):
    text = (text or "").strip()
    if ":" in text:
        host, _, port = text.rpartition(":")
        return (host or "127.0.0.1"), int(port)
    if text.isdigit():
        return "127.0.0.1", int(text)
    return (text or "127.0.0.1"), default_port


def build_arg_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="host.py",
        description="DC-DC 电源控制板 PC 上位机（串口 / TCP / 进程内模拟 三选一）",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="示例：\n"
               "  python host.py --sim\n"
               "  python host.py --sim --cli --duration 6\n"
               "  python host.py --tcp 127.0.0.1:5560\n"
               "  python host.py --port COM7 --baud 115200\n"
               "  python host.py --list-ports\n")
    g = p.add_mutually_exclusive_group()
    g.add_argument("--sim", action="store_true", help="使用进程内嵌模拟板卡（默认）")
    g.add_argument("--tcp", metavar="HOST:PORT", default=None, help="连接 TCP 模拟板卡/串口服务器")
    g.add_argument("--port", metavar="COMx", default=None, help="使用真实串口，例如 COM7 或 /dev/ttyUSB0")

    p.add_argument("--baud", type=int, default=115200, help="串口波特率（默认 115200）")
    p.add_argument("--cli", action="store_true", help="命令行模式（默认是图形界面）")
    p.add_argument("--duration", type=float, default=None, help="运行 N 秒后自动退出")
    p.add_argument("--csv", metavar="PATH", default=None,
                   help="上位机侧 CSV 日志路径（默认自动生成带时间戳的文件名）")
    p.add_argument("--no-csv", action="store_true", help="关闭上位机侧 CSV 日志")
    p.add_argument("--list-ports", action="store_true", help="列出本机可用串口后退出")
    p.add_argument("--gui-selftest", action="store_true",
                   help="图形界面自检：建窗口->刷新几次->销毁退出（无人值守用）")

    p.add_argument("--set-v", type=float, default=12.0, help="启动时下发的电压给定 V（默认 12）")
    p.add_argument("--set-i", type=float, default=0.0,
                   help="启动时下发的电流给定 A（板卡未实现，保持 0）")
    p.add_argument("--output", choices=("on", "off"), default="on",
                   help="启动时是否打开输出（默认 on）")
    p.add_argument("--demo-step", action="store_true",
                   help="演示闭环跟随：跑到一半把给定值调高 20%%")
    p.add_argument("--demo-fault", action="store_true",
                   help="演示故障全流程：给定砍半触发 OVP -> CLEAR_FAULT -> 重新开输出")
    p.add_argument("--sim-board-csv", metavar="PATH", default=None,
                   help="--sim 模式下顺便让内嵌模拟板卡也写一份本地 CSV")
    p.add_argument("--reconnect-test", action="store_true",
                   help="自动化测试用：第 3 秒强制断开链路一次，验证自动重连")
    return p


def list_serial_ports() -> int:
    if not SERIAL_AVAILABLE:
        print(SERIAL_MISSING_HINT)
        return 1
    ports = list(_list_ports.comports())
    if not ports:
        print("本机没有发现可用串口。")
        return 0
    print("发现 %d 个串口：" % len(ports))
    for p in ports:
        print("  %-12s %s" % (p.device, p.description))
    return 0


def make_csv_logger(args) -> CsvLogger:
    if args.no_csv:
        return None
    path = args.csv
    if not path:
        path = "host_log_%s.csv" % datetime.now().strftime("%Y%m%d_%H%M%S")
    try:
        return CsvLogger(path)
    except OSError as exc:
        print("[上位机] 无法创建 CSV 日志 %s：%s（改为不记录）" % (path, exc))
        return None


def build_transport(args) -> BaseTransport:
    if args.port:
        return SerialTransport(args.port, args.baud)
    if args.tcp:
        host, port = _parse_hostport(args.tcp)
        return TcpTransport(host, port)
    return SimTransport(v_set=args.set_v, i_set=args.set_i,
                        board_csv=args.sim_board_csv)


def main(argv=None) -> int:
    args = build_arg_parser().parse_args(argv)

    if args.list_ports:
        return list_serial_ports()

    transport = build_transport(args)
    csv_logger = make_csv_logger(args)
    core = HostCore(transport, csv_logger)

    if csv_logger is not None:
        print("[上位机] CSV 日志：%s" % csv_logger.path)

    if args.gui_selftest:
        return gui_selftest(core, args)

    if args.cli:
        cli = HostCli(core, csv_logger, v_set=args.set_v, i_set=args.set_i,
                      output_on=(args.output == "on"), duration=args.duration,
                      demo_step=args.demo_step, demo_fault=args.demo_fault)
        if args.reconnect_test:
            threading.Thread(target=_reconnect_after, args=(core, 3.0),
                             daemon=True).start()
        return cli.run()

    # --- 图形界面 ---
    try:
        import tkinter as tk
    except ImportError:
        print("[上位机] 本机没有 tkinter，无法启动图形界面。请加 --cli 使用命令行模式。")
        return 1
    try:
        root = tk.Tk()
    except tk.TclError as exc:
        print("[上位机] 无法创建窗口（%s）。可能没有图形环境，请加 --cli 使用命令行模式。" % exc)
        return 1

    gui = HostGui(root, core, csv_logger, v_set=args.set_v, i_set=args.set_i,
                  output_on=(args.output == "on"), duration=args.duration)
    if args.reconnect_test:
        threading.Thread(target=_reconnect_after, args=(core, 3.0), daemon=True).start()
    try:
        root.mainloop()
    except KeyboardInterrupt:
        gui._on_close()                               # noqa: SLF001
    print(core.stats_text())
    return 0


def _reconnect_after(core: HostCore, delay: float) -> None:
    """自动化测试钩子：延时后强制断开一次链路，观察自动重连。"""
    time.sleep(delay)
    print("[上位机] >>> 测试：强制断开链路，验证自动重连 <<<")
    core.reconnect()


def gui_selftest(core: HostCore, args) -> int:
    """无头自检：建窗口 -> update() 若干次 -> 销毁。本机没人看屏幕也能跑。"""
    try:
        import tkinter as tk
    except ImportError:
        print("[GUI自检] 失败：本机没有 tkinter")
        return 1
    try:
        root = tk.Tk()
    except tk.TclError as exc:
        print("[GUI自检] 失败：无法创建窗口（%s）" % exc)
        return 1

    root.withdraw()                                   # 先无头建好界面
    csv_logger = None
    gui = HostGui(root, core, csv_logger, v_set=args.set_v, i_set=args.set_i,
                  output_on=(args.output == "on"), duration=None)

    ok = True
    try:
        # 阶段 1：无头刷新，验证协议/定时器/事件队列都活着
        t0 = time.monotonic()
        while time.monotonic() - t0 < 1.2:
            root.update()
            time.sleep(0.02)
        status_seen = core.stats["status"]
        print("[GUI自检] 阶段1 无头刷新完成：收到 STATUS %d 帧，控件 %d 个"
              % (status_seen, len(root.winfo_children())))

        # 阶段 2：显示窗口拿到真实尺寸，强制走一遍曲线绘制代码
        root.deiconify()
        root.geometry("1000x760")
        root.update()
        t1 = time.monotonic()
        while time.monotonic() - t1 < 1.2:
            root.update()
            time.sleep(0.02)
        gui._draw_plot()                              # noqa: SLF001 - 明确再画一次
        root.update_idletasks()
        items = len(gui.canvas.find_all())
        w, h = gui.canvas.winfo_width(), gui.canvas.winfo_height()
        print("[GUI自检] 阶段2 可见窗口：画布 %dx%d 像素，曲线图元 %d 个，采样点 %d 个"
              % (w, h, items, len(gui.hist_v)))
        if status_seen <= 0:
            print("[GUI自检] 失败：没有收到 STATUS 帧")
            ok = False
        if items < 10:
            print("[GUI自检] 失败：曲线几乎没有画出图元（%d 个）" % items)
            ok = False
    except Exception as exc:                          # noqa: BLE001
        print("[GUI自检] 失败：%s" % exc)
        ok = False
    finally:
        root.withdraw()
        gui._closing = True                           # noqa: SLF001
        core.stop()
        try:
            root.destroy()
        except Exception:
            pass
    print("[GUI自检] 窗口已销毁，没有残留窗口")
    print("[GUI自检] %s" % ("GUI SELFTEST OK" if ok else "GUI SELFTEST FAILED"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
