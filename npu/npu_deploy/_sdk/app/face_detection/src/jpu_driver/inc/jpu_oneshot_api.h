#ifndef JPU_ONESHOT_API_H_
#define JPU_ONESHOT_API_H_

#include "main_helper.h"

#define NUM_FRAME_BUF               3
#define ENC_SRC_BUF_NUM             1
#define BS_SIZE_ALIGNMENT           4096
#define MIN_BS_SIZE                 8192

typedef struct {
    int picWidth;
    int picHeight;
    FrameFormat subsample;
} picInfo;

typedef struct {
    int pad_y;
    int pad_c;
    uint32_t dst_addr;
    void* dst_virt_addr;
} frameOutputInfo;

#if defined(__cplusplus)
extern "C" {
#endif

BOOL JPU_decode_oneShot(DecConfigParam* param, const uint8_t* src, uint32_t bsize, uint32_t* dst_addr, picInfo* retInfo);
BOOL JPU_encode_oneShot(EncConfigParam* param, const uint8_t* src, uint8_t* dst, uint32_t* bsize);

// JPU decode API
BOOL JPU_decode_init(DecConfigParam* param, JpgDecHandle* pHandle);
BOOL create_bistream_feeder(void** pFeeder, const uint8_t* src, uint32_t bsize, EndianMode endian);
BOOL destroy_bistream_feeder(void *pFeeder);
BOOL frame_initialize(void* feeder, JpgDecHandle* pHandle, DecConfigParam* param, picInfo* retInfo, frameOutputInfo* outFrameInfo);
BOOL JPU_decode_one_frame(void* feeder, JpgDecHandle* pHandle, Uint8* pYuv);
BOOL JPU_decode_deinit(JpgDecHandle pHandle);
BOOL FeedOneFrame(void* feeder, JpgDecHandle* pHandle);
BOOL JPU_DecResetRdPtrEx(JpgDecHandle* pHandle);

// JPU encode API
BOOL JPU_encode_init(EncConfigParam* param, JpgEncHandle* pHandle, YuvAttr* pSouceAttr);
BOOL create_bitstream_writer(void** pWriter, uint8_t* dst);
BOOL create_yuv_feeder(void** pFeeder, int8_t* src, YuvAttr* pSouceAttr, Uint32 frameEndian);
BOOL JPU_encode_one_frame(EncConfigParam* pEncConParam, JpgEncHandle* pHandle, void** pFeeder, void** pWriter, uint32_t* bsize);
BOOL destroy_bitstream_writer(void** pWriter);
BOOL destroy_yuv_feeder(void** pFeeder);
BOOL JPU_encode_deinit(JpgEncHandle pHandle);

#if defined(__cplusplus)
}
#endif
#endif
