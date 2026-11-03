# DC-DC 工况识别：NPU 训练与部署包

给 DR1M90（Anlogic）DCDC 闭环项目做的「训练 → 导出 → 板上 NPU 推理」链路。
模型输入是**电压、电流、占空比**三个量（用户指定），输出 4 类工况：

| 类别 | 含义 | 判据（标签定义） |
| --- | --- | --- |
| 0 | 正常-轻载 | I ≤ 0.35 × 2 A |
| 1 | 正常-额定 | 0.35 ~ 0.90 × 2 A |
| 2 | 重载-近限流 | > 0.90 × 2 A（含 CC 恒流段） |
| 3 | 保护故障 | 保护动作、输出已锁存关断 |

## 0. 现状（先看这张表）

> **2026-10-27 更新：模型已在板上硬 NPU 跑通**，证据见 [`out/BOARD_EVIDENCE.md`](out/BOARD_EVIDENCE.md)：
> IRQ 41 增量 615、单次 0.160 ms（CpuRef 5.098 ms，≈32×）、与 PC 结果 0 类不一致 / 2.5e-3 概率偏差。

| 环节 | 状态 | 证据 / 说明 |
| --- | --- | --- |
| 数据集生成（物理仿真+规则标注） | ✅ 完成 | 2400 条，4 类分布 605/623/690/482，见 `out/dataset.csv` |
| 训练 | ✅ 完成 | test acc 99.72%，按试验号分组划分，见 `out/RESULTS.md` |
| ONNX 导出（float32） | ✅ 完成 | `out/dcdc_npu.onnx` 3.5 KB，opset 13，Gemm×3+Softmax，回读对拍 7.7e-7 |
| ONNX 导出（QDQ + 1×1 Conv） | ✅ 完成 | `out/dcdc_npu_qdq.onnx` 3.3 KB，**照官方模型的 QDQ 形态写**，与独立量化实现对拍 4.4e-16，类别与 float 模型一致率 99.72%，测试集 100% |
| QDQ 补零变体 | ✅ 完成 | `out/dcdc_npu_qdq_8x4.onnx`（输入 `[1,8,4,4]`，补零通道/空间，数学等价，对拍 8.9e-16）——形状被 NPU 拒时用它 |
| Alnpu 后端能力摸底 | ✅ 完成 | 从官方 `libarmnn.so.32.1` 反推：硬 NPU 是 int8 卷积引擎、NCHW、通道上限、kernel/stride/pad 规则，见 [`ALNPU_CAPABILITIES.md`](ALNPU_CAPABILITIES.md) |
| ONNX 结构可信度 | ✅ 已交叉验证 | 同一个解析器能正确读出官方 `yolo_face_uint8_15.onnx`（opset 14/124 节点）与 `fire_detect_sim_quant_uint8.onnx`（opset 13/771 节点）的图、初始张量形状与 dtype |
| 板端 C++ 程序 | ✅ 已编译并运行 | 用 SDK 自带 sysroot + 裸机 gcc 12 交叉编译（`board/build_win.ps1`），板上一路跑到推理 |
| 板上 Alnpu 实跑 | ✅ 完成 | `out/dcdc_rq.onnx`：`-b Alnpu` 无回退，IRQ 41 增量 **615**（205 次推理 × 3 层），**0.160 ms/次** vs CpuRef 5.098 ms（≈32×），与 PC 概率最大偏差 2.5e-3、类别 0 不一致（见 `out/BOARD_EVIDENCE.md`） |

**别把 99.72% 当成真实识别能力**：数据是仿真生成的，类别边界本身写在生成器里，
所以「只用 I 阈值的规则」在这份数据上也是 100%。这一轮的目标是**把链路打通、把风险找出来**，
不是给出最终精度。

## 1. 文件清单

