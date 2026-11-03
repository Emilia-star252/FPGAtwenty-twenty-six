#!/usr/bin/env python3
"""Freeze a validation-selected context model, then evaluate test once.

Candidate folders remain immutable. This is exploratory evaluation on the
existing dataset: the old global baseline already exposed its test results.
"""
import argparse
import csv
import json
import os
from pathlib import Path
import shutil

import numpy as np

from train_condition import (build_model, evaluate, file_sha, inputs_for_part,
                             load_dataset, save_json)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--candidates", type=Path, nargs="+", required=True)
    parser.add_argument("--dataset", type=Path, default=Path("fpga_prj/output/npu_dataset_20261026"))
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    dataset, output = args.dataset.resolve(), args.output.resolve()
    if output.exists():
        raise ValueError("output exists; preserve earlier evaluations")
    parts, manifest = load_dataset(dataset)
    summaries = []
    for path in args.candidates:
        path = path.resolve()
        hashes = json.loads((path / "artifact_checksums.json").read_text())
        for name, expected in hashes.items():
            if file_sha(path / name) != expected:
                raise ValueError(f"candidate artifact changed: {path / name}")
        config = json.loads((path / "training_config.json").read_text())
        metrics = json.loads((path / "metrics.json").read_text())
        if metrics["test_evaluated"] or "test" in metrics:
            raise ValueError("select only development candidates without test evaluation")
        if config["model"] != "tiny_conv2d_binary_v1":
            raise ValueError("unexpected candidate architecture")
        for name, expected in config["source_dataset_sha256"].items():
            if file_sha(dataset / name) != expected:
                raise ValueError("candidate used a different dataset version")
        p = json.loads((path / "preprocessing.json").read_text())
        if p["feature_transform"]["mode"] != "causal-relative":
            raise ValueError("this selection compares past-context candidates only")
        # Architecture/feature code must match the training snapshots.
        for name in ("train_condition.py", "causal_features.py"):
            if file_sha(path / name) != file_sha(Path(__file__).with_name(name)):
                raise ValueError(f"training snapshot differs from current implementation: {name}")
        summaries.append({"path": str(path), "seed": config["seed"],
                          "best_epoch": metrics["best_epoch"], "epochs_run": metrics["epochs_run"],
                          "validation": metrics["validation"], "best_pt_sha256": file_sha(path / "best.pt")})
    summaries.sort(key=lambda x: (-x["validation"]["macro_f1"], x["validation"]["cross_entropy_unweighted"]))
    selected = summaries[0]
    chosen = Path(selected["path"])
    output.mkdir(parents=True)
    # Persist selection and weight fingerprint BEFORE computing test predictions.
    lock = {"selection_rule": "maximum validation macro F1, then minimum validation unweighted cross entropy",
            "candidates": summaries, "selected": selected,
            "test_status_at_selection": "not evaluated for these context candidates",
            "existing_test_history": "previous global CPU/GPU baselines already exposed test labels and aggregate results; exploratory evaluation, not a fresh blind holdout",
            "new_data_required_for_confirmatory_evaluation": True}
    save_json(output / "selection_lock.json", lock)
    for name in ("best.pt", "preprocessing.json", "training_config.json", "train_condition.py", "causal_features.py"):
        shutil.copyfile(chosen / name, output / name)
    shutil.copyfile(Path(__file__), output / "evaluate_selected.py")
    os.environ.setdefault("CUBLAS_WORKSPACE_CONFIG", ":4096:8")
    import torch
    if not torch.cuda.is_available():
        raise ValueError("CUDA required for this evaluation")
    torch.use_deterministic_algorithms(True)
    torch.backends.cudnn.benchmark = False
    torch.backends.cudnn.deterministic = True
    device = torch.device("cuda")
    checkpoint = torch.load(output / "best.pt", map_location="cpu", weights_only=True)
    preprocessing = json.loads((output / "preprocessing.json").read_text())
    if checkpoint["preprocessing"] != preprocessing:
        raise ValueError("checkpoint preprocessing does not match sidecar")
    model = build_model(torch).to(device)
    model.load_state_dict(checkpoint["state_dict"])
    inputs = torch.from_numpy(inputs_for_part(parts["test"], preprocessing, dataset, manifest))
    targets = torch.from_numpy(parts["test"]["y"])
    test, logits = evaluate(torch, model, inputs, targets, device, 64)
    with (output / "test_predictions.csv").open("x", encoding="utf-8", newline="") as stream:
        writer = csv.writer(stream)
        writer.writerow(["run_id", "start_sample", "end_sample_exclusive", "true_class", "predicted_class", "logit_normal", "logit_load_transient"])
        for k, score in enumerate(logits):
            part = parts["test"]
            writer.writerow([str(part["run_id"][k]), int(part["start_sample"][k]), int(part["end_sample"][k]),
                             int(part["y"][k]), int(score.argmax()), float(score[0]), float(score[1])])
    report = {"selected_run": str(chosen), "selected_weight_sha256": file_sha(output / "best.pt"),
              "gpu_name": torch.cuda.get_device_name(device), "validation": selected["validation"],
              "test": test, "test_evaluated_after_selection_lock": True,
              "scope": "existing labeled windows only, provisional waveform labels; no event-level or NPU claim",
              "limitations": manifest["limitations"] + [lock["existing_test_history"]]}
    save_json(output / "evaluation.json", report)
    svg = ['<svg xmlns="http://www.w3.org/2000/svg" width="1000" height="440" viewBox="0 0 1000 440"><rect width="100%" height="100%" fill="white"/>',
           '<text x="40" y="35" font-family="sans-serif" font-size="22">Context-relative CNN: existing labeled-window evaluation</text>']
    for panel, (label, metrics) in enumerate((("Validation", selected["validation"]), ("Test (exploratory)", test))):
        x0 = 100 + panel * 480
        svg.append(f'<text x="{x0}" y="78" font-family="sans-serif" font-size="18">{label}</text>')
        for row in range(2):
            for col in range(2):
                x, y = x0 + col * 140, 110 + row * 95
                color = "#d4eddf" if row == col else "#f4e7df"
                value = metrics["confusion_matrix_true_rows_predicted_columns"][row][col]
                svg.append(f'<rect x="{x}" y="{y}" width="138" height="93" fill="{color}"/><text x="{x+69}" y="{y+56}" text-anchor="middle" font-family="sans-serif" font-size="25">{value}</text>')
        svg.append(f'<text x="{x0}" y="330" font-family="sans-serif" font-size="13">True rows / predicted columns: normal, transient</text>')
        svg.append(f'<text x="{x0}" y="355" font-family="sans-serif" font-size="14">Transient recall: {metrics["transient_recall"]:.2%}; normal false positives: {metrics["normal_false_positive_rate"]:.2%}</text>')
    svg.append('<text x="40" y="408" font-family="sans-serif" font-size="13">Only 3 independent step recordings; rule-derived labels. No claim of generalization or board inference.</text></svg>')
    (output / "confusion.svg").write_text("\n".join(svg), encoding="utf-8")
    text = f'''# GPU 后续训练与选模 · 2026-10-26

选中模型：`{chosen.name}`，随机种子 {selected['seed']}，最佳第 {selected['best_epoch']} 轮。先按验证集宏平均 F1、再按无权交叉熵比较两个候选；测试前已记录 selection_lock.json 和权重 SHA256。

预处理：每个窗口使用同一采集中其之前最多 2 秒的三路均值，计算相对变化，再使用训练集拟合的均值/标准差。历史区间不含当前窗口和未来样本，不读取标签作为模型输入。在线使用必须保留相同历史统计及占空比/电流分母下限。现有窗口最多只有约 100 ms 历史时即使用已有历史，并没有强制等待满 2 秒。

| 集合 | 正常正确/正常总数 | 突变正确/突变总数 | 突变召回率 | 正常窗口误报率 |
|---|---:|---:|---:|---:|
| 验证 | {selected['validation']['confusion_matrix_true_rows_predicted_columns'][0][0]}/3295 | {selected['validation']['confusion_matrix_true_rows_predicted_columns'][1][1]}/125 | {selected['validation']['transient_recall']:.2%} | {selected['validation']['normal_false_positive_rate']:.2%} |
| 测试 | {test['confusion_matrix_true_rows_predicted_columns'][0][0]}/3563 | {test['confusion_matrix_true_rows_predicted_columns'][1][1]}/115 | {test['transient_recall']:.2%} | {test['normal_false_positive_rate']:.2%} |

完整指标见 evaluation.json，预测可按 test_predictions.csv 回查原始窗口。权重 best.pt 与 preprocessing.json 一起使用。模型是 2914 参数的浮点二分类 CNN，实际 GPU 为 {report['gpu_name']}。

这些指标只覆盖现有已标注窗口；事件边界、恢复尾段及 36 V 后段额外扰动在原数据集中被排除，没有被当成正确正常预测。只有三次独立阶跃，标签是波形规则初标，故高指标不能证明真实工况泛化。旧基线曾查看同一测试集，因此这次测试属探索性评估，最终应另采独立实验确认。

本次没有振荡数据、三分类训练、ONNX 导出、量化或板端 NPU 推理。不能将 PC 浮点结果视为 Alnpu 兼容性证明。
'''
    (output / "README.md").write_text(text, encoding="utf-8")
    save_json(output / "artifact_checksums.json", {p.name: file_sha(p) for p in output.iterdir() if p.is_file()})
    print("SELECTED_EVALUATION_COMPLETE", json.dumps(report, ensure_ascii=False), flush=True)


if __name__ == "__main__":
    main()
