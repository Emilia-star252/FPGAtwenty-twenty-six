/****************************************************************
 * Copyright (c) 2023 - 2024 Anlogic, Inc.  All rights reserved.
 * SPDX-License-Identifier: MIT
 ****************************************************************/

#include "JW_Decoder.h"
#include "jpuapi.h"
#include "jpuconfig.h"
#include "jpulog.h"
#include "jpuapifunc.h"
#include "jputypes.h"
#include "regdefine.h"
#include <assert.h>
#include <endian.h>
#include <stdlib.h>
#include <string.h>

STATIC void GetFrameBufStride(
    FrameFormat subsample, CbCrInterLeave cbcrIntlv, PackedFormat packed, BOOL scalerOn,
    Uint32 width, Uint32 height, Uint32 bytePerPixel,
    Uint32 *oLumaStride, Uint32 *oLumaHeight, Uint32 *oChromaStride, Uint32 *oChromaHeight) {
    Uint32 lStride, cStride;
    Uint32 lHeight, cHeight;

    lStride = JPU_CEIL(8, width);
    // lStride = JPU_CEIL(128, width);   //To make luma, chroma 64ailgned addr
    lHeight = height;
    cHeight = (height + 1) / 2;

    if (packed == PACKED_FORMAT_NONE) {
        Uint32 chromaDouble = (cbcrIntlv == CBCR_SEPARATED) ? 1 : 2;

        switch (subsample) {
        case FORMAT_400:
            cStride = 0;
            cHeight = 0;
            break;
        case FORMAT_420:
            cStride = (lStride / 2) * chromaDouble;
            cHeight = (height + 1) / 2;
            break;
        case FORMAT_422:
            cStride = (lStride / 2) * chromaDouble;
            cHeight = height;
            break;
        case FORMAT_440:
            cStride = lStride * chromaDouble;
            cHeight = (height + 1) / 2;
            break;
        case FORMAT_444:
            cStride = lStride * chromaDouble;
            cHeight = height;
            break;
        default:
            cStride = 0;
            lStride = 0;
            cHeight = 0;
            break;
        }
    } else {
        switch (packed) {
        case PACKED_FORMAT_422_YUYV:
        case PACKED_FORMAT_422_UYVY:
        case PACKED_FORMAT_422_YVYU:
        case PACKED_FORMAT_422_VYUY:
            lStride = JPU_CEIL(32, lStride * 2);
            cStride = 0;
            cHeight = 0;
            break;
        case PACKED_FORMAT_444:
            lStride = lStride * 3;
            cStride = 0;
            cHeight = 0;
            break;
        default:
            lStride = 0;
            cStride = 0;
            break;
        }
    }

    if (scalerOn == TRUE) {
        /* Luma stride */
        if (subsample == FORMAT_420 || subsample == FORMAT_422 || (PACKED_FORMAT_422_YUYV <= packed && packed <= PACKED_FORMAT_422_VYUY)) {
            lStride = JPU_CEIL(32, lStride);
        } else {
            lStride = JPU_CEIL(16, lStride);
        }
        /* Chroma stride */
        if (cbcrIntlv == CBCR_SEPARATED) {
            if (subsample == FORMAT_444) {
                cStride = JPU_CEIL(16, cStride);
            } else {
                cStride = JPU_CEIL(8, cStride);
            }
        } else {
            cStride = JPU_CEIL(32, cStride);
        }
    } else {
        if (subsample == FORMAT_420 || subsample == FORMAT_422) {
            lStride = JPU_CEIL(16, lStride);
        } else {
            lStride = JPU_CEIL(8, lStride);
        }
    }
    if (subsample == FORMAT_420 || subsample == FORMAT_422) {
        if (cbcrIntlv == CBCR_SEPARATED)
            cStride = JPU_CEIL(8, cStride);
        else
            cStride = JPU_CEIL(16, cStride);
    } else {
        cStride = JPU_CEIL(8, cStride);
    }

    if (subsample == FORMAT_440) {
        lHeight = JPU_CEIL(16, lHeight);
    } else {
        lHeight = JPU_CEIL(8, lHeight);
    }
    cHeight = JPU_CEIL(8, cHeight);

    lStride *= bytePerPixel;
    cStride *= bytePerPixel;

    if (oLumaStride) *oLumaStride = lStride;
    if (oLumaHeight) *oLumaHeight = lHeight;
    if (oChromaStride) *oChromaStride = cStride;
    if (oChromaHeight) *oChromaHeight = cHeight;
}

