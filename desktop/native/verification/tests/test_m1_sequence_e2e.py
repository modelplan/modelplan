# SPDX-License-Identifier: MIT
"""End-to-end run of the M1 booking sequence (SKILL.md section 1) against a fake subject app.

Every step drives the real CLIs in this directory through subprocess (book.py, guardian.py,
release.py, launch.py, drive-scenario.py, check_drive_cleanup.py) with a tiny fake app that
stays up until signalled, in a temporary ledger/run directory. No script internals are
imported, so wiring gaps between the tools surface here.

Legs:
- Launch-mode happy path: request -> start -> guardian -> release -> launch --execute ->
  stop file -> both supervisors exit -> subject gone -> finish --cleaned -> booking finished.
- Drive-mode leg: the same sequence through drive-scenario.py. On Linux the drive subject
  launch stops at the macOS-only process-identity lookup (drive-scenario.py:116 calls
  cleanup-run.py, which dlopens libproc). No test seam exists for that step, so this leg
  asserts the documented expected-fail: admission wiring passes, the attempt is recorded
  not-run with an OSError reason, the guardian cannot confirm closure for the unregistered
  subject and the booking is never finished (see E2E-GAPS.md).
- A second controller on the same booking is refused by the registration lock.
- Drive without a released lease is refused before any child or resource exists.
- A crashed subject leaves the run unclosed: check_drive_cleanup.py fails and the booking
  stays started (no finish), per the closure accounting in SKILL.md.

check_drive_cleanup.py is a drive-mode-only step in SKILL.md; launch-mode closure is the
guardian's confirmed exit. Both are asserted accordingly.

Run (the repo uses unittest; the CI suites discover only verification/ and
verification/tests/, not this directory):
    python3 -m unittest discover -s desktop/native/verification/tests -p 'test_*.py'
"""
import hashlib
import json
import os
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

BIN = Path(__file__).resolve().parents[1] / 'bin'
PY = sys.executable
APPROVAL = 'https://example.test/coordinator/issue-1#issuecomment-1'
FAKE_APP = (
    '#!/usr/bin/env python3\n'
    '# Synthetic M1 subject for the sequence E2E: stays up until signalled.\n'
    'import sys, time\n'
    "if len(sys.argv) > 1 and sys.argv[1] == 'crash':\n"
    '    time.sleep(1.5)\n'  # outlive launch.py registration, then exit by itself
    '    sys.exit(0)\n'
    'while True:\n'
    '    time.sleep(1)\n'
)


def alive(pid):
    if type(pid) is not int or pid <= 0:
        return False
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def wait_until(condition, timeout, message):
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        value = condition()
        if value:
            return value
        time.sleep(0.05)
    raise AssertionError(f'{message} (waited {timeout} seconds)')


