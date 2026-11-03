#!/usr/bin/env python3
"""Move a prepared oscillation run into a NEW training dataset revision."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import shutil

import numpy as np

from threeclass_data import fit_preprocessing, load_raw


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read_json(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def save_json(path, value):
    with Path(path).open("x", encoding="utf-8") as stream:
        json.dump(value, stream, ensure_ascii=False, indent=2, allow_nan=False)
        stream.write("\n")


def check_bank(root):
    for name, expected in read_json(root / "checksums.json").items():
        if sha(root / name) != expected:
            raise ValueError("bank changed: " + name)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--base", type=Path, required=True)
    p.add_argument("--add", type=Path, required=True)
    p.add_argument("--output", type=Path, required=True)
    args = p.parse_args()
    base, addon, out = args.base.resolve(), args.add.resolve(), args.output.resolve()
    if out.exists():
        raise ValueError("output must be new")
    check_bank(base)
    check_bank(addon)
    old = read_json(base / "manifest.json")
    added = read_json(addon / "manifest.json")
    if old["schema"] != "DCDC_THREECLASS_MIXED_SOURCE_V1" or added["schema"] != "DCDC_FROZEN_MODEL_OSCILLATION_HOLDOUT_V1":
        raise ValueError("unsupported input banks")
    if read_json(base / "validation.json")["status"] != "PASS" or read_json(addon / "validation.json")["status"] != "PASS":
        raise ValueError("input audits must pass")
    run = added["run_id"]
    for summary in old["splits"].values():
        if run in summary["runs"]:
            raise ValueError("run already used in base dataset")
    prior_sources = old.get("source_simulations", [old["source_simulation"]])
    if added["source_csv_sha256"] in {s["csv_sha256"] for s in prior_sources}:
        raise ValueError("duplicate source recording")
    csv_path = addon / added["source_csv_preserved"]
    if sha(csv_path) != added["source_csv_sha256"]:
        raise ValueError("source hash mismatch")
    a = np.loadtxt(csv_path, delimiter=",", skiprows=1)
    time_s, signal = a[:, 0], a[:, 1:]
    if not np.isfinite(a).all() or not np.allclose(np.diff(time_s), 1/25000, rtol=1e-7, atol=1e-12):
        raise ValueError("invalid source timing/values")
    with np.load(addon / "windows" / "oscillation_test.npz", allow_pickle=False) as z:
        extra = {k: z[k] for k in z.files}
    grid = np.arange(0, len(a)-255, 128, dtype=np.int64)
    eligible = (time_s >= 3) & (time_s < 9.9)
    starts = grid[np.all(eligible[grid[:, None]+np.arange(256)], axis=1)]
    assert np.array_equal(extra["start_sample"], starts)
    assert np.array_equal(extra["end_sample"], starts+256)
    assert np.array_equal(extra["X"], signal[starts[:, None]+np.arange(256)].astype(np.float32))
    assert np.all(extra["y"] == 2) and np.all(extra["run_id"] == run)
    assert np.all(extra["source_kind"] == "simulation")
    direct = np.array([signal[max(0, int(s)-50000):s].mean(0) for s in starts])
    assert np.allclose(extra["baseline"], direct, rtol=1e-10, atol=1e-10)
    out.mkdir(parents=True)
    for folder in ("source", "windows", "tools"):
        (out / folder).mkdir()
    train = load_raw(base, "train")
    old_count = len(train["y"])
    for key in ("X", "y", "baseline", "run_id", "start_sample", "end_sample", "source_kind"):
        train[key] = np.concatenate([train[key], extra[key]])
    np.savez_compressed(out / "windows" / "train.npz", **train)
    for split in ("validation", "test"):
        shutil.copyfile(base / "windows" / (split+".npz"), out / "windows" / (split+".npz"))
        assert sha(base / "windows" / (split+".npz")) == sha(out / "windows" / (split+".npz"))
    # Preserve both original CSVs in the new revision, without touching the old.
    sources = copy.deepcopy(prior_sources)
    for src in sources:
        shutil.copyfile(base / src["preserved_path"], out / src["preserved_path"])
        assert sha(out / src["preserved_path"]) == src["csv_sha256"]
    new_source = {"run_id": run, "csv_sha256": added["source_csv_sha256"], "samples": len(a),
                  "source_kind": "PLECS simulation", "original_path": added["source_original_path"],
                  "preserved_path": "source/"+csv_path.name, "assigned_split": "train",
                  "label_interval_original_time_s": [3.0, 9.9],
                  "previous_role": "frozen-model test of threeclass_v1; now training by explicit user request",
                  "held_out_for_new_model": False}
    sources.append(new_source)
    shutil.copyfile(csv_path, out / new_source["preserved_path"])
    assert sha(out / new_source["preserved_path"]) == added["source_csv_sha256"]
    manifest = copy.deepcopy(old)
    manifest["dataset_revision"] = "20261027_threeclass_sim_v2_two_oscillation_training_runs"
    manifest["parent_dataset"] = str(base)
    manifest["parent_manifest_sha256"] = sha(base / "manifest.json")
    manifest["source_simulations"] = sources
    manifest["added_training_source_bank"] = str(addon)
    manifest["source_role_change"] = {"run_id": run, "previous": "test of earlier fixed checkpoint", "current": "train", "independent_test_for_this_revision": False}
    manifest["splits"]["train"] = {"shape": list(train["X"].shape),
                                     "runs": sorted(set(train["run_id"].tolist())),
                                     "class_counts": {str(c): int((train["y"] == c).sum()) for c in range(3)}}
    manifest["split_policy"] = "original physical split and first simulation training assignment preserved; new simulation assigned train only; no random window split"
    manifest["limitations"][0] = "two oscillation simulation training runs; no held-out oscillation validation/test run remains"
    manifest["limitations"] = [s for s in manifest["limitations"] if not s.startswith("existing binary trainer")]
    save_json(out / "manifest.json", manifest)
    pre = fit_preprocessing(out)
    save_json(out / "preprocessing_candidate.json", pre)
    seen = set()
    for split in ("train", "validation", "test"):
        part = load_raw(out, split)
        previous = load_raw(base, split)
        n = len(previous["y"])
        for key in ("X", "y", "baseline", "run_id", "start_sample", "end_sample", "source_kind"):
            assert np.array_equal(part[key][:n], previous[key])
        ids = set(part["run_id"].tolist())
        assert not seen & ids
        seen |= ids
        if split == "train":
            for key in ("X", "y", "baseline", "run_id", "start_sample", "end_sample", "source_kind"):
                assert np.array_equal(part[key][n:], extra[key])
        else:
            assert run not in ids and not (part["y"] == 2).any()
    save_json(out / "validation.json", {"status": "PASS", "run_sets_disjoint": True,
              "parent_windows_preserved": sum(s["shape"][0] for s in old["splits"].values()),
              "new_training_windows_checked": len(starts), "new_source_rows": len(a),
              "all_new_values_labels_and_past_means_checked": True,
              "validation_and_test_npz_byte_identical_to_parent": True,
              "oscillation_training_runs": len(sources), "third_class_validation_available": False,
              "third_class_test_available": False, "former_holdout_is_training_now": True})
    readme = f'''# 三分类训练数据 v2

按用户要求，将 `{run}` 的 {len(starts)} 个窗口加入训练。
训练集共 {len(train['y'])} 个窗口：正常 {pre['training_class_counts'][0]}、负载瞬态 {pre['training_class_counts'][1]}、振荡 {pre['training_class_counts'][2]}。
两组振荡仿真 run 都只分配 train。原实测 validation=3420、test=3678 保持原字节内容，仍没有振荡样本。
新 run 的旧测试记录仅对应 earlier threeclass_v1 冻结模型；对本修订训练的新模型，它已不再是独立测试。

输入物理量窗口、25kHz、256点、步长128、过去2秒的因果均值和三通道顺序均不变。
仅在新训练集重拟合标准化与类别权重，见 preprocessing_candidate.json。禁止沿用旧模型量化参数。
本数据目录没有训练权重。训练结果保存到独立 npu_train_20261027_threeclass_v2。
原数据集、历史模型和历史测试记录保留。每个 run 在此修订内不跨集合。
仿真振荡仍需新的独立 run，以及实测数据验证；重叠窗口不能视作独立实验。
'''
    (out / "README.md").write_text(readme, encoding="utf-8")
    for name in (Path(__file__).name, "threeclass_data.py", "causal_features.py"):
        shutil.copyfile(Path(__file__).with_name(name), out / "tools" / name)
    save_json(out / "checksums.json", {q.relative_to(out).as_posix(): sha(q) for q in sorted(out.rglob("*")) if q.is_file()})
    print("THREECLASS_TRAINING_EXTENSION_PASS", "old_train", old_count, "added", len(starts), "new_train", len(train["y"]), "counts", pre["training_class_counts"], flush=True)


if __name__ == "__main__":
    main()
