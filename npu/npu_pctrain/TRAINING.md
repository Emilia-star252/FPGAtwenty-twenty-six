# 当前数据的二分类训练

输入为电压、电流、实际占空比的 256 点窗口；输出顺序为正常 0、负载突变响应 1。当前无振荡样本。标签是波形规则初标，原数据只有三次独立阶跃，训练结果用于建立第一版流程，不能直接证明泛化能力。

## 1. 使用已安装的 GPU 训练环境

当前已确认系统 Python 3.12 安装了 PyTorch 2.11.0+cu128、NumPy 2.5.2，CUDA 可用，显卡为 NVIDIA GeForce RTX 4060 Laptop GPU（8 GiB）。脚本默认使用 CUDA，不需要重新安装 PyTorch或激活虚拟环境。在 Windows PowerShell 执行：

```powershell
Set-Location E:\FPGA_2026
python -c "import torch; print(torch.__version__); print(torch.cuda.is_available()); print(torch.cuda.get_device_name(0))"
```

当前系统 `python` 指向 `D:/python/Environment/Python312/python.exe`。CUDA 不可用时会明确报错，不会悄悄切换到 CPU。确需 CPU 可显式指定 `--device cpu`。

## 2. 检查数据并开始训练

```powershell
python fpga_prj/uisrc/07_software/npu_dataset/train_condition.py --check-data
python fpga_prj/uisrc/07_software/npu_dataset/train_condition.py --epochs 50 --batch-size 64
```

默认读取 `fpga_prj/output/npu_dataset_20261026`，GPU 输出到**新目录** `fpga_prj/output/npu_train_20261026_gpu_v1`。CPU 默认输出仍为 `fpga_prj/output/npu_train_20261026_v1`。输出目录存在时会拒绝覆盖；再次训练需加 `--output fpga_prj/output/npu_train_gpu_v2` 等新目录。

GPU 日志应出现 `CUDA_READY gpu=NVIDIA GeForce RTX 4060 Laptop GPU runtime=12.8` 和 `MODEL parameters=2914 device=cuda`。CUDA 下启用 DataLoader 锁页内存和批次非阻塞传输；在初始化 CUDA 前设置确定性 cuBLAS 工作区，并保留固定种子和确定性算子设置。训练配置记录显卡和运行时版本，指标记录 CUDA 峰值张量显存分配。小网络的总耗时仍可能受 Python/数据传输开销影响，不预设加速倍数。

脚本会校验数据集审计状态和 NPZ/清单 SHA256，检查集合之间 run 不交叉，使用训练集拟合归一化参数和类别权重。输入变换为 `[N,3,1,256]`，模型为 `Conv2D→ReLU→AveragePool→Conv2D→ReLU→AveragePool→Linear(2)`，共 2914 参数，末层输出 logits。使用 Adam、初始学习率 0.001、加权交叉熵、固定随机种子 42，最多 50 轮，验证集长期没有改善时提前停止。

按训练样本数计算的类别权重约 `[0.5071,35.7333]`，比例约 70.5:1；没有再叠加过采样。PyTorch 加权交叉熵会依据这些权重调整损失。训练时不在输出前额外加 Softmax。

以验证集宏平均 F1 选择模型；F1 相同时参考验证集无权交叉熵。测试集只在最佳模型确定后评估一次，不用于拟合参数或选轮次。归一化使用训练集三路通道的全局均值和标准差，不对每个窗口单独归一化。模型使用外部预处理，后续 PS 部署必须复用保存的数值、通道顺序与张量布局。

## 3. 查看结果

- `best.pt`：最佳模型权重、模型类型、类别映射及预处理参数。
- `preprocessing.json`：三路均值、标准差和训练集类别权重。
- `history.csv`：每轮验证指标。
- `metrics.json`：训练/验证/测试的混淆矩阵、各类别精确率/召回率/F1、宏平均 F1、突变召回率、正常窗口误报率，以及“全部判正常”的基线。
- `*_predictions.csv`：按原 run 和样本编号记录窗口预测，可回查波形。
- `training_config.json`：训练参数、环境版本和数据集 SHA256。

