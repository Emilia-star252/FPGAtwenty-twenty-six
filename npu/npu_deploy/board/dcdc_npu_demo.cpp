/*
 * dcdc_npu_demo.cpp —— 在 DR1M90 的硬 NPU 上跑 DC-DC 工况分类模型（3 输入 / 4 类）
 *
 * 输入: Vout(V), Iout(A), duty(%)   输出: 4 类概率 + 类别 + 单次推理耗时
 *
 * 两种加载方式：
 *   默认        -m dcdc_npu_qdq.onnx   走 armnnOnnxParser（推荐）
 *   --weights   用 dcdc_npu_weights.h   在 armnn 里直接搭 FullyConnected（ONNX 解析失败时兜底）
 *
 * 后端：-b Alnpu,CpuRef（默认）；只测 CPU 用 -b CpuRef
 *
 * 板端依赖：libarmnn.so.32 / libarmnnOnnxParser.so.24 / libprotobuf.so.23 + /dev/hard_npu
 *
 * 注意：厂商的 CmaBuf 定义在 flow_common_types.hpp（未随 SDK 的 include 一起发布），
 *       这里直接用 cma_buffer_t + cma_mem_alloc，行为一致但不依赖那个头。
 */

#include <algorithm>
#include <execinfo.h>
#include <signal.h>
#include <ucontext.h>
#include <ucontext.h>
#include <unistd.h>
#include <chrono>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <cstdlib>
#include <fstream>
#include <iostream>
#include <memory>
#include <sstream>
#include <string>
#include <vector>

#include "armnn/Descriptors.hpp"
#include "armnn/INetwork.hpp"
#include "armnn/IRuntime.hpp"
#include "armnn/Logging.hpp"
#include "armnn/Tensor.hpp"
#include "armnn/BackendId.hpp"
#include "armnnOnnxParser/IOnnxParser.hpp"
#include "armnnALUtils/cma_mem.hpp"
#include "armnnALUtils/cma_mem_init.hpp"

#ifdef DCDC_USE_WEIGHTS_HEADER
#include "dcdc_npu_weights.h"
#endif

// 量化版权重头（export_onnx_qdq.py 生成）：用 armnn API 直接搭 QAsymmU8 卷积网，
// 绕开 armnnOnnxParser 解析我们手写 QDQ 图的崩点。
#if __has_include("dcdc_npu_qdq_weights.h")
#include "dcdc_npu_qdq_weights.h"
#define HAVE_QCONV 1
#endif

