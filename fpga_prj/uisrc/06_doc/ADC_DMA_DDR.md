# Historical AXI DMA / HP0 interface

2026-10-19 更新：本页下文为已替换版本，仅供回溯。当前通路是三字段 P481 → AXIS FIFO → FDMA → AXI Matrix → HP1 → DDR。
当前寄存器、启动流程和软件交接见 [ADC_FDMA_HP1.md](ADC_FDMA_HP1.md)。旧 DMA 驱动和 FIQ4 解析不兼容。

# ADC AXIS FIFO -> DMA -> PS DDR

日期：2026-10-19。工程入口 `E:/FPGA_2026/fpga2026.al`，顶层 `DCDC_top`。
Linux 驱动、接收服务和上位机由队友实现。本文件是当前 PL 硬件交接契约。

## 硬件连接

```text
adc_axis_source_0 (32-bit FIQ4 AXIS)
    -> AXIS_Data_FIFO_0 (32-bit, 4096 words)
    -> AXI_DMA_0.S_AXIS_S2MM (32-bit)
    -> AXI_DMA_0.M_AXI_S2MM (64-bit AXI4, 33-bit address)
    -> HP0_Protocol_Converter_0 (AXI4 -> AXI3)
    -> ARM_Processor_System_0.S_AXI_HP0 (64-bit)
    -> PS DDR controller -> software-owned DDR receive buffer

PS M_AXI_GP0 -> AXI_Protocol_Converter_0 (AXI4 -> AXI-Lite)
    -> AXI_Lite_Matrix_0.US_AXI0
       DS_AXI0 -> axi4lite_slave_0 @ 0x80000000
       DS_AXI1 -> AXI_DMA_0.S_AXI_LITE @ 0x80010000
```

所有上述 AXI/AXIS 时钟均接现有 `axi_clk`，顶层来源为 `clk_100m`。
DMA、Matrix、协议转换器接现有 Processor System Reset 输出，与 GP0 控制逻辑同步复位。
FIFO 仍由 `adc_axis_source_0.fifo_reset_n` 单独控制，软件可清采集数据而不复位控制环。
DMA 的局部软复位不会自动清 FIFO；异常恢复必须同时复位 DMA、清 FIFO，以重新建立包边界。

HP0/HP1 保留用户已启用的 64 位配置；本通路仅使用 HP0。HP1 的时钟接系统时钟，所有请求输入明确拉零，不发起访问。
协议转换器写通道启用、读通道关闭；DMA 最大 burst 为 16 beats，满足 HP0 的 4 位 LEN。
HP0 的 SIZE 是两位，64 位总线的编码为 3；LOCK 始终为 0。原厂转换器的额外 REGION/WID 信号不接 PS。

DMA 配置：S2MM=1、MM2S=0、Scatter Gather=0、Micro DMA=0、DRE=0、同步时钟、长度字段 23 位。
这是 **simple/direct mode**：软件每收到一包需提交下一包；未实现 SG 环形描述符或硬件自动连续重装。
`s2mm_introut` 暂未接到 PS 中断输入，当前版本使用 DMASR 轮询。设备树不能声明一个尚未接线的中断。

## GP0 地址

| 地址范围 | 接口 | 说明 |
|---|---|---|
| 0x80000000-0x8000FFFF | 原 DCDC AXI-Lite | 原寄存器偏移保持，实际地址端口为 8 位 |
| 0x80010000-0x8001FFFF | AXI DMA S_AXI_LITE | 硬件 Matrix 解码窗口；DMA 实际地址端口为 10 位 |

只访问文档定义的寄存器，不利用窗口内的地址别名。
DMA 使用对齐的完整 32 位读写；其原厂 AXI-Lite 寄存器接口没有 WSTRB 输入，不能依赖部分字节写。

| DMA 地址 | 偏移 | 寄存器 |
|---|---|---|
| 0x80010030 | 0x30 | S2MM_DMACR：bit0 Run/Stop，bit2 Reset；本版中断使能位保持 0 |
| 0x80010034 | 0x34 | S2MM_DMASR：bit0 Halted，bit1 Idle，bit4 InternalErr，bit5 SlaveErr，bit6 DecodeErr；bit12 IOC，bit14 ErrIrq |
| 0x80010048 | 0x48 | S2MM_DA：目的 DMA 总线地址低 32 位 |
| 0x8001004C | 0x4C | S2MM_DA_MSB：目的 DMA 总线地址高位，本硬件仅使用 bit0 |
| 0x80010058 | 0x58 | S2MM_LENGTH：最后写入 4096，以提交一包接收；完成后检查实际长度 |

