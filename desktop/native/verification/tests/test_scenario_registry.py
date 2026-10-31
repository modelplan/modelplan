# SPDX-License-Identifier: MIT
"""Launch-mode scenario registry: launch.py enforces receipts for registered scenarios only; SKILL.md dispatches
through the registry and keeps the general launch flow for unregistered launches."""
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import MagicMock, patch

BIN = Path(__file__).resolve().parents[1] / 'bin'
SKILL = BIN.parent / 'SKILL.md'
sys.path.insert(0, str(BIN))
import launch  # noqa: E402
import scenario  # noqa: E402

DEMO = {'u6': json.loads((BIN / 'scenarios.json').read_text())['u6'],
        'demo': dict(argvFlag='--demo-contract', prepare='demo-prepare.py', drive='demo-drive.py', receipt=True)}


def no_spawn(*a, **k):
    raise AssertionError('no subject may be started')


class ScenarioRegistryTests(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory(); self.root = Path(self.dir.name)
        self.binary = self.root / 'subject'; self.binary.write_bytes(b'synthetic')
        self.registry = self.root / 'registry'; self.registry.mkdir()
        (self.registry / 'scenarios.json').write_text(json.dumps(DEMO))
        # The demo scenario's own prepare refuses (e.g. its resource is busy) and writes nothing.
        (self.registry / 'demo-prepare.py').write_text('import sys\nsys.exit(2)\n')
        (self.registry / 'demo-drive.py').write_text('import sys\nsys.exit(0)\n')

    def tearDown(self):
        self.dir.cleanup()

    def config(self, **extra):
        c = dict(profile='synthetic', binarySHA256=hashlib.sha256(b'synthetic').hexdigest(), argv=[str(self.binary)],
                 syntheticHome=str(self.root / 'home'), syntheticTmp=str(self.root / 'tmp'),
                 subjectPidPath=str(self.root / 'subject.pid'), stopPath=str(self.root / 'stop'))
        c.update(extra); return c

    def execute(self, c, spawn=no_spawn):
        path = self.root / 'run.json'; path.write_text(json.dumps(c))
        child = MagicMock(pid=123, returncode=0)
        with patch.object(sys, 'argv', ['launch', '--config', str(path), '--execute']), \
             patch.object(scenario, 'REGISTRY', self.registry / 'scenarios.json'), \
             patch.object(launch, 'load_and_admit', lambda c: dict(c, lease=dict(runID='run', epoch='epoch'))), \
             patch.object(launch, 'mark_launching', return_value={}), patch.object(launch, 'register'), \
             patch.object(launch, 'supervise', return_value=None), \
             patch.object(launch.subprocess, 'Popen', side_effect=spawn if spawn is no_spawn else None, return_value=child) as popen:
            try:
                launch.main()
            except SystemExit as exit:
                return exit.code, popen
        return None, popen

    def test_unregistered_launch_runs_without_a_receipt_as_before(self):
        status, popen = self.execute(self.config(argv=[str(self.binary), '--plain-option']), spawn=None)
        self.assertEqual(status, 0); popen.assert_called_once()
        self.assertTrue((self.root / 'home').is_dir())
        self.assertIsNone(scenario.resolve(self.config(), self.registry / 'scenarios.json'))

    def test_second_entry_refused_prepare_leaves_launch_unable_to_spawn(self):
        c = self.config(scenario='demo', argv=[str(self.binary), '--demo-contract', 'x'],
                        preparedReceiptPath=str(self.root / 'prepared.json'))
        path = self.root / 'demo.json'; path.write_text(json.dumps(c))
        self.assertEqual(scenario.main(['prepare', '--config', str(path)], self.registry / 'scenarios.json'), 2)
        for config in (c, {k: v for k, v in c.items() if k != 'preparedReceiptPath'}):
            with self.assertRaisesRegex(ValueError, 'preparation receipt'):
                self.execute(config)
            self.assertFalse((self.root / 'home').exists())

    def test_flag_and_scenario_must_agree(self):
        for extra, error in [(dict(scenario='u6', argv=[str(self.binary), '--demo-contract']), 'scenario/argv mismatch'),
                             (dict(scenario='demo', argv=[str(self.binary), '--u6-drive-contract']), 'scenario/argv mismatch'),
                             (dict(argv=[str(self.binary), '--demo-contract', '--u6-drive-contract']), 'scenario/argv mismatch'),
                             (dict(scenario='missing'), 'unknown scenario')]:
            with self.subTest(extra=extra):
                with self.assertRaisesRegex(ValueError, error):
                    self.execute(self.config(**extra))
                self.assertFalse((self.root / 'home').exists())

    def test_unreadable_registry_fails_closed_for_every_launch(self):
        # A registry that cannot be read cannot prove a run is unregistered, so even a bare argv refuses.
        good = (self.registry / 'scenarios.json').read_text()
        for state in ('missing', 'malformed'):
            path = self.registry / 'scenarios.json'
            if state == 'missing': path.unlink()
            else: path.write_text('{')
            for c in (self.config(), self.config(scenario='u6'), self.config(argv=[str(self.binary), '--u6-drive-contract'])):
                with self.assertRaisesRegex(ValueError, 'scenario registry unreadable'):
                    scenario.resolve(c, path)
            with self.assertRaisesRegex(ValueError, 'scenario registry unreadable'):
                self.execute(self.config())  # the real Launch entry, bare unlabelled argv
            self.assertFalse((self.root / 'home').exists(), state)
            path.write_text(good)

    def test_name_cli_and_step_commands(self):
        u6 = self.root / 'u6.json'; u6.write_text(json.dumps(self.config(scenario='u6', argv=[str(self.binary), '--u6-drive-contract', 'x'])))
        plain = self.root / 'plain.json'; plain.write_text(json.dumps(self.config()))
        run = lambda path: subprocess.run([sys.executable, str(BIN / 'scenario.py'), 'name', '--config', str(path)],
                                          capture_output=True, text=True, check=True).stdout.strip()
        self.assertEqual((run(u6), run(plain)), ('u6', ''))
        self.assertEqual(scenario.command(json.loads(u6.read_text()), 'prepare', u6)[1:],
                         [str(BIN / 'drive-u6.py'), 'prepare', '--config', str(u6)])
        with self.assertRaisesRegex(ValueError, 'no registered scenario'):
            scenario.command(self.config(), 'drive', plain)


class SkillLaunchBranchTests(unittest.TestCase):
    """Run SKILL.md's controller section with a stub python3 that logs calls."""
    def section(self):
        text = SKILL.read_text()
        return text[text.index('SCENARIO=""\ncase "$CONTROLLER_MODE" in'):text.index('# Close: request stop')]

    def run_section(self, name, prepare_status=0, mode='launch'):
        with tempfile.TemporaryDirectory() as directory:
            log = Path(directory) / 'calls'
            stub = ('python3() { echo "${1##*/} $2" >> "$LOG"; case "$1 $2" in\n'
                    '  *scenario.py\\ name) echo "$NAME" ;;\n  *scenario.py\\ prepare) return "$PREPARE" ;;\nesac; }\n')
            script = 'set -e\n' + stub + self.section() + 'wait\n'
            result = subprocess.run(['bash', '-c', script], env=dict(LOG=str(log), NAME=name, PREPARE=str(prepare_status),
                                    CONTROLLER_MODE=mode, RUN_CONFIG='run.json', PATH='/usr/bin:/bin'))
            return result.returncode, log.read_text().split('\n')[:-1] if log.exists() else []

    def test_launch_branch_dispatches_through_the_registry_and_keeps_the_general_flow(self):
        branch = re.search(r'\n  launch\)(.*?);;', self.section(), re.S).group(1)
        self.assertIn('scenario.py name', branch); self.assertIn('scenario.py prepare', branch)
        self.assertIn('launch.py --config "$RUN_CONFIG" --execute &', branch)
        self.assertNotIn('drive-u6', self.section())
        self.assertIn('# ... in launch mode, drive the scenario against the launched subject here ...', self.section())
        self.assertEqual(self.run_section(''), (0, ['scenario.py name', 'launch.py --config']))
        status, calls = self.run_section('u6')
        self.assertEqual((status, calls[:2], sorted(calls[2:])), (0, ['scenario.py name', 'scenario.py prepare'], ['launch.py --config', 'scenario.py drive']))

    def test_refused_prepare_stops_before_launch(self):
        self.assertEqual(self.run_section('demo', prepare_status=2), (2, ['scenario.py name', 'scenario.py prepare']))

    def test_drive_mode_is_unchanged(self):
        self.assertEqual(self.run_section('', mode='drive'), (0, ['drive-scenario.py --config']))


if __name__ == '__main__':
    unittest.main()


class FlagSpellings(unittest.TestCase):
    def test_equals_form_of_a_registered_flag_still_requires_its_scenario(self):
        import scenario
        reg = {"u6": {"argvFlag": "--u6-drive-contract", "prepare": "drive-u6.py prepare", "drive": "drive-u6.py drive", "receipt": True}}
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / "scenarios.json"; path.write_text(json.dumps(reg))
            self.assertEqual(scenario.resolve({"argv": ["/bin/app", "--u6-drive-contract=/x/guard.json"]}, path)[0], "u6")
            with self.assertRaises(ValueError):
                scenario.resolve({"scenario": "other", "argv": ["/bin/app", "--u6-drive-contract=/x"]}, path)
            self.assertIsNone(scenario.resolve({"argv": ["/bin/app", "--u6-drive-contractor"]}, path))
