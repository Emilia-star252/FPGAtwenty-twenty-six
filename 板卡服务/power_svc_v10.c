/* ============================================================================
 * power_svc.c —— DC-DC 智能电源监测与故障诊断系统【板卡侧服务】 v2
 *
 * v2 新增（对接 PL 组《AXI 接口交接说明》）：
 *   --pl mmap          真实读取 PL 寄存器（mmap /dev/mem @ 0x80000000）
 *                      启动校验三个识别值；同帧读取（SAMPLE_COUNT 前后比对）；
 *                      等 0x04.bit6（已捕获至少一帧）后才发布有效采样
 *   输出控制按文档时序：先写 0x44 非零给定 → 再写 0x40=1；实际状态读 0x4C.bit1
 *   给定上限 48 V（0x58）；回读并清除 0x5C 非法命令标志
 *   未实现项按"不支持"处理：电流给定（SET_SETPOINT.i_set≠0）、清故障
 *   新增 CMD_SET_TIME(0x06)：上位机下发 Unix 秒，板卡 settimeofday + 换当天 CSV
 *
 * 编译（虚拟机）：
 *   gcc -O2 -o /tmp/power_svc_x86 power_svc.c -lm && /tmp/power_svc_x86 --selftest
 *   ~/uisrc-lab-anlogic/tools/aarch64-linux/bin/aarch64-linux-gnu-gcc \
 *       -O2 -static -s -o power_svc power_svc.c -lm
 *
 * 运行（板子）：
 *   ./power_svc --selftest
 *   ./power_svc --tcp 5000 --pl sim      # 假数据（现在可演示）
 *   ./power_svc --tcp 5000 --pl mmap     # 真实寄存器（PL 位流到位后）
 * ==========================================================================*/
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <unistd.h>
#include <errno.h>
#include <fcntl.h>
#include <time.h>
#include <math.h>
#include <signal.h>
#include <poll.h>
#include <termios.h>
#include <sys/mman.h>
#include <sys/time.h>
#include <sys/socket.h>
#include <netdb.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
/* ---- SocketCAN（CAN 应用层，2026-10-22 新增）---- */
#include <linux/can.h>
#include <linux/can/raw.h>
#include <net/if.h>
#include <sys/ioctl.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

/* ========================== 协议常量（对齐 protocol.py） ================== */
#define SOF1            0xAA
#define SOF2            0x55
#define MAX_PAYLOAD     64
#define MIN_LEN         2
#define MAX_LEN         (MIN_LEN + MAX_PAYLOAD)   /* 66 */
#define FRAME_OVERHEAD  5

#define CMD_READ_STATUS  0x01
#define CMD_SET_SETPOINT 0x02
#define CMD_SET_OUTPUT   0x03
#define CMD_HEARTBEAT    0x04
#define CMD_CLEAR_FAULT  0x05
#define CMD_SET_TIME     0x06
#define CMD_ACK          0x81
#define CMD_STATUS       0x82
#define CMD_NACK         0x83
#define CMD_TEXT         0x84

#define FLAG_RUNNING     (1u << 0)
#define FLAG_OUTPUT_EN   (1u << 1)
#define FLAG_OVP         (1u << 2)
#define FLAG_OCP         (1u << 3)
#define FLAG_OTP         (1u << 4)
#define FLAG_HOST_ONLINE (1u << 5)
#define FLAG_LOG_OK      (1u << 6)

#define FAULT_NONE     0
#define FAULT_OVP      1
#define FAULT_OCP      2
#define FAULT_OTP      3
#define FAULT_ADC      4    /* ADC 故障锁存（PL 0x4C.bit3） */
#define FAULT_OVERRUN  5    /* 控制采样溢出（PL 0x4C.bit6） */

#define ACK_OK            0
#define ACK_BAD_PARAM     1
#define ACK_FAULT_LATCHED 2
#define ACK_UNSUPPORTED   3

#define STATUS_PAYLOAD_SIZE 26
#define CSV_HEADER "timestamp,uptime_s,v_out,i_out,duty,v_set,i_set,flags,fault"

/* ==================== PL 寄存器（《AXI 接口交接说明》基址 0x80000000） ==== */
#define PL_BASE_DEFAULT     0x80000000UL
#define PL_ID_ADC1          0x00    /* 0x41444331 */
#define PL_ADC_STATUS       0x04
#define PL_SAMPLE_COUNT     0x08
/* 2026-10-20 版：0x0C/0x10/0x14/0x18/0x48 已"退休"，读它们返回 SLVERR
 * —— 在 Linux 上会触发总线错误，绝对不能读！V/I/duty 改从 DDR（FDMA）取。 */
#define PL_FIFO_STATUS      0x20    /* bit2 = 采集 FIFO 复位忙 */
#define PL_FIFO_LEVEL       0x24    /* 单位：32 位字 */
#define PL_FIFO_DATA        0x28    /* 旧 CPU 流已断开 → 实际 SLVERR */
#define PL_FIFO_CTRL        0x2C    /* RW bit0=采集使能 bit1=清 FIFO 脉冲 */
#define PL_FIFO_DROP        0x30    /* 丢新整帧累计 */
#define PL_FIFO_FORMAT      0x34    /* RO = 0x50343831 (P481) */
#define PL_OUT_CTRL         0x40    /* RW bit0: 1 请求开（需 vref!=0 且无故障，否则 SLVERR） */
#define PL_VREF             0x44    /* RW Q16，0..64V；写 0 会自动关输出 */
#define PL_OUT_STATUS       0x4C    /* RO 位图（实时） */
#define PL_VREF_RAMP        0x50    /* RO int32 Q16（斜坡给定） */
#define PL_ID_CTR1          0x54    /* 0x43545231 */
#define PL_VREF_MAX         0x58    /* RO = 4194304 (64.0 V) */
#define PL_ILLEGAL_CMD      0x5C    /* W1C bit0：非法命令标志（独立于保护故障） */
#define PL_FAULT_CLEAR      0x60    /* W1P：写 1 请求清过流/过压（硬件先关输出+清给定） */
#define PL_FAULT_ID         0x64    /* RO = 0x464C5431 (FLT1) 能力标识 */

#define PL_ID_ADC1_VAL      0x41444331u
#define PL_ID_P481_VAL      0x50343831u
#define PL_ID_CTR1_VAL      0x43545231u
#define PL_FAULT_ID_VAL     0x464C5431u

/* ---------------- FDMA（自定义采集 DMA）@ PL_BASE + 0x10000 ---------------- */
#define FDMA_BASE_DEFAULT   0x80010000UL
#define FD_ID               0x00    /* RO = 0x46444D31 (FDM1) */
#define FD_CONTROL          0x04    /* RW 1=运行 0=停止 2=排空复位；读 bit1=复位未完成 */
#define FD_STATUS           0x08    /* bit0 运行 bit1 忙 bit2 环满 bit3 错误 bit4 配置有效 */
#define FD_ERROR            0x0C    /* bit1 AXI/ID 错 bit2 帧格式错 bit4 停止致不完整 */
#define FD_BASE_LO          0x10    /* RW 环物理地址低 32 位 */
#define FD_BASE_HI          0x14    /* RW 仅 bit0 */
#define FD_RING_SLOTS       0x18    /* RW 2..65536，2 的幂，每槽 4096B */
#define FD_PRODUCER         0x1C    /* RO 已完成块计数 */
#define FD_CONSUMER         0x20    /* RW 已消费块计数（不能超过 producer） */
#define FD_BLOCK_BYTES_REG  0x24    /* RO = 4096 */
#define FD_FORMAT           0x28    /* RO = 0x50343831 (P481) */
#define FD_ID_VAL           0x46444D31u
#define FD_FORMAT_VAL       0x50343831u
#define FD_CTRL_STOP        0u
#define FD_CTRL_RUN         1u
#define FD_CTRL_RESET       2u
#define FDST_RUN            (1u << 0)
#define FDST_BUSY           (1u << 1)
#define FDST_FULL           (1u << 2)
#define FDST_ERROR          (1u << 3)
#define FDST_CONFIG         (1u << 4)
#define FD_CTRL_RESET_BUSY  (1u << 1)

#define FDM_FRAME_BYTES     16u     /* P481：V(6B int48 Q16) + I(6B int48 Q16) + duty(4B) */
#define FDM_BLOCK_FRAMES    256u
#define FDM_BLOCK_BYTES     4096u

/* DDR 采样环：由 DTS reserved-memory 预留，这里只做默认值 */
#define DDR_RING_BASE_DEFAULT  0x3FC00000UL   /* 1GB DDR 的最后 4MB */
#define DDR_RING_SLOTS_DEFAULT 1024u          /* 1024 × 4096B = 4MB */

/* 0x4C OUTPUT_STATUS 位 */
#define PLST_OUTPUT_REQUEST (1u << 0)
#define PLST_OUTPUT_ACTIVE  (1u << 1)   /* ★ 界面"输出开"看这一位 */
#define PLST_ADC_INIT       (1u << 2)
#define PLST_ADC_ERROR      (1u << 3)   /* ADC 驱动故障：需系统复位 */
#define PLST_PLL_LOCKED     (1u << 4)
#define PLST_PWM_ARMED      (1u << 5)
#define PLST_SAMPLE_OVERRUN (1u << 6)
#define PLST_OCP            (1u << 7)   /* 实际电流 >4A，过流锁存（2026-10-15 新增） */
#define PLST_OVP            (1u << 8)   /* 实际电压 >80V，过压锁存（2026-10-15 新增） */

/* 需要软件清除 / 阻止开启的故障位（= DCDC_SHUTDOWN_FAULTS） */
#define PL_SHUTDOWN_FAULTS  (PLST_ADC_ERROR | PLST_OCP | PLST_OVP)   /* 0x188 */

/* 0x04 ADC_STATUS 位 */
#define ADCST_FRAME_CAPTURED (1u << 6)  /* ★ 首次上报前必须为 1 */

#define PL_VREF_LIMIT_V     64.0f   /* 2026-10-20 版硬件上限 64V（0x58=4194304） */

/* ========================== 小工具 ======================================= */
static double mono(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + (double)ts.tv_nsec * 1e-9;
}
static void put_u16(uint8_t *p, uint16_t v) { p[0] = (uint8_t)(v & 0xFF); p[1] = (uint8_t)((v >> 8) & 0xFF); }
static uint16_t get_u16(const uint8_t *p) { return (uint16_t)(p[0] | ((uint16_t)p[1] << 8)); }
static void put_f32(uint8_t *p, float f) { memcpy(p, &f, 4); }   /* aarch64 小端 */
static float get_f32(const uint8_t *p) { float f; memcpy(&f, p, 4); return f; }

static uint16_t crc16_modbus(const uint8_t *d, size_t n) {
    uint16_t crc = 0xFFFF;
    for (size_t i = 0; i < n; i++) {
        crc ^= d[i];
        for (int b = 0; b < 8; b++)
            crc = (crc & 1) ? (uint16_t)((crc >> 1) ^ 0xA001) : (uint16_t)(crc >> 1);
    }
    return crc;
}

