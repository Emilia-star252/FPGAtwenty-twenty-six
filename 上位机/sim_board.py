# -*- coding: utf-8 -*-
"""
sim_board.py —— DC-DC 电源控制板【模拟板卡】

作用：在真实硬件到位之前，用软件模拟一块 24V 母线降压 DC-DC 板的物理行为，
      让 PC 上位机 (host.py) 可以完整跑通"下发给定 -> 闭环调节 -> 回传状态 -> 保护动作"
      整条链路。以后的真实板卡只需要实现同样的 protocol.py，上位机不用改。

三种用法
--------------------------------------------------------------------------
1) 独立 TCP 服务端（推荐，模拟"串口服务器/网络透传"）：
       python sim_board.py --tcp 127.0.0.1:5560 --csv sim_log.csv
   可加 --duration 8 跑 8 秒后自动退出（自动化测试用）

2) 嵌入式本地运行（不起 socket，只跑物理模型 + 写 CSV）：
       python sim_board.py --embedded --duration 5

3) 被 host.py 直接 import（进程内嵌模拟板，见 host.py 的 SimTransport）：
       from sim_board import SimBoard
       board = SimBoard(); reply = board.feed(request_bytes)

物理模型
--------------------------------------------------------------------------
* 母线  v_bus = 24V
* 占空比 duty 由 v_set 闭环：目标 duty = v_set / v_bus * 100，限幅 0~95%，
  一阶收敛（时间常数约 80ms）
* 输出电压 v_out 一阶跟随 duty/100 * v_bus（时间常数约 50ms）
* 输出电流 i_out = v_out / r_load，r_load 默认 10Ω 并随时间缓慢波动（模拟负载变化）
* 上报值叠加约 0.5% 测量噪声（内部真实状态不受噪声影响）
* 输出未使能时 v_out 指数衰减到 0
* 保护：OVP v_out > v_set*1.15  ／ OCP i_out > 8A  ／ OTP 结温 > 85℃
        任一条动作 -> 立即关闭输出(OUTPUT_EN=0) + 记录 fault 码，
        必须收到 CLEAR_FAULT 之后才允许重新开输出
* 上位机在线判定：超过 3 秒没收到任何上位机数据就清掉 HOST_ONLINE 位
  —— 这就是"断开上位机后板卡本地继续运行"的体现（输出不会被关掉）

本地 CSV 日志
--------------------------------------------------------------------------
* 每 1 秒写一行，表头 timestamp,uptime_s,v_out,i_out,duty,v_set,i_set,flags,fault
* timestamp 为 ISO8601 本地时间（含时区偏移）
* 每行 flush，并周期 os.fsync（模拟掉电不丢日志）
* 按文件大小轮转（默认 5MB，备份名 xxx.csv.1）
* 日志完全独立于串口/TCP：没有任何上位机连接也照写
"""

from __future__ import annotations

import argparse
import math
import os
import random
import selectors
import socket
import sys
import time
from datetime import datetime

from protocol import (
    ACK_BAD_PARAM, ACK_FAULT_LATCHED, ACK_OK, ACK_UNSUPPORTED,
    CMD_ACK, CMD_CLEAR_FAULT, CMD_HEARTBEAT, CMD_NACK, CMD_READ_STATUS,
    CMD_SET_OUTPUT, CMD_SET_SETPOINT, CMD_SET_TIME, CMD_STATUS, CMD_TEXT,
    FAULT_ADC, FAULT_NONE, FAULT_OCP, FAULT_OTP, FAULT_OVP, FAULT_NAMES,
    FLAG_HOST_ONLINE, FLAG_LOG_OK, FLAG_OCP, FLAG_OTP, FLAG_OUTPUT_EN,
    FLAG_OVP, FLAG_RUNNING, MAX_PAYLOAD, Frame, FrameParser, ProtocolError,
    PL_ADC_INITIALIZED, PL_OUTPUT_ACTIVE, PL_OUTPUT_REQUEST, PL_PLL_LOCKED,
    PL_PWM_ARMED, Status, build_frame, encode_text, pack_byte, unpack_byte,
    unpack_setpoint, unpack_time,
)

