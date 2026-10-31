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

    def test_u6_registers_builder_observations_and_actions_inside_the_kit(self):  # macrev-332-16, -17
        c = self.config(scenario='u6', argv=[str(self.binary), '--u6-drive-contract', 'x'])
        path = self.root / 'u6.json'; path.write_text(json.dumps(c))
        self.assertEqual(scenario.command(c, 'actions', path, extra=['--pointer-binary', 'p'])[1:],
                         [str(BIN.parent / 'U6' / 'action_runner.py'), '--pointer-binary', 'p', '--config', str(path)])
        self.assertEqual(scenario.script_command(DEMO['u6'], 'config', path)[1], str(BIN.parent / 'U6' / 'prepare_config.py'))
        out = subprocess.run([sys.executable, '-B', str(BIN / 'scenario.py'), 'has-actions', '--config', str(path)],
                             capture_output=True, text=True, check=True).stdout.strip()
        self.assertEqual(out, 'actions')
        with self.assertRaisesRegex(ValueError, 'no actions step'):
            scenario.script_command(DEMO['demo'], 'actions', path)
        for script in ('../../outside.py', '/bin/sh'):
            with self.subTest(script=script), self.assertRaisesRegex(ValueError, 'inside the verification kit'):
                scenario.script_command(dict(DEMO['u6'], actions=script), 'actions', path)
        with self.assertRaises(SystemExit):  # extra arguments only reach build/actions
            scenario.main(['prepare', '--config', str(path), '--', '--x'], self.registry / 'scenarios.json')

    def test_started_waits_boundedly_for_this_runs_registered_subject_row(self):
        batch = self.root / 'batch'; batch.mkdir()
        c = self.config(scenario='u6', argv=[str(self.binary), '--u6-drive-contract', 'x'], batch=str(batch), expectedLease=dict(runID='r', epoch='e'))
        clock = iter(range(100)).__next__
        def wait(): return scenario.started(c, clock=lambda: clock(), sleep=lambda _: None)
        self.assertFalse(wait())  # nothing registered: gives up at the bound, never longer than 15 s
        self.assertEqual(scenario.started.__defaults__[1], 15)
        Path(c['subjectPidPath']).write_text(json.dumps(dict(state='running', pid=7, runID='r', epoch='e')))
        rows = batch / 'native-observations.jsonl'
        for row in (dict(event='started', runID='r', epoch='other', pid=7), dict(event='started', runID='r', epoch='e', pid=8)):
            rows.write_text(json.dumps(row) + '\n')
            clock = iter(range(100)).__next__; self.assertFalse(wait())
        rows.write_text(json.dumps(dict(event='started', runID='r', epoch='e', pid=7)) + '\n')
        clock = iter(range(100)).__next__; self.assertTrue(wait())

    def test_build_creates_only_a_fresh_config_for_its_scenario(self):
        target = self.root / 'built.json'
        (self.registry / 'demo-build.py').write_text(
            'import json,sys\nopen(sys.argv[-1],"w").write(json.dumps(dict(scenario=sys.argv[1], argv=["a", "--demo-contract"])))\n')
        reg = self.registry / 'scenarios.json'
        reg.write_text(json.dumps(dict(DEMO, demo=dict(DEMO['demo'], config='demo-build.py'))))
        self.assertEqual(scenario.main(['build', '--scenario', 'demo', '--config', str(target), '--', 'demo'], reg), 0)
        with self.assertRaisesRegex(ValueError, 'run config exists'):
            scenario.main(['build', '--scenario', 'demo', '--config', str(target), '--', 'demo'], reg)
        target.unlink()
        with self.assertRaisesRegex(ValueError, "did not create this scenario"):
            scenario.main(['build', '--scenario', 'demo', '--config', str(target), '--', 'u6'], reg)


