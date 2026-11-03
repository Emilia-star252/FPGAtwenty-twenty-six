/****************************************************************
 * Copyright (c) 2023 - 2024 Anlogic, Inc.  All rights reserved.
 * SPDX-License-Identifier: MIT
 ****************************************************************/

#pragma once
#include "JW_BuffHandleBase.h"
#include "jpuapi.h"
#ifdef __cplusplus
extern "C" {
#endif // __cplusplus

typedef struct JW_DecoderContext {
    JpgDecHandle handle;
    JpgDecInitialInfo initialInfo;
    JpgDecOutputInfo outputInfo;
    JpgDecOpenParam decOP;
    JpgDecParam decParam;
    int profilingEnable;
    JpgRet ret;
    FrameBuffer frameBuf;          // 存储解码的YUV数据的偏移地址信息，指向yuvWrite所在的JPU Buff
    size_t frameBufSize;           // 存储frameBuf的总内存占用
    int frameIdx;                  // 多frame的情况下，指示已经解码了多少个frame
    JW_BuffHandleBase_t *bsFeed;   // handle for jpg-stream
    JW_BuffHandleBase_t *yuvWrite; // handle for yuv-frame
} JW_DecoderContext_t;

void JW_DecoderContextSetDefault(JW_DecoderContext_t *context);

JpgRet JW_DecoderInit(JW_DecoderContext_t *context);

JpgRet JW_DecoderRegisterFrameBuffer(JW_DecoderContext_t *context, JW_BuffHandleBase_t *yuvWrite);

JpgRet JW_DecoderDeInit(JW_DecoderContext_t *context);

BOOL JW_DecoderAct(JW_DecoderContext_t *context);

JpgRet JW_DecoderBitstreamRefresh(JW_DecoderContext_t *context);

#ifdef __cplusplus
}
#endif // __cplusplus