优先看突变召回率和正常误报率，再看宏平均 F1。普通准确率可能因正常占多数而虚高；全部判正常也会达到很高的准确率。误报率在此是**窗口级**指标，不是每小时报警次数。没有外部命令时间戳，不能从该数据宣称精确事件检测延迟。

训练后再做 ONNX 导出、静态量化和实际 `Alnpu` 后端兼容性/执行核验。此网络使用常见算子仅是候选结构，尚未证明安路后端支持当前导出图。`best.pt` 不能直接交给 NPU；PC 训练通过不代表 NPU 推理通过。

## 当前验证边界

2026-10-26 已运行 CPU 第一版，12 轮后提前停止，最佳为第 2 轮。训练集突变召回率 88.15%，验证和测试集突变召回率均为 0；测试准确率虽为 96.87%，但模型把测试窗口全部判为正常，因此该基线未达到可用条件。GPU 训练保持相同数据、结构、种子与超参数，只改变执行设备；不会因为使用显卡就改善样本覆盖和泛化能力。最终 GPU 指标以 GPU 输出目录的 `metrics.json` 为准。

官方参考：

- [PyTorch 安装选择器](https://pytorch.org/get-started/locally/)
- [PyTorch CrossEntropyLoss：类别权重与 logits](https://docs.pytorch.org/docs/stable/generated/torch.nn.CrossEntropyLoss.html)
- [PyTorch CUDA 传输与锁页内存](https://docs.pytorch.org/docs/stable/notes/cuda)

## 后续 GPU 训练：相对历史基线输入

2026-10-26 后续训练采用 `--preprocessing causal-relative --context-seconds 2`。对每个 256 点窗口，使用本次采集内窗口起点之前最多 2 秒的电压、电流、实际占空比均值作为历史基线；计算 `(x - past_mean) / max(abs(past_mean), floor)` 后，再用训练集拟合的全局均值/标准差标准化。三路分母下限依次为 1 V、0.05 A、0.05 占空比。历史不足 2 秒时使用已有历史，不使用当前窗口、未来样本或标签作为输入。

这使模型输入更侧重相对变化，减少绝对电压运行点差异。原始数据、人工实验归属、规则标签、train/validation/test 的 run 分组、256 点窗口长度、分类器结构不改动。默认参数仍兼容原全局归一化基线，因此继续这版训练时必须显式添加 `--preprocessing causal-relative`。

```powershell
python fpga_prj/uisrc/07_software/npu_dataset/train_condition.py --preprocessing causal-relative --context-seconds 2 --epochs 100 --patience 20 --seed 43 --skip-test --output fpga_prj/output/npu_train_gpu_context_new
```

开发阶段使用 `--skip-test`，候选只在训练集和验证集上评估。本轮已有种子 42 与 43 两个候选，验证集宏平均 F1 均为 1；按验证集无权交叉熵选定种子 43。该候选实际训练 51 轮、最佳为第 31 轮。训练、验证阶段没有将测试数据用于预处理拟合或选轮次。

`evaluate_selected.py` 在测试推理前记录候选、选择依据和权重 SHA256，再用选定权重评估一次测试集。最新汇总在 `fpga_prj/output/npu_train_20261026_selected_context_v1/README.md`，冻结权重为同目录 `best.pt`，配套预处理为 `preprocessing.json`。验证混淆矩阵 `[[3295,0],[0,125]]`，测试混淆矩阵 `[[3563,0],[0,115]]`；行是真值、列是预测。

上述 100% 指标只对应已有已标注窗口，不涵盖被排除的事件边界、恢复尾段、后段未确认扰动。只有三次独立阶跃，且旧全局基线曾查看同一测试集，故属于探索性结果；仍需新采独立实验和经确认标签来检验真实泛化。在线 PS 部署还必须复现历史统计；这不是简单复用旧全局归一化参数。当前尚未导出 ONNX、量化或证实 Alnpu 执行。