STUB = r"""
python3() {
  if [ "$1" != -B ]; then echo "NO-B $*" >> "$LOG"; return 99; fi; shift
  if [ "$1" = -c ]; then "$REAL_PY" "$@"; return; fi
  [ "$PYTHONDONTWRITEBYTECODE" = 1 ] || echo "BYTECODE-UNSET" >> "$LOG"
  s=${1##*/}; echo "$s $2" >> "$LOG"
  case "$s" in
    book.py) case "$2" in
        request) echo "request-args $*" >> "$LOG"; echo '{"id": "b1"}' ;;
        withdraw) echo "withdraw-args $*" >> "$LOG"; return "${WITHDRAW:-0}" ;;
        start) printf '{"runID": "%s", "epoch": "%s", "notBefore": 1, "expiresAt": 2}\n' "$8" "${10}"; echo "run=$8 epoch=${10}" >> "$LOG" ;;
      esac ;;
    guardian.py) echo "guardian-stop $5" >> "$LOG"; echo "guardian-grace $8 $9" >> "$LOG"
                 while [ ! -e "$5" ]; do sleep 0.02; done; echo "guardian.py exit" >> "$LOG"; return "${GUARDIAN:-0}" ;;
    release.py) return "${RELEASE:-0}" ;;
    scenario.py) case "$2" in
        name) echo "$NAME" ;;
        booking-unit|booking-scenario) "$REAL_PY" -B "$REAL_BIN/scenario.py" "${@:2}" ;;  # the real registry
        build) echo "build-args $*" >> "$LOG"; [ "${BUILD:-0}" -eq 0 ] || return "$BUILD"
               "$REAL_PY" -c 'import json,sys; c=json.load(open(sys.argv[1])); c["expectedLease"]=dict(runID=sys.argv[3] + sys.argv[5], epoch=sys.argv[4])
json.dump(c, open(sys.argv[2], "w"))' "$TEMPLATE" "$6" "${11}" "${13}" "${WRONG_RUN:-}" ;;
        prepare) return "${PREPARE:-0}" ;;
        drive) if [ -n "$ACTIONS" ]; then  # the monitor: ends on the runner's hand-off or on the stop file
                 while [ ! -e "$FINISH" ] && [ ! -e "$STOP_PATH" ]; do sleep 0.02; done
                 if [ -e "$FINISH" ]; then echo "scenario.py drive saw-finish" >> "$LOG"; else echo "scenario.py drive saw-stop" >> "$LOG"; fi
                 (set -C; echo '{"stop": true, "reason": "run-ended"}' > "$STOP_PATH") 2>/dev/null || true
               fi; return "${DRIVE:-0}" ;;
        has-actions) echo "$ACTIONS" ;;
        started) n=0; while [ ! -e "$ROW" ] && [ $n -lt 250 ]; do sleep 0.02; n=$((n+1)); done
                 [ "${STARTED:-0}" -eq 0 ] && [ -e "$ROW" ] || return "${STARTED:-3}"; echo "started-ok" >> "$LOG" ;;
        actions) echo "action-args $*" >> "$LOG"; [ "${ACTION:-0}" -eq 0 ] || return "$ACTION"
                 echo '{"schema": "u6-actions/1"}' > "$FINISH"; echo "actions-exit" >> "$LOG" ;;
      esac ;;
    launch.py|drive-scenario.py) [ -z "$ROW" ] || { sleep 0.2; : > "$ROW"; }  # the subject's native started row
                                 while [ ! -e "$STOP_PATH" ]; do sleep 0.02; done
                                 echo "$s exit" >> "$LOG"; return "${CONTROLLER:-3}" ;;
    check_launch_cleanup.py) echo "check-args $*" >> "$LOG"  # like the real check: a failed scenario never passes
                             case "$*" in *"--scenario-status 0") return "${CHECK:-0}" ;; *) return 1 ;; esac ;;
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

    def run_sequence(self, mode='launch', name='u6', existing=(), build=False, prefix='', **env):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); log = root / 'calls'
            paths = dict(leasePath=root / 'lease.json', releasePath=root / 'release.json',
                         stopPath=root / 'batch' / 'stop.json', subjectPidPath=root / 'subject.pid')
            (root / 'batch').mkdir()
            config = root / 'batch' / 'run.json'
            # A built scenario's run config does not exist yet: `scenario.py build` makes it from the template.
            (root / 'template.json' if build else config).write_text(json.dumps({k: str(v) for k, v in paths.items()}))
            for key in existing: paths[key].write_text('{}')
            values = dict(LOG=str(log), REAL_PY=sys.executable, NAME=name, CONTROLLER_MODE=mode, RUN_CONFIG=str(config),
                          BOOKING_ID='b1', APPROVAL_URL='https://example.test/ok', PATH='/usr/bin:/bin',
                          TEMPLATE=str(root / 'template.json'), FINISH=str(root / 'batch' / 'operator-finish.json'),
                          REAL_BIN=str(BIN))
            if build: values.update(BUILD_SCENARIO=name, ACTIONS='actions', ROW=str(root / 'batch' / 'started-row'))
            else: values.update(BOOK_UNIT='U11a', BOOK_SCENARIO='cold')
            values.update({k: str(v) for k, v in env.items()})
            result = subprocess.run(['bash', '-c', STUB + prefix + self.block()], env=values, capture_output=True, text=True, timeout=60)
            calls = log.read_text().splitlines() if log.exists() else []
            return dict(status=result.returncode, calls=calls, stderr=result.stderr,
                        config=json.loads(config.read_text()) if config.exists() else None,
                        stop=paths['stopPath'].read_text() if paths['stopPath'].exists() else None, paths=paths,
                        finish=(root / 'batch' / 'operator-finish.json').exists())

    def index(self, calls, prefix):
        return next(i for i, call in enumerate(calls) if call.startswith(prefix))

    def test_launch_order_prepare_launch_drive_stop_wait_check_finish(self):
        r = self.run_sequence(DRIVE=0, CONTROLLER=3, GUARDIAN=0)
        calls = r['calls']
        self.assertEqual(r['status'], 0, r['stderr'])
        order = ['book.py request', 'book.py start', 'release.py --lane', 'scenario.py name', 'scenario.py prepare']
        self.assertEqual([self.index(calls, x) for x in order], sorted(self.index(calls, x) for x in order))
        # launch.py and the drive step both run in the background after prepare; their log lines may interleave
        prepare = self.index(calls, 'scenario.py prepare')
        self.assertTrue(prepare < self.index(calls, 'launch.py --config') and prepare < self.index(calls, 'scenario.py drive'))
        self.assertLess(self.block().index('launch.py" --config'), self.block().index('scenario.py" drive'))
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
        self.assertIn('guardian-grace --quit-grace 5', r['calls'])  # run config default when quitGraceSeconds is absent
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
                self.assertEqual((r['status'], r['calls'][0], r['calls'][2]), (2, 'book.py request', 'book.py withdraw'))
                self.assertNotIn('book.py start', ' '.join(r['calls']))
                self.assertIn('WITHDRAWN: booking=b1 before start (status 2)', r['stderr'])

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

    U6 = ('BUILD_ARGS=(--scratch /attempt/scratch --private-tool copilot)\n'
          'ACTION_ARGS=(--pointer-binary /kit/pointer_drive)\n')

    def u6(self, **env):
        return self.run_sequence(build=True, prefix=self.U6, DRIVE=0, CONTROLLER=3, GUARDIAN=0, **env)

    def test_u6_branch_builds_then_starts_then_monitors_actions_and_closes(self):  # macrev-332-16, -17
        r = self.u6(); calls = r['calls']
        self.assertEqual(r['status'], 0, r['stderr'])
        # Foreground steps in strict order (the background guardian, launch.py and monitor log as they start).
        order = ['book.py request', 'scenario.py build', 'book.py start', 'release.py --lane',
                 'scenario.py name', 'scenario.py prepare', 'scenario.py has-actions', 'started-ok', 'action-args',
                 'actions-exit', 'scenario.py drive saw-finish', 'check_launch_cleanup.py', 'book.py finish']
        self.assertEqual([self.index(calls, x) for x in order], sorted(self.index(calls, x) for x in order), calls)
        self.assertLess(self.index(calls, 'book.py start'), self.index(calls, 'guardian.py --lease'))
        for background in ('launch.py --config', 'scenario.py drive'):  # running before the actions end
            self.assertTrue(self.index(calls, 'scenario.py prepare') < self.index(calls, background)
                            < self.index(calls, 'actions-exit'), calls)
        # The monitor runs while the actions do: it ends only on the runner's exclusive hand-off ...
        self.assertTrue(r['finish'])
        # ... and both supervisors are reaped after the monitor and before the closure check.
        for supervisor in ('launch.py exit', 'guardian.py exit'):
            self.assertTrue(self.index(calls, 'scenario.py drive saw-finish') < self.index(calls, supervisor)
                            < self.index(calls, 'check_launch_cleanup.py'))
        block = self.block()
        self.assertLess(block.index('scenario.py" build'), block.index('book.py" start'))
        self.assertLess(block.index('launch.py" --config'), block.index('scenario.py" drive'))
        self.assertLess(block.index('scenario.py" drive'), block.index('scenario.py" started'))
        self.assertLess(block.index('scenario.py" actions'), block.index('wait "$SCENARIO_PID"'))
        self.assertLess(block.index('wait "$SCENARIO_PID"'), block.index('wait "$CONTROLLER_PID"'))
        # One run/epoch: the builder got the same RUN_ID/EPOCH that start used, and the bind kept it.
        run = next(c for c in calls if c.startswith('run='))
        build = calls[self.index(calls, 'build-args')]
        lease = r['config']['expectedLease']
        self.assertEqual(run, 'run=%s epoch=%s' % (lease['runID'], lease['epoch']))
        self.assertIn('--scenario u6 --config %s -- --booking-id b1 --run-id %s --epoch %s --scratch /attempt/scratch'
                      % (r['paths']['stopPath'].parent / 'run.json', lease['runID'], lease['epoch']), build)
        self.assertIn('--pointer-binary /kit/pointer_drive', calls[self.index(calls, 'action-args')])
        self.assertIn('--scenario-status 0', calls[self.index(calls, 'check-args')])

    def test_u6_failing_action_still_stops_and_closes_but_never_finishes(self):
        r = self.u6(ACTION=4); calls = r['calls']
        self.assertNotIn('actions-exit', calls); self.assertFalse(r['finish'])  # no hand-off from anyone else
        self.assertEqual(json.loads(r['stop'])['reason'], 'scenario-actions-failed')
        self.assertIn('scenario.py drive saw-stop', calls)
        for step in ('launch.py exit', 'guardian.py exit'):
            self.assertLess(self.index(calls, step), self.index(calls, 'check_launch_cleanup.py'))
        self.assertIn('--scenario-status 4', calls[self.index(calls, 'check-args')])
        self.assertNotIn('book.py finish', calls)
        self.assertIn('NEEDS-COORDINATOR', r['stderr']); self.assertIn('actions=4', r['stderr'])
        self.assertNotIn('aborted', r['stderr'])  # a closure question, not an abort

    def test_u6_missing_started_row_skips_actions_and_still_closes(self):
        r = self.u6(STARTED=3); calls = r['calls']
        self.assertNotIn('action-args', ' '.join(calls)); self.assertFalse(r['finish'])
        self.assertEqual(json.loads(r['stop'])['reason'], 'scenario-actions-failed')
        self.assertLess(self.index(calls, 'guardian.py exit'), self.index(calls, 'check_launch_cleanup.py'))
        self.assertIn('--scenario-status 3', calls[self.index(calls, 'check-args')])
        self.assertNotIn('book.py finish', calls)

    def test_u6_builder_failure_stops_before_start(self):
        r = self.u6(BUILD=2)
        self.assertEqual(r['status'], 2)
        self.assertLess(self.index(r['calls'], 'scenario.py build'), self.index(r['calls'], 'book.py withdraw'))
        self.assertIn('--id b1 --lane M1', r['calls'][self.index(r['calls'], 'withdraw-args')])
        self.assertNotIn('book.py start', ' '.join(r['calls'])); self.assertIsNone(r['config'])
        self.assertIsNone(r['stop']); self.assertNotIn('NEEDS-COORDINATOR', r['stderr'])  # nothing started: withdrawn
        self.assertIn('WITHDRAWN: booking=b1', r['stderr'])

    def test_u6_requests_the_registry_unit_and_scenario(self):  # macrev-332-27
        r = self.u6()
        self.assertIn('--lane M1 --unit U6 --scenario U6-DockMenu-synthetic --minutes 20',
                      r['calls'][self.index(r['calls'], 'request-args')])
        self.assertNotIn('book.py withdraw', r['calls'])  # started: the stop trap replaced the pre-start trap

    def test_pre_start_withdraw_failure_claims_no_closure(self):  # macrev-332-28
        r = self.u6(BUILD=2, WITHDRAW=1)
        self.assertEqual(r['status'], 2)
        self.assertIn('NEEDS-COORDINATOR: booking=b1 withdraw failed before start (status 2); no closure claimed', r['stderr'])
        self.assertNotIn('WITHDRAWN', r['stderr']); self.assertNotIn('stays started', r['stderr'])
        self.assertNotIn('book.py finish', r['calls'])

    def test_u6_built_config_for_another_run_is_refused_after_start(self):
        r = self.u6(WRONG_RUN='-other')
        self.assertEqual(r['status'], 3)
        self.assertNotIn('guardian.py --lease', ' '.join(r['calls'])); self.assertNotIn('book.py finish', r['calls'])
        self.assertIn('another run/epoch', r['stderr']); self.assertIn('NEEDS-COORDINATOR', r['stderr'])

    def test_drive_mode_uses_its_own_closure_check(self):
        r = self.run_sequence(mode='drive', name='', CONTROLLER=0)
        calls = r['calls']
        self.assertIn('drive-scenario.py --config', calls); self.assertNotIn('launch.py --config', calls)
        self.assertNotIn('scenario.py name', calls); self.assertNotIn('check_launch_cleanup.py --config', calls)
        self.assertLess(self.index(calls, 'check_drive_cleanup.py'), self.index(calls, 'book.py finish'))
        self.assertNotIn('book.py finish', self.run_sequence(mode='drive', name='', CHECK=1)['calls'])


# Real book.py, guardian.py, release.py, scenario.py (booking-*, name, build) and admission on a disposable ledger;
# only the builder (a fake writing what U6/prepare_config.py writes), Launch, the monitor and the closure check are
# stand-ins. `prepare` runs the real admission.load_and_admit that drive-u6.py prepare runs.
REAL_STUB = r"""
python3() {
  if [ "$1" != -B ]; then echo "NO-B $*" >> "$LOG"; return 99; fi; shift
  if [ "$1" = -c ]; then "$REAL_PY" -B "$@"; return; fi
  s=${1##*/}; echo "$s $2" >> "$LOG"
  case "$s" in
    book.py|guardian.py|release.py) "$REAL_PY" -B "$REAL_BIN/$s" "${@:2}" ;;
    scenario.py) case "$2" in
        build) "$REAL_PY" -B -c 'import sys; sys.path.insert(0, sys.argv[1]); import scenario; from pathlib import Path
