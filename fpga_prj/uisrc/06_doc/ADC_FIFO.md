> 2026-10-20 当前接口变更：采样值仅从DDR获取，GP0只保留控制/状态/FDMA管理；CTR1不变。DCDC偏移0x0c/0x10/0x14/0x18/0x48读取返回SLVERR。下文旧采样寄存器/API说明仅作历史记录，当前以 [分工交接表](GP0_DDR_SPLIT_20261020.md) 为准。PS旧ReadStatus/adc_monitor需队友修改。

# ADC 实际电压、电流的 Q16 FIFO 上传

2026-10-19 更新：当前为 **三字段 P481 → AXIS FIFO → FDMA → AXI Matrix → HP1 → DDR**。
上传完整 48 位 voltage_product、48 位 current_product 和 32 位实际占空比，不上传 status。
每帧 16 字节、每块 4096 字节。旧 CPU FIFO/FIQ4 和 AXI DMA 接收程序不兼容。
当前接口以 [ADC_FDMA_HP1.md](ADC_FDMA_HP1.md) 为准；下文为历史记录。

更新：2026-10-13。工程 `E:/FPGA_2026`，顶层 `DCDC_top`。

## 当前换算

工程实际使用 `uisrc/03_ip/AD7606/uispi7606.v`，其中 `O_ad_range=1`，顶层直接连接到 `ad_range`，对应 **±10 V**。本次保留该引脚电平，修正了过时的 ±5 V 注释。
用户确认：V2 电压通道分压还原 20 倍；V3 电流通道 ADC 输入 1 V 对应 1 A，零电流为 0 V。

按 AD7606 的有符号 16 位编码和标称量程：

```text
ADC 输入电压 = raw × 10 / 32768
实际电压 V   = voltage_raw × 10 / 32768 × 20
实际电流 A   = current_raw × 10 / 32768 × 1

voltage_q16 = saturate32(voltage_raw × 400 + V_OFFSET_Q16)
current_q16 = saturate32(current_raw × 20  + I_OFFSET_Q16)
V/A 数值 = 对应的有符号 Q16 值 / 65536
```

来源：[AD7606 数据手册](https://www.analog.com/media/en/technical-documentation/data-sheets/AD7606_7606-6_7606-4.pdf)，RANGE 定义及 ADC Transfer Function。以上是按确认比例进行的标称换算，尚未用实测点修正模拟前端、参考电压和零点误差。

`DCDC_top.v` 当前默认 `V_SCALE_Q16=400`、`I_SCALE_Q16=20`、两个 OFFSET 均为 0。这两个乘积同时用于已有遥测与控制反馈，更新参数后要使用同一版本的 bit 做控制验证。
如改变 ADC RANGE，需同时重算系数；只有在 ±5 V 时，20 倍电压和 1 倍电流的每码系数才是 200、10。

示例：电压原始码 7864 -> 47.998046875 V；电流原始码 3277 -> 1.000061035 A。

实测两点标定时，每路取原始码 x1/x2 与真实值 y1/y2：

```text
k = (y2 - y1) / (x2 - x1)
b = y1 - k × x1
SCALE_Q16  = round(k × 65536)
OFFSET_Q16 = round(b × 65536)
```

SCALE 已包含 ADC 每码换算和前端比例，不要再乘一次 20 或重复除以 32768。

## 当前 FIFO / 控制版本：FIQ4

本工程现已增加实际占空比、输出状态和 ARM 下发输出开关、v_ref 的接口。
详细寄存器、队友上位机对接、ARM C API 和输出行为见 [DCDC_AXI_CONTROL.md](DCDC_AXI_CONTROL.md)。

每帧依次是 4 个 32 位字：电压 signed Q16、电流 signed Q16、实际占空比 unsigned Q16（0～1）、OUTPUT_STATUS。
四个字段同帧锁存，FIFO 满时丢完整新帧。占空比百分比 = duty_q16 × 100 / 65536。
FIFO_ID=0x46495134（FIQ4）；前一版 FIQ2 两字格式已过时，ARM 解包程序需配套更新。
每包 256 帧 = 1024 字 = **4096 字节**，TLAST 在末帧状态字。将来 DMA 长度也设为 4096。
FIFO 仍保持 32 位、4096 字深度，25 kHz 下约 41 ms 缓冲；LEVEL 按字、DROP_COUNT 按帧。

P=adc_axis_source_0：现在除了 adc_sample_valid、voltage_q16_in、current_q16_in，还接 duty_q16_in 和 control_status_in；它们同时扇出到寄存器模块。
新增 root 的 output_enable_cmd/vref_cmd_q16 输出接顶层控制逻辑，vref_active_q16_in 输入接斜坡给定。其余时钟/复位与握手连接保持原结构，顶层仍 DCDC_top，无新增封装引脚。
磁盘上的 DI XML 与生成 HDL 已同步；关闭旧 DI 并重新读取磁盘设计，避免旧缓存覆盖新端口。

ARM 示例 `uisrc/07_software/adc_fifo_capture/main.c` 现在采集 256 帧后输出：

```text
sample,voltage_V,current_A,duty_percent,output_on,fault_bits
```

程序只采集和打印，不自动开启输出。新硬件复位后默认输出关闭、v_ref=0；ADC 仍运行，看到 duty=0、output_on=0 属于该默认行为。
正式服务端调用 `uisrc/07_software/dcdc_axi` 的接口设置给定和开关输出；低速 STATUS 可直接读寄存器，无须等待 FIFO。

测试入口：`uisrc/02_sim/adc_fifo/run.do`、`run_scaling.do`、`run_remote_control.do`，以及 `test_dcdc_axi.c`。
原厂 FIFO 加密模型仍有内部位宽警告。数字测试覆盖格式、命令范围、输出开关、采样持续、给定斜坡与实际占空比，不代替模拟功率级整定和上板验证。
本次源码/DI/原 bit 备份与构建日志在 `tmp/remote_control_20261013`；上一版标称换算备份仍在 `tmp/calibrated_fifo_20261013`。