```
work/npu_train/
├── dcdc_sim.py          物理仿真 + 标注（四开关 buck-boost、2A 限流、OVP/OCP/OTP、1kSPS+12bit）
├── gen_dataset.py       生成 out/dataset.csv
├── train.py             纯 numpy MLP 3-32-16-4（Adam），按试验号分组划分
├── onnx_min.py          极简 ONNX 读写器（手写 protobuf；同时能解析官方模型做交叉验证）
├── export_onnx.py       导出 out/dcdc_npu.onnx + out/dcdc_npu_weights.h + out/dcdc_npu_model.json
├── export_onnx_qdq.py   导出 QDQ + 1×1 Conv（可用 --pad-c/--pad-hw 出补零变体）
├── inspect_alnpu.py     只读扫描官方 libarmnn，反推 Alnpu 后端支持的形状/参数约束
├── quantize_sim.py      int8/uint8 量化仿真，给 out/quant_report.json
├── validate_onnx.py     ONNX 结构自检（拓扑序/维数/QDQ 类型），跑在导出之后
├── robustness_test.py   传感器误差敏感度（增益/零点/粗量化/噪声），给 out/robustness.json
├── make_board_test.py   从测试集抽样，生成 out/dcdc_board_test.csv + _expected.csv（含 PC 概率）
├── compare_board_output.py  板上输出 vs PC 期望：类别 + 概率级对拍
├── test_compare_board_output.py  对拍工具的自测（完美输出应通过、+10% 电流应被判失败）
├── make_report.py       汇总成 out/RESULTS.md
├── from_board_csv.py    真实日志 CSV → 训练集格式（接真实数据用）
├── REAL_DATA_PLAN.md    真实数据采集方案（工况矩阵/故障触发/验收门槛）
├── ALNPU_CAPABILITIES.md  Alnpu 后端能力摸底（逆向自官方 libarmnn，含形状约束原文）
├── run_all.py           一条命令重跑全链路
├── board/
│   ├── dcdc_npu_demo.cpp   armnn + OnnxParser + CMA 缓冲；两种加载方式（ONNX / C 权重头）
│   ├── CMakeLists.txt      只依赖官方 armnn_lib
│   ├── build.sh            VM 里交叉编译（路径可用环境变量覆盖）
│   ├── run.sh              板上运行（检查 /dev/hard_npu，设 LD_LIBRARY_PATH）
│   └── evidence.sh         一次收齐三类 NPU 证据（verbose 层分配 / CpuRef 时延 / IRQ 40 增量）
├── out/                 产物（dataset / model.npz / onnx / weights.h / RESULTS.md / 图）
└── _sdk/                官方 face_detection SDK 解包（参考源码，不含 33MB 库）
```

## 2. 三条命令跑完

```powershell
# 本机 Python（numpy 即可，无需 torch/onnx/onnxruntime）
py run_all.py --trials 2400 --epochs 600
# 产物：out/dataset.csv  out/model.npz  out/dcdc_npu.onnx  out/dcdc_npu_weights.h
#      out/dcdc_board_test.csv  out/RESULTS.md  out/model_confusion.png
```

单步：

```powershell
py gen_dataset.py --trials 2400 --out out/dataset.csv
py train.py --csv out/dataset.csv --out out/model.npz --epochs 600
py export_onnx.py --model out/model.npz --outdir out          # float32 版（CpuRef 对照）
py export_onnx_qdq.py --model out/model.npz --csv out/dataset.csv --outdir out   # QDQ 版（先试 NPU）
py quantize_sim.py --model out/model.npz --csv out/dataset.csv
```

## 3. 模型与归一化（板上要对齐的关键）

* 图：`Gemm → Relu → Gemm → Relu → Gemm → Softmax`，输入 `[1,3]` float32，输出 `[1,4]` 概率。
* **另有一版等价图** `out/dcdc_npu_qdq.onnx`：同一个 MLP 写成 1×1 卷积（`Conv1x1 ≡ 全连接`），
  输入 `[1,3,1,1]`，按官方模型的 QDQ 写法加量化：
  `QuantizeLinear/DequantizeLinear` 包输入与每层激活，Conv 权重 uint8（非对称，zp≠0）、
  bias int32，结构与 `fire_detect_sim_quant_uint8.onnx` 同型。**上板优先试这一版**。
* 输入不是原始物理量，而是归一化后的 **u = [Vout/48, Iout/2.2, duty/95]**（都在 0..1）。
  * `(x-μ)/σ` 和这个除数都已经**折进第一层权重**，所以模型只吃 u，别在板上再减均值。
  * 这样做是为了后面转 QDQ 时能用**单一 scale=1/255**，不用按通道搞 3 个 scale。
* `out/dcdc_npu_model.json` 里写了 `divisors` 和类别名，C++ 里对应 `kInDiv[3]`，两边改要一起改。
* 参数量 724（权重 672），float32 2.9 KB / int8 672 B —— 对 NPU 是小到几乎不占资源的图。

## 4. 板上部署（4 步，待执行）

### 4.1 板子准备

```sh
# 驱动（你 10-22 已验证过，vermagic 6.1.111-rt42 匹配）
insmod /opt/npu/ko/cma_mem.ko && insmod /opt/npu/ko/jpu.ko && insmod /opt/npu/ko/hard_npu.ko
ls -l /dev/hard_npu /dev/cma_mem /dev/jpu
# armnn 运行库放到 /opt/npu/lib（官方 SDK 的 libarmnn.so.32 / libarmnnOnnxParser.so.24 / libprotobuf.so.23）
```

### 4.2 交叉编译（在 Linux 构建机 / VM 里）

