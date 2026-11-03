/* probe_fdma.c —— 看 PL 到底有没有在产采样：读 FDMA 状态/生产者，隔 1 s 再读一次，
 * 再把这 1 s 内新增块的最后一块按 P481 帧解出来（V/I/duty）。
 * 只读，不写任何控制寄存器（除了不动 consumer），所以可以安全地在 power_svc 运行时跑。
 *
 * 帧格式（power_svc 注释）：每块 4096B = 256 帧 × 16B；
 *   帧 = V(int48 Q16, 6B) + I(int48 Q16, 6B) + duty(uint32)
 */
#include <fcntl.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>

#define FD_BASE   0x80010000UL
#define DDR_BASE  0x3FC00000UL
#define BLOCK     4096u

static volatile uint32_t *fd;
static volatile uint8_t *ring;

static void on_fault(int sig) { fprintf(stderr, "[fdma] SIG%d\n", sig); _exit(3); }

static int64_t dec48(const uint8_t *p) {
    int64_t v = 0;
    for (int k = 0; k < 6; ++k) v |= (int64_t)p[k] << (8 * k);
    if (v & (1LL << 47)) v -= (1LL << 48);
    return v;
}

int main(int argc, char **argv) {
    signal(SIGBUS, on_fault);
    signal(SIGSEGV, on_fault);
    unsigned long ddr = argc > 1 ? strtoul(argv[1], NULL, 0) : DDR_BASE;

    int fd_mem = open("/dev/mem", O_RDWR | O_SYNC);
    if (fd_mem < 0) { perror("open /dev/mem"); return 1; }
    long pg = sysconf(_SC_PAGESIZE);
    fd = (volatile uint32_t *)mmap(NULL, 0x1000, PROT_READ | PROT_WRITE, MAP_SHARED, fd_mem, (off_t)(FD_BASE & ~(unsigned long)(pg - 1)));
    if (fd == MAP_FAILED) { perror("mmap fdma"); return 1; }
    /* 环基址由 PL 决定，别写死 */
    unsigned long ring_base = ((unsigned long)fd[0x14 / 4] << 32) | fd[0x10 / 4];
    if (ring_base == 0) ring_base = ddr;
    ring = (volatile uint8_t *)mmap(NULL, 4 * 1024 * 1024, PROT_READ, MAP_SHARED, fd_mem, (off_t)ring_base);
    if (ring == MAP_FAILED) { perror("mmap ring"); return 1; }
    printf("[fdma] ring_base=0x%lx (from FD_BASE registers)\n", ring_base);

    printf("[fdma] ID=0x%08x FORMAT=0x%08x STATUS=0x%08x ERROR=0x%08x\n",
           fd[0x00 / 4], fd[0x28 / 4], fd[0x08 / 4], fd[0x0C / 4]);
    printf("[fdma] CONTROL=0x%08x BASE=0x%08x%08x SLOTS=%u BLOCK_BYTES=%u\n",
           fd[0x04 / 4], fd[0x14 / 4], fd[0x10 / 4], fd[0x18 / 4], fd[0x24 / 4]);

    uint32_t p0 = fd[0x1C / 4], c0 = fd[0x20 / 4];
    printf("[fdma] t0: producer=%u consumer=%u\n", p0, c0);
    sleep(1);
    uint32_t p1 = fd[0x1C / 4], c1 = fd[0x20 / 4];
    printf("[fdma] t1: producer=%u consumer=%u  (+%u blocks in 1s)\n", p1, c1, p1 - p0);

    if (p1 == p0) {
        printf("[fdma] FAIL: producer 没有增长 —— PL 没有在产采样\n");
        return 2;
    }
    uint32_t slots = fd[0x18 / 4];
    uint32_t slot = (p1 - 1) & (slots - 1);
    const uint8_t *blk = (const uint8_t *)ring + (size_t)slot * BLOCK;
    const uint8_t *f = blk + 255 * 16;             /* 最后一块的最后一帧 */
    int64_t vq = dec48(f);
    int64_t iq = dec48(f + 6);
    uint32_t dq = (uint32_t)f[12] | ((uint32_t)f[13] << 8) | ((uint32_t)f[14] << 16) | ((uint32_t)f[15] << 24);
    printf("[fdma] last frame: V=%.4f V  I=%.4f A  duty=%.2f%%\n",
           (double)vq / 65536.0, (double)iq / 65536.0, (double)dq * 100.0 / 65536.0);
    printf("[fdma] OK\n");
    return 0;
}