static BOOL JW_DecoderCalcuFrameBuffer(
    JW_DecoderContext_t *context, FrameFormat subsample, CbCrInterLeave cbcrIntlv, PackedFormat packed,
    Uint32 rotation, BOOL scalerOn, Uint32 width, Uint32 height, Uint32 bitDepth, Uint8 num) {
    (void)num;
    Uint32 fbLumaStride, fbLumaHeight, fbChromaStride, fbChromaHeight;
    size_t fbLumaSize, fbChromaSize, fbSize;
    Uint32 bytePerPixel = (bitDepth + 7) / 8;

    if (rotation == 90 || rotation == 270) {
        if (subsample == FORMAT_422)
            subsample = FORMAT_440;
        else if (subsample == FORMAT_440)
            subsample = FORMAT_422;
    }

    GetFrameBufStride(
        subsample, cbcrIntlv, packed, scalerOn, width, height, bytePerPixel,
        &fbLumaStride, &fbLumaHeight, &fbChromaStride, &fbChromaHeight);

    fbLumaSize = (size_t)fbLumaStride * (size_t)fbLumaHeight;
    fbChromaSize = (size_t)fbChromaStride * (size_t)fbChromaHeight;

    if (cbcrIntlv == CBCR_SEPARATED) {
        /* fbChromaSize MUST be zero when format is packed mode */
        fbSize = fbLumaSize + 2 * fbChromaSize;

    } else {
        /* Semi-planar */
        fbSize = fbLumaSize + fbChromaSize;
    }

    context->frameBufSize = fbSize;

    if (context->yuvWrite->vtable->Reserve(context->yuvWrite, fbSize) < fbSize) {
        JLOG(ERR, "Fail to allocate frame buffer size=%d\n", fbSize);
        return FALSE;
    }
    PhysicalAddress buff_addr = context->yuvWrite->vtable->GetPhysAddr(context->yuvWrite);
    context->frameBuf.bufY = buff_addr;                                                             /**< It indicates the base address for Y component in the physical address space when linear map is used. */
    context->frameBuf.bufCb = buff_addr + fbLumaSize;                                               /**< It indicates the base address for Cb component in the physical address space when linear map is used. */
    context->frameBuf.bufCr = buff_addr + fbLumaSize + fbChromaSize;                                /**< It indicates the base address for Cr component in the physical address space when linear map is used. */
    context->frameBuf.stride = fbLumaStride; /**< A horizontal stride for luma frame buffer */      /* luma stride */
    context->frameBuf.strideC = fbChromaStride; /**< A horizontal stride for chroma frame buffer */ /* chroma stride */
#ifdef SUPPORT_PADDING_UNALIGNED_YUV                                                                //
    context->frameBuf.fbLumaHeight = fbLumaHeight;                                                  /**< A height for luma frame buffer */
    context->frameBuf.fbChromaHeight = fbChromaHeight;                                              /**< A height for chroma frame buffer */
#endif                                                                                              //
    context->frameBuf.format = subsample;                                                           /**< <<jpuapi_h_FrameFormat>> */
    context->frameBuf.endian = 0;                                                                   // little endian format
    return TRUE;
}

