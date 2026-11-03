> 2026-10-20 当前接口变更：采样值仅从DDR获取，GP0只保留控制/状态/FDMA管理；CTR1不变。DCDC偏移0x0c/0x10/0x14/0x18/0x48读取返回SLVERR。下文旧采样寄存器/API说明仅作历史记录，当前以 [分工交接表](GP0_DDR_SPLIT_20261020.md) 为准。PS旧ReadStatus/adc_monitor需队友修改。

# 给上位机/TCP 服务端队友的 FPGA 接口

日期：2026-10-15。基地址 0x80000000，32 位对齐访问；单位字段采用 Q16（除以 65536）。上位机/TCP 协议由队友负责，本工程提供 AXI 寄存器和 ARM C 接口。

## 下行命令

| 偏移 | 名称 | 内容 |
|---|---|---|
| 0x40 | OUTPUT_CTRL，RW | bit0：1 请求开启、0 关断；复位为 0 |
| 0x44 | VREF_CMD_Q16，RW | 电压给定，0～64 V，即 0～0x00400000；复位为 0 |
| 0x54 | CONTROL_ID，RO | 固定 0x43545231，ASCII CTR1 |
| 0x58 | VREF_MAX_Q16，RO | 当前上限 64 V，4194304 / 0x00400000；服务端先读该值检查范围 |
| 0x5C | COMMAND_ERROR，RO/W1C | bit0：非法 AXI 命令标志，独立于保护故障 |
| 0x60 | FAULT_CLEAR，W1P | bit0 写 1 请求清过流/过压；先关闭输出并清给定；读回 0 |
| 0x64 | FAULT_CONTROL_ID，RO | 0x464C5431，FLT1；清故障 API 先核对能力标识 |

例：12 V 写 0x000C0000，24 V 写 0x00180000，64 V 写 0x00400000。先设给定，再请求输出开。只写给定不会自动开启输出。
OUTPUT_CTRL 使用 WSTRB[0]；VREF 支持按字节合并后整体校验，但软件应使用完整 32 位写。
负数、超过 64 V 或命令地址未对齐的写入返回 SLVERR，旧有效命令不变。ARM 服务端应先校验并返回 NACK，避免让不合法网络数据触发 CPU 总线异常。

输出关即时将四路 PWM 管脚拉低，并清零 PI/软启动状态；ADC 继续 25 kHz 采样。再次开启从 0 给定重新爬升。
非零给定调整保持原有 48 V / V_SOFT_START_MS 的斜率，默认 480 V/s：0 到 48 V 约 100 ms、0 到 12 V 约 25 ms、0 到 64 V 约 133.3 ms。DCDC_top 的 V_REF_Q16 是斜坡速率基准，不是命令上限。给定写 0 会关断实际输出并清除 OUTPUT_CTRL 请求位；给定为 0 时的开启命令被拒绝。
开启需 ADC 初始化完成并在 PWM 周期边界装载新占空比。ADC 故障、外部复位或 PLL 失锁会关断；复位后需重新下发命令。

### PL 保护、故障上传与软件清除

标定后的实际输出电流 >2.5 A 或电压 >80 V 时立即停止闭环，清零 PI / 斜坡并拉低全部四路 PWM。严格大于才触发，不取绝对值；ADC、AXI 和 FIFO 继续运行。protection_stop 握手仍会自动清零旧的 0x40 开启请求与 0x44 给定。
新增独立锁存的过流 bit7（0x80）和过压 bit8（0x100），在实时 0x4C 和 ADC_STATUS 0x04 上报，FIQ4 第四字也包含这些位。读数恢复正常、写输出关或清 FIFO 都不会清除原因，也不会自动重新开启。

清除流程：最近一个完整有效样本必须已恢复至电流 <=2.5 A 且电压 <=80 V，ADC 初始化完成且无 ADC 驱动故障。向 0x60 写 1 请求清故障；硬件先把输出请求和给定都置零，再尝试清除两种保护锁存。若最新样本仍越限或同拍又检测到越限，则保留故障，越限优先。清除成功仍保持输出关闭。

```c
/* 队友现有的“清故障”命令处理分支： */
int rc = DcdcAxi_ClearFaults(&dev);
/* rc == 0 才回复清除成功；-5 表示仍有故障，-3 表示固件不匹配。 */

/* 清除成功后，分别响应新的设置给定和开启命令： */
rc = DcdcAxi_SetVrefMilliVolt(&dev, 12000);
if (rc == DCDC_OK) rc = DcdcAxi_SetOutput(&dev, 1);
```