/* 组帧：返回整帧长度（= LEN + 5）；CRC 覆盖 LEN,CMD,SEQ,PAYLOAD 共 LEN+1 字节 */
static size_t build_frame(uint8_t *out, uint8_t cmd, const uint8_t *pl, size_t n, uint8_t seq) {
    if (n > MAX_PAYLOAD) n = MAX_PAYLOAD;
    uint8_t len = (uint8_t)(MIN_LEN + n);
    out[0] = SOF1; out[1] = SOF2; out[2] = len; out[3] = cmd; out[4] = seq;
    if (n) memcpy(out + 5, pl, n);
    uint16_t crc = crc16_modbus(out + 2, (size_t)len + 1);
    out[5 + n] = (uint8_t)(crc & 0xFF);
    out[6 + n] = (uint8_t)((crc >> 8) & 0xFF);
    return (size_t)len + FRAME_OVERHEAD;
}

/* ========================== 增量解析器 ================================== */
typedef struct { uint8_t cmd, seq; uint8_t payload[MAX_PAYLOAD]; size_t plen; } frame_t;
typedef struct {
    uint8_t buf[1024]; size_t len;
    unsigned long crc_errors, resyncs, frames_ok, bytes_dropped;
} parser_t;

static void parser_push(parser_t *p, const uint8_t *d, size_t n) {
    if (p->len + n > sizeof(p->buf)) {
        size_t drop = p->len + n - sizeof(p->buf);
        if (drop >= p->len) { p->len = 0; }
        else { memmove(p->buf, p->buf + drop, p->len - drop); p->len -= drop; p->bytes_dropped += drop; }
    }
    memcpy(p->buf + p->len, d, n);
    p->len += n;
}

static int parser_next(parser_t *p, frame_t *out) {
    for (;;) {
        size_t idx = (size_t)-1;
        for (size_t i = 0; i + 1 < p->len; i++)
            if (p->buf[i] == SOF1 && p->buf[i + 1] == SOF2) { idx = i; break; }
        if (idx == (size_t)-1) {
            if (p->len > 1) { size_t d = p->len - 1; memmove(p->buf, p->buf + d, 1); p->len = 1; p->bytes_dropped += d; }
            return 0;
        }
        if (idx > 0) { memmove(p->buf, p->buf + idx, p->len - idx); p->len -= idx; p->bytes_dropped += idx; p->resyncs++; }
        if (p->len < 3) return 0;
        uint8_t len = p->buf[2];
        if (len < MIN_LEN || len > MAX_LEN) { p->len--; memmove(p->buf, p->buf + 1, p->len); p->bytes_dropped++; p->resyncs++; continue; }
        size_t total = (size_t)len + FRAME_OVERHEAD;
        if (p->len < total) return 0;
        uint16_t calc = crc16_modbus(p->buf + 2, (size_t)len + 1);
        if (calc != get_u16(p->buf + total - 2)) {
            p->crc_errors++; p->len--; memmove(p->buf, p->buf + 1, p->len); p->bytes_dropped++; p->resyncs++; continue;
        }
        out->cmd = p->buf[3]; out->seq = p->buf[4]; out->plen = (size_t)len - MIN_LEN;
        if (out->plen) memcpy(out->payload, p->buf + 5, out->plen);
        p->len -= total; memmove(p->buf, p->buf + total, p->len); p->frames_ok++;
        return 1;
    }
}

/* ========================== 板卡状态 ===================================== */
typedef struct {
    uint16_t flags;
    float v_out, i_out, duty, v_set, i_set;
    uint16_t fault, reserved;     /* reserved = PL 状态位图快照（0x4C） */
} status_t;

static size_t status_encode(const status_t *s, uint8_t *out) {
    put_u16(out + 0, s->flags);
    put_f32(out + 2, s->v_out);
    put_f32(out + 6, s->i_out);
    put_f32(out + 10, s->duty);
    put_f32(out + 14, s->v_set);
    put_f32(out + 18, s->i_set);
    put_u16(out + 22, s->fault);
    put_u16(out + 24, s->reserved);
    return STATUS_PAYLOAD_SIZE;
}

/* ========================== CSV 日志 ===================================== */
typedef struct {
    FILE *fp; char path[512]; long written; long max_bytes;
    double last_fsync; int ok; char last_error[128]; unsigned long rows;
} csv_t;

static void mkdir_p(const char *dir) {
    char tmp[512]; snprintf(tmp, sizeof(tmp), "%s", dir);
    for (char *p = tmp + 1; *p; p++) if (*p == '/') { *p = 0; mkdir(tmp, 0755); *p = '/'; }
    mkdir(tmp, 0755);
}

static void csv_default_path(char *out, size_t n) {
    time_t t = time(NULL); struct tm tm; localtime_r(&t, &tm);
    snprintf(out, n, "/root/data/power_%04d%02d%02d.csv", tm.tm_year + 1900, tm.tm_mon + 1, tm.tm_mday);
}

static int csv_rotate(csv_t *c) {
    if (c->fp) { fclose(c->fp); c->fp = NULL; }
    char bak[600]; snprintf(bak, sizeof(bak), "%s.1", c->path);
    remove(bak); rename(c->path, bak);
    c->fp = fopen(c->path, "a");
    if (!c->fp) { c->ok = 0; snprintf(c->last_error, sizeof(c->last_error), "%s", strerror(errno)); return -1; }
    fputs(CSV_HEADER "\n", c->fp); fflush(c->fp);
    c->written = (long)strlen(CSV_HEADER) + 1;
    return 0;
}

static int csv_open(csv_t *c, const char *path, long max_bytes) {
    unsigned long rows = c->rows;
    memset(c, 0, sizeof(*c));
    c->rows = rows;
    snprintf(c->path, sizeof(c->path), "%s", path);
    c->max_bytes = max_bytes > 0 ? max_bytes : 5L * 1024 * 1024;

    char dir[512]; snprintf(dir, sizeof(dir), "%s", c->path);
    char *slash = strrchr(dir, '/');
    if (slash) { *slash = 0; if (dir[0]) mkdir_p(dir); }

    int need_header = 1; struct stat sb;
    if (stat(c->path, &sb) == 0 && sb.st_size > 0) { need_header = 0; c->written = (long)sb.st_size; }
    c->fp = fopen(c->path, "a");
    if (!c->fp) { c->ok = 0; snprintf(c->last_error, sizeof(c->last_error), "%s", strerror(errno)); return -1; }
    if (need_header) { fputs(CSV_HEADER "\n", c->fp); fflush(c->fp); c->written += (long)strlen(CSV_HEADER) + 1; }
    c->ok = 1; c->last_fsync = mono();
    return 0;
}

static void csv_log(csv_t *c, double uptime_s, const status_t *s) {
    if (!c->ok) return;
    if (c->written >= c->max_bytes) { if (csv_rotate(c) < 0) return; }
    char ts[32]; time_t t = time(NULL); struct tm tm;
    localtime_r(&t, &tm); strftime(ts, sizeof(ts), "%Y-%m-%d %H:%M:%S", &tm);
    int n = fprintf(c->fp, "%s,%.3f,%.4f,%.4f,%.4f,%.4f,%.4f,%u,%u\n",
                    ts, uptime_s, (double)s->v_out, (double)s->i_out, (double)s->duty,
                    (double)s->v_set, (double)s->i_set, (unsigned)s->flags, (unsigned)s->fault);
    if (n > 0) { c->written += n; c->rows++; }
    fflush(c->fp);
    double now = mono();
    if (now - c->last_fsync >= 5.0) { fsync(fileno(c->fp)); c->last_fsync = now; }
}

static void csv_close(csv_t *c) {
    if (c->fp) { fflush(c->fp); fsync(fileno(c->fp)); fclose(c->fp); c->fp = NULL; }
}

/* ========================== PL 寄存器访问层 ============================= */
/* GP0（控制/状态 0x80000000）+ FDMA（0x80010000）+ DDR 采样环，一次映射好 */
typedef struct {
    int fd;
    volatile uint32_t *reg;       /* GP0 */
    volatile uint32_t *fdma;      /* FDMA */
    volatile uint8_t  *ring;      /* DDR 环（uncached） */
    unsigned long base;
    uint32_t ring_phys;
    uint32_t ring_slots;
    int ok;
} pl_t;

static int pl_open(pl_t *pl, unsigned long base, unsigned long ddr_base, uint32_t slots) {
    memset(pl, 0, sizeof(*pl));
    pl->fd = -1;
    pl->base = base;
    pl->ring_phys = (uint32_t)ddr_base;
    pl->ring_slots = slots;
    pl->fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (pl->fd < 0) return -1;
    /* GP0 与 FDMA 相邻，一次映射 128KB（0x80000000..0x8001FFFF） */
    void *p = mmap(NULL, 0x20000, PROT_READ | PROT_WRITE, MAP_SHARED, pl->fd, (off_t)base);
    if (p == MAP_FAILED) { close(pl->fd); pl->fd = -1; return -2; }
    pl->reg  = (volatile uint32_t *)p;
    pl->fdma = (volatile uint32_t *)((volatile uint8_t *)p + 0x10000);
    /* DDR 采样环：只读（PL 写，CPU 读）；/dev/mem 映射为 uncached，无需刷缓存 */
    size_t rsz = (size_t)slots * FDM_BLOCK_BYTES;
    void *r = mmap(NULL, rsz, PROT_READ, MAP_SHARED, pl->fd, (off_t)ddr_base);
    if (r == MAP_FAILED) {
        munmap((void *)pl->reg, 0x20000);
        close(pl->fd); pl->fd = -1;
        return -3;
    }
    pl->ring = (volatile uint8_t *)r;
    pl->ok = 1;
    return 0;
}

static void pl_close(pl_t *pl) {
    if (pl->ring) { munmap((void *)pl->ring, (size_t)pl->ring_slots * FDM_BLOCK_BYTES); pl->ring = NULL; }
    if (pl->reg)  { munmap((void *)pl->reg, 0x20000); pl->reg = NULL; pl->fdma = NULL; }
    if (pl->fd >= 0) { close(pl->fd); pl->fd = -1; }
    pl->ok = 0;
}

static uint32_t pl_rd(const pl_t *pl, uint32_t off) { return pl->reg[off >> 2]; }
static void pl_wr(const pl_t *pl, uint32_t off, uint32_t val) { pl->reg[off >> 2] = val; }
static uint32_t fd_rd(const pl_t *pl, uint32_t off) { return pl->fdma[off >> 2]; }
static void fd_wr(const pl_t *pl, uint32_t off, uint32_t val) { pl->fdma[off >> 2] = val; }

/* P481 有符号 48 位小端解码（符号扩展到 64 位） */
static int64_t fd_decode_s48(const uint8_t *p) {
    uint64_t v = 0;
    for (int k = 0; k < 6; k++) v |= (uint64_t)p[k] << (k * 8);
    return (v & ((uint64_t)1 << 47)) ? (int64_t)v - ((int64_t)1 << 48) : (int64_t)v;
}

