#!/usr/bin/env python3
"""Export the frozen CNN and calibrate UINT8 QDQ using TRAIN windows only.

Produces PC-verified candidate models, not proof of Alnpu compatibility.
Dependencies may live in the workspace's separate npu_onnx_python_deps folder.
"""
import argparse
from collections import Counter
from contextlib import contextmanager
import csv
import importlib.metadata
import json
from pathlib import Path
import shutil
import sys
import tempfile
import uuid

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
DEPS = ROOT / "tmp/npu_onnx_python_deps"
if DEPS.is_dir():
    sys.path.insert(0, str(DEPS))

import numpy as np
import onnx
import onnxruntime as ort
import torch
from onnxruntime.quantization import (CalibrationDataReader, CalibrationMethod,
                                     QuantFormat, QuantType, quantize_static)
from onnxruntime.quantization.shape_inference import quant_pre_process

from causal_features import baselines_for_part
from train_condition import (build_model, classification_metrics, file_sha,
                             inputs_for_part, load_dataset, save_json)


@contextmanager
def workspace_temporaries(parent):
    """Use ordinary workspace directories for ORT's transient model files.

    Windows restricted tokens cannot reopen owner-only Python tempfile dirs.
    Restore the process-local patch when quantization completes.
    """
    original = tempfile.mkdtemp
    def mkdir(suffix=None, prefix=None, dir=None):
        base = Path(dir) if dir is not None else parent
        path = base / ((prefix or "tmp") + uuid.uuid4().hex + (suffix or ""))
        path.mkdir(mode=0o777)
        return str(path)
    tempfile.mkdtemp = mkdir
    try:
        yield
    finally:
        tempfile.mkdtemp = original


def graph_info(path):
    model = onnx.load(path)
    onnx.checker.check_model(model, full_check=True)
    def binding(value):
        tensor = value.type.tensor_type
        return {"name": value.name, "dtype": onnx.TensorProto.DataType.Name(tensor.elem_type),
                "shape": [d.dim_value if d.HasField("dim_value") else d.dim_param for d in tensor.shape.dim]}
    return {"ir_version": model.ir_version,
            "opsets": {p.domain: p.version for p in model.opset_import},
            "operators": dict(Counter(n.op_type for n in model.graph.node)),
            "initializer_types": dict(Counter(onnx.TensorProto.DataType.Name(p.data_type) for p in model.graph.initializer)),
            "value_info_count": len(model.graph.value_info),
            "inputs": [binding(v) for v in model.graph.input], "outputs": [binding(v) for v in model.graph.output],
            "bytes": Path(path).stat().st_size, "sha256": file_sha(path)}


def complete_shapes(path):
    """The vendor parser crashes on these graphs without intermediate shapes.

    Preserve all nodes, initializers and external I/O; only add inferred
    value_info. Board probes on 2026-10-26 parsed the completed versions.
    """
    before = onnx.load(path)
    after = onnx.shape_inference.infer_shapes(before, strict_mode=True)
    for field in ("node", "initializer", "input", "output"):
        if [x.SerializeToString() for x in getattr(before.graph, field)] != [x.SerializeToString() for x in getattr(after.graph, field)]:
            raise ValueError(f"shape completion unexpectedly changed graph {field}")
    described = {v.name for v in list(after.graph.input) + list(after.graph.output) + list(after.graph.value_info)}
    missing = {name for node in after.graph.node for name in node.output if name} - described
    if missing:
        raise ValueError(f"shape completion omitted intermediate tensors: {sorted(missing)}")
    onnx.checker.check_model(after, full_check=True)
    onnx.save(after, path)


class CalibrationReader(CalibrationDataReader):
    def __init__(self, inputs, indices):
        self.inputs, self.indices, self.position = inputs, indices, 0

    def get_next(self):
        if self.position >= len(self.indices):
            return None
        index = self.indices[self.position]
        self.position += 1
        return {"input": self.inputs[index:index + 1]}

    def rewind(self):
        self.position = 0


def run_ort(path, inputs):
    options = ort.SessionOptions()
    options.intra_op_num_threads = 4
    options.inter_op_num_threads = 1
    session = ort.InferenceSession(str(path), options, providers=["CPUExecutionProvider"])
    # Static batch=1 matches the intended board interface.
    return np.concatenate([session.run(["logits"], {"input": x[None]})[0] for x in inputs])


