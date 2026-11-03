"""compare_board_output.py 的自测：
  1) 完美部署：概率与期望一致 -> 应通过
  2) 电流通道增益 +10%：概率按模型重算 -> 应被检出（偏差超阈值或类别变化）
"""

import csv

import numpy as np

from export_onnx import INPUT_DIV, fold_standardization


def probs_of(model, raw):
    W1, b1 = fold_standardization(model)
    u = raw / np.asarray(INPUT_DIV)[None, :]
    h = np.maximum(u @ W1.T + b1, 0.0)
    h = np.maximum(h @ model["W2"].T + model["b2"], 0.0)
    z = h @ model["W3"].T + model["b3"]
    e = np.exp(z - z.max(axis=1, keepdims=True))
    return e / e.sum(axis=1, keepdims=True)


def write(path, rows, probs, latency):
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        for k, r in enumerate(rows):
            p = probs[k]
            w.writerow([r["v_out"], r["i_out"], r["duty"], int(np.argmax(p))]
                       + [f"{v:.6f}" for v in p] + [latency])


def main():
    model = dict(np.load("out/model.npz", allow_pickle=True))
    rows = list(csv.DictReader(open("out/dcdc_board_test_expected.csv", encoding="utf-8")))
    raw = np.array([[float(r["v_out"]), float(r["i_out"]), float(r["duty"])] for r in rows])
    write("out/_fake_board_ok.csv", rows, probs_of(model, raw), "0.412")

    bad = raw.copy()
    bad[:, 1] *= 1.10                    # 电流增益 +10%
    write("out/_fake_board_bad.csv", rows, probs_of(model, bad), "0.500")


if __name__ == "__main__":
    main()