static int pl_check_ids(const pl_t *pl, int verbose) {
    uint32_t a  = pl_rd(pl, PL_ID_ADC1);
    uint32_t c  = pl_rd(pl, PL_ID_CTR1);
    uint32_t p4 = pl_rd(pl, PL_FIFO_FORMAT);
    uint32_t fm = fd_rd(pl, FD_ID);
    uint32_t fl = pl_rd(pl, PL_FAULT_ID);
    int ok = (a == PL_ID_ADC1_VAL && c == PL_ID_CTR1_VAL &&
              p4 == PL_ID_P481_VAL && fm == FD_ID_VAL);
    if (verbose || !ok)
        printf("[板卡] PL 识别值: ADC1=0x%08X CTR1=0x%08X P481=0x%08X FDM1=0x%08X FLT1=0x%08X -> %s\n",
               a, c, p4, fm, fl, ok ? "匹配" : "不匹配");
    return ok ? 0 : -1;
}

/* 启动采集（严格按交接文档顺序）：
 * 停采集 → FDMA 排空复位 → 清 FIFO → 配环 → FDMA 运行 → 开采集 */
static int pl_capture_start(pl_t *pl, int verbose) {
    pl_wr(pl, PL_FIFO_CTRL, 0u);                 /* 停上传 */
    fd_wr(pl, FD_CONTROL, FD_CTRL_RESET);        /* 排空复位 */
    int t = 0;
    while ((fd_rd(pl, FD_CONTROL) & FD_CTRL_RESET_BUSY) && t < 500) { usleep(1000); t++; }
    if (fd_rd(pl, FD_CONTROL) & FD_CTRL_RESET_BUSY) {
        fprintf(stderr, "[错误] FDMA 排空复位超时（%d ms）\n", t);
        return -1;
    }
    pl_wr(pl, PL_FIFO_CTRL, 2u);                 /* 清 FIFO 脉冲 */
    t = 0;
    while ((pl_rd(pl, PL_FIFO_STATUS) & (1u << 2)) && t < 500) { usleep(1000); t++; }

    /* 配环：必须 32 位对齐写，且此时停止/空闲/producer==consumer */
    fd_wr(pl, FD_BASE_LO, pl->ring_phys);
    fd_wr(pl, FD_BASE_HI, 0u);
    fd_wr(pl, FD_RING_SLOTS, pl->ring_slots);
    if (!(fd_rd(pl, FD_STATUS) & FDST_CONFIG)) {
        fprintf(stderr, "[错误] FDMA 配置无效：base=0x%08X slots=%u status=0x%X\n",
                pl->ring_phys, pl->ring_slots, fd_rd(pl, FD_STATUS));
        return -2;
    }
    fd_wr(pl, FD_CONTROL, FD_CTRL_RUN);
    if (!(fd_rd(pl, FD_STATUS) & FDST_RUN)) {
        fprintf(stderr, "[错误] FDMA 启动被拒：status=0x%X error=0x%X\n",
                fd_rd(pl, FD_STATUS), fd_rd(pl, FD_ERROR));
        return -3;
    }
    pl_wr(pl, PL_FIFO_CTRL, 1u);                 /* 开采集 */
    if (verbose)
        printf("[板卡] 采集已启动：DDR 环 0x%08X × %u 槽（%u KB）；FIFO_LEVEL=%u word\n",
               pl->ring_phys, pl->ring_slots, pl->ring_slots * 4u, pl_rd(pl, PL_FIFO_LEVEL));
    return 0;
}

/* 从 DDR 环取已完成块 → 解析 P481 → 返回最新一帧的 V/I/duty。
 * 返回 0 表示取到新数据；-1 表示暂无新块（沿用上一帧）。
 * 积压超过 4 块时丢弃中间块，只保留最新 4 块，保证显示延迟。 */
/* ---------------- DCD1 TCP stream for the PC web monitor (port 9900) -------- */
static int      g_dcd1_fd = -1;
static char     g_dcd1_host[64] = {0};
static uint16_t g_dcd1_port = 9900;
static uint32_t g_dcd1_rate = 113000;
static uint64_t g_dcd1_seq  = 0;
static unsigned long g_dcd1_pkts = 0, g_dcd1_net_drop = 0;

static void dcd1_put16(uint8_t *p, uint16_t v) { p[0] = (uint8_t)(v & 0xFF); p[1] = (uint8_t)((v >> 8) & 0xFF); }
static void dcd1_put32(uint8_t *p, uint32_t v) { for (int i = 0; i < 4; i++) p[i] = (uint8_t)(v >> (8 * i)); }
static void dcd1_put64(uint8_t *p, uint64_t v) { for (int i = 0; i < 8; i++) p[i] = (uint8_t)(v >> (8 * i)); }

static int dcd1_connect(void)
{
    struct addrinfo hints, *res = NULL;
    char ports[16];
    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    snprintf(ports, sizeof(ports), "%u", (unsigned)g_dcd1_port);
    if (getaddrinfo(g_dcd1_host, ports, &hints, &res) != 0) return -1;
    for (struct addrinfo *a = res; a; a = a->ai_next) {
        int s = socket(a->ai_family, a->ai_socktype, a->ai_protocol);
        if (s < 0) continue;
        struct timeval tv = {5, 0};
        setsockopt(s, SOL_SOCKET, SO_SNDTIMEO, &tv, sizeof(tv));
        if (connect(s, a->ai_addr, a->ai_addrlen) == 0) {
            int fl = fcntl(s, F_GETFL, 0); fcntl(s, F_SETFL, fl | O_NONBLOCK);
            int one = 1; setsockopt(s, IPPROTO_TCP, TCP_NODELAY, &one, sizeof(one));
            g_dcd1_fd = s;
            freeaddrinfo(res);
            printf("[dcd1] connected %s:%u  nominal_rate=%u Hz\n", g_dcd1_host, (unsigned)g_dcd1_port, g_dcd1_rate);
            return 0;
        }
        close(s);
    }
    freeaddrinfo(res);
    return -1;
}

/* send one 4096-byte FDMA block as one DCD1 packet (32B header + 256 P481 frames) */
static void dcd1_send_block(const uint8_t *blk, uint32_t drop)
{
    if (g_dcd1_fd < 0) return;
    uint8_t buf[32 + FDM_BLOCK_BYTES];
    memcpy(buf, "DCD1", 4);
    dcd1_put16(buf + 4, 1);                       /* version */
    dcd1_put16(buf + 6, 0);                       /* mode 0 = live */
    dcd1_put32(buf + 8, g_dcd1_rate);             /* nominal rate */
    dcd1_put64(buf + 12, g_dcd1_seq);             /* first sample index */
    dcd1_put32(buf + 20, FDM_BLOCK_FRAMES);       /* 256 */
    dcd1_put32(buf + 24, drop);                   /* source drop counter */
    dcd1_put32(buf + 28, 0);
    memcpy(buf + 32, blk, FDM_BLOCK_BYTES);

    /* clamp duty to 0..65535 (Q16 fraction) so the PC decoder never rejects a packet */
    for (unsigned k = 0; k < FDM_BLOCK_FRAMES; ++k) {
        uint8_t *fr = buf + 32 + k * FDM_FRAME_BYTES + 12;
        uint32_t d = (uint32_t)fr[0] | ((uint32_t)fr[1] << 8) |
                     ((uint32_t)fr[2] << 16) | ((uint32_t)fr[3] << 24);
        if (d > 65535u) { fr[0] = 0xFF; fr[1] = 0xFF; fr[2] = 0x00; fr[3] = 0x00; }
    }

    size_t n = sizeof(buf), off = 0;
    while (off < n) {
        ssize_t w = write(g_dcd1_fd, buf + off, n - off);
        if (w > 0) { off += (size_t)w; continue; }
        if (w < 0 && (errno == EAGAIN || errno == EWOULDBLOCK)) {
            g_dcd1_net_drop++;
            g_dcd1_seq += FDM_BLOCK_FRAMES;       /* keep index monotonic -> web shows a gap */
            return;
        }
        if (w < 0 && errno == EINTR) continue;
        close(g_dcd1_fd); g_dcd1_fd = -1;
        return;
    }
    g_dcd1_seq += FDM_BLOCK_FRAMES;
    g_dcd1_pkts++;
}

static int pl_read_sample(pl_t *pl, float *v, float *i, float *duty, uint32_t *new_blocks) {
    uint32_t prod = fd_rd(pl, FD_PRODUCER);
    uint32_t cons = fd_rd(pl, FD_CONSUMER);
    uint32_t avail = prod - cons;                    /* 无符号减法，自动处理回绕 */
    if (new_blocks) *new_blocks = 0;
    if (avail == 0) return -1;
    if (avail > pl->ring_slots) avail = pl->ring_slots;   /* 防御 */

    if (avail > 4) {                                  /* 积压过多：丢掉旧的 */
        uint32_t skip = avail - 4;
        cons += skip;
        fd_wr(pl, FD_CONSUMER, cons);
        avail -= skip;
    }

    int got = 0;
    while (avail > 0) {
        uint32_t slot = cons & (pl->ring_slots - 1u);
        const uint8_t *blk = (const uint8_t *)pl->ring + (size_t)slot * FDM_BLOCK_BYTES;
        if (g_dcd1_fd >= 0) dcd1_send_block(blk, pl_rd(pl, PL_FIFO_DROP));
        /* 取该块最后一帧（最新采样） */
        const uint8_t *f = blk + (FDM_BLOCK_FRAMES - 1u) * FDM_FRAME_BYTES;
        int64_t vq = fd_decode_s48(f);
        int64_t iq = fd_decode_s48(f + 6);
        uint32_t dq = (uint32_t)f[12] | ((uint32_t)f[13] << 8) |
                      ((uint32_t)f[14] << 16) | ((uint32_t)f[15] << 24);
        *v = (float)((double)vq / 65536.0);
        *i = (float)((double)iq / 65536.0);
        *duty = (float)((double)dq * 100.0 / 65536.0);
        cons++; avail--; got++;
    }
    fd_wr(pl, FD_CONSUMER, cons);                     /* 归还：不能超过 producer */
    if (new_blocks) *new_blocks = (uint32_t)got;
    return got ? 0 : -1;
}

static int pl_set_vref(const pl_t *pl, float v) {
    if (!(v >= 0.0f && v <= PL_VREF_LIMIT_V)) return -1;
    int32_t q = (int32_t)lroundf(v * 65536.0f);
    if (q == 0) pl_wr(pl, PL_OUT_CTRL, 0u);          /* 给 0 时先关输出（硬件也是这个语义） */
    pl_wr(pl, PL_VREF, (uint32_t)q);
    return 0;
}
static void pl_output_on(const pl_t *pl) { pl_wr(pl, PL_OUT_CTRL, 1u); }
static void pl_output_off(const pl_t *pl) { pl_wr(pl, PL_OUT_CTRL, 0u); }
static int pl_output_active(const pl_t *pl) { return (pl_rd(pl, PL_OUT_STATUS) & PLST_OUTPUT_ACTIVE) ? 1 : 0; }
static int pl_illegal_flag(const pl_t *pl) { return (pl_rd(pl, PL_ILLEGAL_CMD) & 1u) ? 1 : 0; }
static void pl_clear_illegal(const pl_t *pl) { pl_wr(pl, PL_ILLEGAL_CMD, 1u); }   /* W1C */

