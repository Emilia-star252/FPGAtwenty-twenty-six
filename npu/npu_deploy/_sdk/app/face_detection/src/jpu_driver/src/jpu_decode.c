#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "jpuapi.h"
#include "regdefine.h"
#include "jpulog.h"
#include "jpuapifunc.h"
#include "jpu_oneshot_api.h"

static jpu_buffer_t vbStreams[MAX_NUM_INSTANCE];
// static jpu_buffer_t  vbStream    = {0};
static FrameBuffer frameBufs[MAX_NUM_INSTANCE][NUM_FRAME_BUF];
static Uint32    bitDepth = 0;
static Uint32    displayWidth = 0, displayHeight = 0;

BOOL JPU_decode_init(DecConfigParam* param, JpgDecHandle* pHandle)
{
    jpu_buffer_t vbStream            = {0};
    (*pHandle) = NULL;
    JpgDecOpenParam     decOP        = {0};
    JpgRet              ret = JPG_RET_SUCCESS;
    
    BOOL                suc = FALSE;
    DecConfigParam      decConfig;


    memcpy(&decConfig, param, sizeof(DecConfigParam));

    decConfig.feedingMode = FEEDING_METHOD_FIXED_SIZE_MEMIO;

    // Check Parameters
    if ((decConfig.iHorScaleMode || decConfig.iVerScaleMode) && decConfig.roiEnable) {
        JLOG(ERR, "Invalid operation mode : ROI cannot work with the scaler\n");
        return FALSE;
    }
    if(decConfig.packedFormat && decConfig.roiEnable) {
        JLOG(ERR, "Invalid operation mode : ROI cannot work with the packed format conversion\n");
        return FALSE;
    }
    if (decConfig.roiEnable && (decConfig.rotation || decConfig.mirror)) {
        JLOG(ERR, "Invalid operation mode : ROI cannot work with the PPU.\n");
    }
    if (decConfig.packedFormat == PACKED_FORMAT_422_YUYV || 
        decConfig.packedFormat == PACKED_FORMAT_422_UYVY ||
        decConfig.packedFormat == PACKED_FORMAT_422_YVYU ||
        decConfig.packedFormat == PACKED_FORMAT_422_VYUY ||
        decConfig.packedFormat == PACKED_FORMAT_444) {
        if (decConfig.subsample != FORMAT_MAX) {
            JLOG(ERR, "Invalid operation mode : subsample cannot be enabled if ordering is YUYV or UYVY or YVYU or VYUY or AYUV\n");
            return FALSE;
        }
    }

    ret = JPU_Init();
    if (ret != JPG_RET_SUCCESS && ret != JPG_RET_CALLED_BEFORE) {
        suc = 0;
        JLOG(ERR, "JPU_Init failed Error code is 0x%x \n", ret );
        goto ERR_DEC_INIT;
    }

    // Open an instance and get initial information for decoding.
    vbStream.size = (decConfig.bsSize == 0) ? STREAM_BUF_SIZE : decConfig.bsSize;
    vbStream.size = (vbStream.size + 1023) & ~1023; // ceil128(size)
    if (jdi_allocate_dma_memory(&vbStream) < 0) {
        JLOG(ERR, "fail to allocate bitstream buffer\n" );
        goto ERR_DEC_INIT;
    }

    decOP.streamEndian          = decConfig.StreamEndian;
    decOP.frameEndian           = decConfig.FrameEndian;
    decOP.bitstreamBuffer       = vbStream.phys_addr;
    decOP.bitstreamBufferSize   = vbStream.size;
    //set virtual address mapped of physical address
    decOP.pBitStream            = (BYTE *)vbStream.virt_addr; //lint !e511
    decOP.chromaInterleave      = decConfig.cbcrInterleave;
    decOP.packedFormat          = decConfig.packedFormat;
    decOP.roiEnable             = decConfig.roiEnable;
    decOP.roiOffsetX            = decConfig.roiOffsetX;
    decOP.roiOffsetY            = decConfig.roiOffsetY;
    decOP.roiWidth              = decConfig.roiWidth;
    decOP.roiHeight             = decConfig.roiHeight;
    decOP.rotation              = decConfig.rotation;
    decOP.mirror                = decConfig.mirror;
    decOP.pixelJustification    = decConfig.pixelJustification;
    decOP.outputFormat          = decConfig.subsample;
    decOP.intrEnableBit         = ((1<<INT_JPU_DONE) | (1<<INT_JPU_ERROR) | (1<<INT_JPU_BIT_BUF_EMPTY));
    ret = JPU_DecOpen(pHandle, &decOP);
    if( ret != JPG_RET_SUCCESS ) {
        JLOG(ERR, "JPU_DecOpen failed Error code is 0x%x \n", ret );
        goto ERR_DEC_INIT;
    }
    // instIdx = (*pHandle)->instIndex;
    //JPU_DecGiveCommand(pHandle, ENABLE_LOGGING, NULL);
    int instIdx        = (*pHandle)->instIndex;
    vbStreams[instIdx] = vbStream;
    suc = TRUE;
    return suc;

ERR_DEC_INIT:
    jdi_free_dma_memory(&vbStream);

    JPU_DeInit();

    return suc;
}


