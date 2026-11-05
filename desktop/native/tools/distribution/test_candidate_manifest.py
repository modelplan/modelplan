# SPDX-License-Identifier: MIT
import json
from pathlib import Path
import plistlib
import tempfile
import unittest
from candidate_manifest import create, verify


class CandidateManifestTests(unittest.TestCase):
    def test_receipt_binds_source_archive_and_actual_flag(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            archive, info, manifest = root / 'app.zip', root / 'Info.plist', root / 'manifest.json'
            archive.write_bytes(b'synthetic package')
            metadata = {'ModelPlanCockpitEntryEnabled': True, 'CFBundleExecutable': 'ModelPlanCommunity',
                        'CFBundleIdentifier': 'org.modelplan.community.swift.scaffold', 'LSMinimumSystemVersion': '15.0'}
            info.write_bytes(plistlib.dumps(metadata))
            sha = 'a' * 40
            manifest.write_text(json.dumps(create(archive, info, sha, 'c' * 40, '123', '2')))
            verify(archive, manifest, sha)
            with self.assertRaises(ValueError):
                verify(archive, manifest, 'b' * 40)
            archive.write_bytes(b'changed')
            with self.assertRaises(ValueError):
                verify(archive, manifest, sha)
            metadata['CFBundleExecutable'] = 'other'
            info.write_bytes(plistlib.dumps(metadata))
            with self.assertRaises(ValueError):
                create(archive, info, sha, 'c' * 40, '123', '2')
            metadata['CFBundleExecutable'] = 'ModelPlanCommunity'
            metadata['ModelPlanCockpitEntryEnabled'] = False
            info.write_bytes(plistlib.dumps(metadata))
            with self.assertRaises(ValueError):
                create(archive, info, sha, 'c' * 40, '123', '2')