/* 用户态看不到 AXI bresp：PL 用 SLVERR 拒绝非法写时会置 0x5C.bit0，
 * 读出来（顺带清掉）就能判断"这次写到底成没成"。 */
static int pl_took_error(const pl_t *pl) {
    if (pl_rd(pl, PL_ILLEGAL_CMD) & 1u) { pl_wr(pl, PL_ILLEGAL_CMD, 1u); return 1; }
    return 0;
}

/* ========================== 板卡模型（sim 数据源） ====================== */
#define V_BUS_DEFAULT 24.0f
#define OVP_RATIO     1.15f
#define I_TRIP        6.0f
#define T_TRIP        85.0f
#define HOST_TIMEOUT  3.0

typedef struct {
    double t;
    float v_set, i_set, v_out, i_out, duty, temp;
    int output_en;
    uint16_t fault;
    int host_online;
    double last_host_rx;
    unsigned long rx_frames, tx_frames, trips, host_drops, frame_retry_fail;
    int use_pl;
    int has_flt1;              /* 位流是否带 0x60/0x64 清故障寄存器（FLT1 能力） */
    unsigned long blocks_rx;   /* 已从 DDR 环消费的采样块数 */
    uint32_t fdma_err;         /* FDMA 粘滞错误（首次记录） */
    pl_t pl;
} board_t;

static void model_step(board_t *b, double dt) {
    if (dt > 0.2) dt = 0.2;
    double r_load = 10.0 * (1.0 + 0.25 * sin(2.0 * M_PI * 0.05 * b->t));
    float target = b->output_en ? b->v_set : 0.0f;
    b->v_out += (float)(((double)target - (double)b->v_out) * (dt / 0.15));
    if (b->v_out < 0.0f) b->v_out = 0.0f;
    b->i_out = (float)((double)b->v_out / r_load);
    b->duty = b->v_out / V_BUS_DEFAULT * 100.0f;
    double t_target = 28.0 + (double)b->i_out * (double)b->i_out * 6.0;
    b->temp += (float)((t_target - (double)b->temp) * (dt / 20.0));

    if (b->fault == FAULT_NONE) {
        if (b->output_en && b->v_set >= 1.0f && b->v_out > b->v_set * OVP_RATIO) { b->fault = FAULT_OVP; b->output_en = 0; b->trips++; }
        else if (b->i_out > I_TRIP) { b->fault = FAULT_OCP; b->output_en = 0; b->trips++; }
        else if (b->temp > T_TRIP) { b->fault = FAULT_OTP; b->output_en = 0; b->trips++; }
    }
}

/* 主循环里周期调用：把 DDR 环里已完成的块全部取走（保留最新一帧），
 * 保证 25 kHz 采集不会因为环满而丢帧 */
static void pl_pump(board_t *b) {
    float v = b->v_out, i = b->i_out, d = b->duty;
    uint32_t got = 0;
    if (pl_read_sample(&b->pl, &v, &i, &d, &got) == 0) {
        b->v_out = v; b->i_out = i; b->duty = d;
        b->blocks_rx += got;
    }
    uint32_t err = fd_rd(&b->pl, FD_ERROR);
    if (err && b->fdma_err == 0) {
        b->fdma_err = err;
        fprintf(stderr, "[警告] FDMA 错误 0x%X（采集已停，需重启服务）\n", err);
    }
}

/* 组装一帧状态：sim 用模型；mmap 的数据由 pl_pump 提前更新到这里 */
static void board_status(board_t *b, status_t *s) {
    s->i_set = 0.0f;               /* 真实板卡与 sim 均未实现电流给定 */
    if (!b->use_pl) {
        s->v_out = b->v_out; s->i_out = b->i_out; s->duty = b->duty;
        s->v_set = b->v_set; s->fault = b->fault;
        s->flags = (uint16_t)(FLAG_RUNNING
                              | (b->output_en ? FLAG_OUTPUT_EN : 0)
                              | (b->fault == FAULT_OVP ? FLAG_OVP : 0)
                              | (b->fault == FAULT_OCP ? FLAG_OCP : 0)
                              | (b->fault == FAULT_OTP ? FLAG_OTP : 0));
        s->reserved = (uint16_t)((b->output_en ? (PLST_OUTPUT_ACTIVE | PLST_OUTPUT_REQUEST) : 0)
                                 | PLST_ADC_INIT | PLST_PLL_LOCKED | PLST_PWM_ARMED);
        return;
    }

    /* V/I/duty 由主循环的 pl_pump 从 DDR 环更新到 b；这里只读实时状态与给定 */
    float v = b->v_out, i = b->i_out, d = b->duty;
    uint32_t plst = pl_rd(&b->pl, PL_OUT_STATUS);   /* 0x4C 是实时状态，与采样块无关 */
    b->v_set = (float)((int32_t)pl_rd(&b->pl, PL_VREF)) / 65536.0f;

    /* 故障映射（2026-10-15 版：bit3=ADC 驱动故障 / bit7=过流锁存 / bit8=过压锁存） */
    if (plst & PLST_ADC_ERROR)            b->fault = FAULT_ADC;      /* 需系统复位 */
    else if (plst & PLST_OCP)             b->fault = FAULT_OCP;
    else if (plst & PLST_OVP)             b->fault = FAULT_OVP;
    else if (plst & PLST_SAMPLE_OVERRUN)  b->fault = FAULT_OVERRUN;
    else                                  b->fault = FAULT_NONE;
    b->output_en = (plst & PLST_OUTPUT_ACTIVE) ? 1 : 0;

    s->v_out = v; s->i_out = i; s->duty = d; s->v_set = b->v_set;
    s->fault = b->fault;
    s->reserved = (uint16_t)plst;
    s->flags = (uint16_t)(FLAG_RUNNING
                          | ((plst & PLST_OUTPUT_ACTIVE) ? FLAG_OUTPUT_EN : 0)
                          | (b->fault == FAULT_OVP ? FLAG_OVP : 0)
                          | (b->fault == FAULT_OCP ? FLAG_OCP : 0)
                          | (b->fault == FAULT_OTP ? FLAG_OTP : 0));
}

/* ========================== CAN 应用层（SocketCAN）====================== */
/* 标准 11 位 ID，经典 8 字节帧，小端。与 TCP 协议互不影响，可同时启用。
 *
 *  ID     方向    内容
 *  0x101  板→外   电压 f32@0，电流 f32@4
 *  0x102  板→外   占空比 % f32@0，给定 V f32@4
 *  0x103  板→外   flags u16@0，fault u8@2，其余保留
 *  0x201  外→板   电压给定 f32@0（0..64 V）
 *  0x202  外→板   输出开关 u8@0（1=开，0=关）
 *  0x203  外→板   清故障（数据任意）
 *  0x7FF  外→板   心跳（刷新 3 s 在线超时）
 */
#define CAN_ID_MEAS       0x101u
#define CAN_ID_DUTY       0x102u
#define CAN_ID_STATUS     0x103u
#define CAN_ID_SETPOINT   0x201u
#define CAN_ID_OUTPUT     0x202u
#define CAN_ID_CLEAR      0x203u
#define CAN_ID_HEARTBEAT  0x7FFu

typedef struct { int fd; char ifname[IFNAMSIZ]; } can_t;