sys.exit(scenario.main(sys.argv[3:], Path(sys.argv[2])))' "$REAL_BIN" "$KIT_REGISTRY" "${@:2}" ;;
        prepare) "$REAL_PY" -B -c 'import json,sys,time; sys.path.insert(0, sys.argv[1]); import admission; from pathlib import Path
c = json.load(open(sys.argv[2])); end = time.monotonic() + 3
while json.loads(Path(c["leasePath"]).read_text()).get("guardian") is not True and time.monotonic() < end: time.sleep(.05)
a = admission.load_and_admit(c); print("admitted", a["booking"]["unit"], a["booking"]["scenario"])' "$REAL_BIN" "$RUN_CONFIG" >> "$LOG" ;;
        drive|started|actions) return 0 ;;
        *) "$REAL_PY" -B "$REAL_BIN/scenario.py" "${@:2}" ;;
      esac ;;
    launch.py) while [ ! -e "$STOP_PATH" ]; do sleep 0.02; done; return 3 ;;
    check_launch_cleanup.py) return 0 ;;
  esac
}
"""

FAKE_BUILDER = r"""import json, os, subprocess, sys
a = dict(zip(sys.argv[1::2], sys.argv[2::2])); ledger = os.environ['MODELPLAN_BOOKING_LEDGER']
book = [sys.executable, '-B', os.environ['REAL_BIN'] + '/book.py']
if os.environ.get('QUEUE_NEXT'):  # another lane queues behind this booking
    subprocess.run(book + ['request', '--lane', 'M2', '--unit', 'U6', '--scenario', 'next'], check=True, capture_output=True)