class M1Sequence(unittest.TestCase):
    """Temporary ledger/run directory, fake app and CLI helpers shared by every leg."""

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.procs = []
        self.root = Path(self.temp.name)
        self.ledger = self.root / 'ledger.jsonl'
        self.app = self.root / 'fake-app'
        self.app.write_text(FAKE_APP)
        self.app.chmod(0o755)
        self.inputs = self.root / 'inputs'
        self.inputs.mkdir()
        (self.inputs / 'index.html').write_text('<html><body>synthetic</body></html>')

    def tearDown(self):
        for proc in reversed(self.procs):
            if proc.poll() is None:
                proc.terminate()
        for proc in reversed(self.procs):
            if proc.poll() is None:
                try:
                    proc.wait(10)
                except subprocess.TimeoutExpired:
                    proc.kill()
                    proc.wait(10)
        self.temp.cleanup()

    def cli(self, script, *args, timeout=120):
        return subprocess.run([PY, str(BIN / script), *args],
                              capture_output=True, text=True, timeout=timeout)

    def book(self, *args):
        return self.cli('book.py', '--ledger', str(self.ledger), *args)

    def read_json(self, path):
        return json.loads(Path(path).read_text())

    def booking(self, *, minutes, run_id, epoch, lease_path):
        """book.py request + start; returns (booking id, started lease event)."""
        result = self.book('request', '--lane', 'M1', '--unit', 'U11a',
                           '--scenario', 'cold', '--minutes', str(minutes))
        self.assertEqual(result.returncode, 0, result.stderr)
        ident = json.loads(result.stdout)['id']
        result = self.book('start', '--id', ident, '--lane', 'M1',
                           '--run-id', run_id, '--epoch', epoch)
        self.assertEqual(result.returncode, 0, result.stderr)
        lease_path.write_text(result.stdout)
        return ident, json.loads(result.stdout)

    def start_guardian(self, lease_path, stop_path, pid_file):
        out = self.root / 'guardian.out'
        with out.open('w') as stdout:
            proc = subprocess.Popen([PY, str(BIN / 'guardian.py'), '--lease', str(lease_path),
                                     '--stop', str(stop_path), '--subject-pid-file', str(pid_file)],
                                    stdout=stdout, stderr=subprocess.DEVNULL)
        self.procs.append(proc)
        wait_until(lambda: self.beating(lease_path), 10,
                   'guardian did not take over the lease heartbeat')
        return proc, out

    def beating(self, lease_path):
        try:
            lease = self.read_json(lease_path)
        except (OSError, ValueError):
            return None
        beat = lease.get('guardianHeartbeatAt')
        if lease.get('guardian') is not True or type(beat) not in (int, float):
            return None
        return lease if 0 <= time.time() - beat <= 2 else None

    def release(self, ident, lease_path, release_path):
        result = self.cli('release.py', '--ledger', str(self.ledger), '--id', ident, '--lane', 'M1',
                          '--lease', str(lease_path), '--output', str(release_path),
                          '--approval', APPROVAL)
        self.assertEqual(result.returncode, 0, result.stderr)
        return self.read_json(release_path)

    def finish(self, ident, run_id, epoch):
        return self.book('finish', '--id', ident, '--lane', 'M1',
                         '--run-id', run_id, '--epoch', epoch, '--cleaned')

    def status(self):
        result = self.book('status')
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def launch_config(self, ident, lease_path, release_path, stop_path, pid_file, home, tmp, argv):
        config = dict(profile='synthetic',
                      binarySHA256=hashlib.sha256(self.app.read_bytes()).hexdigest(),
                      argv=[str(part) for part in argv],
                      leasePath=str(lease_path), releasePath=str(release_path),
                      stopPath=str(stop_path), syntheticHome=str(home), syntheticTmp=str(tmp),
                      subjectPidPath=str(pid_file), requiredSeconds=30,
                      booking=dict(id=ident, lane='M1', unit='U11a', scenario='cold',
                                   ledger=str(self.ledger)))
        path = self.root / f'launch-{len(argv)}-{home.name}.json'
        path.write_text(json.dumps(config))
        return path

    def start_controller(self, config):
        out = self.root / 'controller.out'
        err = self.root / 'controller.err'
        with out.open('w') as stdout, err.open('w') as stderr:
            proc = subprocess.Popen([PY, str(BIN / 'launch.py'), '--config', str(config), '--execute'],
                                    stdout=stdout, stderr=stderr)
        self.procs.append(proc)
        return proc, out, err

    def registered_subject(self, pid_file, timeout=15):
        def registered():
            try:
                record = self.read_json(pid_file)
            except (OSError, ValueError):
                return None
            return record if record.get('state') == 'running' and alive(record.get('pid')) else None
        return wait_until(registered, timeout, 'subject was never registered as running')

    def json_lines(self, path, count, timeout=15):
        def parsed():
            try:
                text = Path(path).read_text()
            except OSError:
                return None
            lines = [json.loads(line) for line in text.splitlines() if line.strip()]
            return lines if len(lines) >= count else None
        return wait_until(parsed, timeout, f'expected {count} JSON report line(s)')


