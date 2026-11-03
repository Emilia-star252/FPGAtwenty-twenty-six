/****************************************************************
 * Copyright (c) 2023 - 2024 Anlogic, Inc.  All rights reserved.
 * SPDX-License-Identifier: MIT
 ****************************************************************/

#include "JW_BuffHandleFile.h"
#include "jdi.h"
#include "jpuapi.h"
#include <assert.h>
#include <fcntl.h>
#include <stddef.h>
#include <unistd.h>
#ifndef container_of
#define container_of(ptr, type, member)                           \
    __extension__({                                               \
        const __typeof__(((type *)0)->member) *__pmember = (ptr); \
        (type *)((char *)__pmember - offsetof(type, member));     \
    })
#endif
#define _FORCE_THIS container_of(p, JW_BuffHandleFile_t, base)
#ifndef MIN
#define MIN(x, y) ((x) < (y) ? (x) : (y))
#endif // !MIN

/**
 * @brief 析构
 *
 * @param p
 */
static void JW_BuffHandleFile_DeInit2(struct JW_BuffHandleBase *p) {
    JW_BuffHandleFile_t *P = _FORCE_THIS;
    if (P->jbf.size != 0) {
        jdi_free_dma_memory(&P->jbf);
        P->jbf.size = 0;
    }
    if (P->fd > 0) {
        close(P->fd);
        P->fd = 0;
    }
}

/**
 * @brief 返回JPU buff的物理地址,必须4kB对齐
 *
 * @param p
 * @return PhysicalAddress
 */
static PhysicalAddress JW_BuffHandleFile_GetPhysAddr(struct JW_BuffHandleBase *p) {
    JW_BuffHandleFile_t *P = _FORCE_THIS;
    return P->jbf.phys_addr;
}

/**
 * @brief 返回JPU buff的CPU访问地址
 *
 * @param p
 * @return void*
 */
static void *JW_BuffHandleFile_GetVirtAddr(struct JW_BuffHandleBase *p) {
    JW_BuffHandleFile_t *P = _FORCE_THIS;
    return (void *)P->jbf.virt_addr;
}

/**
 * @brief 返回JPU buff的大小,必须4kB对齐
 *
 * @param p
 * @return Uint32
 */
static Uint32 JW_BuffHandleFile_GetSize(struct JW_BuffHandleBase *p) {
    JW_BuffHandleFile_t *P = _FORCE_THIS;
    return P->jbf.size;
}

/**
 * @brief 调整JPU buff的大小,假设是扩容的话
 *
 * @param p
 * @param new_cap_size
 * @return Uint32
 */
static Uint32 JW_BuffHandleFile_Reserve(struct JW_BuffHandleBase *p, Uint32 new_cap_size) {
    new_cap_size = (new_cap_size + 4095) & (~4095);
    JW_BuffHandleFile_t *P = _FORCE_THIS;
    if (new_cap_size <= P->jbf.size)
        return P->jbf.size;
    if (P->jbf.size != 0) {
        jdi_free_dma_memory(&P->jbf);
    }
    P->jbf.size = new_cap_size;
    jdi_allocate_dma_memory(&P->jbf);
    assert(P->jbf.phys_addr != 0);
    return P->jbf.size;
}

/**
 * @brief 通知BuffHandle从外部往JPU buff写入内容,返回写入字节数
 *
 * @param p
 * @param feed_size
 * @return Uint32
 */
static Uint32 JW_BuffHandleFile_FeedAct(struct JW_BuffHandleBase *p, Uint32 feed_size) {
    JW_BuffHandleFile_t *P = _FORCE_THIS;
    assert(P->jbf.phys_addr);
    feed_size = MIN(feed_size, P->f_size - P->f_offset);
    if (feed_size >= P->jbf.size - P->jbf_offset) {
        Uint32 ret;
        if (P->fd > 0)
            read(P->fd, (void *)P->jbf.virt_addr + P->jbf_offset, P->jbf.size - P->jbf_offset);
        ret = P->jbf.size - P->jbf_offset;
        P->jbf_offset = 0;
        P->f_offset += ret;
        if (P->fd <= 0)
            assert(P->f_offset <= P->jbf.size);
        return ret;
    } else {
        if (P->fd > 0)
            read(P->fd, (void *)P->jbf.virt_addr + P->jbf_offset, feed_size);
        P->jbf_offset = feed_size;
        P->f_offset += feed_size;
        if (P->fd <= 0)
            assert(P->f_offset <= P->jbf.size);
        return feed_size;
    }
}

/**
 * @brief 通知BuffHandle从JPU buff往外部写入内容,返回写入字节数
 *
 * @param p
 * @param write_size
 * @return Uint32
 */