DMASR 的 IOC/Dly/Err 中断状态为 W1C，写 `0x7000` 清除；底层 DMA 错误位须通过 DMA reset 恢复。
状态寄存器定义已对照本机 FD 的 `dr1x90/fpsoc/driver/pl_driver/axi_dma/inc/al_axi_dma_hw.h`，并经原厂 IP 仿真验证。

原 DCDC 寄存器仍可读取 ID/样本计数、控制输出和清故障。
采集控制：`0x8000002C` bit0 CaptureEnable，bit1 FIFO clear 脉冲；`0x80000020` bit2 为 FIFO reset/busy；
`0x80000024` 为 FIFO 字数；`0x80000030` 为丢帧计数；`0x80000034` 为 `0x46495134` (FIQ4)。
FIFO 输出已专属连接 DMA，**旧 `0x80000028 FIFO_DATA` 读取返回 SLVERR**，禁止旧 CPU FIFO 读取程序与新版本配用。
旧 FIFO_STATUS 的 empty/head-TLAST 位来自已断开的 CPU stream 端口，不能用于判断 DMA 是否有数据；使用 FIFO_LEVEL 和 DMASR。

## 数据格式及速率

每帧 16 字节，四个小端 32 位字依次为：

1. `int32_t voltage_q16`，电压 V = 值 / 65536。
2. `int32_t current_q16`，电流 A = 值 / 65536。
3. `uint32_t duty_q16`，占空比百分比 = 值 * 100 / 65536。
4. `uint32_t output_status`，位定义见 `DCDC_AXI_CONTROL.md`，故障掩码为 `0x188`。

每 256 帧产生一个 TLAST，因此每包为 **1024 个 32 位字 = 4096 字节**，DMA 接收长度必须配套。
64 位 DDR 写数据的低 32 位先于高 32 位；DMA 自动将相邻两个 AXIS 字打包，不需要另加流位宽转换器。
25 kHz 对应 400000 B/s，约每 10.24 ms 一包。FIFO 为 16384 字节，理想额外缓冲时间约 40.96 ms。
该值是缓冲容量，不是 Linux 最坏调度延迟的保证；持续超过排空能力时会丢新帧，且不允许反压 ADC/控制环。
服务必须监控 DROP_COUNT。当前帧内没有逐帧序号；丢帧只能由计数检测，不能精确定位到每一帧。

## Linux 队友的实现边界

- 映射 DCDC 寄存器和 DMA 寄存器，分别使用正常的 `ioremap`/平台资源与 `readl`/`writel`。
- 用 Linux DMA API 分配属于该设备的接收缓冲区，优先 `dma_alloc_coherent`；使用返回的 `dma_addr_t` 编程 DMA，不能使用用户虚拟地址。
- 配置设备的实际 DMA mask，上限为本硬件的 33 位。接收地址要求至少 8 字节对齐，建议 64 字节对齐，每个缓冲区至少 4096 字节且生命周期覆盖传输。
- 确保所分配区域确为平台的 DDR；不允许向任意硬编码物理地址写入，不覆盖 Linux 内核或其他设备的内存。
- 若使用 streaming DMA mapping，S2MM 方向是 `DMA_FROM_DEVICE`，按 DMA API 做 map/sync/unmap 和所有权交接。HP0 不是 ACP，不能省略缓存处理。
- 可用双缓冲：完成 A 后立即提交 B，再处理 A。接收期间 CPU 不修改 DMA 所持有的缓冲区；提交和完成处使用 DMA API 要求的内存屏障。
- 本版无 DMA IRQ 接线，服务/驱动采用有超时的状态轮询。若 Linux 延迟测试不能满足持续接收要求，再升级 SG 或补接 IRQ，不能仅凭 FIFO 容量声明无丢帧。
- 队友实现设备树 binding 时自行匹配所采用的驱动。当前没有验证现成内核 DMA 驱动与此原厂 IP 的 compatible/binding，不能直接套用其他厂商 compatible。

父节点若使用 2 个 address cells 和 2 个 size cells，资源可描述为：

