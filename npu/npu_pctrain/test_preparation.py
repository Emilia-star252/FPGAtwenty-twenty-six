import copy
import json
from pathlib import Path
import unittest

import numpy as np

from prepare_dataset import clusters, derive_labels, make_windows, validate_config


class PreparationTests(unittest.TestCase):
    def test_unknown_and_mixed_windows_are_excluded(self):
        signal = np.arange(36).reshape(12, 3)
        labels = np.array([0, 0, 0, 0, -1, -1, 1, 1, 1, 1, 1, 1])
        X, y, starts, rejected = make_windows(signal, labels, 4, 2)
        np.testing.assert_array_equal(starts, [0, 6, 8])
        np.testing.assert_array_equal(y, [0, 1, 1])
        np.testing.assert_array_equal(X[1], signal[6:10])
        self.assertEqual(rejected, 2)

    def test_short_unknown_records_produce_no_windows(self):
        X, y, starts, rejected = make_windows(np.ones((3, 3)), np.full(3, -1), 4, 2)
        self.assertEqual(X.shape, (0, 4, 3))
        self.assertEqual(len(y), 0)

    def test_bridge_does_not_merge_late_disturbance(self):
        self.assertEqual(clusters(np.array([10, 11, 14, 15, 80]), 2), [(10, 16), (80, 81)])

    def test_duplicate_group_is_rejected(self):
        config = json.loads((Path(__file__).parent / "dataset_config.json").read_text())
        config["runs"].append(copy.deepcopy(config["runs"][0]))
        with self.assertRaises(ValueError):
            validate_config(config)

    def test_late_disturbance_is_unknown(self):
        config = json.loads((Path(__file__).parent / "dataset_config.json").read_text())
        x = np.tile([24., 1., .5], (250000, 1))
        x[:50000, 1] = .3
        x[50000:75000, 0] = 20.
        x[125000:137500, 0] = 22.
        intervals, labels, means, evidence = derive_labels(x, "load_step", 25000, config["rules"])
        self.assertEqual(labels[60000], 1)
        self.assertEqual(labels[130000], -1)
        self.assertEqual(labels[200000], 0)
        self.assertTrue(evidence["later_voltage_excursions_left_unlabeled"])

    def test_steady_excursion_is_not_silently_normal(self):
        config = json.loads((Path(__file__).parent / "dataset_config.json").read_text())
        x = np.tile([24., 1., .5], (250000, 1))
        x[100000:105000, 0] = 20.
        with self.assertRaises(ValueError):
            derive_labels(x, "steady", 25000, config["rules"])


if __name__ == "__main__":
    unittest.main()
