# 单电压环控制修改

2026-10-25 更新：当前工程已恢复电压外环、电流内环，见 [双环恢复说明](dual_loop_20261025.md)。下文保留单电压环历史记录。

2026-10-13 更新：本文件下文保留早期数字基线。当前增加了电压前馈、±0.2 的 PI 修正限幅、动态 v_ref 斜坡和 AXI 输出开关，默认输出关闭；实际接口与验证见 DCDC_AXI_CONTROL.md。

修改日期：2026-10-12。生产代码：`uisrc/01_rtl/DCDC_top.v`。

控制链路改为 `ADC V2 -> 电压反馈 Q16 -> 电压 PI -> 占空比 Q16 -> PWM 计数`。
调度状态为 `WAIT_SAMPLE -> START_V -> WAIT_V -> WAIT_SAMPLE`，每帧有效采样只运行一次电压 PI。
电流闭环的增益参数、电流给定限幅、反馈和给定寄存器、调度语句以及完整 PI 实例均以 `//` 注释保留。

电压 PI 输出现在代表占空比，限幅使用 `DUTY_MIN_Q16=3277` 和 `DUTY_MAX_Q16=62259`。
两端分别映射为 `200/4000` 和 `3800/4000`，即 5%～95%；中间值按 `floor(duty_q16 * 4000 / 65536)` 换算。
PWM 仍为 100 MHz / 4000 = 25 kHz，占空比在 PWM 周期边界生效。

V3 的电流原始码、`I_SCALE_Q16` 换算、AXI 电流遥测、FIFO 数据与 ChipWatcher 观察保留。
电流不参与闭环调节。电压给定仍为 48 V，`V_KP_Q16`、`V_KI_Q16` 默认仍为 0；
首帧计算后零增益会得到 5% 下限。电压 PI 的输出单位从电流改为占空比，需要按单电压环对象重新整定，仿真用增益不写入生产默认值。

验证结果：

- ModelSim 编译和数字集成仿真通过，0 errors、0 warnings，`SINGLE_VOLTAGE_LOOP_RESULT=1`。
- 测试使用生产 ADC 驱动、PI 和 PWM；PLL、ChipWatcher、PS/AXI 系统使用行为桩，只检查顶层遥测接线。
- 7 次受检更新覆盖 50%、6.25%、95% 和 5% 占空比，以及电压从限幅区返回中间值。
- 只改变电流原码为 1、-20、32767 时，电压反馈保持不变，占空比均为 50%，电流遥测同步更新。
- 完整采样有效到占空比寄存器更新为 6 个 100 MHz 时钟，即 60 ns；PWM 边界生效规则保持不变。
- 检查了 5%、50%、95% 的完整 PWM 周期、每周期一次采样触发、复位和 PLL 失锁清零。
- TD 读取 `fpga2026.al` 和实际 IP 后，`elaborate -top DCDC_top` 完成，无 ERROR 或 CRITICAL-WARNING；厂商 AXI/FIFO IP 的位宽及未连接端口 WARNING 仍有报告。

仿真入口：`uisrc/02_sim/single_voltage_loop/run.do`；日志：`tmp/single_voltage_loop_modelsim.log`。
TD 工程展开入口：`tmp/single_voltage_loop_check.tcl`。
本次未重新综合、布局布线或生成下载文件，也未进行模拟功率级稳定性或上板验证。
`review_20261008` 中的双环审计仿真保留历史用途；当前控制链路回归使用新的单电压环仿真。
