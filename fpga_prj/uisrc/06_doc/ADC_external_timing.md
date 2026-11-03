# AD7606 外部时序约束

更新：2026-10-08。工程 `fpga2026.al`，顶层 `DCDC_top`，器件 `DR1M90GEG400 -2`，TD Release_2026.1_SP2。

约束文件：[fpga2026.sdc](../04_pin/fpga2026.sdc)。这份约束针对当前 100 MHz 系统时钟、`SPI_HALF_CYCLES=8` 的 ADC RTL。板级延迟采用工程预留值，尚未经实板测量或 PCB 提取确认。

## 采样边沿与约束模型

`uispi7606.v` 的移位寄存器由 `clk_100m` 驱动，通过使能进行串行采样；`ad_sclk` 是寄存器输出，并未驱动 FPGA 内部采样时钟。

- BUSY 拉低并经同步后，CS 下降，ADC 输出首位 MSB。8 个系统周期后，FPGA 在产生 SCLK 下降沿的同一系统时钟沿采样 DOUT。
- 后续位由 SCLK 上升沿更新，仍等待 8 个系统周期再采样。半周期为 80 ns，连续读出的 SCLK 为 6.25 MHz。
- 帧间 SCLK 停在高电平，下一帧由 BUSY 同步结果决定起点。不能假定它是与系统时钟保持固定帧相位的自由运行分频时钟。

因此使用周期 10 ns、相位 0 的虚拟时钟 `adc_io_budget` 作为公共时间预算参考，覆盖任意系统时钟边沿启动的 CS/SCLK 往返。虚拟时钟不是 ADC 的实际时钟。输出延迟限制 FPGA 引脚的到达时间，输入延迟计入完整外部往返，再用仅针对 DOUT 输入路径的多周期约束表达 80 ns 的等待时间。

```text
系统边沿        0 ns                         80 ns                   160 ns
首位            CS↓ → 首位有效                FPGA 采样 / SCLK↓       SCLK↑ → 下一位
后续位          SCLK↑ → 新数据有效            FPGA 采样 / SCLK↓       SCLK↑ → 下一位
```

## 延迟预算（单位 ns）

板卡原理图显示接口经过 U5 `SN74AVC16T245`，ADC 模块 VDRIVE 接 3.3 V；当前引脚约束采用 `LVCMOS33`。

| 项目 | 最大预算 | 依据 |
| --- | ---: | --- |
| FPGA 参考边沿至 CS/SCLK 输出引脚 | 7 | 由输出约束检查，包括时钟到达及 FPGA 输出路径 |
| 去程电平转换器 | 6 | 保守工程预留，须核对实际供电、负载和器件版本 |
| 去程 PCB / 连接器 | 2 | 工程预留，须由 PCB 提取或测量确认 |
| AD7606 首位 / 后续位输出延迟 | 39 | 取数据手册 `max(t18,t19)` 的保守值，包含低 VDRIVE 条件 |
| 回程电平转换器 | 6 | 同上 |
| 回程 PCB / 连接器 | 2 | 同上 |
| 额外预算余量 | 1 | 为模型误差、抖动等预留；尚未建立独立的实测抖动模型 |
| **DOUT 引脚最晚到达时间** | **63** | `7+6+2+39+6+2+1` |

AD7606 Rev. G 的 0.3/0.7 VDRIVE 逻辑电平时序表给出：低 VDRIVE 时 `t18` 最大 35 ns、`t19` 最大 39 ns；本工程统一采用 39 ns。3.3 V 标称条件下实际规格更短，但不以典型值替代最坏值。转换器数据手册中 3.3 V / 3.3 V 的最大传播延迟为 2.7 ns；这里每程使用 6 ns 预留，而非宣称板卡已测得 6 ns。

`set_input_delay -min 0` 不依赖未经确认的最小 tCO 或最小板延迟，是比实际串行数据保持窗口更保守的模型。ADC 在采样后仍保持当前位，到下一个 SCLK 上升沿才更新。不得为了消除报告而给 DOUT 加 false path。

五路输出 `ad_sclk/ad_cs/ad_convsta/ad_convstb/ad_rst` 使用 `set_output_delay -max 3`、`-min -0.5`：相对 10 ns 虚拟时钟，限制引脚到达窗口为 **[0.5,7] ns**。这是实现预算，不是 ADC 相对外部 100 MHz 时钟的 setup/hold 规格。

输出约束也限制输出延迟差，但 STA 不直接证明 ADC 引脚处的脉宽、边沿质量或两路 CONVST 偏斜。当前 RTL 的 CONVST 低脉宽为 40 ns，AD7606 要求至少 25 ns；若按输出和去程预算估算最坏压缩量 `7+6+2-0.5=14.5 ns`，仅剩 25.5 ns。该脉宽预算较紧，板级验收须确认转换器负载、实际延迟差及抖动。复位默认约 83.9 ms，复位释放等待 100 ns；改动这些 RTL 参数时仍须核对器件手册。

## 多周期与异步路径的范围

`set_multicycle_path -setup -end 8` 与 `-hold -end 7` 仅从 `ad_dout_a/ad_dout_b` 到 `u_adc/shift_a*/shift_b*` 生效。TD 报告确认 setup 时间预算为 80 ns，hold 时间预算回到 0 ns；没有误加 70 ns 的 hold 要求。移位反馈、计数器、采样使能和 PI 内部路径保持原来的单周期检查。

`ad_busy` 异步输入仅豁免到第一级 `u_adc/busy_meta`；`busy_meta → busy_sync` 和后续状态机路径继续检查。此例外不代替同步器的亚稳态可靠性评估。