static int can_open(can_t *c, const char *ifname) {
    memset(c, 0, sizeof(*c));
    c->fd = -1;
    snprintf(c->ifname, sizeof(c->ifname), "%s", ifname);
    int fd = socket(PF_CAN, SOCK_RAW, CAN_RAW);
    if (fd < 0) return -1;
    struct ifreq ifr;
    memset(&ifr, 0, sizeof(ifr));
    snprintf(ifr.ifr_name, sizeof(ifr.ifr_name), "%s", ifname);
    if (ioctl(fd, SIOCGIFINDEX, &ifr) < 0) { close(fd); return -2; }
    struct sockaddr_can addr;
    memset(&addr, 0, sizeof(addr));
    addr.can_family = AF_CAN;
    addr.can_ifindex = ifr.ifr_ifindex;
    if (bind(fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) { close(fd); return -3; }
    int fl = fcntl(fd, F_GETFL, 0);
    fcntl(fd, F_SETFL, fl | O_NONBLOCK);
    c->fd = fd;
    return 0;
}

static int can_send(can_t *c, uint32_t id, const uint8_t *d, uint8_t len) {
    if (!c || c->fd < 0) return -1;
    if (len > 8) len = 8;
    struct can_frame fr;
    memset(&fr, 0, sizeof(fr));
    fr.can_id = id;
    fr.can_dlc = len;
    if (d && len) memcpy(fr.data, d, len);
    return (int)write(c->fd, &fr, sizeof(fr));
}

/* 1 = 收到一帧，0 = 无数据，-1 = 错误 */
static int can_recv(can_t *c, struct can_frame *fr) {
    if (!c || c->fd < 0) return 0;
    ssize_t n = read(c->fd, fr, sizeof(*fr));
    if (n == (ssize_t)sizeof(*fr)) return 1;
    if (n < 0 && (errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR)) return 0;
    return -1;
}

/* CAN 命令 → 与 TCP 命令同一套规则（限幅 / 联锁 / 清故障语义） */
static void can_apply(board_t *b, const struct can_frame *fr, int verbose) {
    uint8_t d[8];
    memset(d, 0, sizeof(d));
    uint8_t n = fr->can_dlc > 8 ? 8 : fr->can_dlc;
    memcpy(d, fr->data, n);

    switch (fr->can_id & CAN_EFF_MASK) {
    case CAN_ID_SETPOINT: {
        float v; memcpy(&v, d, 4);
        if (!(v >= 0.0f && v <= PL_VREF_LIMIT_V)) {
            if (verbose) printf("[CAN] 拒绝给定 %.2f V（超出 0~64V）\n", (double)v);
            break;
        }
        if (b->use_pl) {
            if (pl_set_vref(&b->pl, v) < 0) break;
            if (pl_took_error(&b->pl)) { if (verbose) printf("[CAN] PL 拒绝给定 %.2f V\n", (double)v); break; }
        } else {
            b->v_set = v;
            if (v == 0.0f) b->output_en = 0;
        }
        if (verbose) printf("[CAN] 给定更新 %.2f V\n", (double)v);
        break;
    }
    case CAN_ID_OUTPUT: {
        int on = d[0] ? 1 : 0;
        if (on) {
            if (b->fault != FAULT_NONE) {
                if (verbose) printf("[CAN] 拒绝开输出：故障 %u\n", (unsigned)b->fault);
                break;
            }
            float vset = b->use_pl ? (float)((int32_t)pl_rd(&b->pl, PL_VREF)) / 65536.0f : b->v_set;
            if (vset <= 0.0f) { if (verbose) printf("[CAN] 拒绝开输出：给定为 0\n"); break; }
            if (b->use_pl) { pl_set_vref(&b->pl, vset); pl_output_on(&b->pl); }
            else b->output_en = 1;
            if (b->use_pl && pl_took_error(&b->pl)) { if (verbose) printf("[CAN] PL 拒绝开输出\n"); break; }
            if (verbose) printf("[CAN] 输出 开\n");
        } else {
            if (b->use_pl) pl_output_off(&b->pl); else b->output_en = 0;
            if (verbose) printf("[CAN] 输出 关\n");
        }
        break;
    }
    case CAN_ID_CLEAR: {
        if (!b->use_pl) {
            b->fault = FAULT_NONE; b->output_en = 0; b->v_set = 0.0f;
            if (verbose) printf("[CAN] 清故障(sim) 完成\n");
            break;
        }
        if (!b->has_flt1) { if (verbose) printf("[CAN] 清故障不支持（位流无 FLT1）\n"); break; }
        pl_clear_illegal(&b->pl);
        pl_wr(&b->pl, PL_FAULT_CLEAR, 1u);
        usleep(3000);
        uint32_t st = pl_rd(&b->pl, PL_OUT_STATUS);
        b->v_set = (float)((int32_t)pl_rd(&b->pl, PL_VREF)) / 65536.0f;
        if (st & PL_SHUTDOWN_FAULTS)
            { if (verbose) printf("[CAN] 清故障被拒：仍锁存 0x%03X\n", (unsigned)(st & PL_SHUTDOWN_FAULTS)); }
        else
            { if (verbose) printf("[CAN] 故障已清（输出保持关闭、给定已清零）\n"); }
        break;
    }
    case CAN_ID_HEARTBEAT:
        b->last_host_rx = mono();
        b->host_online = 1;
        break;
    default:
        break;
    }
}

/* 周期发布（100 ms 一组） */
static void can_publish(can_t *c, const status_t *s) {
    if (!c || c->fd < 0) return;
    uint8_t d[8];
    float v = s->v_out, i = s->i_out;
    memcpy(d, &v, 4); memcpy(d + 4, &i, 4);
    can_send(c, CAN_ID_MEAS, d, 8);

    float duty = s->duty, set = s->v_set;
    memcpy(d, &duty, 4); memcpy(d + 4, &set, 4);
    can_send(c, CAN_ID_DUTY, d, 8);

    memset(d, 0, 8);
    uint16_t flags = s->flags;
    memcpy(d, &flags, 2);
    d[2] = (uint8_t)s->fault;
    can_send(c, CAN_ID_STATUS, d, 8);
}

/* CAN 自发自收自测（需要接口处于 loopback 模式） */
static int can_selftest(const char *ifname) {
    can_t c;
    int rc = can_open(&c, ifname);
    if (rc < 0) {
        printf("[CAN] 打开 %s 失败 rc=%d (%s)\n", ifname, rc, strerror(errno));
        printf("      先执行: ip link set %s up\n", ifname);
        return 1;
    }
    printf("[CAN] %s 已打开\n", ifname);

    uint8_t d[8];
    memset(d, 0, sizeof(d));
    float v = 12.0f;
    memcpy(d, &v, 4);
    int sent = 0;
    for (int k = 0; k < 3; k++) {
        if (can_send(&c, CAN_ID_SETPOINT, d, 8) > 0) sent++;
        usleep(20000);
    }
    printf("[CAN] 已发送 %d 帧（ID 0x%03X，数据 12.0V）\n", sent, CAN_ID_SETPOINT);

    int got = 0;
    struct can_frame fr;
    for (int t = 0; t < 100; t++) {
        int r = can_recv(&c, &fr);
        if (r == 1) {
            got++;
            if (got <= 5)
                printf("[CAN] 收到 ID=0x%03X DLC=%u data=%02X %02X %02X %02X\n",
                       (unsigned)(fr.can_id & CAN_EFF_MASK), (unsigned)fr.can_dlc,
                       fr.data[0], fr.data[1], fr.data[2], fr.data[3]);
        }
        usleep(10000);
    }
    close(c.fd);

    if (got >= 3) {
        printf("[CAN] SELFTEST OK —— 自发自收 %d 帧\n", got);
        return 0;
    }
    printf("[CAN] SELFTEST: 收到 %d 帧（0 表示没有回环）\n", got);
    printf("      若为 0，先切回环模式再测：\n");
    printf("        ip link set %s down\n", ifname);
    printf("        ip link set %s type can bitrate 500000 loopback on\n", ifname);
    printf("        ip link set %s up\n", ifname);
    return 1;
}

/* ========================== 传输层 ====================================== */
static int tx_write(int fd, const uint8_t *d, size_t n) {
    size_t off = 0;
    while (off < n) {
        ssize_t w = write(fd, d + off, n - off);
        if (w > 0) { off += (size_t)w; continue; }
        if (w < 0 && errno == EINTR) continue;
        if (w < 0 && (errno == EAGAIN || errno == EWOULDBLOCK)) return (int)off;
        return -1;
    }
    return (int)off;
}

static int tcp_listen(int port) {
    int fd = socket(AF_INET, SOCK_STREAM, 0);
    if (fd < 0) return -1;
    int one = 1;
    setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &one, sizeof(one));
    struct sockaddr_in a; memset(&a, 0, sizeof(a));
    a.sin_family = AF_INET; a.sin_addr.s_addr = htonl(INADDR_ANY); a.sin_port = htons((uint16_t)port);
    if (bind(fd, (struct sockaddr *)&a, sizeof(a)) < 0) { close(fd); return -1; }
    if (listen(fd, 8) < 0) { close(fd); return -1; }
    return fd;
}

static int serial_open_dev(const char *dev) {
    int fd = open(dev, O_RDWR | O_NOCTTY | O_NONBLOCK);
    if (fd < 0) return -1;
    struct termios tio;
    if (tcgetattr(fd, &tio) < 0) { close(fd); return -1; }
    cfmakeraw(&tio);
    cfsetispeed(&tio, B115200); cfsetospeed(&tio, B115200);
    tio.c_cflag |= (CLOCAL | CREAD); tio.c_cflag &= ~CRTSCTS;
    tio.c_cc[VMIN] = 0; tio.c_cc[VTIME] = 0;
    if (tcsetattr(fd, TCSANOW, &tio) < 0) { close(fd); return -1; }
    tcflush(fd, TCIOFLUSH);
    return fd;
}

/* ========================== 命令处理 ==================================== */
static void send_frame(int fd, unsigned long *txn, uint8_t cmd, const uint8_t *pl, size_t n, uint8_t seq) {
    uint8_t buf[128];
    size_t len = build_frame(buf, cmd, pl, n, seq);
    if (tx_write(fd, buf, len) > 0 && txn) (*txn)++;
}

static void send_text(int fd, unsigned long *txn, const char *msg, uint8_t seq) {
    uint8_t pl[MAX_PAYLOAD];
    size_t n = strlen(msg);
    if (n > MAX_PAYLOAD) n = MAX_PAYLOAD;
    memcpy(pl, msg, n);
    send_frame(fd, txn, CMD_TEXT, pl, n, seq);
}