namespace {

const char *kClasses[4] = {"light", "rated", "heavy", "fault"};

// 模型输入是归一化后的 u = raw / div（与导出脚本、JSON 里的 divisors 一致）
const float kInDiv[3] = {48.0f, 2.2f, 95.0f};

double now_ms() {
    using namespace std::chrono;
    return duration_cast<duration<double, std::milli>>(steady_clock::now().time_since_epoch()).count();
}

std::vector<std::string> split(const std::string &s, char sep) {
    std::vector<std::string> out;
    std::string cur;
    std::istringstream ss(s);
    while (std::getline(ss, cur, sep)) {
        if (!cur.empty()) out.push_back(cur);
    }
    return out;
}

using CmaBufPtr = std::shared_ptr<cma_buffer_t>;

CmaBufPtr alloc_cma(size_t bytes) {
    auto b = std::make_shared<cma_buffer_t>(static_cast<uint32_t>(bytes));
    if (cma_mem_alloc(b.get()) != 0 || b->phys_addr == 0) {
        throw std::runtime_error("cma_mem_alloc failed");
    }
    return b;
}

/** 最小执行器：解析/搭图 -> 优化 -> 加载 -> 绑定 CMA 缓冲。 */
class MiniExecutor {
public:
    MiniExecutor(const std::string &model, const std::vector<armnn::BackendId> &backends, bool verbose,
                 bool qconv = false) {
        armnn::ConfigureLogging(true, verbose, verbose ? armnn::LogSeverity::Info : armnn::LogSeverity::Error);

#ifdef HAVE_QCONV
        if (qconv) {
            fprintf(stderr, "[stage] build quantized conv network (API)\n");
            m_net = build_network_quant_conv();
        } else
#endif
        {
#ifdef DCDC_USE_WEIGHTS_HEADER
            m_net = model.empty() ? build_network_from_header() : parse_onnx(model);
#else
            fprintf(stderr, "[stage] parse onnx\n");
            m_net = parse_onnx(model);
#endif
        }

        cache_infos();      // 不管哪条路径搭的网，都在这里统一缓存输入/输出 TensorInfo
        if (m_outInfo.GetDataType() != armnn::DataType::Float32) m_outLogits = true;   // 量化图输出 uint8 logits

        fprintf(stderr, "[stage] create runtime\n");
        static armnn::IRuntime::CreationOptions rtOpts;
        if (getenv("DCDC_NO_CMA") == nullptr) { rtOpts.m_CustomAllocatorMap["CpuAcc"] = rtOpts.m_CustomAllocatorMap["CpuRef"] = std::shared_ptr<armnn::ICustomAllocator>(new armnn::CmaAllocator); }
        m_runtime = armnn::IRuntime::Create(rtOpts);
        if (!m_runtime) throw std::runtime_error("IRuntime::Create failed (cma_mem 驱动加载了吗？)");

        fprintf(stderr, "[stage] optimize\n");
        static armnn::OptimizerOptionsOpaque optOpts;
        optOpts.SetImportEnabled(true);
        optOpts.SetExportEnabled(true);
        auto optNet = armnn::Optimize(*m_net, backends, m_runtime->GetDeviceSpec(), optOpts);
        if (!optNet) throw std::runtime_error("Optimize failed");

        fprintf(stderr, "[stage] load network\n");
        static armnn::INetworkProperties props(false, armnn::MemorySource::Malloc, armnn::MemorySource::Malloc);
        std::string err;
        if (m_runtime->LoadNetwork(m_netId, std::move(optNet), err, props) != armnn::Status::Success) {
            throw std::runtime_error("LoadNetwork failed: " + err);
        }

        for (auto &info : m_inputInfos) {
            fprintf(stderr, "[stage] alloc input %u B\n", m_inInfo.GetNumBytes());
            m_inBufs.push_back(alloc_cma(m_inInfo.GetNumBytes()));
            m_inTensors.push_back({info.first, armnn::ConstTensor(m_inInfo, m_inBufs.back()->virt_addr)});
        }
        for (auto &info : m_outputInfos) {
            fprintf(stderr, "[stage] alloc output %u B\n", m_outInfo.GetNumBytes());
            m_outBufs.push_back(alloc_cma(m_outInfo.GetNumBytes()));
            m_outTensors.push_back({info.first, armnn::Tensor(m_outInfo, m_outBufs.back()->virt_addr)});
        }
        fprintf(stderr, "[stage] bind done\n");

    }

    void describe() const {
        fprintf(stderr, "[stage] describe start\n");
        for (size_t i = 0; i < m_inputInfos.size(); ++i) {
            const auto &t = m_inInfo;
            fprintf(stderr, "[npu] 输入[%zu] %s shape=", i, i < m_inputNames.size() ? m_inputNames[i].c_str() : "?");
            for (unsigned d = 0; d < t.GetShape().GetNumDimensions(); ++d) fprintf(stderr, "%u ", t.GetShape()[d]);
            fprintf(stderr, "type=%d bytes=%u scale=%f zp=%d\n", (int)t.GetDataType(), t.GetNumBytes(),
                   t.GetQuantizationScale(), t.GetQuantizationOffset());
        }
        for (size_t i = 0; i < m_outputInfos.size(); ++i) {
            const auto &t = m_outInfo;
            fprintf(stderr, "[npu] 输出[%zu] %s shape=", i, i < m_outputNames.size() ? m_outputNames[i].c_str() : "?");
            for (unsigned d = 0; d < t.GetShape().GetNumDimensions(); ++d) fprintf(stderr, "%u ", t.GetShape()[d]);
            fprintf(stderr, "type=%d bytes=%u scale=%f zp=%d\n", (int)t.GetDataType(), t.GetNumBytes(),
                   t.GetQuantizationScale(), t.GetQuantizationOffset());
        }
        fprintf(stderr, "[npu] 输入通道=%u 空间=%u，输出空间=%u\n", m_inChannels, m_inSpatial, m_outSpatial);
        fflush(stdout);
    }