BOOL create_bistream_feeder(void** pFeeder, const uint8_t* src, uint32_t bsize, EndianMode endian) {
    BSChunk srcChunk = {src, bsize, FALSE};
    if (((*pFeeder)=BitstreamFeeder_Create(&srcChunk, FEEDING_METHOD_FIXED_SIZE_MEMIO, endian)) == NULL) {
        return FALSE;
    }
    return TRUE;
}

BOOL destroy_bistream_feeder(void *pFeeder) {
    return BitstreamFeeder_Destroy(pFeeder);
}

BOOL frame_initialize(void* feeder, JpgDecHandle* pHandle, DecConfigParam* param, picInfo* retInfo, frameOutputInfo* outFrameInfo) {
    JpgDecInitialInfo   initialInfo = {0};
    JpgRet              ret = JPG_RET_SUCCESS;
    BOOL                suc = FALSE;

    do {
        /* Fill jpeg data in the bitstream buffer */
        BitstreamFeeder_Act(feeder, (*pHandle), &vbStreams[(*pHandle)->instIndex]);

        if ((ret=JPU_DecGetInitialInfo((*pHandle), &initialInfo)) != JPG_RET_SUCCESS) {
            if (JPG_RET_BIT_EMPTY == ret) {
                JLOG(INFO, "<%s:%d> BITSTREAM EMPTY\n", __FUNCTION__, __LINE__);
                continue;
            }
            else {
                JLOG(ERR, "JPU_DecGetInitialInfo failed Error code is 0x%x, inst=%d \n", ret, (*pHandle)->instIndex);
                return FALSE;
            }
        }
    } while (JPG_RET_SUCCESS != ret);

    Uint32              framebufWidth=0, framebufHeight=0, framebufStride = 0;
    Uint32              decodingWidth, decodingHeight;
    FrameFormat         subsample;
    Uint32              temp;
    BOOL                scalerOn = FALSE;
    if (initialInfo.sourceFormat == FORMAT_420 || initialInfo.sourceFormat == FORMAT_422)
        framebufWidth = JPU_CEIL(16, initialInfo.picWidth);
    else
        framebufWidth  = JPU_CEIL(8, initialInfo.picWidth);

    if (initialInfo.sourceFormat == FORMAT_420 || initialInfo.sourceFormat == FORMAT_440)
        framebufHeight = JPU_CEIL(16, initialInfo.picHeight);
    else
        framebufHeight = JPU_CEIL(8, initialInfo.picHeight);

    decodingWidth  = framebufWidth  >> param->iHorScaleMode;
    decodingHeight = framebufHeight >> param->iVerScaleMode;
    if (param->packedFormat != PACKED_FORMAT_NONE && param->packedFormat != PACKED_FORMAT_444) {
        // When packed format, scale-down resolution should be multiple of 2.
        decodingWidth  = JPU_CEIL(2, decodingWidth);
    }

    subsample = (param->subsample == FORMAT_MAX) ? initialInfo.sourceFormat : param->subsample;
    temp           = decodingWidth;
    decodingWidth  = (param->rotation == 90 || param->rotation == 270) ? decodingHeight : decodingWidth;
    decodingHeight = (param->rotation == 90 || param->rotation == 270) ? temp           : decodingHeight;
    if(param->roiEnable == TRUE) {
        decodingWidth  = framebufWidth  = initialInfo.roiFrameWidth ;
        decodingHeight = framebufHeight = initialInfo.roiFrameHeight;
    }

    if (0 != param->iHorScaleMode || 0 != param->iVerScaleMode) {
        displayWidth  = JPU_FLOOR(2, (framebufWidth >> param->iHorScaleMode));
        displayHeight = JPU_FLOOR(2, (framebufHeight >> param->iVerScaleMode));
    }
    else {
        displayWidth  = decodingWidth;
        displayHeight = decodingHeight;
    }
    JLOG(INFO, "decodingWidth: %d, decodingHeight: %d\n", decodingWidth, decodingHeight);

    // Check restrictions
    if (param->rotation != 0 || param->mirror != MIRDIR_NONE) {
        if (param->subsample != FORMAT_MAX && param->subsample != initialInfo.sourceFormat) {
            JLOG(ERR, "The rotator cannot work with the format converter together.\n");
            goto ERR_DEC_OPEN;
        }
    }

    JLOG(INFO, "<INSTANCE %d>\n", (*pHandle)->instIndex);
    JLOG(INFO, "SOURCE PICTURE SIZE : W(%d) H(%d)\n", initialInfo.picWidth, initialInfo.picHeight);
    JLOG(INFO, "DECODED PICTURE SIZE: W(%d) H(%d)\n", displayWidth, displayHeight);
    JLOG(INFO, "SUBSAMPLE           : %d\n",          subsample);

    //Allocate frame buffer
    Int32               needFrameBufCount = 0;
    // FrameBuffer         frameBufs[(*pHandle)->instIndex][NUM_FRAME_BUF];
    FRAME_BUF*          pFrame[NUM_FRAME_BUF];
    needFrameBufCount = initialInfo.minFrameBufferCount;
    bitDepth          = initialInfo.bitDepth;
    scalerOn          = (BOOL)(param->iHorScaleMode || param->iVerScaleMode);
    if (AllocateFrameBuffer((*pHandle)->instIndex, subsample, param->cbcrInterleave, param->packedFormat, param->rotation, scalerOn, decodingWidth, decodingHeight, bitDepth, needFrameBufCount) == FALSE) {
        JLOG(ERR, "Failed to AllocateFrameBuffer()\n");
        goto ERR_DEC_OPEN;
    }

    Int32               i = 0;
    for( i = 0; i < needFrameBufCount; ++i ) {
        pFrame[i] = GetFrameBuffer((*pHandle)->instIndex, i);
        frameBufs[(*pHandle)->instIndex][i].bufY  = pFrame[i]->vbY.phys_addr;
        frameBufs[(*pHandle)->instIndex][i].bufCb = pFrame[i]->vbCb.phys_addr;
        if (param->cbcrInterleave == CBCR_SEPARATED)
            frameBufs[(*pHandle)->instIndex][i].bufCr = pFrame[i]->vbCr.phys_addr;
        frameBufs[(*pHandle)->instIndex][i].stride  = pFrame[i]->strideY;
        frameBufs[(*pHandle)->instIndex][i].strideC = pFrame[i]->strideC;
        frameBufs[(*pHandle)->instIndex][i].endian  = param->FrameEndian;
        frameBufs[(*pHandle)->instIndex][i].format  = (FrameFormat)pFrame[i]->Format;
    }
    framebufStride = frameBufs[(*pHandle)->instIndex][0].stride;

    // outbufSize = decodingWidth * decodingHeight * 3 * (bitDepth+7)/8;
    if (retInfo != NULL) {
        retInfo->picWidth  = displayWidth;
        retInfo->picHeight = displayHeight;
        retInfo->subsample = subsample;
    }
    // if ((pYuv=malloc(outbufSize)) == NULL) {
    //     JLOG(ERR, "Fail to allocation memory for display buffer\n");
    //     goto ERR_DEC_OPEN;
    // }

    // Register frame buffers requested by the decoder.
    outFrameInfo->dst_addr      = frameBufs[(*pHandle)->instIndex][0].bufY;
    outFrameInfo->dst_virt_addr = (void *)pFrame[0]->vbY.virt_addr;
    outFrameInfo->pad_y         = frameBufs[(*pHandle)->instIndex][0].stride - displayWidth;
    Uint32 decodingWidth_c;
   
    switch (subsample) {
        case FORMAT_420: 
        case FORMAT_422: decodingWidth_c= (displayWidth % 2) ? displayWidth / 2 + 1 : displayWidth / 2; break;
        case FORMAT_444: decodingWidth_c = displayWidth;   break;
        default:   JLOG(ERR,"unsupported subsample format\n"); break;
    }

    outFrameInfo->pad_c = frameBufs[(*pHandle)->instIndex][0].strideC - decodingWidth_c;

    if ((ret = JPU_DecRegisterFrameBuffer((*pHandle), frameBufs[(*pHandle)->instIndex], needFrameBufCount, framebufStride)) != JPG_RET_SUCCESS) {
        JLOG(ERR, "JPU_DecRegisterFrameBuffer failed Error code is 0x%x \n", ret );
        goto ERR_DEC_OPEN;
    }

    if ((ret = JPU_DecGiveCommand((*pHandle), SET_JPG_SCALE_HOR,  &(param->iHorScaleMode))) != JPG_RET_SUCCESS) {
        JLOG(ERR, "JPU_DecGiveCommand[SET_JPG_SCALE_HOR] failed Error code is 0x%x \n", ret );
        goto ERR_DEC_OPEN;
    }
    if ((ret = JPU_DecGiveCommand((*pHandle), SET_JPG_SCALE_VER,  &(param->iVerScaleMode))) != JPG_RET_SUCCESS) {
        JLOG(ERR, "JPU_DecGiveCommand[SET_JPG_SCALE_VER] failed Error code is 0x%x \n", ret );
        goto ERR_DEC_OPEN;
    }

    return TRUE;

ERR_DEC_OPEN:
    FreeFrameBuffer((*pHandle)->instIndex);

    ret = JPU_DecClose(*pHandle);
    if (ret != JPG_RET_SUCCESS)
        suc = 0;

    JPU_DeInit();

    return FALSE;    
}


