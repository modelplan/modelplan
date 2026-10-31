# SPDX-License-Identifier: MIT
"""check_launch_cleanup.py: independent, read-only launch-mode closure check."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

BIN = Path(__file__).resolve().parents[1] / 'bin'
sys.path.insert(0, str(BIN))
import book  # noqa: E402
import check_launch_cleanup as check  # noqa: E402
import guardian  # noqa: E402


def exited_identity():
    """The start identity of a process that has exited and been reaped."""
    child = subprocess.Popen([sys.executable, '-c', 'import sys; sys.stdin.read()'], stdin=subprocess.PIPE)
    ident = guardian.identity(child.pid)
    child.stdin.close(); child.wait()
    return ident


class LaunchCleanupTests(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory(); self.root = Path(self.dir.name)
        self.live = []
        ledger = book.Ledger(self.root / 'ledger.jsonl')
        booking = ledger.request('M1', 'U6', ['u6'], 600)['id']
        lease = ledger.start(booking, 'M1', 'run-1', 'epoch-1')
        batch, scratch, locks = self.root / 'batch', self.root / 'scratch', self.root / 'locks'
        for d in (batch, scratch, locks): d.mkdir()
        (self.root / 'lease.json').write_text(json.dumps(lease))
        self.c = dict(profile='synthetic', scenario='u6', argv=['/synthetic/app', '--u6-drive-contract', str(scratch / 'native-guard.json')],
                      expectedLease={k: lease[k] for k in check.IDENTITY},
                      booking=dict(id=booking, lane='M1', unit='U6', scenario='u6', ledger=str(self.root / 'ledger.jsonl')),
                      leasePath=str(self.root / 'lease.json'), stopPath=str(batch / 'stop.json'),
                      subjectPidPath=str(self.root / 'subject.pid'), preparedReceiptPath=str(batch / 'prepared.json'),
                      syntheticHome=str(scratch / 'home'), syntheticTmp=str(scratch / 'tmp'),
                      syntheticHomeSeed=str(scratch / 'home-seed'), batch=str(batch), scratch=str(scratch), locks=str(locks))
        # A fully closed run: stop requested, subject and launcher gone, locks released, scratch removed.
        Path(self.c['stopPath']).write_text(json.dumps(dict(stop=True, reason='run-ended')))
        self.register(exited_identity(), exited_identity())
        Path(self.c['preparedReceiptPath']).write_text(json.dumps(dict(
            prepared=True, runID='run-1', epoch='epoch-1', attempt='token-1',
            locks=[str(locks / 'M1-candidate-gui'), str(locks / 'slot1')])))

    def tearDown(self):
        for child in self.live:
            child.kill(); child.wait()
        self.dir.cleanup()

    def register(self, subject, launcher, **run):
        record = dict(state='running', launcher=launcher, runID='run-1', epoch='epoch-1', **subject)
        record.update(run)
        Path(self.c['subjectPidPath']).write_text(json.dumps(record))

    def alive(self):
        child = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(30)'])
        self.live.append(child)
        return guardian.identity(child.pid)

    def run_check(self, c=None, controller=3, guardian_status=0, scenario_status=0):
        return check.check(c or self.c, controller, guardian_status, scenario_status)

    def reason(self, name, **statuses):
        return self.run_check(**statuses)[1].get(name)

    def assert_fails(self, name, reason=None, **statuses):
        receipt, reasons = self.run_check(**statuses)
        self.assertFalse(receipt['ok'])
        self.assertEqual(receipt['failures'], [name])
        if name not in ('controllerStatus', 'guardianStatus', 'scenarioStatus'):
            self.assertIs(receipt['checks'][name], False)
        if reason is not None:
            self.assertEqual(reasons[name], reason)
        return receipt

    def test_fully_cleaned_run_passes(self):
        for controller in (0, 3):
            receipt, reasons = self.run_check(controller=controller)
            self.assertTrue(receipt['ok'], reasons)
            self.assertEqual((receipt['failures'], receipt['runID'], receipt['epoch'], reasons), ([], 'run-1', 'epoch-1', {}))
            self.assertEqual(receipt['checks']['controllerStatus'], controller)

    def test_subject_alive_fails(self):
        self.register(self.alive(), exited_identity())
        self.assert_fails('subjectGone', 'alive')

    def test_reused_pid_with_another_start_identity_is_not_our_subject(self):
        other = self.alive(); other['startSeconds'] += 1  # same PID, different start: our subject is gone
        self.register(other, exited_identity())
        self.assertTrue(self.run_check()[0]['ok'])

    def test_registration_for_another_run_or_malformed_identity_fails(self):
        self.register(exited_identity(), exited_identity(), runID='run-0')
        receipt, reasons = self.run_check()
        self.assertEqual((receipt['failures'], reasons['subjectGone']), (['subjectGone', 'helpersGone'], 'registration-other-run'))
        self.register(dict(pid='1', startSeconds=1, startMicroseconds=0), exited_identity())
        self.assert_fails('subjectGone', 'identity-malformed')
        Path(self.c['subjectPidPath']).write_text(json.dumps(dict(state='launching', launcher=exited_identity())))
        self.assertEqual(self.reason('subjectGone'), 'registration-unconfirmed')
        os.unlink(self.c['subjectPidPath'])
        self.assertEqual(self.reason('subjectGone'), 'registration-missing')

    def test_launcher_still_alive_fails(self):
        self.register(exited_identity(), self.alive())
        self.assert_fails('helpersGone', 'launcher-alive')

    def test_exit_statuses(self):
        self.assertEqual(self.assert_fails('guardianStatus', 'exit-3', guardian_status=3)['checks']['guardianStatus'], 3)
        self.assert_fails('scenarioStatus', 'exit-3', scenario_status=3)
        self.assert_fails('controllerStatus', 'exit-1', controller=1)
        self.assertIsNone(self.assert_fails('controllerStatus', 'status-missing', controller=None)['checks']['controllerStatus'])
        self.assert_fails('guardianStatus', 'status-missing', guardian_status=None)
        Path(self.c['stopPath']).write_text('')  # an empty stop file carries no reason for a supervised stop
        self.assert_fails('controllerStatus', 'stopped-without-reason', controller=3)
        self.assertTrue(self.run_check(controller=0)[0]['ok'])

    def test_lock_with_this_attempts_token_fails(self):
        lock = Path(self.c['locks']) / 'slot1'; lock.mkdir()
        (lock / 'owner.json').write_text(json.dumps(dict(runID='run-1', epoch='epoch-1', attempt='token-1')))
        self.assert_fails('locksReleased', 'held')
        (lock / 'owner.json').write_text(json.dumps(dict(runID='run-1', epoch='epoch-1', attempt='someone-else')))
        self.assertTrue(self.run_check()[0]['ok'])  # another attempt's lock is not this attempt's to release
        stray = Path(self.c['locks']) / 'unlisted'; stray.mkdir()
        (stray / 'owner.json').write_text(json.dumps(dict(attempt='token-1')))
        self.assert_fails('locksReleased', 'held')

    def test_missing_prepared_receipt_for_a_receipt_scenario_fails(self):
        os.unlink(self.c['preparedReceiptPath'])
        self.assert_fails('locksReleased', 'prepared-receipt-missing')

    def test_home_tmp_or_seed_left_behind_fails(self):
        for name, check_name in (('syntheticHome', 'syntheticHomeRemoved'), ('syntheticTmp', 'syntheticTmpRemoved'),
                                 ('syntheticHomeSeed', 'syntheticHomeRemoved')):
            with self.subTest(name):
                Path(self.c[name]).mkdir()
                self.assert_fails(check_name, 'remains:' + name)
                Path(self.c[name]).rmdir()

    def test_stop_file_missing_fails(self):
        os.unlink(self.c['stopPath'])
        receipt, reasons = self.run_check(controller=0)
        self.assertEqual((receipt['failures'], reasons['stopPathPresent']), (['stopPathPresent'], 'missing'))

    def test_lease_not_closable_fails(self):
        book.Ledger(self.c['booking']['ledger']).finish(self.c['booking']['id'], 'M1', 'run-1', 'epoch-1', cleaned=True)
        self.assert_fails('leaseClosable', 'not-closable')

    def test_lease_identity_and_ledger_problems_fail(self):
        c = dict(self.c, expectedLease=dict(self.c['expectedLease'], epoch='other'))
        receipt, reasons = self.run_check(c)
        self.assertEqual((reasons['leaseClosable'], receipt['runID'], receipt['epoch']), ('lease-identity-mismatch', 'run-1', 'other'))
        with open(self.c['booking']['ledger'], 'ab') as f: f.write(b'{"partial"')
        self.assert_fails('leaseClosable', 'ledger-incomplete')

    def test_evaluation_never_writes(self):
        before = sorted((p.relative_to(self.root), p.stat().st_mtime_ns) for p in self.root.rglob('*'))
        self.run_check(); self.run_check(controller=1)
        self.assertEqual(sorted((p.relative_to(self.root), p.stat().st_mtime_ns) for p in self.root.rglob('*')), before)

    def cli(self, *statuses):
        path = self.root / 'run.json'; path.write_text(json.dumps(self.c))
        flags = [x for name, value in zip(('controller', 'guardian', 'scenario'), statuses) for x in (f'--{name}-status', str(value))]
        return subprocess.run([sys.executable, '-B', str(BIN / 'check_launch_cleanup.py'), '--config', str(path), *flags],
                              capture_output=True, text=True)

    def assert_pinned_shape(self, receipt):
        """launch-cleanup/1, exactly as the U6 evidence builder consumes it."""
        self.assertEqual(set(receipt), {'schema', 'runID', 'epoch', 'ok', 'checks', 'failures', 'at'})
        self.assertEqual(receipt['schema'], 'launch-cleanup/1')
        self.assertIsInstance(receipt['runID'], str); self.assertIsInstance(receipt['epoch'], str)
        self.assertIs(type(receipt['ok']), bool)
        statuses = ('controllerStatus', 'guardianStatus', 'scenarioStatus')
        booleans = ('subjectGone', 'helpersGone', 'leaseClosable', 'locksReleased', 'syntheticHomeRemoved',
                    'syntheticTmpRemoved', 'stopPathPresent')
        self.assertEqual(set(receipt['checks']), set(statuses + booleans))
        for name in statuses:
            self.assertTrue(receipt['checks'][name] is None or type(receipt['checks'][name]) is int, name)
        for name in booleans:
            self.assertIs(type(receipt['checks'][name]), bool, name)
        self.assertIsInstance(receipt['failures'], list)
        self.assertTrue(all(isinstance(x, str) and x in receipt['checks'] for x in receipt['failures']))
        self.assertIs(receipt['ok'], not receipt['failures'])
        self.assertRegex(receipt['at'], r'^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$')

    def test_cli_prints_and_atomically_writes_the_pinned_receipt_beside_the_stop_path(self):
        written = Path(self.c['stopPath']).parent / 'launch-cleanup.json'
        ok = self.cli(0, 0, 0)
        self.assertEqual(ok.returncode, 0, ok.stderr)
        self.assertEqual(len(ok.stdout.splitlines()), 1)
        receipt = json.loads(ok.stdout); self.assert_pinned_shape(receipt)
        self.assertEqual(json.loads(written.read_text()), receipt)
        self.assertEqual((receipt['ok'], receipt['runID'], receipt['epoch'], receipt['failures']), (True, 'run-1', 'epoch-1', []))
        self.assertEqual({k: receipt['checks'][k] for k in ('controllerStatus', 'guardianStatus', 'scenarioStatus')},
                         dict(controllerStatus=0, guardianStatus=0, scenarioStatus=0))
        self.assertTrue(all(v is True for k, v in receipt['checks'].items() if not k.endswith('Status')))
        self.assertEqual(sorted(p.name for p in written.parent.iterdir()), ['launch-cleanup.json', 'prepared.json', 'stop.json'])
        Path(self.c['syntheticTmp']).mkdir()
        missing = self.cli()  # no statuses: unknown, never closed; the receipt is replaced, not appended
        self.assertEqual(missing.returncode, 1)
        receipt = json.loads(missing.stdout); self.assert_pinned_shape(receipt)
        self.assertEqual(json.loads(written.read_text()), receipt)
        self.assertEqual(receipt['failures'], ['controllerStatus', 'guardianStatus', 'scenarioStatus', 'syntheticTmpRemoved'])
        self.assertEqual((receipt['checks']['controllerStatus'], receipt['checks']['syntheticTmpRemoved']), (None, False))
        self.assertEqual(json.loads(missing.stderr)['reasons']['syntheticTmpRemoved'], 'remains:syntheticTmp')
        for stream in (missing.stdout, missing.stderr):
            self.assertNotIn(str(self.root), stream)  # fixed codes only, no paths

    def test_unwritable_receipt_is_not_closure(self):
        Path(self.c['stopPath']).parent.chmod(0o500)
        try:
            result = self.cli(0, 0, 0)
        finally:
            Path(self.c['stopPath']).parent.chmod(0o700)
        if os.geteuid() != 0:
            self.assertEqual(result.returncode, 1)
            self.assertIn('receipt not written', result.stderr)

if __name__ == '__main__':
    unittest.main()
