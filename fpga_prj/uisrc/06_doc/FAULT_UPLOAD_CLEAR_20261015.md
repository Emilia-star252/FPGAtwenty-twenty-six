# 队友接入：上传故障与清故障

2026-10-15，物理基地址 0x80000000。网络帧格式和命令编号沿用你们现有协议，由 ARM 服务端映射。

| STATUS 原始故障位 | 掩码 | 含义 |
|---|---|---|
| 0x4C.bit3 | 0x00000008 | ADC 驱动故障，仍需系统复位 |
| 0x4C.bit7 | 0x00000080 | 实际电流 >2.5 A，过流锁存 |
| 0x4C.bit8 | 0x00000100 | 实际电压 >80 V，过压锁存 |

```c
DcdcStatus s;
int rc = DcdcAxi_ReadStatus(&dev, &s);
if (rc == DCDC_OK) {
    uint32_t fault_bits = s.output_status & DCDC_SHUTDOWN_FAULTS;
    /* 将 fault_bits 写入现有 STATUS 帧；若已有故障编码则显式映射。 */
}

/* 在队友已有“清故障”命令分支调用，返回 0 才发送成功 ACK： */
rc = DcdcAxi_ClearFaults(&dev);
/* -5：仍有故障；-3：旧硬件/回读不符；-1：参数错误。 */
```

清除入口 0x80000060，32 位写 1；0x80000064 必须读回 0x464C5431（FLT1）。C API 已完成这些访问，Linux 使用 mmap 虚拟地址。

清除会关闭输出并清零给定；只有最近完整样本已回到电流 <=2.5 A、电压 <=80 V、ADC 正常且没有新的越限，才清保护原因。故障没有解除时返回失败。清除不复位 ADC 驱动，也不自动开启 PWM。

恢复顺序：正常采样 → 清故障成功 → 重新设置 v_ref → 单独发输出开。故障期间设置给定或反复发开启命令无法绕过保护。

FIFO 仍为 FIQ4：V、I、duty、status 四字，256 帧/4096 字节。故障触发当帧的状态可能在锁存前，后续帧反映原因；即时故障显示读实时 0x4C。

使用新版 bit 和新版 dcdc_axi.c / dcdc_axi.h；原 0x5C 仍仅清命令错误。当前已完成数字仿真，TCP 端到端和实际功率级仍需上板验证。

串口 FIFO 采集示例也新增 fault_bits 列：sample,voltage_V,current_A,duty_percent,output_on,fault_bits。该列为上述原始掩码的十进制值，例如 128=过流、256=过压、384=两者同时锁存。
