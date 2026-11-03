#!/usr/bin/env python3
"""Export frozen three-class weights as vendor-pattern UINT8 QDQ prefix."""
import argparse
import copy
import csv
import hashlib
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
from onnx import TensorProto as T, helper as H, numpy_helper as N

from export_quantize import complete_shapes, graph_info
from export_square_npu import make_quantized, quantize
from threeclass_data import load_split, load_raw
from train_threeclass_npu import build_feature_model, metrics


def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def save(p, value):
    p.write_text(json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False)+"\n", encoding="utf-8", newline="\n")


def session(path):
    options = ort.SessionOptions()
    options.intra_op_num_threads = 1
    options.inter_op_num_threads = 1
    return ort.InferenceSession(str(path), sess_options=options, providers=["CPUExecutionProvider"])


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--model", type=Path, required=True)
    p.add_argument("--output", type=Path, required=True)
    args = p.parse_args()
    source, out = args.model.resolve(), args.output.resolve()
    if out.exists():
        raise ValueError("use a new output")
    for name, expected in json.loads((source/"artifact_checksums.json").read_text()).items():
        if sha(source/name) != expected:
            raise ValueError("training artifact changed: "+name)
    config = json.loads((source/"training_config.json").read_text())
    dataset = Path(config["dataset"])
    for name, expected in config["data_sha256"].items():
        if sha(dataset/name) != expected:
            raise ValueError("dataset identity mismatch: "+name)
    pre = json.loads((source/"preprocessing.json").read_text())
    ck = torch.load(source/"best.pt", map_location="cpu", weights_only=True)
    if ck["preprocessing"] != pre:
        raise ValueError("checkpoint preprocessing mismatch")
    torch.set_num_threads(4)
    model = build_feature_model().eval()
    model.load_state_dict(ck["state_dict"])
    assert not torch.count_nonzero(model[0].weight[3:]) and not torch.count_nonzero(model[0].bias[3:])
    xtrain, ytrain, meta_train = load_split(dataset, "train", pre)
    # Min/max calibration uses ALL and ONLY training windows, including both
    # simulation runs and every load transient. No test-informed range search.
    ranges = [[float("inf"), -float("inf")] for _ in range(7)]
    with torch.no_grad():
        for start in range(0, len(xtrain), 256):
            value = torch.from_numpy(xtrain[start:start+256])
            for k in range(4):
                if k:
                    value = model[k-1](value)
                ranges[k][0] = min(ranges[k][0], float(value.min()))
                ranges[k][1] = max(ranges[k][1], float(value.max()))
    # Additional max reductions preserve the extrema across calibration data.
    for k in range(4, 7):
        ranges[k] = ranges[3].copy()
    full, params = make_quantized(model, ranges)
    nodes = copy.deepcopy(list(full.graph.node)[:11])
    assert nodes[-2].op_type == "MaxPool" and nodes[-1].op_type == "QuantizeLinear"
    nodes[-1].output[0] = "logits"
    used = {name for node in nodes for name in node.input}
    graph = H.make_graph(nodes, "dcdc_threeclass_psmax_uint8",
                         [H.make_tensor_value_info("input", T.UINT8, [1, 3, 16, 16])],
                         [H.make_tensor_value_info("logits", T.UINT8, [1, 16, 8, 8])],
                         [copy.deepcopy(v) for v in full.graph.initializer if v.name in used])
    qmodel = H.make_model(graph, ir_version=7, opset_imports=[H.make_opsetid("", 14)],
                          producer_name="frozen DCDC threeclass v2; UINT8 PTQ; NPU prefix and explicit PS max")
    out.mkdir(parents=True)
    target = out/"condition_threeclass_uint8.onnx"
    onnx.save(qmodel, target)
    complete_shapes(target)
    weights, bias = model[0].weight.detach().numpy(), model[0].bias.detach().numpy()
    floating = H.make_model(H.make_graph([
        H.make_node("Conv", ["input", "weight", "bias"], ["conv"], kernel_shape=[3, 3], pads=[1, 1, 1, 1], strides=[1, 1], dilations=[1, 1], group=1),
        H.make_node("Relu", ["conv"], ["relu"]),
        H.make_node("MaxPool", ["relu"], ["logits"], kernel_shape=[2, 2], strides=[2, 2], pads=[0, 0, 0, 0], ceil_mode=0)],
        "dcdc_threeclass_fp32", [H.make_tensor_value_info("input", T.FLOAT, [1, 3, 16, 16])],
        [H.make_tensor_value_info("logits", T.FLOAT, [1, 16, 8, 8])], [N.from_array(weights, "weight"), N.from_array(bias, "bias")]),
        ir_version=7, opset_imports=[H.make_opsetid("", 14)])
    onnx.save(floating, out/"condition_threeclass_fp32.onnx")
    complete_shapes(out/"condition_threeclass_fp32.onnx")
    qs = session(target)
    fs = session(out/"condition_threeclass_fp32.onnx")
    ins, inz = params[0]
    outs, outz = params[3]
    contract = {"input": {"dtype":"uint8", "shape":[1,3,16,16], "scale":float(ins), "zero_point":int(inz)},
                "npu_output": {"dtype":"uint8", "shape":[1,16,8,8], "scale":float(outs), "zero_point":int(outz)},
                "class_channels":[0,1,2], "class_order":["normal","load_transient","oscillation"],
                "npu_operations":["Conv3x3","Relu","MaxPool2x2_stride2"],
                "ps_postprocess":"max of 64 contiguous NCHW U8 values per channel; dequantize first 3; first-index argmax",
                "quantize":"clip(round_to_nearest_even(float32(value)/float32(scale))+zero_point,0,255)",
                "physical_input_preprocessing":"past-relative context then frozen v2 train mean/std; no refitting on board",
                "model_sha256":sha(target), "checkpoint_sha256":sha(source/"best.pt"), "board_status":"NOT_RUN"}
    save(out/"model_contract.json", contract)
    shutil.copyfile(source/"preprocessing.json", out/"preprocessing.json")
    (out/"quant_params.txt").write_text(f"{float(ins):.17g} {int(inz)} {float(outs):.17g} {int(outz)}\n", encoding="ascii", newline="\n")
    report = {"calibration_split":"train_only", "calibration_windows":len(xtrain),
              "calibration_class_counts":np.bincount(ytrain,minlength=3).tolist(), "ranges":ranges[:4],
              "method":"full training min/max, per-tensor asymmetric U8 weights/activations, int32 bias; official QDQ ordering",
              "quantized_graph":graph_info(target), "fp32_graph":graph_info(out/"condition_threeclass_fp32.onnx"),
              "frozen_checkpoint_sha256":sha(source/"best.pt"), "evaluation":{}, "board_status":"NOT_RUN",
              "limitations":["oscillation measured on two training simulation runs only", "reused normal/transient validation/test", "no physical-board validation yet"]}
    vectors = out/"golden_vectors"
    vectors.mkdir()
    cases, vector_metadata = [], []
    for split in ("train","validation","test"):
        x,y,meta = (xtrain,ytrain,meta_train) if split=="train" else load_split(dataset,split,pre)
        physical_part = load_raw(dataset, split)
        xq = quantize(x,ins,inz)
        raw = np.concatenate([qs.run(["logits"],{"input":v[None]})[0] for v in xq])
        reduced = raw.max((2,3))
        scores = (reduced[:,:3].astype(np.float32)-np.float32(outz))*np.float32(outs)
        with torch.no_grad():
            native = np.concatenate([model(torch.from_numpy(x[k:k+256])).amax((2,3))[:,:3].numpy() for k in range(0,len(x),256)])
        qpred, fpred = scores.argmax(1), native.argmax(1)
        info = {"windows":len(y), "fp32":metrics(y,fpred), "uint8":metrics(y,qpred),
                "fp32_uint8_class_disagreements":int((qpred!=fpred).sum()),
                "max_abs_score_error":float(abs(scores-native).max()),
                "input_clipped_values":int(((x/ins+np.float32(inz)<-.5)|(x/ins+np.float32(inz)>255.5)).sum())}
        report["evaluation"][split] = info
        with (out/(split+"_predictions.csv")).open("x",encoding="utf-8",newline="") as stream:
            writer=csv.writer(stream);writer.writerow(["run_id","start_sample","true_class","fp32_class","uint8_class","score0","score1","score2"])
            for k in range(len(y)): writer.writerow([str(meta["run_id"][k]),int(meta["start_sample"][k]),int(y[k]),int(fpred[k]),int(qpred[k]),*scores[k].tolist()])
        # Include representative classes, both simulation runs, the lowest
        # margin window of each measured class and every conversion mismatch.
        picks=set(np.flatnonzero(qpred!=y).tolist())
        for run in np.unique(meta["run_id"]):
            for c in range(3):
                candidates=np.flatnonzero((meta["run_id"]==run)&(y==c))
                if len(candidates):
                    for idx in (0,len(candidates)//2,len(candidates)-1): picks.add(int(candidates[idx]))
        ordered=np.sort(native,axis=1); margins=ordered[:,-1]-ordered[:,-2]
        for c in range(3):
            candidates=np.flatnonzero(y==c)
            if len(candidates):picks.add(int(candidates[margins[candidates].argmin()]))
        for k in sorted(picks):
            name=f"{split}_c{int(y[k])}_row{k}"
            x[k].astype("<f4").tofile(vectors/(name+".input_f32.bin"))
            xq[k].tofile(vectors/(name+".input_u8.bin"))
            raw[k].tofile(vectors/(name+".features_u8.bin"))
            physical_part["X"][k].astype("<f4").tofile(vectors/(name+".physical_f32.bin"))
            physical_part["baseline"][k].astype("<f8").tofile(vectors/(name+".baseline_f64.bin"))
            cases.append(f"{name} {int(qpred[k])} {split} {int(y[k])}")
            float_out=fs.run(["logits"],{"input":x[k:k+1]})[0].max((2,3))[:,:3][0]
            assert np.allclose(float_out,native[k],atol=2e-5,rtol=2e-5)
            vector_metadata.append({"name":name,"class_id":int(y[k]),"cpu_quantized_class":int(qpred[k]),
                                    "run_id":str(meta["run_id"][k]),"start_sample":int(meta["start_sample"][k]),
                                    "split":split,"class_maxima_u8":reduced[k,:3].tolist(),"scores":scores[k].tolist(),"fp32_scores":native[k].tolist()})
        print("THREECLASS_QUANT",split,"correct",int((qpred==y).sum()),"of",len(y),"fp32_disagreements",info["fp32_uint8_class_disagreements"],flush=True)
    save(out/"conversion_report.json",report)
    save(vectors/"vectors.json",vector_metadata)
    (vectors/"cases.txt").write_text("\n".join(cases)+"\n",encoding="ascii",newline="\n")
    (vectors/"case_count.txt").write_text(str(len(cases))+"\n",encoding="ascii")
    for name in (Path(__file__).name,"export_square_npu.py","export_quantize.py","train_threeclass_npu.py","threeclass_data.py","causal_features.py"):
        shutil.copyfile(HERE/name,out/name)
    save(out/"artifact_checksums.json",{q.relative_to(out).as_posix():sha(q) for q in sorted(out.rglob("*")) if q.is_file()})
    print("THREECLASS_UINT8_EXPORT_COMPLETE",out,"goldens",len(cases),flush=True)


if __name__=="__main__":
    main()
