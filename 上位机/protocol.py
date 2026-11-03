# -*- coding: utf-8 -*-
"""
protocol.py —— DC-DC 电源控制板通信协议（PC 上位机 / 模拟板卡 / 以后真实板卡固件 共用的唯一真相）

本文件是整条链路里"协议"的唯一实现来源：
  * PC 上位机 (host.py) 用它打包/解包
  * 模拟板卡 (sim_board.py) 用它打包/解包
  * 以后写 C 版板卡固件时，按本文件与 README 中的偏移表逐字节对齐即可

===============================================================================
帧格式（所有多字节整数均为小端 little-endian）
===============================================================================
 偏移   长度    字段      说明
  0      1     SOF1      0xAA
  1      1     SOF2      0x55
  2      1     LEN       长度 = 2 + len(payload)，即 CMD+SEQ+PAYLOAD 的字节数
  3      1     CMD       命令码
  4      1     SEQ       序号（0~255 循环，用于配对 ACK）
  5    LEN-2   PAYLOAD   负载，0 ~ 64 字节
 3+LEN   2     CRC16     MODBUS CRC16，低字节先发，高字节后发
--------------------------------------------------------------------------
 整帧长度 = LEN + 5

CRC16 参数：
  多项式 0xA001（MODBUS 反射多项式），初值 0xFFFF，输入/输出均不反转，无异或输出
  覆盖范围：从 LEN 字节开始，到 PAYLOAD 末尾结束（不含 SOF1/SOF2，也不含 CRC 自身）

===============================================================================
命令码
===============================================================================
  0x01 READ_STATUS   PC -> 板   无 payload        请求一帧 STATUS
  0x02 SET_SETPOINT  PC -> 板   <ff  v_set,i_set 设置输出电压/电流给定
  0x03 SET_OUTPUT    PC -> 板   <B   0/1          输出使能
  0x04 HEARTBEAT     PC -> 板   无 payload        心跳，维持 HOST_ONLINE
  0x05 CLEAR_FAULT   PC -> 板   无 payload        清故障（清完才允许重新开输出）
  0x06 SET_TIME      PC -> 板   <Q   Unix 秒(UTC)  板卡据此校准本地时钟（CSV 时间戳用）
  0x81 ACK           板 -> PC   <B   结果码        0=成功，非 0=失败
  0x82 STATUS        板 -> PC   26 字节          板卡实时状态，见下
  0x83 NACK          板 -> PC   <B   被拒命令码   未知/非法命令
  0x84 TEXT          板 -> PC   UTF-8 文本        板卡侧日志透传

===============================================================================
STATUS payload（固定 26 字节，struct 格式 "<HfffffHH"，小端、无对齐填充）
===============================================================================
 偏移   长度  字段        类型    单位   说明
  0      2   flags       u16     -      标志位，见下
  2      4   v_out       f32     V      实测输出电压
  6      4   i_out       f32     A      实测输出电流
 10      4   duty        f32     %      当前占空比
 14      4   v_set       f32     V      电压给定
 18      4   i_set       f32     A      电流给定（限流点）
 22      2   fault       u16     -      故障码，见 FAULT_NAMES
 24      2   pl_status    u16     -      PL 输出/状态位图快照（0x4C），见 PL_* 位定义

===============================================================================
PL 状态位（STATUS.pl_status，来自 PL 的 0x4C OUTPUT_STATUS 寄存器快照）
===============================================================================
  bit0 PL_OUTPUT_REQUEST   软件请求开启输出
  bit1 PL_OUTPUT_ACTIVE    实际 PWM 输出已使能（★ 界面"输出开"应看这一位）
  bit2 PL_ADC_INITIALIZED  ADC 初始化完成
  bit3 PL_ADC_ERROR        ADC 故障锁存（触发 PWM 关断）
  bit4 PL_PLL_LOCKED       PLL 已锁定
  bit5 PL_PWM_ARMED        PWM 已在周期边界完成使能
  bit6 PL_SAMPLE_OVERRUN   控制计算忙时到达新样本（锁存诊断）

===============================================================================
flags 位定义
===============================================================================
  bit0 RUNNING      板卡运行中（上电后主循环在跑；本模拟器实现为恒 1）
  bit1 OUTPUT_EN    输出已使能
  bit2 OVP          过压保护已触发
  bit3 OCP          过流保护已触发
  bit4 OTP          过温保护已触发
  bit5 HOST_ONLINE  上位机在线（3 秒内收到过上位机数据）
  bit6 LOG_OK       板卡本地 CSV 日志正常
  bit7~15           保留

===============================================================================
直接运行本文件会执行自测：  python protocol.py
===============================================================================
"""