    /** 写 3 个输入并跑一次。x 是原始物理量，内部做归一化。 */
    bool infer(const float x[3], float probs[4], double *elapsed_ms = nullptr) {
        const float u[3] = {x[0] / kInDiv[0], x[1] / kInDiv[1], x[2] / kInDiv[2]};
        auto &in = m_inBufs[0];
        const auto &it = m_inInfo;

        if (it.GetDataType() == armnn::DataType::Float32) {
            float *dst = static_cast<float *>(in->virt_addr);
            std::fill(dst, dst + in->size / sizeof(float), 0.0f);   // 补零通道/补零空间必须为 0
            for (unsigned c = 0; c < 3 && c < m_inChannels; ++c) {
                dst[c * m_inSpatial] = u[c];
            }
        } else {
            const float scale = it.GetQuantizationScale();
            const int zp = it.GetQuantizationOffset();
            auto *dst = static_cast<unsigned char *>(in->virt_addr);
            std::memset(dst, 0, in->size);
            for (unsigned c = 0; c < 3 && c < m_inChannels; ++c) {
                long q = lround(u[c] / scale) + zp;
                dst[c * m_inSpatial] = (unsigned char)std::max(0L, std::min(255L, q));
            }
        }
        cma_mem_sync_for_device(in->phys_addr, in->size);

        const double t0 = now_ms();
        auto st = m_runtime->EnqueueWorkload(m_netId, m_inTensors, m_outTensors);
        const double t1 = now_ms();
        if (st != armnn::Status::Success) return false;
        if (elapsed_ms) *elapsed_ms = t1 - t0;

        auto &out = m_outBufs[0];
        cma_mem_sync_for_cpu(out->phys_addr, out->size);
        const auto &ot = m_outInfo;
        if (ot.GetDataType() == armnn::DataType::Float32) {
            const float *src = static_cast<const float *>(out->virt_addr);
            for (int i = 0; i < 4; ++i) probs[i] = src[i * m_outSpatial];
        } else {
            const float scale = ot.GetQuantizationScale();
            const int zp = ot.GetQuantizationOffset();
            const unsigned char *src = static_cast<const unsigned char *>(out->virt_addr);
            for (int i = 0; i < 4; ++i) probs[i] = (float(src[i * m_outSpatial]) - zp) * scale;
        }

        if (m_outLogits) {            // 量化卷积网输出的是 logits，这里补 softmax
            float mx = probs[0];
            for (int i = 1; i < 4; ++i) mx = std::max(mx, probs[i]);
            float s = 0.0f;
            for (int i = 0; i < 4; ++i) { probs[i] = expf(probs[i] - mx); s += probs[i]; }
            for (int i = 0; i < 4; ++i) probs[i] /= s;
        }
        return true;
    }

    void warmup(int n, const float x[3]) {
        float p[4];
        for (int i = 0; i < n; ++i) infer(x, p);
    }

