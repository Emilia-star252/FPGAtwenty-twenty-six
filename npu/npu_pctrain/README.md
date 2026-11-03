# DCDC 数据集准备：解码、标注、分组与组窗

仅完成训练前的前三步。适用于当前 9 次 P481 实测采集，包含 6 次稳态和用户确认的 3 次负载阶跃。依赖 Python 3.10+、NumPy，以及相邻 `adc_fdma_capture/decode_capture.py`。

当前结果：`E:/FPGA_2026/fpga_prj/output/npu_dataset_20261026/review.html`。

## 文件与标注

- `csv/`：9 组原始采样率波形 CSV 和元数据；包含 `run_id,sample_index,time_s,vout_v,iout_a,duty,class_id`。
- `labels/`：每条记录的样本区间标签，左闭右开。0 正常，1 负载突变响应，未覆盖样本为 -1。
- `evidence/`：完整性、基线、规则阈值、事件范围、排除情况和工况分组依据。
- `plots/`、`review.html`：波形与标签可视审阅；灰色区域不参与训练。图中 10 ms 均值仅用于显示，实际组窗保留原始 25 kHz 数据。
- `windows/{train,validation,test}.npz`：已按独立记录分组的窗口。
- `window_index.csv`：每个窗口的来源记录、起止样本和类别，可追溯到原始 bin。
- `config.json`、`manifest.json`：配置、分组、计数、限制及原始文件 SHA256。
- `validation.json`、`checksums.json`：核验结果与派生文件 SHA256。

标签是**波形规则推导的第一版**，不是独立人工确认的命令边沿真值。用户确认了实验类型，原始采集中没有外部负载命令时间戳。类别 1 只覆盖主阶跃明显压降响应的内部；边界、恢复尾段及后来未确认的扰动保持 -1。36 V 后段额外扰动没有自动归类。首次主响应以 10 ms 均值偏离前基线 2% 的簇确定，桥接不超过 100 ms 的短间断；内部两端各缩进 20 ms，事件前保留 200 ms 空白；事件后依据三路最终稳态阈值及 250 ms 余量恢复正常标签。所有规则可在配置文件中审阅。

主事件具体标签会侧重“负载突变引起的异常响应”，不能将此标签直接用作全部负载命令的真值或精确检测延迟依据。普通纹波或响应中的多次波动没有被当成“振荡”类别。当前没有类别 2 样本。

## 分组与窗口

固定先分组后切片，训练/验证/测试分别为 5/2/2 次完整采集。24 V 阶跃用于训练，36 V 阶跃用于验证，48 V 阶跃用于测试，各集合均同时保留稳态记录。每条记录只属于一个集合，原始内容重复也会报错；禁止把相邻重叠窗口随机分散到三个集合。

窗口长度 256 点（10.24 ms），步长 128 点（5.12 ms），从每条记录的样本 0 对齐。只有全部 256 点都为同一个已知标签才保留。窗口不跨记录，也不跨类别边界或未标注区域。每条采集首尾各 100 ms 不使用。无法填满末尾窗口的余数丢弃。

`X` 形状为 `[窗口数,256,3]`、float32，通道顺序为 `[Vout(V),Iout(A),duty(0..1)]`。`y` 是 int64 的 0 或 1，另有 `run_id/start_sample/end_sample/feature_names/sample_rate_hz`。不使用 pickle 对象、不归一化、不平衡采样、不量化。后续训练的归一化参数和类别权重只能从训练集计算。训练标签已经明显不平衡，后续需要处理。

```python
import numpy as np
data = np.load("E:/FPGA_2026/fpga_prj/output/npu_dataset_20261026/windows/train.npz", allow_pickle=False)
X, y = data["X"], data["y"]
print(X.shape, np.bincount(y))
```

只有三次独立阶跃，窗口数量不能视为独立实验数量。不同电压的阶跃分散在三个集合，验证和测试同时存在工况差异；当前切分适合建立第一版流程，不能代表可靠泛化结论。10.24 ms 内的缓慢变化也可能不足以区分动态阶段，后续应比较长窗口并增加同工况重复实验。

## 复现与核验

在工作区根目录执行，下列 output 必须是尚不存在的新目录；现有输出不会被覆盖：

```powershell
python fpga_prj/uisrc/07_software/npu_dataset/prepare_dataset.py --records fpga_prj/output/fdma_capture_20261025/records --output fpga_prj/output/npu_dataset_new
python fpga_prj/uisrc/07_software/npu_dataset/verify_dataset.py fpga_prj/output/npu_dataset_new
python fpga_prj/uisrc/07_software/npu_dataset/test_preparation.py
```

`verify_dataset.py` 逐帧比较 CSV 与原始 P481 解码，逐窗口核对 NPZ 所有数值、来源和标签，检查窗口无缺失/重复、分组无交叉、清单一致及 CRC/SHA。核验 PASS 证明数值、规则及分组一致，不代替人工标签确认、ADC 标定或硬件时间戳。审计脚本会刷新派生目录内的校验报告；不修改原始数据。

本阶段没有安装训练依赖、训练网络、导出 ONNX、量化、修改 PL 或下载板卡。
