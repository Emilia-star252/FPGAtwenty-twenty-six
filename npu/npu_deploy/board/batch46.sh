#!/bin/sh
# batch46.sh - run the 46 packaged regression cases on the board.
# hard_npu is exclusive: stop the resident daemon first, restart it afterwards.
set -u
cd /opt/npu/threeclass || exit 1
[ -e /dev/hard_npu ] || sh /etc/init.d/S98npu start

RESTART_DAEMON=0
if [ -x /etc/init.d/S99npu_daemon ] && pidof npu_daemon >/dev/null 2>&1; then
  /etc/init.d/S99npu_daemon stop >/dev/null 2>&1
  RESTART_DAEMON=1
  sleep 1
fi

export LD_LIBRARY_PATH=/opt/npu/lib
export LD_PRELOAD=/opt/npu/lib/libsoftnpu_shim.so
read ins inz outs outz < models/quant_params.txt
B0=$(grep HARD_NPU_IRQ /proc/interrupts | awk '{print $2}')
ok=0; bad=0; n=0
while read name cpu group truth; do
  [ -n "$name" ] || continue
  n=$((n+1))
  cls=$(./bin/dcdc_npu_threeclass_infer --model models/condition_threeclass_uint8.onnx \
        --physical-input "vectors/$name.physical_f32.bin" --baseline "vectors/$name.baseline_f64.bin" \
        --input-scale "$ins" --input-zero-point "$inz" \
        --output-scale "$outs" --output-zero-point "$outz" \
        --profile /tmp/tc_p.json --graph /tmp/tc_g.dot 2>&1 | grep -o 'CLASS=[0-9]' | head -1 | cut -d= -f2)
  if [ "$cls" = "$truth" ]; then ok=$((ok+1)); else bad=$((bad+1)); echo "MISMATCH $name truth=$truth got=$cls"; fi
done < vectors/cases.txt
A0=$(grep HARD_NPU_IRQ /proc/interrupts | awk '{print $2}')
echo "CASES=$n OK=$ok BAD=$bad IRQ_DELTA=$((A0-B0))"

if [ "$RESTART_DAEMON" = 1 ]; then
  /etc/init.d/S99npu_daemon start >/dev/null 2>&1
  echo "npu_daemon restarted"
fi
