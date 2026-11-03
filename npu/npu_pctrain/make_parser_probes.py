#!/usr/bin/env python3
"""Prepare offline board parser probes; do not modify production model files."""
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
from onnx import TensorProto, helper, numpy_helper


def digest(data):
    return hashlib.sha256(data).hexdigest()


def prefix_model(model, count):
    shaped = onnx.shape_inference.infer_shapes(model, strict_mode=True)
    nodes = [copy.deepcopy(n) for n in shaped.graph.node[:count]]
    old_output = nodes[-1].output[0]
    infos = {v.name: v for v in list(shaped.graph.value_info) + list(shaped.graph.output)}
    terminal = copy.deepcopy(infos[old_output])
    terminal.name = "logits"
    nodes[-1].output[0] = "logits"
    used = {name for n in nodes for name in n.input}
    intermediate = {name for n in nodes for name in n.output} - {"logits"}
    graph = helper.make_graph(nodes, f"trained_prefix_{count}",
                              [copy.deepcopy(v) for v in model.graph.input], [terminal],
                              [copy.deepcopy(v) for v in model.graph.initializer if v.name in used],
                              value_info=[copy.deepcopy(v) for v in shaped.graph.value_info if v.name in intermediate])
    return helper.make_model(graph, opset_imports=[helper.make_opsetid("", 14)], ir_version=7,
                             producer_name="DCDC parser isolation probe; not a classifier")


