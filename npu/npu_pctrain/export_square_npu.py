#!/usr/bin/env python3
"""PTQ the square model using the board-accepted official QDQ block pattern."""
import csv
import json
from pathlib import Path
import shutil
import sys

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parents[2]
sys.path.insert(0, str(PROJECT / "tmp/npu_onnx_python_deps"))
import numpy as np
import onnx
import onnxruntime as ort
import torch
from onnx import TensorProto, helper, numpy_helper

from causal_features import baselines_for_part
from export_quantize import calibration_indices, complete_shapes, graph_info, run_ort
from train_condition import classification_metrics, file_sha, load_dataset, save_json
from train_square_npu import build_square_model, square_inputs


def qparams(low, high):
    lo, hi = min(float(low), 0.), max(float(high), 0.)
    scale = np.float32(max((hi - lo) / 255., 1e-8))
    zero = np.uint8(np.clip(np.rint(-lo / float(scale)), 0, 255))
    return scale, zero


def quantize(values, scale, zero):
    return np.clip(np.rint(values.astype(np.float32) / scale) + np.float32(zero), 0, 255).astype(np.uint8)


def make_quantized(model, ranges):
    params = [qparams(lo, hi) for lo, hi in ranges]
    weights = model[0].weight.detach().numpy()
    bias = model[0].bias.detach().numpy()
    ws, wz = qparams(weights.min(), weights.max())
    qw = quantize(weights, ws, wz)
    bs = np.float32(params[0][0] * ws)
    qb = np.rint(bias / bs).astype(np.int32)
    initializers, nodes = [], []
    for index, (scale, zero) in enumerate(params):
        initializers.extend([numpy_helper.from_array(np.array(scale, dtype=np.float32), f"s{index}"),
                             numpy_helper.from_array(np.array(zero, dtype=np.uint8), f"z{index}")])
    # Match the vendor example's one-element per-tensor weight/bias params.
    for name, array in [("qw", qw), ("ws", np.array([ws], np.float32)), ("wz", np.array([wz], np.uint8)),
                        ("qb", qb), ("bs", np.array([bs], np.float32)), ("bz", np.array([0], np.int32))]:
        initializers.append(numpy_helper.from_array(array, name))
    nodes.extend([
        helper.make_node("DequantizeLinear", ["input", "s0", "z0"], ["input_dq"]),
        helper.make_node("DequantizeLinear", ["qw", "ws", "wz"], ["weight_dq"]),
        helper.make_node("DequantizeLinear", ["qb", "bs", "bz"], ["bias_dq"]),
        helper.make_node("Conv", ["input_dq", "weight_dq", "bias_dq"], ["conv_f"],
                         kernel_shape=[3, 3], pads=[1, 1, 1, 1], strides=[1, 1], dilations=[1, 1], group=1),
        helper.make_node("QuantizeLinear", ["conv_f", "s1", "z1"], ["conv_q"]),
        helper.make_node("DequantizeLinear", ["conv_q", "s1", "z1"], ["relu_in"]),
        helper.make_node("Relu", ["relu_in"], ["relu_f"]),
        helper.make_node("QuantizeLinear", ["relu_f", "s2", "z2"], ["relu_q"])])
    previous, previous_param = "relu_q", 2
    for layer in range(4):
        param = layer + 3
        name = f"pool{layer+1}"
        terminal = "logits" if layer == 3 else name + "_q"
        nodes.extend([
            helper.make_node("DequantizeLinear", [previous, f"s{previous_param}", f"z{previous_param}"], [name + "_in"]),
            helper.make_node("MaxPool", [name + "_in"], [name + "_f"],
                             kernel_shape=[2, 2], strides=[2, 2], pads=[0, 0, 0, 0], ceil_mode=0),
            helper.make_node("QuantizeLinear", [name + "_f", f"s{param}", f"z{param}"], [terminal])])
        previous, previous_param = terminal, param
    graph = helper.make_graph(nodes, "dcdc_square_uint8",
                              [helper.make_tensor_value_info("input", TensorProto.UINT8, [1, 3, 16, 16])],
                              [helper.make_tensor_value_info("logits", TensorProto.UINT8, [1, 16, 1, 1])], initializers)
    model_proto = helper.make_model(graph, ir_version=7, opset_imports=[helper.make_opsetid("", 14)],
                                    producer_name="DCDC square maxpool classifier; official-pattern UINT8 QDQ")
    return model_proto, params


