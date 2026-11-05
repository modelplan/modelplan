# SPDX-License-Identifier: MIT
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('install_receipt', Path(__file__).with_name('check-install-receipt.py'))
module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)


def facts():
    return {'profile': 'synthetic', 'quarantine': True,
            'before': '/private/var/folders/synthetic/AppTranslocation/A/d/ModelPlan.app',
            'after': '/synthetic/Applications/ModelPlan.app',
            'loginItemPath': '/synthetic/Applications/ModelPlan.app', 'postReboot': 'unknown'}


class InstallReceiptTests(unittest.TestCase):
    def test_translocation_is_observed_not_silently_repaired(self):
        value = module.make_receipt(facts())
        self.assertTrue(value['translocatedBefore'])
        self.assertFalse(value['translocatedAfter'])
        self.assertEqual(value['postReboot'], 'unknown')
        self.assertEqual(value['outcome'], 'NOT_RUN')

    def test_real_or_malformed_paths_and_unknown_status_rejected(self):
        for changes in ({'profile': 'real'}, {'before': '/Users/actual/Private.app'},
                        {'loginItemPath': '/synthetic/../private/Other.app'},
                        {'quarantine': 'yes'}, {'postReboot': 'success'}, {'unrequested': 'private'}):
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                module.make_receipt({**facts(), **changes})

    def test_generated_fixture_is_always_not_real_evidence(self):
        result = module.synthetic_fixture()
        self.assertEqual(result['profile'], 'synthetic')
        self.assertEqual(result['outcome'], 'NOT_RUN')
        self.assertIn(result['quarantine'], (True, False, None))
