# SPDX-License-Identifier: MIT
"""Synthetic identity and coexistence boundaries, never real installs or login state."""
import importlib.util
import json
from pathlib import Path
import plistlib
import re
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / 'tools/u10'))
import package_candidate as packaging
from shape_home import build_home, SETTINGS_PATHS
spec = importlib.util.spec_from_file_location('upgrade_identity', Path(__file__).with_name('upgrade_identity.py'))
checker = importlib.util.module_from_spec(spec); spec.loader.exec_module(checker)
FIXTURE = Path(__file__).with_name('fixtures') / 'g4-upgrade-synthetic.json'


class UpgradeIdentityTests(unittest.TestCase):
    def setUp(self): self.value = json.loads(FIXTURE.read_text())

    def test_fixture_matches_real_packaging_identifiers_and_helper_pin(self):
        script = (ROOT / 'desktop/native/tools/package-neutral.sh').read_text()
        interim = re.search(r'<key>CFBundleIdentifier</key><string>([^<]+)</string>', script).group(1)
        with tempfile.TemporaryDirectory() as directory:
            app = Path(directory) / 'Candidate.app'; resources = app / 'Contents/Resources'; resources.mkdir(parents=True)
            info = app / 'Contents/Info.plist'; info.write_bytes(plistlib.dumps({'CFBundleIdentifier': interim}))
            packaging.configure_product(app, 'a' * 40, '123')
            candidate = plistlib.loads(info.read_bytes())['CFBundleIdentifier']
        pin = json.loads((ROOT / 'desktop/native/consent-cli-pin.json').read_text())
        self.assertEqual(packaging.HELPER_VERSION, pin['version'])
        self.assertTrue(checker.validate(self.value, interim, candidate, packaging.HELPER_VERSION, pin['version']))

    def test_duplicate_items_or_unwritable_settings_are_rejected(self):
        for mutation in ('same-id', 'duplicate-login', 'duplicate-engine', 'duplicate-dock', 'unwritable', 'wrong-helper'):
            value = json.loads(FIXTURE.read_text())
            expected = '1.2.3'; actual = expected
            if mutation == 'same-id': value['candidateBundleID'] = value['interimBundleID']
            if mutation == 'duplicate-login': value['installations'][0]['loginItemNames'].append('duplicate')
            if mutation == 'duplicate-engine': value['scenarios'][0]['engineCount'] = 2
            if mutation == 'duplicate-dock': value['scenarios'][1]['dockCount'] = 2
            if mutation == 'unwritable': value['scenarios'][0]['settingsWritable'] = False
            if mutation == 'wrong-helper': actual = 'old'
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                checker.validate(value, 'org.modelplan.community.swift.scaffold', 'ai.modelplan.candidate', actual, expected)

    def test_fixture_settings_writable_after_bundle_metadata_replacement(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); home = root / 'synthetic-home'
            shape = json.loads((ROOT / 'tools/u14/examples/synthetic-shape.json').read_text())
            baseline = build_home(shape, home, 'coexistence')
            self.assertIn('synthetic-home', baseline['availableCapabilities'])
            settings = home / SETTINGS_PATHS[1]
            data = json.loads(settings.read_text()); original_edge = data['preferences']['dockEdge']
            app = root / 'Synthetic.app'; resources = app / 'Contents/Resources'; resources.mkdir(parents=True)
            info = app / 'Contents/Info.plist'
            info.write_bytes(plistlib.dumps({'CFBundleIdentifier': self.value['interimBundleID']}))
            packaging.configure_product(app, 'a' * 40, '2')
            self.assertEqual(json.loads(settings.read_text())['preferences']['dockEdge'], original_edge)
            data['preferences']['dockEdge'] = 'bottom'; settings.write_text(json.dumps(data))
            self.assertEqual(json.loads(settings.read_text())['preferences']['dockEdge'], 'bottom')
