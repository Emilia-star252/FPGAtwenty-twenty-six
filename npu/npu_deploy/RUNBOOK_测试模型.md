# 板上试模型（以三分类 NPU 模型为主）

主力模型：**`condition_threeclass_uint8.onnx`**（normal / load_transient / oscillation）
板上安装位置：`/opt/npu/threeclass/`（`bin/ models/ vectors/ run.sh`）

---

## 0. 每次开板（三件事）

```powershell
# 板子活着没
Test-Connection 192.168.137.101 -Count 2 -Quiet

# 驱动：cma_mem -> jpu -> hard_npu（已装 /etc/init.d/S98npu，可手动触发）
$s = @'
[ -e /dev/hard_npu ] || sh /etc/init.d/S98npu start
ls /dev/hard_npu /dev/cma_mem
grep HARD_NPU_IRQ /proc/interrupts
'@
$s | & 'D:\FPGA\PuTTY\plink.exe' -ssh -batch -pw root root@192.168.137.101 "sh -s"
```

`/dev/hard_npu` 和 `41: ... HARD_NPU_IRQ` 都在就绪。**记下中断计数**，它是判断"真上 NPU"的硬证据。

> `run.sh` 里已经带了两件必须的东西：
> `LD_LIBRARY_PATH=/opt/npu/lib`、`LD_PRELOAD=/opt/npu/lib/libsoftnpu_shim.so`
> （镜像没有 `/dev/soft_npu` 节点，不加垫片 Alnpu 后端根本初始化不了）。

---

## 0.5 用 `tc.cmd`（不用管路径和 Python 环境）

你机器上的 `py` 是系统 Python 3.12，**没装 numpy**；脚本又在 `D:\deepseek\work\npu_train` 下。
所以别直接 `py scan_threeclass.py`，用这个包装器（它固定用装了 numpy 的 DSH Python）：

```bat
D:\deepseek\work\npu_train\tc.cmd demo
D:\deepseek\work\npu_train\tc.cmd scan  --csv logs\run1.csv --rate 128 --hop 1.0
D:\deepseek\work\npu_train\tc.cmd input --csv logs\run1.csv --end 12.5 --out out\case12
D:\deepseek\work\npu_train\tc.cmd push  out\case12
D:\deepseek\work\npu_train\tc.cmd run   case12
D:\deepseek\work\npu_train\tc.cmd batch
D:\deepseek\work\npu_train\tc.cmd verify
```

在任意目录下都能跑；`scan/input` 的相对路径以**当前目录**为准。
（第一次用 `demo` 会在 `D:\deepseek\work\npu_train\out\` 生成一段合成采样并扫出时间线。）

## 1. 一条命令跑一帧（最常用）

```powershell
$s = @'
cd /opt/npu/threeclass
./run.sh cap_step_win.physical_f32.bin cap_step_win.baseline_f64.bin
'@
$s | & 'D:\FPGA\PuTTY\plink.exe' -ssh -batch -pw root root@192.168.137.101 "sh -s"
```

输出长这样（我跑过的真实输出）：

```
LOGITS 0.6193826795 5.475342751 1.114888787 CLASS=1 inference_ms=0.34017
FILE_INFERENCE_OK strict_requested_backend=Alnpu
[run] irq_delta=1   (1 = one fused NPU op executed)
```

`CLASS`：0=正常、1=负载瞬态、2=振荡。

---

## 2. 换成真实采样（PC 侧三步）

```powershell
# ① 采集日志（板卡 CSV：uptime_s,v_out,i_out,duty,...；10 Hz 或更高更好）
#    板上已有 power_svc（TCP 5000），host.py 也能存 CSV

# ② 转成模型输入（窗口 256 帧 ≈ 2 s @128 Hz）
py make_threeclass_input.py --csv logs\run1.csv --end 12.5 --out out\case12

# ③ 推上板、跑
pscp -pw root -batch out\case12.physical_f32.bin out\case12.baseline_f64.bin root@192.168.137.101:/opt/npu/threeclass/
```

板子侧：

```sh
cd /opt/npu/threeclass && ./run.sh case12.physical_f32.bin case12.baseline_f64.bin
```

**采样率的坑必须知道**：模型按 128 Hz × 256 帧训练；1 Hz 日志喂进去，重采样只是插值，
时间尺度完全不对——只能验证链路，别拿它评精度。工具会在速率 <32 Hz 时告警。

---

## 2.5 先别上板：PC 侧直接看类别时间线

我已经用 numpy 复现了他们的 ONNX（与他们 `features_u8` 逐位一致，46/46），
所以**不接板子也能扫一段采样**，看模型怎么判：

```powershell
py scan_threeclass.py --csv out\cap_phases.csv --rate 128 --hop 1.0
```

真实输出（合成信号：稳态 4 s → 负载阶跃 → 振荡 4 s）：

```
     2.00  normal           [49, 40, 47]
     3.00  normal           [19, 0, 0]
     4.00  load_transient   [23, 34, 34]
     5.00  load_transient   [30, 220, 34]
   ...