`ad_range` 在 RTL 中固定为 0，无动态时序路径，不添加空的 false path。当前 DCDC 只消费 A 通道的部分数据，DOUTB 采样寄存器被优化掉，A 移位寄存器保留 48 位，实际外部输入采样端点为 `shift_a[0]`。SDC 同时覆盖 A/B；复查脚本在 B 路径存在时会检查它，当前则明确记录 B 无保留路径。

更改系统时钟频率、PLL 相位、`SPI_HALF_CYCLES`、ADC 型号、供电、引脚或板卡后，须重新推导预算。尤其不能在保留 setup=8 的同时将 RTL 半周期缩短到 8 拍以下。

## 工具验证结果

使用当前 RTL 和 SDC 在 `output/adc_timing/build` 独立重新综合、布局、布线，并对导出的 `scratch_pr.db` 重新加载 SDC 检查。包含现有 ChipWatcher 调试逻辑，检查慢/快角，报告置信度为 Routed。

| 检查对象 | Setup WNS | Hold WNS |
| --- | ---: | ---: |
| 本次重新布局布线，全局 | +0.640 | +0.033 |
| DOUTA → 采样寄存器 | +15.807 | +0.415 |
| 五路 ADC 控制输出 | +0.896 | +2.268 |
| BUSY 第一级 → 第二级 | +9.036 | +0.316 |
| 原有布线数据库加载本次 SDC，全局 | +0.819 | +0.022 |

所有上述 TNS 均为 0。本次 ADC 报告位于 `output/adc_timing/fresh/`，原有数据库复查报告位于 `output/adc_timing/`。复查脚本均输出 `ADC_STA_PASS`。

额外使用原有布线数据库进行两项隔离的负向检查，生产 SDC 保持正确值：

| 隔离测试 | 预期与结果 |
| --- | --- |
| 输入最大延迟从 63 改为 83 ns | DOUTA setup WNS = -3.873 ns，脚本失败 |
| 移除 DOUT 多周期约束 | DOUTA setup WNS = -53.873 ns，脚本失败 |

结果位于 `output/adc_timing/negative_controls/`。这两项检查确认 DOUT 路径没有被全局例外屏蔽。

`check_timing` 的无效约束、无时钟、时钟定义错误、无路径约束、被遮蔽/忽略的时序例外均为 0。仍存在以下可解释的诊断，未通过空例外隐藏：

- `abnormal input delay(1)`：63 ns 大于虚拟时钟的 10 ns 周期，是多周期往返预算的预期提示；应结合 DOUT 的 80 ns setup / 0 ns hold 报告判断。
- `no input delay(2)`：异步 `ad_busy` 和本任务范围外的板级 `rst_n`。
- `no output delay(6)`：静态 `ad_range/card_power_en`，以及本任务范围外的四路 PWM 输出。
- `dummy node`：未使用的 DOUTB、静态输出和原有 PI 常量优化节点；报告中保留明细。

本次构建还保留了 TD 关于调试时钟布线、带调试属性的系统时钟以及 PLL 驱动未定位 IO 的警告，详见 `tmp/adc_timing/td_20261008_211342.logw`。因此结果表示当前 ADC 预算下的 STA 通过，不表示整个工程没有警告或已完成板级验收。未生成新的下载位流。

## 复查方法

以下脚本只重新分析指定的布线数据库，不重新生成数据库或位流。默认检查原有 `fpga2026_Runs/phy_1/fpga2026_pr.db`；重新实现工程后应再次运行。

```powershell
Set-Location E:\FPGA_2026\output\adc_timing
& 'E:\anlu\TD\bin\td_commands_prompt.exe' 'E:/FPGA_2026/uisrc/05_tools/check_adc_timing.tcl'
```

检查本次独立构建数据库：

```powershell
Set-Location E:\FPGA_2026\output\adc_timing\build
& 'E:\anlu\TD\bin\td_commands_prompt.exe' 'E:/FPGA_2026/output/adc_timing/build/check.tcl'
```

脚本支持 wrapper 预设 `adc_check_db`、`adc_check_out`、`adc_check_sdc` 后 `source`。会检查全局 setup/hold、关键诊断、A/B 采样窗口、五路输出和 BUSY 两级之间的路径；不通过时以非零状态退出。本次完整构建命令保存在 `tmp/adc_timing/rebuild.tcl`，负向约束生成脚本保存在 `tmp/adc_timing/negative_controls.py`。

## 参考资料

- [Analog Devices AD7606/AD7606-6/AD7606-4 数据手册 Rev. G](https://www.analog.com/media/en/technical-documentation/data-sheets/ad7606_7606-6_7606-4.pdf)，Timing Specifications，页 7–8；Serial Interface 一节。
- [Texas Instruments SN74AVC16T245 数据手册](https://www.ti.com/lit/ds/symlink/sn74avc16t245.pdf)，Switching Characteristics。板卡资料包内附版的 3.3 V / 3.3 V 项已核对。
- 本地硬件资料：`E:/baiduDownload/02_F3P_DR1M90GEG400/板卡资料/01_start/01_start_fpga/03_mlk_card_demo/MLK_FEP_DAQ001/02_hardware/FEP-DAQ001-HW-20250108.zip`，其中 `FEP-DAQ001-K200L8B16-N01.pdf`、`YAD-K200L8B16-N01.pdf`、`SN74AVC16T245DGGR.pdf`。只读提取件及核对图位于 `tmp/adc_timing/`。
- 本地 TD 文档：`E:/anlu/TD/doc/SWUG/SWUG200_Timing_Constraints_User_Guide.pdf`、`SWUG201_Timing_Tools_User_Guide.pdf`、`SWUG105_TCL_Command_User_Guide.pdf`。本版本仅支持同一时钟的不确定度设置；本模型额外预留 1 ns，未使用不受支持的跨时钟 uncertainty 命令。
