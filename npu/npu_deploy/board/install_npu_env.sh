#!/bin/sh
# install_npu_env.sh —— 板上安装 NPU 三分类运行环境（刷镜像后跑一次）
set -e
mkdir -p /opt/npu/lib /opt/npu/threeclass/bin /opt/npu/threeclass/models /opt/npu/tc /root/data

chmod +x /opt/npu/threeclass/bin/dcdc_npu_threeclass_infer 2>/dev/null || true
chmod +x /opt/npu/threeclass/batch46.sh 2>/dev/null || true
chmod +x /opt/npu/tc/* 2>/dev/null || true

cat > /etc/init.d/S98npu <<'EOF'
#!/bin/sh
# NPU 驱动自启：cma_mem -> jpu -> hard_npu
KO=/opt/npu/ko
case "$1" in
  start)
    [ -e /dev/hard_npu ] && exit 0
    insmod $KO/cma_mem.ko 2>/dev/null
    insmod $KO/jpu.ko 2>/dev/null
    insmod $KO/hard_npu.ko 2>/dev/null
    ;;
  stop)
    rmmod hard_npu 2>/dev/null; rmmod jpu 2>/dev/null; rmmod cma_mem 2>/dev/null
    ;;
esac
EOF
chmod +x /etc/init.d/S98npu

cat > /opt/npu/threeclass/run.sh <<'EOF'
#!/bin/sh
# 单窗口推理：./run.sh xxx.physical_f32.bin xxx.baseline_f64.bin
set -u
base=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
[ -e /dev/hard_npu ] || sh /etc/init.d/S98npu start
export LD_LIBRARY_PATH=/opt/npu/lib
export LD_PRELOAD=/opt/npu/lib/libsoftnpu_shim.so
read ins inz outs outz < "$base/models/quant_params.txt"
phys=$1; shift; basef=$1; shift
B=$(grep HARD_NPU_IRQ /proc/interrupts | awk '{print $2}')
out=$("$base/bin/dcdc_npu_threeclass_infer" --model "$base/models/condition_threeclass_uint8.onnx" \
      --physical-input "$phys" --baseline "$basef" \
      --input-scale "$ins" --input-zero-point "$inz" \
      --output-scale "$outs" --output-zero-point "$outz" \
      --profile /tmp/tc_profile.json --graph /tmp/tc_graph.dot "$@" 2>&1)
A=$(grep HARD_NPU_IRQ /proc/interrupts | awk '{print $2}')
echo "$out" | grep -E "LOGITS|FILE_INFERENCE_OK" | tail -2
echo "[run] irq_delta=$((A-B))"
EOF
chmod +x /opt/npu/threeclass/run.sh

sh /etc/init.d/S98npu start
ls /dev/hard_npu /dev/cma_mem
echo install-ok
