/****************************************************************
 * Copyright (c) 2023 - 2024 Anlogic, Inc.  All rights reserved.
 * SPDX-License-Identifier: MIT
 ****************************************************************/

#include "JW_BuffHandleMem.h"
#include "jdi.h"
#include "jpuapi.h"
#include <assert.h>
#include <stddef.h>
#ifndef container_of
#define container_of(ptr, type, member)                           \
    __extension__({                                               \
        const __typeof__(((type *)0)->member) *__pmember = (ptr); \
        (type *)((char *)__pmember - offsetof(type, member));     \
    })
#endif
#define _FORCE_THIS container_of(p, JW_BuffHandleMem_t, base)
#ifndef MIN
#define MIN(x, y) ((x) < (y) ? (x) : (y))
#endif // !MIN

/**
 * @brief 析构
 *
 * @param p
 */
static void JW_BuffHandleMem_DeInit2(struct JW_BuffHandleBase *p) {
    JW_BuffHandleMem_t *P = _FORCE_THIS;
    if (P->jbf.size != 0) {
        jdi_free_dma_memory(&P->jbf);
        P->jbf.size = 0;
    }
}

/**
 * @brief 返回JPU buff的物理地址,必须4kB对齐
 *
 * @param p
 * @return PhysicalAddress
 */
static PhysicalAddress JW_BuffHandleMem_GetPhysAddr(struct JW_BuffHandleBase *p) {
    JW_BuffHandleMem_t *P = _FORCE_THIS;
    return P->jbf.phys_addr;
}

/**
 * @brief 返回JPU buff的CPU访问地址
 *
 * @param p
 * @return void*
 */
static void *JW_BuffHandleMem_GetVirtAddr(struct JW_BuffHandleBase *p) {
    JW_BuffHandleMem_t *P = _FORCE_THIS;
    return (void *)P->jbf.virt_addr;
}

/**
 * @brief 返回JPU buff的大小,必须4kB对齐
 *
 * @param p
 * @return Uint32
 */
static Uint32 JW_BuffHandleMem_GetSize(struct JW_BuffHandleBase *p) {
    JW_BuffHandleMem_t *P = _FORCE_THIS;
    return P->jbf.size;
}

/**
 * @brief 调整JPU buff的大小,假设是扩容的话
 *
 * @param p
 * @param new_cap_size
 * @return Uint32
 */
static Uint32 JW_BuffHandleMem_Reserve(struct JW_BuffHandleBase *p, Uint32 new_cap_size) {
    new_cap_size = (new_cap_size + 4095) & (~4095);
    JW_BuffHandleMem_t *P = _FORCE_THIS;
    if (new_cap_size <= P->jbf.size)
        return P->jbf.size;
    if (P->jbf.size != 0) {
        jdi_free_dma_memory(&P->jbf);
    }
    P->jbf.size = new_cap_size;
    jdi_allocate_dma_memory(&P->jbf);
    assert(P->jbf.phys_addr != 0);
    if (P->mem == NULL)
        P->mem_size = P->jbf.size;
    return P->jbf.size;
}

/**
 * @brief 通知BuffHandle从外部往JPU buff写入内容,返回写入字节数
 *
 * @param p
 * @param feed_size
 * @return Uint32
 */