[scan] 类别切换: t=4.00s normal->load_transient
```

用途：**先判断这段数据值不值得上板跑**，以及阈值/窗口长度是否合适。
注意我那段人为"振荡"被判成 load_transient —— 说明它的振荡类和真实 PLECS 振铃签名绑定，
合成信号骗不过去，这本身是个有用的提醒。

## 3. 判断"到底有没有上 NPU"（缺一不可）

| 证据 | 怎么取 | 期望 |
| --- | --- | --- |
| A. 优化图 | `grep -o "ALHardNPU[^\\]*" /tmp/tc_graph.dot` | `ALHardNPU`、`OutputChannels : 16`、`FilterWidth : 3`、`BackendID : Alnpu` |
| B. 中断计数 | 跑前跑后 `grep HARD_NPU_IRQ /proc/interrupts` | 增量 = 推理次数（这个模型每帧 1 次） |
| C. 无回退 | 看日志有没有 `falling back` / `not supported` | 没有 |

三者都成立才算真跑在 NPU 上；只看到 `CLASS=x` 不算。

---

## 4. 已验证的基线数字（2026-10-27）

| 项 | 数值 |
| --- | --- |
| 包内 46 例回归 | **46/46 类别正确**，IRQ 增量 46（每帧 1 次） |
| 单次推理 | 0.369 ms（p50 0.363，min 0.312，max 0.528） |
| 优化图 | 单个 `ALHardNPU` 节点（16 通道 / 3×3） |
| 合成阶跃窗（128 Hz，`cap_step_win`） | CLASS=1（load_transient），0.34 ms，IRQ +1 |

---

## 5. 备用：我那个四分类模型（稳态分级）

只在需要"轻载/额定/近限流/故障"时才用：

```powershell
$s = @'
cd /opt/npu/dcdc
./run.sh -m dcdc_rq.onnx -b Alnpu -c dcdc_board_test.csv --check | tail -3
'@
$s | & 'D:\FPGA\PuTTY\plink.exe' -ssh -batch -pw root root@192.168.137.101 "sh -s"
```

基线：200 样本 0 类不一致、0.158 ms、IRQ 增量 615（205 × 3 层）。

---

## 6. 流式滑窗（已经能跑，替代“一次一个文件”）

板上装了一个常驻式程序 `threeclass_live`：**网络只加载一次**，之后按窗口循环推理。
数据源目前是 CSV 回放，接 FDMA 时只需要换掉数据源那一层。

```powershell
# PC 一条命令：推 CSV 上去并跑流式推理
D:\deepseek\work\npu_train\tc.cmd live D:\deepseek\work\npu_train\out\cap_phases.csv 128 1.0
```

实测（128 Hz 回放，hop 1 s，10 个窗口）：

```
   2.49s  normal          [21 2 0]  0.255 ms
   3.49s  normal          [19 0 0]  0.089 ms
   4.49s  load_transient  [25 220 44]  0.158 ms
   ...
[live] 10 windows, 3.4 ms total (0.34 ms/window incl. preprocess)
```

- 每窗 IRQ +1（`HARD_NPU_IRQ` 增量 = 窗口数），证明每窗都真在 NPU 上跑；
- 与 PC 侧 `tc.cmd scan` 的类别时间线完全一致（时间戳差 0.49 s 是因为板上要等半秒历史才算 baseline）。

## 7. 还差的一环：真实数据源

`threeclass_live` 的 `ReplaySource` 现在读 CSV。接实时只需实现同样的 `size()/at()`
换成读 FDMA 的 DDR 环（`0x3FC00000`，1024 槽 × 4 KB），其余（滑窗、baseline、预处理、推理）不用改。

**当前硬件状态（2026-10-27 实测）**：`power_svc` 起来后 `FDMA producer=0`、`ADC 首帧超时`、
CSV 全 0、`fault=4(ADC)` —— 采样通路没有数据，所以实时这一环暂时无法验证。

## 8. 已知未完成项

| 项 | 状态 |
| --- | --- |
| 板上 46 例回归 | ✅ 46/46，IRQ 46 |
| 流式滑窗（CSV 回放） | ✅ 0.34 ms/窗，IRQ 每窗 +1 |
| 真实采样（128 Hz） | ❌ PL 无 ADC 数据（producer=0） |
| `power_svc --csv-hz 128` | ⚠️ 已改好源码并编出二进制，但板上实测报 Bus error，原因未查清，暂不推荐使用 |
| 三分类模型的泛化 | ⚠️ transient 只有 135 个训练窗口；振荡无独立实测 |