from __future__ import annotations

import struct
from dataclasses import dataclass, field
from typing import List, Optional

__all__ = [
    "SOF1", "SOF2", "MAX_PAYLOAD", "HEADER_SIZE", "FRAME_OVERHEAD",
    "CMD_READ_STATUS", "CMD_SET_SETPOINT", "CMD_SET_OUTPUT", "CMD_HEARTBEAT",
    "CMD_CLEAR_FAULT", "CMD_ACK", "CMD_STATUS", "CMD_NACK", "CMD_TEXT",
    "CMD_SET_TIME",
    "FLAG_RUNNING", "FLAG_OUTPUT_EN", "FLAG_OVP", "FLAG_OCP", "FLAG_OTP",
    "FLAG_HOST_ONLINE", "FLAG_LOG_OK",
    "PL_OUTPUT_REQUEST", "PL_OUTPUT_ACTIVE", "PL_ADC_INITIALIZED",
    "PL_ADC_ERROR", "PL_PLL_LOCKED", "PL_PWM_ARMED", "PL_SAMPLE_OVERRUN",
    "PL_BITS", "PL_STATUS_TEXTS",
    "FAULT_NONE", "FAULT_OVP", "FAULT_OCP", "FAULT_OTP", "FAULT_ADC", "FAULT_OVERRUN", "FAULT_NAMES",
    "FAULT_TEXTS", "FLAG_BITS", "STATUS_STRUCT", "STATUS_PAYLOAD_SIZE",
    "CMD_NAMES", "ACK_OK", "ACK_BAD_PARAM", "ACK_FAULT_LATCHED",
    "ACK_UNSUPPORTED", "ACK_TEXTS", "MIN_LEN", "MAX_LEN",
    "ProtocolError", "crc16_modbus", "build_frame", "Frame", "FrameParser",
    "Status", "decode_status", "decode_text", "encode_text", "parse_frame",
    "pack_setpoint", "unpack_setpoint", "pack_byte", "unpack_byte",
    "pack_time", "unpack_time",
]

# ---------------------------------------------------------------------------
# 常量
# ---------------------------------------------------------------------------

SOF1 = 0xAA                     # 帧头第 1 字节
SOF2 = 0x55                     # 帧头第 2 字节
SOF = bytes((SOF1, SOF2))       # 帧头
MAX_PAYLOAD = 64                # payload 最大字节数
HEADER_SIZE = 5                 # SOF1+SOF2+LEN+? 之外的固定开销：SOF1,SOF2,LEN,CRC_LO,CRC_HI
FRAME_OVERHEAD = 5              # 整帧长度 = LEN + FRAME_OVERHEAD
MIN_LEN = 2                     # LEN 最小值（CMD+SEQ，payload 为空）
MAX_LEN = MIN_LEN + MAX_PAYLOAD # LEN 最大值 = 66

# 命令码
CMD_READ_STATUS = 0x01
CMD_SET_SETPOINT = 0x02
CMD_SET_OUTPUT = 0x03
CMD_HEARTBEAT = 0x04
CMD_CLEAR_FAULT = 0x05
CMD_SET_TIME = 0x06
CMD_ACK = 0x81
CMD_STATUS = 0x82
CMD_NACK = 0x83
CMD_TEXT = 0x84

CMD_NAMES = {
    CMD_READ_STATUS: "READ_STATUS",
    CMD_SET_SETPOINT: "SET_SETPOINT",
    CMD_SET_OUTPUT: "SET_OUTPUT",
    CMD_HEARTBEAT: "HEARTBEAT",
    CMD_CLEAR_FAULT: "CLEAR_FAULT",
    CMD_SET_TIME: "SET_TIME",
    CMD_ACK: "ACK",
    CMD_STATUS: "STATUS",
    CMD_NACK: "NACK",
    CMD_TEXT: "TEXT",
}