__all__ = ["SimBoard", "CsvLogger", "run_tcp_server", "main"]


def fit_text(text: str) -> str:
    """把板卡日志压进一帧 TEXT 的容量（≤64 字节 UTF-8），超长时尾部加省略号。"""
    raw = text.encode("utf-8")
    if len(raw) <= MAX_PAYLOAD:
        return text
    ell = "…"
    raw = raw[:MAX_PAYLOAD - len(ell.encode("utf-8"))]
    while raw:
        try:
            return raw.decode("utf-8") + ell
        except UnicodeDecodeError:
            raw = raw[:-1]
    return ""

# ---------------------------------------------------------------------------
# 本地 CSV 日志
# ---------------------------------------------------------------------------

CSV_HEADER = "timestamp,uptime_s,v_out,i_out,duty,v_set,i_set,flags,fault"


class CsvLogger:
    """板卡本地 CSV 日志：每行 flush，周期性 fsync，按大小轮转。

    flags / fault 两列写十进制整数，方便 pandas / Excel 直接当数字处理。
    """

    def __init__(self, path: str, max_bytes: int = 5 * 1024 * 1024,
                 fsync_interval: float = 5.0) -> None:
        self.path = os.path.abspath(path)
        self.max_bytes = int(max_bytes)
        self.fsync_interval = float(fsync_interval)
        self.rows = 0            # 累计写入行数
        self.rotations = 0       # 轮转次数
        self.ok = False          # 日志是否正常（对应 flags 的 LOG_OK 位）
        self.last_error = ""
        self._fp = None
        self._written = 0        # 当前文件已写字节数
        self._last_fsync = 0.0
        self._open()

    # -- 内部 ---------------------------------------------------------------
    def _open(self) -> None:
        directory = os.path.dirname(self.path)
        if directory and not os.path.isdir(directory):
            os.makedirs(directory, exist_ok=True)
        need_header = (not os.path.exists(self.path)) or os.path.getsize(self.path) == 0
        self._fp = open(self.path, "a", encoding="utf-8", newline="")
        self._written = 0 if need_header else os.path.getsize(self.path)
        if need_header:
            line = CSV_HEADER + "\n"
            self._fp.write(line)
            self._written += len(line.encode("utf-8"))
        self._fp.flush()
        try:
            os.fsync(self._fp.fileno())
        except OSError:
            pass
        self._last_fsync = time.monotonic()
        self.ok = True
        self.last_error = ""

    def _rotate(self) -> None:
        """超限则把当前文件改名为 <path>.1 并重新开头。"""
        try:
            self._fp.close()
        except Exception:
            pass
        backup = self.path + ".1"
        try:
            if os.path.exists(backup):
                os.remove(backup)
            os.replace(self.path, backup)
        except OSError as exc:                      # 轮转失败就直接清空续写
            self.last_error = "轮转失败：%s" % exc
        self.rotations += 1
        self._open()

    # -- 对外 ---------------------------------------------------------------
    def log(self, uptime_s: float, st: Status, now: float = None) -> None:
        """写一行记录。任何 IO 异常都不会向上抛，只把 ok 置 False。"""
        if self._fp is None:
            return
        stamp = datetime.now().astimezone().isoformat(timespec="milliseconds")
        line = "%s,%.3f,%.4f,%.4f,%.4f,%.4f,%.4f,%d,%d\n" % (
            stamp, uptime_s, st.v_out, st.i_out, st.duty, st.v_set, st.i_set,
            int(st.flags), int(st.fault))
        try:
            if self._written + len(line.encode("utf-8")) > self.max_bytes:
                self._rotate()
            self._fp.write(line)
            self._fp.flush()                        # 每行都 flush：进程被 kill 也不丢行
            self._written += len(line.encode("utf-8"))
            self.rows += 1
            self.ok = True
            now = time.monotonic() if now is None else now
            if now - self._last_fsync >= self.fsync_interval:
                os.fsync(self._fp.fileno())         # 周期性落盘：模拟掉电不丢日志
                self._last_fsync = now
        except Exception as exc:                    # noqa: BLE001 - 日志失败不能拖垮板卡
            self.ok = False
            self.last_error = str(exc)

    def close(self) -> None:
        if self._fp is not None:
            try:
                self._fp.flush()
                os.fsync(self._fp.fileno())
            except Exception:
                pass
            try:
                self._fp.close()
            except Exception:
                pass
            self._fp = None
        self.ok = False


