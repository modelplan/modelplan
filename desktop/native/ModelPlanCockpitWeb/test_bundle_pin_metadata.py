# SPDX-License-Identifier: MIT
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('bundle_pin_guard', Path(__file__).with_name('check-bundle-pins.py'))
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)


class BundleMetadataTests(unittest.TestCase):
    def test_appledouble_is_ignored_but_corruption_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            pins = {}
            for edition in ('community', 'official'):
                bundle = root / 'desktop/cockpit/.tmp' / edition
                bundle.mkdir(parents=True)
                content = b'synthetic public bundle'
                (bundle / 'index.html').write_bytes(content)
                manifest = json.dumps(dict(schemaVersion=1, edition=edition, interfaceOnly=True,
                                           files={'index.html': hashlib.sha256(content).hexdigest()})).encode()
                (bundle / 'bundle-manifest.json').write_bytes(manifest)
                (bundle / '._index.html').write_bytes(b'metadata')
                metadata_dir = bundle / '._transport'
                metadata_dir.mkdir()
                (metadata_dir / 'unlisted').write_bytes(b'metadata')
                pins[edition] = hashlib.sha256(manifest).hexdigest()
            source = root / 'desktop/native/ModelPlanAppIntegration/Sources/ModelPlanAppIntegration/CommunityCockpitApplicationFactory.swift'
            source.parent.mkdir(parents=True)
            source.write_text(json.dumps(pins))
            self.assertEqual([entry['files'] for entry in guard.validate(root)], [1, 1])
            result = subprocess.run([sys.executable, '-B', str(Path(guard.__file__)), '--repo', str(root)],
                                    check=True, capture_output=True, text=True)
            self.assertEqual([entry['files'] for entry in json.loads(result.stdout)], [1, 1])
            (root / 'desktop/cockpit/.tmp/community/index.html').write_bytes(b'corrupt')
            with self.assertRaises(ValueError):
                guard.validate(root)


if __name__ == '__main__':
    unittest.main()
