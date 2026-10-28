# SPDX-License-Identifier: MIT
import base64
import importlib.util
import itertools
import json
import plistlib
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
        env.update(RELEASE_REQUESTED='true', GITHUB_EVENT_NAME='workflow_dispatch', GITHUB_REF='refs/heads/main',
                   GITHUB_REPOSITORY='modelplan/modelplan')
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
                            ('GITHUB_REF', 'refs/heads/unreviewed'), ('GITHUB_REPOSITORY', 'fork/modelplan'),
                            ('RELEASE_REQUESTED', 'false')]:
            env = self.configured(); env[name] = value
            self.assertFalse(any(x['ready'] for x in release.release_plan(env).values()))

    def test_all_signed_stage_dependency_combinations(self):
        names = tuple(dict.fromkeys(release.SIGNING + release.NOTARY + release.SPARKLE))
        for present in itertools.product((False, True), repeat=len(names)):
            env = self.configured()
            for name, exists in zip(names, present):
                if not exists:
                    del env[name]
            plan = release.release_plan(env)
            for stage, required in [('sign', release.SIGNING), ('notarize', release.SIGNING + release.NOTARY),
                                    ('appcast', release.SIGNING + release.NOTARY + release.SPARKLE)]:
                self.assertEqual(plan[stage]['ready'], all(name in env for name in required), (stage, present))
            self.assertFalse(plan['adhoc_appcast']['ready'])

    def test_decisions_contain_names_but_not_values(self):
        env = self.configured(); output = str(release.release_plan(env))
        self.assertNotIn('synthetic-present-value', output)

    def test_upstream_error_does_not_echo_bad_secret(self):
        result = type('Result', (), {'returncode': 1, 'stdout': b'PRIVATE-EXAMPLE', 'stderr': b'PRIVATE-EXAMPLE'})()
        with patch.object(release.subprocess, 'run', return_value=result):
            with self.assertRaises(RuntimeError) as error:
                release.run('/fake/sign_update', '--ed-key-file', '-')
            self.assertNotIn('PRIVATE-EXAMPLE', str(error.exception))


class AdhocBetaGates(unittest.TestCase):
    def configured(self):
        env = {name: 'synthetic-present-value' for name in release.ADHOC_BETA}
        env.update(ADHOC_BETA_REQUESTED='true', GITHUB_EVENT_NAME='workflow_dispatch',
                   GITHUB_REF='refs/heads/main', GITHUB_REPOSITORY='modelplan/modelplan')
        return env

    def test_every_combination_of_required_settings(self):
        for present in itertools.product((False, True), repeat=len(release.ADHOC_BETA)):
            with self.subTest(present=present):
                env = self.configured()
                missing = [name for name, exists in zip(release.ADHOC_BETA, present) if not exists]
                for name in missing:
                    del env[name]
                plan = release.release_plan(env)
                self.assertEqual(plan['adhoc_appcast']['ready'], not missing)
                self.assertEqual(plan['adhoc_appcast']['missing'], missing)
                self.assertFalse(any(plan[name]['ready'] for name in ('sign', 'notarize', 'appcast')))
                self.assertNotIn('synthetic-present-value', str(plan))

    def test_whitespace_settings_are_missing(self):
        for name in release.ADHOC_BETA:
            env = self.configured(); env[name] = '  '
            self.assertEqual(release.release_plan(env)['adhoc_appcast']['missing'], [name])

    def test_beta_is_independent_of_apple_and_official_feed_configuration(self):
        env = self.configured()
        for name in release.SIGNING + release.NOTARY:
            if name not in release.ADHOC_BETA:
                env.pop(name, None)
        self.assertTrue(release.release_plan(env)['adhoc_appcast']['ready'])
        env.update(ReleaseGates().configured())
        self.assertTrue(all(stage['ready'] for stage in release.release_plan(env).values()))
        for name in release.SIGNING + release.NOTARY:
            if name not in release.ADHOC_BETA:
                without = dict(env); del without[name]
                self.assertTrue(release.release_plan(without)['adhoc_appcast']['ready'])
                self.assertFalse(release.release_plan(without)['appcast']['ready'])

    def test_trusted_main_dispatch_and_explicit_beta_request_required(self):
        for name, value in [('GITHUB_EVENT_NAME', 'pull_request'), ('GITHUB_EVENT_NAME', 'push'),
                            ('GITHUB_REF', 'refs/tags/v1.0.0'), ('GITHUB_REF', 'refs/heads/topic'),
                            ('GITHUB_REPOSITORY', 'fork/modelplan'), ('GITHUB_REPOSITORY', ''),
                            ('ADHOC_BETA_REQUESTED', 'false')]:
            env = self.configured(); env[name] = value
            self.assertFalse(release.release_plan(env)['adhoc_appcast']['ready'])
        env = self.configured(); del env['ADHOC_BETA_REQUESTED']; env['RELEASE_REQUESTED'] = 'true'
        self.assertFalse(release.release_plan(env)['adhoc_appcast']['ready'])

    def test_feed_files_must_be_distinct_even_with_url_aliases(self):
        for official in ['https://updates.example.invalid/beta.xml',
                         'https://UPDATES.example.invalid:443/beta.xml',
                         'https://updates.example.invalid/a/../beta.xml',
                         'https://updates.example.invalid/%62eta.xml?channel=stable']:
            with self.subTest(official=official), self.assertRaisesRegex(ValueError, 'separate files'):
                release.beta_feed_url({'MACOS_BETA_FEED_URL': 'https://updates.example.invalid/beta.xml',
                                       'MACOS_FEED_URL': official})
        env = {'MACOS_BETA_FEED_URL': 'https://updates.example.invalid/beta.xml'}
        self.assertEqual(release.beta_feed_url(env), env['MACOS_BETA_FEED_URL'])
        env['MACOS_FEED_URL'] = 'https://updates.example.invalid/stable.xml'
        self.assertEqual(release.beta_feed_url(env), env['MACOS_BETA_FEED_URL'])