```dts
/* Fragment only: add a driver-specific compatible in the real platform tree. */
adc-dma@80010000 {
    reg = <0x0 0x80010000 0x0 0x400>;
    /* No interrupts property: DMA IRQ is not connected in this PL revision. */
};
```

## 启动、运行和恢复

初次启动，在与匹配 bit/HPF/FSBL 的平台上：

1. 核对 `0x80000000=ADC1`、`0x80000054=CTR1`、`0x80000064=FLT1`、`0x80000034=FIQ4`。
2. 写 `0x8000002C=0` 停止采集。采集开关只控制上传，不停止 ADC，也不更改 PWM 控制命令。
3. 写 DMA `DMACR=4`，有限时等待 bit2 自动清零。
4. 写 `0x8000002C=2` 清 FIFO，有限时等待 `FIFO_STATUS & 4` 清零。清零同时重置包计数和 DROP_COUNT。
5. 准备并交给 DMA 一个已分配的 4096 字节接收缓冲区。
6. 写 DMA `DMASR=0x7000`、`DMACR=1`；确认 Halted 清零，再写 DA/DA_MSB，最后写 LENGTH=4096。
7. 写 `0x8000002C=1` 开始采集。输出保持既有命令状态；这些操作不会自动设置 Vref 或开启 PWM。
8. 轮询 DMASR：先检查 `status & 0x70` 错误，再等待 IOC 和 Idle；检查完成长度为 4096，检查 DROP_COUNT。
9. 清 IOC，提交下一 DDR 缓冲区的 DA/DA_MSB/LENGTH。连续采集时不要每包清 FIFO，否则会主动丢数据和重置包边界。

正常停机可在包完成边界停止采集，再清理未提交的 FIFO 数据。若在包中途停止采集，DMA 可能因缺少 TLAST 一直等待，不能无限等待 Idle。
异常、超时或中途停机时：停止采集 -> DMA reset 并确认完成 -> FIFO clear 并确认完成 -> 重新准备缓冲区 -> 提交 DMA -> 开采集。
未确认 DMA reset 完成前，不得释放其正在使用的 DDR 缓冲区。恢复会丢弃未完成包，软件必须上报数据间断。
不把 DMA/采集错误等同于功率级故障，不自动开启输出或清保护故障。

## 验证入口

本次已生成新 bit；工程根目录 `fpga2026.hpf` 仍是旧文件，实查其 HP0/HP1 为关闭，不能与新 bit 配套使用。
自动调用平台导出工具没有产生 HPF。上板前须在当前 TD 工程中导出包含新 bit 的 HPF，并由队友据此更新匹配的 PS 初始化/FSBL/启动镜像。
这一步尚未完成；未执行下载、Linux 接收或真实 DDR 落数验证。

`uisrc/02_sim/adc_dma/run.do` 使用实际生成的 `axi_system.v` 和原厂 FIFO、DMA、Matrix、协议转换器模型。
`ps_axi_bfm.sv` 只替代 PS 为 GP0 发起端和 HP0 DDR 响应模型；不能证明真实 PS/DDR、FSBL 或 Linux 驱动已工作。
测试检查两包续接、4096 字节格式、DDR 逐字内容、背压、跨 4KB 边界、旧 FIFO 读 SLVERR、地址越界 DECERR、DDR SLVERR 传播和复位恢复。
原控制/保护 RTL 未改变；另跑已有控制、保护回归。
构建日志与改前 DI 完整备份位于 `tmp/axis_dma_20261019/`，最终验证结果见同目录 `validation.md`。

当前 TD 批处理 Generate Design 对这套导入 RTL/原厂 IP 组合会输出空的地址清单，虽然实际硬件 Matrix 已按上表解码。
生成后运行 `python uisrc/05_tools/check_adc_dma.py --write-address-map`：先校验实际接线与 Matrix/DMA 参数，再记录对应地址清单。
不带参数运行仅检查，不改文件。地址清单中的 HP0 8 GiB 范围是 PS slave 总线窗口，不代表 DDR 实际容量；接收地址仍须由 Linux DMA API 提供。

回滚范围：恢复该目录 `before/uisrc/03_ip/axi_system` 的既有文件，移除本次三个新增子 IP 后重新生成/构建。
备份保留了用户启用 HP0/HP1 后的 PS 配置。测试、文档和交接头文件可独立移除；不需改 ADC、PI、PWM、保护参数或引脚约束。