static Uint32 JW_BuffHandleFile_WriteAct(struct JW_BuffHandleBase *p, Uint32 write_size) {
    JW_BuffHandleFile_t *P = _FORCE_THIS;
    assert(P->jbf.phys_addr);
    if (write_size >= P->jbf.size - P->jbf_offset) {
        Uint32 ret;
        if (P->fd > 0)
            write(P->fd, (void *)P->jbf.virt_addr + P->jbf_offset, P->jbf.size - P->jbf_offset);
        ret = P->jbf.size - P->jbf_offset;
        P->jbf_offset = 0;
        P->f_offset += ret;
        if (P->fd <= 0)
            assert(P->f_offset <= P->jbf.size);
        return ret;
    } else {
        if (P->fd > 0)
            write(P->fd, (void *)P->jbf.virt_addr + P->jbf_offset, write_size);
        P->jbf_offset = write_size;
        P->f_offset += write_size;
        if (P->fd <= 0)
            assert(P->f_offset <= P->jbf.size);
        return write_size;
    }
}

/**
 * @brief 返回WriteAct的总写入
 *
 * @param p
 * @return Uint32
 */
static Uint32 JW_BuffHandleFile_GetWriteSize(struct JW_BuffHandleBase *p) {
    JW_BuffHandleFile_t *P = _FORCE_THIS;
    return P->f_offset;
}

/**
 * @brief 重置读写偏移状态
 *
 * @param p
 */
static void JW_BuffHandleFile_ResetWrRdPtr(struct JW_BuffHandleBase *p, BOOL update_mem_offset) {
    JW_BuffHandleFile_t *P = _FORCE_THIS;
    P->jbf_offset = 0;
    if (update_mem_offset) {
        P->f_offset = 0;
        if (P->fd > 0 && update_mem_offset)
            lseek(P->fd, 0, SEEK_SET);
    }
}

/**
 * @brief 提供写入Jpg Header的CPU访问地址,将在HeaderWriteFinish通知写入完成
 *
 * @param[in] p
 * @param[in] reserve_size
 * @return void*
 */
static void *JW_BuffHandleFile_HeaderWrite(struct JW_BuffHandleBase *p, Uint32 reserve_size) {
    JW_BuffHandleFile_t *P = _FORCE_THIS;
    assert(P->jbf_offset + reserve_size <= P->jbf.size);
    return (void *)P->jbf.virt_addr;
}

/**
 * @brief @ref {HeaderWrite}
 * <br/> 通知写入了write_size个字节
 *
 * @param p
 * @param write_size
 */
static void JW_BuffHandleFile_HeaderWriteFinish(struct JW_BuffHandleBase *p, Uint32 write_size) {
    JW_BuffHandleFile_WriteAct(p, write_size);
    JW_BuffHandleFile_t *P = _FORCE_THIS;
    P->jbf_offset = 0;
}

static struct JW_BuffHandleVtable s_JW_BuffHandleFile_vtable = {
    JW_BuffHandleFile_DeInit2,
    JW_BuffHandleFile_GetPhysAddr,
    JW_BuffHandleFile_GetVirtAddr,
    JW_BuffHandleFile_GetSize,
    JW_BuffHandleFile_Reserve,
    JW_BuffHandleFile_FeedAct,
    JW_BuffHandleFile_WriteAct,
    JW_BuffHandleFile_GetWriteSize,
    JW_BuffHandleFile_ResetWrRdPtr,
    JW_BuffHandleFile_HeaderWrite,
    JW_BuffHandleFile_HeaderWriteFinish};

int JW_BuffHandleFile_Init(JW_BuffHandleFile_t *handle, Uint32 jbf_size, int fd) {
    assert(JPU_IsInit());
    memset(handle, 0, sizeof(JW_BuffHandleFile_t));
    handle->base.vtable = &s_JW_BuffHandleFile_vtable;
    jbf_size = (jbf_size + 4095) & (~4095);
    if (jbf_size != 0)
        JW_BuffHandleFile_Reserve(&handle->base, jbf_size);
    // handle->fd = open(f_path, O_RDWR | O_CREAT);
    handle->fd = fd;
    if (handle->fd > 0) {
        handle->f_size = lseek(handle->fd, 0L, SEEK_END);
        lseek(handle->fd, 0L, SEEK_SET);
        return 0;
    }
    return -1;
}

void JW_BuffHandleFile_DeInit(JW_BuffHandleFile_t *handle) {
    assert(JPU_IsInit());
    return JW_BuffHandleFile_DeInit2(&handle->base);
}