void JW_DecoderContextSetDefault(JW_DecoderContext_t *context) {
    memset(context, 0, sizeof(JW_DecoderContext_t));
    context->decOP.streamEndian = JDI_LITTLE_ENDIAN;
    context->decOP.frameEndian = JDI_LITTLE_ENDIAN;
    context->decOP.chromaInterleave = CBCR_SEPARATED;
    context->decOP.packedFormat = PACKED_FORMAT_NONE; /**< This is for packed image format. It is valid only when source image format is written in YUV444 or RGB24. */
    context->decOP.roiEnable = FALSE;                 /**< This enables the ROI (Region of Interest). */
    context->decOP.roiOffsetX = 0;                    /**< This is ROI offset for width. */
    context->decOP.roiOffsetY = 0;                    /**< This is ROI offset for height. */
    context->decOP.roiWidth = 0;                      /**< This is ROI width from RoiOffsetX. */
    context->decOP.roiHeight = 0;                     /**< This is ROI width from RoiOffsetY. */
    context->decOP.pixelJustification = 0;            /**< avaliable in 16bit pixel.It specifies pixel justification of source image for 12bit encoding mode. */
    context->decOP.rotation = 0;                      /**< It rotates decoded images in 0, 90, 180, or 270 degree */
    context->decOP.mirror = MIRDIR_NONE;              /**< <<jpuapi_h_JpgMirrorDirection>> */
    context->decOP.outputFormat = FORMAT_MAX;         /**< <<jpuapi_h_FrameFormat>> */
    // context->decOP.hangDetectEnable = 0;              /**< This is to detect automatic hangups. */
    // context->decOP.hangDetectSelfInitEnable = 0;      /**< This is to set the automatic initialization after hangup detect. */

    context->decParam.scaleDownRatioHeight = 0;
    context->decParam.scaleDownRatioWidth = 0;
}

