/*
 * threeclass_live.cpp —— 三分类模型的“滑窗流式”推理骨架
 *
 * 和包里那个一次性二进制不同：网络只加载一次，随后按窗口循环推理。
 * 这正好是“实时”需要的形态，只是数据源先用 CSV 回放（--csv）。
 * 等 FDMA 有数据了，把 replay_source 换成读 DDR 环的 sampler 即可，其余不动。
 *
 * 用法：
 *   threeclass_live --model models/condition_threeclass_uint8.onnx \
 *                   --csv cap_phases.csv --rate 128 --hop 0.5
 *
 * 输出每行：t_end  class  scores(u8)  ms
 */

#include <algorithm>
#include <array>
#include <chrono>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <fstream>
#include <memory>
#include <sstream>
#include <stdexcept>
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

#include "threeclass_preprocess.hpp"
#include "quant_io.hpp"

namespace {

const char *kClasses[3] = {"normal", "load_transient", "oscillation"};
constexpr int WINDOW = 256;
constexpr int BASELINE_MAX = 50000;
constexpr float RIPPLE_MIN = 1.5f;
constexpr float DRIFT_RATIO = 0.15f;
constexpr float I_RIPPLE_MIN = 0.08f;  /* 电流峰峰值门限（A） */  /* 窗口均值相对基线偏这么多 -> 当成阶跃，不是振荡 */   /* 判 oscillation 至少要有这么大的峰峰值（V） */

struct Cma {
    std::shared_ptr<cma_buffer_t> b;
    explicit Cma(size_t bytes) : b(std::make_shared<cma_buffer_t>((uint32_t)bytes)) {
        if (cma_mem_alloc(b.get()) != 0 || b->phys_addr == 0) throw std::runtime_error("cma alloc failed");
    }
    cma_buffer_t *operator->() const { return b.get(); }
};

double now_ms() {
    using namespace std::chrono;
    return duration_cast<duration<double, std::milli>>(steady_clock::now().time_since_epoch()).count();
}

/** 数据源接口：现在只有 CSV 回放，接 FDMA 时实现同样的 feed() 即可。 */
class ReplaySource {
public:
    ReplaySource(const std::string &csv, double rate) : rate_(rate) {
        std::ifstream f(csv);
        if (!f) throw std::runtime_error("cannot open csv: " + csv);
        std::string line;
        bool header = true;
        while (std::getline(f, line)) {
            if (line.empty()) continue;
            if (header && line.find_first_not_of("0123456789.-, ") != std::string::npos) { header = false; continue; }
            header = false;
            std::vector<double> v;
            std::stringstream ss(line);
            std::string tok;
            while (std::getline(ss, tok, ',')) {
                try { v.push_back(std::stod(tok)); } catch (...) { v.clear(); break; }
            }
            if (v.size() >= 4) { t_.push_back(v[0]); data_.push_back({v[1], v[2], v[3]}); }
        }
        if (data_.empty()) throw std::runtime_error("no rows in csv");
        // duty 若是百分数则换算
        double maxd = 0;
        for (auto &r : data_) maxd = std::max(maxd, r[2]);
        if (maxd > 1.5) for (auto &r : data_) r[2] /= 100.0;
    }
    size_t size() const { return data_.size(); }
    double t(size_t i) const { return t_[i]; }
    const std::array<double, 3> &at(size_t i) const { return data_[i]; }

private:
    double rate_;
    std::vector<double> t_;
    std::vector<std::array<double, 3>> data_;
};

std::array<float, 768> build_window(const ReplaySource &src, size_t begin, size_t end, std::array<double, 3> &baseline) {
    // baseline = 窗口之前的过去均值（最多 BASELINE_MAX 个采样）
    size_t b0 = begin > (size_t)BASELINE_MAX ? begin - BASELINE_MAX : 0;
    std::array<double, 3> sum{0, 0, 0};
    for (size_t i = b0; i < begin; ++i) {
        const auto &r = src.at(i);
        sum[0] += r[0]; sum[1] += r[1]; sum[2] += r[2];
    }
    size_t n = begin - b0;
    if (n == 0) baseline = {0.0, 0.0, 0.0};
    else baseline = {sum[0] / n, sum[1] / n, sum[2] / n};

    // 取窗口内的点，重采样到 WINDOW 个
    std::array<float, 768> physical{};
    size_t m = end - begin;
    for (int t = 0; t < WINDOW; ++t) {
        double pos = (m <= 1) ? 0.0 : (double)t * (double)(m - 1) / (double)(WINDOW - 1);
        size_t i0 = begin + (size_t)pos;
        size_t i1 = std::min(i0 + 1, end - 1);
        double frac = pos - (double)(i0 - begin);
        for (int c = 0; c < 3; ++c) {
            double v = src.at(i0)[c] * (1.0 - frac) + src.at(i1)[c] * frac;
            physical[t * 3 + c] = (float)v;      // T,C 顺序
        }
    }
    return physical;
}

}  // namespace

