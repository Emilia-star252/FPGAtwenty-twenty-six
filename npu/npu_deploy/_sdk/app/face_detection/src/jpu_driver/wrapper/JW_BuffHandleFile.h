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
typedef struct JW_BuffHandleFile {
    JW_BuffHandleBase_t base;
    int fd;
    Uint32 f_size;
    Uint32 f_offset;
    jpu_buffer_t jbf;
    Uint32 jbf_offset;
} JW_BuffHandleFile_t;

/**
 * @brief  在JPU_Init 和 JPU_Deinit之间调用
 *
 * @param handle
 * @param jbf_size JPU Buff的大小
 * @param fd 文件句柄
 * @return int 0为正常其余错误
 */
int JW_BuffHandleFile_Init(JW_BuffHandleFile_t *handle, Uint32 jbf_size, int fd);

/**
 * @brief  在JPU_Init 和 JPU_Deinit之间调用
 *
 * @param handle
 */
void JW_BuffHandleFile_DeInit(JW_BuffHandleFile_t *handle);

#ifdef __cplusplus
}
#endif // __cplusplus