# flags 位
FLAG_RUNNING = 1 << 0       # 板卡运行中
FLAG_OUTPUT_EN = 1 << 1     # 输出使能
FLAG_OVP = 1 << 2           # 过压
FLAG_OCP = 1 << 3           # 过流
FLAG_OTP = 1 << 4           # 过温
FLAG_HOST_ONLINE = 1 << 5   # 上位机在线
FLAG_LOG_OK = 1 << 6        # 本地日志正常

# (位掩码, 英文短名, 中文名) —— 打印与界面统一从这里取
FLAG_BITS = (
    (FLAG_RUNNING, "RUN", "运行"),
    (FLAG_OUTPUT_EN, "OUT", "输出开"),
    (FLAG_OVP, "OVP", "过压"),
    (FLAG_OCP, "OCP", "过流"),
    (FLAG_OTP, "OTP", "过温"),
    (FLAG_HOST_ONLINE, "HOST", "上位机在线"),
    (FLAG_LOG_OK, "LOG", "日志正常"),
)

# PL 状态位（对应 PL 的 0x4C OUTPUT_STATUS 寄存器）
PL_OUTPUT_REQUEST = 1 << 0     # 软件请求开启输出
PL_OUTPUT_ACTIVE = 1 << 1      # 实际 PWM 输出已使能（界面"输出开"看这一位）
PL_ADC_INITIALIZED = 1 << 2    # ADC 初始化完成
PL_ADC_ERROR = 1 << 3          # ADC 故障锁存
PL_PLL_LOCKED = 1 << 4         # PLL 已锁定
PL_PWM_ARMED = 1 << 5          # PWM 已 armed
PL_SAMPLE_OVERRUN = 1 << 6     # 采样溢出（锁存）

PL_BITS = (
    (PL_OUTPUT_REQUEST, "REQ", "输出请求"),
    (PL_OUTPUT_ACTIVE, "ACT", "输出已使能"),
    (PL_ADC_INITIALIZED, "ADCI", "ADC就绪"),
    (PL_ADC_ERROR, "ADCE", "ADC故障"),
    (PL_PLL_LOCKED, "PLL", "PLL锁定"),
    (PL_PWM_ARMED, "ARM", "PWM已使能"),
    (PL_SAMPLE_OVERRUN, "OVR", "采样溢出"),
)

PL_STATUS_TEXTS = {mask: cn for (mask, _en, cn) in PL_BITS}

# 故障码
FAULT_NONE = 0
FAULT_OVP = 1
FAULT_OCP = 2
FAULT_OTP = 3
FAULT_ADC = 4          # ADC 故障锁存（PL 0x4C.bit3）
FAULT_OVERRUN = 5      # 控制采样溢出（PL 0x4C.bit6）

FAULT_NAMES = {
    FAULT_NONE: "NONE",
    FAULT_OVP: "OVP",
    FAULT_OCP: "OCP",
    FAULT_OTP: "OTP",
    FAULT_ADC: "ADC",
    FAULT_OVERRUN: "OVERRUN",
}

FAULT_TEXTS = {
    FAULT_NONE: "无",
    FAULT_OVP: "过压保护(OVP)",
    FAULT_OCP: "过流保护(OCP)",
    FAULT_OTP: "过温保护(OTP)",
    FAULT_ADC: "ADC 故障锁存",
    FAULT_OVERRUN: "采样溢出",
}

# ACK 结果码
ACK_OK = 0
ACK_BAD_PARAM = 1        # 参数越界
ACK_FAULT_LATCHED = 2    # 有故障未清除，拒绝开输出
ACK_UNSUPPORTED = 3      # 当前状态不支持该操作

ACK_TEXTS = {
    ACK_OK: "成功",
    ACK_BAD_PARAM: "参数越界",
    ACK_FAULT_LATCHED: "有故障未清除",
    ACK_UNSUPPORTED: "当前状态不支持",
}

# STATUS 负载
STATUS_STRUCT = struct.Struct("<HfffffHH")   # flags, v_out, i_out, duty, v_set, i_set, fault, reserved
STATUS_PAYLOAD_SIZE = STATUS_STRUCT.size     # 必须是 26


class ProtocolError(Exception):
    """协议层错误（非法长度、CRC 不符、负载尺寸不对等）。"""


# ---------------------------------------------------------------------------
# CRC16 / MODBUS
# ---------------------------------------------------------------------------

