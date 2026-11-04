# SPDX-License-Identifier: MIT
import importlib.util
import json
import subprocess
import tempfile
import unittest
from pathlib import Path

PATH = Path(__file__).with_name('check_cli_pin_consistency.py')
spec = importlib.util.spec_from_file_location('cli_pin_consistency', PATH)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class CLIPinConsistencyTests(unittest.TestCase):
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
        self.git('add', '.')
        self.git('commit', '-qm', 'base')
        self.base = self.git('rev-parse', 'HEAD').strip()
        self.git('tag', 'v0.5.52')

    def git(self, *args):
        return subprocess.check_output(['git', '-C', str(self.repo), *args], text=True)

    def commit(self):
        self.git('add', '.')
        self.git('commit', '-qm', 'change')

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

if __name__ == '__main__':
    unittest.main()