    int run_rows(const std::vector<std::vector<float>> &rows, int repeat, bool csv_out, bool check) {
        float p[4];
        std::vector<double> lat;
        int bad = 0;
        for (size_t r = 0; r < rows.size(); ++r) {
            const auto &row = rows[r];
            double ms = 0.0;
            bool ok = true;
            for (int k = 0; k < repeat; ++k) ok = infer(row.data(), p, &ms) && ok;
            if (!ok) {
                printf("[npu] 样本 %zu 推理失败\n", r);
                bad++;
                continue;
            }
            lat.push_back(ms);
            int best = 0;
            for (int i = 1; i < 4; ++i) {
                if (p[i] > p[best]) best = i;
            }
            if (csv_out) {
                printf("%.3f,%.3f,%.3f,%d,%s,%.4f,%.4f,%.4f,%.4f,%.3f\n", row[0], row[1], row[2],
                       best, kClasses[best], p[0], p[1], p[2], p[3], ms);
            } else if (r < 40) {
                printf("V=%7.3f I=%6.3f D=%6.2f%% -> %-5s (%.3f %.3f %.3f %.3f) %.3f ms\n",
                       row[0], row[1], row[2], kClasses[best], p[0], p[1], p[2], p[3], ms);
            }
            if (check && row.size() > 3 && int(row[3]) != best) {
                bad++;
                printf("[npu] 期望 %d 实得 %d  (V=%.3f I=%.3f D=%.2f)\n", int(row[3]), best, row[0], row[1], row[2]);
            }
        }
        if (!lat.empty()) {
            std::sort(lat.begin(), lat.end());
            double sum = 0;
            for (double v : lat) sum += v;
            printf("[npu] 样本 %zu, 单次推理: mean=%.3f ms  p50=%.3f ms  min=%.3f  max=%.3f\n",
                   lat.size(), sum / lat.size(), lat[lat.size() / 2], lat.front(), lat.back());
            fflush(stdout);
        }
        return bad == 0 ? 0 : 1;
    }

private:
#ifdef HAVE_QCONV
    /** 用 armnn API 直接搭量化卷积网络（QAsymmU8 输入/权重/激活，int32 bias）。
     *  输入 [1,3,1,1] -> Conv1x1 32 -> ReLU -> Conv1x1 16 -> ReLU -> Conv1x1 4 -> 输出 uint8 logits。 */
    std::shared_ptr<armnn::INetwork> build_network_quant_conv() {
        auto net = armnn::INetwork::Create();
        m_inputNames = {"input"};
        m_outputNames = {"logits"};

        auto qinfo = [](armnn::TensorInfo &ti, float scale, int zp) {
            ti.SetQuantizationScale(scale);
            ti.SetQuantizationOffset(zp);
        };

        armnn::Convolution2dDescriptor cd;
        cd.m_PadLeft = cd.m_PadRight = cd.m_PadTop = cd.m_PadBottom = 0;
        cd.m_StrideX = cd.m_StrideY = 1;
        cd.m_BiasEnabled = true;
        cd.m_DataLayout = armnn::DataLayout::NCHW;

        armnn::ActivationDescriptor relu;
        relu.m_Function = armnn::ActivationFunction::ReLu;

        // 权重/偏置必须活到 Optimize 之后，放静态存储
        auto mkWeights = [&](const unsigned char *w, unsigned out, unsigned in) {
            armnn::TensorInfo ti({out, in, 1, 1}, armnn::DataType::QAsymmU8);
            return ti;
        };
        (void)mkWeights;

        static armnn::TensorInfo w1i({DCDC_Q_H1, 3, 1, 1}, armnn::DataType::QAsymmU8);
        static armnn::TensorInfo b1i({DCDC_Q_H1}, armnn::DataType::Signed32);
        static armnn::TensorInfo w2i({DCDC_Q_H2, DCDC_Q_H1, 1, 1}, armnn::DataType::QAsymmU8);
        static armnn::TensorInfo b2i({DCDC_Q_H2}, armnn::DataType::Signed32);
        static armnn::TensorInfo w3i({DCDC_Q_OUT, DCDC_Q_H2, 1, 1}, armnn::DataType::QAsymmU8);
        static armnn::TensorInfo b3i({DCDC_Q_OUT}, armnn::DataType::Signed32);
        qinfo(w1i, DCDC_Q_W1_SCALE, DCDC_Q_W1_ZP);
        qinfo(w2i, DCDC_Q_W2_SCALE, DCDC_Q_W2_ZP);
        qinfo(w3i, DCDC_Q_W3_SCALE, DCDC_Q_W3_ZP);
        qinfo(b1i, DCDC_Q_B1_SCALE, 0);
        qinfo(b2i, DCDC_Q_B2_SCALE, 0);
        qinfo(b3i, DCDC_Q_B3_SCALE, 0);
        // ConstTensor 要求 TensorInfo 标记为常量
        w1i.SetConstant(true); b1i.SetConstant(true);
        w2i.SetConstant(true); b2i.SetConstant(true);
        w3i.SetConstant(true); b3i.SetConstant(true);

        static armnn::ConstTensor w1(w1i, DCDC_Q_W1);
        static armnn::ConstTensor b1(b1i, DCDC_Q_B1);
        static armnn::ConstTensor w2(w2i, DCDC_Q_W2);
        static armnn::ConstTensor b2(b2i, DCDC_Q_B2);
        static armnn::ConstTensor w3(w3i, DCDC_Q_W3);
        static armnn::ConstTensor b3(b3i, DCDC_Q_B3);

        auto inInfo = armnn::TensorInfo({1, 3, 1, 1}, armnn::DataType::QAsymmU8);
        qinfo(inInfo, DCDC_Q_IN_SCALE, DCDC_Q_IN_ZP);

        auto h1Info = armnn::TensorInfo({1, DCDC_Q_H1, 1, 1}, armnn::DataType::QAsymmU8);
        auto h2Info = armnn::TensorInfo({1, DCDC_Q_H2, 1, 1}, armnn::DataType::QAsymmU8);
        auto outInfo = armnn::TensorInfo({1, DCDC_Q_OUT, 1, 1}, armnn::DataType::QAsymmU8);
        qinfo(h1Info, DCDC_Q_A1_SCALE, DCDC_Q_A1_ZP);
        qinfo(h2Info, DCDC_Q_A2_SCALE, DCDC_Q_A2_ZP);
        qinfo(outInfo, DCDC_Q_O_SCALE, DCDC_Q_O_ZP);

        armnn::IConnectableLayer *in = net->AddInputLayer(0, "input");
        // 这个 armnn 版本：卷积的权重/偏置也是「输入」，用 ConstantLayer 接 slot 1/2
        auto addConv = [&](const char *name, armnn::ConstTensor &w, armnn::ConstTensor &b) {
            static std::vector<std::string> names;   // 让 name 指针活到 Optimize 之后
            names.push_back(std::string(name) + "_w");
            names.push_back(std::string(name) + "_b");
            armnn::IConnectableLayer *wL = net->AddConstantLayer(w, names[names.size() - 2].c_str());
            armnn::IConnectableLayer *bL = net->AddConstantLayer(b, names[names.size() - 1].c_str());
            wL->GetOutputSlot(0).SetTensorInfo(w.GetInfo());
            bL->GetOutputSlot(0).SetTensorInfo(b.GetInfo());
            armnn::IConnectableLayer *c = net->AddConvolution2dLayer(cd, name);
            wL->GetOutputSlot(0).Connect(c->GetInputSlot(1));
            bL->GetOutputSlot(0).Connect(c->GetInputSlot(2));
            return c;
        };
        armnn::IConnectableLayer *c1 = addConv("conv1", w1, b1);
        armnn::IConnectableLayer *r1 = net->AddActivationLayer(relu, "relu1");
        armnn::IConnectableLayer *c2 = addConv("conv2", w2, b2);
        armnn::IConnectableLayer *r2 = net->AddActivationLayer(relu, "relu2");
        armnn::IConnectableLayer *c3 = addConv("conv3", w3, b3);

        in->GetOutputSlot(0).Connect(c1->GetInputSlot(0));
        c1->GetOutputSlot(0).Connect(r1->GetInputSlot(0));
        r1->GetOutputSlot(0).Connect(c2->GetInputSlot(0));
        c2->GetOutputSlot(0).Connect(r2->GetInputSlot(0));
        r2->GetOutputSlot(0).Connect(c3->GetInputSlot(0));

        // 必须显式接一个 OutputLayer，否则优化器会把整张图当死代码删掉
        armnn::IConnectableLayer *outL = net->AddOutputLayer(0, "logits");
        c3->GetOutputSlot(0).Connect(outL->GetInputSlot(0));

        in->GetOutputSlot(0).SetTensorInfo(inInfo);
        c1->GetOutputSlot(0).SetTensorInfo(h1Info);
        r1->GetOutputSlot(0).SetTensorInfo(h1Info);
        c2->GetOutputSlot(0).SetTensorInfo(h2Info);
        r2->GetOutputSlot(0).SetTensorInfo(h2Info);
        c3->GetOutputSlot(0).SetTensorInfo(outInfo);

        m_inputInfos = {armnn::BindingPointInfo(0, inInfo)};
        m_outputInfos = {armnn::BindingPointInfo(0, outInfo)};
        m_outLogits = true;
        return net;
    }
#endif

