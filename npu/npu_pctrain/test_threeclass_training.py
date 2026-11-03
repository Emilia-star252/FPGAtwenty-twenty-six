"""Guard missing-class reporting and the physical NPU/PS model split."""
import unittest

import numpy as np
import torch
from train_threeclass_npu import build_feature_model, class_logits, metrics


class ThreeclassTests(unittest.TestCase):
    def test_missing_class_is_unmeasured_not_perfect_recall(self):
        m = metrics([0, 0, 1, 1], [0, 2, 1, 1])
        self.assertEqual(m["missing_ground_truth_class_ids"], [2])
        self.assertIsNone(m["per_class"][2]["recall"])
        self.assertFalse(m["full_threeclass_evaluation_available"])
        self.assertEqual(m["false_oscillation_predictions_on_nonoscillation"], 1)
        self.assertEqual(m["accuracy"], .75)
        self.assertAlmostEqual(m["macro_f1_supported_classes"], (2/3+1)/2)

    def test_single_pool_ps_max_equals_four_pool_output(self):
        torch.manual_seed(9)
        model = build_feature_model()
        x = torch.randn(4, 3, 16, 16)
        features = model(x)
        reference = features
        for _ in range(3):
            reference = torch.nn.functional.max_pool2d(reference, 2, 2)
        self.assertTrue(torch.equal(features.amax((2, 3)), reference[:, :, 0, 0]))
        self.assertEqual(tuple(features.shape), (4, 16, 8, 8))

    def test_new_channel_learns_and_unused_channels_remain_zero(self):
        torch.manual_seed(2)
        model = build_feature_model()
        with torch.no_grad():
            model[0].weight[3:].zero_()
            model[0].bias[3:].zero_()
        before = model[0].weight[2].detach().clone()
        optimizer = torch.optim.Adam(model.parameters(), lr=.001, weight_decay=1e-4)
        loss = torch.nn.functional.cross_entropy(class_logits(model, torch.randn(8, 3, 16, 16)), torch.full((8,), 2))
        loss.backward()
        self.assertGreater(float(model[0].weight.grad[2].abs().sum()), 0)
        model[0].weight.grad[3:].zero_()
        model[0].bias.grad[3:].zero_()
        optimizer.step()
        self.assertFalse(torch.equal(before, model[0].weight[2]))
        self.assertEqual(int(torch.count_nonzero(model[0].weight[3:])), 0)
        self.assertEqual(int(torch.count_nonzero(model[0].bias[3:])), 0)


if __name__ == "__main__":
    unittest.main()