def crc16_modbus(data: bytes) -> int:
    """计算 MODBUS CRC16。

    多项式 0xA001（0x8005 反射），初值 0xFFFF，逐位反射实现，无异或输出。
    习惯上发送时低字节在前。
    """
    crc = 0xFFFF
    for byte in data:
        crc ^= byte
        for _ in range(8):
            if crc & 0x0001:
                crc = (crc >> 1) ^ 0xA001
            else:
                crc >>= 1
    return crc & 0xFFFF


# ---------------------------------------------------------------------------
# 组帧
# ---------------------------------------------------------------------------

def build_frame(cmd: int, payload: bytes = b"", seq: int = 0) -> bytes:
    """按协议组一帧，返回完整字节串（含 SOF 与 CRC）。

    cmd     : 命令码，0~255
    payload : 负载，最长 MAX_PAYLOAD(64) 字节
    seq     : 序号，0~255（自动取模）
    """
    if not isinstance(payload, (bytes, bytearray, memoryview)):
        raise ProtocolError("payload 必须是 bytes")
    payload = bytes(payload)
    if len(payload) > MAX_PAYLOAD:
        raise ProtocolError("payload 过长：%d > %d" % (len(payload), MAX_PAYLOAD))
    if not (0 <= int(cmd) <= 0xFF):
        raise ProtocolError("命令码越界：%r" % (cmd,))

    length = MIN_LEN + len(payload)
    # CRC 计算范围：LEN 字节 -> PAYLOAD 末尾
    crc_region = bytes((length, int(cmd) & 0xFF, int(seq) & 0xFF)) + payload
    crc = crc16_modbus(crc_region)
    return (SOF
            + bytes((length, int(cmd) & 0xFF, int(seq) & 0xFF))
            + payload
            + bytes((crc & 0xFF, (crc >> 8) & 0xFF)))


@dataclass
class Frame:
    """一帧已通过 CRC 校验的报文。"""
    cmd: int
    seq: int
    payload: bytes = b""

    @property
    def name(self) -> str:
        """命令码的英文短名，未知命令返回 UNKNOWN(0xXX)。"""
        return CMD_NAMES.get(self.cmd, "UNKNOWN(0x%02X)" % self.cmd)

    def hex(self) -> str:
        """返回整帧十六进制串（重新组帧得到，便于日志与对照）。"""
        return build_frame(self.cmd, self.payload, self.seq).hex(" ").upper()

    def __repr__(self) -> str:  # pragma: no cover - 仅调试用
        return "Frame(cmd=0x%02X/%s, seq=%d, payload=%s)" % (
            self.cmd, self.name, self.seq, self.payload.hex(" ").upper())


# ---------------------------------------------------------------------------
# 流解析器（必须能抗噪声 / 半包 / 坏 CRC，并自动重新同步）
# ---------------------------------------------------------------------------

