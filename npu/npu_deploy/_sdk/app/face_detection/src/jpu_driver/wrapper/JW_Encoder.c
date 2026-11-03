/****************************************************************
 * Copyright (c) 2023 - 2024 Anlogic, Inc.  All rights reserved.
 * SPDX-License-Identifier: MIT
 ****************************************************************/

#include "JW_Encoder.h"
#include "jpuapi.h"
#include "jpuconfig.h"
#include "jpulog.h"
#include "jpuapifunc.h"
#include "jputypes.h"
#include "main_helper.h"
#include "regdefine.h"
#include <assert.h>
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

static BOOL JW_EncoderCalcuFrameBuffer(
    JW_EncoderContext_t *context, FrameFormat subsample, CbCrInterLeave cbcrIntlv, PackedFormat packed,
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

    if (context->yuvFeed->vtable->Reserve(context->yuvFeed, fbSize) < fbSize) {
        JLOG(ERR, "Fail to allocate frame buffer size=%d\n", fbSize);
        return FALSE;
    }
    PhysicalAddress buff_addr = context->yuvFeed->vtable->GetPhysAddr(context->yuvFeed);
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

static void CalcSliceHeight(JpgEncOpenParam *encOP, Uint32 sliceHeight) {
    Uint32 width = encOP->picWidth;
    Uint32 height = encOP->picHeight;
    Uint32 aligned_buf_height;
    FrameFormat format = encOP->sourceFormat;

    if (encOP->rotation == 90 || encOP->rotation == 270) {
        width = encOP->picHeight;
        height = encOP->picWidth;
        if (format == FORMAT_422)
            format = FORMAT_440;
        else if (format == FORMAT_440)
            format = FORMAT_422;
    }

    if (format == FORMAT_420 || format == FORMAT_440)
        aligned_buf_height = JPU_CEIL(16, height);
    else
        aligned_buf_height = JPU_CEIL(8, height);

    if (sliceHeight == 0) {
        if (format == FORMAT_420 || format == FORMAT_440)
            encOP->sliceHeight = aligned_buf_height;
        else
            encOP->sliceHeight = aligned_buf_height;
    } else
        encOP->sliceHeight = sliceHeight;

    if (encOP->sliceHeight != aligned_buf_height) {
        if (format == FORMAT_420 || format == FORMAT_422)
            encOP->restartInterval = (width + 15) / 16;
        else
            encOP->restartInterval = (width + 7) / 8;

        if (format == FORMAT_420 || format == FORMAT_440)
            encOP->restartInterval *= (encOP->sliceHeight / 16);
        else
            encOP->restartInterval *= (encOP->sliceHeight / 8);
        encOP->sliceInstMode = TRUE;
    }
}

void JW_EncoderContextSetDefault(JW_EncoderContext_t *context) {
    memset(context, 0, sizeof(JW_EncoderContext_t));
    context->encOP.picWidth = 0;                      /**< The width of a picture to be encoded in pixels */
    context->encOP.picHeight = 0;                     /**< The height of a picture to be encoded in pixels */
    context->encOP.sourceFormat = FORMAT_420;         /**< <<jpuapi_h_FrameFormat>> */
    context->encOP.restartInterval = 0;               /**< The number of MCU in the restart interval */
    context->encOP.streamEndian = JDI_LITTLE_ENDIAN;  //
    context->encOP.frameEndian = JDI_LITTLE_ENDIAN;   //
    context->encOP.chromaInterleave = CBCR_SEPARATED; //
    context->encOP.jpg12bit = FALSE;                  /**< It enables 12bit encoding mode. */
    context->encOP.q_prec0 = FALSE;                   /**< Luma quantization tables for 12bit encoding mode */
    context->encOP.q_prec1 = FALSE;                   /**< Chroma quantization tables for 12bit encoding mode */
    context->encOP.packedFormat = PACKED_FORMAT_NONE; /**< It specifies a packed image format. It is valid only when source image format is written in YUV444 or RGB24. */
    context->encOP.pixelJustification = 0;            /**< It specifies pixel justification of source image for 12bit encoding mode. */
    context->encOP.tiledModeEnable = FALSE;           /**< It enables use of tiled mode. */
    context->encOP.sliceHeight = 0;                   /**< It specifies a slice height for slice encoding. */
    context->encOP.sliceInstMode = FALSE;             //
    context->encOP.rotation = 0;                      /**< It rotates source images in 0, 90, 180, or 270 degree before encoding. */
    context->encOP.mirror = MIRDIR_NONE;              /**< <<jpuapi_h_JpgMirrorDirection>> */
}

void JW_EncoderContextSetHuffTable(JW_EncoderContext_t *context) {
    int ret;
    EncMjpgParam mjpgParam;
    memset(&mjpgParam, 0x00, sizeof(EncMjpgParam));

    mjpgParam.sourceFormat = context->encOP.sourceFormat;

    char null = 0;
    ret = jpgGetHuffTable(&null, &mjpgParam, context->encOP.jpg12bit);
    if (ret == 0) return;
    ret = jpgGetQMatrix(&null, &mjpgParam);
    if (ret == 0) return;

    memcpy(context->encOP.huffVal, mjpgParam.huffVal, 4 * 256);
    memcpy(context->encOP.huffBits, mjpgParam.huffBits, 4 * 256);
    memcpy(context->encOP.qMatTab, mjpgParam.qMatTab, 4 * 64 * sizeof(short));

    // Currently only 2DC,2AC huffman table for 12-bit case
    // So, copy them to EX1 to EX2 to modeling rest 2 tables
    if (context->encOP.jpg12bit == TRUE) {
        memcpy(&context->encOP.huffVal[4][0], &context->encOP.huffVal[0][0], 4 * 256);
        memcpy(&context->encOP.huffBits[4][0], &context->encOP.huffBits[0][0], 4 * 256);
    }
}

JpgRet JW_EncoderInit(JW_EncoderContext_t *context) {
    if (!JPU_IsInit()) {
        context->ret = JPG_RET_NOT_INITIALIZED;
        JLOG(ERR, "JPU was not initialized yet\n");
        goto ERR_ENC_INIT;
    }
    assert(context->bsWrite && context->yuvFeed->vtable->GetPhysAddr(context->bsWrite));

    if (
        (context->bsWrite->vtable->GetSize(context->bsWrite) % 4096) != 0
        || context->bsWrite->vtable->GetSize(context->bsWrite) < 8192) {
        context->ret = JPG_RET_INSUFFICIENT_BITSTREAM_BUFFER;
        JLOG(ERR, "Invalid size of bitstream buffer\n");
        goto ERR_ENC_INIT;
    }

    context->encOP.intrEnableBit = ((1 << INT_JPU_DONE) | (1 << INT_JPU_ERROR) | (1 << INT_JPU_BIT_BUF_FULL));
    context->encOP.bitstreamBuffer = context->bsWrite->vtable->GetPhysAddr(context->bsWrite);
    context->encOP.bitstreamBufferSize = context->bsWrite->vtable->GetSize(context->bsWrite);
    if (context->encOP.packedFormat) {
        if (context->encOP.packedFormat == PACKED_FORMAT_444 && context->encOP.sourceFormat != FORMAT_444) {
            context->ret = JPG_RET_INVALID_PARAM;
            JLOG(ERR, "Invalid operation mode : In case of using packed mode. sourceFormat must be FORMAT_444\n");
            goto ERR_ENC_INIT;
        }
    }

    int srcFrameFormat = 0;
    int framebufWidth = 0, framebufHeight = 0;
    // srcFrameFormat means that it is original source image format.
    srcFrameFormat = context->encOP.sourceFormat;
    if (context->encOP.rotation == 90 || context->encOP.rotation == 270) {
        if (srcFrameFormat == FORMAT_422)
            srcFrameFormat = FORMAT_440;
        else if (srcFrameFormat == FORMAT_440)
            srcFrameFormat = FORMAT_422;
    }
    framebufWidth =
        (srcFrameFormat == FORMAT_420 || srcFrameFormat == FORMAT_422) ?
            JPU_CEIL(16, context->encOP.picWidth) :
            JPU_CEIL(8, context->encOP.picWidth);
    framebufHeight =
        (srcFrameFormat == FORMAT_420 || srcFrameFormat == FORMAT_440) ?
            JPU_CEIL(16, context->encOP.picHeight) :
            JPU_CEIL(8, context->encOP.picHeight);

    CalcSliceHeight(&context->encOP, context->encOP.sliceHeight);

    if (context->encOP.sliceInstMode)
        context->encOP.intrEnableBit |= (1 << INT_JPU_SLICE_DONE);

    // Open an instance and get initial information for encoding.
    if ((context->ret = JPU_EncOpen(&context->handle, &context->encOP)) != JPG_RET_SUCCESS) {
        JLOG(ERR, "JPU_EncOpen failed Error code is 0x%x \n", context->ret);
        goto ERR_ENC_INIT;
    }

    // JPU_EncGiveCommand(handle, ENABLE_LOGGING, NULL);
    // int instIdx = context->handle;

    JPU_EncGiveCommand(
        context->handle, SET_JPG_USE_STUFFING_BYTE_FF, &context->stuffByteEnable);
    if (context->encQualityPercentage > 0) {
        JPU_EncGiveCommand(context->handle, SET_JPG_QUALITY_FACTOR, &context->encQualityPercentage);
    }
    if (context->yuvFeed) {
        context->ret = JW_EncoderRegisterFrameBuffer(context, context->yuvFeed);
        if (context->ret != JPG_RET_SUCCESS)
            goto ERR_ENC_INIT;
    }
    JLOG(
        INFO, "framebuffer stride = %d, width = %d, height = %d\n",
        context->frameBuf.stride, framebufWidth, framebufHeight);
    JLOG(
        INFO, "framebuffer format = %d, packed format = %d, Interleave = %d\n",
        srcFrameFormat, context->encOP.packedFormat, context->encOP.chromaInterleave);
    if (context->profilingEnable) {
        JLOG(
            INFO, "[PF] framebuffer format = %d, packed format = %d, Interleave = %d\n",
            srcFrameFormat, context->encOP.packedFormat, context->encOP.chromaInterleave);
    }
ERR_ENC_INIT:
    if (context->ret != JPG_RET_SUCCESS && context->handle != NULL) {
        JW_EncoderDeInit(context);
    }
    return context->ret;
}

JpgRet JW_EncoderRegisterFrameBuffer(JW_EncoderContext_t *context, JW_BuffHandleBase_t *yuvFeed) {
    if (yuvFeed != NULL)
        context->yuvFeed = yuvFeed;
    else
        assert(context->yuvFeed);

    int srcFrameFormat = 0;
    int framebufWidth = 0, framebufHeight = 0;
    // srcFrameFormat means that it is original source image format.
    srcFrameFormat = context->encOP.sourceFormat;
    if (context->encOP.rotation == 90 || context->encOP.rotation == 270) {
        if (srcFrameFormat == FORMAT_422)
            srcFrameFormat = FORMAT_440;
        else if (srcFrameFormat == FORMAT_440)
            srcFrameFormat = FORMAT_422;
    }
    framebufWidth =
        (srcFrameFormat == FORMAT_420 || srcFrameFormat == FORMAT_422) ?
            JPU_CEIL(16, context->encOP.picWidth) :
            JPU_CEIL(8, context->encOP.picWidth);
    framebufHeight =
        (srcFrameFormat == FORMAT_420 || srcFrameFormat == FORMAT_440) ?
            JPU_CEIL(16, context->encOP.picHeight) :
            JPU_CEIL(8, context->encOP.picHeight);
    int needFrameBufCount = 1;
    Uint32 bitDepth = (context->encOP.jpg12bit == FALSE) ? 8 : 12;

    if (!JW_EncoderCalcuFrameBuffer(
            context, context->encOP.sourceFormat, context->encOP.chromaInterleave,
            context->encOP.packedFormat, 0, FALSE, framebufWidth,
            framebufHeight, bitDepth, needFrameBufCount)) {
        JLOG(ERR, "Failed to AllocateFrameBuffer()\n");
        context->ret = JPG_RET_INSUFFICIENT_RESOURCE;
        return context->ret;
    }
    context->encParam.sourceFrame = &context->frameBuf;
    return context->ret;
}

BOOL JW_EncoderAct(JW_EncoderContext_t *context) {
    assert(context->yuvFeed && context->yuvFeed->vtable->GetPhysAddr(context->yuvFeed));
    BOOL suc = FALSE;
    Uint32 enc_size = 0;
    do {
        // context->bsWrite->vtable->ResetWrRdPtr(context->bsWrite, TRUE);
        // Write picture header
        if (context->encHeaderMode == ENC_HEADER_MODE_NORMAL) {
            JpgEncParamSet encHeaderParam = {0};
            encHeaderParam.size = 1U << 12;
            encHeaderParam.pParaSet = context->bsWrite->vtable->HeaderWrite(context->bsWrite, encHeaderParam.size);
            encHeaderParam.headerMode = ENC_HEADER_MODE_NORMAL; // Encoder header disable/enable control. Annex:A 1.2.3 item 13
            encHeaderParam.quantMode = JPG_TBL_NORMAL;          // JPG_TBL_MERGE    // Merge quantization table. Annex:A 1.2.3 item 7
            encHeaderParam.huffMode = JPG_TBL_NORMAL;           // JPG_TBL_MERGE    //Merge huffman table. Annex:A 1.2.3 item 6
            encHeaderParam.disableAPPMarker = 0;                // Remove APPn. Annex:A item 11
            encHeaderParam.enableSofStuffing = TRUE;            // Remove zero stuffing bits before 0xFFDA. Annex:A item 16.
            if (encHeaderParam.headerMode == ENC_HEADER_MODE_NORMAL) {
                if (encHeaderParam.pParaSet) {
                    // make picture header
                    JPU_EncGiveCommand(context->handle, ENC_JPG_GET_HEADER, &encHeaderParam); // return exact header size int endHeaderparam.siz;
                    JLOG(INFO, "JPU_EncGiveCommand[ENC_JPG_GET_HEADER] header size=%d\n", encHeaderParam.size);
                    enc_size += encHeaderParam.size;
                    context->bsWrite->vtable->HeaderWriteFinish(context->bsWrite, encHeaderParam.size);
                    // context->handle->JpgInfo->encInfo.streamWrPtr = encHeaderParam.size + context->bsWrite->vtable->GetPhysAddr(context->bsWrite);
                    // JpuWriteInstReg(0, MJPEG_BBC_WR_PTR_REG, context->handle->JpgInfo->encInfo.streamWrPtr);
                    // JPU_EncUpdateBitstreamBuffer(context->handle, encHeaderParam.size);
                }
            }
        }

        context->yuvFeed->vtable->FeedAct(context->yuvFeed, context->frameBufSize);

        // Start encoding a frame.
        context->ret = JPU_EncStartOneFrame(context->handle, &context->encParam);
        if (context->ret != JPG_RET_SUCCESS) {
            JLOG(ERR, "JPU_EncStartOneFrame failed Error code is 0x%x \n", context->ret);
            goto ERR_ENC_OPEN;
        }
        int int_reason;
        while (1) {
            while (1) {
                int_reason = JPU_WaitInterrupt(context->handle, JPU_INTERRUPT_TIMEOUT_MS);
                if (int_reason == -1) {
                    JLOG(ERR, "Error : inst %d timeout happened\n", context->handle->instIndex);
                    JPU_SWReset((JpgHandle)context->handle);
                    goto ERR_ENC_OPEN;
                }
                if (int_reason == -2) {
                    JLOG(ERR, "Interrupt occurred. but this interrupt is not for my instance\n");
                    continue;
                }

                if (int_reason & (1 << INT_JPU_DONE) || int_reason & (1 << INT_JPU_SLICE_DONE)) { // Must catch PIC_DONE interrupt before catching EMPTY interrupt
                    // Do no clear INT_JPU_DONE these will be cleared in JPU_EncGetOutputInfo.
                    break;
                }

                if (int_reason & (1 << INT_JPU_BIT_BUF_FULL)) {
                    // JLOG(INFO, "INT_JPU_BIT_BUF_FULL interrupt issued INSTANCE %d \n", instIdx);
                    PhysicalAddress prdPtr;
                    PhysicalAddress pwrPtr;
                    int size;
                    JPU_EncGetBitstreamBuffer(context->handle, &prdPtr, &pwrPtr, &size);
                    Uint32 wr_size = context->bsWrite->vtable->WriteAct(context->bsWrite, size);
                    assert(pwrPtr <= context->handle->JpgInfo->encInfo.streamBufEndAddr + 4096);
                    assert(wr_size == size);
                    if (pwrPtr >= context->handle->JpgInfo->encInfo.streamBufEndAddr)
                        context->bsWrite->vtable->ResetWrRdPtr(context->bsWrite, FALSE);
                    enc_size += wr_size;
                    JPU_EncUpdateBitstreamBuffer(context->handle, wr_size);
                    JPU_ClrStatus(context->handle, (1 << INT_JPU_BIT_BUF_FULL));
                }

                // if (int_reason & (1 << INT_JPU_PIC_CYCLE_ERROR)) {
                //     JLOG(INFO, "PIC error Occured \n\n");
                //     break;
                // }
                // if (int_reason & (1 << INT_JPU_TC_CYCLE_ERROR)) {
                //     JLOG(INFO, "TC error Occured \n\n");
                //     break;
                // }
                // if (int_reason & (1 << INT_JPU_DMA_CYCLE_ERROR)) {
                //     JLOG(INFO, "DMA error Occured \n\n");
                //     break;
                // }
            }
            if ((context->ret = JPU_EncGetOutputInfo(context->handle, &context->outputInfo)) != JPG_RET_SUCCESS) {
                JLOG(ERR, "JPU_EncGetOutputInfo failed Error code is 0x%x \n", context->ret);
                goto ERR_ENC_OPEN;
            }
            JpgEncInfo *pEncInfo = &context->handle->JpgInfo->encInfo;
            if (pEncInfo->encSlicePosY == 0) {
                break;
            } else {
                JPU_EncStartOneFrame(context->handle, &context->encParam);
            }
        }

        enc_size += context->bsWrite->vtable->WriteAct(context->bsWrite, context->outputInfo.bitstreamSize);

        JPU_EncUpdateBitstreamBuffer(context->handle, context->outputInfo.bitstreamSize);

        JLOG(
            TRACE, "Enc: %d, rdPtr=0x%x, wrPtr=0x%x cycles=%d wrSize=%d\n",
            context->handle->instIndex, context->outputInfo.streamRdPtr, context->outputInfo.streamWrPtr, context->outputInfo.frameCycle, enc_size);

        suc = TRUE;

    } while (0);
ERR_ENC_OPEN:
    return suc;
}

JpgRet JW_EncoderDeInit(JW_EncoderContext_t *context) {
    if (context->handle != NULL)
        JPU_EncClose(context->handle);
    return context->ret;
}