#!/bin/sh
# 在板子上跑：先确认 NPU 驱动已加载、库路径正确。
#
#   ./run.sh                      # 交互输入 V I D
#   ./run.sh -c dcdc_board_test.csv --check
#   ./run.sh -b CpuRef -c dcdc_board_test.csv   # 纯 CPU 对比
#   ./run.sh -b Alnpu,CpuRef -v -c ... | tee npu_evidence.log
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
BASE=${NPU_BASE:-/opt/npu}

if [ ! -e /dev/hard_npu ] || [ ! -e /dev/cma_mem ]; then
    echo "[run] 缺 /dev/hard_npu 或 /dev/cma_mem，先加载驱动："
    echo "      insmod cma_mem.ko && insmod jpu.ko && insmod hard_npu.ko"
    exit 1
fi

# 官方 SDK 的库放在 $BASE/lib（libarmnn.so.32 / libarmnnOnnxParser.so.24 / libprotobuf.so.23）
LD_LIBRARY_PATH="$BASE/lib:$HERE:$LD_LIBRARY_PATH"
export LD_LIBRARY_PATH

exec "$HERE/dcdc_npu_demo" -m "${MODEL:-$HERE/dcdc_npu_qdq.onnx}" "$@"
