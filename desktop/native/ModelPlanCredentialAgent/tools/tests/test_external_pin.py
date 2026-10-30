# SPDX-License-Identifier: MIT
import unittest
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parents[1]))
from check_embedded_agent import CheckFailure, require_expected_sha

class ExternalPinTests(unittest.TestCase):
    def pin(self):
        return {'schemaVersion': 1, 'sha256': 'a' * 64, 'bytes': 10,
                'inputSHA256': 'b' * 64, 'bundleIdentifier': 'ai.modelplan.credential-agent'}
    def test_approved_external_pin_is_required_to_match(self):
        require_expected_sha(self.pin(), 'a' * 64)
        for expected in ('c' * 64, '', 'A' * 64, 'a' * 63):
            with self.assertRaises(CheckFailure):
                require_expected_sha(self.pin(), expected)
