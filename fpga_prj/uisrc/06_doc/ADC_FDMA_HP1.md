# 三字段采样：AXIS FIFO → FDMA → Matrix → HP1 → DDR

2026-10-19。工程入口 `E:/FPGA_2026/fpga2026.al`，顶层 `DCDC_top`。
本版替换 AXI DMA/HP0 采集支路。旧 AXI DMA 寄存器和 FIQ4 解析程序不兼容。

2026-10-20：GP0已退出原码、最新V/I和实际占空比读取，仅保留控制/状态及FDMA管理；CTR1保持0x43545231。PS接口变更见 [GP0_DDR_SPLIT_20261020.md](GP0_DDR_SPLIT_20261020.md)。

## 实际通路

```text
voltage_product[47:0] + current_product[47:0] + applied_duty_q16[31:0]
  → adc_axis_source_0：adc_valid 时同帧锁存，32 位 AXIS
  → AXIS_Data_FIFO_0：4096 个 32 位字，独立采集复位
  → adc_fdma_writer_0：32→64 位适配，最多 16 beat 的 INCR 突发
  → HP1_AXI_Matrix_0.US0：64 位 AXI4，33 位地址，2 入 1 出
  → HP1_Protocol_Converter_0：AXI4→AXI3，READ_WRITE
  → ARM_Processor_System_0.S_AXI_HP1：64 位
  → PS DDR 控制器 → Linux 分配的 DDR 环形采样缓冲区

PS M_AXI_GP0 → AXI-Lite 协议转换器 → AXI_Lite_Matrix_0
  DS_AXI0：DCDC 原控制/状态 @ 0x80000000
  DS_AXI1：新 FDMA 控制/进度 @ 0x80010000
```

上述总线使用现有 `clk_100m` 和 Processor System Reset。
保留 PS 当前 HP0/HP1 使能及 DDR 配置；HDMI 使用 HP0，采样上传继续使用 HP1。
2026-10-24：软 NPU 经 ID/突发适配桥接 Matrix US1，与 FDMA 共享 HP1。
FDMA 写仲裁优先级高于 NPU；NPU 控制走 GP1，数据读写不经过 GP0。
接线、地址、中断及软件交接见 [NPU_HP1_20261024.md](NPU_HP1_20261024.md)。
ADC、PI、PWM、保护算法、采样周期和引脚/SDC 不变。上传阻塞仅丢新采集帧并累加 DROP_COUNT，不反压控制环。

FDMA 是本工程新增的 `adc_fdma_writer.v`，采用“缓冲区地址/长度管理＋突发写”的逻辑，
并非原厂 AXI DMA IP，也不是把视频 demo 的 `uiFDMA.v` 直接接到 AXIS。
每次先缓存完整的一次突发数据，再发 AW/W；等待本次 B 响应后才继续。
所有 burst 最多 16 beat，且不跨 4 KB 边界。AW、W 受背压时保持请求和数据稳定。
软复位会排空已发起的写请求和 B 响应，不能强行撤销已承诺的 AXI 事务。

## 唯一数据帧格式 P481

| 字节偏移 | 长度 | 数据 |
|---|---|---|
| 0 | 6 | `voltage_product`，有符号 48 位，小端，Q16 |
| 6 | 6 | `current_product`，有符号 48 位，小端，Q16 |
| 12 | 4 | `applied_duty_q16`，无符号 32 位，小端，Q16 |

保留原始两个 48 位乘积，不饱和、不截断。读取电压/电流时先将 48 位二补码符号扩展到 64 位，再除以 65536 得 V/A。
占空比为 PWM 实际锁存值，输出被禁止时为 0；百分比 = duty × 100 / 65536。
没有状态、时间戳、帧序号或额外填充。故障和丢帧状态从 GP0 读取。

AXIS 字序：`V[31:0]`、`{I[15:0], V[47:32]}`、`I[47:16]`、`duty[31:0]`。
每 256 帧、1024 个 32 位字产生一次 TLAST；每块 4096 字节。
FDMA 检查每拍 TKEEP=0xf，以及只有第 1024 个字带 TLAST。
25 kHz 时为 400000 B/s，每块 10.24 ms。FIFO 容量为 16384 字节；这不代表 Linux 调度延迟已验证。

头文件：`uisrc/07_software/adc_fdma/dcdc_adc_fdma_regs.h`，包含布局及有符号 48 位解码函数。

## FDMA 寄存器

基址 **0x80010000**；只使用对齐、WSTRB=0xf 的 32 位读写，其他写法返回 SLVERR。
未定义寄存器读取/写入返回 SLVERR。没有 DMA IRQ 接线，软件轮询进度。

| 偏移 | 读写 | 定义 |
|---|---|---|
| 0x00 | R | ID = 0x46444d31，FDM1 |
| 0x04 | RW | 写 1：运行；写 0：停止新采集写入；写 2：请求排空软复位。读 bit0=运行请求，bit1=复位进行中 |
| 0x08 | R | bit0=运行请求；bit1=内部状态忙；bit2=环满；bit3=错误；bit4=配置有效 |
| 0x0c | R | 粘滞错误：bit1=BRESP 非 OKAY 或返回 ID 异常；bit2=TKEEP/TLAST 格式错误；bit4=停止导致包不完整。通过排空软复位清除 |
| 0x10 | RW | 环形缓冲区 DMA 地址低 32 位 |
| 0x14 | RW | DMA 地址高位，仅 bit0 有效，其他值写入拒绝 |
| 0x18 | RW | 缓冲区槽数，2..65536，必须是 2 的幂；每槽 4096 字节 |
| 0x1c | R | PRODUCER：已成功完成的块计数，32 位回绕 |
| 0x20 | RW | CONSUMER：软件已处理并归还的块计数，32 位回绕 |
| 0x24 | R | 固定块长度 4096 |
| 0x28 | R | 格式 ID = 0x50343831，P481 |

