# SPDX-License-Identifier: MIT
"""The emitted receipt must be accepted by the packaged verification entry point."""
import hashlib
import json
from pathlib import Path
import plistlib
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / 'desktop/native/verification/bin'))
import packaged_candidate
from candidate_manifest import create


class CandidateConsumerTests(unittest.TestCase):
    def test_producer_receipt_drives_real_synthetic_prepare(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            archive = root / 'candidate.zip'; archive.write_bytes(b'synthetic package')
            content = root / 'App/Contents'; (content / 'Helpers').mkdir(parents=True)
            (content / 'Resources').mkdir()
            helper = content / 'Helpers/modelplan'; helper.write_bytes(b'synthetic cli')
            digest = hashlib.sha256(helper.read_bytes()).hexdigest()
            (content / 'Resources/modelplan.sha256').write_text(digest + '\n')
            sources = {'arm64': 'd' * 64, 'x86_64': 'e' * 64}
            pin = root / 'pin.json'; pin.write_text(json.dumps({'version':'0.0.1','sourceSHA256ByArchitecture':sources}))
            info = content / 'Info.plist'
            info.write_bytes(plistlib.dumps({'CFBundleExecutable':'ModelPlanCommunity',
                'CFBundleIdentifier':'org.modelplan.community.swift.scaffold','LSMinimumSystemVersion':'15.0',
                'ModelPlanCockpitEntryEnabled':True,'ModelPlanHelperVersion':'0.0.1',
                'ModelPlanSourceHelperSHA256ByArchitecture':sources,'ModelPlanBundledHelperSHA256':digest}))
            manifest = root / 'manifest.json'
            manifest.write_text(json.dumps(create(archive, info, 'a'*40, 'c'*40, '123', '1', pin)))
            template = root / 'template.json'
            template.write_text(json.dumps({'profile':'synthetic','launchMode':'direct',
                'expectedLease':{'runID':'run','epoch':'epoch'},
                **{k:str(root/k) for k in ('leasePath','releasePath','stopPath','subjectPidPath','candidateCleanupReceipt')}}))
            record = packaged_candidate.prepare(archive, manifest, template, root, root/'registry.json')
            self.assertEqual(record['sourceSHA'], 'a'*40)
            self.assertEqual(record['packageSHA256'], hashlib.sha256(archive.read_bytes()).hexdigest())