static void handle_frame(board_t *b, csv_t *csv, int fd, const frame_t *fr, int verbose) {
    uint8_t ack[2];
    b->host_online = 1;
    b->last_host_rx = mono();
    b->rx_frames++;

    switch (fr->cmd) {
    case CMD_READ_STATUS: {
        status_t s; memset(&s, 0, sizeof(s));
        board_status(b, &s);
        s.flags |= (uint16_t)(csv->ok ? FLAG_LOG_OK : 0) | FLAG_HOST_ONLINE;
        uint8_t pl[STATUS_PAYLOAD_SIZE]; status_encode(&s, pl);
        send_frame(fd, &b->tx_frames, CMD_STATUS, pl, STATUS_PAYLOAD_SIZE, fr->seq);
        break;
    }
    case CMD_SET_SETPOINT: {
        if (fr->plen != 8) { ack[0] = ACK_BAD_PARAM; send_frame(fd, &b->tx_frames, CMD_ACK, ack, 1, fr->seq); break; }
        float v = get_f32(fr->payload), i = get_f32(fr->payload + 4);
        if (!(v >= 0.0f && v <= PL_VREF_LIMIT_V)) {
            ack[0] = ACK_BAD_PARAM; send_frame(fd, &b->tx_frames, CMD_ACK, ack, 1, fr->seq);
            if (verbose) printf("[板卡] 拒绝给定 v=%.2f（超出 0~64V）\n", (double)v);
            break;
        }
        if (b->use_pl && pl_set_vref(&b->pl, v) < 0) {
            ack[0] = ACK_BAD_PARAM; send_frame(fd, &b->tx_frames, CMD_ACK, ack, 1, fr->seq);
            break;
        }
        if (b->use_pl && pl_took_error(&b->pl)) {
            ack[0] = ACK_BAD_PARAM; send_frame(fd, &b->tx_frames, CMD_ACK, ack, 1, fr->seq);
            send_text(fd, &b->tx_frames, "PL 拒绝了该给定（超 64V 或非法）", (uint8_t)(fr->seq + 1));
            if (verbose) printf("[板卡] PL 拒绝给定 v=%.2f（0x5C 置位）\n", (double)v);
            break;
        }
        if (!b->use_pl) b->v_set = v;
        if (i != 0.0f) {
            /* 真实板卡未实现电流给定：明确返回"不支持"，不谎报成功 */
            ack[0] = ACK_UNSUPPORTED;
            send_frame(fd, &b->tx_frames, CMD_ACK, ack, 1, fr->seq);
            send_text(fd, &b->tx_frames, "电流给定未实现（已忽略），仅电压给定生效", (uint8_t)(fr->seq + 1));
            if (verbose) printf("[板卡] 电压给定 %.2fV 已生效；电流给定未实现（忽略）\n", (double)v);
        } else {
            ack[0] = ACK_OK;
            send_frame(fd, &b->tx_frames, CMD_ACK, ack, 1, fr->seq);
            if (verbose) printf("[板卡] 给定更新 v=%.2fV\n", (double)v);
        }
        break;
    }
    case CMD_SET_OUTPUT: {
        if (fr->plen < 1) { ack[0] = ACK_BAD_PARAM; send_frame(fd, &b->tx_frames, CMD_ACK, ack, 1, fr->seq); break; }
        uint8_t on = fr->payload[0];
        float vset = b->use_pl ? (float)((int32_t)pl_rd(&b->pl, PL_VREF)) / 65536.0f : b->v_set;
        if (on) {
            if (b->fault != FAULT_NONE) {
                ack[0] = ACK_FAULT_LATCHED; send_frame(fd, &b->tx_frames, CMD_ACK, ack, 1, fr->seq);
                send_text(fd, &b->tx_frames, "有故障未清除，拒绝开输出", (uint8_t)(fr->seq + 1));
                if (verbose) printf("[板卡] 拒绝开输出：故障 %u\n", (unsigned)b->fault);
                break;
            }
            if (vset <= 0.0f) {                     /* 零给定下的开启请求被拒绝 */
                ack[0] = ACK_BAD_PARAM; send_frame(fd, &b->tx_frames, CMD_ACK, ack, 1, fr->seq);
                send_text(fd, &b->tx_frames, "零给定不能开输出，请先下发电压给定", (uint8_t)(fr->seq + 1));
                if (verbose) printf("[板卡] 拒绝开输出：给定为 0\n");
                break;
            }
            if (b->use_pl) { pl_set_vref(&b->pl, vset); pl_output_on(&b->pl); }
            else b->output_en = 1;
            if (b->use_pl && pl_took_error(&b->pl)) {
                ack[0] = ACK_FAULT_LATCHED;
                send_frame(fd, &b->tx_frames, CMD_ACK, ack, 1, fr->seq);
                send_text(fd, &b->tx_frames, "PL 拒绝开输出：给定为 0 或保护故障未清除", (uint8_t)(fr->seq + 1));
                if (verbose) printf("[板卡] PL 拒绝开输出（0x5C 置位，见 0x4C 故障位）\n");
                break;
            }
            ack[0] = ACK_OK; send_frame(fd, &b->tx_frames, CMD_ACK, ack, 1, fr->seq);
            if (b->use_pl) {
                usleep(3000);
                if (verbose) printf("[板卡] 输出开请求已接受（PL output_active=%d，实际开启以 STATUS 为准）\n",
                                    pl_output_active(&b->pl));
            } else if (verbose) printf("[板卡] 输出 开\n");
        } else {
            if (b->use_pl) pl_output_off(&b->pl); else b->output_en = 0;
            ack[0] = ACK_OK; send_frame(fd, &b->tx_frames, CMD_ACK, ack, 1, fr->seq);
            if (verbose) printf("[板卡] 输出 关\n");
        }
        break;
    }
    case CMD_HEARTBEAT:
        ack[0] = ACK_OK; send_frame(fd, &b->tx_frames, CMD_ACK, ack, 1, fr->seq);
        break;
    case CMD_CLEAR_FAULT: {
        /* 2026-10-15 版硬件已实现：0x60 写 1 清过流/过压锁存，0x64 回读 FLT1 */
        if (!b->use_pl) {
            if (b->fault == FAULT_ADC) {
                ack[0] = ACK_FAULT_LATCHED;
                send_frame(fd, &b->tx_frames, CMD_ACK, ack, 1, fr->seq);
                send_text(fd, &b->tx_frames, "ADC 驱动故障需系统复位，软件清不掉", (uint8_t)(fr->seq + 1));
            } else if (b->fault != FAULT_NONE) {
                b->fault = FAULT_NONE; b->output_en = 0; b->v_set = 0.0f;
                ack[0] = ACK_OK;
                send_frame(fd, &b->tx_frames, CMD_ACK, ack, 1, fr->seq);
                send_text(fd, &b->tx_frames, "故障已清，输出保持关闭、给定已清零；请重设给定再单独开输出",
                          (uint8_t)(fr->seq + 1));
            } else {
                ack[0] = ACK_OK;
                send_frame(fd, &b->tx_frames, CMD_ACK, ack, 1, fr->seq);
                send_text(fd, &b->tx_frames, "无故障，清故障为空操作", (uint8_t)(fr->seq + 1));
            }
            if (verbose) printf("[板卡] 清故障(sim)：剩余故障=%u\n", (unsigned)b->fault);
            break;
        }
        if (!b->has_flt1) {
            ack[0] = ACK_UNSUPPORTED;
            send_frame(fd, &b->tx_frames, CMD_ACK, ack, 1, fr->seq);
            send_text(fd, &b->tx_frames, "位流不带 FLT1(0x64)，无法清故障；请烧入 2026-10-15 版位流",
                      (uint8_t)(fr->seq + 1));
            if (verbose) printf("[板卡] 清故障：位流无 FLT1 能力\n");
            break;
        }
        pl_clear_illegal(&b->pl);                 /* 顺带清 0x5C 非法命令标志 */
        pl_wr(&b->pl, PL_FAULT_CLEAR, 1u);        /* W1P：请求清故障（硬件先关输出+清给定） */
        usleep(3000);
        {
            uint32_t fid = pl_rd(&b->pl, PL_FAULT_ID);
            uint32_t st = pl_rd(&b->pl, PL_OUT_STATUS);
            uint32_t shutdown = st & PL_SHUTDOWN_FAULTS;
            b->v_set = (float)((int32_t)pl_rd(&b->pl, PL_VREF)) / 65536.0f;   /* 硬件已清零 → 同步 */
            if (fid != PL_FAULT_ID_VAL) {
                ack[0] = ACK_UNSUPPORTED;
                send_frame(fd, &b->tx_frames, CMD_ACK, ack, 1, fr->seq);
                send_text(fd, &b->tx_frames, "清故障：FLT1 回读不符（固件版本不匹配）", (uint8_t)(fr->seq + 1));
                if (verbose) printf("[板卡] 清故障失败：0x64 回读 0x%08X\n", fid);
            } else if (shutdown) {
                ack[0] = ACK_FAULT_LATCHED;
                send_frame(fd, &b->tx_frames, CMD_ACK, ack, 1, fr->seq);
                send_text(fd, &b->tx_frames, "故障未解除：需先恢复正常采样（电流<=4A、电压<=80V、ADC 无故障）",
                          (uint8_t)(fr->seq + 1));
                if (verbose) printf("[板卡] 清故障被拒：仍锁存 0x%03X\n", (unsigned)shutdown);
            } else {
                ack[0] = ACK_OK;
                send_frame(fd, &b->tx_frames, CMD_ACK, ack, 1, fr->seq);
                send_text(fd, &b->tx_frames, "故障已清，输出保持关闭、给定已清零；请重设给定再单独开输出",
                          (uint8_t)(fr->seq + 1));
                if (verbose) printf("[板卡] 清故障成功（0x4C=0x%08X，输出保持关闭）\n", st);
            }
        }
        break;
    }
    case CMD_SET_TIME: {
        if (fr->plen != 8) { ack[0] = ACK_BAD_PARAM; send_frame(fd, &b->tx_frames, CMD_ACK, ack, 1, fr->seq); break; }
        uint64_t secs = 0; memcpy(&secs, fr->payload, 8);      /* 小端 */
        struct timeval tv; tv.tv_sec = (time_t)secs; tv.tv_usec = 0;
        if (settimeofday(&tv, NULL) == 0) {
            char newpath[512]; csv_default_path(newpath, sizeof(newpath));
            if (csv->fp && strcmp(newpath, csv->path) != 0) {   /* 首次同步/跨天 → 换当天文件 */
                long mb = csv->max_bytes;
                csv_close(csv);
                csv_open(csv, newpath, mb);
                if (verbose) printf("[板卡] 时间同步 → 日志切到 %s\n", csv->path);
            }
            ack[0] = ACK_OK; send_frame(fd, &b->tx_frames, CMD_ACK, ack, 1, fr->seq);
            if (verbose) {
                char ts[32]; time_t t = time(NULL); struct tm tm; localtime_r(&t, &tm);
                strftime(ts, sizeof(ts), "%Y-%m-%d %H:%M:%S", &tm);
                printf("[板卡] 时间已同步为 %s\n", ts);
            }
        } else {
            ack[0] = ACK_UNSUPPORTED; send_frame(fd, &b->tx_frames, CMD_ACK, ack, 1, fr->seq);
            send_text(fd, &b->tx_frames, "设置时间失败（需 root 权限）", (uint8_t)(fr->seq + 1));
        }
        break;
    }
    default:
        ack[0] = fr->cmd; send_frame(fd, &b->tx_frames, CMD_NACK, ack, 1, fr->seq);
        if (verbose) printf("[板卡] 未知命令 0x%02X -> NACK\n", fr->cmd);
        break;
    }
}

/* ========================== 自测（KAT） ================================= */
static void hexify(const uint8_t *d, size_t n, char *out, size_t outsz) {
    out[0] = 0;
    for (size_t i = 0; i < n; i++) {
        char t[8];
        snprintf(t, sizeof(t), "%02X%s", d[i], (i + 1 < n) ? " " : "");
        strncat(out, t, outsz - strlen(out) - 1);
    }
}

static int selftest(void) {
    int fail = 0;
    uint8_t buf[160];
    char hex[512];

    printf("=== power_svc 协议自测（必须与 protocol.py 完全一致）===\n");

    uint16_t c1 = crc16_modbus((const uint8_t *)"123456789", 9);
    uint8_t r2[3] = {0x02, 0x01, 0x00};
    uint16_t c2 = crc16_modbus(r2, 3);
    printf("[%s] CRC '123456789' = 0x%04X（期望 0x4B37）\n", c1 == 0x4B37 ? "OK" : "FAIL", c1);
    printf("[%s] CRC(02 01 00)   = 0x%04X（期望 0x90D1）\n", c2 == 0x90D1 ? "OK" : "FAIL", c2);
    if (c1 != 0x4B37 || c2 != 0x90D1) fail++;

    size_t n = build_frame(buf, CMD_READ_STATUS, NULL, 0, 0);
    hexify(buf, n, hex, sizeof(hex));
    printf("[%s] READ_STATUS  : %s\n", strcmp(hex, "AA 55 02 01 00 D1 90") == 0 ? "OK" : "FAIL", hex);
    if (strcmp(hex, "AA 55 02 01 00 D1 90") != 0) fail++;

    uint8_t sp[8]; put_f32(sp, 12.0f); put_f32(sp + 4, 5.0f);
    n = build_frame(buf, CMD_SET_SETPOINT, sp, 8, 1);
    hexify(buf, n, hex, sizeof(hex));
    printf("[%s] SET_SETPOINT : %s\n",
           strcmp(hex, "AA 55 0A 02 01 00 00 40 41 00 00 A0 40 C0 59") == 0 ? "OK" : "FAIL", hex);
    if (strcmp(hex, "AA 55 0A 02 01 00 00 40 41 00 00 A0 40 C0 59") != 0) fail++;

    status_t s; memset(&s, 0, sizeof(s));
    s.flags = (uint16_t)(FLAG_RUNNING | FLAG_OUTPUT_EN | FLAG_HOST_ONLINE | FLAG_LOG_OK);
    s.v_out = 17.75f; s.i_out = 1.5f; s.duty = 74.5f; s.v_set = 18.0f; s.i_set = 3.25f;
    s.fault = FAULT_OVP; s.reserved = 0;
    uint8_t pl[STATUS_PAYLOAD_SIZE]; status_encode(&s, pl);
    n = build_frame(buf, CMD_STATUS, pl, STATUS_PAYLOAD_SIZE, 7);
    hexify(buf, n, hex, sizeof(hex));
    const char *expect = "AA 55 1C 82 07 63 00 00 00 8E 41 00 00 C0 3F 00 00 95 42 "
                         "00 00 90 41 00 00 50 40 01 00 00 00 E5 4C";
    printf("[%s] STATUS       : %s\n", strcmp(hex, expect) == 0 ? "OK" : "FAIL", hex);
    if (strcmp(hex, expect) != 0) { fail++; printf("     期望       : %s\n", expect); }

    uint8_t tp[8]; uint64_t secs = 1760000000ULL;
    memcpy(tp, &secs, 8);
    n = build_frame(buf, CMD_SET_TIME, tp, 8, 1);
    hexify(buf, n, hex, sizeof(hex));
    const char *expect_t = "AA 55 0A 06 01 00 78 E7 68 00 00 00 00 44 AA";
    printf("[%s] SET_TIME     : %s\n", strcmp(hex, expect_t) == 0 ? "OK" : "FAIL", hex);
    if (strcmp(hex, expect_t) != 0) fail++;

    parser_t p; memset(&p, 0, sizeof(p));
    frame_t f;
    uint8_t noise[] = {0x00, 0xAA, 0x11, 0xAA, 0x55, 0x03, 0x82, 0x09, 0x77, 0xEE};
    parser_push(&p, noise, sizeof(noise));
    while (parser_next(&p, &f)) { printf("[FAIL] 噪声解出帧（不应发生）\n"); fail++; }
    uint8_t good[160];
    size_t gn = build_frame(good, CMD_READ_STATUS, NULL, 0, 3);
    uint8_t bad[160]; memcpy(bad, good, gn); bad[gn - 1] ^= 0xFF;
    parser_push(&p, bad, gn);
    while (parser_next(&p, &f)) { printf("[FAIL] 坏 CRC 解出帧（不应发生）\n"); fail++; }
    parser_push(&p, good, 6);
    while (parser_next(&p, &f)) { printf("[FAIL] 半包解出帧（不应发生）\n"); fail++; }
    parser_push(&p, good + 6, gn - 6);
    int got = 0; while (parser_next(&p, &f)) got++;
    printf("[%s] 抗干扰重同步：收帧=%d（期望 1）CRC错=%lu（期望 2）重同步=%lu 丢字节=%lu\n",
           (got == 1 && p.crc_errors == 2) ? "OK" : "FAIL", got, p.crc_errors, p.resyncs, p.bytes_dropped);
    if (got != 1 || p.crc_errors != 2) fail++;

    printf("-------------------------------------------------------------\n");
    if (fail) printf("SELFTEST FAIL（%d 项不符）\n", fail);
    else      printf("SELFTEST OK —— 与 protocol.py 字节级一致\n");
    return fail ? 1 : 0;
}