def toy_conv(height, width, kernel_height, kernel_width):
    weight = np.full((1, 3, kernel_height, kernel_width), 1 / (3 * kernel_height * kernel_width), dtype=np.float32)
    bias = np.zeros(1, dtype=np.float32)
    node = helper.make_node("Conv", ["input", "weight", "bias"], ["logits"],
                            kernel_shape=[kernel_height, kernel_width],
                            pads=[kernel_height // 2, kernel_width // 2] * 2,
                            strides=[1, 1], dilations=[1, 1], group=1)
    graph = helper.make_graph([node], "toy_conv",
                              [helper.make_tensor_value_info("input", TensorProto.FLOAT, [1, 3, height, width])],
                              [helper.make_tensor_value_info("logits", TensorProto.FLOAT, [1, 1, height, width])],
                              [numpy_helper.from_array(weight, "weight"), numpy_helper.from_array(bias, "bias")])
    return helper.make_model(graph, opset_imports=[helper.make_opsetid("", 14)], ir_version=7)


RUNNER = r'''#!/bin/sh
# BOARD-only: parse each graph in a separate process; never run inference.
set -eu
base=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
runtime=${1:-/tmp/dcdc_npu}
app="$runtime/bin/dcdc_npu_infer"
input="$runtime/golden_vectors/class0_row0.input_f32.bin"
if [ "$(uname -m)" != aarch64 ]; then echo 'ERROR: run on the board serial terminal.' >&2; exit 1; fi
if [ ! -x "$app" ] || [ ! -r "$input" ]; then
    echo "ERROR: diagnostic application/input missing under $runtime; extract the earlier diagnostic board tar first." >&2
    exit 1
fi
if ! "$app" --help | grep -q -- '--parse-only'; then echo 'ERROR: diagnostic binary required.' >&2; exit 1; fi
export LD_LIBRARY_PATH="$runtime/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
ulimit -c 0
logs="$base/logs_$(date +%Y%m%d_%H%M%S)_$$"
mkdir "$logs"
printf 'case\tresult\texit\tlast_stage\n' > "$logs/results.tsv"
cr=$(printf '\r')
while read -r name; do
    name=${name%"$cr"}
    [ -n "$name" ] || continue
    log="$logs/$name.log"
    if "$app" --model "$base/models/$name.onnx" --input "$input" --parse-only > "$log" 2>&1; then code=0; else code=$?; fi
    if grep -q '^PARSE_ONLY_OK ' "$log"; then
        result=PARSE_AND_BINDINGS_OK
    elif grep -q '^STAGE=MODEL_PARSE_OK$' "$log"; then
        result=MODEL_PARSED_BINDING_CHECK_STOPPED
    elif grep -q '^STAGE=MODEL_PARSE_BEGIN ' "$log"; then
        result=MODEL_PARSE_FAILED
    else
        result=INIT_FAILED
    fi
    stage=$(grep '^STAGE=' "$log" | tail -n 1)
    printf '%s\t%s\t%s\t%s\n' "$name" "$result" "$code" "$stage" >> "$logs/results.tsv"
    printf 'CASE=%s RESULT=%s EXIT=%s\n' "$name" "$result" "$code"
done < "$base/cases.txt"
echo "PARSER_PROBES_FINISHED logs=$logs"
echo 'Results describe parsing only. No Optimize/LoadNetwork/EnqueueWorkload was requested.'
cat "$logs/results.tsv"
'''


def main():
    output = PROJECT / "output/npu_parser_probes_20261026"
    if output.exists():
        raise ValueError("output exists; preserve earlier probe package")
    (output / "models").mkdir(parents=True)
    source = PROJECT / "output/npu_onnx_20261026_v1"
    original = onnx.load(source / "condition_fp32.onnx")
    quantized = onnx.load(source / "condition_uint8_qdq.onnx")
    official_path = PROJECT / "tmp/npu_official_model_inspection/yolo_face_uint8_15.onnx"
    if not official_path.is_file():
        with tarfile.open(PROJECT / "output/npu_baseline/official_demo/sdk/face_detection.tar.gz", "r:gz") as archive:
            member = next(m for m in archive.getmembers() if m.name.endswith("/inputs/yolo_face_uint8_15.onnx"))
            official_data = archive.extractfile(member).read()
    else:
        official_data = official_path.read_bytes()
    (output / "models/00_official_yolo_reference.onnx").write_bytes(official_data)
    models = {"01_toy_conv_image16": toy_conv(16, 16, 3, 3),
              "02_toy_conv_height1": toy_conv(1, 256, 1, 3)}
    for count in (1, 2, 3, 4, 5, 6, 7, 8):
        name = f"{count+2:02}_prefix{count}_{original.graph.node[count-1].op_type}"
        models[name] = prefix_model(original, count)
    models["11_original_fp32"] = original
    models["12_inferred_fp32"] = onnx.shape_inference.infer_shapes(original, strict_mode=True)
    models["13_original_qdq"] = quantized
    models["14_inferred_qdq"] = onnx.shape_inference.infer_shapes(quantized, strict_mode=True)
    metadata = {}
    for name, model in models.items():
        onnx.checker.check_model(model, full_check=True)
        onnx.save(model, output / f"models/{name}.onnx")
        metadata[name] = {"operators": [n.op_type for n in model.graph.node],
                          "input_shape": [[d.dim_value for d in v.type.tensor_type.shape.dim] for v in model.graph.input],
                          "output_shape": [[d.dim_value for d in v.type.tensor_type.shape.dim] for v in model.graph.output],
                          "value_info_count": len(model.graph.value_info)}
    # The official reference is a byte-for-byte copy, not rewritten by modern ONNX.
    onnx.checker.check_model(onnx.load_model_from_string(official_data))
    names = ["00_official_yolo_reference"] + sorted(models)
    (output / "cases.txt").write_bytes(("\n".join(names) + "\n").encode("ascii"))
    (output / "run_parse_probes.sh").write_bytes(RUNNER.encode("ascii"))
    (output / "model_metadata.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    readme = '''# 板端 ONNX 解析隔离测试

现有事实：诊断版 CMA、默认 runtime、日志及 parser 创建均通过；原 FP32 与 QDQ 均在 CreateNetworkFromBinaryFile 内段错误。不能由此断定某个具体算子或硬件损坏。

本普通 tar 包无需编译，只包含原始官方 YOLO 对照模型、小型 Conv 图、原训练图的逐节点前缀及补全 shape value_info 的完整图。官方模型保持逐字节原样。所有测试只请求原诊断程序的 --parse-only，不执行 Optimize/LoadNetwork/EnqueueWorkload。

新图均通过 ONNX checker，但这不证明旧版板端解析器支持。两个 toy Conv 的输入分别为 [1,3,16,16] 与 [1,3,1,256]，用于区分普通二维输入与 height=1 输入。前缀图用于找出第一处开始失败的节点。补全 value_info 的图用于检查静态形状信息是否影响解析；没有改变训练权重或数学计算。

注意：00 官方模型的输入名为 images，输出为 output0/output1，因此原诊断程序在解析成功后会因自定义 input/logits 绑定检查退出 1。脚本识别 STAGE=MODEL_PARSE_OK，将其记为 MODEL_PARSED_BINDING_CHECK_STOPPED，表示官方图解析成功，不是推理成功。其余前缀图输出名均为 logits；输出维度可能不是 [1,2]，只用于解析诊断，不能替换生产模型执行分类。

## 传输与执行

将 npu_parser_probes_20261026.tar 复制到 TF 卡启动分区根目录。开发板上：

```sh
cd /tmp
tar -xf /mnt/mmcblk0p1/npu_parser_probes_20261026.tar
sh /tmp/npu_parser_probes/run_parse_probes.sh
```

需要 /tmp/dcdc_npu 中已有诊断版应用；如果重启后 /tmp 被清空，先从 TF 卡解压 dcdc_npu_diag_board_20261026.tar 恢复应用。也可把其他诊断版目录作为 run_parse_probes.sh 的第一个参数。

每个模型在独立进程中解析，某个图段错误不会阻止其他用例继续。保存每例完整日志及 results.tsv。回传最后 CASE=... 和汇总表；失败仍无法定位时，再获取 gdb/core 调用栈。

这不是新训练模型，也不修改现有镜像、生产模型、驱动、PL、FPGA 输出控制。测试期间会重复初始化官方 CMA/runtime。没有新的准确率或 NPU 执行声明。
'''
    (output / "README.md").write_text(readme, encoding="utf-8", newline="\n")
    hashes = {p.relative_to(output).as_posix(): digest(p.read_bytes()) for p in output.rglob("*") if p.is_file()}
    manifest = {"files_sha256": hashes, "cases": len(names), "checker": "PASS",
                "official_reference_sha256": digest(official_data), "production_graphs_modified": False,
                "board_run": "NOT_RUN", "purpose": "parse-only isolation; not a classifier or hardware inference proof"}
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    package = output / "npu_parser_probes_20261026.tar"
    with tarfile.open(package, "w:") as archive:
        for p in sorted(output.rglob("*")):
            if not p.is_file() or p == package:
                continue
            relative = p.relative_to(output).as_posix()
            data = p.read_bytes()
            info = tarfile.TarInfo("npu_parser_probes/" + relative)
            info.size = len(data)
            info.mode = 0o755 if p.suffix == ".sh" else 0o644
            archive.addfile(info, io.BytesIO(data))
    with tarfile.open(package, "r:") as archive:
        for name, expected in hashes.items():
            assert digest(archive.extractfile("npu_parser_probes/" + name).read()) == expected
        for name in ("cases.txt", "run_parse_probes.sh"):
            assert b"\r" not in archive.extractfile("npu_parser_probes/" + name).read()
    print("PARSER_PROBE_PACKAGE_PASS", package, "cases", len(names), "bytes", package.stat().st_size)


if __name__ == "__main__":
    main()
