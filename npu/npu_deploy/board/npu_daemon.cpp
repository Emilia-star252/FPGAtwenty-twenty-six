/*
 * npu_daemon.cpp —— 板上常驻：读 FDMA -> 2 s 滑窗 -> NPU 推理 -> 写 /tmp/npu.status
 *
 * HMI（/opt/hmi/hmi）每 500 ms 读 /tmp/npu.status：
 *     0 -> "● 正常"（绿）   1 -> "● 突变"（红）   其它 -> "● 无结果"
 *
 * 本程序把三分类模型的输出映射成这两档：
 *     normal(0)            -> 0
 *     load_transient(1)    -> 1
 *     oscillation(2)       -> 1
 *
 * 用法：
 *   npu_daemon --model models/condition_threeclass_uint8.onnx --status /tmp/npu.status
 *   npu_daemon --model ... --csv cap_vstep.csv --loop      # 回放调试
 *
 * 说明：
 *   - 只读 FDMA（peek），不写 consumer，所以可以和 power_svc 同时跑
 *   - 网络只加载一次，常驻内存
 */
#include <algorithm>
#include <array>
#include <chrono>
#include <cmath>
#include <cstdio>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <deque>
#include <fstream>
#include <memory>
#include <sstream>
#include <stdexcept>
#include <string>
#include <sys/mman.h>
#include <fcntl.h>
#include <unistd.h>
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
#include "quant_io.hpp"

namespace {

constexpr int WINDOW = 256;
constexpr double TRAIN_RATE = 128.0;
constexpr int BASELINE_MAX = 50000;

const float MEAN[3] = {-0.00164139201f, 0.00973002799f, -0.000640165294f};
const float STD[3] = {0.356568277f, 0.371016115f, 0.0256481692f};
const double FLOORS[3] = {1.0, 0.05, 0.05};

const char *kClasses[3] = {"normal", "load_transient", "oscillation"};

// ---- FDMA 寄存器（与 power_svc / probe_fdma 一致）----
constexpr unsigned long FD_BASE = 0x80010000UL;
constexpr unsigned int BLOCK = 4096u;
constexpr unsigned int FRAMES = 256u;
constexpr unsigned int FB = 16u;

struct Sample {
    double t;
    float v, i, d;
};

struct Cma {
    std::shared_ptr<cma_buffer_t> b;
    explicit Cma(size_t bytes) : b(std::make_shared<cma_buffer_t>((uint32_t)bytes)) {
        if (cma_mem_alloc(b.get()) != 0 || b->phys_addr == 0) throw std::runtime_error("cma alloc failed");
    }
    cma_buffer_t *operator->() const { return b.get(); }
};

double mono() {
    using namespace std::chrono;
    return duration_cast<duration<double>>(steady_clock::now().time_since_epoch()).count();
}

int64_t dec48(const uint8_t *p) {
    int64_t v = 0;
    for (int k = 0; k < 6; ++k) v |= (int64_t)p[k] << (8 * k);
    if (v & (1LL << 47)) v -= (1LL << 48);
    return v;
}

void write_status(const std::string &path, int code, const std::string &extra) {
    const std::string tmp = path + ".tmp";
    FILE *f = fopen(tmp.c_str(), "w");
    if (!f) return;
    fprintf(f, "%d\n", code);
    fclose(f);
    rename(tmp.c_str(), path.c_str());
    // 另写一份详细日志，方便排查
    FILE *g = fopen("/tmp/npu.log", "w");
    if (g) { fprintf(g, "%s\n", extra.c_str()); fclose(g); }
}

}  // namespace