class LaunchModeHappyPath(M1Sequence):
    def test_book_guardian_release_launch_stop_and_verified_finish(self):
        lease_path = self.root / 'lease.json'
        release_path = self.root / 'release.json'
        stop_path = self.root / 'STOP'
        pid_file = self.root / 'subject.pid'
        ident, lease = self.booking(minutes=2, run_id='run-launch', epoch='epoch-launch',
                                    lease_path=lease_path)
        guardian, guardian_out = self.start_guardian(lease_path, stop_path, pid_file)
        record = self.release(ident, lease_path, release_path)
        self.assertIs(record['m1Released'], True)
        self.assertEqual(record['approval'], APPROVAL)
        self.assertEqual((record['runID'], record['epoch']), (lease['runID'], lease['epoch']))
        repeat = self.cli('release.py', '--ledger', str(self.ledger), '--id', ident, '--lane', 'M1',
                          '--lease', str(lease_path), '--output', str(release_path),
                          '--approval', APPROVAL)
        self.assertEqual(repeat.returncode, 2, repeat.stdout)  # a receipt is never overwritten
        self.assertEqual(record, self.read_json(release_path))

        config = self.launch_config(ident, lease_path, release_path, stop_path, pid_file,
                                    self.root / 'home', self.root / 'tmp', [self.app])
        controller, out, err = self.start_controller(config)
        subject = self.registered_subject(pid_file)
        self.assertEqual(self.json_lines(out, 1)[0]['ownedPID'], subject['pid'])
        self.assertTrue(alive(subject['pid']))

        stop_path.write_text('')  # request stop, then wait for both supervisors (SKILL.md)
        controller_status = controller.wait(30)
        guardian_status = guardian.wait(30)
        self.assertIn(controller_status, (0, 3))  # ended normally or stopped by supervision
        self.assertEqual(guardian_status, 0)
        report = self.json_lines(out, 2)[1]
        self.assertEqual(report['ownedPID'], subject['pid'])
        self.assertEqual(self.read_json(guardian_out),
                         dict(guardian='stopped', subjectClosed=True))
        self.assertFalse(alive(subject['pid']))  # no leftover subject process

        finish = self.finish(ident, 'run-launch', 'epoch-launch')
        self.assertEqual(finish.returncode, 0, finish.stderr)
        state = self.status()
        self.assertIsNone(state['head'])
        self.assertEqual(state['queue'], [])
        done = state['history'][-1]
        self.assertEqual((done['id'], done['state'], done['cleaned']), (ident, 'finished', True))
        self.assertFalse(self.ledger.with_name(self.ledger.name + '.lock').exists())


class OneControllerPerBooking(M1Sequence):
    def test_second_controller_is_refused_and_the_booking_still_closes(self):
        lease_path = self.root / 'lease.json'
        release_path = self.root / 'release.json'
        stop_path = self.root / 'STOP'
        pid_file = self.root / 'subject.pid'
        ident, _ = self.booking(minutes=2, run_id='run-single', epoch='epoch-single',
                                lease_path=lease_path)
        guardian, _ = self.start_guardian(lease_path, stop_path, pid_file)
        self.release(ident, lease_path, release_path)
        config = self.launch_config(ident, lease_path, release_path, stop_path, pid_file,
                                    self.root / 'home', self.root / 'tmp', [self.app])
        controller, _, _ = self.start_controller(config)
        subject = self.registered_subject(pid_file)

        rival = self.launch_config(ident, lease_path, release_path, stop_path, pid_file,
                                   self.root / 'home-rival', self.root / 'tmp-rival', [self.app])
        refused = subprocess.run([PY, str(BIN / 'launch.py'), '--config', str(rival), '--execute'],
                                 capture_output=True, text=True, timeout=60)
        self.assertNotEqual(refused.returncode, 0, refused.stdout)
        self.assertIn('one controller per booking', refused.stderr)
        self.assertEqual(self.read_json(pid_file), subject)  # registration not replaced

        stop_path.write_text('')
        self.assertIn(controller.wait(30), (0, 3))
        self.assertEqual(guardian.wait(30), 0)
        self.assertFalse(alive(subject['pid']))
        finish = self.finish(ident, 'run-single', 'epoch-single')
        self.assertEqual(finish.returncode, 0, finish.stderr)
        self.assertIsNone(self.status()['head'])


