# SPDX-License-Identifier: MIT
import base64
import importlib.util
from pathlib import Path
import stat
import tempfile
import unittest
from unittest.mock import patch
import zipfile
import xml.etree.ElementTree as ET

spec = importlib.util.spec_from_file_location('release_scaffold', Path(__file__).with_name('release.py'))
release = importlib.util.module_from_spec(spec); spec.loader.exec_module(release)


class ReleaseGates(unittest.TestCase):
    def configured(self):
        env = {key: 'synthetic-present-value' for key in release.SIGNING + release.NOTARY + release.SPARKLE}
        env.update(RELEASE_REQUESTED='true', GITHUB_EVENT_NAME='workflow_dispatch', GITHUB_REF='refs/heads/main')
        return env

    def test_empty_environment_skips_every_stage(self):
        plan = release.release_plan({})
        self.assertTrue(all(not stage['ready'] for stage in plan.values()))
        self.assertIn('SPARKLE_ED25519_PRIVATE_KEY', plan['appcast']['missing'])

    def test_each_missing_signing_value_blocks_entire_chain(self):
        for key in release.SIGNING:
            with self.subTest(key=key):
                env = self.configured(); del env[key]
                self.assertFalse(any(stage['ready'] for stage in release.release_plan(env).values()))

    def test_notary_and_sparkle_skip_independently(self):
        env = self.configured(); del env['APPLE_NOTARY_KEY_P8_BASE64']
        plan = release.release_plan(env)
        self.assertTrue(plan['sign']['ready']); self.assertFalse(plan['notarize']['ready']); self.assertFalse(plan['appcast']['ready'])
        env = self.configured(); del env['SPARKLE_ED25519_PRIVATE_KEY']
        plan = release.release_plan(env)
        self.assertTrue(plan['notarize']['ready']); self.assertFalse(plan['appcast']['ready'])

    def test_no_pr_tag_other_branch_or_unrequested_signing(self):
        for name, value in [('GITHUB_EVENT_NAME', 'pull_request'), ('GITHUB_REF', 'refs/tags/v1.0.0'),
                            ('GITHUB_REF', 'refs/heads/unreviewed'), ('RELEASE_REQUESTED', 'false')]:
            env = self.configured(); env[name] = value
            self.assertFalse(any(x['ready'] for x in release.release_plan(env).values()))

    def test_decisions_contain_names_but_not_values(self):
        env = self.configured(); output = str(release.release_plan(env))
        self.assertNotIn('synthetic-present-value', output)

    def test_upstream_error_does_not_echo_bad_secret(self):
        result = type('Result', (), {'returncode': 1, 'stdout': b'PRIVATE-EXAMPLE', 'stderr': b'PRIVATE-EXAMPLE'})()
        with patch.object(release.subprocess, 'run', return_value=result):
            with self.assertRaises(RuntimeError) as error:
                release.run('/fake/sign_update', '--ed-key-file', '-')
            self.assertNotIn('PRIVATE-EXAMPLE', str(error.exception))


class CandidateArchive(unittest.TestCase):
    def check(self, extra=None):
        with tempfile.TemporaryDirectory() as root:
            path = Path(root) / 'candidate.zip'
            with zipfile.ZipFile(path, 'w') as archive:
                archive.writestr('ModelPlan.app/Contents/Info.plist', 'neutral-test-only')
                if extra:
                    name, value, symlink = extra
                    item = zipfile.ZipInfo(name)
                    if symlink: item.external_attr = (stat.S_IFLNK | 0o777) << 16
                    archive.writestr(item, value)
            release.check_archive(path)

    def test_internal_framework_links_allowed(self):
        self.check(('ModelPlan.app/Contents/Frameworks/Test.framework/Versions/Current', 'A', True))

    def test_traversal_and_external_links_refused(self):
        for extra in [('../escape', 'x', False), ('/absolute', 'x', False), ('other.app/a', 'x', False),
                      ('ModelPlan.app/link', '../../outside', True), ('ModelPlan.app/link', '/private/tmp', True)]:
            with self.subTest(extra=extra), self.assertRaises(ValueError): self.check(extra)

    def test_community_bundle_cannot_become_signed_official_candidate(self):
        with tempfile.TemporaryDirectory() as root:
            app = Path(root) / 'ModelPlan.app'; resources = app / 'Contents/Resources'; resources.mkdir(parents=True)
            (resources / 'build-edition.json').write_text('{"edition":"community"}')
            (resources / 'release-provenance.json').write_text('{"sourceCommit":"' + 'a' * 40 + '"}')
            (app / 'Contents/Info.plist').write_bytes(release.plistlib.dumps({}))
            with self.assertRaisesRegex(ValueError, 'edition'): release.validate_candidate(app, 'a' * 40, 'test.bundle', 'EXAMPLE123')


class AppcastCandidate(unittest.TestCase):
    def test_signature_size_versions_escape_and_minimum_os(self):
        with tempfile.TemporaryDirectory() as root:
            archive = Path(root) / 'app.zip'; archive.write_bytes(b'synthetic archive, not an update')
            signature = base64.b64encode(bytes(64)).decode()
            info = {'CFBundleVersion': '42', 'CFBundleShortVersionString': '1.2.3 & test'}
            xml = release.appcast_bytes(info, archive, signature, 'https://example.invalid/app.zip?a=1&b=2', 'https://example.invalid/appcast.xml')
            parsed = ET.fromstring(xml); item = parsed.find('channel/item')
            self.assertEqual(item.find(f'{{{release.NS}}}version').text, '42')
            self.assertEqual(item.find(f'{{{release.NS}}}minimumSystemVersion').text, '14.0.0')
            self.assertEqual(item.find('enclosure').attrib['length'], str(archive.stat().st_size))
            self.assertIn('1.2.3 & test', item.find('title').text)

    def test_unsigned_empty_and_non_https_feed_refused(self):
        with tempfile.TemporaryDirectory() as root:
            archive = Path(root) / 'app.zip'; archive.write_bytes(b'neutral')
            info = {'CFBundleVersion': '1', 'CFBundleShortVersionString': '1.0'}
            signature = base64.b64encode(bytes(64)).decode()
            for url in ('http://example.invalid/app.zip', 'https://user:secret@example.invalid/app.zip', 'file:///tmp/app.zip'):
                with self.assertRaises(ValueError): release.appcast_bytes(info, archive, signature, url, 'https://example.invalid/feed')
            with self.assertRaises(ValueError): release.appcast_bytes(info, archive, '', 'https://example.invalid/a', 'https://example.invalid/feed')
            archive.write_bytes(b'')
            with self.assertRaises(ValueError): release.appcast_bytes(info, archive, signature, 'https://example.invalid/a', 'https://example.invalid/feed')


if __name__ == '__main__': unittest.main()