class FrameParser:
    """把任意字节流切成 Frame 列表的增量解析器。

    抗干扰策略：
      1. 在缓冲区里找 SOF(AA 55)；丢弃 SOF 之前的垃圾字节，计入 resyncs
      2. 长度字段非法（<2 或 >66）时，只丢弃 1 个字节，回到第 1 步重新找 SOF
      3. 凑满整帧后校验 CRC；CRC 错则只丢弃 1 个字节（不是整帧），
         这样即使帧中间恰好出现 AA 55 也能最终重新同步；计入 crc_errors
      4. 数据不足时保留剩余字节，等下次 feed()

    统计量：
      crc_errors     CRC 校验失败次数
      resyncs        重新同步（丢弃过字节才重新找到帧头）次数
      frames_ok      成功解出的帧数
      bytes_dropped  累计丢弃的字节数
    """

    def __init__(self) -> None:
        self._buf = bytearray()
        self.crc_errors = 0
        self.resyncs = 0
        self.frames_ok = 0
        self.bytes_dropped = 0

    # -- 统计 ---------------------------------------------------------------
    def reset(self) -> None:
        """清空缓冲区（统计量保留，便于统计整条连接）。"""
        self._buf.clear()

    def reset_stats(self) -> None:
        self.crc_errors = 0
        self.resyncs = 0
        self.frames_ok = 0
        self.bytes_dropped = 0

    def stats_text(self) -> str:
        return ("收帧=%d CRC错=%d 重同步=%d 丢字节=%d"
                % (self.frames_ok, self.crc_errors, self.resyncs, self.bytes_dropped))

    # -- 主流程 -------------------------------------------------------------
    def feed(self, data: bytes) -> List[Frame]:
        """喂入新收到的字节，返回本次能解出的所有帧。"""
        out: List[Frame] = []
        if data:
            self._buf.extend(bytes(data))

        while True:
            # --- 1. 找帧头 ---
            idx = self._buf.find(SOF)
            if idx < 0:
                # 没有帧头：保留最后 1 个字节（它可能是被截断的 0xAA）
                if len(self._buf) > 1:
                    drop = len(self._buf) - 1
                    del self._buf[:drop]
                    self.bytes_dropped += drop
                break
            if idx > 0:
                del self._buf[:idx]
                self.bytes_dropped += idx
                self.resyncs += 1

            # 现在 buf[0:2] == AA 55
            if len(self._buf) < 3:
                break                                  # 长度字节还没到

            length = self._buf[2]
            if length < MIN_LEN or length > MAX_LEN:
                # 非法长度：这个 AA 55 是巧合，丢掉 1 字节继续找
                del self._buf[:1]
                self.bytes_dropped += 1
                self.resyncs += 1
                continue

            total = length + FRAME_OVERHEAD
            if len(self._buf) < total:
                break                                  # 半包，等后续字节

            raw = bytes(self._buf[:total])
            crc_calc = crc16_modbus(raw[2:total - 2])
            crc_recv = raw[total - 2] | (raw[total - 1] << 8)
            if crc_calc != crc_recv:
                # CRC 错：只丢 1 字节，继续在剩余数据里找下一个 SOF
                self.crc_errors += 1
                del self._buf[:1]
                self.bytes_dropped += 1
                self.resyncs += 1
                continue

            del self._buf[:total]
            self.frames_ok += 1
            out.append(Frame(cmd=raw[3], seq=raw[4], payload=raw[5:total - 2]))

        return out


def parse_frame(data: bytes) -> Optional[Frame]:
    """便捷函数：data 恰好是一帧时返回 Frame，否则返回 None（主要用于测试）。"""
    parser = FrameParser()
    frames = parser.feed(data)
    if len(frames) == 1 and not parser._buf:  # noqa: SLF001 - 同文件内部使用
        return frames[0]
    return None


# ---------------------------------------------------------------------------
# STATUS 负载
# ---------------------------------------------------------------------------