# ---------------------------------------------------------------------------
# 模拟板卡
# ---------------------------------------------------------------------------

class SimBoard:
    """一块模拟的 DC-DC 控制板。

    对外关键接口：
        feed(data) -> bytes     喂入 PC 发来的字节流，返回要立刻回给 PC 的字节流
        take_async() -> bytes   取走板卡主动产生的字节（周期 STATUS / TEXT 日志）
        status_frame() -> bytes 立即组一帧 STATUS
        tick(dt)                按 dt 秒推进物理模型与保护逻辑
    """

    V_BUS_DEFAULT = 24.0          # 母线电压 V
    R_LOAD_DEFAULT = 10.0         # 负载电阻 Ω
    TAU_OUT = 0.05                # 输出电压一阶时间常数 s
    TAU_DUTY = 0.08               # 占空比闭环时间常数 s
    DUTY_MAX = 95.0               # 占空比上限 %
    I_TRIP = 8.0                  # 过流保护阈值 A
    OVP_RATIO = 1.15              # 过压保护比例（相对 v_set）
    T_TRIP = 85.0                 # 过温保护阈值 ℃
    HOST_TIMEOUT = 3.0            # 上位机超时时间 s
    VREF_LIMIT_V = 48.0           # 电压给定上限（对齐 PL 0x58 寄存器 = 48V）
    NOISE = 0.005                 # 测量噪声幅度（约 0.5%）
    T_AMBIENT = 25.0              # 环境温度 ℃
    R_TH = 1.5                    # 热阻 K/W
    C_TH = 8.0                    # 热容 J/K

    def __init__(self, v_bus: float = V_BUS_DEFAULT, r_load: float = R_LOAD_DEFAULT,
                 v_set: float = 12.0, i_set: float = 5.0,
                 push_period: float = 1.0, push_enabled: bool = True,
                 csv_logger: CsvLogger = None, tick_period: float = 1.0,
                 seed: int = None, verbose: bool = False) -> None:
        self.v_bus = float(v_bus)
        self.r_load_base = float(r_load)
        self.r_load = float(r_load)

        # --- 设定值 / 输出 ---
        self.v_set = float(v_set)
        self.i_set = float(i_set)
        self.output_en = False

        # --- 真实物理状态 ---
        self.duty = 0.0            # %
        self.v_out_true = 0.0      # V（不含噪声）
        self.i_out_true = 0.0      # A
        self.temp = self.T_AMBIENT

        # --- 测量值（含噪声，上报用）---
        self.v_meas = 0.0
        self.i_meas = 0.0

        # --- 故障 / 保护 ---
        self.fault = FAULT_NONE
        self.fault_latched = False
        self.trip_count = 0

        # --- 通信状态 ---
        self.parser = FrameParser()
        self.rx_frames = 0
        self.tx_frames = 0
        self.seq_tx = 0
        self._async = bytearray()
        self._last_host_rx = None
        self.host_online = False
        self.host_timeout_count = 0     # 上位机掉线次数

        # --- 时间 ---
        self.t = 0.0                    # 板卡运行时间 s（由 tick 累加）
        self.last_tick = time.monotonic()
        self.host_time = None           # 上位机下发的 Unix 秒（SET_TIME，这里只记录）
        self.push_period = float(push_period)
        self.push_enabled = bool(push_enabled)
        self._last_push = time.monotonic()

        # --- 日志 ---
        self.csv = csv_logger
        self.csv_period = float(tick_period)
        self._csv_acc = 0.0
        self.tick_count = 0

        self.verbose = verbose
        self.rng = random.Random(seed)

    # ------------------------------------------------------------------
    # 状态组装
    # ------------------------------------------------------------------
    def flags(self) -> int:
        f = FLAG_RUNNING                       # 板卡上电运行中，恒为 1
        if self.output_en:
            f |= FLAG_OUTPUT_EN
        if self.fault == FAULT_OVP:
            f |= FLAG_OVP
        elif self.fault == FAULT_OCP:
            f |= FLAG_OCP
        elif self.fault == FAULT_OTP:
            f |= FLAG_OTP
        if self.host_online:
            f |= FLAG_HOST_ONLINE
        if self.csv is not None and self.csv.ok:
            f |= FLAG_LOG_OK
        return f

    def pl_status(self) -> int:
        """模拟板卡的 PL 状态位图（真实板卡来自 0x4C 寄存器快照）。

        只填"确实有对应硬件行为"的位：ADC 就绪 / PLL 锁定 / 输出相关。
        故障本身通过 fault 码上报，不在这里重复表达。
        """
        s = PL_ADC_INITIALIZED | PL_PLL_LOCKED
        if self.output_en:
            s |= PL_OUTPUT_ACTIVE | PL_OUTPUT_REQUEST | PL_PWM_ARMED
        return s

    def status(self) -> Status:
        """当前状态快照（上报值带测量噪声）。"""
        return Status(flags=self.flags(),
                      v_out=self.v_meas, i_out=self.i_meas, duty=self.duty,
                      v_set=self.v_set, i_set=0.0,       # 电流给定未实现，恒 0
                      fault=self.fault, reserved=self.pl_status())

    def _next_seq(self) -> int:
        self.seq_tx = (self.seq_tx + 1) & 0xFF
        return self.seq_tx

    def status_frame(self) -> bytes:
        """立即组一帧 STATUS（占用一个发送序号）。"""
        self.tx_frames += 1
        return build_frame(CMD_STATUS, self.status().encode(), self._next_seq())

    def queue_text(self, text: str) -> None:
        """往异步发送队列塞一条板卡日志（TEXT 帧，超长自动截断）。"""
        text = fit_text(text)
        self.tx_frames += 1
        self._async += build_frame(CMD_TEXT, encode_text(text), self._next_seq())
        if self.verbose:
            print("[板卡][日志] %s" % text)
            sys.stdout.flush()

    def take_async(self) -> bytes:
        """取走板卡主动产生的字节（周期 STATUS、TEXT）。"""
        if not self._async:
            return b""
        out = bytes(self._async)
        self._async.clear()
        return out

    # ------------------------------------------------------------------
    # 接收 PC 数据
    # ------------------------------------------------------------------
    def feed(self, data: bytes) -> bytes:
        """喂入上位机发来的字节流，返回需要立刻回给上位机的字节流。"""
        now = time.monotonic()
        self._last_host_rx = now
        self._set_host_online(True)

        out = bytearray()
        frames = self.parser.feed(data)
        for fr in frames:
            self.rx_frames += 1
            try:
                out += self._handle(fr)
            except ProtocolError as exc:
                self.queue_text("协议错误：%s" % exc)
                out += build_frame(CMD_NACK, pack_byte(fr.cmd), self._next_seq())
        return bytes(out)

    def _handle(self, fr: Frame) -> bytes:
        cmd = fr.cmd

        if cmd == CMD_READ_STATUS:
            return self.status_frame()

        if cmd == CMD_HEARTBEAT:
            return self._ack(fr.seq, ACK_OK)     # 与真实板卡一致：回 ACK

        if cmd == CMD_SET_TIME:
            try:
                secs = unpack_time(fr.payload)
            except ProtocolError:
                return self._ack(fr.seq, ACK_BAD_PARAM)
            self.host_time = secs               # 模拟板卡只记录，不改系统时间
            self.queue_text("时间已同步(模拟)：%s"
                            % time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(secs)))
            return self._ack(fr.seq, ACK_OK)

        if cmd == CMD_SET_SETPOINT:
            try:
                v, i = unpack_setpoint(fr.payload)
            except ProtocolError:
                self.queue_text("SET_SETPOINT 负载长度错误")
                return self._ack(fr.seq, ACK_BAD_PARAM)
            if not (0.0 <= v <= self.VREF_LIMIT_V):
                self.queue_text("电压给定越界拒绝 Vset=%.2fV（允许 0~48V）" % v)
                return self._ack(fr.seq, ACK_BAD_PARAM)
            self.v_set = v
            if i != 0.0:
                # 真实板卡未实现电流给定：明确返回"不支持"，不谎报成功
                self.queue_text("电压给定 %.2fV 已生效；电流给定未实现（忽略）" % v)
                return self._ack(fr.seq, ACK_UNSUPPORTED)
            self.queue_text("给定更新 Vset=%.2fV" % v)
            return self._ack(fr.seq, ACK_OK)

        if cmd == CMD_SET_OUTPUT:
            try:
                en = unpack_byte(fr.payload)
            except ProtocolError:
                return self._ack(fr.seq, ACK_BAD_PARAM)
            if en:
                if self.fault != FAULT_NONE:
                    self.queue_text("拒绝开输出:有未清故障(%s)"
                                    % FAULT_NAMES.get(self.fault, self.fault))
                    return self._ack(fr.seq, ACK_FAULT_LATCHED)
                if self.v_set <= 0.0:
                    self.queue_text("零给定不能开输出，请先下发电压给定")
                    return self._ack(fr.seq, ACK_BAD_PARAM)
                if not self.output_en:
                    self.output_en = True
                    self.queue_text("输出已使能")
            else:
                if self.output_en:
                    self.output_en = False
                    self.queue_text("输出已关闭（上位机指令）")
            return self._ack(fr.seq, ACK_OK)

        if cmd == CMD_CLEAR_FAULT:
            # 对齐 2026-10-15 硬件：清故障会关闭输出并清零给定；ADC 驱动故障需系统复位清不掉
            if self.fault == FAULT_ADC:
                self.queue_text("ADC 驱动故障需系统复位，软件清不掉")
                return self._ack(fr.seq, ACK_FAULT_LATCHED)
            if self.fault != FAULT_NONE:
                self.fault = FAULT_NONE
                self.output_en = False
                self.v_set = 0.0
                self.queue_text("故障已清，输出保持关闭、给定已清零；请重设给定再单独开输出")
            else:
                self.queue_text("无故障，清故障为空操作")
            return self._ack(fr.seq, ACK_OK)

        # 未知命令
        self.queue_text("收到未知命令 0x%02X" % cmd)
        return build_frame(CMD_NACK, pack_byte(cmd), self._next_seq())

    def _ack(self, seq: int, code: int) -> bytes:
        self.tx_frames += 1
        return build_frame(CMD_ACK, pack_byte(code), seq)

    # ------------------------------------------------------------------
    # 物理模型
    # ------------------------------------------------------------------
    def tick(self, dt: float) -> None:
        """按 dt 秒推进模拟。dt <= 0 时只做时间同步，不推进物理。"""
        if dt < 0:
            dt = 0.0
        self.t += dt
        self.tick_count += 1
        now = time.monotonic()

        # --- 上位机在线判定（3 秒无数据即离线，但板卡本地继续运行）---
        if self._last_host_rx is None or (now - self._last_host_rx) > self.HOST_TIMEOUT:
            self._set_host_online(False)

        if dt > 0.0:
            # --- 负载缓慢波动（两个不同周期的正弦叠加，模拟负载变化）---
            self.r_load = self.r_load_base * (
                1.0 + 0.08 * math.sin(2.0 * math.pi * self.t / 7.3)
                + 0.03 * math.sin(2.0 * math.pi * self.t / 1.7))

            # --- duty 闭环：目标 duty = v_set / v_bus * 100 ---
            if self.output_en and self.fault == FAULT_NONE:
                target_duty = self.v_set / self.v_bus * 100.0
            else:
                target_duty = 0.0
            target_duty = max(0.0, min(self.DUTY_MAX, target_duty))
            alpha_d = 1.0 - math.exp(-dt / self.TAU_DUTY)
            self.duty += (target_duty - self.duty) * alpha_d
            self.duty = max(0.0, min(self.DUTY_MAX, self.duty))

            # --- v_out 一阶跟随 duty/100*v_bus；未使能时指数衰减到 0 ---
            target_v = self.duty / 100.0 * self.v_bus
            alpha_v = 1.0 - math.exp(-dt / self.TAU_OUT)
            self.v_out_true += (target_v - self.v_out_true) * alpha_v
            if self.v_out_true < 0.0:
                self.v_out_true = 0.0

            # --- 电流 ---
            self.i_out_true = self.v_out_true / self.r_load

            # --- 结温模型：热源 = I²·Rds 等效，向环境散热 ---
            heat = self.i_out_true * self.i_out_true * 1.0        # W
            d_temp = (heat - (self.temp - self.T_AMBIENT) / self.R_TH) / self.C_TH * dt
            self.temp += d_temp

            self._measure()
            self._protect()

        # --- 本地 CSV 采样（与串口无关，独立进行）---
        if self.csv is not None:
            self._csv_acc += dt
            if self._csv_acc >= self.csv_period:
                self._csv_acc = 0.0
                self.csv.log(self.t, self.status(), now)

    def _measure(self) -> None:
        """加入约 0.5% 测量噪声，供上报与记录。"""
        n = self.NOISE
        self.v_meas = max(0.0, self.v_out_true * (1.0 + self.rng.uniform(-n, n)))
        self.i_meas = max(0.0, self.i_out_true * (1.0 + self.rng.uniform(-n, n)))

    def _protect(self) -> None:
        """保护逻辑：任一条动作就关闭输出并锁存故障码。"""
        if self.fault != FAULT_NONE or not self.output_en:
            return
        if self.v_set >= 1.0 and self.v_out_true > self.v_set * self.OVP_RATIO:
            self.trip(FAULT_OVP, "Vout=%.2f>%.2f*%.2f"
                      % (self.v_out_true, self.v_set, self.OVP_RATIO))
        elif self.i_out_true > self.I_TRIP:
            self.trip(FAULT_OCP, "Iout=%.2f>%.1f" % (self.i_out_true, self.I_TRIP))
        elif self.temp > self.T_TRIP:
            self.trip(FAULT_OTP, "T=%.1fC>%.0fC" % (self.temp, self.T_TRIP))

    def trip(self, code: int, detail: str = "") -> None:
        """触发保护：记录故障码 + 立即关闭输出（需要 CLEAR_FAULT 才能恢复）。"""
        if self.fault != FAULT_NONE:
            return
        self.fault = code
        self.fault_latched = True
        self.output_en = False
        self.trip_count += 1
        self.queue_text("保护动作:%s %s,输出已关,需清故障"
                        % (FAULT_NAMES.get(code, code), detail))

    # ------------------------------------------------------------------
    # 周期推送
    # ------------------------------------------------------------------
    def _set_host_online(self, online: bool) -> None:
        if online == self.host_online:
            return
        self.host_online = online
        if online:
            self.queue_text("上位机已连接,HOST_ONLINE 置位")
        else:
            self.host_timeout_count += 1
            self.queue_text("上位机超时%.0fs离线,本地继续运行,输出保持"
                            % self.HOST_TIMEOUT)

    def maybe_push_status(self, now: float = None) -> bool:
        """到了推送周期就往异步队列塞一帧 STATUS。返回是否推送了。"""
        if not self.push_enabled:
            return False
        now = time.monotonic() if now is None else now
        if now - self._last_push >= self.push_period:
            self._last_push = now
            self._async += self.status_frame()
            return True
        return False

    # ------------------------------------------------------------------
    def close(self) -> None:
        if self.csv is not None:
            self.csv.close()

    def summary(self) -> str:
        return ("[板卡汇总] 运行 %.1fs  收帧=%d 发帧=%d  保护动作=%d 次  "
                "上位机掉线=%d 次  CSV 行数=%s"
                % (self.t, self.rx_frames, self.tx_frames, self.trip_count,
                   self.host_timeout_count,
                   self.csv.rows if self.csv else "未启用"))


