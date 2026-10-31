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

    def test_stopping_the_recorded_step_pid_reaches_the_step_itself(self):
        # The sequence's trap TERMs the scenario.py PID it recorded; the step under it must not be orphaned.
        marker = self.root / 'step-terminated'
        (self.registry / 'demo-drive.py').write_text(
            'import signal,sys,time\n'
            f'signal.signal(signal.SIGTERM, lambda *_: (open({str(marker)!r}, "w").close(), sys.exit(143)))\n'
            f'open({str(marker)!r} + ".ready", "w").close()\ntime.sleep(30)\n')
        c = self.config(scenario='demo', argv=[str(self.binary), '--demo-contract', 'x'])
        path = self.root / 'demo.json'; path.write_text(json.dumps(c))
        code = ('import sys; sys.path.insert(0, sys.argv[1]); import scenario; from pathlib import Path\n'
                'sys.exit(scenario.main(["drive", "--config", sys.argv[2]], Path(sys.argv[3])))')
        proc = subprocess.Popen([sys.executable, '-B', '-c', code, str(BIN), str(path), str(self.registry / 'scenarios.json')])
        deadline = time.monotonic() + 10
        while not Path(str(marker) + '.ready').exists() and time.monotonic() < deadline: time.sleep(.02)
        proc.terminate()
        self.assertEqual(proc.wait(10), 143)
        self.assertTrue(marker.exists())

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


STUB = r"""
python3() {
  if [ "$1" != -B ]; then echo "NO-B $*" >> "$LOG"; return 99; fi; shift
  if [ "$1" = -c ]; then "$REAL_PY" "$@"; return; fi
  [ "$PYTHONDONTWRITEBYTECODE" = 1 ] || echo "BYTECODE-UNSET" >> "$LOG"
  s=${1##*/}; echo "$s $2" >> "$LOG"
  case "$s" in
    book.py) case "$2" in
        request) echo '{"id": "b1"}' ;;
        start) printf '{"runID": "%s", "epoch": "%s", "notBefore": 1, "expiresAt": 2}\n' "$8" "${10}"; echo "run=$8 epoch=${10}" >> "$LOG" ;;
      esac ;;
    guardian.py) echo "guardian-stop $5" >> "$LOG"
                 while [ ! -e "$5" ]; do sleep 0.02; done; echo "guardian.py exit" >> "$LOG"; return "${GUARDIAN:-0}" ;;
    release.py) return "${RELEASE:-0}" ;;
    scenario.py) case "$2" in name) echo "$NAME" ;; prepare) return "${PREPARE:-0}" ;; drive) return "${DRIVE:-0}" ;; esac ;;
    launch.py|drive-scenario.py) while [ ! -e "$STOP_PATH" ]; do sleep 0.02; done
                                 echo "$s exit" >> "$LOG"; return "${CONTROLLER:-3}" ;;
    check_launch_cleanup.py) echo "check-args $*" >> "$LOG"; return "${CHECK:-0}" ;;
    check_drive_cleanup.py) return "${CHECK:-0}" ;;
  esac
}
"""