JpgRet JW_DecoderInit(JW_DecoderContext_t *context) {
    if (!JPU_IsInit()) {
        context->ret = JPG_RET_NOT_INITIALIZED;
        JLOG(ERR, "JPU was not initialized yet\n");
        goto ERR_DEC_INIT;
    }

    assert(context->bsFeed && context->bsFeed->vtable->GetPhysAddr(context->bsFeed));

    context->decOP.bitstreamBuffer = context->bsFeed->vtable->GetPhysAddr(context->bsFeed);
    context->decOP.bitstreamBufferSize = context->bsFeed->vtable->GetSize(context->bsFeed);
    context->decOP.pBitStream = (BYTE *)context->bsFeed->vtable->GetVirtAddr(context->bsFeed);
    // context->decOP.intrEnableBit = ((1 << INT_JPU_DONE) | (1 << INT_JPU_ERROR) | (1 << INT_JPU_BIT_BUF_EMPTY)
    //                                 | (1 << INT_JPU_PIC_CYCLE_ERROR) | (1 << INT_JPU_TC_CYCLE_ERROR) | (1 << INT_JPU_DMA_CYCLE_ERROR));
    context->decOP.intrEnableBit = ((1 << INT_JPU_DONE) | (1 << INT_JPU_ERROR) | (1 << INT_JPU_BIT_BUF_EMPTY));
    context->ret = JPU_DecOpen(&context->handle, &context->decOP);
    if (context->ret != JPG_RET_SUCCESS) {
        JLOG(ERR, "JPU_DecOpen failed Error code is 0x%x \n", context->ret);
        goto ERR_DEC_INIT;
    }

    int instIdx = context->handle->instIndex;
    if ((context->ret = JW_DecoderBitstreamRefresh(context) != JPG_RET_SUCCESS)) {
        JLOG(ERR, "JW_DecoderBitstreamRefresh failed Error code is 0x%x, inst=%d \n", context->ret, instIdx);
        goto ERR_DEC_INIT;
    }

    if ((context->ret = JPU_DecGetInitialInfo(context->handle, &context->initialInfo)) != JPG_RET_SUCCESS) {
        JLOG(ERR, "JPU_DecGetInitialInfo failed Error code is 0x%x, inst=%d \n", context->ret, instIdx);
        goto ERR_DEC_INIT;
    }

    Uint32 framebufWidth = 0, framebufHeight = 0;
    Uint32 decodingWidth, decodingHeight;
    Uint32 displayWidth, displayHeight;

    if (context->initialInfo.sourceFormat == FORMAT_420 || context->initialInfo.sourceFormat == FORMAT_422)
        framebufWidth = JPU_CEIL(16, context->initialInfo.picWidth);
    else
        framebufWidth = JPU_CEIL(8, context->initialInfo.picWidth);

    if (context->initialInfo.sourceFormat == FORMAT_420 || context->initialInfo.sourceFormat == FORMAT_440)
        framebufHeight = JPU_CEIL(16, context->initialInfo.picHeight);
    else
        framebufHeight = JPU_CEIL(8, context->initialInfo.picHeight);

    decodingWidth = framebufWidth >> context->decParam.scaleDownRatioWidth;
    decodingHeight = framebufHeight >> context->decParam.scaleDownRatioHeight;
    if (context->decOP.packedFormat != PACKED_FORMAT_NONE && context->decOP.packedFormat != PACKED_FORMAT_444) {
        // When packed format, scale-down resolution should be multiple of 2.
        decodingWidth = JPU_CEIL(2, decodingWidth);
    }

    context->decOP.outputFormat = (context->decOP.outputFormat == FORMAT_MAX) ? context->initialInfo.sourceFormat : context->decOP.outputFormat;

    Uint32 temp = decodingWidth;
    decodingWidth = (context->decOP.rotation == 90 || context->decOP.rotation == 270) ? decodingHeight : decodingWidth;
    decodingHeight = (context->decOP.rotation == 90 || context->decOP.rotation == 270) ? temp : decodingHeight;

    if (context->decOP.roiEnable == TRUE) {
        decodingWidth = framebufWidth = context->initialInfo.roiFrameWidth;
        decodingHeight = framebufHeight = context->initialInfo.roiFrameHeight;
    }

    if (0 != context->decParam.scaleDownRatioWidth || 0 != context->decParam.scaleDownRatioHeight) {
        displayWidth = JPU_FLOOR(2, (framebufWidth >> context->decParam.scaleDownRatioWidth));
        displayHeight = JPU_FLOOR(2, (framebufHeight >> context->decParam.scaleDownRatioHeight));
    } else {
        displayWidth = decodingWidth;
        displayHeight = decodingHeight;
    }
    JLOG(INFO, "decodingWidth: %d, decodingHeight: %d\n", decodingWidth, decodingHeight);

    // Check restrictions
    if (context->decOP.rotation != 0 || context->decOP.mirror != MIRDIR_NONE) {
        if (context->decOP.outputFormat != FORMAT_MAX && context->decOP.outputFormat != context->initialInfo.sourceFormat) {
            JLOG(ERR, "The rotator cannot work with the format converter together.\n");
            context->ret = JPG_RET_INVALID_PARAM;
            goto ERR_DEC_INIT;
        }
    }
    JLOG(INFO, "<INSTANCE %d>\n", instIdx);
    JLOG(INFO, "SOURCE PICTURE SIZE : W(%d) H(%d)\n", context->initialInfo.picWidth, context->initialInfo.picHeight);
    JLOG(INFO, "DECODED PICTURE SIZE: W(%d) H(%d)\n", displayWidth, displayHeight);
    JLOG(INFO, "SUBSAMPLE           : %d\n", context->decOP.outputFormat);

    if (context->profilingEnable) {
        JLOG(INFO, "[PF] DECODED PICTURE SIZE: W(%d) H(%d)\n", displayWidth, displayHeight);
        JLOG(INFO, "[PF] SUBSAMPLE           : %d\n", context->decOP.outputFormat);
    }

    if ((
            context->ret = JPU_DecGiveCommand(
                context->handle, SET_JPG_SCALE_HOR, &(context->decParam.scaleDownRatioWidth)))
        != JPG_RET_SUCCESS) {
        JLOG(ERR, "JPU_DecGiveCommand[SET_JPG_SCALE_HOR] failed Error code is 0x%x \n", context->ret);
        goto ERR_DEC_INIT;
    }
    if ((
            context->ret = JPU_DecGiveCommand(
                context->handle, SET_JPG_SCALE_VER, &(context->decParam.scaleDownRatioWidth)))
        != JPG_RET_SUCCESS) {
        JLOG(ERR, "JPU_DecGiveCommand[SET_JPG_SCALE_VER] failed Error code is 0x%x \n", context->ret);
        goto ERR_DEC_INIT;
    }

    // if (context->decOP.hangDetectEnable) {
    //     context->decParam.pic_co_val = (Uint64)context->initialInfo.picWidth * (Uint64)context->initialInfo.picHeight / 8 / 8 * 3044 * 2.5; // 3044 comes from average cycle value of 1 mcu at worst case in cnm env.
    //     context->decParam.tc_co_val = 20000000;                                                                                             // tc can not over this value in normal case.
    //     context->decParam.dma_co_val = 1000000;                                                                                             // dma can not over this value in normal case.
    //     JLOG(INFO, "Target Cycle Cnt !!! \n");
    //     JLOG(INFO, "Picture : %d, TC : %d, DMA : %d \n", context->decParam.pic_co_val, context->decParam.tc_co_val, context->decParam.dma_co_val);
    // }

    if (context->yuvWrite) {
        context->ret = JW_DecoderRegisterFrameBuffer(context, NULL);
        if (context->ret != JPG_RET_SUCCESS)
            goto ERR_DEC_INIT;
    }

ERR_DEC_INIT:
    if (context->ret != JPG_RET_SUCCESS && context->handle != NULL) {
        JW_DecoderDeInit(context);
    }
    return context->ret;
}