class DriveWithoutRelease(M1Sequence):
    def test_drive_without_a_released_lease_is_refused_before_any_resource(self):
        lease_path = self.root / 'lease.json'
        stop_path = self.root / 'STOP'
        pid_file = self.root / 'subject.pid'
        locks = self.root / 'locks'
        locks.mkdir()
        ident, _ = self.booking(minutes=12, run_id='run-unreleased', epoch='epoch-unreleased',
                                lease_path=lease_path)
        guardian, _ = self.start_guardian(lease_path, stop_path, pid_file)
        # No release.py: the run config points at a receipt that was never issued.
        config = self.root / 'drive.json'
        config.write_text(json.dumps(dict(
            runID='run-unreleased', epoch='epoch-unreleased', GO=True,
            announcementID='e2e-synthetic-announcement',
            start=self.read_json(lease_path)['notBefore'],
            expiresAt=self.read_json(lease_path)['expiresAt'],
            batch=str(self.root / 'batch'), scratch=str(self.root / 'scratch'),
            leasePath=str(lease_path), releasePath=str(self.root / 'release.json'),
            stopPath=str(stop_path), subjectPidPath=str(pid_file),
            booking=dict(id=ident, lane='M1', unit='U11a', scenario='cold', ledger=str(self.ledger)),
            binary=str(self.app), binarySHA256=hashlib.sha256(self.app.read_bytes()).hexdigest(),
            head='synthetic-head', inputRoot=str(self.inputs), entry='index.html',
            locks=str(locks), buildRoots=[], resourceRoot=str(self.root), scripts=[])))
        refused = self.cli('drive-scenario.py', '--config', str(config))
        self.assertNotEqual(refused.returncode, 0, refused.stdout)
        self.assertIn('release.json', refused.stderr)
        self.assertFalse((self.root / 'batch').exists())
        self.assertFalse((self.root / 'scratch').exists())
        self.assertEqual(list(locks.iterdir()), [])
        self.assertFalse(pid_file.exists())  # no subject was ever launched
        state = self.status()
        self.assertEqual((state['head']['id'], state['head']['state']), (ident, 'started'))

        guardian.terminate()  # nothing ran: end the leg without finishing the booking
        self.assertEqual(guardian.wait(15), 0)


class CrashedSubject(M1Sequence):
    def test_crashed_subject_leaves_the_run_unclosed_and_the_cleanup_check_fails(self):
        lease_path = self.root / 'lease.json'
        release_path = self.root / 'release.json'
        stop_path = self.root / 'STOP'
        pid_file = self.root / 'subject.pid'
        ident, _ = self.booking(minutes=2, run_id='run-crash', epoch='epoch-crash',
                                lease_path=lease_path)
        guardian, guardian_out = self.start_guardian(lease_path, stop_path, pid_file)
        self.release(ident, lease_path, release_path)
        config = self.launch_config(ident, lease_path, release_path, stop_path, pid_file,
                                    self.root / 'home', self.root / 'tmp', [self.app, 'crash'])
        crashed = subprocess.run([PY, str(BIN / 'launch.py'), '--config', str(config), '--execute'],
                                 capture_output=True, text=True, timeout=60)
        self.assertEqual(crashed.returncode, 0, crashed.stderr)  # the child ended by itself
        report = json.loads(crashed.stdout.splitlines()[-1])
        self.assertIsNone(report['stoppedBy'])
        self.assertEqual(report['exit'], 0)
        subject = self.read_json(pid_file)  # it registered, then exited by itself
        self.assertEqual(subject['state'], 'running')
        self.assertFalse(alive(subject['pid']))

        # The launcher is gone, so the guardian ends the run itself as launcher-lost (exit 3), not as a
        # clean stop, even though the crashed subject is confirmed gone. Waiting for that exit makes the
        # outcome deterministic instead of racing the guardian's next poll.
        self.assertEqual(guardian.wait(15), 3)
        self.assertEqual(self.read_json(guardian_out), dict(guardian='launcher-lost', subjectClosed=True))
        # No verified-cleanup batch exists for this run, so the closure gate fails ...
        gate_config = self.root / 'gate.json'
        gate_config.write_text(json.dumps(dict(batch=str(self.root / 'batch'),
                                               runID='run-crash', epoch='epoch-crash')))
        self.assertEqual(self.cli('check_drive_cleanup.py', str(gate_config)).returncode, 1)
        # ... the sequence must not finish, and the booking (the lease) stays held.
        state = self.status()
        self.assertEqual((state['head']['id'], state['head']['state']), (ident, 'started'))