def calibration_indices(part):
    """Uniformly cover every normal run, and all available step windows."""
    selected = []
    for run in np.unique(part["run_id"]):
        normal = np.flatnonzero((part["run_id"] == run) & (part["y"] == 0))
        if len(normal):
            selected.extend(normal[np.linspace(0, len(normal) - 1, min(128, len(normal)), dtype=np.int64)].tolist())
    selected.extend(np.flatnonzero(part["y"] == 1).tolist())
    return np.array(sorted(set(selected)), dtype=np.int64)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model-dir", type=Path, default=ROOT / "output/npu_train_20261026_selected_context_v1")
    parser.add_argument("--dataset", type=Path, default=ROOT / "output/npu_dataset_20261026")
    parser.add_argument("--output", type=Path, default=ROOT / "output/npu_onnx_20261026_v2_shapes")
    args = parser.parse_args()
    source, dataset, output = args.model_dir.resolve(), args.dataset.resolve(), args.output.resolve()
    if output.exists():
        raise ValueError("output exists; choose a new conversion directory")
    for name, expected in json.loads((source / "artifact_checksums.json").read_text()).items():
        if file_sha(source / name) != expected:
            raise ValueError(f"selected artifact changed: {name}")
    for name in ("train_condition.py", "causal_features.py"):
        if file_sha(source / name) != file_sha(HERE / name):
            raise ValueError("model implementation differs from frozen training snapshot")
    parts, manifest = load_dataset(dataset)
    preprocessing = json.loads((source / "preprocessing.json").read_text())
    checkpoint = torch.load(source / "best.pt", map_location="cpu", weights_only=True)
    if checkpoint["preprocessing"] != preprocessing:
        raise ValueError("preprocessing differs from saved checkpoint")
    output.mkdir(parents=True)
    work = output / "work"
    work.mkdir()
    torch.set_num_threads(4)
    model = build_model(torch).eval()
    model.load_state_dict(checkpoint["state_dict"])
    for name in ("preprocessing.json", "best.pt", "train_condition.py", "causal_features.py"):
        shutil.copyfile(source / name, output / name)
    shutil.copyfile(Path(__file__), output / "export_quantize.py")
    fp32 = output / "condition_fp32.onnx"
    # The local vendor reference is opset 14, IR 7, FLOAT external I/O.
    # Use the legacy exporter explicitly to target that older parser format.
    torch.onnx.export(model, torch.zeros((1, 3, 1, 256), dtype=torch.float32), str(fp32),
                      input_names=["input"], output_names=["logits"], opset_version=14,
                      dynamo=False, external_data=False)
    complete_shapes(fp32)
    fp_info = graph_info(fp32)
    if fp_info["inputs"] != [{"name": "input", "dtype": "FLOAT", "shape": [1, 3, 1, 256]}]:
        raise ValueError("unexpected exported input binding")
    train_inputs = inputs_for_part(parts["train"], preprocessing, dataset, manifest)
    indices = calibration_indices(parts["train"])
    with (output / "calibration_windows.csv").open("x", newline="", encoding="utf-8") as stream:
        writer = csv.writer(stream)
        writer.writerow(["split", "row_in_train_npz", "run_id", "start_sample", "class_id"])
        for index in indices:
            part = parts["train"]
            writer.writerow(["train", int(index), str(part["run_id"][index]), int(part["start_sample"][index]), int(part["y"][index])])
    quantized = output / "condition_uint8_qdq.onnx"
    with workspace_temporaries(work):
        preprocessed = work / "condition_inferred.onnx"
        quant_pre_process(str(fp32), str(preprocessed), skip_optimization=True, skip_symbolic_shape=True)
        quantize_static(str(preprocessed), str(quantized), CalibrationReader(train_inputs, indices),
                        quant_format=QuantFormat.QDQ, activation_type=QuantType.QUInt8,
                        weight_type=QuantType.QUInt8, per_channel=False,
                        calibrate_method=CalibrationMethod.MinMax,
                        op_types_to_quantize=["Conv", "Gemm"],
                        extra_options={"ActivationSymmetric": False, "WeightSymmetric": False})
    # QDQ insertion introduces additional intermediate tensors after calibration.
    complete_shapes(quantized)
    q_info = graph_info(quantized)
    if q_info["inputs"] != fp_info["inputs"] or q_info["outputs"] != fp_info["outputs"]:
        raise ValueError("QDQ external bindings unexpectedly changed")
    if "QuantizeLinear" not in q_info["operators"] or "UINT8" not in q_info["initializer_types"]:
        raise ValueError("quantized model lacks expected UINT8 QDQ nodes")
    print("EXPORT_AND_CALIBRATION_PASS", json.dumps({"calibration_train_windows": len(indices), "graphs": {"fp32": fp_info, "qdq": q_info}}), flush=True)
    report = {"source_weight_sha256": file_sha(source / "best.pt"),
              "versions": {"python": sys.version, "torch": torch.__version__, "onnx": onnx.__version__,
                           "onnxruntime": ort.__version__, "numpy": np.__version__},
              "graphs": {"fp32": fp_info, "uint8_qdq": q_info},
              "calibration": {"split": "train", "windows": len(indices), "method": "MinMax",
                              "normal_windows_per_run_max": 128, "step_windows": "all train positives",
                              "activation_type": "uint8", "weight_type": "uint8", "per_channel": False,
                              "validation_or_test_used_for_calibration": False},
              "evaluation": {}, "scope": "ONNX Runtime CPU only; not Arm NN parser or Alnpu hardware proof"}
    for split in ("validation", "test"):
        inputs = inputs_for_part(parts[split], preprocessing, dataset, manifest)
        with torch.no_grad():
            native = np.concatenate([model(torch.from_numpy(inputs[k:k + 128])).numpy() for k in range(0, len(inputs), 128)])
        floating = run_ort(fp32, inputs)
        qdq = run_ort(quantized, inputs)
        if not np.allclose(native, floating, rtol=2e-4, atol=2e-4):
            raise ValueError(f"FP32 export differs from PyTorch logits: {split}")
        original_metrics = classification_metrics(parts[split]["y"], native.argmax(1))
        floating_metrics = classification_metrics(parts[split]["y"], floating.argmax(1))
        qdq_metrics = classification_metrics(parts[split]["y"], qdq.argmax(1))
        report["evaluation"][split] = {
            "windows": len(inputs), "pytorch": original_metrics, "fp32_onnx": floating_metrics,
            "uint8_qdq": qdq_metrics, "max_abs_fp32_logit_error": float(np.max(np.abs(native - floating))),
            "max_abs_qdq_logit_error": float(np.max(np.abs(native - qdq))),
            "qdq_vs_fp32_class_disagreements": int(np.count_nonzero(qdq.argmax(1) != floating.argmax(1)))}
        with (output / f"{split}_conversion_predictions.csv").open("x", newline="", encoding="utf-8") as stream:
            writer = csv.writer(stream)
            writer.writerow(["run_id", "start_sample", "true_class", "pytorch_class", "fp32_onnx_class", "uint8_qdq_class", "fp32_logit_0", "fp32_logit_1", "qdq_logit_0", "qdq_logit_1"])
            for k in range(len(inputs)):
                writer.writerow([str(parts[split]["run_id"][k]), int(parts[split]["start_sample"][k]), int(parts[split]["y"][k]),
                                 int(native[k].argmax()), int(floating[k].argmax()), int(qdq[k].argmax()),
                                 *floating[k].tolist(), *qdq[k].tolist()])
        print("CONVERSION_EVALUATION", split, json.dumps(report["evaluation"][split]), flush=True)
        if split == "test":
            vectors = output / "golden_vectors"
            vectors.mkdir()
            baselines = baselines_for_part(parts[split], dataset, manifest, preprocessing["feature_transform"]["context_seconds"])
            examples = []
            for label in (0, 1):
                rows = np.flatnonzero(parts[split]["y"] == label)
                for position in (0, len(rows) // 2):
                    index = int(rows[position])
                    name = f"class{label}_row{index}"
                    physical = parts[split]["X"][index]
                    physical.astype("<f4").tofile(vectors / f"{name}.physical_f32.bin")
                    inputs[index].astype("<f4").tofile(vectors / f"{name}.input_f32.bin")
                    examples.append({"name": name, "run_id": str(parts[split]["run_id"][index]),
                                     "start_sample": int(parts[split]["start_sample"][index]),
                                     "history_baseline": baselines[index].tolist(),
                                     "physical_shape": [256, 3], "model_input_shape": [1, 3, 1, 256],
                                     "dtype": "little-endian float32", "class_id": label,
                                     "pytorch_logits": native[index].tolist(), "fp32_onnx_logits": floating[index].tolist(),
                                     "uint8_qdq_logits": qdq[index].tolist()})
            save_json(vectors / "vectors.json", examples)
    qgraph = onnx.load(quantized)
    tensors = {p.name: onnx.numpy_helper.to_array(p) for p in qgraph.graph.initializer}
    first_q = next(n for n in qgraph.graph.node if n.op_type == "QuantizeLinear" and n.input[0] == "input")
    report["input_internal_quantizer"] = {"scale": float(tensors[first_q.input[1]]),
                                           "zero_point": int(tensors[first_q.input[2]]),
                                           "dtype": "uint8", "external_input_remains": "float32; do not quantize it twice"}
    save_json(output / "conversion_report.json", report)
    compatibility = {
        "official_reference": "local demo.zip/sdk/face_detection.tar.gz/inputs/yolo_face_uint8_15.onnx",
        "official_graph": "IR7, opset14, FLOAT external I/O, UINT8 internal QDQ weights/activations",
        "matching_format": True,
        "pending_board_checks": ["Arm NN ONNX parser accepts every node and tensor shape",
                                 "strict Alnpu backend supports Conv/Relu/AveragePool/Flatten/Gemm and height=1 tensors",
                                 "runtime tensor types/scales and input preparation agree with golden vectors",
                                 "no silent CpuAcc/CpuRef fallback; compare outputs and concurrency with FDMA"],
        "armnn_parser_tested": False, "strict_alnpu_tested": False, "board_inference_tested": False}
    save_json(output / "compatibility.json", compatibility)
    shutil.copyfile(HERE / "EXPORT.md", output / "README.md")
    save_json(output / "artifact_checksums.json", {p.relative_to(output).as_posix(): file_sha(p) for p in output.rglob("*") if p.is_file()})
    print("ONNX_CONVERSION_COMPLETE", str(output), flush=True)


if __name__ == "__main__":
    main()