    std::shared_ptr<armnn::INetwork> parse_onnx(const std::string &model) {
        auto parser = armnnOnnxParser::IOnnxParser::Create();
        if (!parser) throw std::runtime_error("IOnnxParser::Create failed");
        std::shared_ptr<armnn::INetwork> net = parser->CreateNetworkFromBinaryFile(model.c_str());
        if (!net) throw std::runtime_error("onnx parse failed: " + model);
        m_inputNames = parser->GetInputTensorNames();
        m_outputNames = parser->GetOutputTensorNames();
        fprintf(stderr, "[stage] parser: %zu 输入 / %zu 输出\n", m_inputNames.size(), m_outputNames.size());
        if (m_inputNames.empty()) throw std::runtime_error("parser 没有报出输入张量名");
        for (const auto &n : m_inputNames) m_inputInfos.push_back(parser->GetNetworkInputBindingInfo(n));
        for (const auto &n : m_outputNames) m_outputInfos.push_back(parser->GetNetworkOutputBindingInfo(n));
        cache_infos();
        return net;
    }

#ifdef DCDC_USE_WEIGHTS_HEADER
    std::shared_ptr<armnn::INetwork> build_network_from_header() {
        auto net = armnn::INetwork::Create();
        m_inputNames = {"input"};
        m_outputNames = {"probs"};

        armnn::FullyConnectedDescriptor fc;
        fc.m_BiasEnabled = true;
        fc.m_TransposeWeightMatrix = true;

        auto toTensor = [](const float *w, unsigned rows, unsigned cols) {
            return armnn::ConstTensor(armnn::TensorInfo({rows, cols}, armnn::DataType::Float32), w);
        };
        auto toBias = [](const float *b, unsigned n) {
            return armnn::ConstTensor(armnn::TensorInfo({n}, armnn::DataType::Float32), b);
        };

        static armnn::ConstTensor w1 = toTensor(DCDC_W1, DCDC_H1, DCDC_IN);
        static armnn::ConstTensor b1 = toBias(DCDC_B1, DCDC_H1);
        static armnn::ConstTensor w2 = toTensor(DCDC_W2, DCDC_H2, DCDC_H1);
        static armnn::ConstTensor b2 = toBias(DCDC_B2, DCDC_H2);
        static armnn::ConstTensor w3 = toTensor(DCDC_W3, DCDC_OUT, DCDC_H2);
        static armnn::ConstTensor b3 = toBias(DCDC_B3, DCDC_OUT);

        armnn::ActivationDescriptor relu;
        relu.m_Function = armnn::ActivationFunction::ReLu;

        // 这个 armnn 版本里 FullyConnected 的权重/偏置是「输入」，要用 ConstantLayer 接进来
        armnn::IConnectableLayer *in = net->AddInputLayer(0, "input");
        armnn::IConnectableLayer *w1L = net->AddConstantLayer(w1, "w1");
        armnn::IConnectableLayer *b1L = net->AddConstantLayer(b1, "b1");
        armnn::IConnectableLayer *fc1 = net->AddFullyConnectedLayer(fc, "fc1");
        armnn::IConnectableLayer *r1 = net->AddActivationLayer(relu, "relu1");
        armnn::IConnectableLayer *w2L = net->AddConstantLayer(w2, "w2");
        armnn::IConnectableLayer *b2L = net->AddConstantLayer(b2, "b2");
        armnn::IConnectableLayer *fc2 = net->AddFullyConnectedLayer(fc, "fc2");
        armnn::IConnectableLayer *r2 = net->AddActivationLayer(relu, "relu2");
        armnn::IConnectableLayer *w3L = net->AddConstantLayer(w3, "w3");
        armnn::IConnectableLayer *b3L = net->AddConstantLayer(b3, "b3");
        armnn::IConnectableLayer *fc3 = net->AddFullyConnectedLayer(fc, "fc3");
        armnn::SoftmaxDescriptor sm;
        sm.m_Axis = 1;
        armnn::IConnectableLayer *soft = net->AddSoftmaxLayer(sm, "softmax");

        in->GetOutputSlot(0).Connect(fc1->GetInputSlot(0));
        w1L->GetOutputSlot(0).Connect(fc1->GetInputSlot(1));
        b1L->GetOutputSlot(0).Connect(fc1->GetInputSlot(2));
        fc1->GetOutputSlot(0).Connect(r1->GetInputSlot(0));
        r1->GetOutputSlot(0).Connect(fc2->GetInputSlot(0));
        w2L->GetOutputSlot(0).Connect(fc2->GetInputSlot(1));
        b2L->GetOutputSlot(0).Connect(fc2->GetInputSlot(2));
        fc2->GetOutputSlot(0).Connect(r2->GetInputSlot(0));
        r2->GetOutputSlot(0).Connect(fc3->GetInputSlot(0));
        w3L->GetOutputSlot(0).Connect(fc3->GetInputSlot(1));
        b3L->GetOutputSlot(0).Connect(fc3->GetInputSlot(2));
        fc3->GetOutputSlot(0).Connect(soft->GetInputSlot(0));

        auto inInfo = armnn::TensorInfo({1, DCDC_IN}, armnn::DataType::Float32);
        auto outInfo = armnn::TensorInfo({1, DCDC_OUT}, armnn::DataType::Float32);
        in->GetOutputSlot(0).SetTensorInfo(inInfo);
        fc1->GetOutputSlot(0).SetTensorInfo(armnn::TensorInfo({1, DCDC_H1}, armnn::DataType::Float32));
        r1->GetOutputSlot(0).SetTensorInfo(armnn::TensorInfo({1, DCDC_H1}, armnn::DataType::Float32));
        fc2->GetOutputSlot(0).SetTensorInfo(armnn::TensorInfo({1, DCDC_H2}, armnn::DataType::Float32));
        r2->GetOutputSlot(0).SetTensorInfo(armnn::TensorInfo({1, DCDC_H2}, armnn::DataType::Float32));
        fc3->GetOutputSlot(0).SetTensorInfo(armnn::TensorInfo({1, DCDC_OUT}, armnn::DataType::Float32));
        soft->GetOutputSlot(0).SetTensorInfo(outInfo);

        m_inputInfos = {armnn::BindingPointInfo(0, inInfo)};
        m_outputInfos = {armnn::BindingPointInfo(0, outInfo)};
        return net;
    }
#endif