JpgRet JW_DecoderRegisterFrameBuffer(JW_DecoderContext_t *context, JW_BuffHandleBase_t *yuvWrite) {
    if (yuvWrite != NULL)
        context->yuvWrite = yuvWrite;
    else
        assert(context->yuvWrite);

    Uint32 framebufWidth = 0, framebufHeight = 0;
    Uint32 decodingWidth, decodingHeight;
    {
        if (context->initialInfo.sourceFormat == FORMAT_420 || context->initialInfo.sourceFormat == FORMAT_422)
            framebufWidth = JPU_CEIL(16, context->initialInfo.picWidth);
        else
            framebufWidth = JPU_CEIL(8, context->initialInfo.picWidth);

        if (context->initialInfo.sourceFormat == FORMAT_420 || context->initialInfo.sourceFormat == FORMAT_440)
            framebufHeight = JPU_CEIL(16, context->initialInfo.picHeight);
        else
            framebufHeight = JPU_CEIL(8, context->initialInfo.picHeight);

        decodingWidth = framebufWidth >> context->decParam.scaleDownRatioWidth;
        decodingHeight = framebufHeight >> context->decParam.scaleDownRatioHeight;
        if (context->decOP.packedFormat != PACKED_FORMAT_NONE && context->decOP.packedFormat != PACKED_FORMAT_444) {
            // When packed format, scale-down resolution should be multiple of 2.
            decodingWidth = JPU_CEIL(2, decodingWidth);
        }

        Uint32 temp = decodingWidth;
        decodingWidth = (context->decOP.rotation == 90 || context->decOP.rotation == 270) ? decodingHeight : decodingWidth;
        decodingHeight = (context->decOP.rotation == 90 || context->decOP.rotation == 270) ? temp : decodingHeight;

        if (context->decOP.roiEnable == TRUE) {
            decodingWidth = framebufWidth = context->initialInfo.roiFrameWidth;
            decodingHeight = framebufHeight = context->initialInfo.roiFrameHeight;
        }
    }

    if (FALSE
        == JW_DecoderCalcuFrameBuffer(
            context, context->decOP.outputFormat,
            context->decOP.chromaInterleave,
            context->decOP.packedFormat, context->decOP.rotation,
            (context->decParam.scaleDownRatioWidth || context->decParam.scaleDownRatioHeight),
            decodingWidth, decodingHeight, context->initialInfo.bitDepth,
            context->initialInfo.minFrameBufferCount)) {
        JLOG(ERR, "Failed to AllocateFrameBuffer()\n");
        context->ret = JPG_RET_INSUFFICIENT_RESOURCE;
        return context->ret;
    }

    // Register frame buffers requested by the decoder.
    if ((
            context->ret = JPU_DecRegisterFrameBuffer(
                context->handle, &context->frameBuf,
                // context->initialInfo.minFrameBufferCount,
                1,
                context->frameBuf.stride))
        != JPG_RET_SUCCESS) {
        JLOG(ERR, "JPU_DecRegisterFrameBuffer failed Error code is 0x%x \n", context->ret);
        return context->ret;
    }
    return context->ret;
}

JpgRet JW_DecoderDeInit(JW_DecoderContext_t *context) {
    if (context->handle != NULL)
        JPU_DecClose(context->handle);

    return context->ret;
}