0x60 是 W1P 命令，读回为 0，原始 AXI 写返回 OK 仅表示请求接收。C API 会检查 FLT1 能力标识（0x64=0x464C5431）及实际故障/命令回读，旧 bit 不会被误判为清除成功。队友不得无条件 ACK。
ADC 驱动故障仍由系统复位恢复，0x60 不复位 ADC；bit3 未解除时 ClearFaults 返回 -5。0x5C 只清非法命令标志。电流给定、温度和可编程电流限值仍未实现。
故障未清除时，非零给定下的开启命令会被联锁拒绝。恢复顺序为“正常采样 → 清故障成功 → 重新设置给定 → 开启”，无需为过流/过压重启系统。系统复位仍清除保护锁存和旧命令。
数字保护基于 25 kHz 完整样本，实际响应仍包含采样相位、ADC 转换和串行读取时间。

## 上行 STATUS 字段

| 偏移 | 字段 | 单位/说明 |
|---|---|---|
| 0x08 | sequence | ADC 帧计数，uint32 |
| 0x14 | voltage_q16 | int32 / 65536，V |
| 0x18 | current_q16 | int32 / 65536，A |
| 0x48 | duty_q16 | PWM 实际生效占空比，uint32 / 65536；百分比需再乘 100 |
| 0x4C | output_status | 实时状态，见下表 |
| 0x44 | vref_requested_q16 | 已接受的目标电压，可作为“板卡当前给定”回显 |
| 0x50 | vref_active_q16 | 当前斜坡给定，int32 / 65536，V |
| 0x30 | dropped_frames | FIFO 丢弃的 ADC 帧数 |

OUTPUT_STATUS：bit0=请求开启，bit1=实际 PWM 已开启，bit2=ADC 初始化完成，bit3=ADC 驱动故障，bit4=PLL 锁定，bit5=PWM 周期边界已使能，bit6=控制采样溢出，bit7=过流锁存，bit8=过压锁存；bit31:9 保留。上传故障字段可取 output_status & 0x188，保持原始位含义。
上位机的“输出开”指示应取 **bit1**，不能只看请求位。占空比来自 PWM 内部实际锁存的高电平计数，不是尚未生效的 PI 计算结果；输出关闭时报告 0。
电压、电流、占空比在同一 ADC 帧锁存。直接读取时，先读 sequence，再读这三个字段，最后重读 sequence；两次相等才接收。状态/给定是实时字段，不属于上述帧快照。

## ARM 调用接口

加入队友的 Linux 服务端。
FD 裸机传物理基地址 0x80000000；Linux 应传已映射的 AXI 寄存器页虚拟地址，不能直接将物理地址强转指针访问。

```c
DcdcAxi dev = {0};
int rc = DcdcAxi_Bind(&dev, mapped_register_base);

/* 在相应上位机命令处理函数中调用： */
rc = DcdcAxi_SetVrefMilliVolt(&dev, 12000);  /* SET_VREF: 12 V */
rc = DcdcAxi_SetOutput(&dev, 1);            /* OUTPUT_ON */
rc = DcdcAxi_SetOutput(&dev, 0);            /* OUTPUT_OFF */
rc = DcdcAxi_ClearFaults(&dev);             /* 现有清故障命令 */

DcdcStatus s;
rc = DcdcAxi_ReadStatus(&dev, &s);          /* 构造上位机 STATUS */
```

这些行是三个独立命令的示例，不要在启动代码中依次全部执行。
队友负责 TCP/串口帧的 CRC、序号和 ACK/NACK 编码，并串行调用 C 接口：返回 0 表示请求已接受；-1 参数错误、-2 超范围/零给定开输出、-3 硬件版本/回读错误、-4 采样快照重试失败、-5 ADC / 过流 / 过压故障未解除或拒绝开启。
OUTPUT_ON 的 ACK 表示请求已登记，随后以 STATUS.bit1 判断实际输出；不能把收到命令直接当作输出已开启。
浮点输入先检查有限值和范围，再转毫伏调用 SetVrefMilliVolt；也可用 SetVrefQ16 保留更高精度。
当前 64 V 对应 SetVrefMilliVolt(dev, 64000) 或 SetVrefQ16(dev, 4194304)。API 动态读取 0x58，旧 48 V bit 仍会拒绝 64 V；队友的 GUI 和 TCP 输入校验需同步支持新上限，优先使用硬件回读值。
ReadStatus 在实际输出关断时返回 duty=0，即使最后一帧的占空比快照尚未刷新。
保护停机后 0x40 / 0x44 自动清零。清故障成功后重新设置给定并开启；头文件新增 DCDC_OVERCURRENT_FAULT、DCDC_OVERVOLTAGE_FAULT、DCDC_SHUTDOWN_FAULTS 和 DcdcAxi_ClearFaults。

