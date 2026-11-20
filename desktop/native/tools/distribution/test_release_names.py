# SPDX-License-Identifier: MIT
"""D57/D321: the packaged app is one product named ModelPlan, with no retired name in the bundle.

Runs the real package-neutral.sh through the synthetic toolchain of test_package_neutral_hook,
then the release-names check the release workflow runs on the real bundle.
"""
from pathlib import Path
import plistlib
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_release_names as names  # noqa: E402
from test_package_neutral_hook import PackageNeutralFixture, ROOT  # noqa: E402


class ReleaseNamesTests(unittest.TestCase):
    def package(self, edition=None):
        folder = tempfile.TemporaryDirectory()
        self.addCleanup(folder.cleanup)
        fixture = PackageNeutralFixture(Path(folder.name))
        result = fixture.run(environment={'MODELPLAN_EDITION': edition} if edition else None)
        self.assertEqual(result.returncode, 0, result.stderr)
        return fixture.output / 'ModelPlan.app'

    def test_both_editions_are_one_app_named_modelplan(self):
        for edition in ('official', 'neutral'):
            with self.subTest(edition=edition):
                app = self.package(edition if edition == 'official' else None)
                self.assertEqual(names.problems(app, edition), [])
                info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
                self.assertEqual(info['CFBundleIdentifier'], 'ai.modelplan.app')
                self.assertEqual(info['CFBundleExecutable'], 'ModelPlan')
                self.assertEqual(info['ModelPlanEdition'], edition)
                for language in ('en', 'zh-Hans'):
                    text = (app / 'Contents/Resources' / (language + '.lproj') / 'InfoPlist.strings').read_text()
                    self.assertNotIn('Community', text)
                    self.assertNotIn('社区版', text)

    def test_release_bundle_must_not_carry_community_or_shequban(self):
        app = self.package('official')
        for needle in ('ModelPlan Community', '社区版'):
            with self.subTest(needle=needle):
                planted = app / 'Contents/MacOS/ModelPlan'
                original = planted.read_bytes()
                planted.write_bytes(original + needle.encode('utf-8'))
                self.assertIn('Contents/MacOS/ModelPlan contains a retired product name', names.problems(app, 'official'))
                planted.write_bytes(original)
        self.assertEqual(names.main(['--app', str(app), '--edition', 'official']), 0)

    def test_wrong_edition_or_identifier_is_refused(self):
        app = self.package()
        self.assertTrue(any('ModelPlanEdition' in line for line in names.problems(app, 'official')))
        info_path = app / 'Contents/Info.plist'
        info = plistlib.loads(info_path.read_bytes())
        info['CFBundleIdentifier'] = 'org.modelplan.community.swift.scaffold'
        info_path.write_bytes(plistlib.dumps(info))
        found = names.problems(app, 'neutral')
        self.assertTrue(any('CFBundleIdentifier' in line for line in found))
        self.assertTrue(any('still says' in line for line in found))

    def test_release_workflow_checks_the_official_bundle_after_packaging(self):
        workflow = (ROOT / '.github/workflows/macos-distribution.yml').read_text()
        build = workflow.index('bash desktop/native/tools/package-neutral.sh')
        check = workflow.index('check_release_names.py --app "$RUNNER_TEMP/neutral-build/ModelPlan.app" --edition official')
        self.assertLess(workflow.index('MODELPLAN_EDITION: official'), build)
        self.assertLess(build, check)
        self.assertLess(check, workflow.index('ditto -c -k --sequesterRsrc --keepParent'))


if __name__ == '__main__':
    unittest.main()
