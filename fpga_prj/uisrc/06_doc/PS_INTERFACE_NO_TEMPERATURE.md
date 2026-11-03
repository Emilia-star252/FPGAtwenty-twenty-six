# PS 对接：GP0 控制 + 单向 HP1 DDR 上传（无温度）

2026-10-20：DDR 专门上传连续采样，GP0 仅控制/状态/FDMA管理；CTR1 保留。PS软件由队友修改。
工程入口 `E:/FPGA_2026/fpga2026.al`，顶层 `DCDC_top`。
当前仅上传电压、电流和实际占空比，无温度通道、温度字段或温度故障位。

## 1. 地址和通路

```text
命令/状态：PS M_AXI_GP0 → AXI-Lite 转换/Matrix → DCDC 与 FDMA 寄存器
采样上传：48/48/32 三字段打包 → AXIS FIFO → FDMA 写 → AXI Matrix → HP1 → DDR
```

| 资源 | PS 总线基地址 | 用途 |
|---|---|---|
| DCDC 控制/状态 | 0x80000000 | 给定电压、输出启停、故障、采集开关和诊断 |
| 自定义 FDMA | 0x80010000 | DDR 环地址/槽数、运行/复位、生产/消费进度 |
| DDR 采样环 | B，由 PS 分配并写入 FDMA 配置 | 连续 P481 采样数据；不是固定物理地址 |

不使用 DDR 命令邮箱，也不要求预留先前的 `0x1F000000` 邮箱区或发送 PING。
先前 CMD2/STS2 邮箱软件不适用于当前版本。
FDMA 是本工程的 FDM1 自定义控制协议，不是原厂 AXI DMA IP 寄存器。
采样 DDR 地址必须由平台 DMA 分配/映射取得，不能使用用户态虚拟地址。

## 2. 每个量的偏移

### DCDC 寄存器（相对 0x80000000）

| 名称 | 偏移 | 完整地址 | 类型/权限 |
|---|---|---|---|
| 接口 ID ADC1 | 0x00 | 0x80000000 | R，0x41444331 |
| ADC 状态 | 0x04 | 0x80000004 | R，uint32 位图 |
| 完整采样计数 | 0x08 | 0x80000008 | R，uint32 |
| FIFO 状态 | 0x20 | 0x80000020 | R，仅用于采集复位忙等有效位，见下文 |
| FIFO 已缓存字数 | 0x24 | 0x80000024 | R，uint32，单位为 32 位字 |
| 采集控制 | 0x2c | 0x8000002c | RW，bit0=采集使能；bit1=清 FIFO 脉冲 |
| DROP_COUNT | 0x30 | 0x80000030 | R，丢新整帧计数 |
| 帧格式 P481 | 0x34 | 0x80000034 | R，0x50343831 |
| 输出请求 | 0x40 | 0x80000040 | RW，bit0=ON/OFF |
| 请求给定 Vref | 0x44 | 0x80000044 | RW，uint32 Q16，范围 0..64 V |
| 输出状态/功率故障 | 0x4c | 0x8000004c | R，uint32 位图 |
| 当前斜坡 Vref | 0x50 | 0x80000050 | R，uint32 Q16 |
| 控制 ID CTR1 | 0x54 | 0x80000054 | R，0x43545231 |
| 最大 Vref | 0x58 | 0x80000058 | R，4194304，即 64 V Q16 |
| 命令错误 | 0x5c | 0x8000005c | R，bit0=错误；写 bit0=1 清错误 |
| 清故障命令 | 0x60 | 0x80000060 | W，bit0=1 发一次清故障脉冲 |
| 清故障能力 ID FLT1 | 0x64 | 0x80000064 | R，0x464c5431 |

`0x28 FIFO_DATA` 的旧 CPU 破坏性读取端已断开，读取返回 SLVERR；不能用旧 FIFO 读程序收数据。
FIFO_STATUS bit2 表示采集 FIFO 复位忙；empty/head-TLAST 等来自旧 CPU stream 的位不用于判断 DMA 是否有数据。
连续采样用 FDMA PRODUCER 判断整块完成，使用 FIFO_LEVEL 和 DROP_COUNT 诊断缓存状态。

OUTPUT_STATUS 位定义：bit0=输出请求；bit1=实际 PWM 使能；bit2=ADC 初始化完成；
bit3=ADC 驱动故障；bit4=PLL 锁定；bit5=PWM 已准备；bit6=控制计算过载诊断；
bit7=过流锁存；bit8=过压锁存；其余保留。
功率关闭故障取 `status & 0x188`，可同时有多个故障，没有另一个独立故障码寄存器。


