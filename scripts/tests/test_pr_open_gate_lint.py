# SPDX-License-Identifier: MIT
import importlib.util
import json
import os
from pathlib import Path
import contextlib
import io
import tempfile
import unittest
from unittest import mock

spec = importlib.util.spec_from_file_location('lint', Path(__file__).resolve().parents[1] / 'pr_open_gate_lint.py')
lint = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lint)


class GateLintTests(unittest.TestCase):
    def test_design_paths_and_exclusions(self):
        self.assertEqual(lint.surfaces([{'filename':'desktop/cockpit/src/main.ts'}]), {'cockpit'})
        self.assertEqual(lint.surfaces([{'filename':'desktop/native/ModelPlanDock/Logic/Dock.swift'}]), {'dock'})
        self.assertEqual(lint.surfaces([{'filename':'desktop/cockpit/tests/a.test.ts'}, {'filename':'docs/a.md'}]), set())
        self.assertEqual(lint.surfaces([{'filename':'desktop/native/ModelPlanSettings/Tests/a.swift'}]), set())
        self.assertEqual(lint.surfaces([{'filename':'desktop/cockpit/src/a.ts','previous_filename':'desktop/native/ModelPlanDock/Logic/x.swift'}]), {'dock','cockpit'})

    def test_mechanical_pin_only_and_missing_patch(self):
        path='desktop/native/ModelPlanAppIntegration/Sources/ModelPlanAppIntegration/CommunityCockpitApplicationFactory.swift'
        pins='@@ -1 +1 @@\n-        "community":"'+'a'*64+'",\n+        "community":"'+'b'*64+'",'
        self.assertEqual(lint.surfaces([{'filename':path,'patch':pins}]), set())
        self.assertEqual(lint.surfaces([{'filename':path}]), {'integration'})
        self.assertEqual(lint.surfaces([{'filename':path,'patch':pins+'\n+        let changed = true'}]), {'integration'})

    def test_missing_requirement_id_and_staged_list(self):
        files=[{'filename':'desktop/cockpit/src/main.ts'}]
        issue=('## Staged PRs\n'
               '- [ ] #465 cockpit show/hide toggle and menu anchor\n'
               '- [ ] #450 cockpit fader publication and engine labels (includes #457)\n'
               '- [Retain cockpit shell state #466](https://github.com/modelplan/modelplan/pull/466)\n'
               '\n## Required before enabling (test-first rule)\n'
               '- [ ] normal-entry → real cockpit window → page tests for staged ID CKP-ENG-01 (#450); CKP-SHELL-01 (#465)\n'
               '- [ ] independent follow-up (#468)\n'
               'Prose mentions #999 but is not a checklist.\n')
        for number in (450, 457, 465, 466, 468):
            with self.subTest(number=number):
                self.assertEqual(lint.warnings(files, 'Implements CKP-ENG-01. Staged under #470.', number, issue), [])
        self.assertEqual(len(lint.warnings(files, 'Checked SHA-256.', 465, issue)), 1)
        self.assertEqual(len(lint.warnings(files, 'Staged under #470.', 999, issue)), 2)
        self.assertEqual(len(lint.warnings(files, 'Implements CKP-ENG-01. See #470.', 999, issue)), 0)
        self.assertEqual(len(lint.warnings([{'filename':'docs/a.md'}], '', 999, issue)), 0)
        self.assertEqual(len(lint.warnings(files, 'CKP-ENG-01. Staged under #470.', 465, None)), 1)

    def test_entry_paginates_and_issue_failure_warns(self):
        with tempfile.TemporaryDirectory() as directory:
            event = Path(directory) / 'event.json'
            event.write_text(json.dumps({'pull_request': {'number': 17, 'body': 'CKP-ENG-01 staged under #470'}}))
            paths = [{'filename': f'docs/{i}.md'} for i in range(100)]
            def fake_api(url):
                if url.endswith('&page=1'):
                    return paths
                if url.endswith('&page=2'):
                    return [{'filename': 'desktop/cockpit/src/main.ts'}]
                raise OSError('synthetic unavailable')
            with mock.patch.dict(os.environ, {'GITHUB_EVENT_PATH': str(event)}), mock.patch.object(lint, 'api', side_effect=fake_api):
                self.assertEqual(lint.run(), ['Could not check issue #470 staged PRs; verify the staging list manually.'])

    def test_timeout_and_page_limit_are_warnings(self):
        output = io.StringIO()
        with mock.patch.object(lint, 'run', side_effect=TimeoutError()), contextlib.redirect_stdout(output):
            lint.main()
        self.assertIn('::warning::Could not complete PR gate lint', output.getvalue())
        with tempfile.TemporaryDirectory() as directory:
            event = Path(directory) / 'event.json'
            event.write_text(json.dumps({'pull_request': {'number': 17, 'body': ''}}))
            with mock.patch.dict(os.environ, {'GITHUB_EVENT_PATH': str(event)}), mock.patch.object(lint, 'api', return_value=[{'filename':'docs/a.md'}] * 100) as request:
                with self.assertRaisesRegex(ValueError, 'truncated'):
                    lint.run()
                self.assertLessEqual(request.call_count, 5)


if __name__ == '__main__':
    unittest.main()