```sh
# 官方 SDK 用的是 ~/uisrc-lab-anlogic/tools/aarch64-linux/bin/aarch64-linux-gnu-g++
ARMNN_DIR=$HOME/npu/app/face_detection/libs/armnn_lib ./board/build.sh
# 想要「不依赖 ONNX 解析」的兜底模式，再加 WEIGHTS=1
WEIGHTS=1 ARMNN_DIR=... ./board/build.sh
```

依赖与官方 `npu_flow/CMakeLists.txt` 一致：`armnn armnnUtils armnnOnnxParser protobuf fmt`。
`cma_mem_*` 与 `CmaBuf` 的符号由官方 armnn 库提供（官方 app 也是这么链的）。

### 4.3 拷到板上

```sh
pscp -r board\build\dcdc_npu_demo board\run.sh board\evidence.sh \
      out\dcdc_npu_qdq.onnx out\dcdc_npu.onnx out\dcdc_board_test.csv root@<board>:/opt/npu/dcdc/
```

### 4.4 跑，并抓「真的跑在 NPU 上」的证据

先手动跑一遍确认能加载（`run.sh` 默认就用 QDQ 那版）：

```sh
cd /opt/npu/dcdc
chmod +x run.sh evidence.sh
./run.sh -c dcdc_board_test.csv --check        # 断点 1：能否加载 + 与 PC 结果是否一致
```

然后把三类证据一次性收齐（约 1 分钟）：

```sh
./evidence.sh                                  # 产出 npu_evidence_<时间戳>/summary.txt
```

`evidence.sh` 做的事：
1. `-b Alnpu -v` 跑一遍，保存 armnn Info 日志（看每层分到哪个后端）；
2. `-b CpuRef` 跑同一份输入，保存时延对照；
3. 读 `/proc/interrupts` 里 IRQ 40 的计数前后差（最硬的证据：驱动真的进了硬 NPU 中断）。

判定 NPU 真实参与的三个独立证据（缺一不可）：

1. `-v` 日志里层被分配到 `Alnpu`；若回退会显示实际使用的后端。
2. 时延差异：`-b Alnpu` 与 `-b CpuRef` 单次推理时间不同（3 层小图，NPU 可能是「启动开销大于计算」，别只看绝对值）。
3. `IRQ 40` 计数在推理后增加。

拿回 PC 后还要做一次**概率级对拍**（比只看类别严格得多，归一化/通道顺序/量化错位都会立刻暴露）：

```powershell
# board_out.csv 是板上 `-c` 模式的输出（v,i,d,class,p0..p3,ms）
py compare_board_output.py board_out.csv out/dcdc_board_test_expected.csv
# 量化模型改用：--tol 5e-2
```

判据：类别逐条一致；float32 版概率最大偏差 < 1e-4，QDQ 版 < 5e-2。
自测过这个比较器：完美输出通过；把电流读数放大 10% 后它会报 10 条类别不一致 + 偏差 1.0。

注意 `--check` 用的是仿真测试集，只验证「板上结果和 PC 一致」，不验证真实工况能力。

## 5. 风险与下一步（按优先级）

1. **Alnpu 是否接受 3 通道 1×1 Conv 仍是未知数。** 官方两个模型都是 QDQ + Conv，但它们是
   `[1,3,416,416]`/`[1,3,640,640]` 的自然图像输入、通道数 16 起跳；我们这个图是 `[1,3,1,1]`。
   我从官方 `libarmnn.so.32.1` 里捞到了硬 NPU 的形状约束（通道上限 4095、`pad=(k-1)/2`、
   `k+s≤10`、必须 NCHW 等，见 `ALNPU_CAPABILITIES.md`），但**没有**找到最小空间尺寸和通道对齐要求，
   所以只能上板试：
   * 先试 `dcdc_npu_qdq.onnx`（`[1,3,1,1]`）；
   * 被拒就换 `dcdc_npu_qdq_8x4.onnx`（`[1,8,4,4]`，补零、数学等价）——这个变体就是为
     「通道要 4/8 对齐」「空间不能是 1×1」这两种可能准备的；
   * 仍被拒：抓 stderr 里的断言原文（`the channel of conv input ...` 这类句子），按它给的具体限制改。
   * float32 的 `dcdc_npu.onnx` 留着做「CpuRef 也能跑」的对照，别删。
2. **板子不在线。** 本次没法编译和实跑；等板子接上（网口/USB-ICS/串口），按 4.1–4.4 执行。
3. **数据是仿真的。** 真实采样到位后用 `from_board_csv.py` 转格式重训（完整采集方案见
   [`REAL_DATA_PLAN.md`](REAL_DATA_PLAN.md)：每类 ≥300 窗口、≥20 个试验组、边界带加密、
   故障各 ≥40 次，以及验收门槛）：
   ```powershell
   py from_board_csv.py "logs/*.csv" --window 10 --out out/dataset_board.csv
   py train.py --csv out/dataset_board.csv --out out/model_board.npz
   ```
   1 Hz 日志的窗口是 10 s，和仿真的 100 ms 不是一个尺度；建议同时把
   `v_std/i_std/d_std`（脚本已经算出来了）加进特征再练一版对比。