队友使用的最终字段转换：

```text
Vout = voltage_q16 / 65536.0
Iout = current_q16 / 65536.0
Duty_percent = duty_q16 * 100.0 / 65536.0
Output_on = (output_status & 2) != 0
Vref = vref_requested_q16 / 65536.0
```

## FIFO / 后续 DMA 格式

FIFO_ID（0x34）更新为 **0x46495134，FIQ4**。每个 ADC 帧按顺序包含四个 32 位字：

1. 电压 signed Q16，V。
2. 电流 signed Q16，A。
3. 实际占空比 unsigned Q16，0～1。
4. OUTPUT_STATUS 快照。

四个字段同一时刻锁存。FIFO 满时丢整个新帧，不破坏配对顺序。FIFO_LEVEL（0x24）按字计数，DROP_COUNT（0x30）按帧计数。
触发当帧的 FIFO 状态快照可能仍是故障前值，后续帧包含锁存原因；即时故障显示应读实时 0x4C。新增 bit7/8 不改变 FIQ4 字序和包长。
每包 256 帧 = 1024 字 = **4096 字节**，TLAST 在最后一帧的状态字。将来 DMA 单包长度设置 4096；FIFO 数据宽度继续为 32 位。
4096 字深度约能缓冲 1024 帧，即 25 kHz 下约 41 ms，实际容量以握手计数为准。
新的 adc_fifo_capture/main.c 输出 CSV：sample,voltage_V,current_A,duty_percent,output_on,fault_bits。fault_bits 为 status & 0x188 的十进制值。程序只采集/打印，不会自动开启功率输出。
正式上位机的低速 STATUS 可直接用 ReadStatus，无需等待或排空整包 FIFO。此前 FIQ2 的双字解包程序不兼容 FIQ4。

## DI 与下载

磁盘中框图、组件 XML 和生成 HDL 已同步新增：duty_q16_in[31:0]、control_status_in[31:0]、vref_active_q16_in[31:0] 输入，以及 output_enable_cmd、vref_cmd_q16[31:0] 输出。
前两根同时送采样打包和寄存器；vref_active 只供寄存器读取；命令输出接 DCDC_top。保留 protection_stop 自动清旧命令，新增 fault_clear_cmd 从 AXI 从机返回顶层；组件 XML、Design.xml、UI、包装和生成 HDL 已同步。没有新增封装引脚。
若 DI 已打开，关闭并重新读取磁盘设计，再 Validate；避免旧缓存覆盖新端口。下载配套的新 bit/HPF 和 ARM 程序。

本次故障上传 / 清除验证：生产 ADC、标定、非零仿真 PI、PWM 与真实 AXI 寄存器联合测试通过，覆盖原因锁存、持续越限拒绝清除、安全清除后保持 OFF/给定为零、清除后重新开启，以及新越限优先于同拍清除。FIFO 回归验证 bit7/8 完整上传、W1P/WSTRB/地址对齐和 FLT1 能力读回。
C API 主机测试、FD AArch64 编译、64 V 给定 / 原斜坡、标定 / 饱和回归通过。
完整综合布线和 bit 生成完成：2026-10-15 22:41；SWNS 0.812 ns、HWNS 0.025 ns、STNS/HTNS 为 0，STA 覆盖率 99.95%。记录见 tmp/fault_clear_20261015/validation.md；已有厂商 IP / 时钟警告保留，实际功率级及 TCP 端到端联调仍待上板验证。
备份与日志：tmp/fault_clear_20261015。给队友使用 dcdc_axi_handoff_fault_clear_20261015.zip；此前无故障位的 restart 交接包留作历史版本。
