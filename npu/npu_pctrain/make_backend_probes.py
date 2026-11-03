#!/usr/bin/env python3
"""Build strict-Alnpu assignment probes from the local official quantized graph.

Diagnostic graphs only, not trained DCDC classifiers. The existing diagnostic
application rejects their external bindings before EnqueueWorkload.
"""
import copy
import hashlib
import io
import json
from pathlib import Path
import sys
import tarfile

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parents[2]
sys.path.insert(0, str(PROJECT / "tmp/npu_onnx_python_deps"))
import numpy as np
import onnx
import onnxruntime as ort
from onnx import TensorProto, helper, numpy_helper


def official_prefix(source, count, height, width, integer_input, integer_output):
    nodes = [copy.deepcopy(n) for n in source.graph.node[:count]]
    first_quantized = nodes[0].output[0]
    if integer_input:
        nodes = nodes[1:]
        for n in nodes:
            for k, name in enumerate(n.input):
                if name == first_quantized:
                    n.input[k] = "input"
    else:
        nodes[0].input[0] = "input"
    nodes[-1].output[0] = "logits"
    used = {name for node in nodes for name in node.input}
    weights = [copy.deepcopy(t) for t in source.graph.initializer if t.name in used]
    graph = helper.make_graph(nodes, "official_pattern_backend_probe",
                              [helper.make_tensor_value_info("input", TensorProto.UINT8 if integer_input else TensorProto.FLOAT,
                                                              [1, 3, height, width])],
                              [helper.make_tensor_value_info("logits", TensorProto.UINT8 if integer_output else TensorProto.FLOAT,
                                                              None)], weights)
    return helper.make_model(graph, opset_imports=[helper.make_opsetid("", 14)], ir_version=7)


def replace_initializer(model, name, value):
    for k, tensor in enumerate(model.graph.initializer):
        if tensor.name == name:
            model.graph.initializer[k].CopyFrom(numpy_helper.from_array(value, name))
            return
    raise ValueError("missing initializer " + name)