地址至少 8 字节对齐，建议分配 4 KB 对齐区域。地址加整个环长度必须在实现的 33 位地址范围内，
当前校验保守地要求末尾地址小于 2^33。真正可用范围由 Linux 分配的 DDR DMA 区域决定。
修改地址/槽数要求运行关闭、内部状态空闲且无未消费块；重新配置前建议总是排空复位。
非法启动配置返回 SLVERR，不发 AXI 请求。

用无符号减法计算 `available = producer - consumer`。
当 available 达到 slots 时停止发起下一块，绝不覆盖未归还槽。
软件处理的槽地址 = `base + (consumer & (slots-1)) * 4096`。
一块全部写完且最后一个 B 响应成功，硬件才递增 PRODUCER。
软件可以一次归还多个已完成块；超前归还、倒退计数会被拒绝。
块写出错时可能已有部分字节进入该槽，PRODUCER 不发布该块；复位后重建采集边界。

## Linux 队友的操作顺序

1. 使用与当前 bit 配套的平台 HPF/PS 初始化/FSBL，确认 GP0 IDs：ADC1、CTR1、FLT1、P481 和 FDM1。
2. 写 DCDC `0x8000002c=0` 停上传；写 FDMA `CONTROL=2`，有超时地等待 CONTROL bit1 清零。
3. 写 DCDC `0x8000002c=2` 清 FIFO；等待 `0x80000020` bit2 清零。此时包边界及 DROP_COUNT 重置。
4. 通过 Linux DMA API 为此设备分配连续 DMA 地址范围的 DDR 环。优先 coherent 分配，mask 按 33 位或平台可用的更窄范围设置。
5. 写 BASE_LO、BASE_HI、RING_SLOTS，确认 STATUS bit4=1；初次 producer/consumer 均为 0。
6. 写 FDMA `CONTROL=1`，再写 DCDC `0x8000002c=1` 开始上传。无需每块软件重装地址/长度。
7. 轮询 ERROR、PRODUCER 及 DCDC `0x80000030 DROP_COUNT`。确认完成块后按 DMA API 所需屏障/同步规则读取内容。
8. 处理完一个或多个完整块后，写新的 CONSUMER。归还后不得继续使用该槽内容；如需异步显示/网络/NPU，应先复制到消费者持有的内存。

HP1 不是 ACP。若使用 streaming mapping，方向为 DMA_FROM_DEVICE，并按 DMA API 做所有权交接及 map/sync/unmap。
不得把 CPU 虚拟地址写进 FDMA，不得硬编码未知物理 DDR 地址。环被 FDMA 持有期间不能释放。
Linux 驱动/设备树/接收服务由队友实现；新寄存器是自定义协议，不能用旧 AXI DMA 驱动或 compatible。
实际寄存器资源长度 0x2c；GP0 Matrix 为此资源分配 64 KB 窗口，不应利用窗口内地址别名。

异常或中途停止：停上传 → 请求 FDMA 排空复位 → 等待复位结束 → 清 FIFO → 重新启动。
若 PS/AXI 总线不返回响应，复位会保持等待，软件必须超时报错并保留 DMA 缓冲区。
不要将上传错误等同于功率级故障；采集配置不会自动开启 PWM、设置 Vref 或清除保护。
环满后 FIFO 仍可短时缓存；长时间不归还会丢新帧。当前没有逐帧序号，DROP_COUNT 只能说明有数据间断，不能定位丢失帧。

## 验证与构建

- `uisrc/02_sim/adc_fdma/run.do`：实际生成 DI＋原厂 FIFO/Matrix/转换器，PS 替换为 GP0/HP1 总线模型。
- `python uisrc/05_tools/check_adc_fdma.py`：接线/时钟/复位/地址清单审计。
- TD Generate Design 后若清空地址清单，执行 `python uisrc/05_tools/check_adc_fdma.py --write-address-map`；先审计实际连接再记录清单。
- `tmp/ddr_data_gp0_control_20261020/validation.md`：本次GP0分工变更验证与新bit指纹。

2026-10-19 已恢复为 GP0 控制/状态 + 单向 FDMA/HP1 DDR 上传；移除了双向邮箱与心跳许可。
无需预留旧的 0x1F000000 邮箱，也不发送 CMD2/HELLO/PING。采样环仍需由 PS 分配并通过 GP0 配置。
双向版本源码/bit/HPF 已保存到 `tmp/rollback_gp0_hp1_20261019/`，不能将其中的旧 HPF 当作当前平台。
上板前需从当前磁盘工程导出包含新 bit 的匹配 HPF，并配套 PS 初始化/FSBL。
仿真不代表真实 PS DDR、Linux 或功率级验证；本次尚未下载上板。

此前回退版本的bit与时序仅作历史记录；本次新bit及结果以本次验证记录为准。
此前回退版bit：`output/rollback_gp0_hp1_20261019/fpga2026_gp0_hp1.bit`。当前分工版本使用 `output/ddr_data_gp0_control_20261020/fpga2026_ddr_data_gp0_control.bit`。