BOOL JW_DecoderAct(JW_DecoderContext_t *context) {
    assert(context->yuvWrite && context->yuvWrite->vtable->GetPhysAddr(context->yuvWrite));
    BOOL suc = FALSE;
    Int32 int_reason = 0;
    Uint64 temp1, temp2;
    JLOG(INFO, "I   F    FB_INDEX  FRAME_START  ECS_START  CONSUME   RD_PTR   WR_PTR      CYCLE\n");
    JLOG(INFO, "-------------------------------------------------------------------------------\n");
    do {
        // Start decoding a frame.
        context->ret = JPU_DecStartOneFrame(context->handle, &context->decParam);
        if (context->ret != JPG_RET_SUCCESS && context->ret != JPG_RET_EOS) {
            JLOG(ERR, "JPU_DecStartOneFrame failed Error code is 0x%x \n", context->ret);
            goto DEC_RET;
        }

        if (context->ret == JPG_RET_EOS) {
            JPU_DecGetOutputInfo(context->handle, &context->outputInfo);
            JLOG(INFO, "JPG_RET_EOS\n");
            suc = TRUE;
            goto DEC_RET;
        }

        while (1) {
            if ((int_reason = JPU_WaitInterrupt(context->handle, JPU_INTERRUPT_TIMEOUT_MS)) == -1) {
                JLOG(ERR, "Error : timeout happened\n");
                JLOG(
                    INFO,
                    "%02d %04d  %8d     %8x %8x %10u  %8x  %8x %10u\n",
                    context->handle->instIndex, context->frameIdx, context->outputInfo.indexFrameDisplay,
                    context->outputInfo.bytePosFrameStart, context->outputInfo.ecsPtr, context->outputInfo.consumedByte,
                    context->outputInfo.rdPtr, context->outputInfo.wrPtr, context->outputInfo.frameCycle);
                // temp1 = JpuReadInstReg(0, MJPEG_CYCLE_OUT_INFO_REG1);
                // temp2 = JpuReadInstReg(0, MJPEG_CYCLE_OUT_INFO_REG0);
                // JLOG(INFO, "Picture Cycle Value : %d \n", (temp1 << 32 | temp2));
                // temp1 = JpuReadInstReg(0, MJPEG_CYCLE_OUT_INFO_REG3);
                // temp2 = JpuReadInstReg(0, MJPEG_CYCLE_OUT_INFO_REG2);
                // JLOG(INFO, "TC Cycle Value : %d \n", (temp1 << 32 | temp2));
                // temp1 = JpuReadInstReg(0, MJPEG_CYCLE_OUT_INFO_REG5);
                // temp2 = JpuReadInstReg(0, MJPEG_CYCLE_OUT_INFO_REG4);
                // JLOG(INFO, "DMA Cycle Value : %d \n", (temp1 << 32 | temp2));

                JPU_SWReset((JpgHandle)context->handle);
                break;
            }
            if (int_reason == -2) {
                JLOG(ERR, "Interrupt occurred. but this interrupt is not for my instance \n");
                continue;
            }

            if (int_reason & (1 << INT_JPU_BIT_BUF_EMPTY)) {
                JLOG(INFO, "\tINSTANCE #%d int_reason(INT_JPU_BIT_BUF_EMPTY): %08x\n", context->handle->instIndex, int_reason);
                Uint32 wr_size = context->bsFeed->vtable->FeedAct(context->bsFeed, ~0);
                if (wr_size == 0 && context->handle->JpgInfo->decInfo.streamEndflag != 0) {
                    JLOG(ERR, "Not enough Bitstream\n");
                    JPU_ClrStatus(context->handle, (1 << INT_JPU_BIT_BUF_EMPTY));
                    JPU_DecGetOutputInfo(context->handle, &context->outputInfo);
                    goto DEC_RET;
                }
                JPU_DecUpdateBitstreamBuffer(context->handle, wr_size);
                JPU_ClrStatus(context->handle, (1 << INT_JPU_BIT_BUF_EMPTY));
                if (int_reason & (1 << INT_JPU_DONE)) {
                    // if empty and done interupt can be asserted at same time. in this case. host should ignore done interrupt at this time and wait for done interrupt again.
                    continue;
                    ;
                }
            }

            if (int_reason & ((1 << INT_JPU_DONE) | (1 << INT_JPU_ERROR))) {
                // Do no clear INT_JPU_DONE and INT_JPU_ERROR interrupt. these will be cleared in JPU_DecGetOutputInfo.
                JLOG(INFO, "\tINSTANCE #%d int_reason: %08x\n", context->handle->instIndex, int_reason);
                break;
            }

            // if (int_reason & (1 << INT_JPU_PIC_CYCLE_ERROR)) {
            //     JLOG(TRACE, "PIC cycle out error Occurred \n\n");
            //     break;
            // }
            // if (int_reason & (1 << INT_JPU_TC_CYCLE_ERROR)) {
            //     JLOG(TRACE, "TC cycle out error Occurred \n\n");
            //     break;
            // }
            // if (int_reason & (1 << INT_JPU_DMA_CYCLE_ERROR)) {
            //     JLOG(TRACE, "DMA cycle out error Occurred \n\n");
            //     break;
            // }
        }
        if ((context->ret = JPU_DecGetOutputInfo(context->handle, &context->outputInfo)) != JPG_RET_SUCCESS) {
            JLOG(ERR, "JPU_DecGetOutputInfo failed Error code is 0x%x \n", context->ret);
            goto DEC_RET;
        }

        JLOG(
            INFO, "%02d %04d  %8d     %8x %8x %10u  %8x  %8x %10u\n",
            context->handle->instIndex, context->frameIdx, context->outputInfo.indexFrameDisplay,
            context->outputInfo.bytePosFrameStart, context->outputInfo.ecsPtr, context->outputInfo.consumedByte,
            context->outputInfo.rdPtr, context->outputInfo.wrPtr, context->outputInfo.frameCycle);
        if (context->profilingEnable) {
            JLOG(
                INFO, "[PF] %02d %04d  %8d     %8x %8x %10u  %8x  %8x %10u\n",
                context->handle->instIndex, context->frameIdx, context->outputInfo.indexFrameDisplay,
                context->outputInfo.bytePosFrameStart, context->outputInfo.ecsPtr, context->outputInfo.consumedByte,
                context->outputInfo.rdPtr, context->outputInfo.wrPtr, context->outputInfo.frameCycle);
        }

        if (context->outputInfo.numOfErrMBs) {
            Int32 errRstIdx, errPosX, errPosY;
            errRstIdx = (context->outputInfo.numOfErrMBs & 0x0F000000) >> 24;
            errPosX = (context->outputInfo.numOfErrMBs & 0x00FFF000) >> 12;
            errPosY = (context->outputInfo.numOfErrMBs & 0x00000FFF);
            JLOG(ERR, "Error restart Idx : %d, MCU x:%d, y:%d, in Frame : %d \n", errRstIdx, errPosX, errPosY, context->frameIdx);
        }
        if (context->outputInfo.decodingSuccess == 0) {
            JLOG(ERR, "JPU_DecGetOutputInfo decode fail framdIdx %d \n", context->frameIdx);
            break;
        }
        context->frameIdx++;

        suc = TRUE;
    } while (0);

DEC_RET:
    if (suc)
        context->yuvWrite->vtable->WriteAct(context->yuvWrite, context->frameBufSize);
    return suc;
}

JpgRet JW_DecoderBitstreamRefresh(JW_DecoderContext_t *context) {
    context->bsFeed->vtable->ResetWrRdPtr(context->bsFeed, TRUE);
    context->ret = JPU_DecSetRdPtr(context->handle, context->bsFeed->vtable->GetPhysAddr(context->bsFeed), TRUE);
    if (context->ret != JPG_RET_SUCCESS)
        return context->ret;
    Uint32 wr_size = context->bsFeed->vtable->FeedAct(context->bsFeed, ~0);
    JPU_DecUpdateBitstreamBuffer(context->handle, wr_size);
    if (wr_size == 0) {
        context->ret = JPG_RET_INSUFFICIENT_BITSTREAM_BUFFER;
        JLOG(ERR, "FeedAct failed");
    }

    context->frameIdx = 0;
    return context->ret;
}