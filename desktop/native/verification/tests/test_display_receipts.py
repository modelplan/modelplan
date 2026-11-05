# SPDX-License-Identifier: MIT
import importlib.util
from pathlib import Path
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'validate_display_receipt.py'
spec = importlib.util.spec_from_file_location('g4_display_receipt', SCRIPT)
validator = importlib.util.module_from_spec(spec); spec.loader.exec_module(validator)


def receipt():
    return {'schemaVersion': 1, 'profile': 'synthetic', 'events': [
        {'kind': name, 'elapsedSeconds': number, 'display': label, 'preferenceSHA256': 'a' * 64}
        for name, number, label in [('sleep', 0, 'internal'), ('wake', 20, 'internal'),
                                    ('unplug', 30, 'external'), ('replug', 40, 'external')]]}


class DisplayReceiptTests(unittest.TestCase):
    def test_valid_order_labels_and_preference_hash(self):
        self.assertTrue(validator.validate(receipt(), {'internal', 'external'}))

    def test_invalid_labels_order_times_and_changes_fail(self):
        mutations = [lambda x: x['events'][2].update(display='foreign'),
                     lambda x: x['events'][1].update(elapsedSeconds=-1),
                     lambda x: x['events'][2].update(elapsedSeconds=10),
                     lambda x: x['events'][3].update(preferenceSHA256='b' * 64),
                     lambda x: x['events'][1].update(kind='replug'),
                     lambda x: x.update(profile='real'), lambda x: x['events'].pop()]
        for mutate in mutations:
            value = receipt(); mutate(value)
            with self.subTest(value=value), self.assertRaises(ValueError):
                validator.validate(value, {'internal', 'external'})

    def test_missing_or_unsafe_approval_refused(self):
        for labels in (set(), {'internal'}, {'internal', 'external', '../private'}):
            with self.subTest(labels=labels), self.assertRaises(ValueError):
                validator.validate(receipt(), labels)