BOOL JPU_decode_one_frame(void* feeder, JpgDecHandle* pHandle, Uint8* pYuv) {

    JpgRet              ret = JPG_RET_SUCCESS;
    JpgDecParam         decParam    = {0};
    JpgDecOutputInfo    outputInfo    = {0};
    BOOL                suc = FALSE;
    Int32               int_reason = 0;

    /* LOG HEADER */
    JLOG(INFO, "I   F    FB_INDEX  FRAME_START  ECS_START  CONSUME   RD_PTR   WR_PTR      CYCLE\n");
    JLOG(INFO, "-------------------------------------------------------------------------------\n");

    while(1) {
        // Start decoding a frame.
        ret = JPU_DecStartOneFrame((*pHandle), &decParam);
        if (ret != JPG_RET_SUCCESS && ret != JPG_RET_EOS) {
            if (ret == JPG_RET_BIT_EMPTY) {
                JLOG(INFO, "BITSTREAM NOT ENOUGH.............\n");
                BitstreamFeeder_Act(feeder, (*pHandle), &vbStreams[(*pHandle)->instIndex]);
                continue;
            }

            JLOG(ERR, "JPU_DecStartOneFrame failed Error code is 0x%x \n", ret );
            goto ERR_DEC_OPEN;
        }
        if (ret == JPG_RET_EOS) {
            JPU_DecGetOutputInfo((*pHandle), &outputInfo);
            suc = TRUE;
            break;
        }

        //JLOG(INFO, "\t<+>INSTANCE #%d JPU_WaitInterrupt\n", (*pHandle)->instIndex);
        while(1) {
            if ((int_reason=JPU_WaitInterrupt((*pHandle), JPU_INTERRUPT_TIMEOUT_MS)) == -1) {
                JLOG(ERR, "Error : timeout happened\n");
                JPU_SWReset((*pHandle));
                break;
            }
            if (int_reason == -2) {
                JLOG(ERR, "Interrupt occurred. but this interrupt is not for my instance \n");
                continue;
            }

            if (int_reason & ((1<<INT_JPU_DONE) | (1<<INT_JPU_ERROR) | (1<<INT_JPU_SLICE_DONE))) {
                // Do no clear INT_JPU_DONE and INT_JPU_ERROR interrupt. these will be cleared in JPU_DecGetOutputInfo.
                JLOG(INFO, "\tINSTANCE #%d int_reason: %08x\n", (*pHandle)->instIndex, int_reason);
                break;
            }

            if (int_reason & (1<<INT_JPU_BIT_BUF_EMPTY)) {
                BitstreamFeeder_Act(feeder, (*pHandle), &vbStreams[(*pHandle)->instIndex]);
                JPU_ClrStatus((*pHandle), (1<<INT_JPU_BIT_BUF_EMPTY));
            }
        }
        //JLOG(INFO, "\t<->INSTANCE #%d JPU_WaitInterrupt\n", handle->instIndex);

        if ((ret=JPU_DecGetOutputInfo((*pHandle), &outputInfo)) != JPG_RET_SUCCESS) {
            JLOG(ERR, "JPU_DecGetOutputInfo failed Error code is 0x%x \n", ret );
            goto ERR_DEC_OPEN;
        }

        if (outputInfo.decodingSuccess == 0)
            JLOG(ERR, "JPU_DecGetOutputInfo decode fail\n");

        JLOG(INFO, "%02d  %8d     %8x %8x %10d  %8x  %8x %10d\n",
            (*pHandle)->instIndex, outputInfo.indexFrameDisplay, outputInfo.bytePosFrameStart, outputInfo.ecsPtr, outputInfo.consumedByte,
            outputInfo.rdPtr, outputInfo.wrPtr, outputInfo.frameCycle);

        if (outputInfo.indexFrameDisplay == -1)
            break;

        // saveIdx = outputInfo.indexFrameDisplay;
        // if (!SaveYuvImageHelperFormat_V20(fpYuv, dst, &frameBufs[(*pHandle)->instIndex][saveIdx], decOP.chromaInterleave, decOP.packedFormat, displayWidth, displayHeight, bitDepth, FALSE)) {
        //     goto ERR_DEC_OPEN;
        // }
        if (pYuv != NULL) {
            FrameBuffer* pframeBuf_res;
            pframeBuf_res = (*pHandle)->JpgInfo->decInfo.frameBufPool;

            if (!SaveYuvImageHelperFormat_V20(NULL, pYuv, pframeBuf_res, (*pHandle)->JpgInfo->decInfo.chromaInterleave, (*pHandle)->JpgInfo->decInfo.packedFormat, displayWidth, displayHeight, bitDepth, FALSE)) {
                goto ERR_DEC_OPEN;
            }
        }

        if (outputInfo.numOfErrMBs) {
            Int32 errRstIdx, errPosX, errPosY;
            errRstIdx = (outputInfo.numOfErrMBs & 0x0F000000) >> 24;
            errPosX = (outputInfo.numOfErrMBs & 0x00FFF000) >> 12;
            errPosY = (outputInfo.numOfErrMBs & 0x00000FFF);
            JLOG(ERR, "Error restart Idx : %d, MCU x:%d, y:%d\n", errRstIdx, errPosX, errPosY);
        }

        suc = TRUE;
        break;

    }

ERR_DEC_OPEN:

    return suc;
}

BOOL JPU_decode_deinit(JpgDecHandle pHandle) {
    JpgRet              ret = JPG_RET_SUCCESS;
    BOOL                suc = TRUE;

    FreeFrameBuffer((pHandle)->instIndex);

    // Now that we are done with decoding, close the open instance.
    ret = JPU_DecClose(pHandle);
    if (ret != JPG_RET_SUCCESS)
        suc = 0;

    jdi_free_dma_memory(&vbStreams[(pHandle)->instIndex]);
    vbStreams[(pHandle)->instIndex].base = 0;
    vbStreams[(pHandle)->instIndex].size = 0;

    JPU_DeInit();

    // JLOG(INFO, "\nJPU decode deinit. instIdx=%d\n" , (*pHandle)->instIndex);

    return suc;
}

BOOL FeedOneFrame(void* feeder, JpgDecHandle* pHandle) {
    BitstreamFeeder_Act(feeder, (*pHandle), &vbStreams[(*pHandle)->instIndex]);
    return TRUE;
}

BOOL JPU_DecResetRdPtrEx(JpgDecHandle* pHandle) {
    JPU_DecSetRdPtrEx((*pHandle), vbStreams[(*pHandle)->instIndex].phys_addr, TRUE);
    return TRUE;
}