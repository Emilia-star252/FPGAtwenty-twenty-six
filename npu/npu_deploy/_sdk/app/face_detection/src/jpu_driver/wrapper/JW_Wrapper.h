/****************************************************************
 * Copyright (c) 2023 - 2024 Anlogic, Inc.  All rights reserved.
 * SPDX-License-Identifier: MIT
 ****************************************************************/

#pragma once

#include "JW_BuffHandleBase.h"
#include "JW_BuffHandleMem.h"
#include "JW_BuffHandleMemNoCopy.h"
#include "JW_BuffHandleFile.h"
#include "JW_Decoder.h"
#include "JW_Encoder.h"

#ifdef __cplusplus
extern "C" {
#endif // __cplusplus

JpgRet JW_Init();
void JW_DeInit();

#ifdef __cplusplus
}
#endif // __cplusplus