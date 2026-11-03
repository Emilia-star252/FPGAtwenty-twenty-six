# DCDC ONNX 导出与 UINT8 QDQ 转换

本阶段完成电脑端格式转换、校准和数值一致性验证。板端解析、严格 Alnpu 分配和实际推理分别记录；解析成功不能替代实际 NPU 执行证据，当前状态见 compatibility.json。

### 板端解析反馈与 shape 完整化

2026-10-26 用户的 15 图隔离测试表明：原始 FP32/QDQ 均在模型解析阶段段错误；补全 value_info 后，两个完整图都通过解析与绑定检查。官方原模型、单卷积及包含 Gemm 的各层前缀也能解析。因此本导出流程已在浮点导出后、QDQ 插入后分别补全中间张量形状，并检查节点、权重和外部输入/输出没有改变。默认新目录为 npu_onnx_20261026_v2_shapes，保留旧图用于问题追溯。

该证据说明这些图的 shape 元数据完整性影响当前官方解析器；未取得解析器内部调用栈，不能据此断言其确切实现缺陷。通过解析仍不代表 Optimize、严格 Alnpu 分配或实际推理通过。板端下一步使用已通过解析的完整 inferred QDQ 图执行四组 golden 输入。

后续板端测试已进入 Optimize，但当前图被严格 Alnpu 拒绝：日志包含 Convolution2d、Float32 Activation、AveragePool/非方形池化核与步长、Reshape、Quantize/Dequantize 不支持，最终 Failed to assign a backend to each layer。因此当前 1x5 卷积加矩形平均池化的候选模型尚不能作为硬件可用模型部署，未进入 LoadNetwork/EnqueueWorkload。下一步先用官方量化块的方形卷积/最大池化与不同 I/O 类型探针确定支持组合，再适配网络及训练/量化流程。不能把打开 CPU 回退称为解决了严格 NPU 执行问题。

## 模型与输入

- `condition_fp32.onnx`：固定输入 `[1,3,1,256]`、float32，输出 `[1,2]` logits；类别顺序正常 0、负载突变响应 1。
- `condition_uint8_qdq.onnx`：Conv/Gemm 采用 UINT8 静态 QDQ 量化；其余算子保持原图语义。**外部输入/输出仍是 float32**，不能把原始电压电流直接转 uint8 后输入，也不能在浮点模型输入前重复执行内部量化。
- `preprocessing.json`、`causal_features.py`：输入必须先按训练时的三路历史相对变化与均值/标准差处理。当前模型不是单个窗口归一化；需要同一采集的过去最多 2 秒历史，历史区间不包含当前窗口或未来样本。

原始单位为电压 V、电流 A、实际占空比 0..1。计算 `relative=(x-past_mean)/max(abs(past_mean),floor)`，三路 floor 为 `[1 V,0.05 A,0.05]`；再用保存的训练均值和标准差标准化，从 `[256,3]` 转为 `[1,3,1,256]`。没有历史时不能直接复用该模型，已有训练窗口最少有约 100 ms 历史。

## 来源与校准

权重来自冻结的 `npu_train_20261026_selected_context_v1/best.pt`。本地官方示例 `yolo_face_uint8_15.onnx` 已检查为 IR7/opset14、FLOAT 外部 I/O、内部 UINT8 QDQ，因此导出选择 opset14 和同类量化格式。相同格式不等于同一后端可执行：当前 CNN 的 AveragePool、Flatten、Gemm、height=1 张量等都仍需核验。

校准仅使用训练集合：每条训练记录最多 128 个均匀分布的正常窗口，以及全部训练突变窗口。完整索引见 `calibration_windows.csv`。MinMax、逐张量 UINT8 激活/权重；验证和测试数据不参与校准。

## 如何查看结果

- `conversion_report.json`：PyTorch、浮点 ONNX、QDQ ONNX 的验证/测试指标，以及 logits 误差、预测分歧数、版本、图节点和文件 SHA256。
- `*_conversion_predictions.csv`：每个已有已标注窗口的三种预测，可追溯到原 run 和起始样本。
- `golden_vectors/`：4 组已标注测试窗口，用于之后的板端输入和结果比对。`physical_f32.bin` 是 `[256,3]` 的物理量，`input_f32.bin` 是 `[1,3,1,256]` 的已预处理输入；均为小端 float32。`vectors.json` 包含历史均值和两份 ONNX 的参考输出。
- `compatibility.json`：明确列出尚未完成的板端核验。

这些指标仅针对现有规则初标窗口。只有三次独立阶跃，且同一测试集已被旧模型查看，转换对比不构成新的独立盲测或真实工况泛化证明。未标注的边界、恢复尾段和额外扰动没有作为正常类别参与这些指标。

## 下一层：板端文件推理

先使用已经处理好的 golden input，建立不依赖实时采样的最小 Arm NN 文件推理程序。按官方 `CreateNetworkFromBinaryFile → Optimize → LoadNetwork → 输入/输出张量绑定 → EnqueueWorkload` 流程加载候选模型；限制后端为 `Alnpu`，记录不支持的层/形状，读取实际 runtime tensor 类型和 scale/offset，确认没有 CpuAcc/CpuRef 回退。单靠模型文件或设备节点存在不能证明 NPU 执行。

如果解析/严格后端失败，应保留错误和不支持节点，针对后端调整导出图或网络后重新训练/校准；不能宣称这个模型已可上板。通过文件推理和 golden vectors 比对后，再把 FDMA 数据接到 PS 历史统计、组窗、预处理和推理，继续验证采样连续性与推理延迟。

## 复现

在工作区根目录执行，输出目录必须是新的：

```powershell
python fpga_prj/uisrc/07_software/npu_dataset/export_quantize.py --output fpga_prj/output/npu_onnx_new
```

依赖 `numpy/torch/onnx/onnxruntime/protobuf/ml_dtypes/flatbuffers/packaging`。ONNX 相关依赖本次安装在工作区 `fpga_prj/tmp/npu_onnx_python_deps`，脚本自动添加到当前进程的模块路径，不修改全局 PyTorch。工具链版本见结果报告；导出为兼容本地旧版示例的明确 `dynamo=False,opset_version=14` 路径。

参考：[PyTorch ONNX 导出](https://docs.pytorch.org/docs/stable/onnx)、[ONNX Runtime 静态量化](https://onnxruntime.ai/docs/performance/model-optimizations/quantization.html)。
