# SPDX-License-Identifier: MIT
import hashlib
import importlib.util
import json
import plistlib
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

PATH = Path(__file__).with_name('check_cli_pin_consistency.py')
spec = importlib.util.spec_from_file_location('cli_pin_consistency', PATH)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class SyntheticRepo:
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.repo = Path(self.tmp.name)
        self.git('init', '-q')
        self.git('config', 'user.email', 'synthetic@example.invalid')
        self.git('config', 'user.name', 'Synthetic')
        (self.repo / 'cli').mkdir()
        (self.repo / 'cli' / 'source.go').write_text('one\n')
        self.pin = self.repo / 'desktop/native/consent-cli-pin.json'
        self.pin.parent.mkdir(parents=True)
        self.pin.write_text(json.dumps({'version': '0.5.52'}))
        minimum = self.repo / module.MINIMUM
        minimum.parent.mkdir(parents=True, exist_ok=True)
        minimum.write_text('public static let minimumAppServerVersion = "0.5.52"\n')
        self.git('add', '.')
        self.git('commit', '-qm', 'base')
        self.base = self.git('rev-parse', 'HEAD').strip()
        self.git('tag', 'v0.5.52')

    def git(self, *args):
        return subprocess.check_output(['git', '-C', str(self.repo), *args], text=True)

    def commit(self):
        self.git('add', '.')
        self.git('commit', '-qm', 'change')


class CLIPinConsistencyTests(SyntheticRepo, unittest.TestCase):
    def test_unchanged_cli_passes_and_stale_cli_fails(self):
        module.assert_pin_matches(self.repo)
        (self.repo / 'cli/source.go').write_text('two\n')
        self.commit()
        with self.assertRaisesRegex(ValueError, 'differs'):
            module.assert_pin_matches(self.repo)

    def test_missing_tag_and_invalid_pin_fail_closed(self):
        self.pin.write_text(json.dumps({'version': '0.5.53'}))
        with self.assertRaisesRegex(ValueError, 'tag'):
            module.assert_pin_matches(self.repo)
        self.pin.write_text(json.dumps({'version': '../bad'}))
        with self.assertRaisesRegex(ValueError, 'version'):
            module.assert_pin_matches(self.repo)

    def test_candidate_or_pin_change_triggers(self):
        event = {'pull_request': {'base': {'sha': self.base}, 'head': {'ref': 'feature'}, 'labels': [], 'title': 'routine'}}
        self.assertFalse(module.requires_check(self.repo, event))
        event['pull_request']['labels'] = [{'name': 'release-candidate'}]
        self.assertTrue(module.requires_check(self.repo, event))
        event['pull_request']['labels'] = []
        self.pin.write_text(json.dumps({'version': '0.5.51'}))
        self.commit()
        self.assertTrue(module.requires_check(self.repo, event))

    def test_new_tag_and_repin_accept_matching_tree(self):
        (self.repo / 'cli/source.go').write_text('two\n')
        self.commit()
        self.git('tag', 'v0.5.53')
        self.pin.write_text(json.dumps({'version': '0.5.53'}))
        self.commit()
        module.assert_pin_matches(self.repo)

    def test_tag_cannot_be_older_than_the_app_minimum(self):
        self.git('tag', 'v0.5.49')
        self.pin.write_text(json.dumps({'version': '0.5.49'}))
        with self.assertRaisesRegex(ValueError, 'older than the app minimum'):
            module.assert_pin_matches(self.repo)


SOURCE = {'arm64': 'a' * 64, 'x86_64': 'b' * 64}
ROOT = Path(__file__).resolve().parents[4]


def write_app(app, reports='modelplan 0.5.52', *, release=True, exit_code=0, declared='0.5.52', sources=SOURCE):
    """Synthetic helper executable plus the records package-neutral.sh writes after sealing."""
    helper = app / 'Contents/Helpers/modelplan'
    helper.parent.mkdir(parents=True, exist_ok=True)
    (app / 'Contents/Resources').mkdir(exist_ok=True)
    helper.write_text(f'#!/bin/sh\n[ "$1" = version ] || exit 2\nprintf "%s\\n" "{reports}"\nexit {exit_code}\n')
    helper.chmod(0o755)
    digest = hashlib.sha256(helper.read_bytes()).hexdigest()
    (app / 'Contents/Resources/modelplan.sha256').write_text(digest + '\n')
    info = {'CFBundleExecutable': 'ModelPlanCommunity', 'ModelPlanPublicSource': 'c' * 40,
            'ModelPlanBundledHelperSHA256': digest}
    if release:
        info.update({'ModelPlanHelperVersion': declared, 'ModelPlanSourceHelperSHA256ByArchitecture': sources})
    (app / 'Contents/Info.plist').write_bytes(plistlib.dumps(info))
    return app