class SkillLaunchBranchTests(unittest.TestCase):
    """Run SKILL.md's whole M1 sequence with a stub python3 that logs calls (bash, real uuidgen/date)."""
    def block(self):
        text = SKILL.read_text()
        start = text.index('```sh\n', text.index('M1 uses this exact sequence')) + len('```sh\n')
        return text[start:text.index('```', start)]

    def run_sequence(self, mode='launch', name='u6', existing=(), **env):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); log = root / 'calls'
            paths = dict(leasePath=root / 'lease.json', releasePath=root / 'release.json',
                         stopPath=root / 'batch' / 'stop.json', subjectPidPath=root / 'subject.pid')
            (root / 'batch').mkdir()
            config = root / 'run.json'; config.write_text(json.dumps({k: str(v) for k, v in paths.items()}))
            for key in existing: paths[key].write_text('{}')
            values = dict(LOG=str(log), REAL_PY=sys.executable, NAME=name, CONTROLLER_MODE=mode, RUN_CONFIG=str(config),
                          BOOKING_ID='b1', APPROVAL_URL='https://example.test/ok', PATH='/usr/bin:/bin')
            values.update({k: str(v) for k, v in env.items()})
            result = subprocess.run(['bash', '-c', STUB + self.block()], env=values, capture_output=True, text=True, timeout=60)
            calls = log.read_text().splitlines() if log.exists() else []
            return dict(status=result.returncode, calls=calls, stderr=result.stderr, config=json.loads(config.read_text()),
                        stop=paths['stopPath'].read_text() if paths['stopPath'].exists() else None, paths=paths)

    def index(self, calls, prefix):
        return next(i for i, call in enumerate(calls) if call.startswith(prefix))

    def test_launch_order_prepare_launch_drive_stop_wait_check_finish(self):
        r = self.run_sequence(DRIVE=0, CONTROLLER=3, GUARDIAN=0)
        calls = r['calls']
        self.assertEqual(r['status'], 0, r['stderr'])
        order = ['book.py request', 'book.py start', 'release.py --lane', 'scenario.py name',
                 'scenario.py prepare', 'launch.py --config', 'scenario.py drive']
        self.assertEqual([self.index(calls, x) for x in order], sorted(self.index(calls, x) for x in order))
        # the guardian runs in the background from before the release until the stop
        self.assertTrue(self.index(calls, 'book.py start') < self.index(calls, 'guardian.py --lease') < self.index(calls, 'guardian.py exit'))
        drive, check = self.index(calls, 'scenario.py drive'), self.index(calls, 'check_launch_cleanup.py')
        # stop is requested after the drive step returns; both supervisors are reaped before the check runs
        self.assertTrue(drive < self.index(calls, 'launch.py exit') < check)
        self.assertTrue(self.index(calls, 'guardian.py exit') < check < self.index(calls, 'book.py finish'))
        self.assertIn('--controller-status 3 --guardian-status 0 --scenario-status 0', calls[self.index(calls, 'check-args')])
        self.assertNotIn('check_drive_cleanup.py', ' '.join(calls))
        self.assertNotIn('BYTECODE-UNSET', calls); self.assertFalse([c for c in calls if c.startswith('NO-B')])
        self.assertEqual(json.loads(r['stop'])['reason'], 'sequence-close')

    def test_failed_closure_check_never_finishes(self):
        r = self.run_sequence(DRIVE=3, CHECK=1)
        self.assertIn('--scenario-status 3', r['calls'][self.index(r['calls'], 'check-args')])
        self.assertNotIn('book.py finish', r['calls'])
        self.assertIn('NEEDS-COORDINATOR: booking=b1', r['stderr']); self.assertIn('closure unconfirmed', r['stderr'])

    def test_one_stop_path_from_the_run_config(self):
        r = self.run_sequence()
        self.assertIn('guardian-stop ' + str(r['paths']['stopPath']), r['calls'])
        block = self.block()
        self.assertEqual(re.findall(r'STOP_PATH=\S+', block), ['STOP_PATH=$(cfg'])
        self.assertIn('STOP_PATH=$(cfg stopPath)', block)
        self.assertNotIn('touch', block)
        self.assertEqual(re.findall(r'--stop\s+(\S+)', block), ['"$STOP_PATH"'])

    def test_bytecode_is_never_written(self):
        block = self.block()
        self.assertLess(block.index('export PYTHONDONTWRITEBYTECODE=1'), block.index('python3'))
        self.assertEqual(re.findall(r'python3(?! -B)', block), [])

    def test_fresh_run_identity_per_attempt_bound_into_the_config(self):
        first, second = self.run_sequence(), self.run_sequence()
        runs = [next(c for c in r['calls'] if c.startswith('run=')) for r in (first, second)]
        self.assertNotEqual(runs[0], runs[1])
        self.assertRegex(runs[0], r'^run=m1-[0-9a-f-]{36} epoch=\d{8}T\d{6}Z$')
        lease = first['config']['expectedLease']
        self.assertEqual('run=%s epoch=%s' % (lease['runID'], lease['epoch']), runs[0])

    def test_existing_attempt_paths_refuse_before_start(self):
        for key in ('leasePath', 'releasePath', 'stopPath', 'subjectPidPath'):
            with self.subTest(key):
                r = self.run_sequence(existing=[key])
                self.assertEqual((r['status'], r['calls']), (2, ['book.py request']))

    def test_refused_prepare_stops_reaps_and_reports_without_launch(self):
        r = self.run_sequence(PREPARE=2)
        self.assertEqual(r['status'], 3)
        self.assertNotIn('launch.py --config', r['calls']); self.assertNotIn('book.py finish', r['calls'])
        self.assertEqual(json.loads(r['stop'])['reason'], 'sequence-aborted')
        self.assertIn('NEEDS-COORDINATOR', r['stderr']); self.assertIn('aborted (status 2)', r['stderr'])

    def test_failed_release_stops_the_guardian_it_started(self):
        r = self.run_sequence(RELEASE=2)
        self.assertEqual(r['status'], 3)
        self.assertNotIn('scenario.py name', r['calls']); self.assertNotIn('book.py finish', r['calls'])
        self.assertIn('NEEDS-COORDINATOR', r['stderr'])

    def test_unregistered_launch_keeps_the_general_flow(self):
        r = self.run_sequence(name='')
        self.assertEqual([c for c in r['calls'] if c.startswith(('scenario.py', 'launch.py --', 'check', 'book.py finish'))],
                         ['scenario.py name', 'launch.py --config', 'check_launch_cleanup.py --config', 'check-args ' + r['calls'][self.index(r['calls'], 'check-args')][11:], 'book.py finish'])
        self.assertIn('# ... in launch mode, drive the scenario against the launched subject here', self.block())

    def test_drive_mode_uses_its_own_closure_check(self):
        r = self.run_sequence(mode='drive', name='', CONTROLLER=0)
        calls = r['calls']
        self.assertIn('drive-scenario.py --config', calls); self.assertNotIn('launch.py --config', calls)
        self.assertNotIn('scenario.py name', calls); self.assertNotIn('check_launch_cleanup.py --config', calls)
        self.assertLess(self.index(calls, 'check_drive_cleanup.py'), self.index(calls, 'book.py finish'))
        self.assertNotIn('book.py finish', self.run_sequence(mode='drive', name='', CHECK=1)['calls'])


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
