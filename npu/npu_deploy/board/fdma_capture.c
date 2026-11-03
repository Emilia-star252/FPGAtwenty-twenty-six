/* fdma_capture.c —— 独立的高采样率采集器（不依赖 power_svc，只读 FDMA 环）
 *
 * 用途：子卡到位后，把 V/I/duty 按指定频率落成 CSV，给三分类模型做 128 Hz 窗口。
 *
 *   /opt/npu/tc/fdma_capture --out /root/data/cap.csv --hz 128 --duration 60
 *
 * 说明：
 *   - 每块 4096B = 256 帧 × 16B（V int48 Q16 / I int48 Q16 / duty uint32）
 *   - 每次循环读 producer，把新块读掉并把 consumer 追到 producer（否则环会满）
 *   - 按 --hz 抽稀输出；实际块率未知时也能自适应
 *   - 只读 GP0/FDMA 的状态寄存器，不写控制寄存器，避免影响 PL
 */
#include <fcntl.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>

#define FD_BASE   0x80010000UL
#define DDR_BASE  0x3FC00000UL
#define BLOCK     4096u
#define FRAMES    256u
#define FB        16u

static volatile uint32_t *fd;
static volatile uint8_t *ring;
static FILE *out;
static int g_peek = 0;   /* >0: 只读最近 N 块，不动 consumer（可与 power_svc 共存） */
static long written;

static void on_fault(int sig) { fprintf(stderr, "[cap] SIG%d (PL/DDR 访问异常)\n", sig); _exit(3); }

static double mono(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + (double)ts.tv_nsec / 1e9;
}

static int64_t dec48(const uint8_t *p) {
    int64_t v = 0;
    for (int k = 0; k < 6; ++k) v |= (int64_t)p[k] << (8 * k);
    if (v & (1LL << 47)) v -= (1LL << 48);
    return v;
}

int main(int argc, char **argv) {
    const char *path = "/root/data/cap.csv";
    double hz = 128.0, duration = 0.0;
    for (int i = 1; i < argc; ++i) {
        if (!strcmp(argv[i], "--out") && i + 1 < argc) path = argv[++i];
        else if (!strcmp(argv[i], "--hz") && i + 1 < argc) hz = atof(argv[++i]);
        else if (!strcmp(argv[i], "--duration") && i + 1 < argc) duration = atof(argv[++i]);
        else if (!strcmp(argv[i], "--peek") && i + 1 < argc) g_peek = atoi(argv[++i]);
        else { fprintf(stderr, "usage: %s [--out FILE] [--hz 128] [--duration SEC] [--peek N]\n", argv[0]); return 2; }
    }
    if (hz <= 0) hz = 128.0;

    signal(SIGBUS, on_fault);
    signal(SIGSEGV, on_fault);

    int m = open("/dev/mem", O_RDWR | O_SYNC);
    if (m < 0) { perror("open /dev/mem"); return 1; }
    long pg = sysconf(_SC_PAGESIZE);
    fd = (volatile uint32_t *)mmap(NULL, 0x1000, PROT_READ | PROT_WRITE, MAP_SHARED, m, (off_t)(FD_BASE & ~(unsigned long)(pg - 1)));
    if (fd == MAP_FAILED) { perror("mmap fdma"); return 1; }
    /* 环基址由 PL 决定，别写死 */
    unsigned long ring_base = ((unsigned long)fd[0x14 / 4] << 32) | fd[0x10 / 4];
    if (ring_base == 0) ring_base = DDR_BASE;
    ring = (volatile uint8_t *)mmap(NULL, 4 * 1024 * 1024, PROT_READ, MAP_SHARED, m, (off_t)ring_base);
    if (ring == MAP_FAILED) { perror("mmap ring"); return 1; }
    printf("[fdma] ring_base=0x%lx (from FD_BASE registers)\n", ring_base);

    uint32_t id = fd[0x00 / 4], fmt = fd[0x28 / 4], st = fd[0x08 / 4];
    printf("[cap] FDMA id=0x%08x format=0x%08x status=0x%08x slots=%u\n",
           id, fmt, st, fd[0x18 / 4]);
    if (id != 0x46444D31u || fmt != 0x50343831u) {
        fprintf(stderr, "[cap] FDMA 标识不对，PL 位流可能不是这一版\n");
        return 1;
    }

    out = fopen(path, "w");
    if (!out) { perror(path); return 1; }
    fprintf(out, "uptime_s,v_out,i_out,duty\n");
    fflush(out);

    const double t0 = mono();
    const uint32_t peek = (g_peek > 0) ? (uint32_t)g_peek : 0;
    uint32_t cons = fd[0x20 / 4];          /* 消费模式：从当前消费点开始 */
    uint32_t last = peek ? (fd[0x1C / 4] - peek) : 0;   /* 观察模式：只看最近 peek 块 */
    double last_emit = -1e9;
    unsigned long blocks = 0, samples = 0;
    int idle_loops = 0;

    while (duration <= 0.0 || mono() - t0 < duration) {
        uint32_t prod = fd[0x1C / 4];
        uint32_t begin;
        if (peek) {
            if ((uint32_t)(prod - last) > peek) last = prod - peek;   /* 落后太多就跳 */
            begin = last;
        } else {
            begin = cons;
            if ((uint32_t)(prod - begin) > 64) begin = prod - 64;     /* 落后太多就跳 */
        }
        if (begin == prod) {
            if (++idle_loops > 2000 && blocks == 0) {
                fprintf(stderr, "[cap] producer 一直不动（%u），PL 没有在产采样\n", prod);
                break;
            }
            usleep(200);
            continue;
        }
        idle_loops = 0;
        uint32_t slots = fd[0x18 / 4];
        for (uint32_t idx = begin; idx != prod; ++idx) {
            uint32_t slot = idx & (slots - 1u);
            const uint8_t *blk = (const uint8_t *)ring + (size_t)slot * BLOCK;
            const uint8_t *f = blk + (FRAMES - 1u) * FB;     /* 取该块最新一帧 */
            double now = mono();
            if (now - last_emit >= 1.0 / hz) {
                int64_t vq = dec48(f), iq = dec48(f + 6);
                uint32_t dq = (uint32_t)f[12] | ((uint32_t)f[13] << 8) |
                              ((uint32_t)f[14] << 16) | ((uint32_t)f[15] << 24);
                fprintf(out, "%.4f,%.4f,%.4f,%.3f\n", now - t0, (double)vq / 65536.0,
                        (double)iq / 65536.0, (double)dq * 100.0 / 65536.0);
                last_emit = now;
                samples++;
                if ((written = ftell(out)) < 0 || samples % 64 == 0) fflush(out);
            }
            blocks++;
            if (!peek) cons = idx + 1;
        }
        if (peek) last = prod;
        else fd[0x20 / 4] = cons;          /* 归还 consumer，防止环满 */
    }

    fflush(out);
    fclose(out);
    double dt = mono() - t0;
    printf("[cap] %.1fs: %lu blocks, %lu samples -> %.1f Hz 实际采样率, 文件 %s\n",
           dt, blocks, samples, samples / (dt > 0 ? dt : 1), path);
    if (blocks == 0) printf("[cap] 没有数据：确认子卡/ADC 是否在产帧\n");
    return blocks ? 0 : 2;
}