class AdhocBetaCandidate(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.app = self.root / 'ModelPlan.app'
        self.resources = self.app / 'Contents/Resources'; self.resources.mkdir(parents=True)
        self.helper = self.app / 'Contents/Helpers/modelplan'; self.helper.parent.mkdir()
        self.helper.write_bytes(b'synthetic universal helper')
        executable = self.app / 'Contents/MacOS/ModelPlan'; executable.parent.mkdir()
        executable.write_bytes(b'synthetic universal executable')
        self.output = self.root / 'payload'
        self.info = {'CFBundleIdentifier': 'test.modelplan', 'CFBundleExecutable': 'ModelPlan',
                     'CFBundleVersion': '42', 'CFBundleShortVersionString': '0.1 & beta',
                     'LSMinimumSystemVersion': '14.0', 'SUFeedURL': 'https://example.invalid/beta.xml',
                     'SUPublicEDKey': base64.b64encode(bytes(32)).decode()}
        self.write_info()
        (self.resources / 'build-edition.json').write_text(json.dumps({'edition': 'official'}))
        (self.resources / 'release-provenance.json').write_text(json.dumps({'sourceCommit': 'a' * 40}))
        (self.resources / 'modelplan.sha256').write_text(release.sha256(self.helper) + '\n')
        for name in ('LICENSE.txt', 'CLI-THIRD-PARTY-NOTICES.md', 'VISUAL-LICENSE.md'):
            (self.resources / name).write_text('synthetic notice')
        self.env = dict(AdhocBetaGates().configured(), GITHUB_SHA='a' * 40, RUNNER_TEMP=str(self.root),
                        MACOS_BUNDLE_ID='test.modelplan', MACOS_BETA_FEED_URL=self.info['SUFeedURL'],
                        MACOS_FEED_URL='https://example.invalid/stable.xml',
                        MACOS_UPDATE_URL='https://example.invalid/ModelPlan-beta-universal.zip',
                        MACOS_RELEASE_NOTES_URL='https://example.invalid/notes/42')
        environment = patch.dict(release.os.environ, self.env, clear=True)
        environment.start(); self.addCleanup(environment.stop)
        self.calls = []
        self.signature = base64.b64encode(bytes(64)).decode()

    def write_info(self):
        (self.app / 'Contents/Info.plist').write_bytes(plistlib.dumps(self.info))

    def fake_run(self, *args, input=None):
        self.calls.append((args, input))
        if args[:3] == ('xcrun', 'lipo', '-archs'):
            return b'arm64 x86_64'
        if args[:5] == ('codesign', '--force', '--deep', '--sign', '-'):
            self.helper.write_bytes(b'synthetic helper changed by deep signing')
        if args[0] == 'ditto':
            Path(args[-1]).write_bytes(b'synthetic zip; not an installable app')
        if '-p' in args:
            return self.signature.encode()
        return b''

    def prepare(self):
        return release.adhoc_appcast(self.app, self.output, '/fake/sign_update')

    def test_payload_signing_order_integrity_xml_and_draft_metadata(self):
        with patch.object(release, 'run', side_effect=self.fake_run):
            self.prepare()
        commands = [args for args, _ in self.calls]
        sign = commands.index(('codesign', '--force', '--deep', '--sign', '-', str(self.app)))
        seal = commands.index(('codesign', '--force', '--sign', '-', str(self.app)))
        verify = commands.index(('codesign', '--verify', '--deep', '--strict', str(self.app)))
        archive = self.output / 'ModelPlan-beta-universal.zip'
        zip_index = commands.index(('ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', str(self.app), str(archive)))
        self.assertLess(sign, seal); self.assertLess(seal, verify); self.assertLess(verify, zip_index)
        self.assertEqual((self.resources / 'modelplan.sha256').read_text().strip(), release.sha256(self.helper))
        self.assertIn(('/fake/sign_update', '--ed-key-file', '-', '--verify', str(archive), self.signature), commands)
        swift = next(args for args in commands if args[0] == 'swift')
        self.assertEqual(swift[-3:], (self.info['SUPublicEDKey'], self.signature, str(archive)))
        for args, data in self.calls:
            self.assertNotIn(self.env['SPARKLE_ED25519_PRIVATE_KEY'], args)

            if args[0] == '/fake/sign_update':
                self.assertEqual(data, self.env['SPARKLE_ED25519_PRIVATE_KEY'].encode() + b'\n')
        xml = ET.parse(self.output / 'appcast-beta.xml')
        item = xml.find('channel/item')
        self.assertEqual(xml.find('channel/link').text, self.env['MACOS_BETA_FEED_URL'])
        self.assertEqual(item.find(f'{{{release.NS}}}channel').text, 'beta')
        self.assertEqual(item.find(f'{{{release.NS}}}minimumSystemVersion').text, '14.0.0')
        self.assertEqual(item.find(f'{{{release.NS}}}releaseNotesLink').text, self.env['MACOS_RELEASE_NOTES_URL'])
        self.assertEqual(item.find('enclosure').attrib[f'{{{release.NS}}}edSignature'], self.signature)
        self.assertEqual(item.find('enclosure').attrib['url'], self.env['MACOS_UPDATE_URL'])
        self.assertEqual(item.find('enclosure').attrib['length'], str(archive.stat().st_size))
        manifest = json.loads((self.output / 'draft-release.json').read_text())
        self.assertIs(manifest['draft'], True); self.assertIs(manifest['prerelease'], True)
        self.assertEqual(manifest['target_commitish'], self.env['GITHUB_SHA'])
        for line in (self.output / 'SHA256SUMS').read_text().splitlines():
            checksum, name = line.split('  ')
            self.assertEqual(checksum, release.sha256(self.output / name))
        self.assertEqual({path.name for path in self.output.iterdir()},
                         {'ModelPlan-beta-universal.zip', 'appcast-beta.xml', 'SHA256SUMS', 'draft-release.json'})

    def test_invalid_candidate_is_refused_before_signing_or_output(self):
        # Exercise the real shared validation rather than replacing it with a successful stub.
        invalid = [('CFBundleIdentifier', 'wrong.bundle'), ('LSMinimumSystemVersion', '13.0'),
                   ('CFBundleVersion', 'not-a-build'), ('SUPublicEDKey', ''),
                   ('SUFeedURL', self.env['MACOS_FEED_URL'])]
        for key, value in invalid:
            with self.subTest(key=key):
                original = self.info[key]; self.info[key] = value; self.write_info()
                with patch.object(release, 'run', side_effect=self.fake_run), self.assertRaises(ValueError):
                    self.prepare()
                self.assertFalse(self.output.exists())
                self.assertFalse(any(args[0] == 'codesign' for args, _ in self.calls))
                self.info[key] = original; self.write_info(); self.calls.clear()
        for name, invalid_text in [('build-edition.json', '{"edition":"community"}'),
                                   ('release-provenance.json', '{"sourceCommit":"wrong"}'),
                                   ('modelplan.sha256', 'incorrect')]:
            with self.subTest(name=name):
                path = self.resources / name; original = path.read_text(); path.write_text(invalid_text)
                with patch.object(release, 'run', side_effect=self.fake_run), self.assertRaises(ValueError):
                    self.prepare()
                self.assertFalse(self.output.exists()); self.assertEqual(self.calls, [])
                path.write_text(original)
        (self.resources / 'VISUAL-LICENSE.md').unlink()
        with patch.object(release, 'run') as command, self.assertRaises(ValueError):
            self.prepare()
        command.assert_not_called()

    def test_nonuniversal_candidate_is_refused(self):
        with patch.object(release, 'run', return_value=b'arm64'), self.assertRaisesRegex(ValueError, 'universal'):
            self.prepare()
        self.assertFalse(self.output.exists())

    def test_signed_path_still_requires_valid_team(self):
        with patch.object(release, 'run', side_effect=self.fake_run), self.assertRaisesRegex(ValueError, 'source/team'):
            release.validate_candidate(self.app, self.env['GITHUB_SHA'], self.env['MACOS_BUNDLE_ID'], '',
                                       feed=self.env['MACOS_BETA_FEED_URL'])

    def test_equal_feed_files_refused_before_validation_or_signing(self):
        with patch.dict(release.os.environ, {'MACOS_FEED_URL': self.env['MACOS_BETA_FEED_URL']}):
            with patch.object(release, 'validate_candidate') as validate, patch.object(release, 'run') as command:
                with self.assertRaisesRegex(ValueError, 'separate files'):
                    self.prepare()
                validate.assert_not_called(); command.assert_not_called()
        self.assertFalse(self.output.exists())

    def test_notarized_appcast_also_refuses_the_beta_feed_file(self):
        with patch.dict(release.os.environ, {'MACOS_FEED_URL': self.env['MACOS_BETA_FEED_URL']}):
            with patch.object(release, 'sign_archive') as sign, self.assertRaisesRegex(ValueError, 'separate files'):
                release.appcast(self.app, self.output, '/fake/sign_update')
            sign.assert_not_called()
        self.assertFalse(self.output.exists())

    def test_non_https_beta_urls_are_refused_before_signing(self):
        for name in ('MACOS_BETA_FEED_URL', 'MACOS_UPDATE_URL', 'MACOS_RELEASE_NOTES_URL'):
            with self.subTest(name=name), patch.dict(release.os.environ, {name: 'http://example.invalid/file'}):
                with patch.object(release, 'run') as command, self.assertRaises(ValueError):
                    self.prepare()
                command.assert_not_called()
                self.assertFalse(self.output.exists())

    def test_failed_signature_verification_never_creates_manifest_or_appcast(self):
        def fail_verification(*args, input=None):
            if args[0] == 'swift':
                raise RuntimeError('synthetic public-key mismatch')
            return self.fake_run(*args, input=input)
        with patch.object(release, 'run', side_effect=fail_verification), self.assertRaises(RuntimeError):
            self.prepare()
        self.assertFalse((self.output / 'draft-release.json').exists())
        self.assertFalse((self.output / 'appcast-beta.xml').exists())


    def test_resigning_refreshes_info_and_resource_pin_together(self):
        self.info.update(ModelPlanHelperVersion='0.5.43',
                         ModelPlanSourceHelperSHA256='a' * 64,
                         ModelPlanBundledHelperSHA256=release.sha256(self.helper))
        self.write_info()
        with patch.object(release, 'run', side_effect=self.fake_run):
            self.prepare()
        info = plistlib.loads((self.app / 'Contents/Info.plist').read_bytes())
        self.assertEqual(info['ModelPlanBundledHelperSHA256'], release.sha256(self.helper))
        self.assertEqual((self.resources / 'modelplan.sha256').read_text().strip(), info['ModelPlanBundledHelperSHA256'])
        self.assertEqual(info['ModelPlanSourceHelperSHA256'], 'a' * 64)
        self.assertEqual(info['ModelPlanHelperVersion'], '0.5.43')


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
            self.assertIsNone(item.find(f'{{{release.NS}}}channel'))
            self.assertIsNone(item.find(f'{{{release.NS}}}releaseNotesLink'))
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
