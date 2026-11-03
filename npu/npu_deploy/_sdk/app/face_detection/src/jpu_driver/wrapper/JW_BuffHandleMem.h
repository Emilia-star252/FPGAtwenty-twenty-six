/****************************************************************
 * Copyright (c) 2023 - 2024 Anlogic, Inc.  All rights reserved.
 * SPDX-License-Identifier: MIT
 ****************************************************************/

#pragma once
#include "JW_BuffHandleBase.h"
#include "jdi.h"
#include "jputypes.h"
#ifdef __cplusplus
extern "C" {
#endif // __cplusplus

/**
 * @brief 代理JPU Buff和缓存的数据拷贝
 *
 */
typedef struct JW_BuffHandleMem {
    JW_BuffHandleBase_t base;
    void *mem;
    Uint32 mem_size;
    Uint32 mem_offset;
    jpu_buffer_t jbf;
    Uint32 jbf_offset;
} JW_BuffHandleMem_t;

/**
 * @brief 在JPU_Init 和 JPU_Deinit之间调用
 *
 * @param handle
 * @param jbf_size JPU Buff的大小
 * @param buff 缓存地址,为NULL则不代理数据拷贝,但jbf_size必须大于之后执行FeedAct\WriteAct的大小
 * @param buff_size 缓存大小
 * @return int 0为正常其余错误
 */
int JW_BuffHandleMem_Init(JW_BuffHandleMem_t *handle, Uint32 jbf_size, void *buff, Uint32 buff_size);

/**
 * @brief  在JPU_Init 和 JPU_Deinit之间调用
 *
 * @param handle
 */
void JW_BuffHandleMem_DeInit(JW_BuffHandleMem_t *handle);

#ifdef __cplusplus
}
#endif // __cplusplus
