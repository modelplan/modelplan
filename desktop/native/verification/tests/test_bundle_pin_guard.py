# SPDX-License-Identifier: MIT
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[2] / 'ModelPlanCockpitWeb/check-bundle-pins.py'
spec = importlib.util.spec_from_file_location('bundle_pin_guard', SCRIPT)
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)


class BundlePinGuardTests(unittest.TestCase):
    def fixture(self, root):
        pins = {}
        for edition in ('community', 'official'):
            directory = root / 'desktop/cockpit/.tmp' / edition
            directory.mkdir(parents=True)
            body = b'public synthetic HTML'
            (directory / 'index.html').write_bytes(body)
            manifest = json.dumps(dict(schemaVersion=1, edition=edition, interfaceOnly=True, files={'index.html': hashlib.sha256(body).hexdigest()})).encode()
            (directory / 'bundle-manifest.json').write_bytes(manifest)
            pins[edition] = hashlib.sha256(manifest).hexdigest()
        source = root / 'desktop/native/ModelPlanAppIntegration/Sources/ModelPlanAppIntegration/CommunityCockpitApplicationFactory.swift'
        source.parent.mkdir(parents=True)
        source.write_text(json.dumps(pins))
        return source

    def test_accepts_both_real_output_digests(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.fixture(root)
            self.assertEqual([x['files'] for x in guard.validate(root)], [1, 1])

    def test_rejects_wrong_native_pin_and_orphan_output(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = self.fixture(root)
            original = source.read_text()
            pins = json.loads(original)
            pins['official'] = '0' * 64
            source.write_text(json.dumps(pins))
            with self.assertRaises(ValueError):
                guard.validate(root)
            source.write_text(original)
            (root / 'desktop/cockpit/.tmp/official/orphan.js').write_text('orphan')
            with self.assertRaises(ValueError):
                guard.validate(root)