# ---------------------------------------------------------------------------
# TCP 服务端（把 socket 字节流接到 SimBoard 上）
# ---------------------------------------------------------------------------

def _parse_hostport(text: str, default_port: int = 5560):
    """解析 "host:port" / "port" / ":port"。"""
    text = (text or "").strip()
    if not text:
        return "127.0.0.1", default_port
    if ":" in text:
        host, _, port = text.rpartition(":")
        return (host or "127.0.0.1"), int(port)
    if text.isdigit():
        return "127.0.0.1", int(text)
    return text, default_port


def run_tcp_server(bind_host: str, bind_port: int, board: SimBoard,
                   duration: float = None, verbose: bool = True) -> int:
    """起一个 TCP 服务端，把每个客户端收到的字节喂给 board.feed() 并回写。

    单线程 selectors 实现，支持多个客户端共用同一块板卡：
      * 应答只回给发起请求的客户端
      * 周期 STATUS 与板卡日志（TEXT）广播给所有客户端
    """
    sel = selectors.DefaultSelector()
    lsock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    lsock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    lsock.bind((bind_host, bind_port))
    lsock.listen(4)
    lsock.setblocking(False)
    sel.register(lsock, selectors.EVENT_READ, data=None)
    clients = {}                                  # socket -> 对端地址

    if verbose:
        print("[板卡] TCP 服务端已启动：%s:%d（Ctrl+C 退出）" % (bind_host, bind_port))
        sys.stdout.flush()

    t_start = time.monotonic()
    last = t_start
    last_report = t_start
    exit_code = 0
    try:
        while True:
            now = time.monotonic()
            dt = now - last
            last = now

            board.tick(dt)
            board.maybe_push_status(now)

            for key, _mask in sel.select(timeout=0.02):
                if key.data is None:                       # 新连接
                    try:
                        conn, addr = lsock.accept()
                    except OSError:
                        continue
                    conn.settimeout(2.0)                   # 阻塞式发送，但带超时兜底
                    sel.register(conn, selectors.EVENT_READ, data=addr)
                    clients[conn] = addr
                    if verbose:
                        print("[板卡] 客户端接入 %s:%d（当前 %d 个）"
                              % (addr[0], addr[1], len(clients)))
                        sys.stdout.flush()
                else:                                      # 已有连接可读
                    conn = key.fileobj
                    try:
                        data = conn.recv(4096)
                    except (ConnectionResetError, socket.timeout, OSError) as exc:
                        data = None
                        if verbose:
                            print("[板卡] 客户端读取异常：%s" % exc)
                    if not data:
                        _drop_client(sel, clients, conn, verbose)
                        continue
                    reply = board.feed(data)
                    if reply:
                        try:
                            conn.sendall(reply)
                        except OSError as exc:
                            if verbose:
                                print("[板卡] 回写失败：%s" % exc)
                            _drop_client(sel, clients, conn, verbose)

            # 广播板卡主动产生的字节（周期 STATUS / 事件日志）
            pending = board.take_async()
            if pending:
                for conn in list(clients):
                    try:
                        conn.sendall(pending)
                    except OSError:
                        _drop_client(sel, clients, conn, verbose)

            if verbose and now - last_report >= 2.0:
                last_report = now
                st = board.status()
                print("[板卡] t=%6.1fs %s 客户端=%d 温度=%.1f℃"
                      % (board.t, st.one_line(), len(clients), board.temp))
                sys.stdout.flush()

            if duration is not None and (now - t_start) >= duration:
                if verbose:
                    print("[板卡] 已到达 --duration %.1fs，正常退出" % duration)
                break
    except KeyboardInterrupt:
        if verbose:
            print("\n[板卡] 收到 Ctrl+C，正常退出")
    finally:
        for conn in list(clients):
            try:
                conn.close()
            except OSError:
                pass
        clients.clear()
        try:
            sel.close()
        except Exception:
            pass
        try:
            lsock.close()
        except OSError:
            pass
    return exit_code