4. **OTP 没单列。** 输入里没有温度，OTP 停机后的 V/I/D 与 OVP/OCP 完全相同，
   归到「保护故障」一类；要区分就得把温度也作为输入（会变成 4 输入，需重新导出）。 

## 6. 为什么手写 ONNX（而不是 pip install onnx）

这台机器连不上 PyPI（`pip download onnx` 直接挂住，HTTPS 也断），装不了 onnx / torch / onnxruntime。
所以：训练用纯 numpy（729 参数的图，CPU 2 秒练完），ONNX 用 protobuf 字段号手写，
并自带一个最小解析器做回读对拍。

解析器的正确性做了两层校验：
* 往返：自己写的文件能解析回来，且与 numpy 前向的最大概率偏差 7.7e-7；QDQ 版与独立量化实现
  的最大偏差 4.4e-16（按同一套 float32 scale 重建权重，逐位一致）；
* 交叉：同一解析器能正确读出官方 `yolo_face_uint8_15.onnx` / `fire_detect_sim_quant_uint8.onnx`
  的 opset、节点类型统计、初始张量形状与 dtype（这证明字段号/类型映射不是自说自话）。

QDQ 版的写法是**对着官方模型抄的**：`QuantizeLinear(float32) → DequantizeLinear → Conv`，
Conv 权重 uint8（非对称，zp≠0）、bias int32（scale = 输入 scale × 权重 scale）、
激活 uint8（ReLU 后 zp=0）。这是能在没有文档的情况下做到的最贴近的形态。

仍然没有做的是「用真正的 ONNX Runtime 或 armnn 解析一次」——这个只能在板上/构建机上补，
`run.sh` 的断点 1 就是干这个的。

## 7. 已验证 / 未验证清单

**已在本机验证（可复跑）**

| 项目 | 怎么验证的 | 结果 |
| --- | --- | --- |
| 数据集物理合理 | 电流不超过 2.002 A、电压不超过 48 V、故障样本 V/I/d 全 0 | 通过 |
| 模型数值正确 | 手写前向 vs ONNX 反解析执行 | 7.7e-7（float）/ 4.4e-16（QDQ） |
| ONNX 结构 | `validate_onnx.py`：拓扑序、维数、QDQ 类型逐个查 | 两个模型都通过 |
| 解析器可信 | 用同一解析器读官方 yolo / fire_detect 模型 | opset/节点/张量形状都对 |
| 量化代价 | int8/uint8 仿真 | 100%（1/360 翻转） |
| 传感器误差敏感度 | ±2%/±5% 增益、+20mA 零点、粗量化、2%/5% 噪声 | ±2% 不掉点，5% 掉 2~4pp |
| 真实数据重训路径 | 用手头 28 个窗口的旧日志跑通 `from_board_csv → train → export` | 跑通；同时验证了「缺类/样本过少」告警会正常触发（`out/retrain_dryrun.log`） |
| 板上对拍工具 | `test_compare_board_output.py`：完美输出应通过，+10% 电流读数应被判失败 | 通过（后者报 10 条类别不一致、偏差 1.0） |
| Alnpu 约束摸底 | 扫描官方 `libarmnn.so.32.1` 的符号与断言字符串 | 硬 NPU = int8 卷积引擎；NCHW；conv 通道≤4095、FC 输入通道≤2038；`pad=(k-1)/2`；`k+s≤10`（2x2/1x4 mode） |
| 补零变体 | `dcdc_npu_qdq_8x4.onnx` 与默认版对拍 | 偏差 8.9e-16，测试集同样 100% |

**未验证（需要板子/构建机）**

| 项目 | 缺什么 | 怎么补 |
| --- | --- | --- |
| C++ 能否编译 | 本机无 aarch64-linux 工具链 | VM 里 `ARMNN_DIR=... ./board/build.sh` |
| ONNX 能否被 armnn 解析 | 只能在板/构建机上跑 | `run.sh -c dcdc_board_test.csv --check` |
| Alnpu 是否接这个图 | 需要 `-b Alnpu -v` 的层分配日志 | `./evidence.sh` |
| NPU 是否真的执行 | IRQ 40 计数增量 | `./evidence.sh` |
| 真实工况识别能力 | 真实带标注数据 | `from_board_csv.py` → `train.py` |

## 8. 复现环境

* Python 3.12 + numpy（无 torch / onnx / onnxruntime）
* Windows 本机生成模型；Linux 构建机（VM，aarch64-linux-gnu 工具链）编译板端程序
* 板子：DR1M90GEG400，内核 6.1.111-rt42，硬 NPU @ 0x63F00000 / IRQ 40