@dataclass
class Status:
    """板卡状态（对应 STATUS 命令的 26 字节负载）。"""

    flags: int = 0
    v_out: float = 0.0
    i_out: float = 0.0
    duty: float = 0.0
    v_set: float = 0.0
    i_set: float = 0.0
    fault: int = FAULT_NONE
    reserved: int = 0

    # -- 编解码 -------------------------------------------------------------
    def encode(self) -> bytes:
        """编码为 26 字节负载。"""
        return STATUS_STRUCT.pack(
            int(self.flags) & 0xFFFF,
            float(self.v_out), float(self.i_out), float(self.duty),
            float(self.v_set), float(self.i_set),
            int(self.fault) & 0xFFFF, int(self.reserved) & 0xFFFF,
        )

    @classmethod
    def decode(cls, payload: bytes) -> "Status":
        """从 26 字节负载解码；长度不对抛 ProtocolError。"""
        payload = bytes(payload)
        if len(payload) != STATUS_PAYLOAD_SIZE:
            raise ProtocolError("STATUS 负载长度应为 %d，实际 %d"
                                % (STATUS_PAYLOAD_SIZE, len(payload)))
        (flags, v_out, i_out, duty, v_set, i_set, fault, pl_status) = \
            STATUS_STRUCT.unpack(payload)
        return cls(flags=flags, v_out=v_out, i_out=i_out, duty=duty,
                   v_set=v_set, i_set=i_set, fault=fault, reserved=pl_status)

    @classmethod
    def from_frame(cls, frame: Frame) -> "Status":
        """从 STATUS 帧解码。"""
        if frame.cmd != CMD_STATUS:
            raise ProtocolError("不是 STATUS 帧：0x%02X" % frame.cmd)
        return cls.decode(frame.payload)

    def to_frame(self, seq: int = 0) -> bytes:
        """打包成完整 STATUS 帧。"""
        return build_frame(CMD_STATUS, self.encode(), seq)

    # -- pl_status 别名（字段名仍是 reserved，含义为 PL 状态位图 0x4C）------
    @property
    def pl_status(self) -> int:
        return int(self.reserved)

    @pl_status.setter
    def pl_status(self, value: int) -> None:
        self.reserved = int(value) & 0xFFFF

    def pl_status_text(self) -> str:
        """PL 状态位中文串，例如 "输出已使能|PLL锁定|ADC就绪"。"""
        items = [cn for (mask, _en, cn) in PL_BITS if self.pl_status & mask]
        return "|".join(items) if items else "无"

    def pl_status_short(self) -> str:
        """PL 状态位英文短串，例如 "ACT|PLL|ADCI"。"""
        items = [en for (mask, en, _cn) in PL_BITS if self.pl_status & mask]
        return "|".join(items) if items else "-"

    # -- 可读化 -------------------------------------------------------------
    def flags_text(self) -> str:
        """中文可读标志串，例如 "运行|输出开|上位机在线"；无任何位置位时返回 "无"。"""
        items = [cn for (mask, _en, cn) in FLAG_BITS if self.flags & mask]
        return "|".join(items) if items else "无"

    def flags_short(self) -> str:
        """英文短标志串，例如 "RUN|OUT|HOST"；无任何位置位时返回 "-"。"""
        items = [en for (mask, en, _cn) in FLAG_BITS if self.flags & mask]
        return "|".join(items) if items else "-"

    def fault_text(self) -> str:
        """故障码中文名。"""
        return FAULT_TEXTS.get(self.fault, "未知故障(%d)" % self.fault)

    def has_flag(self, mask: int) -> bool:
        return bool(self.flags & mask)

    def one_line(self) -> str:
        """CLI 一行摘要（不含时间戳）。"""
        return ("Vout=%6.2fV Iout=%5.2fA Duty=%5.1f%% SET=%6.2fV/%5.2fA "
                "FLAGS=%-18s 故障=%s"
                % (self.v_out, self.i_out, self.duty, self.v_set, self.i_set,
                   self.flags_short(), self.fault_text()))


def decode_status(payload: bytes) -> Status:
    """便捷函数：把 26 字节 STATUS 负载解码成 Status。"""
    return Status.decode(payload)


# ---------------------------------------------------------------------------
# 文本 / 负载小工具
# ---------------------------------------------------------------------------

def decode_text(payload: bytes) -> str:
    """解码 TEXT 帧负载（UTF-8，非法字节用替换符，不抛异常）。"""
    return bytes(payload).decode("utf-8", errors="replace")


def encode_text(text: str) -> bytes:
    """编码 TEXT 帧负载（UTF-8，超长时截断到 64 字节且不切断多字节字符）。"""
    raw = text.encode("utf-8")
    if len(raw) <= MAX_PAYLOAD:
        return raw
    raw = raw[:MAX_PAYLOAD]
    while raw:
        try:
            raw.decode("utf-8")
            return raw
        except UnicodeDecodeError:
            raw = raw[:-1]
    return b""


def unpack_setpoint(payload: bytes):
    """解析 SET_SETPOINT 负载 -> (v_set, i_set)。"""
    if len(payload) != 8:
        raise ProtocolError("SET_SETPOINT 负载应为 8 字节，实际 %d" % len(payload))
    return struct.unpack("<ff", payload)


def pack_setpoint(v_set: float, i_set: float) -> bytes:
    return struct.pack("<ff", float(v_set), float(i_set))


def pack_byte(value: int) -> bytes:
    return struct.pack("<B", int(value) & 0xFF)


def unpack_byte(payload: bytes) -> int:
    if len(payload) < 1:
        raise ProtocolError("负载不足 1 字节")
    return payload[0]

def pack_time(unix_seconds) -> bytes:
    """SET_TIME 负载：<Q  Unix 秒（UTC）。"""
    return struct.pack("<Q", int(unix_seconds) & 0xFFFFFFFFFFFFFFFF)


def unpack_time(payload: bytes) -> int:
    """解析 SET_TIME 负载 -> Unix 秒（UTC）。"""
    if len(payload) != 8:
        raise ProtocolError("SET_TIME 负载应为 8 字节，实际 %d" % len(payload))
    return struct.unpack("<Q", payload)[0]