if os.environ.get('WITHDRAW_FIRST'):  # someone else already withdrew it: the sequence's own withdraw must fail
    subprocess.run(book + ['withdraw', '--id', a['--booking-id'], '--coordinator', '--reason', 'test'], check=True, capture_output=True)
if os.environ.get('FAIL_BUILD'): sys.exit(2)
root = os.environ['ATTEMPT']
json.dump(dict(scenario='u6', profile='synthetic', binarySHA256='a' * 64, argv=['/bin/true', '--u6-drive-contract', 'x'],
               requiredSeconds=300, quitGraceSeconds=5, leasePath=root + '/lease.json', releasePath=root + '/release.json',
               stopPath=root + '/batch/stop.json', subjectPidPath=root + '/subject.json',
               booking=dict(id=a['--booking-id'], lane='M1', unit=os.environ.get('FAKE_UNIT', 'U6'),
                            scenario='U6-DockMenu-synthetic', ledger=ledger),
               expectedLease=dict(runID=a['--run-id'], epoch=a['--epoch'])), open(a['--config'], 'x'))
"""


class SkillRealLedgerTests(unittest.TestCase):
    """macrev-332-27/-28: the documented shell against a real disposable book.Ledger."""
    block = SkillLaunchBranchTests.block

    def run_real(self, **env):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); (root / 'batch').mkdir(); kit = root / 'kit'; (kit / 'bin').mkdir(parents=True)
            (kit / 'fake_builder.py').write_text(FAKE_BUILDER)
            entry = dict(json.loads((BIN / 'scenarios.json').read_text())['u6'], config='../fake_builder.py')
            (kit / 'bin' / 'scenarios.json').write_text(json.dumps(dict(u6=entry)))
            ledger = root / 'ledger.jsonl'; log = root / 'calls'
            values = dict(LOG=str(log), REAL_PY=sys.executable, REAL_BIN=str(BIN), KIT_REGISTRY=str(kit / 'bin' / 'scenarios.json'),
                          ATTEMPT=str(root), MODELPLAN_BOOKING_LEDGER=str(ledger), CONTROLLER_MODE='launch',
                          RUN_CONFIG=str(root / 'batch' / 'run.json'), BUILD_SCENARIO='u6',
                          APPROVAL_URL='https://example.test/coordinator#issuecomment-1', PATH='/usr/bin:/bin')
            values.update({k: str(v) for k, v in env.items()})
            result = subprocess.run(['bash', '-c', REAL_STUB + self.block()], env=values, capture_output=True, text=True, timeout=90)
            state = json.loads(subprocess.run([sys.executable, '-B', str(BIN / 'book.py'), '--ledger', str(ledger), 'status'],
                                              capture_output=True, text=True, check=True).stdout)
            next_start = None
            if env.get('QUEUE_NEXT'):
                next_id = next(b['id'] for b in state['queue'] if b['lane'] == 'M2')
                next_start = subprocess.run([sys.executable, '-B', str(BIN / 'book.py'), '--ledger', str(ledger), 'start',
                                             '--id', next_id, '--lane', 'M2', '--run-id', 'next', '--epoch', 'next'],
                                            capture_output=True, text=True)
            return dict(status=result.returncode, stderr=result.stderr, state=state, next_start=next_start,
                        calls=log.read_text().splitlines() if log.exists() else [])

    def mine(self, state):
        return next(b for b in state['queue'] + state['history'] if b['lane'] == 'M1')

    def test_registry_booking_is_admitted_through_build_start_prepare_and_finish(self):  # macrev-332-27
        r = self.run_real()
        self.assertEqual(r['status'], 0, r['stderr'])
        self.assertIn('admitted U6 U6-DockMenu-synthetic', r['calls'])  # real admission matched the real ledger head
        booking = self.mine(r['state'])
        self.assertEqual((booking['unit'], booking['scenarios'], booking['state']), ('U6', ['U6-DockMenu-synthetic'], 'finished'))

    def test_a_different_built_unit_is_refused_and_withdrawn(self):
        r = self.run_real(FAKE_UNIT='U7')
        self.assertNotEqual(r['status'], 0)
        self.assertIn('books another unit/scenario', r['stderr'])
        self.assertNotIn('book.py start', ' '.join(r['calls']))
        self.assertEqual(self.mine(r['state'])['state'], 'withdrawn')

    def test_builder_failure_withdraws_so_the_next_booking_can_start(self):  # macrev-332-28
        r = self.run_real(FAIL_BUILD=1, QUEUE_NEXT=1)
        self.assertEqual(r['status'], 2)
        self.assertEqual(self.mine(r['state'])['state'], 'withdrawn')
        self.assertEqual(r['state']['head']['lane'], 'M2')
        self.assertEqual(r['next_start'].returncode, 0, r['next_start'].stderr)
        self.assertIn('WITHDRAWN: booking=', r['stderr']); self.assertNotIn('NEEDS-COORDINATOR', r['stderr'])

    def test_failed_withdraw_needs_the_coordinator_and_claims_no_closure(self):
        r = self.run_real(FAIL_BUILD=1, WITHDRAW_FIRST=1)
        self.assertEqual(r['status'], 2)
        self.assertRegex(r['stderr'], r'NEEDS-COORDINATOR: booking=\S+ withdraw failed before start \(status 2\); no closure claimed')
        self.assertNotIn('WITHDRAWN', r['stderr']); self.assertNotIn('book.py start', ' '.join(r['calls']))


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
