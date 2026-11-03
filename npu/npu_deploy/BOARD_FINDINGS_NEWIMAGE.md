# 2026-10-27 晚：新镜像 + 子卡到位，NPU 全链路实测

## 1. 板子被重新刷过（重要）

新镜像（kernel 6.1.111-rt42）和我们之前的部署**完全不同**：

| 项 | 之前 | 新镜像 |
| --- | --- | --- |
| `/opt/npu` | lib + dcdc + threeclass + ko | **只剩 ko** |
| `/etc/init.d/S98npu` | 有 | 没了 |
| `/root/data` | 有 | 没有 |
| libstdc++ | 有 | **没有**（`/usr/lib/libstdc++*` 不存在） |
| HMI | S99hmi 在 /etc/init.d | S99hmi 在 `/opt/hmi/S99hmi` |

所以刷完镜像必须重做一遍部署：`/opt/npu/lib`（armnn/onnxparser/protobuf/**libstdc++/libgcc_s**/shim）、
`/opt/npu/threeclass`、`/etc/init.d/S98npu`。

## 2. FDMA 环地址变了：0x3FC00000 → 0x94000000

新位流把采样环放在 **0x94000000**，而且它写在 `FDMA FD_BASE_LO/HI`（0x10/0x14）里。
之前工具里写死的 `0x3FC00000` 读到的是别的内存（解出来 V=16287 V 这种离谱值）。

**正确做法：从寄存器读基址**，别写死：

```c
ring_base = ((unsigned long)fd[0x14/4] << 32) | fd[0x10/4];
```

`probe_fdma.c` / `fdma_capture.c` 已改成这样。

## 3. 子卡到位后 ADC 真的出数据了

```
[fdma] ring_base=0x9400000 (from FD_BASE registers)
[fdma] ID=0x46444d31 FORMAT=0x50343831 STATUS=0x00000013 ERROR=0x00000000
[fdma] t0: producer=51934 consumer=51934
[fdma] t1: producer=52032 consumer=52031  (+98 blocks in 1s)
[fdma] last frame: V=24.2038 V  I=0.5000 A  duty=50.37%
[fdma] OK
```

- 98 blocks/s × 256 帧/块 ≈ **25 kHz** 原始采样率
- 解出来的 V/I/duty 完全合理（24 V / 0.5 A / 50%）

真实采集 20 秒（`fdma_capture --hz 128`）：

```
[cap] 20.0s: 2054 blocks, 1954 samples -> 97.7 Hz 实际采样率
```

> 注意：每个块只取 1 帧 → 上限就是块率 ≈98 Hz。要真到 128 Hz，需要每块取 2 帧
> （块内 stride）。目前 98 Hz 也够用：窗口工具按**时间**取 2 s 再重采样到 256 帧，
> 只要求把 `--rate 98` 传对。

## 4. 真实数据 → NPU：全链路跑通

板上流式推理（`threeclass_live`，真实采集的 cap_01.csv）：

```
   2.50s  normal  [19 1 0]  0.243 ms
   4.50s  normal  [19 0 0]  0.115 ms
   ...
  19.56s  normal  [19 0 0]  0.098 ms
[live] 18 windows, 5.9 ms total (0.33 ms/window incl. preprocess)
irq_delta=18
```

- 18 个窗口 → **IRQ 增量 18**（每窗 1 次硬 NPU 中断）
- 0.33 ms/窗（含预处理）
- PC 侧 `scan` 同样数据：18/18 都判 `normal`，与板上一致

46 例回归（新镜像上重跑）：`CASES=46 OK=46 BAD=0 IRQ_DELTA=46`。

## 5. 还没做的一步：真实负载阶跃

现在只采到**稳态**（24 V / 0.5 A），模型判 `normal` 正确。
要验证 `load_transient`，需要现场**物理切换负载**（或电子负载打阶跃）：

1. 起采集：`/opt/npu/tc/fdma_capture --out /root/data/cap_step.csv --hz 128 --duration 30`
2. 采集期间手动切换负载 3~5 次
3. 采完 `tc.cmd scan --csv cap_step.csv --rate 98`

另外振荡类（`oscillation`）同样需要真实激励，目前没有独立验证。

## 6. 部署命令（刷完新镜像后照抄）