# ---------------------------------------------------------------------------
# 自测
# ---------------------------------------------------------------------------

# 已知答案测试向量（KAT）：以后 C 版固件必须能复现出同样的十六进制串。
# STATUS 向量对应的字段值：
#   flags=0x0063(RUN|OUT|HOST|LOG)  v_out=17.75V  i_out=1.5A  duty=74.5%
#   v_set=18.0V  i_set=3.25A  fault=1(OVP)  reserved=0   seq=7
KAT_STATUS_FRAME_HEX = ("AA 55 1C 82 07 63 00 00 00 8E 41 00 00 C0 3F 00 00 95 42 "
                        "00 00 90 41 00 00 50 40 01 00 00 00 E5 4C")
KAT_READ_STATUS_FRAME_HEX = "AA 55 02 01 00 D1 90"
KAT_SETPOINT_FRAME_HEX = "AA 55 0A 02 01 00 00 40 41 00 00 A0 40 C0 59"


def _selftest() -> None:
    print("=" * 78)
    print("protocol.py 自测")
    print("=" * 78)

    # --- 0. CRC 已知向量 ---------------------------------------------------
    # MODBUS 标准校验向量："123456789" 的 CRC16/MODBUS = 0x4B37
    assert crc16_modbus(b"123456789") == 0x4B37, hex(crc16_modbus(b"123456789"))
    # 协议自身 CRC 覆盖区的经典向量（LEN=0x02, CMD=0x01, SEQ=0x00）
    assert crc16_modbus(bytes((0x02, 0x01, 0x00))) == 0x90D1, \
        hex(crc16_modbus(bytes((0x02, 0x01, 0x00))))
    print("[OK] CRC16/MODBUS 已知向量：'123456789' -> 0x4B37；LEN..PAYLOAD(02 01 00) -> 0x90D1")

    assert STATUS_PAYLOAD_SIZE == 26, STATUS_PAYLOAD_SIZE
    print("[OK] STATUS 负载长度 = %d 字节（struct '<HfffffHH'）" % STATUS_PAYLOAD_SIZE)

    # --- 1. STATUS 编码 -> 组帧 -> 解析 -> 字段相等 -------------------------
    # 这里特意挑选在 IEEE754 单精度里"精确可表示"的数值（17.75 / 1.5 / 74.5 / 3.25），
    # 这样往返之后 == 比较成立，KAT 向量也便于 C 版逐字节对照。
    st = Status(flags=FLAG_RUNNING | FLAG_OUTPUT_EN | FLAG_HOST_ONLINE | FLAG_LOG_OK,
                v_out=17.75, i_out=1.5, duty=74.5, v_set=18.0, i_set=3.25,
                fault=FAULT_OVP, reserved=0)
    frame_bytes = build_frame(CMD_STATUS, st.encode(), seq=7)

    parser = FrameParser()
    frames = parser.feed(frame_bytes)
    assert len(frames) == 1, frames
    f = frames[0]
    assert f.cmd == CMD_STATUS, f.cmd
    assert f.seq == 7, f.seq
    st2 = Status.decode(f.payload)
    assert st2 == st, "\n%r\n%r" % (st, st2)
    assert st2.flags_text() == "运行|输出开|上位机在线|日志正常", st2.flags_text()
    assert st2.flags_short() == "RUN|OUT|HOST|LOG", st2.flags_short()
    assert st2.fault_text() == "过压保护(OVP)", st2.fault_text()
    print("[OK] STATUS 编码->组帧->解析->字段相等；flags_text()=%r" % st2.flags_text())

    # 非精确可表示的浮点：只要求"字节级往返一致"（float32 量化后恒等）
    stx = Status(flags=1, v_out=12.345, i_out=1.2345, duty=50.123, v_set=12.3,
                 i_set=5.05, fault=0, reserved=0)
    assert Status.decode(Status.decode(stx.encode()).encode()) == Status.decode(stx.encode())
    print("[OK] 一般浮点数值字节级往返一致（float32 量化后稳定）")

    # --- 2. 已知答案向量（KAT，供 C 版对照）--------------------------------
    kat = frame_bytes.hex(" ").upper()
    assert kat == KAT_STATUS_FRAME_HEX, "STATUS KAT 不符：\n  实际=%s\n  期望=%s" % (kat, KAT_STATUS_FRAME_HEX)
    kat2 = build_frame(CMD_READ_STATUS, b"", seq=0).hex(" ").upper()
    assert kat2 == KAT_READ_STATUS_FRAME_HEX, kat2
    kat3 = build_frame(CMD_SET_SETPOINT, pack_setpoint(12.0, 5.0), seq=1).hex(" ").upper()
    assert kat3 == KAT_SETPOINT_FRAME_HEX, kat3
    print("[OK] 已知答案测试向量（KAT）全部匹配")
    print("     READ_STATUS   (cmd=0x01, seq=0)                    : %s" % kat2)
    print("     SET_SETPOINT  (12.0V,5.0A, seq=1)                  : %s" % kat3)
    print("     STATUS        (seq=7, 字段值见文件内注释)            : %s" % kat)

    # --- 3. 抗干扰：垃圾字节 + 半包 + 错 CRC + 再跟一帧好的 -----------------
    good_a = build_frame(CMD_STATUS, st.encode(), seq=1)
    good_b = build_frame(CMD_TEXT, encode_text("板卡日志：输出已使能"), seq=2)

    noise = bytes([0x00, 0xAA, 0x11, 0xAA, 0x55, 0x03, 0x82, 0x09, 0x77, 0xEE])  # 假帧头+非法长度+垃圾
    bad_crc = bytearray(build_frame(CMD_READ_STATUS, b"", seq=3))
    bad_crc[-1] ^= 0xFF                       # 打坏 CRC 高字节
    half = good_a[:6]                          # 故意截半

    stream = noise + bytes(bad_crc) + half
    parser2 = FrameParser()
    got = parser2.feed(stream)
    assert got == [], "噪声段不应解出帧：%r" % got
    # 补上 good_a 的剩余部分，再跟一整帧 good_b
    got = parser2.feed(good_a[6:] + good_b)
    assert len(got) == 2, "应解出 2 帧，实际 %d: %r" % (len(got), got)
    assert got[0].cmd == CMD_STATUS and got[0].seq == 1, got[0]
    assert got[1].cmd == CMD_TEXT and got[1].seq == 2, got[1]
    assert decode_text(got[1].payload) == "板卡日志：输出已使能"
    assert parser2.crc_errors == 2, parser2.crc_errors   # 噪声假帧 1 次 + 人为打坏 CRC 1 次
    assert parser2.resyncs >= 2, parser2.resyncs
    print("[OK] 抗干扰重新同步：%s" % parser2.stats_text())

    # --- 4. 逐字节投喂（模拟串口一次只来 1 个字节）-------------------------
    parser3 = FrameParser()
    collected = []
    blob = good_a + good_b + good_a
    for i in range(len(blob)):
        collected.extend(parser3.feed(blob[i:i + 1]))
    assert [fr.seq for fr in collected] == [1, 2, 1], [fr.seq for fr in collected]
    assert parser3.crc_errors == 0 and parser3.resyncs == 0, parser3.stats_text()
    print("[OK] 逐字节投喂 3 帧全部正确解出（无 CRC 错、无重同步）")

    # --- 5. 只用一次 0xAA 的极端情况：单字节 0xAA 结尾不应被吃掉 -----------
    parser4 = FrameParser()
    assert parser4.feed(b"\xAA") == []
    got = parser4.feed(good_b[1:])             # 把 0x55 补上
    assert len(got) == 1 and got[0].cmd == CMD_TEXT, got
    print("[OK] 跨包截断的帧头 0xAA 能被正确保留并续接")

    # --- 6. 边界检查 -------------------------------------------------------
    try:
        build_frame(0x02, b"\x00" * (MAX_PAYLOAD + 1))
    except ProtocolError:
        pass
    else:
        raise AssertionError("超长 payload 应当报错")
    try:
        Status.decode(b"\x00" * 25)
    except ProtocolError:
        pass
    else:
        raise AssertionError("错误长度的 STATUS 负载应当报错")
    print("[OK] 边界检查：超长 payload / 错误 STATUS 长度 均正确报错")

    print("-" * 78)
    print("SELFTEST OK")


if __name__ == "__main__":
    _selftest()