def _drop_client(sel, clients, conn, verbose) -> None:
    addr = clients.pop(conn, None)
    try:
        sel.unregister(conn)
    except Exception:
        pass
    try:
        conn.close()
    except OSError:
        pass
    if verbose and addr:
        print("[板卡] 客户端断开 %s:%d（剩余 %d 个）" % (addr[0], addr[1], len(clients)))
        sys.stdout.flush()


def run_embedded(board: SimBoard, duration: float = None, verbose: bool = True) -> int:
    """不起 socket，只按真实时间推进物理模型与 CSV 日志。"""
    if verbose:
        print("[板卡] 嵌入式模式（无 socket），仅运行物理模型与本地 CSV 日志")
        sys.stdout.flush()
    t_start = time.monotonic()
    last = t_start
    last_report = t_start
    try:
        while True:
            now = time.monotonic()
            dt = now - last
            last = now
            board.tick(dt)
            board.maybe_push_status(now)
            board.take_async()                       # 没人连，直接丢弃
            if verbose and now - last_report >= 2.0:
                last_report = now
                print("[板卡] t=%6.1fs %s" % (board.t, board.status().one_line()))
                sys.stdout.flush()
            if duration is not None and (now - t_start) >= duration:
                break
            time.sleep(0.01)
    except KeyboardInterrupt:
        if verbose:
            print("\n[板卡] 收到 Ctrl+C，正常退出")
    return 0


