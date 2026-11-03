"""把厂商 QDQ 模型读进来、再用我们自己的 writer 原样写出去，用来判断：
   - 若板上能解析 → 我们的“图结构”没问题，问题在序列化细节
   - 若板上仍崩   → 说明我们的 writer 写出来的字节里有 parser 不吃的东西
"""

import numpy as np

import onnx_min as om


def main():
    src = "_sdk/app/face_detection/inputs/fire_detect_sim_quant_uint8.onnx"
    dst = "out/vendor_roundtrip.onnx"
    m = om.read_model(open(src, "rb").read())

    nodes = []
    for n in m["nodes"]:
        attrs = []
        for k, v in n["attrs"].items():
            if isinstance(v, float):
                attrs.append(om.attr_float(k, v))
            else:
                attrs.append(om.attr_int(k, int(v)))
        nodes.append(om.node(n["op"], n["inputs"], n["outputs"], n["name"], attrs))

    inits = [om.tensor(k, v) for k, v in m["initializers"].items()]
    ins = [om.value_info(v["name"], v["dims"], v["dtype"] or 1) for v in m["input_info"]]
    outs = [om.value_info(v["name"], v["dims"], v["dtype"] or 1) for v in m["output_info"]]

    buf = om.make_model(nodes, inits, ins, outs, opset=m["opset"] or 13, graph_name="vendor_roundtrip")
    open(dst, "wb").write(buf)
    print(f"[roundtrip] {src} -> {dst}  ({len(buf)} B, nodes={len(nodes)}, inits={len(inits)})")

    # 自检：读回来节点数/张量数一致
    m2 = om.read_model(open(dst, "rb").read())
    print(f"[roundtrip] 回读: nodes={len(m2['nodes'])} inits={len(m2['initializers'])} "
          f"in={m2['inputs']} out={len(m2['outputs'])}")


if __name__ == "__main__":
    main()
