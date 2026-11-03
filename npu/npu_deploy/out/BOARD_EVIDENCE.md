# 板上 NPU 实测证据（2026-10-27）

**结论：DC-DC 工况识别模型已经在 DR1M90 的硬 NPU 上跑通，并拿到了硬件执行证据。**

## 1. 最终可用的模型

`out/dcdc_rq.onnx` —— 由下面这条命令生成（同一份训练权重）：

```
py export_onnx_qdq.py --model out/model.npz --csv out/dataset.csv --outdir out \
   --name dcdc_rq --pad-c 8 --pad-hw 4 --kernel 3 \
   --q-after-conv --relu-on-quant --u8-logits
```

它和训练模型的数学等价性已验证：

* 与独立量化实现的最大概率偏差 **0.000e+00**
* 测试集准确率 **100.00%**（float 模型 99.72%）
* 与 float 模型类别一致率 99.72%

三个关键设计（缺一不可，都是踩出来的）：

| 设计 | 作用 |
| --- | --- |
| 输入补零到 **8 通道 / 4×4** | 3 通道 / 1×1 的图不会触发 ALHardNPU 融合，会被当普通 Convolution2d 拒绝 |
| **3×3 卷积、只有中心权重非零** | 数学上等价于 1×1，但满足 NPU 对「卷积」的形态预期 |
| `Q → Relu(u8) → DQ`（ReLU 作用在量化张量上） | ReLU 夹在 Conv 和 Q 之间会截断量化边界，融合节点输出变 Float32 而被拒 |

## 2. 执行证据

| 证据 | 数值 |
| --- | --- |
| 后端 | `-b Alnpu`（只给 Alnpu，无回退警告） |
| **IRQ 41 `HARD_NPU_IRQ` 增量** | **615**（200 样本 + 5 次预热 = 205 次推理 × 3 个融合卷积层 = 615，完全对得上） |
| 单次推理时延（Alnpu） | mean **0.160 ms**，p50 0.158 ms，min 0.141，max 0.246 |
| 单次推理时延（CpuRef） | mean **5.098 ms**，p50 5.058 ms |
| 加速比 | **≈32×** |
| 板端 vs PC 结果 | 200 条：类别不一致 **0**，概率最大偏差 **2.5e-3**（阈值 5e-2） |
| 板端 vs 标签 | `--check` 0 条不一致 |

原始文件在 `board/evidence/`：`summary.txt`、`alnpu.log`、`cpuref.log`、`board_out.csv`。

## 3. 复现步骤

```sh
# 板上
insmod /opt/npu/ko/cma_mem.ko && insmod /opt/npu/ko/jpu.ko && insmod /opt/npu/ko/hard_npu.ko
export LD_LIBRARY_PATH=/opt/npu/lib
export LD_PRELOAD=/opt/npu/lib/libsoftnpu_shim.so     # 本镜像没有 soft_npu 设备树节点，见 BOARD_FINDINGS.md
cd /opt/npu/dcdc
./dcdc_npu_demo -m dcdc_rq.onnx -b Alnpu -c dcdc_board_test.csv --check
```

## 4. 必须说明的局限

1. **软 NPU 是假的**：板子的系统镜像只编了硬 NPU 的 DT 节点，libarmnn 初始化时却要打开
   `/dev/soft_npu`。`libsoftnpu_shim.so` 只对这一个路径作假（open→/dev/zero、ioctl→假寄存器、
   mmap→匿名内存）。**本结果只证明硬 NPU 工作**，软 NPU（Concat/Pooling/Resize/YOLO 后处理）没有验证。
2. 输入是 **8 通道 / 4×4 补零**，所以板上程序要把 3 个特征写进前 3 个通道的 (0,0)，其余补 0
   （`dcdc_npu_demo` 已按 shape 自动处理）。
3. 训练数据是**物理仿真**的，99.72%/100% 只证明链路和数值正确，不代表真实工况识别能力；
   真实采样到位后用 `from_board_csv.py` + `train.py` 重训，导出命令不变。
4. 用厂商 640×640 模型直接在 NPU 上跑曾把板子挂死（看门狗 20 s 后自恢复），
   所以大模型不要盲跑，先用 `--optimize-only` 看层分配。