/* ========================== 主程序 ====================================== */
#define POWER_SVC_VERSION "v10-dcd1clamp"
static volatile sig_atomic_t g_stop = 0;
static void on_sig(int sig) { (void)sig; g_stop = 1; }


static void usage(const char *argv0) {
    printf("用法: %s [选项]\n", argv0);
    printf("  --tcp PORT        监听 TCP 端口（默认 5000）\n");
    printf("  --serial DEV      用串口（如 /dev/ttyS0）\n");
    printf("  --pl sim|mmap     数据源：sim=假模型（默认），mmap=读 PL 寄存器\n");
    printf("  --pl-base HEX     GP0 寄存器物理基址（默认 0x80000000；FDMA 在 +0x10000）\n");
    printf("  --ddr-base HEX    DDR 采样环物理基址（默认 0x3FC00000，需 DTS reserved-memory）\n");
    printf("  --ddr-slots N     环槽数，必须是 2 的幂（默认 1024，每槽 4096B = 4MB）\n");
    printf("  --dcd1 HOST[:PORT] 同时把 P481 原始帧以 DCD1 包发到 PC 网页监测（默认端口 9900）\n");
    printf("  --dcd1-rate HZ     DCD1 头里的名义采样率（默认 113000，需与实际位流一致）\n");
    printf("  --can IF          同时启用 CAN 应用层（如 --can can0）\n");
    printf("  --can-selftest [IF] CAN 自发自收自测（默认 can0）后退出\n");
    printf("  --csv PATH        CSV 路径（默认 /root/data/power_YYYYMMDD.csv）\n");
    printf("  --no-csv          关闭本地日志\n");
    printf("  --csv-max-mb N    日志轮转上限 MB（默认 5）\n");
    printf("  --duration SEC    跑指定秒数后退出（0=一直跑）\n");
    printf("  --selftest        协议自检后退出\n");
    printf("  --quiet           少打印\n");
    printf("  --help\n");
}


/* ---------------- multi-client TCP support (v6) ---------------- */
#define MAX_TCP_CLIENTS 6
typedef struct { int fd; parser_t ps; } tcp_client_t;
static tcp_client_t g_cli[MAX_TCP_CLIENTS];

static void cli_del(int idx)
{
    if (idx < 0 || idx >= MAX_TCP_CLIENTS) return;
    if (g_cli[idx].fd >= 0) { close(g_cli[idx].fd); g_cli[idx].fd = -1; }
}

static void cli_add(int fd)
{
    int fl = fcntl(fd, F_GETFL, 0); fcntl(fd, F_SETFL, fl | O_NONBLOCK);
    int one = 1; setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, &one, sizeof(one));
    for (int i = 0; i < MAX_TCP_CLIENTS; i++) {
        if (g_cli[i].fd >= 0) continue;
        g_cli[i].fd = fd;
        memset(&g_cli[i].ps, 0, sizeof(g_cli[i].ps));
        printf("[board] TCP client #%d connected\n", i + 1);
        fflush(stdout);
        return;
    }
    printf("[board] too many clients, rejected\n");
    close(fd);
}

static void cli_broadcast(const uint8_t *buf, size_t n)
{
    for (int i = 0; i < MAX_TCP_CLIENTS; i++) {
        if (g_cli[i].fd < 0) continue;
        ssize_t w = write(g_cli[i].fd, buf, n);
        if (w < 0 && errno != EAGAIN && errno != EWOULDBLOCK && errno != EINTR)
            cli_del(i);
    }
}