class BundledHelperTests(unittest.TestCase):
    """The packaged Contents/Helpers/modelplan must be the declared pinned release."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        root = Path(self.tmp.name)
        self.pin = root / 'consent-cli-pin.json'
        self.pin.write_text(json.dumps({'version': '0.5.52', 'sourceSHA256ByArchitecture': SOURCE}))
        self.app = root / 'ModelPlan Community.app'
        self.helper = self.app / 'Contents/Helpers/modelplan'
        self.helper.parent.mkdir(parents=True)

    def package(self, *args, **options):
        write_app(self.app, *args, **options)

    def check(self, **options):
        return module.assert_helper_matches(self.app, self.pin, **options)

    def test_pinned_release_helper_passes_through_its_own_version_report(self):
        self.package()
        self.assertEqual(self.check(require_release_identity=True), '0.5.52')
        self.package(release=False)
        self.assertEqual(self.check(), '0.5.52')

    def test_helper_reporting_another_build_is_refused(self):
        # Older release, an unreleased source build and a source build stamped on top of the pin.
        for reported in ('modelplan 0.5.51', 'modelplan 0.5.53', 'modelplan 0.1.0-dev',
                         'modelplan 0.5.52+e2e.0123456789ab', 'modelplan 0.5.52-rc.1', 'modelplan'):
            with self.subTest(reported=reported):
                self.package(reported)
                with self.assertRaisesRegex(ValueError, 'bundled helper reports'):
                    self.check()

    def test_helper_that_cannot_report_a_version_is_refused(self):
        self.package(exit_code=3)
        with self.assertRaisesRegex(ValueError, 'could not report'):
            self.check()
        self.package()
        self.helper.chmod(0o644)
        with self.assertRaisesRegex(ValueError, 'could not report'):
            self.check()

    def test_helper_replaced_after_its_records_were_written_is_refused(self):
        self.package()
        self.helper.write_text('#!/bin/sh\necho "modelplan 0.5.52"\n')
        self.helper.chmod(0o755)
        with self.assertRaisesRegex(ValueError, 'recorded hash'):
            self.check()
        # Matching resource record but stale Info.plist hash.
        digest = hashlib.sha256(self.helper.read_bytes()).hexdigest()
        (self.app / 'Contents/Resources/modelplan.sha256').write_text(digest + '\n')
        with self.assertRaisesRegex(ValueError, 'metadata hash'):
            self.check()

    def test_declared_identity_must_equal_the_pin(self):
        self.package(declared='0.5.49')
        with self.assertRaisesRegex(ValueError, "declares helper '0.5.49'"):
            self.check()
        self.package(sources={**SOURCE, 'arm64': '0' * 64})
        with self.assertRaisesRegex(ValueError, 'source hashes'):
            self.check()
        self.package(release=False)
        with self.assertRaisesRegex(ValueError, 'lacks a release helper identity'):
            self.check(require_release_identity=True)

    def test_missing_or_linked_helper_and_invalid_pin_fail_closed(self):
        with self.assertRaisesRegex(ValueError, 'missing'):
            self.check()
        self.package()
        real = self.helper.with_name('real-modelplan')
        self.helper.rename(real)
        self.helper.symlink_to(real)
        with self.assertRaisesRegex(ValueError, 'linked'):
            self.check()
        self.pin.write_text(json.dumps({'version': '0.5.52-dev'}))
        with self.assertRaisesRegex(ValueError, 'pin version'):
            self.check()


class CandidateCommandTests(SyntheticRepo, unittest.TestCase):
    """The command a candidate job runs: bundled helper and source tree must both match the pin."""

    def run_gate(self, *args):
        return subprocess.run([sys.executable, str(PATH), '--repo', str(self.repo), *args],
                              capture_output=True, text=True)

    def make_app(self, reports):
        # Outside the synthetic repository so the App does not dirty its tree.
        outside = tempfile.TemporaryDirectory()
        self.addCleanup(outside.cleanup)
        return write_app(Path(outside.name) / 'candidate.app', reports, release=False)

    def test_stale_engine_candidate_is_refused_even_when_helper_matches_the_pin(self):
        # Today's owner build: the released 0.5.52 helper inside an App whose cli/ moved on.
        app = self.make_app('modelplan 0.5.52')
        self.assertEqual(self.run_gate('--force', '--app', str(app)).returncode, 0)
        (self.repo / 'cli/source.go').write_text('newer engine\n')
        self.commit()
        result = self.run_gate('--force', '--app', str(app))
        self.assertEqual(result.returncode, 1)
        self.assertIn('differs from pinned CLI tag v0.5.52', result.stderr)
        # Helper-only mode (routine builds) still passes; it makes no source-tree claim.
        self.assertEqual(self.run_gate('--app', str(app)).returncode, 0)

    def test_candidate_with_a_different_helper_is_refused(self):
        app = self.make_app('modelplan 0.1.0-dev')
        result = self.run_gate('--force', '--app', str(app))
        self.assertEqual(result.returncode, 1)
        self.assertIn("bundled helper reports 'modelplan 0.1.0-dev'", result.stderr)
        result = self.run_gate('--app', str(app), '--require-release-identity')
        self.assertEqual(result.returncode, 1)
        self.assertIn('lacks a release helper identity', result.stderr)


class WorkflowWiringTests(unittest.TestCase):
    def test_built_apps_are_checked_against_the_pin_they_were_packaged_from(self):
        neutral = (ROOT / '.github/workflows/macos-distribution.yml').read_text()
        self.assertIn('check_cli_pin_consistency.py --app "$RUNNER_TEMP/neutral-build/ModelPlan Community.app" '
                      '--pin desktop/native/consent-cli-pin.json --require-release-identity', neutral)
        self.assertLess(neutral.index('package-neutral.sh "$RUNNER_TEMP/cli-archives"'),
                        neutral.index('check_cli_pin_consistency.py --app'))
        smoke = (ROOT / '.github/workflows/desktop.yml').read_text()
        self.assertIn('check_cli_pin_consistency.py --app "$RUNNER_TEMP/smoke-neutral-build/ModelPlan Community.app" '
                      '--pin codex/cli-pin.json', smoke)


if __name__ == '__main__':
    unittest.main()
