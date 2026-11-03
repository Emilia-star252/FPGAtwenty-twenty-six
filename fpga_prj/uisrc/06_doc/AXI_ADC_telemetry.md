> 2026-10-20 当前接口变更：采样值仅从DDR获取，GP0只保留控制/状态/FDMA管理；CTR1不变。DCDC偏移0x0c/0x10/0x14/0x18/0x48读取返回SLVERR。下文旧采样寄存器/API说明仅作历史记录，当前以 [分工交接表](GP0_DDR_SPLIT_20261020.md) 为准。PS旧ReadStatus/adc_monitor需队友修改。

> 2026-10-19：上传数据面已切换为 P481 三字段 FDMA/HP1；当前采集格式与接收接口见 [ADC_FDMA_HP1.md](ADC_FDMA_HP1.md)。下文旧 FIFO/FIQ4 上传内容仅作历史参考，DCDC 控制/故障寄存器仍保留。

# AXI ADC 电压、电流和状态上传

数据路径：AD7606 → FPGA 锁存最近一帧 → ARM 通过 AXI 轮询 → UART1 输出。
全部 FPGA 数据通路使用已有的 `clk_100m`，本次没有增加封装引脚。
控制结构沿用已有单电压环；2026-10-13 修正了 ADC 单位换算，PI 参数和 PWM 结构未在本次更改。

## 寄存器

基地址 `0x80000000`，32 位访问，偏移按字节计算。

| 偏移 | 名称 | 属性 | 内容 |
|---|---|---|---|
| 0x00 | ID | RO | 固定 0x41444331（ADC1），用来识别新版本位流 |
| 0x04 | STATUS | RO | 下表定义的实时状态 |
| 0x08 | SAMPLE_COUNT | RO | AXI 复位释放后，每次 adc_valid 加 1，32 位回绕 |
| 0x0C | VOLTAGE_RAW | RO | adc_data_a[47:32]（V2），16 位补码符号扩展到 32 位 |
| 0x10 | CURRENT_RAW | RO | adc_data_a[31:16]（V3），16 位补码符号扩展到 32 位 |
| 0x14 | VOLTAGE_Q16 | RO | 同一帧 voltage_raw × V_SCALE_Q16 + V_OFFSET_Q16，饱和到有符号 32 位 |
| 0x18 | CURRENT_Q16 | RO | 同一帧 current_raw × I_SCALE_Q16 + I_OFFSET_Q16，饱和到有符号 32 位 |
| 0x1C、0x38–0x3C、0x60–0x7C | RESERVED | RO | 读 0，写入忽略 |
| 0x40–0x5C | CONTROL | — | 输出开关、Vref、占空比及状态，见 DCDC_AXI_CONTROL.md |
| 0x20–0x34 | FIFO | — | 详见 ADC_FIFO.md；CTRL=0x2C 可写，DATA=0x28 为弹出读 |
| 0x80–0xFC | SCRATCH | RW | 32 个测试寄存器，保留字节写使能 |

遥测 RO 写入均忽略；FIFO_CTRL 和远程控制寄存器按其位定义处理，非法远程控制写返回 SLVERR。不要再以“64 个寄存器全部可写”的旧程序测试这个版本。
从模块地址宽度仍为 8；有效寄存器只有上述 256 字节，较高地址位不会区分寄存器。

STATUS 位定义：

| 位 | 名称 | 含义 |
|---|---|---|
| 0 | initialized | ADC 已首次就绪，初始化完成状态锁存 |
| 1 | ready | ADC 驱动当前可接收采样请求 |
| 2 | busy | ADC 驱动处于初始化、转换、读取或故障状态 |
| 3 | error | ADC 驱动错误锁存，外部系统复位清除 |
| 4 | pll_locked | 系统 PLL 锁定 |
| 5 | sample_overrun | 控制计算未结束时又到新采样，控制复位清除 |
| 6 | sample_seen | AXI 复位释放后至少锁存过一帧，AXI 复位清除 |
| 31:7 | reserved | 当前顶层接 0 |

## 同一帧读取

四个采样字段及 SAMPLE_COUNT 在 adc_valid 同一时钟沿更新。
ARM 先读 SAMPLE_COUNT，再读四个采样字段，最后再读 SAMPLE_COUNT。
两次计数相等才接受；否则重读。STATUS 是实时状态，不保证与采样字段属于同一帧。
不要通过读取单周期 adc_valid 来判断新样本；使用 sample_seen 和 SAMPLE_COUNT。
这是“最近一帧”遥测，不保证 ARM 收到每一帧，UART 示例每 500 ms 输出一次。

