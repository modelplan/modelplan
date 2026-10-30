# SPDX-License-Identifier: MIT
import json
import os
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'tools/u10'))
import package_candidate as packaging

PIN = json.loads((ROOT / 'desktop/native/consent-cli-pin.json').read_text())


class PackagingTests(unittest.TestCase):
    def setUp(self):
        scratch = ROOT / '.tmp'
        scratch.mkdir(exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(dir=scratch)
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.app = self.root / 'ModelPlan.app'
        for folder in ('Helpers', 'Resources', 'MacOS'):
            (self.app / 'Contents' / folder).mkdir(parents=True)
        self.helper = self.app / 'Contents/Helpers/modelplan'
        self.helper.write_bytes(b'synthetic universal helper before signature')
        self.info_path = self.app / 'Contents/Info.plist'
        self.info_path.write_bytes(plistlib.dumps({'CFBundleIdentifier': packaging.BUNDLE_ID}))
        self.raw = {}
        for arch in ('arm64', 'x86_64'):
            self.raw[arch] = self.root / arch
            self.raw[arch].write_bytes(('synthetic released ' + arch).encode())
        self.hashes = {arch: packaging.identity.digest_file(p) for arch, p in self.raw.items()}
        self.source = 'a' * 40
        self.commands = []

    def command(self, *args):
        args = [str(a) for a in args]
        self.commands.append(args)
        if args[0] == 'codesign' and '--force' in args and args[-1] == str(self.helper):
            self.helper.write_bytes(b'synthetic helper bytes AFTER signing')
        elif args[0] == sys.executable:
            # Exercise the canonical producer's metadata function with synthetic release inputs.
            self.assertIn('--mode', args)
            self.assertEqual(args[args.index('--mode') + 1], 'release')
            info = plistlib.loads(self.info_path.read_bytes())
            for key in ('ModelPlanSourceHelperSHA256', 'ModelPlanHelperVersion',
                        'ModelPlanSourceHelperSHA256ByArchitecture'):
                info.pop(key, None)
            sealed = packaging.identity.digest_file(self.helper)
            info.update(packaging.identity.metadata(self.source, self.hashes, sealed))
            self.info_path.write_bytes(plistlib.dumps(info))
            (self.app / 'Contents/Resources/modelplan.sha256').write_text(sealed + '\n')
        return b''

    def seal(self, command=None):
        with patch.object(packaging.identity, 'SOURCE', self.hashes):
            return packaging.seal(self.app, self.source, self.raw, command or self.command)

    def test_helper_is_sealed_before_identity_and_outer_app(self):
        before = packaging.identity.digest_file(self.helper)
        result = self.seal()
        after = packaging.identity.digest_file(self.helper)
        self.assertNotEqual(before, after)
        self.assertEqual(result['ModelPlanBundledHelperSHA256'], after)
        self.assertEqual(result['ModelPlanHelperVersion'], PIN['version'])
        self.assertEqual(result['ModelPlanSourceHelperSHA256ByArchitecture'], self.hashes)
        self.assertEqual(self.commands[0][-1], str(self.helper))
        self.assertEqual(self.commands[1][0], sys.executable)
        self.assertEqual(self.commands[2][-1], str(self.app))
        self.assertNotIn('--deep', self.commands[0])
        self.assertNotIn('--deep', self.commands[2])
        self.assertEqual(self.commands[-1][1:4], ['--verify', '--deep', '--strict'])
        self.assertEqual((self.app / 'Contents/Resources/modelplan.sha256').read_text(), after + '\n')

    def test_previous_or_modified_raw_release_fails_before_signing(self):
        with self.assertRaisesRegex(ValueError, 'unverified release'):
            packaging.seal(self.app, self.source, self.raw, self.command)
        self.assertEqual(self.commands, [])
        with patch.object(packaging.identity, 'SOURCE', self.hashes):
            self.raw['arm64'].write_bytes(b'previous release')
            with self.assertRaises(ValueError):
                packaging.seal(self.app, self.source, self.raw, self.command)
        self.assertEqual(self.commands, [])

    def test_helper_mutation_after_outer_seal_is_rejected(self):
        def tamper(*args):
            result = self.command(*args)
            if str(args[0]) == 'codesign' and '--force' in args and args[-1] == self.app:
                self.helper.write_bytes(b'late mutation')
            return result
        with self.assertRaisesRegex(ValueError, 'identity mismatch'):
            self.seal(tamper)

    def test_resource_hash_and_source_identity_mismatch_are_rejected(self):
        self.seal()
        (self.app / 'Contents/Resources/modelplan.sha256').write_text('0' * 64 + '\n')
        with patch.object(packaging.identity, 'SOURCE', self.hashes):
            with self.assertRaisesRegex(ValueError, 'resource hash mismatch'):
                packaging.verify_identity(self.app, self.source, self.hashes)
            with self.assertRaisesRegex(ValueError, 'identity mismatch'):
                packaging.verify_identity(self.app, 'b' * 40, self.hashes)

    def test_linked_input_and_resource_trees_fail_closed(self):
        self.raw['arm64'].unlink()
        self.raw['arm64'].symlink_to(self.raw['x86_64'])
        with self.assertRaises(ValueError):
            self.seal()
        folder = self.root / 'resources'
        folder.mkdir()
        (folder / 'escape').symlink_to(self.raw['x86_64'])
        with self.assertRaises(ValueError):
            packaging.copy_tree(folder, self.root / 'copied')

    def test_public_resources_include_separate_visual_and_ofl_notices_and_placeholder(self):
        receipt = packaging.stage_resources(self.app)
        self.assertEqual(receipt['cockpit'], 'placeholder')
        r = self.app / 'Contents/Resources'
        self.assertIn('U10 interface placeholder', (r / 'Cockpit/index.html').read_text())
        self.assertTrue((r / 'VISUAL-LICENSE.md').is_file())
        for family in ('manrope', 'dm-sans', 'jetbrains-mono', 'share-tech-mono'):
            self.assertTrue((r / 'ThirdParty/fonts' / family / 'OFL.txt').is_file())
        self.assertTrue((r / 'ThirdParty/licenses/pulse/THIRD_PARTY_NOTICES.md').is_file())
        self.assertNotEqual(receipt['fonts']['sha256'], receipt['officialVisuals']['sha256'])
        self.assertEqual((r / 'OfficialVisuals/runtime/manifest.json').read_bytes(),
                         (ROOT / 'desktop/official-visuals/runtime/manifest.json').read_bytes())

    def test_u11_public_dist_is_consumed_without_running_code(self):
        public = self.root / 'public'
        # Other resource inputs come from reviewed public files; only the cockpit seam varies.
        import shutil
        shutil.copytree(ROOT / 'desktop/official-visuals', public / 'desktop/official-visuals')
        shutil.copytree(ROOT / 'desktop/third-party', public / 'desktop/third-party')
        cockpit = public / 'desktop/cockpit/dist'
        cockpit.mkdir(parents=True)
        (cockpit / 'index.html').write_text('<p>synthetic U11 built bundle</p>')
        receipt = packaging.stage_resources(self.app, public)
        self.assertEqual(receipt['cockpit'], 'bundled-interface-only')
        self.assertEqual((self.app / 'Contents/Resources/Cockpit/index.html').read_bytes(),
                         (cockpit / 'index.html').read_bytes())

    def test_u14_manifest_binds_final_app_helper_sources_and_archive_evidence(self):
        self.seal()
        r = self.app / 'Contents/Resources/OfficialVisuals/runtime'
        r.mkdir(parents=True)
        (r / 'manifest.json').write_text('{"synthetic":true}')
        repo = self.root / 'repo'
        repo.mkdir()
        subprocess.run(['git', 'init', '-q', str(repo)], check=True)
        subprocess.run(['git', '-C', str(repo), '-c', 'user.name=Test', '-c', 'user.email=test@example.invalid',
                        'commit', '--allow-empty', '-qm', 'Synthetic candidate source'], check=True)
        source = packaging.git(repo, 'rev-parse', 'HEAD')
        receipt = {'sourceCommit': source, 'archive': {'file': 'candidate.zip', 'sha256': 'b' * 64}}
        result = packaging.evidence(self.app, self.root, repo, 'synthetic-candidate', receipt)
        self.assertEqual(result['artifacts']['app'], packaging.artifact(self.app, allow_tree=True))
        self.assertEqual(result['artifacts']['helper']['sha256'], packaging.identity.digest_file(self.helper))
        self.assertEqual(result['sources'], [{'repository': 'modelplan/modelplan', 'sha': source, 'dirty': False}])
        self.assertEqual(result['artifacts']['helperVersion'], PIN['version'])
        self.assertEqual(result['publicationData']['state'], 'unsupported')
        self.assertTrue(all(s['outcome'] in ('unsupported', 'not-run') for s in result['scenarios']))
        self.assertEqual(result['checks'][0]['id'], 'U10-packaging-identity')
        blob = self.root / 'evidence' / result['checks'][0]['evidence'][0]['ref']
        self.assertEqual(json.loads(blob.read_text())['archive'], receipt['archive'])
        with self.assertRaises(ValueError):
            packaging.evidence(self.app, self.root, repo, 'synthetic-candidate', receipt)

    def test_product_identity_uses_declared_version_and_rejects_invalid_build(self):
        packaging.configure_product(self.app, self.source, '123')
        info = plistlib.loads(self.info_path.read_bytes())
        self.assertEqual(info['CFBundleIdentifier'], 'ai.modelplan.candidate')
        self.assertEqual(info['CFBundleShortVersionString'], json.loads((ROOT / 'desktop/package.json').read_text())['version'])
        self.assertEqual(info['CFBundleVersion'], '123')
        for value in ('0', '-1', '1.2', 'abc'):
            with self.assertRaises(ValueError):
                packaging.configure_product(self.app, self.source, value)

    def test_final_candidate_check_requires_the_external_credential_pin(self):
        calls = []
        with patch.dict(os.environ, {}, clear=True):
            with self.assertRaisesRegex(ValueError, 'independent SHA256'):
                packaging.verify_credential_helper(self.app, lambda *args: calls.append(args))
        self.assertEqual(calls, [])
        with patch.dict(os.environ, {'MODELPLAN_CREDENTIAL_AGENT_ARTIFACT': str(self.root),
                                     'MODELPLAN_CREDENTIAL_AGENT_SHA256': 'c' * 64}):
            packaging.verify_credential_helper(self.app, lambda *args: calls.append(list(map(str, args))))
            args = calls[-1]
            self.assertIn('--single', args)
            self.assertEqual(args[args.index('--expected-sha256') + 1], 'c' * 64)
            self.assertEqual(args[-1], str(self.app))
            def reject(*args):
                raise subprocess.CalledProcessError(1, args)
            with self.assertRaises(subprocess.CalledProcessError):
                packaging.verify_credential_helper(self.app, reject)

    def test_missing_approved_credential_input_stops_before_cli_fetch_or_build(self):
        with patch.object(packaging.platform, 'system', return_value='Darwin'), \
             patch.object(packaging, 'git', side_effect=['a' * 40, '']), \
             patch.object(packaging, 'load_json', return_value={'version': packaging.HELPER_VERSION}), \
             patch.object(packaging.credential_artifact, 'acquire', side_effect=ValueError('approval missing')), \
             patch.object(packaging.release, 'fetch_cli') as cli_fetch, \
             patch.object(packaging, 'run') as build:
            with self.assertRaisesRegex(ValueError, 'approval missing'):
                packaging.build(self.root / 'missing-approved-artifact', 'synthetic-candidate', '1')
            cli_fetch.assert_not_called()
            build.assert_not_called()

    def test_linux_cannot_claim_a_real_mac_package(self):
        with patch.object(packaging.platform, 'system', return_value='Linux'):
            with self.assertRaisesRegex(ValueError, 'requires macOS'):
                packaging.build(self.root / 'out', 'candidate', '1')


if __name__ == '__main__':
    unittest.main()
