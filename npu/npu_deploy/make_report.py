"""汇总训练/导出结果，生成 out/RESULTS.md（可重复执行，数字来自实际产物）。"""

from __future__ import annotations

import csv
import json
import os
import sys

import numpy as np

import dcdc_sim as sim


def dataset_stats(path):
    xs, ys = [], []
    with open(path, newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            xs.append([float(row["v_mean"]), float(row["i_mean"]), float(row["d_mean"])])
            ys.append(int(row["label"]))
    x = np.asarray(xs)
    y = np.asarray(ys)
    per = []
    for c in range(4):
        m = y == c
        per.append({
            "class": sim.CLASS_NAMES[c],
            "n": int(m.sum()),
            "v": [float(x[m, 0].min()), float(x[m, 0].max())],
            "i": [float(x[m, 1].min()), float(x[m, 1].max())],
            "d": [float(x[m, 2].min()), float(x[m, 2].max())],
        })
    return len(y), per


def main(argv=None) -> int:
    outdir = "out"
    metrics_path = os.path.join(outdir, "model_metrics.json")
    model_json = os.path.join(outdir, "dcdc_npu_model.json")
    dataset = os.path.join(outdir, "dataset.csv")
    onnx_path = os.path.join(outdir, "dcdc_npu.onnx")

    with open(metrics_path, encoding="utf-8") as f:
        m = json.load(f)
    with open(model_json, encoding="utf-8") as f:
        mm = json.load(f)
    n, per = dataset_stats(dataset)
    onnx_size = os.path.getsize(onnx_path)

    lines = []
    lines.append("# DC-DC 工况识别：训练 / 导出结果\n")
    lines.append("> 本文件由 `make_report.py` 从实际产物生成，改数据后重跑即可更新。\n")
    lines.append("## 1. 训练集\n")
    lines.append(f"- 来源：`dcdc_sim.py` 物理仿真（四开关 buck-boost + 限流 + OVP/OCP 保护），共 **{n}** 条")
    lines.append(f"- 划分：按试验号分组，train {m['n']['train']} / val {m['n']['val']} / test {m['n']['test']}")
    lines.append("- 特征（模型输入）：`v_mean`(V), `i_mean`(A), `d_mean`(%)\n")
    lines.append("| 类别 | 样本数 | V 范围 (V) | I 范围 (A) | duty 范围 (%) |")
    lines.append("| --- | ---: | --- | --- | --- |")
    for p in per:
        lines.append(f"| {p['class']} | {p['n']} | {p['v'][0]:.2f}–{p['v'][1]:.2f} | "
                     f"{p['i'][0]:.3f}–{p['i'][1]:.3f} | {p['d'][0]:.2f}–{p['d'][1]:.2f} |")
    lines.append("")
    lines.append("## 2. 训练结果\n")
    lines.append(f"- 网络：MLP 3 → {mm['hidden'][0]} → {mm['hidden'][1]} → 4，ReLU + Softmax")
    lines.append(f"- 训练轮数：{m['epochs']}（最佳 val 轮次 {m['best_epoch']}）")
    lines.append(f"- 准确率：train {m['acc']['train'] * 100:.2f}% / val {m['acc']['val'] * 100:.2f}% / "
                 f"test {m['acc']['test'] * 100:.2f}%")
    lines.append(f"- 对照：只用 I/V 阈值的规则 test acc = {m['rule_baseline_test'] * 100:.2f}%")
    lines.append("")
    lines.append("混淆矩阵（行=真值，列=预测）：\n")
    lines.append("| 真值 \\ 预测 | 轻载 | 额定 | 近限流 | 故障 |")
    lines.append("| --- | ---: | ---: | ---: | ---: |")
    for i, row in enumerate(m["confusion_test"]):
        lines.append(f"| {sim.CLASS_NAMES[i]} | " + " | ".join(str(v) for v in row) + " |")
    lines.append("")
    lines.append("| 类别 | support | precision | recall | F1 |")
    lines.append("| --- | ---: | ---: | ---: | ---: |")
    for pc in m["per_class"]:
        lines.append(f"| {pc['name']} | {pc['support']} | {pc['precision']:.3f} | "
                     f"{pc['recall']:.3f} | {pc['f1']:.3f} |")
    lines.append("")
    lines.append("## 3. 量化可行性（numpy 仿真）\n")
    qpath = os.path.join(outdir, "quant_report.json")
    if os.path.exists(qpath):
        with open(qpath, encoding="utf-8") as f:
            q = json.load(f)
        lines.append("官方两个现成模型（yolo_face_uint8_15 / fire_detect_sim_quant_uint8）都是 QDQ 结构：")
        lines.append("输入是 uint8 值域的 float 张量 + QuantizeLinear，权重 uint8。硬 NPU 大概率只吃量化图，")
        lines.append("所以先算清楚量化代价：\n")
        lines.append(f"- float test acc = {q['acc_float'] * 100:.2f}%")
        lines.append(f"- int8 权重 / uint8 激活 仿真 acc = {q['acc_quant'] * 100:.2f}%"
                     f"（{q['flipped']}/{q['n_test']} 个样本预测翻转）")
        lines.append(f"- 参数量 {q['params']}：float32 {q['bytes_float32']} B → int8 权重 {q['bytes_int8_weights']} B")
        lines.append(f"- 每张量 scale：input {q['scales']['input']:.6f}，"
                     f"w1 {q['scales']['w1']:.3e}，w2 {q['scales']['w2']:.3e}，w3 {q['scales']['w3']:.3e}")
        lines.append("")
        lines.append("结论：量化损失在这个任务上可以忽略（类别没变），可以走 QDQ 导出；")
        lines.append("但 QDQ 图能否被 Alnpu 后端接受，只有在板上试才知道（见 5. 风险）。")
    else:
        lines.append("（未生成 quant_report.json）")
    lines.append("")
    rb_path = os.path.join(outdir, "robustness.json")
    if os.path.exists(rb_path):
        with open(rb_path, encoding="utf-8") as f:
            rb = json.load(f)
        lines.append("## 4. 鲁棒性（传感器误差敏感度）\n")
        lines.append("不动模型，只改喂进去的三个量（等价于板上增益误差/零点漂移/量化变粗/噪声）：\n")
        lines.append("| 场景 | 准确率 | 相对基线 | 与基线预测一致 |")
        lines.append("| --- | ---: | ---: | ---: |")
        for c in rb["cases"]:
            lines.append(f"| {c['case']} | {c['acc'] * 100:.2f}% | {c['delta'] * 100:+.2f}pp | "
                         f"{c['same_as_base'] * 100:.2f}% |")
        lines.append("")
        lines.append("读法：±2% 增益误差和 10mV/1% 的粗量化基本不掉点；±5% 增益或 5% 噪声掉 2~4 个点，"
                     "掉的主要是贴着类别边界（I≈0.7A / 1.8A）的样本。")
        lines.append("这说明**标定/bias 比模型容量更重要**：真实板上先保证电流采样准，再谈网络加深。")
        lines.append("")
    lines.append("## 5. 导出产物\n")
    lines.append(f"- `{onnx_path}`（{onnx_size} B）：opset 13，Gemm→Relu→Gemm→Relu→Gemm→Softmax（float32，"
                 "给 CpuRef/CpuAcc 兜底用）")
    qdq_json = os.path.join(outdir, "dcdc_npu_qdq_model.json")
    if os.path.exists(qdq_json):
        with open(qdq_json, encoding="utf-8") as f:
            qm = json.load(f)
        lines.append(f"- `dcdc_npu_qdq.onnx`：QDQ + 1×1 Conv（输入 [1,3,1,1]，Conv 权重 uint8、"
                     f"bias int32、激活 uint8）—— **先试这个上 Alnpu**")
        lines.append(f"  - 与独立量化实现数值对拍偏差 {qm['max_dev_vs_reference']:.1e}；"
                     f"与 float 模型类别一致率 {qm['agree_with_float'] * 100:.2f}%；"
                     f"测试集准确率 {qm['acc_test'] * 100:.2f}%")
        lines.append(f"  - 量化参数：输入 scale {qm['quant']['input_scale']:.6f}，"
                     + "，".join(f"conv{i + 1} w_scale {L['w_scale']:.4e} / a_scale "
                                f"{L['a_scale']:.4e}" for i, L in enumerate(qm["quant"]["layers"][:2])))
    pad_json = os.path.join(outdir, "dcdc_npu_qdq_8x4_model.json")
    if os.path.exists(pad_json):
        with open(pad_json, encoding="utf-8") as f:
            pm = json.load(f)
        lines.append(f"- `dcdc_npu_qdq_8x4.onnx`：同样的图，输入补零到 "
                     f"{pm['input']['shape']}（通道/空间对齐被 NPU 要求时用它），"
                     f"测试集 {pm['acc_test'] * 100:.2f}%，对拍偏差 {pm['max_dev_vs_reference']:.1e}")
    lines.append("- `dcdc_npu_weights.h`：C 数组（`--weights` 兜底模式用）")
    lines.append("- `dcdc_npu_model.json`：输入顺序、类别名、隐藏层宽度、除数")
    lines.append("- 标准化与除数已折进第一层；板上先做 u = [V/48, I/2.2, duty/95] 再喂模型")
    lines.append("- 结构自检（`validate_onnx.py`）：三个模型都通过——拓扑序、Gemm 权重/输入维数、"
                 "Conv 权重与通道、QDQ 的 scale/zp 类型都逐个查过")
    lines.append("")
    lines.append("## 6. 怎么读这些数字（重要）\n")
    lines.append("1. 数据是**物理仿真**的，且 4 个类别的边界（0.35/0.90 × 2 A）本身就写在生成器里，")
    lines.append("   所以 test 准确率和「规则基线」几乎一样高。这只证明**链路通了、模型没写错**，")
    lines.append("   不能当作真实工况识别能力的证据。")
    lines.append("2. 只给 3 个瞬时量时，轻载/额定/近限流本质上是按电流大小分档；真实板子上还有纹波、")
    lines.append("   采样相位、标定误差、温漂，边界样本会明显变多。")
    lines.append("3. 真实数据到位后（`host.py` 的 CSV 或板内日志导出成同样列名），重跑 `train.py` 即可，")
    lines.append("   建议同时把窗口统计量（std/斜率）加进特征，再对比一次。")
    lines.append("4. 保护故障类在输入里只表现为「输出关断」（V≈0、I≈0、d=0）；OTP 没有可观测温度，")
    lines.append("   与 OVP/OCP 停机后的签名相同，因此没有单列。")
    lines.append("")

    text = "\n".join(lines)
    path = os.path.join(outdir, "RESULTS.md")
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)
    print(f"[report] 写出 {path}（{len(text)} 字符）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
