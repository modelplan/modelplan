# SPDX-License-Identifier: MIT
import argparse
import contextlib
import io
import json
import os
from pathlib import Path
import subprocess
import socket
import sys
import tarfile
import tempfile
import time
import unittest
from unittest.mock import patch

import run as drive
import release


class DriverClock:
    """Virtual clock for the driver's own time budgets (wall and monotonic).

    Time advances only when the driver sleeps, never while it does preflight
    I/O, so a slow host cannot spend the budget before a case has started.
    Each driver sleep still yields briefly for real, so the subject worker and
    its process group are real and actually running. `on_sleep` runs on every
    driver sleep: the first one happens inside the active case's wait loop.
    """
    HOLD_LIMIT = 30  # real seconds; a hold never outlives it

    def __init__(self, on_sleep=None, hold_limit=HOLD_LIMIT):
        self.wall = time.time()
        self.mono = time.monotonic()
        self.on_sleep = on_sleep
        self.sleeps = 0
        self.hold_limit = hold_limit
        self.held_since = None
        self.hold_expired = False

    def time(self):
        return self.wall

    def monotonic(self):
        return self.mono

    def sleep(self, seconds):
        self.sleeps += 1
        # on_sleep may return False to hold virtual time until an event happens.
        # A hold is bounded in real time: after hold_limit the clock runs again,
        # so the driver's own scenario/run deadlines end the case and the test
        # fails on its outcome (and hold_expired) instead of hanging.
        hold = self.on_sleep is not None and self.on_sleep(self) is False
        if hold and not self.hold_expired:
            self.held_since = self.held_since or time.monotonic()
            if time.monotonic() - self.held_since >= self.hold_limit:
                self.hold_expired = True
        if not hold:
            self.held_since = None
        if not hold or self.hold_expired:
            self.advance(seconds)
        time.sleep(min(seconds, .01))

    def advance(self, seconds):
        self.wall += seconds
        self.mono += seconds


class DriveTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='engine-drive-test-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.binary = self.root / 'subject'
        self.binary.write_text('#!/usr/bin/env python3\nimport time\ntime.sleep(30)\n')
        self.binary.chmod(0o700)
        self.args = argparse.Namespace(output=self.root / 'evidence', binary=self.binary,
            source_sha='a' * 40, release=None, old_release=[],
            shape=Path(__file__).with_name('profile.json'), context=None, level='L1',
            run_id='test-run', attempt='1', epoch='test-epoch', timeout=20,
            scenario_timeout=1, deadline=None, stop_file=None)
        drive.STOP = False

    def execute(self, clock=None):
        with contextlib.redirect_stdout(io.StringIO()), \
             (patch.object(drive, 'time', clock) if clock else contextlib.nullcontext()):
            status = drive.execute(self.args)
        manifest = json.loads((self.args.output / 'manifest.json').read_text())
        return status, manifest

    def test_loopback_recording_trap_does_not_probe_host_dns(self):
        with patch.object(socket, 'getfqdn', side_effect=AssertionError('DNS forbidden')), \
             patch.object(socket, 'gethostbyaddr', side_effect=AssertionError('DNS forbidden')):
            server = drive.LoopbackTrapServer(('127.0.0.1', 0), drive.fixture.Trap)
            try:
                self.assertEqual(server.server_address[0], '127.0.0.1')
                self.assertEqual(server.server_name, 'localhost')
            finally:
                server.server_close()

    def test_source_or_pending_profile_cannot_qualify_as_l2(self):
        self.args.level = 'L2'
        unapproved = json.loads(self.args.shape.read_text())
        unapproved.update(fidelity='hand-built', approvalRef=None)
        self.args.shape = self.root / 'pending-profile.json'
        self.args.shape.write_text(json.dumps(unapproved))
        status, result = self.execute()
        self.assertEqual(status, 1)
        self.assertIsNone(result['earnedLevel'])
        self.assertIn('released-subject-required', result['qualification'])
        self.assertIn('coordinator-shape-approval-required', result['qualification'])
        self.assertTrue(all(s['outcome'] == 'unsupported' for s in result['scenarios']))
        self.assertEqual(result['cleanup']['outcome'], 'cleaned', result['cleanup'])
        self.assertFalse((self.args.output / '.work').exists())

    def test_hosted_mac_is_l1_even_with_approved_inputs(self):
        shape = dict(fidelity='approved-shape-export', approvalRef='shape-review')
        subject = dict(kind='released')
        context = dict(dedicatedTestMac=True, approvalRef='run-review')
        with patch.object(drive.platform, 'system', return_value='Darwin'), patch.dict(os.environ, GITHUB_ACTIONS='true'):
            self.assertEqual(drive.qualification('L2', shape, subject, {'v0.5.46': {}, 'v0.5.47': {}}, context),
                             ['dedicated-test-mac-required'])
        with patch.object(drive.platform, 'system', return_value='Darwin'), patch.dict(os.environ, GITHUB_ACTIONS='false'):
            self.assertEqual(drive.qualification('L2', shape, subject, {'v0.5.46': {}, 'v0.5.47': {}}, context), [])

    def test_stop_records_not_run_and_preserves_subject_profile(self):
        self.args.stop_file = self.root / 'stop'
        self.args.stop_file.touch()
        status, result = self.execute()
        self.assertEqual(status, 1)
        self.assertTrue(all(s['outcome'] == 'not-run' and s['reason'] == 'caller-stop' for s in result['scenarios']))
        self.assertEqual(result['subject']['binarySHA256'], release.sha(self.binary.read_bytes()))
        self.assertEqual(result['cleanup']['outcome'], 'cleaned', result['cleanup'])

    def test_timeout_reaps_owned_worker_and_keeps_outcome(self):
        # A real stalled subject exercises supervisor/worker process-group cleanup.
        # One scenario is enough; this is not a mock of the timeout implementation.
        # The driver's clock is virtual so slow preflight cannot exhaust the run budget first.
        with patch.object(drive, 'IDS', ['U2-migration']):
            status, result = self.execute(DriverClock())
        self.assertEqual(status, 1)
        self.assertEqual(result['scenarios'][0]['outcome'], 'timeout')
        self.assertEqual(result['scenarios'][0]['reason'], 'scenario-deadline')
        self.assertEqual(result['cleanup']['outcome'], 'cleaned', result['cleanup'])
        self.assertFalse((self.args.output / '.work').exists())

    def test_absolute_deadline_marks_active_case_timeout_and_rest_not_run(self):
        clock = DriverClock()
        self.args.deadline = clock.time() + 17  # 15s cleanup reserve, 2s work
        self.args.scenario_timeout = 20
        with patch.object(drive, 'IDS', ['U2-migration', 'U2-two-writers']):
            status, result = self.execute(clock)
        self.assertEqual(status, 1)
        self.assertGreater(clock.sleeps, 0)  # the deadline hit while the first case was active
        self.assertEqual(result['scenarios'][0]['outcome'], 'timeout')
        self.assertEqual(result['scenarios'][0]['reason'], 'run-deadline')
        self.assertEqual(result['scenarios'][1]['outcome'], 'not-run')
        self.assertEqual(result['scenarios'][1]['reason'], 'run-deadline')
        self.assertEqual(result['cleanup']['outcome'], 'cleaned', result['cleanup'])

    def test_absolute_deadline_survives_slow_preflight(self):
        # Preflight time must count once against the absolute deadline, not twice.
        clock = DriverClock()
        self.args.deadline = clock.time() + 17.5  # 15s reserve, 1.5s preflight, 1s work; the old double count left none
        self.args.scenario_timeout = 20
        real = drive.qualification
        def slow(*a, **k):
            clock.advance(1.5)  # exactly 1.5s of preflight on both clocks, however slow the host is
            return real(*a, **k)
        with patch.object(drive, 'IDS', ['U2-migration', 'U2-two-writers']), patch.object(drive, 'qualification', slow):
            status, result = self.execute(clock)
        self.assertEqual(status, 1)
        self.assertEqual(result['scenarios'][0]['outcome'], 'timeout')
        self.assertEqual(result['scenarios'][0]['reason'], 'run-deadline')
        self.assertEqual(result['scenarios'][1]['outcome'], 'not-run')

    def test_stop_during_case_ends_owned_process_and_keeps_remaining_not_run(self):
        self.args.stop_file = self.root / 'stop-during'
        # Event ordering, not a timer racing the scenario timeout: the driver's clock
        # is held until the worker is running its case (it has built the synthetic
        # home, so its TERM handler is installed), and only then is the stop given.
        home = self.args.output / '.work' / 'U2-migration-home' / 'bin'
        def stop_when_case_runs(clock):
            if not home.exists():
                return False
            self.args.stop_file.touch()
        clock = DriverClock(on_sleep=stop_when_case_runs)
        with patch.object(drive, 'IDS', ['U2-migration', 'U2-two-writers']):
            status, result = self.execute(clock)
        self.assertEqual(status, 1)
        self.assertFalse(clock.hold_expired, 'worker never started its case')
        self.assertTrue(self.args.stop_file.exists())
        self.assertTrue(all(s['outcome'] == 'not-run' and s['reason'] == 'caller-stop'
                            for s in result['scenarios']))
        self.assertEqual(result['cleanup']['outcome'], 'cleaned', result['cleanup'])

    def test_driver_clock_hold_is_bounded_in_real_time(self):
        clock = DriverClock(on_sleep=lambda c: False, hold_limit=.2)
        began = time.monotonic()
        start = clock.monotonic()
        while clock.monotonic() == start:
            self.assertLess(time.monotonic() - began, 5, 'hold never released')
            clock.sleep(.05)
        self.assertTrue(clock.hold_expired)

    def test_stalled_worker_fails_the_stop_test_in_bounded_time(self):
        # A worker that never reaches its case: the hold expires, the driver's
        # own 1s scenario timeout ends the case, and the owned process is reaped.
        self.args.stop_file = self.root / 'never-given'
        clock = DriverClock(on_sleep=lambda c: False, hold_limit=.5)
        began = time.monotonic()
        with patch.object(drive, 'IDS', ['U2-migration']):
            status, result = self.execute(clock)
        self.assertLess(time.monotonic() - began, 15)
        self.assertTrue(clock.hold_expired)
        self.assertEqual(result['scenarios'][0]['outcome'], 'timeout')
        self.assertEqual(result['cleanup']['outcome'], 'cleaned', result['cleanup'])

    def test_stop_before_worker_is_ready_still_confirms_cleanup(self):
        # Stop on the first wait-loop sleep, usually before the worker has
        # installed its TERM handler. Darwin then answers the group KILL with
        # EPERM (only a zombie leader is left). Give that answer on every host,
        # after delivering the KILL, so the outcome does not depend on how far
        # the worker got: cleanup must be proven by the empty-group probe.
        real_killpg = os.killpg
        def darwin_killpg(pgid, sig):
            if sig == drive.signal.SIGKILL:
                with contextlib.suppress(OSError):
                    real_killpg(pgid, sig)
                raise PermissionError(1, 'Operation not permitted')
            return real_killpg(pgid, sig)
        self.args.stop_file = self.root / 'stop-early'
        clock = DriverClock(on_sleep=lambda c: self.args.stop_file.touch())
        with patch.object(drive, 'IDS', ['U2-migration', 'U2-two-writers']), \
             patch.object(drive.os, 'killpg', darwin_killpg):
            status, result = self.execute(clock)
        self.assertEqual(status, 1)
        self.assertGreater(clock.sleeps, 0)  # the stop came while the first case was active
        self.assertTrue(all(s['outcome'] == 'not-run' and s['reason'] == 'caller-stop'
                            for s in result['scenarios']))
        self.assertEqual(result['cleanup']['outcome'], 'cleaned', result['cleanup'])

    def test_eperm_on_group_kill_with_live_member_stays_unconfirmed(self):
        # The EPERM path must prove the group empty; a surviving member is a failure.
        process = subprocess.Popen([sys.executable, '-c',
            'import os,signal,time; signal.signal(signal.SIGTERM, lambda *_: os._exit(0)); '
            'os.fork() == 0 and signal.signal(signal.SIGTERM, signal.SIG_IGN); time.sleep(30)'],
            start_new_session=True, stdin=subprocess.PIPE)
        self.addCleanup(process.stdin.close)
        self.addCleanup(lambda: subprocess.run(['kill', '-9', '--', '-%d' % process.pid], capture_output=True))
        time.sleep(.5)
        real_killpg = os.killpg
        def darwin_killpg(pgid, sig):
            if sig == drive.signal.SIGKILL:
                raise PermissionError(1, 'Operation not permitted')
            return real_killpg(pgid, sig)
        with patch.object(drive.os, 'killpg', darwin_killpg), self.assertRaises(PermissionError):
            drive.terminate(process)
        self.assertIsNotNone(process.returncode)  # leader reaped; a member survived

    def test_cleanup_failure_keeps_original_results_and_durable_evidence(self):
        def finish(args, output, scratch, manifest, *rest):
            for s in manifest['scenarios']:
                s.update(outcome='pass', reason='observed')
            return []
        def fail_cleanup(path):
            before = json.loads((self.args.output / 'manifest.json').read_text())
            self.assertTrue(all(s['outcome'] == 'pass' for s in before['scenarios']))
            self.assertTrue((self.args.output / 'profile.json').exists())
            raise PermissionError('read-only cache')
        with patch.object(drive, 'run_scenarios', side_effect=finish), patch.object(drive.shutil, 'rmtree', side_effect=fail_cleanup):
            status, result = self.execute()
        self.assertEqual(status, 1)
        self.assertEqual(result['outcome'], 'pass')
        self.assertTrue(all(s['outcome'] == 'pass' for s in result['scenarios']))
        self.assertEqual(result['cleanup']['outcome'], 'failed')
        self.assertIsNone(result['earnedLevel'])
        self.assertEqual(json.loads((self.args.output / 'cleanup.json').read_text())['reasons'], ['scratch-removal-failed'])

    def test_preflight_failure_also_has_all_scenario_outcomes(self):
        self.args.binary = self.root / 'missing'
        status, result = self.execute()
        self.assertEqual(status, 1)
        self.assertEqual(result['outcome'], 'not-run')
        self.assertTrue(all(s['reason'] == 'preflight-or-harness-failed' for s in result['scenarios']))
        self.assertEqual(result['cleanup']['outcome'], 'cleaned', result['cleanup'])

    def test_annotated_release_tag_resolves_to_commit_not_tag_object(self):
        tag = io.BytesIO(json.dumps(dict(object=dict(type='tag', sha='a' * 40))).encode())
        commit = io.BytesIO(json.dumps(dict(object=dict(type='commit', sha='b' * 40))).encode())
        with patch.object(release.urllib.request, 'urlopen', side_effect=[tag, commit]):
            self.assertEqual(release.resolve_commit('v0.5.47'), 'b' * 40)
        with patch.object(release, 'resolve_commit', return_value='b' * 40):
            with self.assertRaisesRegex(ValueError, 'release-tag-commit-mismatch'):
                release.fetch('v0.5.47', 'a' * 40, self.root / 'must-not-exist')
        self.assertFalse((self.root / 'must-not-exist').exists())

    def test_release_checksum_and_executable_bytes_are_both_checked(self):
        asset = release.asset_name()
        data = b'ordinary-release-test-bytes'
        stream = io.BytesIO()
        with tarfile.open(fileobj=stream, mode='w:gz') as archive:
            item = tarfile.TarInfo('modelplan')
            item.size = len(data)
            archive.addfile(item, io.BytesIO(data))
        packed = stream.getvalue()
        (self.root / asset).write_bytes(packed)
        (self.root / 'modelplan').write_bytes(data)
        (self.root / 'checksums.txt').write_text(release.sha(packed) + '  ' + asset + '\n')
        record = dict(tag='v0.5.47', commit='b' * 40, asset=asset,
                      archiveSHA256=release.sha(packed), binarySHA256=release.sha(data))
        path = self.root / 'release.json'
        path.write_text(json.dumps(record))
        _, identity = release.verify(path)
        self.assertEqual(identity['binarySHA256'], release.sha(data))
        (self.root / 'modelplan').write_bytes(b'source-build-substitution')
        with self.assertRaisesRegex(ValueError, 'release-executable-mismatch'):
            release.verify(path)
        (self.root / 'modelplan').write_bytes(data)
        (self.root / asset).write_bytes(packed + b'modified')
        with self.assertRaisesRegex(ValueError, 'release-checksum-mismatch'):
            release.verify(path)


if __name__ == '__main__':
    unittest.main()