    void cache_infos() {
        m_inInfo = m_inputInfos.at(0).second;
        m_inInfo.SetConstant(true);   // ConstTensor 要求 TensorInfo 标记为常量（官方 executor.cpp 同款）
        m_outInfo = m_outputInfos.at(0).second;
        const armnn::TensorShape &inShape = m_inInfo.GetShape();
        m_inChannels = inShape.GetNumDimensions() == 4 ? inShape[1] : 3;
        m_inSpatial = inShape.GetNumDimensions() == 4 ? inShape[2] * inShape[3] : 1;
        const armnn::TensorShape &outShape = m_outInfo.GetShape();
        m_outSpatial = outShape.GetNumDimensions() == 4 ? outShape[2] * outShape[3] : 1;
    }

    std::shared_ptr<armnn::INetwork> m_net;
    std::shared_ptr<armnn::IRuntime> m_runtime;
    armnn::NetworkId m_netId{0};
    std::vector<std::string> m_inputNames, m_outputNames;
    std::vector<armnn::BindingPointInfo> m_inputInfos, m_outputInfos;
    armnn::TensorInfo m_inInfo, m_outInfo;
    std::vector<CmaBufPtr> m_inBufs, m_outBufs;
    armnn::InputTensors m_inTensors;
    armnn::OutputTensors m_outTensors;
    unsigned m_inChannels = 3;
    unsigned m_inSpatial = 1;
    unsigned m_outSpatial = 1;
    bool m_outLogits = false;      // --qconv：输出是 uint8 logits，需要 host 侧 softmax
};

void usage(const char *prog) {
    printf(
        "用法: %s [选项]\n"
        "  -m, --model PATH      ONNX 模型（默认 dcdc_npu_qdq.onnx）\n"
        "  -b, --backends LIST   后端顺序，默认 Alnpu,CpuRef\n"
        "  -c, --csv PATH        从 CSV 读 V,I,D[,label]，逐样本推理并输出 CSV\n"
        "  -n, --repeat N        每个样本重复推理 N 次（默认 1）\n"
        "  -w, --warmup N        预热 N 次（默认 5）\n"
        "      --check           若 CSV 有 label 列则统计一致率\n"
        "      --qconv           用内置量化权重（QAsymmU8 1x1 Conv）直接搭网，绕开 ONNX parser\n"
        "      --optimize-only   只做解析/优化/加载，不执行推理（避免板子被 NPU 挂死）\n"
        "  -v, --verbose         armnn Info 日志（能看到各层分配到哪个后端）\n"
        "  -h, --help\n"
        "      --live PATH    常驻模式：监视 V I D 文件（默认 /tmp/vi.txt），结果写 /tmp/npu.status\n"
        "      --status PATH  常驻模式输出文件（默认 /tmp/npu.status；0=正常 1=异常）\n"
        "      --period MS    常驻模式轮询周期（默认 100 ms）\n"
        "不带 --csv 时从 stdin 读，每行: V I D\n",
        prog);
}

}  // namespace

