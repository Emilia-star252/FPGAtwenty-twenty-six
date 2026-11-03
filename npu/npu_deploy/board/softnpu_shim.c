/*
 * softnpu_shim.c —— 在没有 soft_npu 设备树节点/PL IP 的镜像上，让 armnn 的 Alnpu 后端能初始化。
 *
 * 背景：libarmnn 的 Alnpu 后端在建 IRuntime 时无条件打开 /dev/soft_npu 并
 *       ioctl(GET_REGISTER_INFO) + mmap 寄存器区；我们的镜像只编了硬 NPU 的 DT 节点，
 *       soft_npu.ko 的 probe 不会跑，所以 open 必然失败 → 整个 Alnpu 后端不可用（连硬 NPU 一起）。
 *
 * 做法：LD_PRELOAD 一个垫片，只对 "/dev/soft_npu" 这一个路径作假：
 *       open   -> /dev/zero
 *       ioctl  -> GET_REGISTER_INFO 返回一块假地址；READ/WRITE_REG/WAIT 直接成功
 *       mmap   -> 匿名内存（读写落在自己的页里，不会碰不存在的 AXI 从设备）
 *
 * 风险：这会让“软 NPU 算子”看起来可用但实际不工作。所以只跑纯硬 NPU 的图（Conv/FC），
 *       看到结果必须用 IRQ 计数 + PC 侧概率对拍来验证，不能只看“跑通了”。
 */

#define _GNU_SOURCE
#include <dlfcn.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <unistd.h>

static int g_fake_fd = -1;
static int (*real_open)(const char *, int, ...);
static int (*real_open64)(const char *, int, ...);
static int (*real_ioctl)(int, unsigned long, ...);
static void *(*real_mmap)(void *, size_t, int, int, int, off_t);

static void shim_init(void) {
    if (!real_open) {
        real_open = (int (*)(const char *, int, ...))dlsym(RTLD_NEXT, "open");
        real_open64 = (int (*)(const char *, int, ...))dlsym(RTLD_NEXT, "open64");
        real_ioctl = (int (*)(int, unsigned long, ...))dlsym(RTLD_NEXT, "ioctl");
        real_mmap = (void *(*)(void *, size_t, int, int, int, off_t))dlsym(RTLD_NEXT, "mmap");
    }
}

static int maybe_fake(const char *path) {
    if (path && strstr(path, "soft_npu")) {
        if (g_fake_fd < 0) {
            g_fake_fd = real_open("/dev/zero", O_RDWR);
            fprintf(stderr, "[shim] /dev/soft_npu 用假设备代替（fd=%d）\n", g_fake_fd);
        }
        return g_fake_fd;
    }
    return -1;
}

int open(const char *path, int flags, ...) {
    shim_init();
    mode_t mode = 0;
    if (flags & O_CREAT) {
        va_list ap;
        va_start(ap, flags);
        mode = (mode_t)va_arg(ap, int);
        va_end(ap);
    }
    int f = maybe_fake(path);
    return f >= 0 ? f : real_open(path, flags, mode);
}

int open64(const char *path, int flags, ...) {
    shim_init();
    mode_t mode = 0;
    if (flags & O_CREAT) {
        va_list ap;
        va_start(ap, flags);
        mode = (mode_t)va_arg(ap, int);
        va_end(ap);
    }
    int f = maybe_fake(path);
    return f >= 0 ? f : (real_open64 ? real_open64(path, flags, mode) : real_open(path, flags, mode));
}

int ioctl(int fd, unsigned long req, ...) {
    shim_init();
    void *arg = NULL;
    va_list ap;
    va_start(ap, req);
    arg = va_arg(ap, void *);
    va_end(ap);

    if (fd == g_fake_fd) {
        struct { uint64_t addr, size; } *reg;
        switch (req) {
            case _IO('S', 1):   /* GET_REGISTER_INFO */
                reg = (void *)arg;
                if (reg) { reg->addr = 0x1f0000000ULL; reg->size = 0x10000; }
                return 0;
            case _IO('S', 3):   /* READ_REG：假装寄存器是 0 */
                if (arg) ((struct { uint32_t addr, data; } *)arg)->data = 0;
                return 0;
            case _IO('S', 0):   /* WAIT_INTERRUPT */
            case _IO('S', 2):   /* WRITE_REG */
                return 0;
            default:
                return 0;
        }
    }
    return real_ioctl(fd, req, arg);
}

void *mmap(void *addr, size_t len, int prot, int flags, int fd, off_t off) {
    shim_init();
    if (fd == g_fake_fd) {
        void *p = real_mmap(NULL, len, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
        fprintf(stderr, "[shim] soft_npu 寄存器区映射到匿名内存 %p (%zu B)\n", p, len);
        return p;
    }
    return real_mmap(addr, len, prot, flags, fd, off);
}

void *mmap64(void *addr, size_t len, int prot, int flags, int fd, off_t off) {
    return mmap(addr, len, prot, flags, fd, off);
}
