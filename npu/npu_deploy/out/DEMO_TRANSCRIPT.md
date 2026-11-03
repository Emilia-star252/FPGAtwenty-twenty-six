# 三分类 NPU 模型：板上演示记录

生成时间：2026-10-27 12:25，板卡 192.168.137.101

## 1. 46 例回归
```
CASES=46 OK=46 BAD=0 IRQ_DELTA=46
```

## 2. 流式滑窗（128 Hz 回放，hop 1 s）
```
[live] csv=cap_phases.csv rows=1536 rate=128.0Hz hop=1.00s
[live] model loaded: in=768B out=1024B scale=0.040594459/0.024775308
   2.49s  normal          [21 2 0]  0.255 ms
   3.49s  normal          [19 0 0]  0.089 ms
   4.49s  load_transient  [25 220 44]  0.158 ms
   5.49s  load_transient  [25 220 44]  0.091 ms
   6.49s  load_transient  [9 217 8]  0.102 ms
   7.49s  load_transient  [9 213 11]  0.095 ms
   8.49s  load_transient  [8 229 12]  0.091 ms
   9.49s  load_transient  [8 225 15]  0.090 ms
  10.49s  load_transient  [0 221 34]  0.089 ms
  11.49s  load_transient  [0 218 36]  0.090 ms
[live] 10 windows, 3.4 ms total (0.34 ms/window incl. preprocess)
```

## 3. PC 侧同样的数据（交叉对照）
```
[scan] cap_phases.csv: 10 windows, hop 1.0s, model condition_threeclass_uint8.onnx
  t_end(s)  class             scores(u8)
     2.00  normal           [49, 40, 47]
     3.00  normal           [19, 0, 0]
     4.00  load_transient   [23, 34, 34]
     5.00  load_transient   [30, 220, 34]
     6.00  load_transient   [9, 220, 8]
     7.00  load_transient   [9, 216, 9]
     8.00  load_transient   [9, 212, 11]
     9.00  load_transient   [9, 226, 15]
    10.00  load_transient   [15, 220, 11]
    11.00  load_transient   [15, 218, 13]
[scan] counts: normal 2, load_transient 8, oscillation 0
[scan] switches: t=4.00s normal->load_transient
```