static void on_fatal(int sig) {
    void *bt[32];
    int n = backtrace(bt, 32);
    fprintf(stderr, "[fatal] signal %d, backtrace (%d frames):\n", sig, n);
    backtrace_symbols_fd(bt, n, 2);
    _exit(128 + sig);
}

static void on_fatal_info(int sig, siginfo_t *info, void *ctx) {
    ucontext_t *uc = (ucontext_t *)ctx;
    fprintf(stderr, "[fatal] signal %d addr=%p pc=%p lr=%p sp=%p\n", sig,
            info ? info->si_addr : (void *)0,
            (void *)uc->uc_mcontext.pc, (void *)uc->uc_mcontext.regs[30],
            (void *)uc->uc_mcontext.sp);
    _exit(128 + sig);
}

int main(int argc, char **argv) {
    std::string model = "dcdc_npu_qdq.onnx";
    std::vector<armnn::BackendId> backends = {armnn::BackendId("Alnpu"), armnn::BackendId("CpuRef")};
    std::string csvPath;
    int repeat = 1, warmup = 5;
    bool verbose = false, check = false, qconv = false, optimizeOnly = false;
    std::string livePath, statusPath = "/tmp/npu.status";
    int periodMs = 100;
#ifdef DCDC_USE_WEIGHTS_HEADER
    bool useHeader = false;
#endif

    for (int i = 1; i < argc; ++i) {
        std::string a = argv[i];
        auto next = [&](const char *what) -> std::string {
            if (i + 1 >= argc) { fprintf(stderr, "%s 需要一个参数\n", what); exit(2); }
            return argv[++i];
        };
        if (a == "-m" || a == "--model") model = next("--model");
        else if (a == "-b" || a == "--backends") {
            backends.clear();
            for (auto &s : split(next("--backends"), ',')) backends.emplace_back(s);
        } else if (a == "-c" || a == "--csv") csvPath = next("--csv");
        else if (a == "-n" || a == "--repeat") repeat = std::stoi(next("--repeat"));
        else if (a == "-w" || a == "--warmup") warmup = std::stoi(next("--warmup"));
        else if (a == "-v" || a == "--verbose") verbose = true;
        else if (a == "--check") check = true;
        else if (a == "--qconv") qconv = true;
        else if (a == "--optimize-only") optimizeOnly = true;
        else if (a == "--live") livePath = next("--live");
        else if (a == "--status") statusPath = next("--status");
        else if (a == "--period") periodMs = std::stoi(next("--period"));
#ifdef DCDC_USE_WEIGHTS_HEADER
        else if (a == "--weights") { useHeader = true; }
#endif
        else if (a == "-h" || a == "--help") { usage(argv[0]); return 0; }
        else { fprintf(stderr, "未知参数: %s\n", a.c_str()); usage(argv[0]); return 2; }
    }

#ifdef DCDC_USE_WEIGHTS_HEADER
    if (useHeader) model.clear();
#endif

    printf("[npu] model=%s  backends=", model.empty() ? "(weights header)" : model.c_str());
    for (auto &b : backends) printf("%s ", std::string(b).c_str());
    printf("\n");

    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_sigaction = on_fatal_info;
    sa.sa_flags = SA_SIGINFO;
    sigaction(SIGSEGV, &sa, NULL);
    sigaction(SIGBUS, &sa, NULL);
    cma_mem_init();
    int rc = 0;
    try {
        MiniExecutor ex(model, backends, verbose, qconv);
        fprintf(stderr, "[stage] ctor ok\n");
        ex.describe();
        if (optimizeOnly) {
            fprintf(stderr, "[npu] optimize-only：已成功加载网络，跳过推理\n");
            cma_mem_deinit();
            return 0;
        }

        std::vector<std::vector<float>> rows;
        if (!csvPath.empty()) {
            std::ifstream f(csvPath);
            if (!f) { fprintf(stderr, "打不开 CSV: %s\n", csvPath.c_str()); return 2; }
            std::string line;
            while (std::getline(f, line)) {
                if (line.empty() || line[0] == '#') continue;
                std::vector<float> row;
                for (auto &tok : split(line, ',')) {
                    char *end = nullptr;
                    float v = strtof(tok.c_str(), &end);
                    if (end == tok.c_str()) { row.clear(); break; }   // 表头之类的非数字行
                    row.push_back(v);
                }
                if (row.size() >= 3) rows.push_back(row);
            }
            printf("[npu] 读入 %zu 行\n", rows.size());
        } else {
            std::string line;
            while (std::getline(std::cin, line)) {
                std::vector<float> row;
                for (auto &tok : split(line, ' ')) {
                    char *end = nullptr;
                    float v = strtof(tok.c_str(), &end);
                    if (end != tok.c_str()) row.push_back(v);
                }
                if (row.size() >= 3) rows.push_back(row);
            }
        }
        if (rows.empty()) { fprintf(stderr, "没有输入样本\n"); return 2; }

        float warm[3] = {24.0f, 1.5f, 50.0f};
        ex.warmup(warmup, warm);

        /* ---------------- live mode: continuous classification ---------------- */
        if (!livePath.empty()) {
            fprintf(stderr, "[npu] live: watch %s -> %s (period %d ms)\n",
                    livePath.c_str(), statusPath.c_str(), periodMs);
            float p[4];
            std::string last;
            while (true) {
                std::ifstream f(livePath);
                std::string line;
                if (f && std::getline(f, line) && !line.empty() && line != last) {
                    last = line;
                    std::vector<float> row;
                    for (auto &tok : split(line, ' ')) {
                        char *end = nullptr;
                        float v = strtof(tok.c_str(), &end);
                        if (end != tok.c_str()) row.push_back(v);
                    }
                    if (row.size() >= 3) {
                        double ms = 0.0;
                        if (ex.infer(row.data(), p, &ms)) {
                            int best = 0;
                            for (int i = 1; i < 4; ++i) if (p[i] > p[best]) best = i;
                            int code = (best <= 1) ? 0 : 1;
                            FILE *sf = fopen(statusPath.c_str(), "w");
                            if (sf) { fprintf(sf, "%d\n", code); fclose(sf); }
                            FILE *lf = fopen("/tmp/npu.log", "a");
                            if (lf) {
                                fprintf(lf, "V=%7.3f I=%6.3f D=%6.2f -> code=%d class=%s (%.3f %.3f %.3f %.3f) %.3f ms\n",
                                        row[0], row[1], row[2], code, kClasses[best],
                                        p[0], p[1], p[2], p[3], ms);
                                fclose(lf);
                            }
                        }
                    }
                }
                usleep((useconds_t)periodMs * 1000);
            }
        }

        rc = ex.run_rows(rows, repeat, !csvPath.empty(), check);
    } catch (const std::exception &e) {
        fprintf(stderr, "[npu] 失败: %s\n", e.what());
        cma_mem_deinit();
        return 1;
    }
    cma_mem_deinit();
    return rc;
}
