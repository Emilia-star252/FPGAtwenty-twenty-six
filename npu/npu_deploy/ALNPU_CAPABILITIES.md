# Alnpu 后端能力摸底（从官方 `libarmnn.so.32.1` 里捞出来的）

SDK 没有 NPU 文档，但 Alnpu 后端是**编译进 `libarmnn.so.32.1`** 的，符号名和断言字符串都留着。
用 `inspect_alnpu.py` 只读扫描，得到下面这些结论。**这是逆向推断，不是厂商承诺**——
真伪最终要靠板上 `-b Alnpu -v` 的日志验证。

## 1. 后端结构（符号名）

```
armnn::AlnpuBackend                  ← 注册名就是 "Alnpu"
armnn::AlnpuWorkloadFactory
armnn::AlnpuLayerSupport
armnn::AlnpuMemoryManager
armnn::AlnpuTensorHandleFactory
armnn::AlnpuBackendContext
```

分两类执行体：

| 类 | 作用 | 证据 |
| --- | --- | --- |
| `AlnpuALHardNPUWorkload` | **硬 NPU**（0x63F00000）执行体 | 符号 `r_HardNPUDriver`、`FillHardDriverData`、`Split`、`infer_tiles_shpae`、`/dev/hard_npu`、`wait_for_hard_npu_irq` |
| `AlnpuConcatWorkload` / `AlnpuPooling2dWorkload` / `AlnpuPreluWorkload` / `AlnpuResizeWorkload` / `AlnpuConstantWorkload` / `AlnpuYoloPostProcess` | **软 NPU**（PL 里的逻辑） | 符号 `r_SoftNPUConcatDriver`、字符串 `PL(Programmable Logic) Not Support RESIZE` |

`AlnpuLayerSupport` 只对外暴露这几个 `Is*Supported`：
`IsInputSupported / IsOutputSupported / IsMemoryCopySupported / IsConstantSupported /
IsConcatSupported / IsPooling2dSupported / IsPreluSupported / IsResizeSupported /
IsALHardNPUSupported`。

**含义**：优化器会把能塞进硬 NPU 的子图整体融合成一个 `ALHardNPU` 节点
（`OptimizeSubgraphView` + `Split` + tile 切分），而不是逐层 dispatch。
所以「某个算子支不支持」取决于那个融合 pass，不是逐层的 `IsXXXSupported`。

## 2. 硬 NPU 是整数卷积引擎（寄存器表）

字符串里直接有寄存器名，说明它是定点/整数流水：

```
HARDNPU__FM_SIZE / FM_PLANE / FILTER_SIZE / KERNAL_SIZE / GRID_PAD / GRID_SIZE / TILE_*
HARDNPU__INPUT_FM_ZERO_POINT / INPUT_FILTER_ZERO_POINT
HARDNPU__INT_SCALE0..15 / UINT_SCALE
HARDNPU__ACT_SCALE / ACT_ZERO_POINT_OUTPUT / ACT_RSHIFT / ACT_POOLING_EN
HARDNPU__WORK_MODE / RAM_SCALING_PARAM / RAM_BIAS_PARAM / ADD_BIAS_EN
HARDNPU__INTERRUPT_STATUS / WAIT(irq) / HARDNPU__CRASHED...
```

有 `INT_SCALE0..15`、`INPUT_FM_ZERO_POINT`、`ACT_SCALE`、`ACT_RSHIFT` → **它就是 int8/uint8 量化卷积**，
支持每层一个 scale（16 个 scale 寄存器）和激活量化。这解释了为什么官方两个模型都是 QDQ + uint8 权重。

## 3. 能看到的形状/参数约束（原文照抄）

```
the channel of conv input is not lesser or equal to 4095
the channel of FC input is not lesser or equal to 2038
the kernel_h and the kernel_w mismatched
the kernel_h size of is not supported
the stride_x size is not supported
hardware not support these pad
the pad is not equal to (kernel_size-1)/2
kernel_w and stride_w are not obey the rule k + s <= 10 in 2x2 mode
kernel_w and stride_w are not obey the rule k + s * 3 <= 10 in 1x4 mode
the pool input dataLayout is not NCHW
Invalid number of ALHardNPU TensorInfos. TensorInfos should be of format: {input, output, weights, biases}.
```

解读：

| 约束 | 对我们的影响 |
| --- | --- |
| **NCHW** | 我们导出的是 NCHW ✓ |
| conv 输入通道 ≤ 4095、FC 输入通道 ≤ 2038 | 3/32/16 远小于上限 ✓ |
| `pad == (kernel-1)/2` | 1×1 卷积 → pad=0 ✓（3×3 就要 pad=1） |
| kernel/stride 的「2x2 / 1x4 mode」规则 `k+s<=10` | 1×1、stride 1 不触发 ✓ |
| 有 FC 的执行消息 | **全连接也是支持的**（可能被当成 1×1 卷积执行） |

**没有找到**：最小空间尺寸、通道是否必须 4/8/16 对齐、tile 尺寸下限。这几项只能上板试。

## 4. 对我们模型的两个判断

1. **float32 `Gemm` 图大概率不会进硬 NPU**：硬 NPU 是整数引擎，`AlnpuALHardNPUWorkload::get_quant_info`
   说明它要量化信息。所以 `dcdc_npu.onnx`（float）当 CPU 参照，不要指望它上 NPU。
2. **QDQ + 1×1 Conv 是对的方向**，但仍有两个未知：3 通道是否够（NPU 可能按 4/8 对齐取数）、
   1×1 空间是否被 tile 逻辑接受。为此我额外导出了补零变体：
   `out/dcdc_npu_qdq_8x4.onnx`（输入 `[1,8,4,4]`，只有前 3 通道的 (0,0) 位置有数据）。
   数学上与原模型完全等价（补零通道权重也是 0），对拍偏差 8.9e-16，测试集同样 100%。

## 5. 上板时的判定顺序

1. `run.sh -m dcdc_npu_qdq.onnx -b Alnpu -v` → 看 `ALHardNPU` 是否被创建、有没有 `Split` 失败
2. 若报形状/通道不支持 → 换 `dcdc_npu_qdq_8x4.onnx` 再试
3. 两者都被拒 → 抓日志里的断言原文（上面那些句子会出现在 stderr），按它给的具体限制改造
4. 成功 → `evidence.sh` 收 IRQ 40 增量 + 时延，用 `compare_board_output.py --tol 5e-2` 对拍概率

## 6. 复现方法

```powershell
py inspect_alnpu.py                    # 汇总：alnpu 字符串 / 层类型 / 约束消息
```

原始库位置：`_sdk/app/face_detection/libs/armnn_lib/lib/libarmnn.so.32.1`（38 MB，从官方 SDK tar 里解出）。
