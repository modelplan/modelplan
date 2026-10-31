#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Real throwaway Ed25519 signatures plus beta history/publication negative controls."""
import base64
from io import BytesIO
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
from urllib.error import HTTPError
import xml.etree.ElementTree as ET

import release


class BetaAppcastTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory()
        cls.addClassCleanup(cls.temporary.cleanup)
        cls.root = Path(cls.temporary.name)
        cls.archive = cls.root / 'test.zip'
        cls.archive.write_bytes(b'throwaway test archive')
        # Keys exist only during this test. No real release secret or account is used.
        if sys.platform == 'darwin':
            source = cls.root / 'sign.swift'
            source.write_text('''import CryptoKit
import Foundation
let key = Curve25519.Signing.PrivateKey()
let bytes = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
let signature = try key.signature(for: bytes)
print(key.publicKey.rawRepresentation.base64EncodedString())
print(signature.base64EncodedString())
''')
            result = subprocess.check_output(['swift', str(source), str(cls.archive)], text=True).splitlines()
            cls.public_key, cls.signature = result
        else:
            private = cls.root / 'throwaway.pem'
            subprocess.run(['openssl', 'genpkey', '-algorithm', 'Ed25519', '-out', str(private)], check=True,
                           capture_output=True)
            public = subprocess.check_output(['openssl', 'pkey', '-in', str(private), '-pubout', '-outform', 'DER'])
            cls.public_key = base64.b64encode(public[-32:]).decode()
            signature = subprocess.check_output(['openssl', 'pkeyutl', '-sign', '-rawin', '-inkey', str(private),
                                                  '-in', str(cls.archive)])
            cls.signature = base64.b64encode(signature).decode()
            private.unlink()
        cls.feed = 'https://updates.example.invalid/appcast-beta.xml'
        cls.notes = 'https://updates.example.invalid/release-notes.html'

    def appcast(self, version, previous=None, *, channel='beta', feed=None):
        return release.appcast_bytes({'CFBundleVersion': version, 'CFBundleShortVersionString': version},
                                     self.archive, self.signature, 'https://example.invalid/beta.zip',
                                     feed or self.feed, channel_name=channel, release_notes=self.notes,
                                     previous=previous)

    def test_enclosure_has_real_signature_verifiable_with_throwaway_public_key(self):
        item = ET.fromstring(self.appcast('10')).find('channel/item')
        signature = item.find('enclosure').get(f'{{{release.NS}}}edSignature')
        self.assertEqual(signature, self.signature)
        if sys.platform == 'darwin':
            # Use the production independent verifier against the serialized signature.
            with patch.dict(os.environ, {'RUNNER_TEMP': str(self.root),
                                         'SPARKLE_ED25519_PRIVATE_KEY': 'test-only-stdin'}):
                original = release.run
                def signer(*args, input=None):
                    if args[0] == '/test/sign_update':
                        return signature.encode() if '-p' in args else b''
                    return original(*args, input=input)
                with patch.object(release, 'run', side_effect=signer):
                    self.assertEqual(release.sign_archive({'SUPublicEDKey': self.public_key}, self.archive,
                                                          '/test/sign_update'), signature)
                    with self.assertRaises(RuntimeError):
                        release.sign_archive({'SUPublicEDKey': base64.b64encode(bytes(32)).decode()},
                                             self.archive, '/test/sign_update')
        else:
            public = self.root / 'public.der'
            public.write_bytes(bytes.fromhex('302a300506032b6570032100') + base64.b64decode(self.public_key))
            sig = self.root / 'signature.bin'; sig.write_bytes(base64.b64decode(signature))
            command = ['openssl', 'pkeyutl', '-verify', '-pubin', '-keyform', 'DER', '-inkey', str(public),
                       '-rawin', '-in', str(self.archive), '-sigfile', str(sig)]
            self.assertEqual(subprocess.run(command, capture_output=True).returncode, 0)
            tampered = self.root / 'tampered.zip'; tampered.write_bytes(b'changed archive')
            command[command.index(str(self.archive))] = str(tampered)
            self.assertNotEqual(subprocess.run(command, capture_output=True).returncode, 0)

    def test_numeric_version_order_history_preservation_and_rollback_refusal(self):
        history = self.appcast('9')
        history = self.appcast('10', history)
        # Even out-of-order valid old items are sorted numerically, not lexically.
        root = ET.fromstring(history); channel = root.find('channel')
        channel.append(channel.find('item')); channel.remove(channel.find('item'))
        feed = ET.fromstring(self.appcast('11.1', ET.tostring(root)))
        self.assertEqual([item.findtext(f'{{{release.NS}}}version') for item in feed.findall('channel/item')],
                         ['11.1', '10', '9'])
        for version in ('1', '9', '10', '10.0', '10.0.0'):
            with self.subTest(version=version), self.assertRaisesRegex(ValueError, 'increase'):
                self.appcast(version, history)
        for version in ('', 'beta-12', '-1', '1.2.3.4'):
            with self.subTest(version=version), self.assertRaises(ValueError):
                self.appcast(version)

    def test_beta_channel_cannot_mix_with_stable_or_other_feed(self):
        for history in (self.appcast('1', channel=None),
                        self.appcast('1', feed='https://example.invalid/stable.xml')):
            with self.assertRaises(ValueError):
                self.appcast('2', history)
        with self.assertRaises(ValueError):
            self.appcast('2', self.appcast('1'), channel=None)

    def test_unsigned_and_duplicate_history_refused(self):
        for corruption in ('signature', 'duplicate', 'length'):
            root = ET.fromstring(self.appcast('1')); channel = root.find('channel'); item = channel.find('item')
            if corruption == 'signature': item.find('enclosure').attrib.pop(f'{{{release.NS}}}edSignature')
            if corruption == 'duplicate': channel.append(item)
            if corruption == 'length': item.find('enclosure').set('length', '0')
            with self.subTest(corruption=corruption), self.assertRaises(ValueError):
                self.appcast('2', ET.tostring(root))

    def test_history_bootstrap_requires_explicit_opt_in_and_confirmed_404(self):
        output = self.root / 'history.xml'
        with patch.dict(os.environ, {'MACOS_BETA_FEED_URL': self.feed}, clear=True):
            for code, bootstrap in ((404, False), (403, True), (500, True)):
                with patch.object(release, 'urlopen', side_effect=HTTPError(self.feed, code, 'test', {}, None)):
                    with self.assertRaises(ValueError):
                        release.fetch_beta_history(output, bootstrap=bootstrap)
            with patch.object(release, 'urlopen', side_effect=HTTPError(self.feed, 404, 'test', {}, None)):
                release.fetch_beta_history(output, bootstrap=True)
            self.assertEqual(release.previous_beta_items(output.read_bytes(), self.feed), [])
            with patch.object(release, 'urlopen', return_value=BytesIO(self.appcast('1'))):
                release.fetch_beta_history(output)
            self.assertEqual(len(release.previous_beta_items(output.read_bytes(), self.feed)), 1)


