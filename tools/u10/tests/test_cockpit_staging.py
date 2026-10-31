# SPDX-License-Identifier: MIT
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import zipfile

SPEC = importlib.util.spec_from_file_location('check_cockpit_staging', Path(__file__).resolve().parents[1] / 'check_cockpit_staging.py')
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


class CockpitStagingTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.dist = self.root / 'dist'
        self.dist.mkdir()
        self.index = b'<html>synthetic official cockpit entry</html>'
        self.manifest = json.dumps({'schemaVersion': 1, 'edition': 'official', 'interfaceOnly': True,
                                    'files': {'index.html': checker.sha256(self.index)}}).encode()
        (self.dist / 'index.html').write_bytes(self.index)
        (self.dist / 'bundle-manifest.json').write_bytes(self.manifest)
        self.expected = checker.sha256(self.manifest)
        self.candidate = self.root / 'candidate'
        self.candidate.mkdir()
        self.receipt('bundled-interface-only')
        self.archive()

    def receipt(self, state):
        (self.candidate / 'packaging-receipt.json').write_text(json.dumps({'resources': {'cockpit': state}}))

    def archive(self, manifest=None, index=None, omit_manifest=False):
        prefix = 'ModelPlan.app/Contents/Resources/Cockpit/'
        with zipfile.ZipFile(self.candidate / 'ModelPlan-candidate-adhoc.zip', 'w') as archive:
            if not omit_manifest:
                archive.writestr(prefix + 'bundle-manifest.json', self.manifest if manifest is None else manifest)
            archive.writestr(prefix + 'index.html', self.index if index is None else index)

    def test_staged_and_exact_archived_official_bundle_pass(self):
        self.assertEqual(checker.check(self.dist, self.expected)['stagedManifestSHA256'], self.expected)
        result = checker.check(self.dist, self.expected, self.candidate)
        self.assertEqual(result['archivedManifestSHA256'], self.expected)
        self.assertFalse(result['packagedPlaceholder'])

    def test_missing_or_wrong_reviewed_hash_fails(self):
        for value in [None, '', 'bad', '0' * 64]:
            with self.subTest(value=value), self.assertRaises(ValueError):
                checker.check(self.dist, value)

    def test_missing_or_linked_staged_manifest_fails(self):
        manifest = self.dist / 'bundle-manifest.json'
        manifest.unlink()
        with self.assertRaises(ValueError):
            checker.check(self.dist, self.expected)
        target = self.root / 'manifest.json'
        target.write_bytes(self.manifest)
        manifest.symlink_to(target)
        with self.assertRaises(ValueError):
            checker.check(self.dist, self.expected)

    def test_changed_staged_entry_fails(self):
        (self.dist / 'index.html').write_bytes(b'changed')
        with self.assertRaises(ValueError):
            checker.check(self.dist, self.expected)

    def test_nonofficial_manifest_fails_even_when_its_hash_is_supplied(self):
        data = json.loads(self.manifest)
        data['edition'] = 'community'
        encoded = json.dumps(data).encode()
        (self.dist / 'bundle-manifest.json').write_bytes(encoded)
        with self.assertRaises(ValueError):
            checker.check(self.dist, checker.sha256(encoded))

    def test_placeholder_receipt_fails(self):
        self.receipt('placeholder')
        with self.assertRaisesRegex(ValueError, 'placeholder'):
            checker.check(self.dist, self.expected, self.candidate)

    def test_lying_receipt_cannot_hide_archived_placeholder(self):
        self.archive(index=b'<h1>U10 interface placeholder</h1>')
        with self.assertRaisesRegex(ValueError, 'placeholder'):
            checker.check(self.dist, self.expected, self.candidate)

    def test_missing_or_wrong_archived_manifest_fails(self):
        self.archive(omit_manifest=True)
        with self.assertRaises(ValueError):
            checker.check(self.dist, self.expected, self.candidate)
        self.archive(manifest=b'{}')
        with self.assertRaises(ValueError):
            checker.check(self.dist, self.expected, self.candidate)

    def test_changed_archived_entry_fails(self):
        self.archive(index=b'non-placeholder but changed')
        with self.assertRaises(ValueError):
            checker.check(self.dist, self.expected, self.candidate)


if __name__ == '__main__':
    unittest.main()