# ---------------------------------------------------------------------------
# 命令行
# ---------------------------------------------------------------------------

def build_arg_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="sim_board.py",
        description="DC-DC 电源控制板【模拟板卡】：模拟物理行为 + 本地 CSV 日志 + TCP 服务端",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="示例：\n"
               "  python sim_board.py --tcp 127.0.0.1:5560 --csv sim_log.csv\n"
               "  python sim_board.py --tcp 127.0.0.1:5560 --csv sim_log.csv --duration 8\n"
               "  python sim_board.py --embedded --duration 5 --csv test.csv\n")
    p.add_argument("--tcp", metavar="HOST:PORT", default=None,
                   help="TCP 监听地址，例如 127.0.0.1:5560；不给则进入嵌入式模式")
    p.add_argument("--embedded", action="store_true",
                   help="嵌入式模式：不起 socket，只跑物理模型（供上层 import 或本地验证）")
    p.add_argument("--csv", metavar="PATH", default="sim_log.csv",
                   help="本地 CSV 日志路径（默认 sim_log.csv）")
    p.add_argument("--no-csv", action="store_true", help="关闭本地 CSV 日志")
    p.add_argument("--csv-max-mb", type=float, default=5.0,
                   help="CSV 轮转大小上限 MB（默认 5）")
    p.add_argument("--duration", type=float, default=None,
                   help="运行 N 秒后自动退出（自动化测试用）")
    p.add_argument("--v-set", type=float, default=12.0, help="上电初始电压给定 V（默认 12）")
    p.add_argument("--i-set", type=float, default=5.0, help="上电初始电流给定 A（默认 5）")
    p.add_argument("--output-on", action="store_true", help="上电就把输出打开（默认关闭）")
    p.add_argument("--push-period", type=float, default=1.0,
                   help="主动推送 STATUS 的周期秒（默认 1.0）")
    p.add_argument("--no-push", action="store_true", help="关闭周期主动推送 STATUS")
    p.add_argument("--seed", type=int, default=None, help="随机种子（复现用）")
    p.add_argument("--quiet", action="store_true", help="少打印")
    return p


def main(argv=None) -> int:
    args = build_arg_parser().parse_args(argv)

    logger = None
    if not args.no_csv:
        logger = CsvLogger(args.csv, max_bytes=int(args.csv_max_mb * 1024 * 1024))
        if not args.quiet:
            print("[板卡] 本地 CSV 日志：%s（上限 %.1fMB，每行 flush，周期 fsync）"
                  % (logger.path, args.csv_max_mb))

    board = SimBoard(v_set=args.v_set, i_set=args.i_set,
                     push_period=args.push_period, push_enabled=not args.no_push,
                     csv_logger=logger, seed=args.seed, verbose=not args.quiet)
    board.output_en = bool(args.output_on)

    verbose = not args.quiet
    try:
        if args.tcp and not args.embedded:
            host, port = _parse_hostport(args.tcp)
            run_tcp_server(host, port, board, duration=args.duration, verbose=verbose)
        else:
            run_embedded(board, duration=args.duration, verbose=verbose)
    except OSError as exc:
        print("[板卡] 网络错误：%s" % exc, file=sys.stderr)
        return 1
    finally:
        if verbose:
            print(board.summary())
            if logger is not None and logger.last_error:
                print("[板卡] CSV 日志异常：%s" % logger.last_error)
        board.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
