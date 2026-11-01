# SPDX-License-Identifier: MIT
"""Public numerical receipts identify evidence without exposing machine paths."""
import json
from pathlib import Path
import re
import unittest


class PublicReceiptTests(unittest.TestCase):
    def test_public_receipts_use_relative_immutable_evidence_ids(self):
        root = Path(__file__).resolve().parents[1] / 'results'
        for path in root.glob('*.json'):
            with self.subTest(receipt=path.name):
                data = json.loads(path.read_text())
                self.assertNotIn('fullEvidencePath', data)
                self.assertEqual(data['evidenceID'], data['runID'] + '@sha256:' + data['fullEvidenceManifestSHA256'])
                self.assertRegex(data['fullEvidenceManifestSHA256'], r'^[a-f0-9]{64}$')
                def walk(value):
                    if isinstance(value, str):
                        self.assertFalse(value.startswith(('/', '\\\\')) or re.match(r'^[A-Za-z]:[\\/]', value), 'absolute machine path in public receipt')
                        self.assertNotRegex(value, r'/(?:mnt|home)/')
                        self.assertNotIn('DevShared', value)
                    elif isinstance(value, dict):
                        for item in value.values():
                            walk(item)
                    elif isinstance(value, list):
                        for item in value:
                            walk(item)
                walk(data)


if __name__ == '__main__':
    unittest.main()
