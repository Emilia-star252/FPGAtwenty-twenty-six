/****************************************************************
 * Copyright (c) 2023 - 2024 Anlogic, Inc.  All rights reserved.
 * SPDX-License-Identifier: MIT
 ****************************************************************/

#pragma once
#include "jputypes.h"

#ifdef __cplusplus
extern "C" {
#endif // __cplusplus

/**
 * @brief JPU Buff的基类,在JPU Wrapper包装的api中是JPU和外部数据沟通的桥梁
 * <br/> BuffHandle必须包含了一块物理连续地址的Buffer,接口为 @ref {JW_BuffHandleVtable}
 * <br/> 如果要自定义实现,请继承并实现所有接口
 */
struct JW_BuffHandleBase;
struct JW_BuffHandleVtable {
    /**
     * @brief 析构
     *
     * @param p
     */
    void (*DeInit)(struct JW_BuffHandleBase *p);

    /**
     * @brief 返回JPU buff的物理地址,必须4kB对齐
     *
     * @param p
     * @return PhysicalAddress
     */
    PhysicalAddress (*GetPhysAddr)(struct JW_BuffHandleBase *p);

    /**
     * @brief 返回JPU buff的CPU访问地址
     *
     * @param p
     * @return void*
     */
    void *(*GetVirtAddr)(struct JW_BuffHandleBase *p);

    /**
     * @brief 返回JPU buff的大小,必须4kB对齐
     *
     * @param p
     * @return Uint32
     */
    Uint32 (*GetSize)(struct JW_BuffHandleBase *p);

    /**
     * @brief 调整JPU buff的大小,假设是扩容的话
     *
     * @param p
     * @param new_cap_size
     * @return Uint32
     */
    Uint32 (*Reserve)(struct JW_BuffHandleBase *p, Uint32 new_cap_size);

    /**
     * @brief 通知BuffHandle从外部往JPU buff写入内容,返回写入字节数
     *
     * @param p
     * @param feed_size
     * @return Uint32
     */
    Uint32 (*FeedAct)(struct JW_BuffHandleBase *p, Uint32 feed_size);

    /**
     * @brief 通知BuffHandle从JPU buff往外部写入内容,返回写入字节数
     *
     * @param p
     * @param write_size
     * @return Uint32
     */
    Uint32 (*WriteAct)(struct JW_BuffHandleBase *p, Uint32 write_size);

    /**
     * @brief 返回WriteAct的总写入
     *
     * @param p
     * @return Uint32
     */
    Uint32 (*GetWriteSize)(struct JW_BuffHandleBase *p);

    /**
     * @brief 重置读写偏移状态
     *
     * @param p
     * @param update_mem_offset 是否更新外部缓存的指针
     */
    void (*ResetWrRdPtr)(struct JW_BuffHandleBase *p, BOOL update_mem_offset);

    /**
     * @brief 提供写入Jpg Header的CPU访问地址,将在HeaderWriteFinish通知写入完成
     *
     * @param[in] p
     * @param[in] reserve_size
     * @return void*
     */
    void *(*HeaderWrite)(struct JW_BuffHandleBase *p, Uint32 reserve_size);

    /**
     * @brief @ref {HeaderWrite}
     * <br/> 通知写入了write_size个字节
     *
     * @param p
     * @param write_size
     */
    void (*HeaderWriteFinish)(struct JW_BuffHandleBase *p, Uint32 write_size);
};
typedef struct JW_BuffHandleBase {
    struct JW_BuffHandleVtable *vtable;
} JW_BuffHandleBase_t;

#ifdef __cplusplus
}
#endif // __cplusplus