## 数据换算

原始码为有符号 ADC 计数。Q16 的数值为寄存器有符号值除以 65536。
2026-10-13 已按实际 RANGE=1（±10 V）和用户确认的电压 20 倍、电流 1 V=1 A、零点 0 V，设置每码系数 V_SCALE_Q16=400、I_SCALE_Q16=20。
新增 V_OFFSET_Q16/I_OFFSET_Q16，默认 0，可按实测点补偿截距。这是标称换算，实测增益/零点校准方法见 ADC_FIFO.md。
这组换算同时用于控制反馈、最新值遥测和 FIFO 上传；FIFO 格式现为 FIQ4：每帧电压、电流、实际占空比、状态四个 32 位字；原始码遥测仍保留。

## 修改位置与 DI 端口

- uisrc/01_rtl/axi4lite_slave_v11.sv：同帧锁存、采样计数、只读地址映射。
- uisrc/01_rtl/axi4lite_slave.v：传递 6 个遥测输入。
- uisrc/01_rtl/DCDC_top.v：连接 V2、V3、有效脉冲、换算值和状态。
- uisrc/03_ip/axi_system：框图 XML、RTL 包装及生成 HDL 已同步增加遥测端口。

在 DI 中，6 个输入均连接到 axi4lite_slave_0 上的同名输入；adc_sample_valid、voltage_q16_in、current_q16_in 还同时接到 adc_axis_source_0：

| 端口 | 宽度 |
|---|---|
| adc_sample_valid | 1 |
| voltage_raw_in | 16 |
| current_raw_in | 16 |
| voltage_q16_in | 32 |
| current_q16_in | 32 |
| adc_status_in | 32 |

这些是 DCDC_top 内部子模块端口，不需要添加 FPGA 管脚约束。
重新定制 RTL 模块后，应检查 rst_n 的逻辑接口仍为 RESETn。
框图端口/连线已写入 Design.xml 和组件 XML，后续 Generate Design 应保留它们。

## 用户操作顺序

1. 若 TD/DI 已打开，重新加载磁盘上的文件；重新打开 axi_system 检查 6 个输入，Validate Design。
2. Flow → Generate Design，刷新层级，顶层保持 DCDC_top。
3. 本次已完成综合、布局布线，新的位流输出为 fpga2026_Runs/phy_1/fpga2026.bit；后续改动源码或重新生成设计后，需要再运行 Generate Bitstream。
4. Project → Export Hardware Platform File，勾选 Include bitstream，导出新 HPF。
5. FD 平台的 system.mss → Change Referenced HPF → 新 HPF → Re-generate BSP Sources。
6. 将 uisrc/07_software/adc_monitor/main.c 的内容替换应用 main.c，Clean、Build。
7. 调试配置勾选 Program FPGA 和 Run Platform Init，使用新平台中的位流；F8 运行。
8. UART1 使用 115200、8N1，每 500 ms 打印采样计数、原始码、Q16 和实时状态。

上板验收：ID 正确，sample_seen=1，采样计数持续变化；原始 V2/V3 与 ChipWatcher 同符号、同量级；
error=0、overrun=0，init=1、pll=1。ready/busy 随采样阶段变化属于正常现象。
ADC 没有模拟输入时不要求原始码严格为 0，检查噪声、零偏和实际连接。

修改前 9 个文件的备份位于 tmp/adc_telemetry/before。

## 本次验证（2026-10-11）

- TD 全流程生成位流，顶层 DCDC_top；最终布线后 SWNS=0.559 ns、HWNS=0.028 ns，STNS/HTNS 均为 0。
- 当前时序约束覆盖率为 99.95%；既有 IP、调试时钟等警告仍保留，完整日志见 tmp/adc_telemetry/build_console.txt。
- ARM 示例使用 FD 自带 AArch64 GCC，以 -Wall -Wextra -Werror 完成编译检查；尚需在实际 FD 应用中链接和上板运行。
- 新版本的 ADC 遥测尚未上板验证；之前的 AXI scratch 测试通过不代表本次采样数据已经验收。
- 现有 FD 平台里的 HPF/bit 不会由本次构建自动更新，请按上面的导出、导入步骤更新。
