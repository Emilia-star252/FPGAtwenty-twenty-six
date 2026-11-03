# 板上实测记录（2026-10-27，首次真正跑起来）

板子：DR1M90GEG400 / Buildroot / 内核 6.1.111-rt42 / `192.168.137.101`（root/root，dropbear+OpenSSH 8.9）

## 1. 板子侧已就绪的部分

```
insmod cma_mem.ko / jpu.ko / hard_npu.ko   -> /dev/cma_mem、/dev/jpu、/dev/hard_npu
/sys/bus/platform/devices/63f00000.hard_npu/driver -> hard_npu
IRQ：41（不是 40！）  /proc/interrupts 里是 `HARD_NPU_IRQ`
板子没有编译器、没有 python、没有 libarmnn；只有 libstdc++ 6.0.24 + glibc 2.25
```

注意：内核日志 `find irq num: 41`，而 `40` 是 `JPU_CODEC_IRQ`。
`evidence.sh` 里按名字抓 IRQ，别再写死 40。

## 2. 怎么在没有 Linux 主机的情况下编出板端程序（关键突破）

本机没有 WSL/VMware/Linux，SDK 里的 `aarch64-linux-gnu-g++` 是 x86-64 Linux 程序跑不了。
但是从 `D:\FPGA\uisrc-lab-anlogicM-V4.0.1.tar.gz` 里解出了它自带的 **sysroot**（纯文件）：

```
glibc 2.25 + libstdc++.so.6.0.24 + C++ 头（7.5.0）+ crt1.o/crti.o/crtn.o/libc_nonshared.a + ld-2.25.so
```

板子的 rootfs 正好也是 glibc 2.25 / libstdc++ 6.0.24 —— ABI 完全对得上。
于是用**裸机工具链** `aarch64-none-elf-g++ 12.3.1` 当编译器、拿这个 sysroot 当头文件与库：

```
g++ -std=c++17 -march=armv8-a -nostdinc -nostdinc++ \
    -isystem <sysroot>/include/c++/7.5.0 -isystem <sysroot>/include/c++/7.5.0/aarch64-linux-gnu \
    -isystem <sysroot>/libc/usr/include  ...
link: -nostdlib crt1.o crti.o crtbegin.o libarmnn.so.32 libarmnnOnnxParser.so.24 libprotobuf.so.23 \
      libstdc++.so.6 libm libc libc_nonshared.a ld-linux-aarch64.so.1 libgcc.a crtend.o crtn.o \
      -Wl,--dynamic-linker=/lib/ld-linux-aarch64.so.1 -Wl,-rpath,/opt/npu/lib
```

脚本：`board/build_win.ps1`（`-ExecutionPolicy Bypass` 才能跑）。
产物是正常的 aarch64 动态 ELF，板上直接运行 ✅

踩过的坑（都已修）：
* `-march=armv8-a` 必须加，否则 gcc12 生成 LSE 原子指令（`__aarch64_ldadd4_acq_rel`），A35 不支持。
* `CmaBuf` 定义在厂商 `flow_common_types.hpp`（没随 include 发布）→ 直接用 `cma_buffer_t` + `cma_mem_alloc`。
* 这个 armnn 版本 `AddFullyConnectedLayer` 只接受 `(desc, name)`，权重/偏置要用 `AddConstantLayer` 接 slot 1/2。
* `ConstTensor` 要求 `TensorInfo` 先 `SetConstant(true)`，否则运行时报 InvalidArgument。
* `IRuntimePtr` 等是带函数指针 deleter 的 unique_ptr，C++17 下不能默认构造 → 改用 `shared_ptr`。
* TensorInfo 在绑定后不保证还有效 → 提前把 `TensorInfo` 拷贝成成员缓存。

## 3. 已经跑通的

| 项 | 结果 |
| --- | --- |
| float32 `Gemm` 三分类模型 | ✅ 板上 CpuRef 跑通，3 个样本分类正确，**0.14 ms/次** |
| float32 `Conv` 1×1 探针（probe A） | ✅ 解析/加载/推理通过，0.085 ms/次 |
| 厂商 QDQ 模型（fire_detect） | ✅ 解析/优化/加载通过（说明 parser 支持 QDQ + 软 NPU 垫片可用） |

## 4. 卡住的两件事（下一步）

