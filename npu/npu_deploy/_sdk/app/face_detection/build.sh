#!/bin/bash
# 当出现错误的时候终止脚本
set -e

# 设置脚本当前绝对路径
SCRIPT_DIR=/home/uisrc/app/face_detection

# 设置工程根目录
ROOT_DIR=/home/uisrc/uisrc-lab-anlogic

# 设置交叉编译工具链
cxx_compiler="/home/uisrc/uisrc-lab-anlogic/tools/aarch64-linux/bin/aarch64-linux-gnu-g++"
c_compiler="/home/uisrc/uisrc-lab-anlogic/tools/aarch64-linux/bin/aarch64-linux-gnu-gcc"

# 设置内核目录（根据你的实际路径修改）
KERNELDIR="/home/uisrc/uisrc-lab-anlogic/sources/linux"  # 修改为实际的内核源码路径
ARCH="arm64"  # 或者 "aarch64"

# 从npu demo中拷贝opencv和armnn
cd $SCRIPT_DIR
mkdir -p rootfs
mkdir -p rootfs/root

# 从libs目录拷贝内容（相当于原来的npu/libs）
rsync -av ./libs/* ./rootfs/root/

# 拷贝输入文件和脚本
rsync -av ./inputs ./rootfs/root/
rsync -av ./scripts ./rootfs/root/

# 执行编译
DEMO_DIR=$SCRIPT_DIR/src
build_dir=$SCRIPT_DIR/build
install_dir=$SCRIPT_DIR/rootfs/root

# 调用cmake进行编译
cmake -DCMAKE_BUILD_TYPE:STRING=Release -S$DEMO_DIR -B$build_dir -G Ninja \
-DCMAKE_EXPORT_COMPILE_COMMANDS:BOOL=TRUE \
-DCMAKE_CXX_COMPILER:FILEPATH=${cxx_compiler} \
-DCMAKE_C_COMPILER:FILEPATH=${c_compiler} \
-DCMAKE_SYSTEM_NAME:STRING=Linux \
-DBUILD_MODULES:BOOL=ON \
-DBUILD_APPS:BOOL=ON \
-DKERNELDIR:STRING=${KERNELDIR} \
-DARCH:STRING=${ARCH} \
-DArmnn_DIR=${SCRIPT_DIR}/rootfs/root/armnn_lib \
-DOpenCV_DIR=${SCRIPT_DIR}/rootfs/root/ffmpeg_opencv4.7.0_aarch64/lib/cmake/opencv4 \
-DCMAKE_INSTALL_PREFIX:STRING=${install_dir}

# 编译 & 安装
cmake --build $build_dir --config Release --target install --