```powershell
# 1) 建目录
plink ... "mkdir -p /opt/npu/lib /opt/npu/threeclass/bin /opt/npu/threeclass/models /opt/npu/tc /root/data"

# 2) 传库（注意：新镜像没有 libstdc++，必须带）
pscp ... libarmnn.so.32 libarmnnOnnxParser.so.24 libprotobuf.so.23 libstdc++.so.6 libgcc_s.so.1 libsoftnpu_shim.so -> /opt/npu/lib/

# 3) 传程序 + 模型 + 向量
pscp ... dcdc_npu_threeclass_infer -> /opt/npu/threeclass/bin/
pscp ... threeclass_live probe_fdma fdma_capture probe_ddr -> /opt/npu/tc/
pscp ... condition_threeclass_uint8.onnx quant_params.txt -> /opt/npu/threeclass/models/
pscp -r ... vectors -> /opt/npu/threeclass/

# 4) 板上一键（S98npu + run.sh + batch46.sh 见 RUNBOOK）
```

跑：`sh /opt/npu/threeclass/batch46.sh` → 期望 `CASES=46 OK=46 BAD=0 IRQ_DELTA=46`。

## 7. 真实阶跃：模型确实报出了 load_transient

用 peek 模式采集（不抢 power_svc 的 FDMA 消费权）+ 通过协议帧改给定 24 V -> 12 V：

```
     5.50s  normal           [19, 0, 0]
     6.00s  load_transient   [34, 156, 32]
     ...
    27.00s  load_transient   [27, 159, 0]
[scan] counts: normal 4, load_transient 22, oscillation 0
```

**这是这个三分类模型第一次在真实数据上报出 `load_transient`**（之前都是打包向量）。
采集文件 `out/cap_vstep.csv`（2734 点，97.6 Hz）。

## 8. 硬件侧发现（需要人看）

1. **读 `0x80000048` 会 Bus error**：`devmem 0x80000048 32` 直接 SIGBUS。
   我之前那版 `power_svc --csv-hz` 崩在 Bus error，很可能就是这个地址。
   建议让做 PL 的同学确认 0x48 是否没解码，或读它有副作用。
2. **`0x8000004C` = 0x37**：bit0/1/2/4/5 置位，bit3(ADC 故障)/bit6(溢出) 未置位。
   所以输出掉到 0.32 V 时**不是 ADC 故障位造成的**。
3. 服务日志明确：`电流给定未实现（忽略）` —— 设 i_set 无效，只有 v_set 生效。
4. 现场状态：`vref=16.00 V`、`output_active=1`，但 `V=0.32 V / duty=0%`，
   功率级没在开关，需要人去查输入电源/输出回路，或者断电重启。

## 9. 单客户端限制（脚本要注意）

`power_svc` 同时只接受一个 TCP 连接：如果上一个连接是半开状态，新的 connect 会一直
超时（listen 队列没人取）。脚本里连续发命令时要么复用同一个连接，要么每次前
`/etc/init.d/S99power restart`。

## 10. HMI 的 NPU 模块已接到真实推理（2026-10-31）

`/opt/hmi/hmi` 里的 `onNpuPoll()` 每 500 ms 读 `/tmp/npu.status`：
`0` -> "● 正常"（绿）、`1` -> "● 突变"（红）、其它 -> "● 无结果"（灰）。
之前没人写这个文件，所以界面一直显示"无结果"。

现在由常驻进程 `npu_daemon` 写：

| 环节 | 实现 |
| --- | --- |
| 数据 | 读 FDMA 环（peek，不抢 power_svc 的消费权） |
| 窗口 | 每 0.5 s 取最近 2 s，重采样成 256 帧 |
| 推理 | 三分类模型跑硬 NPU，约 0.20 ms/次 |
| 映射 | normal -> 0；load_transient / oscillation -> 1 |
| 去抖 | 同一新状态连续 2 个窗口才切换（避免闪） |
| 待机 | 窗口内 V<1 V 且纹波<0.5 V 时写 -1（显示"无结果"，不硬判） |

### 开机自启（已实测重启验证）

```
/etc/init.d/S98npu          驱动 insmod
/etc/init.d/S99npu_daemon   起 npu_daemon（写 /tmp/npu.status）
```

重启后检查：

```
/dev/cma_mem  /dev/hard_npu           都在
330 root  /opt/hmi/hmi                 界面
337 root  /opt/npu/tc/npu_daemon ...   识别进程
347 root  /usr/bin/power_svc ...       采集服务
41: 142 ... HARD_NPU_IRQ               中断计数在涨（说明一直在算）
```

### 注意

1. **`hard_npu` 独占**：daemon 跑着时，手动跑 `batch46.sh`/`threeclass_live` 会报
   `Can't open hard_npu driver`。`batch46.sh` 已改成自动"停 daemon -> 跑回归 -> 拉起"。
2. 开机后输出默认是关的，此时界面显示灰色"无结果"（这是待机门，不是故障）。
3. 负载真跳变时，界面 1~1.5 s 内翻红（2 s 窗口 + 2 窗口去抖）。
