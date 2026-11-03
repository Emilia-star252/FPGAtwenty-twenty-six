/* probe_ddr.c —— 只在板上探两类内存能不能碰：
 *   0x3FC00000  DDR 采样环（power_svc 的 --ddr-base 默认值，需要 DTS reserved-memory）
 *   0x80000000  GP0 寄存器
 * 读一个字 + 写一个字（只在环里写回原值）。SIGBUS 就是没映射/没保留。
 */
#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>

static const char *g_where = "?";
static void on_fault(int sig) {
    fprintf(stderr, "[probe] SIG%d while touching %s -> 该物理区间不可访问\n", sig, g_where);
    _exit(3);
}

static int touch(unsigned long phys, const char *name, int do_write) {
    int fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (fd < 0) { perror("open /dev/mem"); return 1; }
    long page = sysconf(_SC_PAGESIZE);
    unsigned long base = phys & ~(unsigned long)(page - 1);
    size_t len = (phys - base) + 0x1000;
    void *p = mmap(NULL, len, PROT_READ | PROT_WRITE, MAP_SHARED, fd, (off_t)base);
    if (p == MAP_FAILED) { perror("mmap"); close(fd); return 1; }
    g_where = name;
    volatile unsigned int *q = (volatile unsigned int *)((char *)p + (phys - base));
    unsigned int v = *q;
    printf("[probe] %s 0x%08lx read=0x%08x", name, phys, v);
    if (do_write) { *q = v; printf(" write=ok"); }
    printf("\n");
    munmap(p, len);
    close(fd);
    return 0;
}

int main(void) {
    signal(SIGBUS, on_fault);
    signal(SIGSEGV, on_fault);
    unsigned long gp0 = 0x80000000UL, ddr = 0x3FC00000UL;
    int rc = 0;
    rc |= touch(gp0 + 0x0, "GP0_ID", 0);
    rc |= touch(gp0 + 0x58, "GP0_0x58", 0);
    rc |= touch(ddr, "DDR_RING[0]", 1);            /* 写回原值，验证是否可写 */
    rc |= touch(ddr + 0x1000, "DDR_RING[1slot]", 0);
    rc |= touch(ddr + 4095, "DDR_RING[last]", 0);
    printf("[probe] done rc=%d\n", rc);
    return rc;
}
