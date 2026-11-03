import unittest

import numpy as np

from train_condition import classification_metrics, fit_preprocessing, preprocess
from causal_features import prefix_baselines, relative_values


class TrainingDataTests(unittest.TestCase):
    def test_context_excludes_current_and_future_samples(self):
        source = np.arange(60, dtype=np.float64).reshape(20, 3)
        before = prefix_baselines(source, np.array([5, 10]), 4)
        np.testing.assert_allclose(before[0], source[1:5].mean(0))
        np.testing.assert_allclose(before[1], source[6:10].mean(0))
        changed = source.copy()
        changed[5:] += 10000
        np.testing.assert_array_equal(prefix_baselines(changed, [5], 4)[0], before[0])

    def test_context_does_not_cross_run_start(self):
        source = np.arange(60).reshape(20, 3)
        np.testing.assert_allclose(prefix_baselines(source, [2], 100)[0], source[:2].mean(0))
        with self.assertRaises(ValueError):
            prefix_baselines(source, [0], 100)

    def test_relative_preprocessing_uses_known_past_only(self):
        x = np.array([[[24., .3, .5], [22., .4, .48]],
                      [[36., .8, .6], [33., .9, .57]]], dtype=np.float32)
        baseline = np.array([[24., .3, .5], [36., .8, .6]])
        transformed = relative_values(x, baseline)
        config = fit_preprocessing(x, np.array([0, 1]), baseline, 2.)
        self.assertEqual(config["feature_transform"]["mode"], "causal-relative")
        np.testing.assert_allclose(config["mean"], transformed.mean((0, 1), dtype=np.float64))
        with self.assertRaises(ValueError):
            preprocess(x, config)
        result = preprocess(x, config, baseline)
        np.testing.assert_allclose(result.mean((0, 2, 3)), 0, atol=1e-6)

    def test_normalization_uses_training_only(self):
        train = np.arange(24, dtype=np.float32).reshape(2, 4, 3)
        config = fit_preprocessing(train, np.array([0, 1]))
        out = preprocess(train, config)
        self.assertEqual(out.shape, (2, 3, 1, 4))
        self.assertEqual(out.dtype, np.float32)
        np.testing.assert_allclose(out.mean(axis=(0, 2, 3)), 0, atol=1e-6)
        np.testing.assert_allclose(out.std(axis=(0, 2, 3)), 1, atol=1e-6)
        shifted_validation = train + 100
        self.assertGreater(float(preprocess(shifted_validation, config).mean()), 1)

    def test_zero_std_is_floored(self):
        config = fit_preprocessing(np.ones((2, 4, 3), dtype=np.float32), np.array([0, 1]))
        self.assertEqual(config["std"], [1e-6] * 3)
        self.assertTrue(np.isfinite(preprocess(np.ones((2, 4, 3), dtype=np.float32), config)).all())

    def test_weights_are_inverse_training_counts(self):
        config = fit_preprocessing(np.ones((4, 4, 3), dtype=np.float32), np.array([0, 0, 0, 1]))
        np.testing.assert_allclose(config["class_weights"], [2 / 3, 2])

    def test_missing_training_class_is_rejected(self):
        with self.assertRaises(ValueError):
            fit_preprocessing(np.ones((2, 4, 3)), np.array([0, 0]))

    def test_high_accuracy_does_not_hide_missing_transients(self):
        y = np.array([0] * 99 + [1])
        metrics = classification_metrics(y, np.zeros(100, dtype=np.int64))
        self.assertEqual(metrics["accuracy"], .99)
        self.assertEqual(metrics["balanced_accuracy"], .5)
        self.assertEqual(metrics["transient_recall"], 0)
        self.assertLess(metrics["macro_f1"], .5)

    def test_confusion_matrix_orientation(self):
        metrics = classification_metrics(np.array([0, 0, 1, 1]), np.array([0, 1, 1, 1]))
        self.assertEqual(metrics["confusion_matrix_true_rows_predicted_columns"], [[1, 1], [0, 2]])
        self.assertEqual(metrics["transient_recall"], 1)
        self.assertEqual(metrics["normal_false_positive_rate"], .5)


if __name__ == "__main__":
    unittest.main()