def alter_first_convolution(model, channels_in, channels_out, kh, kw):
    conv = next(n for n in model.graph.node if n.op_type == "Conv")
    weight_dq = next(n for n in model.graph.node if n.output[0] == conv.input[1])
    bias_dq = next(n for n in model.graph.node if n.output[0] == conv.input[2])
    initializers = {t.name: numpy_helper.to_array(t) for t in model.graph.initializer}
    zero_point = int(initializers[weight_dq.input[2]].reshape(-1)[0])
    replace_initializer(model, weight_dq.input[0], np.full((channels_out, channels_in, kh, kw), zero_point, dtype=np.uint8))
    replace_initializer(model, bias_dq.input[0], np.zeros(channels_out, dtype=np.int32))
    for a in conv.attribute:
        if a.name == "kernel_shape":
            a.CopyFrom(helper.make_attribute("kernel_shape", [kh, kw]))
        elif a.name == "pads":
            a.CopyFrom(helper.make_attribute("pads", [kh // 2, kw // 2] * 2))
    model.graph.input[0].type.tensor_type.shape.dim[1].dim_value = channels_in
    return model


def pool_chain(source):
    model = official_prefix(source, 12, 16, 16, True, True)
    # The source prefix already has Conv/Relu/MaxPool and a quantized output.
    qscale, qzero = model.graph.node[-1].input[1:3]
    for k in range(2, 5):
        old = f"pool{k-1}_q"
        model.graph.node[-1].output[0] = old
        model.graph.node.extend([
            helper.make_node("DequantizeLinear", [old, qscale, qzero], [f"pool{k}_in"]),
            helper.make_node("MaxPool", [f"pool{k}_in"], [f"pool{k}_float"],
                             kernel_shape=[2, 2], strides=[2, 2], pads=[0, 0, 0, 0], ceil_mode=0),
            helper.make_node("QuantizeLinear", [f"pool{k}_float", qscale, qzero], ["logits"])])
    return model


RUNNER = r'''#!/bin/sh
# Strict backend assignment/load probes; external bindings deliberately fail
# the old FLOAT classifier guard, so EnqueueWorkload must never be reached.
set -eu
base=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
runtime=${1:-/tmp/dcdc_npu}
app="$runtime/bin/dcdc_npu_infer"
if [ "$(uname -m)" != aarch64 ]; then echo 'ERROR: run on the board.' >&2; exit 1; fi
if [ ! -x "$app" ]; then echo 'ERROR: extract diagnostic board package first.' >&2; exit 1; fi
export LD_LIBRARY_PATH="$runtime/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
logs="$base/logs_$(date +%Y%m%d_%H%M%S)_$$"
mkdir "$logs"
printf 'case\tassignment\tload\texit\tlast_stage\n' > "$logs/results.tsv"
ulimit -c 0
while read -r name; do
    [ -n "$name" ] || continue
    log="$logs/$name.log"
    if "$app" --model "$base/models/$name.onnx" \
        --input "$runtime/golden_vectors/class0_row0.input_f32.bin" \
        --graph "$logs/$name.dot" --profile "$logs/$name.profile.json" > "$log" 2>&1; then code=0; else code=$?; fi
    assignment=FAILED
    load=NOT_REACHED
    if grep -q '^STAGE=OPTIMIZE_OK$' "$log"; then assignment=ALNPU_ASSIGNMENT_OK; fi
    if grep -q '^STAGE=LOAD_NETWORK_OK$' "$log"; then load=LOADED; fi
    if grep -q '^STAGE=ENQUEUE_BEGIN$' "$log"; then
        echo "ERROR: unexpected enqueue for $name; stop and preserve $logs" >&2
        exit 3
    fi
    stage=$(grep '^STAGE=' "$log" | tail -n 1)
    printf '%s\t%s\t%s\t%s\t%s\n' "$name" "$assignment" "$load" "$code" "$stage" >> "$logs/results.tsv"
    printf 'CASE=%s RESULT=%s LOAD=%s EXIT=%s\n' "$name" "$assignment" "$load" "$code"
done < "$base/cases.txt"
echo "BACKEND_PROBES_FINISHED logs=$logs"
cat "$logs/results.tsv"
echo 'Exit 1 after LOAD_NETWORK_OK may be the intentional classifier binding guard; read assignment/load columns.'
'''


def main():
    output = PROJECT / "output/npu_backend_probes_20261026"
    if output.exists():
        raise ValueError("preserve existing output")
    (output / "models").mkdir(parents=True)
    official = onnx.load(PROJECT / "tmp/npu_official_model_inspection/yolo_face_uint8_15.onnx")
    cases = {
        "00_conv3x3_f32_in_f32_out": official_prefix(official, 7, 16, 16, False, False),
        "01_conv3x3_u8_in_u8_out": official_prefix(official, 6, 16, 16, True, True),
        "02_conv3x3_f32_in_u8_out": official_prefix(official, 6, 16, 16, False, True),
        "03_conv3x3_u8_in_f32_out": official_prefix(official, 7, 16, 16, True, False),
        "04_conv_relu_u8": official_prefix(official, 9, 16, 16, True, True),
        "05_conv_relu_maxpool_u8": official_prefix(official, 12, 16, 16, True, True),
        "06_two_conv_blocks_u8": official_prefix(official, 17, 16, 16, True, True),
        "07_rectangular_conv1x5_u8": alter_first_convolution(official_prefix(official, 6, 1, 256, True, True), 3, 16, 1, 5),
        "08_head_conv1x1_two_outputs_u8": alter_first_convolution(official_prefix(official, 6, 1, 1, True, True), 16, 2, 1, 1),
        "09_four_square_maxpools_u8": pool_chain(official),
        "10_conv3x3_spatial32_u8": official_prefix(official, 6, 32, 32, True, True),
        "11_conv3x3_spatial64_u8": official_prefix(official, 6, 64, 64, True, True)}
    opts = ort.SessionOptions()
    opts.intra_op_num_threads = 1
    opts.inter_op_num_threads = 1
    metadata = {}
    for name, graph in cases.items():
        graph = onnx.shape_inference.infer_shapes(graph, strict_mode=True)
        onnx.checker.check_model(graph, full_check=True)
        input_info = graph.graph.input[0].type.tensor_type
        output_info = graph.graph.output[0].type.tensor_type
        input_shape = [d.dim_value for d in input_info.shape.dim]
        output_shape = [d.dim_value for d in output_info.shape.dim]
        # This guarantees the existing diagnostic app rejects bindings before
        # its input-copy/EnqueueWorkload path, even if assignment/load succeed.
        assert input_info.elem_type != TensorProto.FLOAT or input_shape != [1, 3, 1, 256] or output_shape != [1, 2]
        path = output / f"models/{name}.onnx"
        onnx.save(graph, path)
        session = ort.InferenceSession(str(path), opts, providers=["CPUExecutionProvider"])
        array = np.zeros(input_shape, dtype=np.uint8 if input_info.elem_type == TensorProto.UINT8 else np.float32)
        values = session.run(["logits"], {"input": array})[0]
        assert list(values.shape) == output_shape and np.isfinite(values).all()
        metadata[name] = {"input_type": TensorProto.DataType.Name(input_info.elem_type), "input_shape": input_shape,
                          "output_type": TensorProto.DataType.Name(output_info.elem_type), "output_shape": output_shape,
                          "operators": [n.op_type for n in graph.graph.node], "onnx_checker": "PASS", "ort_synthetic_execution": "PASS"}
    (output / "cases.txt").write_bytes(("\n".join(cases) + "\n").encode("ascii"))
    (output / "run_backend_probes.sh").write_bytes(RUNNER.encode("ascii"))
    (output / "models.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    notes = '''# Alnpu 结构与量化接口隔离测试

原 DCDC CNN 已通过补全 shape 的解析修复，但严格 Alnpu 分配拒绝其 1x5 卷积、Float32 中间激活、AveragePool、非方形池化/步长及部分 Quantize/Dequantize/Reshape。不能用 CPU 回退掩盖这些限制。

本包从原始官方 YOLO 的第一/第二量化卷积块构造小图，测试 3x3 方形卷积、量化 ReLU、2x2 MaxPool、1x1 两通道头、不同空间尺寸，以及浮点或 UINT8 外部接口。全图补全 shape。12 个图均通过 ONNX checker 和 ONNX Runtime 合成输入执行；它们是能力探针，不是训练好的电源工况模型。

无需重新编译。将普通 tar 复制到 TF 卡启动分区，启动板卡后运行：

```sh
cd /tmp
tar -xf /mnt/mmcblk0p1/dcdc_npu_diag_board_20261026.tar
tar -xf /mnt/mmcblk0p1/npu_backend_probes_20261026.tar
sh /tmp/npu_backend_probes/run_backend_probes.sh
```

程序沿用严格 Alnpu 偏好，只检查 Optimize 分配及 LoadNetwork。探针 I/O 与原 FLOAT [1,3,1,256]→[1,2] 分类器合同故意不匹配，原应用的绑定检查会在 EnqueueWorkload 之前停止，因此 EXIT=1 不一定是分配失败；重点看 ALNPU_ASSIGNMENT_OK、LOAD=LOADED 和最后阶段。脚本一旦发现意外 ENQUEUE_BEGIN 会停止。结果不能称为实际 NPU 数值推理通过。

每例日志与优化图保存在 logs_时间_PID；最后汇总结果发回后，根据实际支持组合确定新的网络结构、量化边界及 PS 输入/输出处理，再重新训练。此包不修改原模型、镜像、驱动、PL、PI 或 PWM。
'''
    (output / "README.md").write_text(notes, encoding="utf-8", newline="\n")
    checks = {p.relative_to(output).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in output.rglob("*") if p.is_file()}
    manifest = {"cases": len(cases), "files_sha256": checks, "board_tested": False,
                "onnx_checker_and_ort_synthetic_execution": "PASS", "uses_diagnostic_app_binding_guard_to_stop_before_enqueue": True}
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    archive_path = output / "npu_backend_probes_20261026.tar"
    with tarfile.open(archive_path, "w:") as archive:
        for p in sorted(output.rglob("*")):
            if not p.is_file() or p == archive_path:
                continue
            data = p.read_bytes()
            info = tarfile.TarInfo("npu_backend_probes/" + p.relative_to(output).as_posix())
            info.size = len(data)
            info.mode = 0o755 if p.suffix == ".sh" else 0o644
            archive.addfile(info, io.BytesIO(data))
    with tarfile.open(archive_path, "r:") as archive:
        for name, expected in checks.items():
            assert hashlib.sha256(archive.extractfile("npu_backend_probes/" + name).read()).hexdigest() == expected
        for name in ("cases.txt", "run_backend_probes.sh"):
            assert b"\r" not in archive.extractfile("npu_backend_probes/" + name).read()
    print("BACKEND_PROBE_PACKAGE_PASS", archive_path, "cases", len(cases), "bytes", archive_path.stat().st_size)


if __name__ == "__main__":
    main()