int main(int argc, char **argv) {
    std::string model, statusPath = "/tmp/npu.status", csvPath;
    double hop = 0.5, replayRate = 98.0;
    bool loop = false;
    for (int i = 1; i < argc; ++i) {
        std::string a = argv[i];
        auto next = [&]() -> std::string {
            if (++i >= argc) { fprintf(stderr, "missing value for %s\n", a.c_str()); exit(2); }
            return argv[i];
        };
        if (a == "--model") model = next();
        else if (a == "--status") statusPath = next();
        else if (a == "--csv") csvPath = next();
        else if (a == "--rate") replayRate = std::stod(next());
        else if (a == "--hop") hop = std::stod(next());
        else if (a == "--loop") loop = true;
        else { fprintf(stderr, "usage: %s --model M.onnx [--status /tmp/npu.status] [--csv FILE] [--rate 98] [--hop 0.5] [--loop]\n", argv[0]); return 2; }
    }
    if (model.empty()) { fprintf(stderr, "need --model\n"); return 2; }

    cma_mem_init();
    try {
        armnn::ConfigureLogging(true, false, armnn::LogSeverity::Error);
        auto parser = armnnOnnxParser::IOnnxParser::Create();
        auto network = parser->CreateNetworkFromBinaryFile(model.c_str());
        if (!network) throw std::runtime_error("onnx parse failed");
        auto in_binding = parser->GetNetworkInputBindingInfo("input");
        auto out_binding = parser->GetNetworkOutputBindingInfo("logits");

        auto runtime = armnn::IRuntime::Create(armnn::IRuntime::CreationOptions());
        if (!runtime) throw std::runtime_error("runtime create failed (cma_mem?)");

        armnn::OptimizerOptionsOpaque opts;
        opts.SetImportEnabled(true);
        opts.SetExportEnabled(true);
        auto opt = armnn::Optimize(*network, {armnn::BackendId("Alnpu")}, runtime->GetDeviceSpec(), opts);
        if (!opt) throw std::runtime_error("optimize failed (strict Alnpu)");

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

        printf("[npu] model loaded: in=%uB out=%uB status=%s\n",
               in_info.GetNumBytes(), out_info.GetNumBytes(), statusPath.c_str());
        fflush(stdout);

        // ---- 数据源 ----
        std::deque<Sample> hist;
        std::vector<Sample> replay;      // 回放模式：整段数据
        size_t replayIdx = 0;
        double nextFeed = 0.0;
        double lastInfer = 0.0;
        int shownCode = -2;          // 当前显示的状态
        int pendCode = -2, pendCount = 0;
        std::ifstream csv;
        int fd_mem = -1;
        volatile uint32_t *fd = nullptr;
        volatile uint8_t *ring = nullptr;
        uint32_t cons = 0, slots = 0;
        unsigned long ring_base = 0;
        double t0 = mono();
        double sampleRate = 98.0;      // 块率估计（1 样本/块）
        uint32_t rateProd = 0;
        double rateT = 0.0;
        double sampleT = 0.0;          // 按块计数推进的时间轴

        if (!csvPath.empty()) {
            csv.open(csvPath);
            if (!csv) throw std::runtime_error("cannot open csv: " + csvPath);
            std::string line;
            bool header = true;
            while (std::getline(csv, line)) {
                if (line.empty()) continue;
                if (header && line.find_first_not_of("0123456789.-, ") != std::string::npos) { header = false; continue; }
                header = false;
                std::vector<double> v;
                std::stringstream ss(line);
                std::string tok;
                while (std::getline(ss, tok, ',')) {
                    try { v.push_back(std::stod(tok)); } catch (...) { v.clear(); break; }
                }
                if (v.size() < 4) continue;
                replay.push_back({v[0], (float)v[1], (float)v[2], (float)(v[3] > 1.5 ? v[3] / 100.0 : v[3])});
            }
            if (replay.empty()) throw std::runtime_error("csv has no samples");
            printf("[npu] replay %zu samples @%.1f Hz%s\n", replay.size(), replayRate, loop ? " (loop)" : "");
        } else {
            fd_mem = open("/dev/mem", O_RDWR | O_SYNC);
            if (fd_mem < 0) throw std::runtime_error("open /dev/mem failed");
            long pg = sysconf(_SC_PAGESIZE);
            fd = (volatile uint32_t *)mmap(NULL, 0x1000, PROT_READ | PROT_WRITE, MAP_SHARED, fd_mem,
                                           (off_t)(FD_BASE & ~(unsigned long)(pg - 1)));
            if (fd == MAP_FAILED) throw std::runtime_error("mmap FDMA failed");
            /* 开机时 power_svc 可能还没把 FDMA 配好：先等它，别直接退出 */
            ring_base = 0;
            for (int attempt = 0; attempt < 240; ++attempt) {
                ring_base = ((unsigned long)fd[0x14 / 4] << 32) | fd[0x10 / 4];
                if (ring_base) break;
                if (attempt % 20 == 0) fprintf(stderr, "[npu] waiting for FDMA ring base...\n");
                usleep(500000);
            }
            if (!ring_base) throw std::runtime_error("FDMA ring base stayed 0 (power_svc 没起来？)");
            ring = (volatile uint8_t *)mmap(NULL, 4 * 1024 * 1024, PROT_READ, MAP_SHARED, fd_mem, (off_t)ring_base);
            if (ring == MAP_FAILED) throw std::runtime_error("mmap ring failed");
            slots = fd[0x18 / 4];
            cons = fd[0x1C / 4];
            rateProd = cons;
            rateT = mono();
            printf("[npu] FDMA ring=0x%lx slots=%u, live mode\n", ring_base, slots);
        }
        fflush(stdout);

        // ---- 主循环 ----
        for (;;) {
            // 1) 取数据
            if (!csvPath.empty()) {
                /* 回放：按 replayRate 的节奏把整段数据“实时”喂进来 */
                double now = mono();
                if (nextFeed == 0.0) nextFeed = now;
                while (now >= nextFeed && replayIdx < replay.size()) {
                    Sample s = replay[replayIdx++];
                    s.t = nextFeed - t0;
                    hist.push_back(s);
                    nextFeed += 1.0 / replayRate;
                }
                if (replayIdx >= replay.size()) {
                    if (!loop) break;
                    replayIdx = 0;
                }
                while (hist.size() > 60000) hist.pop_front();
            } else {
                /* 基址被重新配置时重新映射（power_svc restart 后会重配） */
                unsigned long now_base = ((unsigned long)fd[0x14 / 4] << 32) | fd[0x10 / 4];
                if (now_base && now_base != ring_base) {
                    ring = (volatile uint8_t *)mmap(NULL, 4 * 1024 * 1024, PROT_READ, MAP_SHARED,
                                                    fd_mem, (off_t)now_base);
                    if (ring != MAP_FAILED) {
                        ring_base = now_base;
                        slots = fd[0x18 / 4];
                        cons = fd[0x1C / 4];
                        fprintf(stderr, "[npu] FDMA ring re-mapped to 0x%lx\n", ring_base);
                    }
                }
                uint32_t prod = fd[0x1C / 4];
                if (prod != cons) {
                    uint32_t n = prod - cons;
                    if (n > 96) cons = prod - 96;    // 落后太多就跳（会丢数据，但时间轴不会压缩）
                    while (cons != prod) {
                        uint32_t slot = cons & (slots - 1u);
                        const uint8_t *blk = (const uint8_t *)ring + (size_t)slot * BLOCK;
                        const uint8_t *f = blk + (FRAMES - 1u) * FB;
                        int64_t vq = dec48(f), iq = dec48(f + 6);
                        uint32_t dq = (uint32_t)f[12] | ((uint32_t)f[13] << 8) |
                                      ((uint32_t)f[14] << 16) | ((uint32_t)f[15] << 24);
                        sampleT += 1.0 / sampleRate;   /* 关键：时间按块率推进 */
                        hist.push_back({sampleT, (float)(vq / 65536.0), (float)(iq / 65536.0),
                                        (float)(dq * 100.0 / 65536.0 / 100.0)});
                        ++cons;
                    }
                    while (hist.size() > 60000) hist.pop_front();
                    /* 每 0.5 s 估一次真实块率 */
                    double nowr = mono();
                    if (rateT == 0.0) { rateT = nowr; rateProd = prod; }
                    else if (nowr - rateT >= 0.5) {
                        double r = (double)(prod - rateProd) / (nowr - rateT);
                        if (r > 20.0 && r < 400.0) sampleRate = 0.7 * sampleRate + 0.3 * r;
                        rateProd = prod;
                        rateT = nowr;
                    }
                } else {
                    usleep(2000);
                }
            }

            // 2) 够 2 s 数据就跑一次推理
            if (hist.size() < WINDOW || mono() - lastInfer < hop) continue;
            lastInfer = mono();

            /* 固定样本数窗口：2 s × 实际块率（约 196 个），避免时间戳估计误差导致窗口长短不一 */
            size_t winIn = (size_t)std::lround((WINDOW / TRAIN_RATE) * sampleRate);
            if (winIn < 16) winIn = 16;
            if (hist.size() < winIn + 4) continue;
            double tEnd = hist.back().t;
            size_t begin = hist.size() - winIn;
            size_t count = winIn;

            // baseline = 窗口之前的过去均值
            /* baseline 只用窗口前最近 10 s：否则输出刚开时会把“关断期”算进去，一直判成突变 */
            size_t baseIn = (size_t)std::lround(6.0 * sampleRate);
            if (baseIn > (size_t)BASELINE_MAX) baseIn = (size_t)BASELINE_MAX;
            size_t b0 = begin > baseIn ? begin - baseIn : (size_t)0;
            double sum[3] = {0, 0, 0};
            for (size_t k = b0; k < begin; ++k) { sum[0] += hist[k].v; sum[1] += hist[k].i; sum[2] += hist[k].d; }
            size_t nb = begin - b0;
            std::array<double, 3> baseline{0, 0, 0};
            if (nb) baseline = {sum[0] / nb, sum[1] / nb, sum[2] / nb};

            // 重采样到 256 帧（时间上等间隔）
            std::array<float, 768> physical{};
            double vmin = 1e9, vmax = -1e9;
            for (int t = 0; t < WINDOW; ++t) {
                double pos = (count <= 1) ? 0.0 : (double)t * (double)(count - 1) / (double)(WINDOW - 1);
                size_t i0 = begin + (size_t)pos;
                size_t i1 = std::min(i0 + 1, hist.size() - 1);
                double frac = pos - (double)(i0 - begin);
                float v = (float)(hist[i0].v * (1.0 - frac) + hist[i1].v * frac);
                float i = (float)(hist[i0].i * (1.0 - frac) + hist[i1].i * frac);
                float d = (float)(hist[i0].d * (1.0 - frac) + hist[i1].d * frac);
                physical[t * 3 + 0] = v;
                physical[t * 3 + 1] = i;
                physical[t * 3 + 2] = d;
                vmin = std::min<double>(vmin, v);
                vmax = std::max<double>(vmax, v);
            }

            // 预处理（冻结的 train mean/std）+ 量化
            unsigned char *dst = static_cast<unsigned char *>(in->virt_addr);
            for (int t = 0; t < WINDOW; ++t) {
                for (int c = 0; c < 3; ++c) {
                    const float value = physical[t * 3 + c];
                    const float denom = (float)std::max(std::fabs(baseline[c]), FLOORS[c]);
                    const float rel = (float)(((double)value - baseline[c]) / (double)denom);
                    const float norm = (rel - MEAN[c]) / STD[c];
                    dst[c * WINDOW + t] = (unsigned char)square_quantize(
                        norm, in_info.GetQuantizationScale(), in_info.GetQuantizationOffset());
                }
            }
            cma_mem_sync_for_device(in->phys_addr, in->size);

            double t0ms = mono();
            auto st = runtime->EnqueueWorkload(net_id, inputs, outputs);
            double ms = (mono() - t0ms) * 1000.0;
            if (st != armnn::Status::Success) throw std::runtime_error("EnqueueWorkload failed");
            cma_mem_sync_for_cpu(out->phys_addr, out->size);

            const unsigned char *o = static_cast<const unsigned char *>(out->virt_addr);
            unsigned chmax[16] = {0};
            for (int c = 0; c < 16; ++c)
                for (int k = 0; k < 64; ++k) chmax[c] = std::max(chmax[c], (unsigned)o[c * 64 + k]);
            int cls = 0;
            for (int c = 1; c < 3; ++c) if (chmax[c] > chmax[cls]) cls = c;

            /* 输出没开（V 很低、纹波也小）时不要硬分类：写 -1，HMI 显示“无结果” */
            double vmean = 0.0, imean = 0.0, dmean = 0.0;
            for (int t = 0; t < WINDOW; ++t) {
                vmean += physical[t * 3 + 0];
                imean += physical[t * 3 + 1];
                dmean += physical[t * 3 + 2];
            }
            vmean /= (double)WINDOW;
            imean /= (double)WINDOW;
            dmean /= (double)WINDOW;
            if (vmean < 1.0 && (vmax - vmin) < 0.5) {
                char idle[192];
                snprintf(idle, sizeof(idle), "t=%.2f standby Vmean=%.2f -> no result", tEnd, vmean);
                write_status(statusPath, -1, idle);
                printf("[npu] %s\n", idle);
                fflush(stdout);
                continue;
            }

            /* 物理门：模型判“瞬态/振荡”时，要求信号真的有变化，否则按正常处理。
             * 目的：避免在训练分布外（比如 12 V 工况）模型边界抖动导致界面长期报突变。 */
            const double vppRel = (vmax - vmin) / std::max(1.0, vmean);
            const double driftI = std::fabs(imean - baseline[1]) / std::max(0.02, std::fabs(baseline[1]));
            const double driftV = std::fabs(vmean - baseline[0]) / std::max(0.5, std::fabs(baseline[0]));
            bool physicalEvent = false;
            if (cls == 1) physicalEvent = (driftI > 0.15 || driftV > 0.05);
            else if (cls == 2) physicalEvent = (vppRel > 0.05);
            if (cls != 0 && !physicalEvent) cls = 0;   // 没有实际变化就归为正常

            const int code = (cls == 0) ? 0 : 1;      // 0=正常 1=突变
            char extra[256];
            snprintf(extra, sizeof(extra), "t=%.2f class=%s code=%d scores=[%u %u %u] V=%.2f I=%.3f duty=%.3f Vpp=%.2f driftV=%.3f driftI=%.3f win=%zu rate=%.1f ms=%.3f",
                     tEnd, kClasses[cls], code, chmax[0], chmax[1], chmax[2], vmean, imean, dmean, vmax - vmin, driftV, driftI,
                     count, sampleRate, ms);
            /* 去抖：同一个新状态连续出现 2 次才更新显示 */
            if (code == shownCode) {
                pendCode = -2;
                pendCount = 0;
            } else if (code == pendCode) {
                if (++pendCount >= 2) {
                    shownCode = code;
                    pendCode = -2;
                    pendCount = 0;
                }
            } else {
                pendCode = code;
                pendCount = 1;
            }
            if (shownCode == -2 || shownCode != code) {
                char pend[256];
                snprintf(pend, sizeof(pend), "%s (pending %d)", extra, pendCount);
                write_status(statusPath, shownCode == -2 ? code : shownCode, pend);
                printf("[npu] %s\n", pend);
                fflush(stdout);
                continue;
            }
            write_status(statusPath, code, extra);
            printf("[npu] %s\n", extra);
            fflush(stdout);
        }
    } catch (const std::exception &e) {
        fprintf(stderr, "[npu] failed: %s\n", e.what());
        cma_mem_deinit();
        return 1;
    }
    cma_mem_deinit();
    return 0;
}
