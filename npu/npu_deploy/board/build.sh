#!/bin/sh
# 在 Linux 构建机（VM）里交叉编译 dcdc_npu_demo。
# 官方 SDK 用的是 ~/uisrc-lab-anlogic/tools/aarch64-linux/bin/aarch64-linux-gnu-g++，
# 这里全部可用环境变量覆盖。
#
# 用法:
#   ARMNN_DIR=~/npu/app/face_detection/libs/armnn_lib ./build.sh
#   WEIGHTS=1 ARMNN_DIR=... ./build.sh        # 额外支持 --weights 模式
set -e

HERE=$(cd "$(dirname "$0")" && pwd)
CXX=${CXX:-$HOME/uisrc-lab-anlogic/tools/aarch64-linux/bin/aarch64-linux-gnu-g++}
CC=${CC:-$HOME/uisrc-lab-anlogic/tools/aarch64-linux/bin/aarch64-linux-gnu-gcc}
: "${ARMNN_DIR:?需要设置 ARMNN_DIR=<sdk>/app/face_detection/libs/armnn_lib}"

echo "[build] CXX=$CXX"
echo "[build] ARMNN_DIR=$ARMNN_DIR"

cmake -S "$HERE" -B "$HERE/build" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_COMPILER="$CXX" \
    -DCMAKE_C_COMPILER="$CC" \
    -DCMAKE_SYSTEM_NAME=Linux \
    -DArmnn_DIR="$ARMNN_DIR" \
    -DDCDC_USE_WEIGHTS="${WEIGHTS:-OFF}"

cmake --build "$HERE/build" -j
echo "[build] 产物: $HERE/build/dcdc_npu_demo"