int main(int argc, char **argv) {
    std::string model, csv, profile;
    double rate = 128.0, hop = 0.5;
    for (int i = 1; i < argc; ++i) {
        std::string a = argv[i];
        auto next = [&]() -> std::string {
            if (++i >= argc) { fprintf(stderr, "missing value for %s\n", a.c_str()); exit(2); }
            return argv[i];
        };
        if (a == "--model") model = next();
        else if (a == "--csv") csv = next();
        else if (a == "--rate") rate = std::stod(next());
        else if (a == "--hop") hop = std::stod(next());
        else if (a == "--profile") profile = next();
        else { fprintf(stderr, "usage: %s --model M.onnx --csv cap.csv [--rate 128] [--hop 0.5]\n", argv[0]); return 2; }
    }
    if (model.empty() || csv.empty()) { fprintf(stderr, "need --model and --csv\n"); return 2; }

    cma_mem_init();
    try {
        ReplaySource src(csv, rate);
        printf("[live] csv=%s rows=%zu rate=%.1fHz hop=%.2fs\n", csv.c_str(), src.size(), rate, hop);

        armnn::ConfigureLogging(true, false, armnn::LogSeverity::Error);
        auto parser = armnnOnnxParser::IOnnxParser::Create();
        auto network = parser->CreateNetworkFromBinaryFile(model.c_str());
        if (!network) throw std::runtime_error("onnx parse failed");
        auto in_binding = parser->GetNetworkInputBindingInfo("input");
        auto out_binding = parser->GetNetworkOutputBindingInfo("logits");

        armnn::IRuntime::CreationOptions rt;
        rt.m_CustomAllocatorMap["CpuAcc"] = rt.m_CustomAllocatorMap["CpuRef"] =
            std::shared_ptr<armnn::ICustomAllocator>(new armnn::CmaAllocator);
        auto runtime = armnn::IRuntime::Create(rt);
        if (!runtime) throw std::runtime_error("runtime create failed (cma_mem ko?)");

        armnn::OptimizerOptionsOpaque opts;
        opts.SetImportEnabled(true);
        opts.SetExportEnabled(true);
        auto opt = armnn::Optimize(*network, {armnn::BackendId("Alnpu")}, runtime->GetDeviceSpec(), opts);
        if (!opt) throw std::runtime_error("optimize failed");

        static armnn::INetworkProperties props(false, armnn::MemorySource::Malloc, armnn::MemorySource::Malloc);
        armnn::NetworkId net_id;
        std::string err;
        if (runtime->LoadNetwork(net_id, std::move(opt), err, props) != armnn::Status::Success)
            throw std::runtime_error("load network failed: " + err);

        auto in_info = in_binding.second;
        auto out_info = out_binding.second;
        in_info.SetConstant(true);
        Cma in(in_info.GetNumBytes());
        Cma out(out_info.GetNumBytes());
        armnn::InputTensors inputs{{in_binding.first, armnn::ConstTensor(in_info, in->virt_addr)}};
        armnn::OutputTensors outputs{{out_binding.first, armnn::Tensor(out_info, out->virt_addr)}};

        printf("[live] model loaded: in=%uB out=%uB scale=%.9f/%.9f\n",
               in_info.GetNumBytes(), out_info.GetNumBytes(),
               in_info.GetQuantizationScale(), out_info.GetQuantizationScale());

        size_t win = (size_t)std::lround(WINDOW * rate / 128.0);   // 128 Hz 时 = 256
        size_t step = (size_t)std::lround(hop * rate);
        if (step < 1) step = 1;
        int n = 0;
        auto t_start = now_ms();
        size_t min_history = (size_t)std::lround(rate * 0.5);   // 至少半秒历史才能算 baseline
        for (size_t end = win + min_history; end <= src.size(); end += step) {
            size_t begin = end - win;
            std::array<double, 3> baseline{};
            auto physical = build_window(src, begin, end, baseline);
            auto normalized = threeclass_preprocess(physical.data(), physical.size(), baseline.data());

            auto *dst = static_cast<unsigned char *>(in->virt_addr);
            for (int k = 0; k < 768; ++k)
                dst[k] = square_quantize(normalized[k], in_info.GetQuantizationScale(), in_info.GetQuantizationOffset());
            cma_mem_sync_for_device(in->phys_addr, in->size);

            double t0 = now_ms();
            auto st = runtime->EnqueueWorkload(net_id, inputs, outputs);
            double ms = now_ms() - t0;
            if (st != armnn::Status::Success) throw std::runtime_error("EnqueueWorkload failed");
            cma_mem_sync_for_cpu(out->phys_addr, out->size);

            const auto *o = static_cast<const unsigned char *>(out->virt_addr);
            std::array<unsigned, 16> chmax{};
            for (int c = 0; c < 16; ++c) {
                unsigned m = 0;
                for (int k = 0; k < 64; ++k) m = std::max(m, (unsigned)o[c * 64 + k]);
                chmax[c] = m;
            }
            int cls = 0;
            for (int c = 1; c < 3; ++c) if (chmax[c] > chmax[cls]) cls = c;

            /* 后处理门限（模型权重不动）：
               模型是 causal-relative 特征，给定一变，历史均值还没跟上，
               窗口里就带一个持续直流偏置 —— 它会把「阶跃后的稳态」判成 oscillation。
               所以用窗口内的实际起伏来做否决：
                 · V/I 都没起伏            -> 稳态（normal）
                 · 有起伏且均值整体跑了    -> 阶跃响应（load_transient）
                 · 有起伏但均值没跑        -> 才是振荡，保留模型判定 */
            float vmin = physical[0], vmax = physical[0];
            float imin = physical[1], imax = physical[1];
            float vsum = 0, isum = 0;
            for (int t = 0; t < WINDOW; ++t) {
                float v = physical[t * 3 + 0], i = physical[t * 3 + 1];
                if (v < vmin) vmin = v;
                if (v > vmax) vmax = v;
                if (i < imin) imin = i;
                if (i > imax) imax = i;
                vsum += v;
                isum += i;
            }
            const float vpp = vmax - vmin;
            const float ipp = imax - imin;
            const float drift = std::fabs(vsum / WINDOW - (float)baseline[0]);
            const bool quiet = (vpp < RIPPLE_MIN) && (ipp < I_RIPPLE_MIN);
            int tag = 0;
            if (quiet) {
                cls = 0;                                        /* 没起伏 = 稳态 */
                tag = 1;
            } else if (cls == 2 && drift > DRIFT_RATIO * std::fabs((float)baseline[0])) {
                cls = 1;                                        /* 有起伏但均值跑了 = 阶跃 */
                tag = 2;
            }
            printf("%7.2fs  %-15s [%u %u %u]  Vpp=%5.2fV Ipp=%5.3fA drift=%5.2fV%s  %.3f ms\n",
                   src.t(end - 1), kClasses[cls], chmax[0], chmax[1], chmax[2], vpp, ipp, drift,
                   tag == 1 ? " (steady)" : (tag == 2 ? " (osc->transient)" : ""), ms);
            n++;
        }
        printf("[live] %d windows, %.1f ms total (%.2f ms/window incl. preprocess)\n",
               n, now_ms() - t_start, (now_ms() - t_start) / std::max(1, n));
    } catch (const std::exception &e) {
        fprintf(stderr, "[live] failed: %s\n", e.what());
        cma_mem_deinit();
        return 1;
    }
    cma_mem_deinit();
    return 0;
}
