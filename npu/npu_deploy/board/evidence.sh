#!/bin/sh
# 一次把「NPU 到底有没有参与」的三类证据收齐，输出到指定目录。
#
#   ./evidence.sh [输出目录]          默认 npu_evidence_<时间戳>
#   CSV=dcdc_board_test.csv ./evidence.sh
#
# 采集内容：
#   1) Alnpu 强制 + armnn Info 日志（看层分配到哪个后端）        -> alnpu_verbose.log
#   2) 同一份输入跑 CpuRef，对比单次推理时延                      -> cpuref.log / summary.txt
#   3) 硬 NPU 的 IRQ 40 计数增量（最硬的证据）                    -> irq_before.txt / irq_after.txt
set -e

HERE=$(cd "$(dirname "$0")" && pwd)
OUT=${1:-npu_evidence_$(date +%Y%m%d_%H%M%S)}
CSV=${CSV:-dcdc_board_test.csv}
MODEL=${MODEL:-dcdc_npu_qdq.onnx}

mkdir -p "$OUT"
cd "$HERE"

irq_count() {
    # 硬 NPU 的中断号因内核/DT 而异：本板是 41，名字是 HARD_NPU_IRQ（40 是 JPU_CODEC_IRQ）。
    # 优先按名字找，找不到再退回 40/41。
    line=$(grep -E 'HARD_NPU_IRQ' /proc/interrupts 2>/dev/null | head -1)
    [ -n "$line" ] || line=$(grep -E '(^|[[:space:]])4[01]:' /proc/interrupts 2>/dev/null | head -1)
    echo "$line" | awk '{s=0; for(i=2;i<=NF;i++) if ($i ~ /^[0-9]+$/) s+=$i; print s+0}'
}

echo "[evidence] 输出目录: $OUT"
echo "[evidence] 模型: $MODEL  样本: $CSV"

grep -E 'HARD_NPU_IRQ|(^|[[:space:]])4[01]:' /proc/interrupts > "$OUT/irq_before.txt" 2>/dev/null || true
BEFORE=$(irq_count)
[ -n "$BEFORE" ] || BEFORE=0

echo "[evidence] 1/3  Alnpu + verbose ..."
./run.sh -m "$MODEL" -b Alnpu -v -c "$CSV" --check > "$OUT/alnpu_verbose.log" 2>&1 || \
    echo "[evidence] Alnpu 运行返回非零，见 $OUT/alnpu_verbose.log"

AFTER=$(irq_count)
[ -n "$AFTER" ] || AFTER=0
grep -E 'HARD_NPU_IRQ|(^|[[:space:]])4[01]:' /proc/interrupts > "$OUT/irq_after.txt" 2>/dev/null || true

echo "[evidence] 2/3  CpuRef 对照 ..."
./run.sh -m "$MODEL" -b CpuRef -c "$CSV" --check > "$OUT/cpuref.log" 2>&1 || \
    echo "[evidence] CpuRef 运行返回非零，见 $OUT/cpuref.log"

echo "[evidence] 3/3  干净 CSV（供 PC 侧对拍概率）..."
./run.sh -m "$MODEL" -b Alnpu -c "$CSV" > "$OUT/board_out.csv" 2> "$OUT/board_out.err" || \
    echo "[evidence] 干净 CSV 运行返回非零，见 $OUT/board_out.err"

{
    echo "=== NPU 证据汇总 $(date) ==="
    echo "模型: $MODEL"
    echo "样本: $CSV"
    echo
    echo "--- IRQ 40 计数 ---"
    echo "before=$BEFORE  after=$AFTER  delta=$((AFTER - BEFORE))"
    echo "（delta>0 说明驱动确实进了硬 NPU 中断；若为 0 而日志里又显示 Alnpu，需要怀疑是 CPU 回退或中断号变了）"
    echo
    echo "--- 层分配（alnpu_verbose.log 摘要）---"
    grep -iE 'backend|alnpu|cpu' "$OUT/alnpu_verbose.log" | head -40 || echo "(日志里没有 backend 行)"
    echo
    echo "--- 时延对比 ---"
    echo "Alnpu: $(grep '单次推理' "$OUT/alnpu_verbose.log" | tail -1)"
    echo "CpuRef: $(grep '单次推理' "$OUT/cpuref.log" | tail -1)"
    echo
    echo "--- 与期望标签的一致率 ---"
    echo "Alnpu: $(grep -c '期望' "$OUT/alnpu_verbose.log" || true) 条不一致"
    echo "CpuRef: $(grep -c '期望' "$OUT/cpuref.log" || true) 条不一致"
    echo
    echo "--- 拿回 PC 后必做（概率级对拍，比只看类别严格）---"
    echo "python compare_board_output.py $OUT/board_out.csv out/dcdc_board_test_expected.csv"
    echo "量化模型加 --tol 5e-2；float32 模型用默认 1e-4"
} > "$OUT/summary.txt" 2>&1

cat "$OUT/summary.txt"
echo "[evidence] 完成：把 $OUT 整个目录拷回来即可"
