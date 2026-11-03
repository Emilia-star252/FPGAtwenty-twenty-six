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

typedef struct JW_EncoderContext {
    JpgEncHandle handle;
    JpgEncOpenParam encOP;
    JpgEncParam encParam;
    JpgEncOutputInfo outputInfo;
    JpgEncParamSet encHeaderParam;

    Uint32 encHeaderMode; // always 0
    int profilingEnable;
    Uint32 stuffByteEnable; // enable StuffByte
    Uint32 encQualityPercentage; //
    JpgRet ret;
    FrameBuffer frameBuf;         // 存储解码的YUV数据的偏移地址信息，指向yuvFeed所在的JPU Buff
    size_t frameBufSize;          // 存储frameBuf的总内存占用
    JW_BuffHandleBase_t *bsWrite; // handle for jpg-stream
    JW_BuffHandleBase_t *yuvFeed; // handle for yuv-frame
} JW_EncoderContext_t;

void JW_EncoderContextSetDefault(JW_EncoderContext_t *context);

void JW_EncoderContextSetHuffTable(JW_EncoderContext_t *context);

JpgRet JW_EncoderInit(JW_EncoderContext_t *context);

JpgRet JW_EncoderRegisterFrameBuffer(JW_EncoderContext_t *context, JW_BuffHandleBase_t *yuvFeed);

JpgRet JW_EncoderDeInit(JW_EncoderContext_t *context);

BOOL JW_EncoderAct(JW_EncoderContext_t *context);

JpgRet JW_EncoderBitstreamRefresh(JW_EncoderContext_t *context);

#ifdef __cplusplus
}
#endif // __cplusplus