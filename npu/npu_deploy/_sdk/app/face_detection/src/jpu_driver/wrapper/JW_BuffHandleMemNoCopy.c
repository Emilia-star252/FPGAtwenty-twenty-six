/****************************************************************
 * Copyright (c) 2023 - 2024 Anlogic, Inc.  All rights reserved.
 * SPDX-License-Identifier: MIT
 ****************************************************************/

#include "JW_BuffHandleMemNoCopy.h"
#include <assert.h>
#include <string.h>

static struct JW_BuffHandleVtable s_JW_BuffHandleMemNoCpy_vtable;
static struct JW_BuffHandleVtable *p_JW_BuffHandleMemNoCpy_vtable = NULL;
static struct JW_BuffHandleVtable *p_JW_BuffHandleMem_vtable_backup = NULL;

#define _FORCE_THIS (JW_BuffHandleMemNoCopy_t *)((size_t)(void *)p - (size_t)(void *)(&((JW_BuffHandleMemNoCopy_t *)0)->hm.base))

static void JW_BuffHandleMemNoCopy_DeInit2(struct JW_BuffHandleBase *p) {
    JW_BuffHandleMemNoCopy_t *P = _FORCE_THIS;
    p_JW_BuffHandleMem_vtable_backup->DeInit(&P->hm.base);
    if (P->jpg_header) {
        free(P->jpg_header);
        P->jpg_header = 0;
    }
}

static void *JW_BuffHandleMemNoCopy_HeaderWrite(struct JW_BuffHandleBase *p, Uint32 reserve_size) {
    JW_BuffHandleMemNoCopy_t *P = _FORCE_THIS;
    if (P->jpg_header == NULL) {
        P->jpg_header_size = reserve_size;
        P->jpg_header = malloc(reserve_size);
    }
    assert(P->jpg_header);
    return P->jpg_header;
}

static void JW_BuffHandleMemNoCopy_HeaderWriteFinish(struct JW_BuffHandleBase *p, Uint32 write_size) {
    JW_BuffHandleMemNoCopy_t *P = _FORCE_THIS;
    P->jpg_header_size = write_size;
}

int JW_BuffHandleMemNoCopy_Init(JW_BuffHandleMemNoCopy_t *handle, Uint32 jbf_size) {
    memset(handle, 0, sizeof(JW_BuffHandleMemNoCopy_t));
    int ret = JW_BuffHandleMem_Init(&handle->hm, jbf_size, NULL, jbf_size);
    if (ret)
        return ret;

    if (p_JW_BuffHandleMemNoCpy_vtable == NULL) {
        p_JW_BuffHandleMemNoCpy_vtable = &s_JW_BuffHandleMemNoCpy_vtable;
        p_JW_BuffHandleMem_vtable_backup = handle->hm.base.vtable;
        memcpy(p_JW_BuffHandleMemNoCpy_vtable, p_JW_BuffHandleMem_vtable_backup, sizeof(struct JW_BuffHandleVtable));
        // 重载下列函数
        p_JW_BuffHandleMemNoCpy_vtable->DeInit = JW_BuffHandleMemNoCopy_DeInit2;
        p_JW_BuffHandleMemNoCpy_vtable->HeaderWrite = JW_BuffHandleMemNoCopy_HeaderWrite;
        p_JW_BuffHandleMemNoCpy_vtable->HeaderWriteFinish = JW_BuffHandleMemNoCopy_HeaderWriteFinish;
    }
    handle->hm.base.vtable = p_JW_BuffHandleMemNoCpy_vtable;
    return ret;
}

void JW_BuffHandleMemNoCopy_DeInit(JW_BuffHandleMemNoCopy_t *handle) {
    JW_BuffHandleMemNoCopy_DeInit2(&handle->hm.base);
}