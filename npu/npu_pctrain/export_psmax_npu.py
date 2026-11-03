#!/usr/bin/env python3
"""Cut at the validated 16->8 pool and verify explicit PS max against the frozen model."""
from pathlib import Path
import copy
import hashlib
import json
import shutil
import sys

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parents[2]
sys.path.insert(0, str(PROJECT / 'tmp/npu_onnx_python_deps'))
import numpy as np
import onnx
import onnxruntime as ort
from onnx import TensorProto, helper as H, numpy_helper as N
from export_quantize import complete_shapes, graph_info
from export_square_npu import quantize
from train_square_npu import square_inputs
from train_condition import load_dataset


def save_json(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8', newline='\n')


def main():
    source = PROJECT / 'output/npu_square_onnx_20261026_v1'
    output = PROJECT / 'output/npu_psmax_onnx_20261026_v1'
    if output.exists():
        raise ValueError('preserve previous conversion; choose a new output directory')
    original = source / 'condition_square_uint8.onnx'
    baseline = onnx.load(original)
    params = {t.name: N.to_array(t) for t in baseline.graph.initializer}
    # Every removed Q/DQ round trip is exactly the identity on all 256 U8 values.
    all_bytes = np.arange(256, dtype=np.uint8)
    for index in (3, 4, 5, 6):
        assert np.array_equal(params[f's{index}'], params['s3'])
        assert np.array_equal(params[f'z{index}'], params['z3'])
        dequantized = (all_bytes.astype(np.int32) - int(params[f'z{index}'])).astype(np.float32) * params[f's{index}']
        assert np.array_equal(quantize(dequantized, params[f's{index}'], params[f'z{index}']), all_bytes)
    nodes = copy.deepcopy(list(baseline.graph.node)[:11])
    assert nodes[-2].op_type == 'MaxPool' and nodes[-1].output[0] == 'pool1_q'
    for i in (9, 12, 15, 18):
        node = baseline.graph.node[i]
        attrs = {a.name: H.get_attribute_value(a) for a in node.attribute}
        assert node.op_type == 'MaxPool' and attrs['kernel_shape'] == [2, 2] and attrs['strides'] == [2, 2]
        assert attrs['pads'] == [0, 0, 0, 0] and attrs['ceil_mode'] == 0
    nodes[-1].output[0] = 'logits'
    used = {s for node in nodes for s in node.input}
    initializers = [copy.deepcopy(t) for t in baseline.graph.initializer if t.name in used]
    graph = H.make_graph(nodes, 'dcdc_square_npu_prefix_ps_global_max',
                         [copy.deepcopy(baseline.graph.input[0])],
                         [H.make_tensor_value_info('logits', TensorProto.UINT8, [1, 16, 8, 8])], initializers)
    model = H.make_model(graph, ir_version=baseline.ir_version,
                         opset_imports=copy.deepcopy(list(baseline.opset_import)),
                         producer_name='Frozen trained weights; NPU Conv/Relu/one pool; explicit PS channel max')
    for name in ['qw', 'ws', 'wz', 'qb', 'bs', 'bz']:
        assert next(t for t in model.graph.initializer if t.name == name).SerializeToString() == \
               next(t for t in baseline.graph.initializer if t.name == name).SerializeToString()
    output.mkdir()
    target = output / 'condition_square_psmax_uint8.onnx'
    onnx.save(model, target)
    complete_shapes(target)
    opts = ort.SessionOptions()
    opts.intra_op_num_threads = 1
    opts.inter_op_num_threads = 1
    old = ort.InferenceSession(str(original), sess_options=opts, providers=['CPUExecutionProvider'])
    new = ort.InferenceSession(str(target), sess_options=opts, providers=['CPUExecutionProvider'])
    report = {'original_model_sha256': hashlib.sha256(original.read_bytes()).hexdigest(),
              'prefix': graph_info(target), 'trained_weights_byte_identical': True,
              'removed_pool_quantization_identical': True, 'qdq_identity_checked_all_256_uint8_values': True,
              'equivalence': 'Three 2x2/stride2 max pools on 8x8 equal a channel-wise max over all 64 values',
              'board_execution': 'NOT_RUN', 'evaluation': {}, 'goldens': [],
              'limitation': 'Existing exploratory validation/test data are reused to verify conversion equivalence; not new generalization evidence'}
    dataset = PROJECT / 'output/npu_dataset_20261026'
    parts, manifest = load_dataset(dataset)
    pre = json.loads((source / 'preprocessing.json').read_text())
    for split in ['validation', 'test']:
        x = square_inputs(parts[split], pre, dataset, manifest)
        xin = quantize(x, params['s0'], params['z0'])
        disagreements = 0
        for value in xin:
            before = old.run(['logits'], {'input': value[None]})[0]
            features = new.run(['logits'], {'input': value[None]})[0]
            after = features.max(axis=(2, 3), keepdims=True)
            assert np.array_equal(before, after), split
            disagreements += int(before[:, :2, 0, 0].argmax(1)[0] != after[:, :2, 0, 0].argmax(1)[0])
        report['evaluation'][split] = {'windows': len(xin), 'all_16_channel_u8_outputs_exact': True,
                                        'classification_disagreements': disagreements}
        print('PSMAX_EQUIVALENCE', split, len(xin), 'all_16_channels_exact', flush=True)
    vectors = output / 'golden_vectors'
    vectors.mkdir()
    for file in (source / 'golden_vectors').iterdir():
        if file.is_file(): shutil.copyfile(file, vectors / file.name)
    for line in (vectors / 'references.txt').read_text().splitlines():
        name = line.split()[0]
        x = np.fromfile(vectors / f'{name}.input_f32.bin', dtype='<f4').reshape(1, 3, 16, 16)
        features = new.run(['logits'], {'input': quantize(x, params['s0'], params['z0'])})[0]
        reduced = features.max(axis=(2, 3), keepdims=True)
        expected = old.run(['logits'], {'input': quantize(x, params['s0'], params['z0'])})[0]
        assert np.array_equal(reduced, expected)
        features.tofile(vectors / f'{name}.features_u8.bin')
        reduced.tofile(vectors / f'{name}.reduced_u8.bin')
        report['goldens'].append({'name': name, 'features_bytes': features.size, 'all_channels_exact': True})
    shutil.copyfile(source / 'preprocessing.json', output / 'preprocessing.json')
    quant = f"{float(params['s0']):.17g} {int(params['z0'])} {float(params['s3']):.17g} {int(params['z3'])}\n"
    (output / 'psmax_quant_params.txt').write_bytes(quant.encode('ascii'))
    contract = {'input': {'dtype': 'uint8', 'shape': [1, 3, 16, 16], 'scale': float(params['s0']), 'zero_point': int(params['z0'])},
                'npu_output': {'dtype': 'uint8', 'shape': [1, 16, 8, 8], 'scale': float(params['s3']), 'zero_point': int(params['z3'])},
                'npu_operations': ['Conv3x3', 'Relu', 'MaxPool2x2_stride2'],
                'ps_postprocess': 'NCHW: max of 64 UINT8 values per channel; dequantize channels 0/1; argmax',
                'reduced_shape': [1, 16, 1, 1], 'class_channels': [0, 1], 'board_status': 'NOT_RUN'}
    save_json(output / 'model_contract.json', contract)
    save_json(output / 'equivalence_report.json', report)
    shutil.copyfile(__file__, output / Path(__file__).name)
    save_json(output / 'artifact_checksums.json', {p.relative_to(output).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                                               for p in output.rglob('*') if p.is_file()})
    print('PSMAX_EXPORT_OK', output, flush=True)


if __name__ == '__main__':
    main()
