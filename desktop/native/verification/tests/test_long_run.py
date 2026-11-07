# SPDX-License-Identifier: MIT
"""detach.py and hold.py: a run that outlives short tool calls, and probes served during its hold.
The whole sequence through the real CLIs is in test_m1_sequence_e2e.py (LongRunFromShortToolCalls)."""
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from unittest import mock

BIN = Path(__file__).resolve().parents[1] / 'bin'
sys.path.insert(0, str(BIN))
import detach  # noqa: E402
import hold as hold_run  # noqa: E402
import launch  # noqa: E402
import subject_options  # noqa: E402

PROBE = ['doctor', 'readers', '--json']
HELPER = '#!/bin/sh\nenv | sort\n'
SLOW_HELPER = '#!/bin/sh\nexec sleep 60\n'


class Base(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        launch.RUN.update(hold=None)

    def helper(self, text=HELPER):
        path = self.root / 'modelplan'; path.write_text(text); path.chmod(0o755)
        return path

    def hold(self, helper, seconds=100, env=None):
        hold = hold_run.Hold(seconds, self.root / 'probes', helper, env or {'HOME': '/h', 'PATH': '/usr/bin:/bin'})
        hold.begin(1000.0)
        self.addCleanup(hold.close, 0.0)
        return hold

    def ask(self, name, argv=PROBE):
        (self.root / 'probes' / (name + '.request.json')).write_text(json.dumps(dict(argv=argv)))

    def result(self, name):
        return json.loads((self.root / 'probes' / (name + '.result.json')).read_text())

    def run_probe(self, hold, now=1001.0):
        hold.tick(now)
        hold.active['process'].wait(10)
        hold.tick(now + 1)


class DetachTests(Base):
    def test_command_survives_the_end_of_the_callers_process_group(self):
        record = self.root / 'record'; flag = self.root / 'flag'
        code = f'import pathlib,sys,time;time.sleep(1);pathlib.Path({str(flag)!r}).touch();print("done");sys.exit(7)'
        caller = subprocess.Popen(['/bin/sh', '-c', '"$@"; sleep 60', 'call', sys.executable, str(BIN / 'detach.py'), 'start',
                                   '--record', str(record), '--stdout', str(self.root / 'out'), '--stderr', str(self.root / 'err'),
                                   '--', sys.executable, '-c', code], stdout=subprocess.DEVNULL, start_new_session=True)
        end = time.monotonic() + 10
        while not record.exists() and time.monotonic() < end:
            time.sleep(0.02)
        os.killpg(caller.pid, signal.SIGKILL); caller.wait(10)
        status, result = detach.wait(record, 20)
        self.assertEqual((status, result['exit']), (0, 7))
        self.assertTrue(flag.exists())
        self.assertEqual((self.root / 'out').read_text(), 'done\n')

    def test_wait_reports_running_and_a_lost_runner(self):
        record = self.root / 'record'
        record.write_text(json.dumps(dict(runner=dict(pid=5, startSeconds=1, startMicroseconds=0), exit=None)))
        same = lambda pid: dict(pid=pid, startSeconds=1, startMicroseconds=0)
        self.assertEqual(detach.wait(record, 0, lookup=same)[0], 2)
        self.assertEqual(detach.wait(record, 0, lookup=lambda pid: None)[0], 3)
        reused = lambda pid: dict(pid=pid, startSeconds=2, startMicroseconds=0)
        self.assertEqual(detach.wait(record, 0, lookup=reused)[0], 3)

    def test_an_existing_record_is_refused(self):
        record = self.root / 'record'; record.write_text('{}')
        with self.assertRaisesRegex(ValueError, 'already exists'):
            detach.start(str(record), 'o', 'e', ['true'])


class HoldTests(Base):
    def test_probe_runs_the_engine_with_the_launch_contract_environment(self):
        hold = self.hold(self.helper(), env={'HOME': '/h', 'PATH': '/usr/bin:/bin', 'MODELPLAN_READERS': 'off',
                                             'CODEX_HOME': '/elsewhere', 'CFFIXED_USER_HOME': '/h'})
        self.ask('a')
        self.run_probe(hold)
        result = self.result('a')
        self.assertEqual((result['exit'], result['error']), (0, None))
        output = Path(result['stdoutPath']).read_text()
        self.assertIn('MODELPLAN_READERS=off', output)
        self.assertNotIn('CODEX_HOME', output)
        self.assertNotIn('CFFIXED_USER_HOME', output)
        self.assertEqual(Path(result['stdoutPath']).stat().st_mode & 0o777, 0o600)
        self.assertEqual(hold.summary(1010.0)['probes'],
                         [dict(argv=PROBE, exit=0, error=None, stdoutSHA256=result['stdoutSHA256'])])

    def test_only_listed_probes_run(self):
        hold = self.hold(self.helper())
        for name, argv in (('a', ['doctor', 'readers', '--json', '--refresh']), ('b', 'doctor'), ('c', ['status'])):
            self.ask(name, argv)
        hold.tick(1001.0)
        self.assertIsNone(hold.active)
        for name in 'abc':
            self.assertEqual(self.result(name)['error'], 'probe not allowed')
        with self.assertRaisesRegex(ValueError, 'probe not allowed'):
            hold_run.request(dict(subjectPidPath=str(self.root / 'pid')), ['status'], 1)

    def test_probe_needs_a_bundled_engine(self):
        hold = self.hold(None)
        self.ask('a')
        hold.tick(1001.0)
        self.assertEqual(self.result('a')['error'], 'probes need an app-zip subject')

    def test_hold_ends_on_time_but_waits_for_a_running_probe(self):
        hold = self.hold(self.helper(SLOW_HELPER), seconds=10)
        self.ask('a')
        self.assertFalse(hold.tick(1009.0))
        self.assertFalse(hold.tick(1011.0))  # elapsed, probe still running
        hold.active['process'].kill(); hold.active['process'].wait(10)
        self.assertTrue(hold.tick(1012.0))
        self.assertEqual(hold.summary(1012.0)['heldSeconds'], 12.0)

    def test_request_after_the_hold_is_not_served(self):
        hold = self.hold(self.helper(), seconds=10)
        self.ask('a')
        self.assertTrue(hold.tick(1010.0))
        self.assertFalse((self.root / 'probes' / 'a.result.json').exists())

    def test_slow_probe_is_killed_and_recorded(self):
        hold = self.hold(self.helper(SLOW_HELPER))
        self.ask('a')
        hold.tick(1001.0)
        process = hold.active['process']
        hold.tick(1001.0 + hold_run.PROBE_SECONDS)
        self.assertIsNotNone(process.returncode)
        self.assertEqual(self.result('a')['error'], 'timeout')

    def test_close_stops_a_running_probe_before_the_restore(self):
        hold = self.hold(self.helper(SLOW_HELPER))
        self.ask('a')
        hold.tick(1001.0)
        process = hold.active['process']
        hold.close(1002.0)
        self.assertIsNotNone(process.returncode)
        self.assertEqual(self.result('a')['error'], 'run-ended')
        self.assertFalse(hold.summary(1002.0)['complete'])

    def test_client_gets_the_result_from_a_serving_launcher(self):
        config = dict(subjectPidPath=str(self.root / 'pid'))
        hold = hold_run.Hold(100, hold_run.probe_dir(config), self.helper(), {'PATH': '/usr/bin:/bin'})
        hold.begin(time.time()); stop = threading.Event()

        def serve():
            while not stop.is_set():
                hold.tick(time.time()); time.sleep(0.02)
        thread = threading.Thread(target=serve); thread.start()
        try:
            result = hold_run.request(config, PROBE, 10)
        finally:
            stop.set(); thread.join()
        self.assertEqual(result['exit'], 0)

    def test_client_without_a_hold_run_fails_clearly(self):
        config = self.root / 'run.json'; config.write_text(json.dumps(dict(subjectPidPath=str(self.root / 'pid'))))
        self.assertEqual(hold_run.main(['--config', str(config), *PROBE]), 2)


class LaunchHoldTests(Base):
    def config(self, **fields):
        return dict(stopPath=str(self.root / 'STOP'), **fields)

    def test_contract_and_lease_limits(self):
        for bad in (0, -1, 1.5, '200', True):
            with self.assertRaisesRegex(ValueError, 'holdSeconds'):
                subject_options.validate({'holdSeconds': bad})
        subject_options.validate({'holdSeconds': 200})
        with self.assertRaisesRegex(ValueError, '--holdSeconds conflicts'):
            subject_options.merge_flags({'holdSeconds': 10}, holdSeconds=20)
        lease = dict(expiresAt=1000)
        hold_run.check_fits(dict(holdSeconds=200, lease=lease), 740)
        with self.assertRaisesRegex(ValueError, 'does not fit the booking; 199 left'):
            hold_run.check_fits(dict(holdSeconds=200, lease=lease), 741)

    def test_elapsed_hold_writes_the_stop_file_and_closes_as_any_stop(self):
        class Child:
            returncode = None
            def poll(self): return self.returncode
            def terminate(self): self.returncode = -15
            def wait(self, timeout=None): return self.returncode
        hold = mock.Mock(); hold.tick.return_value = True
        config = self.config()
        reasons = lambda c, now: 'stop-file' if Path(c['stopPath']).exists() else None
        child = Child()
        with mock.patch.object(launch, 'stop_reason', side_effect=reasons):
            self.assertEqual(launch.supervise(child, config, sleep=lambda _: None, hold=hold), 'stop-file')
        self.assertEqual(json.loads(Path(config['stopPath']).read_text())['reason'], 'hold-complete')
        self.assertEqual(child.returncode, -15)

    def test_exit_status_says_whether_the_hold_was_kept(self):
        config = self.config()
        hold = mock.Mock(done=True); launch.RUN['hold'] = hold
        self.addCleanup(launch.RUN.update, hold=None)
        self.assertEqual(launch.ended(config, 'stop-file'), ('hold-complete', 0))
        self.assertFalse(Path(config['stopPath']).exists())
        hold.done = False
        self.assertEqual(launch.ended(config, 'stop-file'), ('stop-file', 3))
        self.assertEqual(launch.ended(config, 'guardian-heartbeat-stale'), ('guardian-heartbeat-stale', 3))
        self.assertEqual(launch.ended(config, None), ('subject-ended-before-hold', 3))
        self.assertTrue(Path(config['stopPath']).exists())
        launch.RUN['hold'] = None
        self.assertEqual(launch.ended(config, None), (None, 0))
        self.assertEqual(launch.ended(config, 'deadline'), ('deadline', 3))

    def test_a_hold_the_lease_cannot_cover_is_refused_before_spawn(self):
        binary = self.root / 'subject'; binary.write_bytes(b'x')
        config = self.root / 'run.json'
        config.write_text(json.dumps(dict(profile='synthetic', syntheticHome=str(self.root / 'home'), syntheticTmp=str(self.root / 'tmp'),
                                          argv=[str(binary)], binarySHA256=hashlib.sha256(b'x').hexdigest(),
                                          subjectPidPath=str(self.root / 'pid'), lease=dict(expiresAt=time.time() + 100))))
        with mock.patch.object(launch, 'load_and_admit', side_effect=lambda x: x), \
                mock.patch.object(launch.subprocess, 'Popen') as popen, \
                self.assertRaisesRegex(ValueError, 'does not fit the booking'):
            launch.main(['--config', str(config), '--execute', '--hold-seconds', '200'])
        popen.assert_not_called()
        self.assertFalse((self.root / 'pid.probes').exists())


if __name__ == '__main__':
    unittest.main()