退休地址：DCDC偏移 `0x0c/0x10/0x14/0x18/0x48` 均不再提供采样值，读取返回 SLVERR。CTR1仍为0x43545231。

### FDMA 寄存器（相对 0x80010000）

| 名称 | 偏移 | 定义 |
|---|---|---|
| ID | 0x00 | FDM1=0x46444d31 |
| CONTROL | 0x04 | 写 1=运行；0=停止新写入；2=请求排空复位；读 bit1=复位未完成 |
| STATUS | 0x08 | bit0=运行请求；bit1=忙；bit2=环满；bit3=错误；bit4=配置有效 |
| ERROR | 0x0c | bit1=AXI 响应/ID 错；bit2=TKEEP/TLAST 错；bit4=停止造成不完整包 |
| BASE_LO/BASE_HI | 0x10/0x14 | DMA 地址低 32 位/高位 bit0 |
| RING_SLOTS | 0x18 | 2..65536，2 的幂；每槽 4096 字节 |
| PRODUCER | 0x1c | 成功完成的整块累计计数 |
| CONSUMER | 0x20 | PS 已处理并归还的累计块数 |
| BLOCK_BYTES | 0x24 | 固定 4096 |
| FORMAT | 0x28 | P481=0x50343831 |

FDMA 寄存器使用对齐、完整 32 位写入（WSTRB=0xf）。
改变 BASE/槽数应先停采集、排空复位，避免改变硬件正在使用的缓冲区。

### 连续采样帧（相对每帧起点）

| 字段 | 字节偏移 | 长度 | 格式 |
|---|---|---|---|
| voltage_product | 0x00 | 6 字节 | signed 48 位，小端 Q16 |
| current_product | 0x06 | 6 字节 | signed 48 位，小端 Q16 |
| applied_duty_q16 | 0x0c | 4 字节 | unsigned 32 位，小端 Q16 |

每帧 16 字节，无状态/温度/时间戳/额外填充。状态和故障通过 GP0 获取。
GP0不再提供原码、最新V/I或占空比值。DDR流保留完整的48位乘积，布局与之前的P481一致。

## 3. 格式与缩放

```text
电压 V   = 有符号 Q16 电压 / 65536.0
电流 A   = 有符号 Q16 电流 / 65536.0
占空比 % = duty_q16 * 100.0 / 65536.0
给定值 V = vref_q16 / 65536.0
```

DDR 中的 48 位数须先二补码符号扩展到 int64，不能只取低 32 位。
当前默认标定：voltage_product=voltage_raw×400；current_product=current_raw×20，偏移均为 0。
上传乘积已经完成比例换算，PS 不再乘一次 400/20。
12 V 给定=786432（0x000c0000）；50% 占空比=32768。

## 4. 更新方式和基本启动顺序

- 三字段按完整 ADC 采样同帧锁存，25 kHz，即 40 μs/帧。
- FDMA 将每 256 帧写成 4096 字节块，满速约 10.24 ms/块；采集带宽 400000 B/s。
- GP0 用于控制命令、状态/故障与生产/消费计数轮询；当前没有 DMA IRQ。
- PS 从 `producer-consumer` 得到已完成未消费块数，槽地址=`B+(consumer & (slots-1))*4096`。
- 处理/复制完块后更新 FDMA CONSUMER；未归还槽不被覆盖，缓存长期拥塞时丢新帧并计数。

启动：确认匹配 bit/HPF/FSBL → GP0 读取 ADC1/CTR1/FLT1/P481/FDM1 → 采集关闭 →
FDMA CONTROL=2 并等待排空复位 → 清 FIFO 并等待复位忙结束 → 配置 PS 分配的 DMA 环 →
FDMA CONTROL=1 → 采集控制=1 → 轮询 PRODUCER 并消费/归还块。
输出控制独立：写 Vref 后明确写 ON；清故障先 OFF/Vref=0，安全条件不满足时不会清掉保护。
本版本不含邮箱超时许可，不要求 1 s 会话心跳；原本的 PL 快速保护仍保持。

本次完整分工与PS修改清单见 [GP0_DDR_SPLIT_20261020.md](GP0_DDR_SPLIT_20261020.md)。
旧 `DcdcAxi_ReadStatus()` 与 `adc_monitor/main.c` 会读取退休地址，需要队友修改后使用；本次未改PS软件实现。

FDMA运行约定见 [ADC_FDMA_HP1.md](ADC_FDMA_HP1.md)。
控制 API：`uisrc/07_software/dcdc_axi/`；采样布局/FDMA 宏：`uisrc/07_software/adc_fdma/dcdc_adc_fdma_regs.h`。
本次验证记录：`tmp/ddr_data_gp0_control_20261020/validation.md`。尚未进行真实板上 DDR/Linux/功率级验证。
