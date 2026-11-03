/****************************************************************
 * Copyright (c) 2023 - 2024 Anlogic, Inc.  All rights reserved.
 * SPDX-License-Identifier: MIT
 ****************************************************************/

#include "JW_Wrapper.h"
#include "jpuapi.h"
#include "jpulog.h"

JpgRet JW_Init() {
    JpgRet ret = JPU_Init();

    if (ret != JPG_RET_SUCCESS && ret != JPG_RET_CALLED_BEFORE) {
        JLOG(ERR, "JPU_Init failed Error code is 0x%x \n", ret);
        return ret;
    }

    Uint32 apiVersion;
    Uint32 hwRevision;
    Uint32 hwProductId;
    JPU_GetVersionInfo(&apiVersion, &hwRevision, &hwProductId);
    JLOG(INFO, "JPU Version API_VERSION=0x%x, HW_REVISION=%d, HW_PRODUCT_ID=0x%x\n", apiVersion, hwRevision, hwProductId);

    if (hwProductId != PRODUCT_ID_CODAJ12) {
        JLOG(ERR, "Error JPU HW_PRODUCT_ID=0x%x is not match with API_VERSION=0x%x\n", hwProductId, apiVersion);
        JPU_DeInit();
        return ret;
    }
    return ret;
}

void JW_DeInit() {
    JPU_DeInit();
}