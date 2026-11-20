# SPDX-License-Identifier: MIT
"""D57: test-build-walkthrough.yml finds the packaged app of any ref, before or after the rename,
on both the artifact path and the fallback packager path."""
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[4]
SCRIPT = ROOT / 'desktop/native/verification/walkthrough/one-app.sh'
WORKFLOW = (ROOT / '.github/workflows/test-build-walkthrough.yml').read_text()


class OneAppTests(unittest.TestCase):
    def find(self, *names):
        with tempfile.TemporaryDirectory() as folder:
            for name in names:
                (Path(folder) / name / 'Contents').mkdir(parents=True)
            result = subprocess.run(['bash', str(SCRIPT), folder], capture_output=True, text=True)
            return result.returncode, result.stdout.strip().removeprefix(folder + '/')

    def test_renamed_and_pre_rename_bundles_are_found(self):
        self.assertEqual(self.find('ModelPlan.app'), (0, 'ModelPlan.app'))
        self.assertEqual(self.find('ModelPlan Community.app'), (0, 'ModelPlan Community.app'))

    def test_none_both_or_other_names_are_refused(self):
        for names in ((), ('ModelPlan.app', 'ModelPlan Community.app'), ('Other.app',)):
            with self.subTest(names=names):
                self.assertNotEqual(self.find(*names)[0], 0)

    def test_both_workflow_paths_use_the_finder_and_either_zip_name(self):
        self.assertEqual(WORKFLOW.count('walkthrough/one-app.sh'), 2)
        self.assertIn('one-app.sh" "$RUNNER_TEMP/subject-app")', WORKFLOW)
        self.assertIn('one-app.sh" "$RUNNER_TEMP/subject-build")', WORKFLOW)
        pattern = re.search(r"grep -oE '(\^\[0-9a-f\]\{64\}  ModelPlan\(-Community\)\?-native\\\.zip\$)'", WORKFLOW)
        self.assertIsNotNone(pattern)
        regex = pattern.group(1).replace('\\.', r'\.')
        for name in ('ModelPlan-native.zip', 'ModelPlan-Community-native.zip'):
            self.assertRegex('a' * 64 + '  ' + name, regex)
        self.assertNotIn('ModelPlan.app" >> "$GITHUB_ENV"', WORKFLOW)


if __name__ == '__main__':
    unittest.main()
