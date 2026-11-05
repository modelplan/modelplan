# SPDX-License-Identifier: MIT
import hashlib
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
            helper = root / 'Helpers/modelplan'
            helper.parent.mkdir()
            helper.write_bytes(b'synthetic pinned CLI')
            cli_hash = hashlib.sha256(helper.read_bytes()).hexdigest()
            resource = root / 'Resources/modelplan.sha256'
            resource.parent.mkdir()
            resource.write_text(cli_hash + '\n')
            cli_pin = root / 'cli-pin.json'
            source_hashes = {'arm64': 'd' * 64, 'x86_64': 'e' * 64}
            cli_pin.write_text(json.dumps({'version': '0.0.1', 'sourceSHA256ByArchitecture': source_hashes}))
            metadata = {'ModelPlanCockpitEntryEnabled': True, 'CFBundleExecutable': 'ModelPlanCommunity',
                        'CFBundleIdentifier': 'org.modelplan.community.swift.scaffold', 'LSMinimumSystemVersion': '15.0',
                        'ModelPlanHelperVersion': '0.0.1', 'ModelPlanSourceHelperSHA256ByArchitecture': source_hashes,
                        'ModelPlanBundledHelperSHA256': cli_hash}
            info.write_bytes(plistlib.dumps(metadata))
            sha = 'a' * 40
            manifest.write_text(json.dumps(create(archive, info, sha, 'c' * 40, '123', '2', cli_pin)))
            verify(archive, manifest, sha)
            self.assertEqual(json.loads(manifest.read_text())['cliSource'], 'declared-reviewed-release')
            self.assertEqual(json.loads(manifest.read_text())['cliVersion'], '0.0.1')
            helper.write_bytes(b'forged')
            with self.assertRaises(ValueError):
                create(archive, info, sha, 'c' * 40, '123', '2', cli_pin)
            helper.write_bytes(b'synthetic pinned CLI')
            with self.assertRaises(ValueError):
                verify(archive, manifest, 'b' * 40)
            archive.write_bytes(b'changed')
            with self.assertRaises(ValueError):
                verify(archive, manifest, sha)
            metadata['CFBundleExecutable'] = 'other'
            info.write_bytes(plistlib.dumps(metadata))
            with self.assertRaises(ValueError):
                create(archive, info, sha, 'c' * 40, '123', '2', cli_pin)
            metadata['CFBundleExecutable'] = 'ModelPlanCommunity'
            metadata['ModelPlanCockpitEntryEnabled'] = False
            info.write_bytes(plistlib.dumps(metadata))
            with self.assertRaises(ValueError):
                create(archive, info, sha, 'c' * 40, '123', '2', cli_pin)