static Uint32 JW_BuffHandleMem_FeedAct(struct JW_BuffHandleBase *p, Uint32 feed_size) {
    JW_BuffHandleMem_t *P = _FORCE_THIS;
    assert(P->jbf.phys_addr);
    feed_size = MIN(feed_size, P->mem_size - P->mem_offset);
    if (feed_size >= P->jbf.size - P->jbf_offset) {
        Uint32 ret;
        if (P->mem != NULL)
            memcpy((void *)P->jbf.virt_addr + P->jbf_offset, P->mem + P->mem_offset, P->jbf.size - P->jbf_offset);
        ret = P->jbf.size - P->jbf_offset;
        P->jbf_offset = 0;
        P->mem_offset += ret;
        if (P->mem == NULL)
            assert(P->mem_offset <= P->jbf.size);
        return ret;
    } else {
        if (P->mem != NULL)
            memcpy((void *)P->jbf.virt_addr + P->jbf_offset, P->mem + P->mem_offset, feed_size);
        P->jbf_offset = feed_size;
        P->mem_offset += feed_size;
        if (P->mem == NULL)
            assert(P->mem_offset <= P->jbf.size);
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
static Uint32 JW_BuffHandleMem_WriteAct(struct JW_BuffHandleBase *p, Uint32 write_size) {
    JW_BuffHandleMem_t *P = _FORCE_THIS;
    assert(P->jbf.phys_addr);
    write_size = MIN(write_size, P->mem_size - P->mem_offset);
    if (write_size >= P->jbf.size - P->jbf_offset) {
        Uint32 ret;
        if (P->mem != NULL)
            memcpy(P->mem + P->mem_offset, (void *)P->jbf.virt_addr + P->jbf_offset, P->jbf.size - P->jbf_offset);
        ret = P->jbf.size - P->jbf_offset;
        P->jbf_offset = 0;
        P->mem_offset += ret;
        if (P->mem == NULL)
            assert(P->mem_offset <= P->jbf.size);
        return ret;
    } else {
        if (P->mem != NULL)
            memcpy(P->mem + P->mem_offset, (void *)P->jbf.virt_addr + P->jbf_offset, write_size);
        P->jbf_offset = write_size;
        P->mem_offset += write_size;
        if (P->mem == NULL)
            assert(P->mem_offset <= P->jbf.size);
        return write_size;
    }
}

/**
 * @brief 返回WriteAct的总写入
 *
 * @param p
 * @return Uint32
 */
static Uint32 JW_BuffHandleMem_GetWriteSize(struct JW_BuffHandleBase *p) {
    JW_BuffHandleMem_t *P = _FORCE_THIS;
    return P->mem_offset;
}

/**
 * @brief 重置读写偏移状态
 *
 * @param p
 */
static void JW_BuffHandleMem_ResetWrRdPtr(struct JW_BuffHandleBase *p, BOOL update_mem_offset) {
    JW_BuffHandleMem_t *P = _FORCE_THIS;
    P->jbf_offset = 0;
    if (update_mem_offset)
        P->mem_offset = 0;
}

/**
 * @brief 提供写入Jpg Header的CPU访问地址,将在HeaderWriteFinish通知写入完成
 *
 * @param[in] p
 * @param[in] reserve_size
 * @return void*
 */
static void *JW_BuffHandleMem_HeaderWrite(struct JW_BuffHandleBase *p, Uint32 reserve_size) {
    JW_BuffHandleMem_t *P = _FORCE_THIS;
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
static void JW_BuffHandleMem_HeaderWriteFinish(struct JW_BuffHandleBase *p, Uint32 write_size) {
    JW_BuffHandleMem_WriteAct(p, write_size);
    JW_BuffHandleMem_t *P = _FORCE_THIS;
    P->jbf_offset = 0;
}

static struct JW_BuffHandleVtable s_JW_BuffHandleMem_vtable = {
    JW_BuffHandleMem_DeInit2,
    JW_BuffHandleMem_GetPhysAddr,
    JW_BuffHandleMem_GetVirtAddr,
    JW_BuffHandleMem_GetSize,
    JW_BuffHandleMem_Reserve,
    JW_BuffHandleMem_FeedAct,
    JW_BuffHandleMem_WriteAct,
    JW_BuffHandleMem_GetWriteSize,
    JW_BuffHandleMem_ResetWrRdPtr,
    JW_BuffHandleMem_HeaderWrite,
    JW_BuffHandleMem_HeaderWriteFinish};

int JW_BuffHandleMem_Init(JW_BuffHandleMem_t *handle, Uint32 jbf_size, void *buff, Uint32 buff_size) {
    assert(JPU_IsInit());
    memset(handle, 0, sizeof(JW_BuffHandleMem_t));
    handle->base.vtable = &s_JW_BuffHandleMem_vtable;
    jbf_size = (jbf_size + 4095) & (~4095);
    if (jbf_size != 0)
        JW_BuffHandleMem_Reserve(&handle->base, jbf_size);
    handle->mem = buff;
    handle->mem_size = buff_size;
    return handle->jbf.size == 0 ? 0 : (handle->jbf.phys_addr == 0 ? -1 : 0);
}

void JW_BuffHandleMem_DeInit(JW_BuffHandleMem_t *handle) {
    assert(JPU_IsInit());
    return JW_BuffHandleMem_DeInit2(&handle->base);
}