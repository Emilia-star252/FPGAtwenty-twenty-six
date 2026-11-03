echo "--- driver bind ---"
ls -l /sys/bus/platform/devices/63f00000.hard_npu/driver 2>&1 | sed 's/.*-> //'
echo "--- irq 40 ---"
grep -E " 40:" /proc/interrupts || echo "(no irq 40)"
echo "--- dmesg hard_npu ---"
dmesg | grep -i -E "hard_npu|cma_mem|npu" | tail -n 8
echo "--- video ---"
ls /dev/video* 2>&1