def main():
    source = PROJECT / "output/npu_train_20261026_square_v1"
    dataset = PROJECT / "output/npu_dataset_20261026"
    output = PROJECT / "output/npu_square_onnx_20261026_v1"
    if output.exists():
        raise ValueError("preserve previous conversion")
    for name, expected in json.loads((source / "artifact_checksums.json").read_text()).items():
        if file_sha(source / name) != expected:
            raise ValueError("training artifact changed: " + name)
    parts, manifest = load_dataset(dataset)
    pre = json.loads((source / "preprocessing.json").read_text())
    checkpoint = torch.load(source / "best.pt", map_location="cpu", weights_only=True)
    model = build_square_model().eval()
    model.load_state_dict(checkpoint["state_dict"])
    assert not torch.count_nonzero(model[0].weight[2:]) and not torch.count_nonzero(model[0].bias[2:])
    torch.set_num_threads(4)
    output.mkdir(parents=True)
    fp32 = output / "square_fp32.onnx"
    torch.onnx.export(model, torch.zeros(1, 3, 16, 16), str(fp32), input_names=["input"], output_names=["logits"],
                      opset_version=14, dynamo=False, external_data=False)
    complete_shapes(fp32)
    xtrain = square_inputs(parts["train"], pre, dataset, manifest)
    indices = calibration_indices(parts["train"])
    ranges = [[float("inf"), -float("inf")] for _ in range(7)]
    with torch.no_grad():
        for begin in range(0, len(indices), 128):
            value = torch.from_numpy(xtrain[indices[begin:begin+128]])
            for index in range(7):
                if index:
                    value = model[index-1](value)
                ranges[index][0] = min(ranges[index][0], float(value.min()))
                ranges[index][1] = max(ranges[index][1], float(value.max()))
    qgraph, params = make_quantized(model, ranges)
    quantized = output / "condition_square_uint8.onnx"
    onnx.save(qgraph, quantized)
    complete_shapes(quantized)
    # Same operation ordering, square attributes and external tensor types as
    # accepted board probe 09; actual trained numeric execution is still pending.
    probe = onnx.load(PROJECT / "output/npu_backend_probes_20261026/models/09_four_square_maxpools_u8.onnx")
    qmodel = onnx.load(quantized)
    assert [n.op_type for n in probe.graph.node] == [n.op_type for n in qmodel.graph.node]
    for pn, qn in zip(probe.graph.node, qmodel.graph.node):
        if pn.op_type in ("Conv", "Relu", "MaxPool"):
            assert [a.SerializeToString() for a in pn.attribute] == [a.SerializeToString() for a in qn.attribute]
    contract = {"input": {"dtype": "uint8", "shape": [1, 3, 16, 16], "scale": float(params[0][0]), "zero_point": int(params[0][1])},
                "output": {"dtype": "uint8", "shape": [1, 16, 1, 1], "scale": float(params[-1][0]), "zero_point": int(params[-1][1])},
                "class_channels": [0, 1], "unused_channels": list(range(2, 16)),
                "quantize": "clip(round_to_nearest_even(float32(x)/float32(scale))+zero_point,0,255)",
                "dequantize": "float32(q-zero_point)*float32(scale)",
                "preprocessing": "physical 256x3 -> past-relative -> train mean/std -> channel-major 3x16x16 -> UINT8",
                "board_status": "operator/shape pattern assigned+loaded in probe; trained numeric inference pending"}
    save_json(output / "model_contract.json", contract)
    save_json(output / "preprocessing.json", pre)
    with (output / "calibration_windows.csv").open("x", newline="", encoding="utf-8") as stream:
        writer = csv.writer(stream)
        writer.writerow(["split", "train_npz_index", "run_id", "start_sample", "class_id"])
        for k in indices:
            writer.writerow(["train", int(k), str(parts["train"]["run_id"][k]), int(parts["train"]["start_sample"][k]), int(parts["train"]["y"][k])])
    report = {"weight_sha256": file_sha(source / "best.pt"), "graphs": {"fp32": graph_info(fp32), "uint8": graph_info(quantized)},
              "calibration_split": "train", "calibration_windows": len(indices), "activation_ranges": ranges,
              "same_operator_attribute_pattern_as_accepted_probe09": True, "evaluation": {},
              "limitations": manifest["limitations"], "board_numeric_inference": "NOT_RUN"}
    options = ort.SessionOptions()
    options.intra_op_num_threads = 4
    options.inter_op_num_threads = 1
    session = ort.InferenceSession(str(quantized), options, providers=["CPUExecutionProvider"])
    for split in ("validation", "test"):
        x = square_inputs(parts[split], pre, dataset, manifest)
        xin = quantize(x, *params[0])
        raw = np.concatenate([session.run(["logits"], {"input": v[None]})[0] for v in xin])
        scores = (raw.astype(np.int32) - int(params[-1][1])).astype(np.float32) * params[-1][0]
        scores = scores[:, :2, 0, 0]
        with torch.no_grad():
            native = np.concatenate([model(torch.from_numpy(x[k:k+128]))[:, :2, 0, 0].numpy() for k in range(0, len(x), 128)])
        floating = run_ort(fp32, x)[:, :2, 0, 0]
        assert np.allclose(native, floating, rtol=2e-4, atol=2e-4)
        report["evaluation"][split] = {"fp32": classification_metrics(parts[split]["y"], native.argmax(1)),
                                        "uint8": classification_metrics(parts[split]["y"], scores.argmax(1)),
                                        "classification_disagreements": int(np.count_nonzero(scores.argmax(1) != native.argmax(1))),
                                        "max_abs_score_error": float(np.max(np.abs(scores-native)))}
        print("SQUARE_CONVERSION", split, json.dumps(report["evaluation"][split]), flush=True)
        if split == "test":
            directory = output / "golden_vectors"
            directory.mkdir()
            base = baselines_for_part(parts[split], dataset, manifest, 2.)
            vectors, lines = [], []
            for c in (0, 1):
                candidates = np.flatnonzero(parts[split]["y"] == c)
                for position in (0, len(candidates)//2):
                    k = int(candidates[position])
                    name = f"class{c}_row{k}"
                    x[k].astype("<f4").tofile(directory / f"{name}.input_f32.bin")
                    xin[k].tofile(directory / f"{name}.input_u8.bin")
                    parts[split]["X"][k].astype("<f4").tofile(directory / f"{name}.physical_f32.bin")
                    vectors.append({"name": name, "class_id": c, "run_id": str(parts[split]["run_id"][k]),
                                    "start_sample": int(parts[split]["start_sample"][k]), "history_baseline": base[k].tolist(),
                                    "scores": scores[k].tolist(), "fp32_scores": native[k].tolist(), "raw_output_u8": raw[k].reshape(-1).tolist()})
                    lines.append(f"{name} {c} {scores[k,0]:.10g} {scores[k,1]:.10g}")
            save_json(directory / "vectors.json", vectors)
            (directory / "references.txt").write_bytes(("\n".join(lines)+"\n").encode("ascii"))
    save_json(output / "conversion_report.json", report)
    for name in ("train_square_npu.py", "export_square_npu.py", "train_condition.py", "causal_features.py"):
        shutil.copyfile(HERE / name, output / name)
    save_json(output / "artifact_checksums.json", {p.relative_to(output).as_posix(): file_sha(p) for p in output.rglob("*") if p.is_file()})
    print("SQUARE_UINT8_EXPORT_COMPLETE", output, flush=True)


if __name__ == "__main__":
    main()
