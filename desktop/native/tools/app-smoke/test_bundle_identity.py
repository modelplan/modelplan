# SPDX-License-Identifier: MIT
"""Real identity-writer CLI gates with synthetic files; no helper, signing or Swift execution."""
import hashlib
import importlib.util
from pathlib import Path
import plistlib
import shlex
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[4]
WRITER = ROOT / 'desktop/native/tools/write-consent-bundle-identity.py'
spec = importlib.util.spec_from_file_location('smoke_identity_writer', WRITER)
writer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(writer)


class BundleIdentityModeTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.app = self.root / 'Community.app'
        for name in ['Helpers', 'Resources']:
            (self.app / 'Contents' / name).mkdir(parents=True)
        self.helper = self.app / 'Contents/Helpers/modelplan'
        self.helper.write_bytes(b'synthetic sealed helper; never executed')
        self.digest = hashlib.sha256(self.helper.read_bytes()).hexdigest()
        self.pin = self.app / 'Contents/Resources/modelplan.sha256'
        self.pin.write_text(self.digest + '\n')
        self.info_path = self.app / 'Contents/Info.plist'
        self.info = {'CFBundleName': 'Synthetic Community',
                     **writer.metadata('a' * 40, dict(writer.SOURCE), self.digest)}
        self.info_path.write_bytes(plistlib.dumps(self.info))
        self.arm = self.root / 'arm64'; self.arm.write_bytes(b'unverified synthetic arm64 input')
        self.intel = self.root / 'x86_64'; self.intel.write_bytes(b'unverified synthetic Intel input')

    def run_writer(self, *mode, source='b' * 40):
        return subprocess.run([sys.executable, '-B', str(WRITER), '--app', str(self.app),
                               '--public-source', source, '--arm64-input', str(self.arm),
                               '--x86-64-input', str(self.intel), *mode], capture_output=True, text=True)

    def test_default_and_explicit_release_reject_unverified_identity_without_writing(self):
        before = self.info_path.read_bytes(), self.pin.read_bytes()
        for mode in [(), ('--mode', 'release')]:
            with self.subTest(mode=mode):
                result = self.run_writer(*mode)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('unverified release/source identity', result.stderr)
                self.assertEqual((self.info_path.read_bytes(), self.pin.read_bytes()), before)

    def test_unverified_mode_clears_current_and_legacy_release_admission_fields(self):
        for legacy in [False, True]:
            with self.subTest(legacy=legacy):
                info = dict(self.info)
                if legacy:
                    info.pop('ModelPlanSourceHelperSHA256ByArchitecture')
                    info['ModelPlanSourceHelperSHA256'] = writer.SOURCE['arm64']
                self.info_path.write_bytes(plistlib.dumps(info))
                result = self.run_writer('--mode', 'unverified')
                self.assertEqual(result.returncode, 0, result.stderr)
                actual = plistlib.loads(self.info_path.read_bytes())
                self.assertEqual(actual, {'CFBundleName': 'Synthetic Community',
                                         'ModelPlanPublicSource': 'b' * 40,
                                         'ModelPlanBundledHelperSHA256': self.digest})
                self.assertEqual(self.pin.read_text(), self.digest + '\n')

    def test_unverified_mode_still_rejects_invalid_source_and_linked_inputs(self):
        self.assertNotEqual(self.run_writer('--mode', 'unverified', source='bad').returncode, 0)
        target = self.root / 'linked-input'; self.arm.rename(target); self.arm.symlink_to(target)
        result = self.run_writer('--mode', 'unverified')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('missing, linked or oversized helper', result.stderr)

    def test_only_smoke_workflow_selects_unverified_mode_and_requires_its_state(self):
        smoke = (ROOT / '.github/workflows/desktop.yml').read_text().split('  app-smoke:', 1)[1].split('  native:', 1)[0]
        release = (ROOT / '.github/workflows/macos-distribution.yml').read_text()
        def calls(text, script):
            return [shlex.split(line) for line in text.splitlines() if script in line]
        smoke_package = calls(smoke, 'tools/package-neutral.sh')
        release_package = calls(release, 'tools/package-neutral.sh')
        self.assertEqual(len(smoke_package), 1)
        self.assertIn('--unverified', smoke_package[0])
        self.assertTrue(release_package)
        self.assertTrue(all('--unverified' not in command for command in release_package))
        checker = calls(smoke, 'app-smoke/check-app-smoke.py')
        self.assertEqual(len(checker), 1)
        self.assertIn('--expect-unverified', checker[0])

    def test_smoke_artifact_is_built_from_the_exact_head_it_is_labelled_with(self):
        # A pull_request run's default checkout is the synthetic merge commit; the artifact is
        # labelled with the PR head, so the job must check that head out and refuse to publish an
        # artifact whose bundle source or checkout differs from the label (macrevb-567-5).
        smoke = (ROOT / '.github/workflows/desktop.yml').read_text().split('  app-smoke:', 1)[1].split('  native:', 1)[0]
        head = '${{ github.event.pull_request.head.sha || github.sha }}'
        checkout = smoke.split('- uses: actions/checkout@v4', 1)[1].split('- uses:', 1)[0]
        self.assertIn('ref: ' + head, checkout)
        zipping = smoke.split('Zip the packaged native app', 1)[1].split('- uses:', 1)[0]
        self.assertIn('SOURCE_SHA: ' + head, zipping)
        self.assertIn('Print :ModelPlanPublicSource', zipping)
        self.assertIn('git rev-parse HEAD', zipping)
        guard = zipping.index('"$SOURCE_SHA" ]')
        self.assertLess(guard, zipping.index('ditto -c'))  # refused before anything is zipped
        self.assertIn('name: native-app-unverified-' + head, smoke)


if __name__ == '__main__':
    unittest.main()
