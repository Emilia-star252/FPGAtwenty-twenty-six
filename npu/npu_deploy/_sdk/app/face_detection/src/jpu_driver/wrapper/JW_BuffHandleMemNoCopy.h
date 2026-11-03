/****************************************************************
 * Copyright (c) 2023 - 2024 Anlogic, Inc.  All rights reserved.
 * SPDX-License-Identifier: MIT
 ****************************************************************/

#pragma once
#include "JW_BuffHandleMem.h"
#include "jputypes.h"
#ifdef __cplusplus
extern "C" {
#endif // __cplusplus

typedef struct {
    JW_BuffHandleMem_t hm;
    void *jpg_header;
    Uint32 jpg_header_size;
} JW_BuffHandleMemNoCopy_t;

/**
 * @brief 在JPU_Init 和 JPU_Deinit之间调用
 *
 * @param handle
 * @param jbf_size JPU Buff的大小
 */
int JW_BuffHandleMemNoCopy_Init(JW_BuffHandleMemNoCopy_t *handle, Uint32 jbf_size);

/**
 * @brief  在JPU_Init 和 JPU_Deinit之间调用
 *
 * @param handle
 */
void JW_BuffHandleMemNoCopy_DeInit(JW_BuffHandleMemNoCopy_t *handle);

#ifdef __cplusplus
}
#endif // __cplusplus
