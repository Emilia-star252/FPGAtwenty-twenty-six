# DDR 采样与 GP0 控制分工交接

2026-10-20。入口 `E:/FPGA_2026/fpga2026.al`，顶层 `DCDC_top`。
按用户要求保留 **CTR1=0x43545231**。PS 软件由队友修改，本次未改动 `uisrc/07_software/`。

| 通路 | 当前内容 |
|---|---|
| DDR，经 HP1 写入 | 电压、电流、实际占空比的连续采样 |
| GP0 | 给定、启停、清故障、状态、采集诊断，以及 FDMA 配置与进度 |

## DDR 数据格式保持 P481

```text
voltage_product[47:0], current_product[47:0], applied_duty_q16[31:0]
 -> 32-bit AXIS -> FIFO -> FDMA -> 64-bit AXI Matrix
 -> AXI4/AXI3 converter -> HP1 -> PS 分配的 DDR 环
```

| 每帧字节偏移 | 数据 | 格式／换算 |
|---|---|---|
| 0x00 | voltage_product，6 字节 | 有符号48位、小端、Q16；符号扩展到 int64 后 /65536 得 V |
| 0x06 | current_product，6 字节 | 有符号48位、小端、Q16；符号扩展到 int64 后 /65536 得 A |
| 0x0c | applied_duty_q16，4 字节 | 无符号32位、小端；*100/65536 得占空比 % |

每帧16字节、每块256帧/4096字节，正常25 kHz采样约400000 B/s。
没有 ADC 原码、温度、状态或额外填充。两个原码只保留在 PL 内部用于标定和控制/保护，未改变这些算法。
`adc_axis_source.v`、`adc_fdma_writer.v` 及 P481 布局与改前完全一致。

## GP0 DCDC：基址 0x80000000

| 偏移 | 访问 | 名称及含义 |
|---|---|---|
| 0x00 | R | ADC1=0x41444331，诊断接口标识 |
| 0x04 | R | ADC 状态，原位定义保留 |
| 0x08 | R | 完整采样累计计数，供诊断 |
| 0x20 | R | FIFO 状态；bit2 表示复位忙，旧 CPU stream 的 empty/head-TLAST 位不用于 FDMA 判定 |
| 0x24 | R | FIFO_LEVEL，单位32位字 |
| 0x2c | RW | bit0=采集使能；bit1=清 FIFO 脉冲 |
| 0x30 | R | DROP_COUNT，丢新整帧累计计数 |
| 0x34 | R | P481=0x50343831 |
| 0x40 | RW | 输出请求，bit0=ON/OFF |
| 0x44 | RW | 请求给定 Vref，uint32 Q16，0..64 V |
| 0x4c | R | 输出状态与故障，原位定义保留 |
| 0x50 | R | PL 当前斜坡给定，uint32 Q16 |
| 0x54 | R | **CTR1=0x43545231，按要求保留** |
| 0x58 | R | 最大 Vref，4194304，即64 V Q16 |
| 0x5c | RW | bit0=命令错误；写 bit0=1清除 |
| 0x60 | W | 写 bit0=1，发一次清故障请求 |
| 0x64 | R | FLT1=0x464c5431 |

**已退出的 GP0 读取地址**：`0x0c` 原始电压、`0x10` 原始电流、`0x14` 最新电压、`0x18` 最新电流、`0x48` 实际占空比。
这些地址读取均返回 `RRESP=SLVERR(2'b10)`，数据总线置0；不能将其当作“测量为0”。
旧 `0x28 FIFO_DATA` 在生产 DI 中仍未连接 CPU 流，读取同样返回 SLVERR。
这些退休地址的原有写入行为仍无作用；不要用写入探测采样值。

输出状态0x4c：bit0=输出请求，bit1=实际PWM使能，bit2=ADC初始化完成，bit3=ADC驱动故障，
bit4=PLL锁定，bit5=PWM已准备，bit6=控制计算过载诊断，bit7=过流锁存，bit8=过压锁存。
关闭输出故障掩码仍为 `0x188`。输出和故障互锁、给定范围及斜坡行为均保持。

## FDMA：基址 0x80010000，接口保持 FDM1

| 偏移 | 名称 | 含义 |
|---|---|---|
| 0x00 | ID | FDM1=0x46444d31 |
| 0x04 | CONTROL | 写1运行、0停止新写入、2请求排空复位；读bit1=复位未完成 |
| 0x08 | STATUS | bit0运行请求、bit1忙、bit2环满、bit3错误、bit4配置有效 |
| 0x0c | ERROR | bit1 AXI响应/ID错误，bit2帧格式错误，bit4停止导致包不完整 |
| 0x10/0x14 | BASE_LO/BASE_HI | DDR DMA地址低32位/高位bit0 |
| 0x18 | RING_SLOTS | 2..65536，2的幂，每槽4096字节 |
| 0x1c | PRODUCER | 已成功写完的累计整块数 |
| 0x20 | CONSUMER | PS处理并归还的累计整块数 |
| 0x24 | BLOCK_BYTES | 4096 |
| 0x28 | FORMAT | P481=0x50343831 |

FDMA配置写入用完整32位、WSTRB=0xf。当前仍通过轮询PRODUCER获取完成进度，没有DMA中断。
DDR地址由Linux DMA API分配/映射获得，保持设备内存所有权及缓存同步规则。
读取槽地址=`B+(consumer & (slots-1))*4096`，处理/复制完块后写CONSUMER。

## 队友需要修改的 PS 软件

1. 删除对 DCDC `0x0c/0x10/0x14/0x18/0x48` 的读取；显示/网络电压、电流和占空比都从已完成的 DDR 块解析。
2. 原 `DcdcAxi_ReadStatus()` 会读取已退出的地址，必须改写；其状态结构中的 V/I/duty 改从 DDR 采样结果取得。
   GP0 状态读取只保留输出/故障、给定、采样计数、丢帧等管理信息。旧 `adc_monitor/main.c` 不能直接运行。
3. CTR1 校验值继续用0x43545231。ID不区分本次寄存器裁剪，必须按本交接表部署配套软件。
4. 给定、启停、清故障、FDMA配置和进度寄存器地址不变。清故障仍要求安全完整采样，清除后保持OFF/Vref=0。

启动顺序保持：匹配bit/HPF/FSBL → 关闭采集 → FDMA排空复位 → 清FIFO → 配置PS分配的DDR环 → FDMA运行 → 开采集。
异常恢复用“停采集 → FDMA排空复位 → 清FIFO → 重启”；复位未完成前不能释放硬件持有的DDR缓冲区。

验证记录与改前快照：`tmp/ddr_data_gp0_control_20261020/`。
新bit需匹配当前工程重新导出的HPF及PS初始化/FSBL；仿真与时序不代表已完成板上DDR/Linux验证。