@unittest.skipUnless(sys.platform.startswith('linux'),
                     'documents the macOS-only drive subject-identity seam; see E2E-GAPS.md')
class DriveModeSequence(M1Sequence):
    def test_sequence_admits_then_stops_at_the_macos_subject_identity_seam(self):
        lease_path = self.root / 'lease.json'
        release_path = self.root / 'release.json'
        stop_path = self.root / 'STOP'
        pid_file = self.root / 'subject.pid'
        locks = self.root / 'locks'
        locks.mkdir()
        ident, lease = self.booking(minutes=12, run_id='run-drive', epoch='epoch-drive',
                                    lease_path=lease_path)
        guardian, guardian_out = self.start_guardian(lease_path, stop_path, pid_file)
        self.release(ident, lease_path, release_path)
        config = self.root / 'drive.json'
        config.write_text(json.dumps(dict(
            runID='run-drive', epoch='epoch-drive', GO=True,
            announcementID='e2e-synthetic-announcement',
            start=lease['notBefore'], expiresAt=lease['expiresAt'],
            batch=str(self.root / 'batch'), scratch=str(self.root / 'scratch'),
            leasePath=str(lease_path), releasePath=str(release_path),
            stopPath=str(stop_path), subjectPidPath=str(pid_file),
            booking=dict(id=ident, lane='M1', unit='U11a', scenario='cold', ledger=str(self.ledger)),
            binary=str(self.app), binarySHA256=hashlib.sha256(self.app.read_bytes()).hexdigest(),
            head='synthetic-head', inputRoot=str(self.inputs), entry='index.html',
            locks=str(locks), buildRoots=[], resourceRoot=str(self.root), scripts=[])))

        result = self.cli('drive-scenario.py', '--config', str(config), timeout=180)
        self.assertEqual(result.returncode, 0, result.stderr)
        report = json.loads(result.stdout.splitlines()[-1])
        # Booking, guardian heartbeat and release all admitted (setup ran); the attempt then
        # stopped at the macOS-only identity lookup, which this environment cannot perform.
        self.assertEqual((report['runID'], report['epoch']), ('run-drive', 'epoch-drive'))
        self.assertEqual(report['outcome'], 'not-run')
        self.assertTrue(report['reason'].startswith('OSError-errno-'), report['reason'])
        self.assertEqual(self.read_json(self.root / 'batch' / 'README.json')['runID'], 'run-drive')
        cleanup = report['cleanup']
        for key in ('ownedExited', 'guardianExited', 'topObserverJoined', 'leaseReleased'):
            self.assertIs(cleanup[key], True)
        self.assertEqual(cleanup['scratchRemoved'], ['home', 'tmp'])
        self.assertEqual(list(locks.iterdir()), [])

        # The exec-gated child was killed before running and never registered, so the
        # guardian cannot confirm closure; the drive-cleanup gate alone does not suffice.
        registration = self.read_json(pid_file)
        self.assertEqual(registration['state'], 'launching')
        self.assertFalse(alive(registration['launcher']['pid']))
        self.assertTrue(stop_path.exists())  # drive wrote it while closing the attempt
        self.assertEqual(guardian.wait(20), 3)
        self.assertIs(self.read_json(guardian_out)['subjectClosed'], False)
        self.assertEqual(self.cli('check_drive_cleanup.py', str(config)).returncode, 0)

        # Closure is unconfirmed: no finish, and the booking keeps holding the lease.
        state = self.status()
        self.assertEqual((state['head']['id'], state['head']['state']), (ident, 'started'))


if __name__ == '__main__':
    unittest.main()
