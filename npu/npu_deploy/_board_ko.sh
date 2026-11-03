set -e
mkdir -p /opt/npu/ko
cp -f /tmp/01_????/*.ko /opt/npu/ko/ 2>/dev/null || cp -f /tmp/01_*/*.ko /opt/npu/ko/
ls -l /opt/npu/ko/
echo "--- insmod ---"
insmod /opt/npu/ko/cma_mem.ko && echo "cma_mem ok"
insmod /opt/npu/ko/jpu.ko && echo "jpu ok"
insmod /opt/npu/ko/hard_npu.ko && echo "hard_npu ok"
echo "--- dev ---"
ls -l /dev/hard_npu /dev/cma_mem /dev/jpu 2>&1
echo "--- dmesg ---"
dmesg | tail -n 15