class FailClosedTests(unittest.TestCase):
    def test_workflow_keeps_keys_out_of_pr_and_publication_jobs(self):
        workflow = (Path(__file__).resolve().parents[4] / '.github/workflows/macos-distribution.yml').read_text()
        jobs = dict(re.findall(r'^  ([a-z-]+):\n(.*?)(?=^  [a-z-]+:\n|\Z)',
                               workflow.split('\njobs:\n', 1)[1], re.MULTILINE | re.DOTALL))
        self.assertNotIn('secrets.', jobs['neutral-build'])
        self.assertNotIn('environment:', jobs['neutral-build'])
        for name in ('release-candidate', 'adhoc-beta-candidate', 'publish-beta-draft'):
            guard = re.search(r'^    if: (.*)$', jobs[name], re.MULTILINE).group(1)
            for required in ("github.event_name == 'workflow_dispatch'", "github.ref == 'refs/heads/main'",
                             "github.repository == 'modelplan/modelplan'"):
                self.assertIn(required, guard)
            self.assertIn('environment: macos-release', jobs[name])
        self.assertIn("vars.MACOS_DEVELOPER_ID_ENABLED == 'true'", jobs['release-candidate'])
        self.assertIn('needs: adhoc-beta-candidate', jobs['publish-beta-draft'])
        self.assertNotIn('secrets.', jobs['publish-beta-draft'])
        beta = jobs['adhoc-beta-candidate']
        self.assertEqual(set(re.findall(r'secrets\.([A-Z0-9_]+)', beta)), {'SPARKLE_ED25519_PRIVATE_KEY'})
        self.assertIn('contents: read', beta)
        self.assertNotIn('contents: write', beta)
        self.assertIn('shell: bash', beta.split('id: gates', 1)[1].split('- name:', 1)[0])
        self.assertIn('--previous-appcast', beta)

    def test_requested_beta_without_key_fails_plan_command_with_clear_setting_name(self):
        with tempfile.TemporaryDirectory() as root:
            env = {name: 'synthetic-setting' for name in release.ADHOC_BETA}
            env.update(GITHUB_EVENT_NAME='workflow_dispatch', GITHUB_REF='refs/heads/main',
                       GITHUB_REPOSITORY='modelplan/modelplan', ADHOC_BETA_REQUESTED='true',
                       GITHUB_OUTPUT=str(Path(root) / 'outputs'))
            for value in ('', '   '):
                env['SPARKLE_ED25519_PRIVATE_KEY'] = value
                result = subprocess.run([sys.executable, str(Path(release.__file__)), 'plan'], env=env,
                                        capture_output=True, text=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('SPARKLE_ED25519_PRIVATE_KEY', result.stderr)
                self.assertIn('GitHub environment', result.stderr)
                self.assertNotIn('synthetic-setting', result.stdout + result.stderr)

    def test_beta_generation_refuses_missing_key_before_reading_app_or_running_tool(self):
        with patch.dict(os.environ, {'GITHUB_EVENT_NAME': 'workflow_dispatch', 'GITHUB_REF': 'refs/heads/main',
                                    'GITHUB_REPOSITORY': 'modelplan/modelplan', 'ADHOC_BETA_REQUESTED': 'true'},
                        clear=True), patch.object(release, 'run') as command:
            with self.assertRaisesRegex(release.ConfigurationError, 'SPARKLE_ED25519_PRIVATE_KEY'):
                release.adhoc_appcast('/absent/app', '/absent/output', '/absent/tool')
            command.assert_not_called()


class DraftPublicationTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(); self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        archive = self.root / 'ModelPlan-beta-universal.zip'; archive.write_bytes(b'synthetic')
        base = 'https://github.com/modelplan/modelplan/releases/download/macos-beta-42/'
        xml = release.appcast_bytes({'CFBundleVersion': '42', 'CFBundleShortVersionString': '0.1 beta'},
                                    archive, base64.b64encode(bytes(64)).decode(), base + archive.name,
                                    'https://example.invalid/appcast-beta.xml', channel_name='beta',
                                    release_notes=base + 'release-notes.html')
        (self.root / 'appcast-beta.xml').write_bytes(xml)
        for name in ('RELEASE_NOTES.md', 'release-notes.html'):
            (self.root / name).write_text('synthetic notes')
        self.metadata = {'draft': True, 'prerelease': True, 'target_commitish': 'a' * 40,
                         'tag_name': 'macos-beta-42', 'name': 'ModelPlan beta'}
        self.write_metadata(); self.write_checksums()
        environment = patch.dict(os.environ, {'GITHUB_EVENT_NAME': 'workflow_dispatch',
                                              'GITHUB_REF': 'refs/heads/main',
                                              'GITHUB_REPOSITORY': 'modelplan/modelplan', 'GITHUB_SHA': 'a' * 40,
                                              'GH_TOKEN': 'synthetic-github-token',
                                              'SPARKLE_ED25519_PRIVATE_KEY': 'must-not-reach-publisher'}, clear=True)
        environment.start(); self.addCleanup(environment.stop)

    def write_metadata(self):
        (self.root / 'draft-release.json').write_text(json.dumps(self.metadata))

    def write_checksums(self):
        names = ('ModelPlan-beta-universal.zip', 'appcast-beta.xml', 'RELEASE_NOTES.md', 'release-notes.html')
        (self.root / 'SHA256SUMS').write_text(''.join(f'{release.sha256(self.root / name)}  {name}\n' for name in names))

    def test_publication_only_creates_draft_prerelease_never_latest_or_overwrites(self):
        with patch.object(release.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0)) as command:
            release.publish_beta(self.root)
        args = command.call_args.args[0]
        self.assertEqual(args[:4], ['gh', 'release', 'create', 'macos-beta-42'])
        for flag in ('--draft', '--prerelease', '--latest=false'):
            self.assertIn(flag, args)
        self.assertEqual(command.call_args.kwargs['env']['GH_TOKEN'], 'synthetic-github-token')
        self.assertNotIn('SPARKLE_ED25519_PRIVATE_KEY', command.call_args.kwargs['env'])
        with patch.object(release.subprocess, 'run', return_value=subprocess.CompletedProcess([], 1)):
            with self.assertRaisesRegex(RuntimeError, 'never overwritten'):
                release.publish_beta(self.root)

    def test_stable_release_wrong_tag_commit_or_untrusted_trigger_refused(self):
        for name, value in (('draft', False), ('prerelease', False), ('tag_name', 'v42'),
                            ('target_commitish', 'b' * 40)):
            original = self.metadata[name]; self.metadata[name] = value; self.write_metadata()
            with self.subTest(name=name), patch.object(release.subprocess, 'run') as command:
                with self.assertRaises(ValueError): release.publish_beta(self.root)
                command.assert_not_called()
            self.metadata[name] = original; self.write_metadata()
        for name, value in (('GITHUB_EVENT_NAME', 'pull_request'), ('GITHUB_REF', 'refs/heads/topic'),
                            ('GITHUB_REPOSITORY', 'fork/modelplan')):
            with patch.dict(os.environ, {name: value}), patch.object(release.subprocess, 'run') as command:
                with self.assertRaises(release.ConfigurationError): release.publish_beta(self.root)
                command.assert_not_called()

    def test_changed_archive_or_wrong_final_download_url_refused(self):
        path = self.root / 'appcast-beta.xml'
        path.write_bytes(path.read_bytes().replace(b'macos-beta-42/', b'v42/'))
        self.write_checksums()
        with patch.object(release.subprocess, 'run') as command:
            with self.assertRaisesRegex(ValueError, 'URLs'): release.publish_beta(self.root)
            command.assert_not_called()
        (self.root / 'ModelPlan-beta-universal.zip').write_bytes(b'tampered')
        # Restore the URLs; the changed archive must still fail the checksum check.
        path.write_bytes(path.read_bytes().replace(b'v42/', b'macos-beta-42/'))
        with patch.object(release.subprocess, 'run') as command:
            with self.assertRaisesRegex(ValueError, 'checksum'): release.publish_beta(self.root)
            command.assert_not_called()


if __name__ == '__main__':
    unittest.main()