static void cli_broadcast_text(const char *msg)
{
    uint8_t pl[MAX_PAYLOAD];
    size_t n = strlen(msg);
    if (n > MAX_PAYLOAD) n = MAX_PAYLOAD;
    memcpy(pl, msg, n);
    uint8_t fr[128];
    size_t fl = build_frame(fr, CMD_TEXT, pl, n, 0);
    cli_broadcast(fr, fl);
}
int main(int argc, char **argv) {
    setvbuf(stdout, NULL, _IOLBF, 0);   /* 重定向到文件时也按行刷新 → 日志实时可见 */
    int port = 5000, use_tcp = 1, no_csv = 0, verbose = 1;
    double duration = 0.0, csv_max_mb = 5.0;
    const char *serial_dev = NULL;
    char csv_path[512]; csv_path[0] = 0;
    int use_pl = 0;
    unsigned long pl_base = PL_BASE_DEFAULT;
    unsigned long ddr_base = DDR_RING_BASE_DEFAULT;
    uint32_t ddr_slots = DDR_RING_SLOTS_DEFAULT;
    const char *can_if = NULL;
    int can_self = 0;

    for (int i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "--selftest")) return selftest();
        else if (!strcmp(argv[i], "--tcp") && i + 1 < argc) { port = atoi(argv[++i]); use_tcp = 1; serial_dev = NULL; }
        else if (!strcmp(argv[i], "--serial") && i + 1 < argc) { serial_dev = argv[++i]; use_tcp = 0; }
        else if (!strcmp(argv[i], "--pl") && i + 1 < argc) use_pl = (strcmp(argv[++i], "mmap") == 0);
        else if (!strcmp(argv[i], "--pl-base") && i + 1 < argc) pl_base = strtoul(argv[++i], NULL, 0);
        else if (!strcmp(argv[i], "--ddr-base") && i + 1 < argc) ddr_base = strtoul(argv[++i], NULL, 0);
        else if (!strcmp(argv[i], "--ddr-slots") && i + 1 < argc) ddr_slots = (uint32_t)strtoul(argv[++i], NULL, 0);
        else if (!strcmp(argv[i], "--dcd1") && i + 1 < argc) {
            char *pv = argv[++i];
            char *colon = strchr(pv, ':');
            if (colon) { *colon = 0; g_dcd1_port = (uint16_t)atoi(colon + 1); }
            snprintf(g_dcd1_host, sizeof(g_dcd1_host), "%s", pv);
        }
        else if (!strcmp(argv[i], "--dcd1-rate") && i + 1 < argc) g_dcd1_rate = (uint32_t)strtoul(argv[++i], NULL, 0);
        else if (!strcmp(argv[i], "--can") && i + 1 < argc) can_if = argv[++i];
        else if (!strcmp(argv[i], "--can-selftest")) {
            can_self = 1;
            if (i + 1 < argc && argv[i + 1][0] != '-') can_if = argv[++i];
        }
        else if (!strcmp(argv[i], "--csv") && i + 1 < argc) snprintf(csv_path, sizeof(csv_path), "%s", argv[++i]);
        else if (!strcmp(argv[i], "--no-csv")) no_csv = 1;
        else if (!strcmp(argv[i], "--csv-max-mb") && i + 1 < argc) csv_max_mb = atof(argv[++i]);
        else if (!strcmp(argv[i], "--duration") && i + 1 < argc) duration = atof(argv[++i]);
        else if (!strcmp(argv[i], "--quiet")) verbose = 0;
        else if (!strcmp(argv[i], "--help")) { usage(argv[0]); return 0; }
        else { fprintf(stderr, "未知参数: %s\n", argv[i]); usage(argv[0]); return 2; }
    }

    if (can_self) return can_selftest(can_if ? can_if : "can0");

    if (csv_path[0] == 0) csv_default_path(csv_path, sizeof(csv_path));

    signal(SIGINT, on_sig);
    signal(SIGTERM, on_sig);

    board_t b; memset(&b, 0, sizeof(b));
    b.pl.fd = -1; b.pl.reg = NULL;
    b.v_set = 12.0f; b.i_set = 0.0f; b.temp = 28.0f; b.last_host_rx = -1e9;
    b.use_pl = use_pl;

    if (use_pl) {
        /* 槽数必须 2..65536 的 2 的幂；环基址 FDMA 要求 8 字节对齐 */
        if (ddr_slots < 2 || ddr_slots > 65536 || (ddr_slots & (ddr_slots - 1)) != 0) {
            fprintf(stderr, "[错误] --ddr-slots 必须是 2..65536 的 2 的幂（当前 %u）\n", ddr_slots);
            return 2;
        }
        if (ddr_base & 7u) {
            fprintf(stderr, "[错误] --ddr-base 必须 8 字节对齐（当前 0x%lX）\n", ddr_base);
            return 2;
        }
        int orc = pl_open(&b.pl, pl_base, ddr_base, ddr_slots);
        if (orc < 0) {
            fprintf(stderr, "[错误] 映射失败 rc=%d：/dev/mem GP0@0x%lX + DDR 环@0x%lX(%u KB)：%s\n"
                            "       需 root；并确认 DTS 的 reserved-memory 预留了该区域\n",
                    orc, pl_base, ddr_base, ddr_slots * 4u, strerror(errno));
            return 3;
        }
        printf("[板卡] 已映射: GP0 0x%lX / FDMA 0x%lX / DDR 环 0x%lX × %u 槽\n",
               pl_base, pl_base + 0x10000UL, ddr_base, ddr_slots);
        if (pl_check_ids(&b.pl, 1) < 0) {
            fprintf(stderr, "[错误] PL 识别值不匹配：位流里没有这套 IP，或基址不对。\n"
                            "       期望 ADC1/P481/CTR1/FDM1；请确认是 2026-10-20 版位流，或先用 --pl sim。\n");
            return 4;
        }
        b.has_flt1 = (pl_rd(&b.pl, PL_FAULT_ID) == PL_FAULT_ID_VAL);
        printf("[板卡] FLT1 清故障能力: %s（0x64=0x%08X）\n",
               b.has_flt1 ? "支持" : "不支持", pl_rd(&b.pl, PL_FAULT_ID));
        uint32_t vmax = pl_rd(&b.pl, PL_VREF_MAX);
        printf("[板卡] 0x58 给定上限 = %u (%.1f V)；0x50 斜坡给定 = %.3f V\n",
               vmax, vmax / 65536.0,
               (double)((int32_t)pl_rd(&b.pl, PL_VREF_RAMP)) / 65536.0);

        int waited = 0;
        while (!(pl_rd(&b.pl, PL_ADC_STATUS) & ADCST_FRAME_CAPTURED) && waited < 5000) { usleep(10000); waited += 10; }
        if (pl_rd(&b.pl, PL_ADC_STATUS) & ADCST_FRAME_CAPTURED)
            printf("[板卡] ADC 已捕获采样帧（等待 %d ms）；ADC_STATUS=0x%08X\n", waited, pl_rd(&b.pl, PL_ADC_STATUS));
        else
            fprintf(stderr, "[警告] 等待 ADC 首帧超时（%d ms），ADC_STATUS=0x%08X\n", waited, pl_rd(&b.pl, PL_ADC_STATUS));

        if (pl_capture_start(&b.pl, verbose) < 0)
            fprintf(stderr, "[警告] 采集启动失败：V/I/duty 不可用（输出控制仍可用）\n");
    } else {
        printf("[板卡] 数据源：sim（假模型；接真实位流后用 --pl mmap）\n");
    }

    can_t can;
    memset(&can, 0, sizeof(can));
    can.fd = -1;
    if (can_if) {
        int crc2 = can_open(&can, can_if);
        if (crc2 < 0)
            fprintf(stderr, "[警告] 打开 CAN %s 失败 rc=%d (%s)；仅 TCP/串口可用\n",
                    can_if, crc2, strerror(errno));
        else if (verbose)
            printf("[板卡] CAN 已启用: %s（发布 0x101/0x102/0x103，接收 0x201/0x202/0x203/0x7FF）\n", can_if);
    }

    csv_t csv; memset(&csv, 0, sizeof(csv));
    if (!no_csv) {
        if (csv_open(&csv, csv_path, (long)(csv_max_mb * 1024 * 1024)) < 0)
            fprintf(stderr, "[警告] CSV 打开失败: %s（继续运行，无本地日志）\n", csv.last_error);
        else if (verbose)
            printf("[板卡] 本地日志: %s（上限 %.1fMB，每行 flush，5s fsync）\n", csv.path, csv_max_mb);
    }

    int lfd = -1, cfd = -1;
    if (use_tcp) {
        lfd = tcp_listen(port);
        if (lfd < 0) { fprintf(stderr, "监听 %d 失败: %s\n", port, strerror(errno)); csv_close(&csv); return 1; }
        if (verbose) printf("[板卡] TCP 监听 0.0.0.0:%d，等上位机连接…\n", port);
    } else {
        cfd = serial_open_dev(serial_dev);
        if (cfd < 0) { fprintf(stderr, "打开串口 %s 失败: %s\n", serial_dev, strerror(errno)); csv_close(&csv); return 1; }
        if (verbose) printf("[板卡] 串口 %s 已打开（115200 8N1）\n", serial_dev);
    }

    if (g_dcd1_host[0]) dcd1_connect();

    parser_t ps; memset(&ps, 0, sizeof(ps));      /* serial-mode parser */
    uint8_t rbuf[512];
    double last = mono(), last_csv = mono(), last_status = 0.0, last_pump = 0.0, last_can = 0.0, last_dcd1 = 0.0, last_vi = 0.0;
    const double csv_period = 1.0, status_period = 0.5;

    for (int i = 0; i < MAX_TCP_CLIENTS; i++) { g_cli[i].fd = -1; }

    while (!g_stop) {
        struct pollfd pfds[MAX_TCP_CLIENTS + 3]; int nf = 0;
        if (use_tcp && lfd >= 0) { pfds[nf].fd = lfd; pfds[nf].events = POLLIN; nf++; }
        else if (!use_tcp && cfd >= 0) { pfds[nf].fd = cfd; pfds[nf].events = POLLIN; nf++; }
        if (use_tcp) {
            for (int ci = 0; ci < MAX_TCP_CLIENTS; ci++)
                if (g_cli[ci].fd >= 0) { pfds[nf].fd = g_cli[ci].fd; pfds[nf].events = POLLIN; nf++; }
        }
        if (can.fd >= 0) { pfds[nf].fd = can.fd; pfds[nf].events = POLLIN; nf++; }

        int pr = poll(pfds, (nfds_t)nf, 20);
        if (pr > 0) {
            for (int i = 0; i < nf; i++) {
                if (!(pfds[i].revents & POLLIN)) continue;

                if (use_tcp && pfds[i].fd == lfd) {
                    int nc = accept(lfd, NULL, NULL);
                    if (nc >= 0) cli_add(nc);
                    continue;
                }

                if (!use_tcp && cfd >= 0 && pfds[i].fd == cfd) {
                    ssize_t r = read(cfd, rbuf, sizeof(rbuf));
                    if (r > 0) {
                        parser_push(&ps, rbuf, (size_t)r);
                        frame_t f;
                        while (parser_next(&ps, &f)) handle_frame(&b, &csv, cfd, &f, verbose);
                    } else if (r == 0) {
                        close(cfd); cfd = -1;
                    } else if (errno != EAGAIN && errno != EWOULDBLOCK && errno != EINTR) {
                        close(cfd); cfd = -1;
                    }
                    continue;
                }

                if (use_tcp) {
                    for (int ci = 0; ci < MAX_TCP_CLIENTS; ci++) {
                        if (g_cli[ci].fd != pfds[i].fd) continue;
                        ssize_t r = read(g_cli[ci].fd, rbuf, sizeof(rbuf));
                        if (r > 0) {
                            parser_push(&g_cli[ci].ps, rbuf, (size_t)r);
                            frame_t f;
                            while (parser_next(&g_cli[ci].ps, &f))
                                handle_frame(&b, &csv, g_cli[ci].fd, &f, verbose);
                        } else if (r == 0) {
                            cli_del(ci);
                        } else if (errno != EAGAIN && errno != EWOULDBLOCK && errno != EINTR) {
                            cli_del(ci);
                        }
                        break;
                    }
                }
            }
        }

        if (can.fd >= 0) {
            struct can_frame cf;
            while (can_recv(&can, &cf) == 1) {
                b.rx_frames++;
                can_apply(&b, &cf, verbose);
            }
        }

        double now = mono(); double dt = now - last; last = now;
        b.t += dt;
        if (!b.use_pl) model_step(&b, dt);

        if (b.use_pl && now - last_pump >= 0.02) {
            last_pump = now;
            pl_pump(&b);
        }

        /* DCD1 (web monitor) reconnect */
        if (g_dcd1_host[0] && g_dcd1_fd < 0 && now - last_dcd1 > 2.0) {
            last_dcd1 = now;
            dcd1_connect();
        }
        /* publish latest V/I/duty for the NPU classifier (10 Hz) */
        if (now - last_vi >= 0.1) {
            last_vi = now;
            FILE *vf = fopen("/tmp/vi.txt", "w");
            if (vf) {
                fprintf(vf, "%.4f %.4f %.4f\n", (double)b.v_out, (double)b.i_out, (double)b.duty);
                fclose(vf);
            }
        }


        if (b.host_online && (now - b.last_host_rx) > HOST_TIMEOUT) {
            b.host_online = 0; b.host_drops++;
            cli_broadcast_text("host timeout, board keeps running");
        }

        if (now - last_status >= status_period) {
            last_status = now;
            status_t s; memset(&s, 0, sizeof(s));
            board_status(&b, &s);
            s.flags |= (uint16_t)(csv.ok ? FLAG_LOG_OK : 0) | (b.host_online ? FLAG_HOST_ONLINE : 0);
            uint8_t pl[STATUS_PAYLOAD_SIZE]; status_encode(&s, pl);
            uint8_t sfbuf[128];
            size_t sflen = build_frame(sfbuf, CMD_STATUS, pl, STATUS_PAYLOAD_SIZE, 0);
            if (use_tcp) {
                cli_broadcast(sfbuf, sflen);
            } else if (cfd >= 0) {
                if (tx_write(cfd, sfbuf, sflen) > 0) b.tx_frames++;
            }
        }

        if (can.fd >= 0 && now - last_can >= 0.1) {
            last_can = now;
            status_t cs; memset(&cs, 0, sizeof(cs));
            board_status(&b, &cs);
            cs.flags |= (uint16_t)(csv.ok ? FLAG_LOG_OK : 0) | (b.host_online ? FLAG_HOST_ONLINE : 0);
            can_publish(&can, &cs);
        }

        if (!no_csv && now - last_csv >= csv_period) {
            last_csv = now;
            status_t s; memset(&s, 0, sizeof(s));
            board_status(&b, &s);
            s.flags |= (uint16_t)(csv.ok ? FLAG_LOG_OK : 0) | (b.host_online ? FLAG_HOST_ONLINE : 0);
            csv_log(&csv, b.t, &s);
            if (verbose && ((unsigned long)b.t % 5) == 0)
                printf("[板卡] t=%6.1fs Vout=%6.2fV Iout=%5.2fA Duty=%5.1f%% SET=%6.2fV PLST=0x%04X 故障=%u 日志=%lu行\n",
                       b.t, (double)s.v_out, (double)s.i_out, (double)s.duty, (double)s.v_set,
                       (unsigned)s.reserved, (unsigned)s.fault, csv.rows);
        }

        if (duration > 0 && b.t >= duration) break;
    }

    if (verbose) {
        printf("[板卡] 退出：收帧=%lu 发帧=%lu 保护=%lu次 上位机掉线=%lu次 无新采样块=%lu CSV=%lu行\n",
               b.rx_frames, b.tx_frames, b.trips, b.host_drops, b.frame_retry_fail, csv.rows);
        if (b.use_pl) {
            printf("[板卡] 0x5C 非法命令标志=%d；已消费采样块=%lu\n",
                   pl_illegal_flag(&b.pl), b.blocks_rx);
            printf("[板卡] FDMA: producer=%u consumer=%u status=0x%X error=0x%X FIFO_LEVEL=%u DROP=%u\n",
                   fd_rd(&b.pl, FD_PRODUCER), fd_rd(&b.pl, FD_CONSUMER),
                   fd_rd(&b.pl, FD_STATUS), fd_rd(&b.pl, FD_ERROR),
                   pl_rd(&b.pl, PL_FIFO_LEVEL), pl_rd(&b.pl, PL_FIFO_DROP));
        }
    }
    if (g_dcd1_fd >= 0) { close(g_dcd1_fd); g_dcd1_fd = -1; }
    if (g_dcd1_host[0] && verbose) printf("[dcd1] sent %lu packets, net drop %lu\n", g_dcd1_pkts, g_dcd1_net_drop);
    if (cfd >= 0) close(cfd);
    if (lfd >= 0) close(lfd);
    csv_close(&csv);
    if (can.fd >= 0) close(can.fd);
    if (b.use_pl) pl_close(&b.pl);
    return 0;
}