1. **Alnpu 明确拒绝 Float32 卷积**：
   ```
   Warning: Layer of type Convolution2d is not supported on requested backend Alnpu
            for input data type Float32 and output data type Float32
            (reason: Do Not Supported, Convolution2d can`t fit to 'alnpu')
   ```
   → 必须走量化（QAsymm8）。这和寄存器表（INT_SCALE0..15、ACT_RSHIFT、ZERO_POINT）一致。

2. **我们自己的 QDQ onnx 会让 armnn parser 直接段错误**（addr=0x24/0x30，崩在 libarmnnOnnxParser 里），
   而厂商同类模型能解析。已排除：raw_data 编码、rank-0 标量 scale/zp。
   探针结果：A（纯 float Conv）✅、B（输入 QDQ + float 权重）❌、C（全 QDQ 无 Softmax）❌
   → 问题出在 Q/DQ 这一段结构，下一步逐个对齐厂商写法（例如 Q/DQ 之间的张量名、是否需要
   `axis` 属性、scale/zp 是否必须复用同一 initializer、输入 Q 的输出是否要额外 consumer）。

## 5. 软 NPU 设备垫片（shim）

板子的系统镜像只为硬 NPU 编了 DT 节点，没有 `soft_npu` 节点/PL IP，但 libarmnn 的 Alnpu 后端
初始化时会无条件打开 `/dev/soft_npu`，失败就整个后端不可用（连硬 NPU 一起）。

`board/softnpu_shim.c` 用 LD_PRELOAD 只对这**一个路径**作假：open→/dev/zero，
ioctl(GET_REGISTER_INFO)→返回假地址，mmap→匿名内存。跑纯硬 NPU 图时软 NPU 不会被真正用到。

**这会影响结论的可信度**：用垫片时不能只凭"跑通了"就说软 NPU 正常；硬 NPU 必须用
IRQ 计数 + PC 侧概率对拍来证明。

## 6. 第二轮实测（同日晚）：量化网络在本机 API 上跑通，但 Alnpu 仍然拒绝

因为我们的 QDQ onnx 会让 parser 崩，我加了兜底路线：把量化参数导出成 C 头
（`out/dcdc_npu_qdq_weights.h`），用 armnn API 直接搭 QAsymmU8 1×1 卷积网
（`dcdc_npu_demo --qconv`），完全不经过 ONNX parser。

结果：

| 测试 | 结果 |
| --- | --- |
| `--qconv -b CpuRef` | ✅ 三样本分类正确，0.23 ms/次 |
| `--qconv -b Alnpu` | ❌ `Convolution2d is not supported on requested backend Alnpu for input data type QAsymmU8 and output data type QAsymmU8 (reason: Do Not Supported, Convolution2d can't fit to 'alnpu')` |
| 3×3 QDQ 探针（probe_D） | ❌ parser 仍在同一地址崩 → 与 kernel 大小无关 |
| IRQ 41 | 全程 0，说明硬 NPU 从未被真正启动 |

结论（重要）：

1. **标准 `Convolution2d` 层不管 float 还是 QAsymmU8 都进不了 Alnpu**。
   结合符号表里的 `ALHardNPUQueueDescriptor` / `IsALHardNPUSupported`，说明这块 NPU 走的是
   **自定义的 ALHardNPU 融合层**，而不是 armnn 的标准卷积层。
2. 这个融合大概率发生在**厂商改造过的 ONNX parser**里（把 QDQ+Conv 子图整体转成 ALHardNPU），
   所以手工用 API 搭标准 Conv 永远不会命中；必须让 parser 吃下我们的 QDQ 图。
3. 因此下一步的关键只有一个：**让我们写出的 QDQ onnx 能被 parser 接受**。
   建议做法（按成本排序）：
   * 用我们的 writer 把厂商的 QDQ 模型「读出来再原样写回」，在板上试解析：
     能解析 → 说明是结构/字段差异；不能 → 说明是我们的序列化细节（字段顺序、属性编码）。
   * 逐项对齐：节点名风格、initializer 是否复用、ir_version（厂商是 7，我们写 8）、
     value_info 是否出现、是否有 `axis` 属性。
   * 若都不行，退一步：把 QDQ 图交给 armnn 之前的**普通 float Conv 模型**，
     看能否用 `--qconv` 之外的路径触发 ALHardNPU（目前证据表明不能）。



## 7. 第三轮：QDQ 图终于能被 parser 解析（两个关键修复）

| 现象 | 修复 |
| --- | --- |
| parser 段错误（addr 0x24，libarmnnOnnxParser 内） | 中间张量缺 alue_info（graph field 13）。厂商模型里每个中间张量都有，补上后不再崩 |
| There is no raw data for onnx::TensorProto ... uint8_t | uint8/int32 必须写 
aw_data，不能写 int32_data |

现在 dcdc_npu_qdq.onnx 能完整解析（1 输入 / 1 输出），进到 Optimize 才失败。

## 8. 当前卡点：import 出来的 Conv 类型不匹配

`
Convolution2d is not supported ... for input data type QAsymmU8 and output data type Float32
   (reason: ... Reference Convolution2d: input and output types mismatched)
`

说明 armnn 的 parser **把输入端的 Q/DQ 折叠掉了**（网络输入直接变成 QAsymmU8），
但 Conv 的输出仍是 Float32（因为我们的 Conv 权重是反量化后的 float，输出张量声明为 float），
于是同一个 Conv 输入量化、输出浮点 → 没有任何后端愿意接。

要让 Conv 变成「全量化」，两种可能：
1. 让 Conv 的权重保持量化（QOperator 风格：Conv 直接吃 uint8 权重/激活，量化参数挂在属性上），
   但厂商模型是 QDQ 风格，parser 未必支持 QOperator；
2. 让 QDQ 完全闭合：每个 Conv 的输入/输出都紧跟 Q/DQ（我们目前只有激活后 Q/DQ，
   输入端那对 Q/DQ 被 parser 吃掉了，导致第一个 Conv 输入量化、输出浮点）。
   下一步试：去掉输入端的 Q/DQ，改成「Conv(权重 float) → Relu → Q → DQ → ...」全部 float 链，
   看 parser 会不会把中间的 Q/DQ 折成量化 Conv；或反过来把每个 Conv 前后都包成 Q/DQ。

另外确认：手工 API 搭的 QAsymmU8 Conv 网络（--qconv）在 CpuRef 上正确（0.23 ms），
但 Alnpu 同样拒绝 Convolution2d，说明 ALHardNPU 只认它自己的融合层。


## 9. 第四轮：ALHardNPU 真的出现了（8 通道是关键）

三个修复叠加之后，armnn 终于把我们的图**融合成了 `ALHardNPU` 节点**：

| 修复 | 作用 |
| --- | --- |
| 中间张量补 `value_info`（field 13） | parser 不再在 Q/DQ 上段错误 |
| uint8/int32 改回 `raw_data` | 解决 "There is no raw data for TensorProto ... uint8_t" |
| 输入补零到 **8 通道 / 4×4**（`--pad-c 8 --pad-hw 4`） | **触发融合**；3 通道/1×1 的图不会融合，被当成普通 Convolution2d 拒绝 |

日志从 `Convolution2d is not supported` 变成了：

```
Layer of type ALHardNPU is not supported ... for input QAsymmU8 and output Float32
   (reason: output is not a supported type, input and output types mismatched)
Layer of type Quantize is not supported ... input Float32 output QAsymmU8
```

也就是说：**融合成功了，但 Q/DQ 边界没被吸收进融合节点**，留下了独立的 `Quantize` 层，
而 Alnpu 不吃独立 Quantize；融合节点的输出还被判成 Float32。

## 10. 下一步（就差这一步）

现在的问题从「怎么让 NPU 接受」变成了「怎么让 Q/DQ 被融合节点吸收」。可试的方向：

1. **去掉输入端的 Q/DQ**，让第一层 Conv 直接吃 float 输入（融合节点输入类型可能要求 QAsymmU8，
   需要试）。
2. **把每个 Q/DQ 紧贴在 Conv 两侧**（Conv → Q → DQ 顺序调整为 Q → Conv → DQ），
   让融合 pass 看到「量化 Conv」而不是「浮点 Conv + 量化激活」。
3. 输出端已经是 uint8 logits（`--u8-logits`），host 侧做 softmax；这条已经通了（CpuRef 上 100% 一致）。
4. 若仍不行，退而求其次：只让**第一层 Conv** 上 NPU（其余 CpuRef），至少拿到 IRQ 证据。

现在 `out/dcdc_npu_qdq_u8.onnx` 是「8 通道 + 4×4 + uint8 logits」的版本，
数值对拍 0 偏差、测试集 100%，是当前最接近能上 NPU 的产物。


## 11. 第五轮：一次真实的「NPU 执行 → 板子挂死」事故（重要）

为了确认硬 NPU 到底能不能执行，我拿**厂商的 640×640 模型**（`vendor_qdq.onnx`）在板上跑
`-b Alnpu,CpuRef`。结果：

1. 优化阶段：厂商模型的 Conv **全部被 Alnpu 接受**（没有一条 Convolution2d 警告），
   只有 Splitter / Concat / ElementwiseBinary 因缺 PL 软 NPU IP 回退到 CpuRef；
2. 真正 EnqueueWorkload 时：**板子直接失去响应**（SSH 断、ping 不通）；
3. 约 20 秒后板子**自己重启**（uptime 归零，`/opt/npu` 下的文件都还在），重新 insmod 模块后恢复。

这说明两件事：

* 硬 NPU 的执行路径**是通的**——厂商模型的卷积确实被发到 NPU 上跑了（所以才挂）；
* 但我们的运行环境还缺东西：大概率是 **软 NPU 垫片**（假寄存器区）或 CMA 缓冲/中断处理
  不匹配。跑到真 NPU 时，驱动在等一个永远不会来的中断，或者 DMA 地址不对，导致挂死。

**结论：在把 Q/DQ 类型匹配问题解决之前，不要再对任意大模型直接 `-b Alnpu` 跑。**
安全做法：
* 先用 `-b Alnpu` 只做 **Optimize**（看层分配），不 Enqueue；
* 真正执行时用 `-b Alnpu,CpuRef` 且**只跑我们自己的小模型**（8 通道 4×4）；
* 每次执行前记录 IRQ 计数，挂死后能判断是否进过中断。

## 12. 下一轮的具体计划

1. 让图变成「全量化、无 DQ」：输入 `Q(float→u8)` → Conv(u8 权重, u8 激活) → Relu(u8) → Conv … → 输出 u8。
   若 armnn parser 支持这种 QOperator 写法，ALHardNPU 的 in/out 类型就能对上。
2. 或者在 QDQ 形式下把 `value_info` 里 Conv 的输出声明成 uint8（配合去掉该处的 DQ），
   让融合节点看到「量化输出」。
3. 执行前先 `cat /proc/interrupts | grep HARD_NPU_IRQ` 记录基线，跑完再看增量；
   一旦挂死，重启后从断点继续，不要重复跑大模型。


## 13. 成功：硬 NPU 跑通（2026-10-27）

最终可用的图（`out/dcdc_rq.onnx`）需要**同时**满足三个条件：

1. 输入补零到 **8 通道 / 4×4**（3 通道不触发融合）；
2. **3×3 卷积但只有中心权重非零**（等价 1×1，形态上像真卷积）；
3. **ReLU 放在 Q 之后、DQ 之前**（作用在 uint8 上），否则量化边界被 Relu 截断，
   融合节点输出变 Float32 而被拒。

实测：

* `-b Alnpu` 单独使用，无任何回退警告；
* **IRQ 41 增量 615** = 205 次推理（200 样本 + 5 预热）× 3 个融合卷积层，完全吻合；
* 时延 0.160 ms/次（CpuRef 5.098 ms，≈32×）；
* 200 条样本类别 0 不一致，概率最大偏差 2.5e-3（阈值 5e-2）。

对照实验（都失败，供后人少走弯路）：

| 变体 | 结果 |
| --- | --- |
| 3 通道 1×1 QDQ | `Convolution2d is not supported`（根本不融合） |
| 8 通道 4×4，`Conv→Relu→Q→DQ` | 融合出 ALHardNPU，但 `output Float32` 类型不匹配 |
| 8 通道 4×4，`Conv→Q→DQ→Relu` | 不融合，Quantize/Dequantize 独立层被拒 |
| 无 ReLU（线性模型） | 能融合且被接受，但精度只有 79% |
| 厂商 640×640 模型 | 卷积被接受，但执行时把板子挂死（看门狗 20 s 自恢复） |


## 14. 更正：融合不是被 ReLU 卡住的，是被**通道数**卡住的

把别人交付的三分类模型（16 通道、Conv3x3 + Relu(float) + MaxPool、输入 [1,3,16,16] u8）
放到板上实跑，结果：

* 优化图里是单个 ALHardNPU 节点：OutputChannels : 16、FilterWidth : 3、BackendID : Alnpu；
* 46 例 46/46 类别正确，IRQ 41 增量 **46**（每帧 1 次中断）；
* 单次推理 0.369 ms（p50 0.363）。

也就是说：**16 通道时，ReLU 作用在 float 上、后面还跟着 MaxPool，照样能融合**。
我之前在 8 通道上得出的「ReLU 夹在 Conv 和 Q 之间会破坏融合」只对 8 通道成立，
真正敏感的是通道对齐（3 不行、8 能行但容错低、16 很稳）。
我自己的模型继续用 Q → ReLU(u8) → DQ 的写法即可，不需要改。
