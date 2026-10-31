# SPDX-License-Identifier: MIT
"""Synthetic ledgers and mocked launchers only: no GUI or Mac access."""
import errno
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import Mock, patch

BIN = Path(__file__).parents[1] / 'bin'
sys.path.insert(0, str(BIN))
import book
import launch

spec = importlib.util.spec_from_file_location('booking_drive', BIN / 'drive-scenario.py')
drive = importlib.util.module_from_spec(spec)
spec.loader.exec_module(drive)


class Bookings(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.path = self.root / 'ledger.jsonl'
        self.now = 1000
        self.ledger = book.Ledger(self.path, clock=lambda: self.now)

    def request(self, lane='M2'):
        return self.ledger.request(lane, 'U11a', ['cold', 'repeat'])['id']

    def cli(self, *args):
        return [sys.executable, str(BIN / 'book.py'), '--ledger', str(self.path), *args]

    def test_concurrent_requests_and_reads_are_serialized_fifo(self):
        children = [subprocess.Popen(self.cli('request', '--lane', f'lane-{i}', '--unit', 'U11a',
                                            '--scenario', 'cold'), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                    for i in range(16)]
        reader = subprocess.Popen(self.cli('status'), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        outputs = []
        for child in children:
            out, err = child.communicate(timeout=15)
            self.assertEqual(child.returncode, 0, err)
            outputs.append(json.loads(out))
        out, err = reader.communicate(timeout=15)
        self.assertEqual(reader.returncode, 0, err)
        self.assertEqual(json.loads(out)['events'], len(json.loads(out)['queue']))
        events = [json.loads(line) for line in self.path.read_text().splitlines()]
        self.assertEqual([e['seq'] for e in events], list(range(1, 17)))
        self.assertEqual(len({e['id'] for e in outputs}), 16)
        state = self.ledger.status()
        self.assertEqual([b['id'] for b in state['queue']], [e['id'] for e in events])
        self.assertEqual(state['head']['id'], events[0]['id'])

    def test_only_one_concurrent_start_wins(self):
        ident = self.request()
        children = [subprocess.Popen(self.cli('start', '--id', ident, '--lane', 'M2',
                                             '--run-id', f'run-{i}', '--epoch', 'epoch'),
                                     stdout=subprocess.PIPE, stderr=subprocess.PIPE) for i in range(4)]
        for child in children:
            child.communicate(timeout=15)
        self.assertEqual(sorted(c.returncode for c in children), [0, 2, 2, 2])
        self.assertEqual(self.ledger.status()['events'], 2)

    def test_non_head_start_and_wrong_lane_are_refused_without_append(self):
        first, second = self.request(), self.request('M3')
        for ident, lane in ((second, 'M3'), (first, 'M3')):
            with self.assertRaisesRegex(ValueError, 'only the queued head'):
                self.ledger.start(ident, lane, 'run', 'epoch')
        self.assertEqual(self.ledger.status()['events'], 2)
        self.ledger.start(first, 'M2', 'run', 'epoch')
        with self.assertRaises(ValueError):
            self.ledger.start(second, 'M3', 'other', 'epoch')

    def test_requesting_lane_withdraws_queued_head_or_non_head(self):
        first, second, third = self.request(), self.request('M3'), self.request('M4')
        self.ledger.withdraw(second, 'M3', reason='unit no longer ready')
        self.assertEqual(self.ledger.status()['head']['id'], first)
        self.ledger.withdraw(first, 'M2', reason='session abandoned')
        state = self.ledger.status()
        self.assertEqual(state['head']['id'], third)
        self.assertEqual([b['state'] for b in state['history']], ['withdrawn', 'withdrawn'])
        self.assertEqual(state['history'][0]['withdrawnBy'], 'M2')
        self.assertNotIn('cleaned', state['history'][0])
        self.ledger.start(third, 'M4', 'run', 'epoch')

    def test_coordinator_withdraws_abandoned_head_with_reason(self):
        first, second = self.request(), self.request('M3')
        event = self.ledger.withdraw(first, coordinator=True, reason='requesting lane unavailable')
        self.assertEqual(event['event'], 'withdraw')
        state = self.ledger.status()
        self.assertEqual(state['head']['id'], second)
        self.assertEqual(state['history'][0]['withdrawnBy'], 'coordinator')
        self.assertEqual(state['history'][0]['reason'], event['reason'])

    def test_withdraw_refuses_wrong_actor_missing_reason_and_started_or_terminal_booking(self):
        ident = self.request()
        for fields in (dict(lane='M3'), dict(), dict(lane='M2', coordinator=True),
                       dict(coordinator=1), dict(coordinator=True, reason='')):
            with self.assertRaises(ValueError):
                self.ledger.withdraw(ident, **(dict(reason='cancel') | fields))
        self.assertEqual(self.ledger.status()['events'], 1)
        self.ledger.start(ident, 'M2', 'run', 'epoch')
        for fields in (dict(lane='M2'), dict(coordinator=True)):
            with self.assertRaises(ValueError):
                self.ledger.withdraw(ident, reason='cancel', **fields)
        self.ledger.finish(ident, 'M2', 'run', 'epoch', cleaned=True)
        with self.assertRaises(ValueError):
            self.ledger.withdraw(ident, coordinator=True, reason='already finished')
        with self.assertRaises(ValueError):
            self.ledger.withdraw('unknown', coordinator=True, reason='unknown')
        self.assertEqual(self.ledger.status()['events'], 3)

    def test_replay_validates_withdraw_actor_reason_and_state(self):
        ident = self.request()
        request = json.loads(self.path.read_text())
        event = dict(version=1, seq=2, at=self.now, event='withdraw', id=ident,
                     lane='M2', coordinator=False, reason='cancel')
        self.assertEqual(book.Ledger.replay([request, event])[ident]['state'], 'withdrawn')
        coordinator = event | dict(lane=None, coordinator=True)
        self.assertEqual(book.Ledger.replay([request, coordinator])[ident]['withdrawnBy'], 'coordinator')
        for fields in (dict(lane='M3'), dict(lane=None), dict(coordinator=True),
                       dict(coordinator=1), dict(reason=''), dict(reason=None), dict(reason='bad\nline')):
            with self.assertRaises(ValueError):
                book.Ledger.replay([request, event | fields])
        with self.assertRaises(ValueError):
            book.Ledger.replay([request, event, event | dict(seq=3)])
        started = dict(version=1, seq=2, at=self.now, event='start', id=ident, runID='run', epoch='epoch')
        with self.assertRaises(ValueError):
            book.Ledger.replay([request, started, coordinator | dict(seq=3)])

    def test_withdraw_cli_and_replay_after_restart(self):
        first, second = self.request(), self.request('M3')
        result = subprocess.run(self.cli('withdraw', '--id', first, '--coordinator',
                                         '--reason', 'lane unavailable'), capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)['event'], 'withdraw')
        result = subprocess.run(self.cli('withdraw', '--id', second, '--lane', 'M3',
                                         '--reason', 'unit withdrawn'), capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIsNone(book.Ledger(self.path).status()['head'])

    def test_ledger_requires_configuration_and_explicit_path_overrides_environment(self):
        env_path = self.root / 'env-ledger.jsonl'
        with patch.dict(os.environ, {}, clear=True):
            with self.assertRaisesRegex(ValueError, 'MODELPLAN_BOOKING_LEDGER'):
                book.Ledger()
            with self.assertRaisesRegex(ValueError, 'shared ledger required'):
                book.Ledger(' ')
            with patch.dict(os.environ, dict(MODELPLAN_BOOKING_LEDGER=' ')):
                with self.assertRaisesRegex(ValueError, 'shared ledger required'):
                    book.Ledger()
            result = subprocess.run([sys.executable, str(BIN / 'book.py'), 'status'],
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 2)
            self.assertIn('shared ledger required', json.loads(result.stderr)['error'])
            with patch.dict(os.environ, dict(MODELPLAN_BOOKING_LEDGER=str(env_path))):
                book.Ledger().status()
                book.Ledger(self.path).status()
                result = subprocess.run([sys.executable, str(BIN / 'book.py'), 'status'],
                                        capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                explicit = self.root / 'explicit.jsonl'
                result = subprocess.run([sys.executable, str(BIN / 'book.py'), '--ledger',
                                         str(explicit), 'status'], capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertTrue(explicit.exists())
        self.assertTrue(env_path.exists()); self.assertTrue(self.path.exists())

    def test_finish_requires_owner_and_explicit_cleanup(self):
        first, second = self.request(), self.request('M3')
        self.ledger.start(first, 'M2', 'run', 'epoch')
        for args in ((first, 'M2', 'wrong', 'epoch'), (second, 'M3', 'run', 'epoch')):
            with self.assertRaises(ValueError):
                self.ledger.finish(*args, cleaned=True)
        with self.assertRaisesRegex(ValueError, 'cleanup confirmation'):
            self.ledger.finish(first, 'M2', 'run', 'epoch')
        receipt = self.ledger.finish(first, 'M2', 'run', 'epoch', cleaned=True)
        self.assertEqual(receipt['receipt'], 'end + cleaned')
        self.assertTrue(self.ledger.status()['history'][0]['cleaned'])
        self.assertEqual(self.ledger.status()['head']['id'], second)

    def test_expiry_waits_for_duration_plus_grace_and_never_claims_cleanup(self):
        first, second = self.request(), self.request('M3')
        self.ledger.start(first, 'M2', 'run', 'epoch')
        self.now += book.MAX_SECONDS + book.GRACE_SECONDS - 1
        self.assertEqual(self.ledger.expire()['event'], 'no-expiry')
        with self.assertRaises(ValueError):
            self.ledger.start(second, 'M3', 'other', 'epoch')
        self.now += 1
        self.assertTrue(self.ledger.status()['expiryEligible'])
        self.assertEqual(self.ledger.status()['head']['id'], first)  # explicit expiry only
        self.assertEqual(self.ledger.expire()['event'], 'expire')
        self.assertIsNone(self.ledger.status()['history'][0]['cleaned'])
        self.ledger.start(second, 'M3', 'other', 'epoch')
        with self.assertRaises(ValueError):
            self.ledger.finish(first, 'M2', 'run', 'epoch', cleaned=True)
        self.assertEqual(self.ledger.expire()['event'], 'no-expiry')
        self.assertEqual(self.ledger.status()['head']['id'], second)

    def test_invalid_inputs_never_create_ledger(self):
        for seconds in (0, -1, 1201, True, float('nan')):
            with self.assertRaises(ValueError):
                self.ledger.request('M2', 'U11a', ['cold'], seconds)
        for scenarios in ([], ['cold', 'cold'], [''], ['bad\nline'], 'cold', [None]):
            with self.assertRaises(ValueError):
                self.ledger.request('M2', 'U11a', scenarios)
        self.assertFalse(self.path.exists())

    def test_mkdir_serializes_when_smb_flock_is_unsupported(self):
        with patch.object(book.fcntl, 'flock', side_effect=OSError(errno.EOPNOTSUPP, 'synthetic SMB')):
            ident = self.request()
            self.assertEqual(self.ledger.status()['head']['id'], ident)
        self.assertFalse(self.path.with_name('ledger.jsonl.lock').exists())

    def test_existing_transaction_lock_fails_closed_and_is_not_stolen(self):
        lock = self.path.with_name('ledger.jsonl.lock')
        lock.mkdir(); (lock / 'owner.json').write_text('{}')
        with self.assertRaisesRegex(ValueError, 'locked'):
            book.Ledger(self.path, lock_timeout=0).status()
        self.assertTrue(lock.exists())
        self.assertFalse(self.path.exists())

    def test_lock_owner_has_only_opaque_labels_and_no_hostname(self):
        lock = self.path.with_name('ledger.jsonl.lock')
        records = []

        def clock():
            records.append(json.loads((lock / 'owner.json').read_text()))
            return self.now

        self.ledger.clock = clock
        with patch.object(socket, 'gethostname', return_value='synthetic-host-identity') as hostname:
            ident = self.request()
            self.ledger.status()
            self.ledger.start(ident, 'M2', 'run', 'epoch')
            self.ledger.admit(dict(id=ident, lane='M2', unit='U11a', scenario='cold'),
                              dict(runID='run', epoch='epoch', notBefore=self.now,
                                   expiresAt=self.now + 60), 60)
            self.ledger.finish(ident, 'M2', 'run', 'epoch', cleaned=True)
            self.ledger.expire()
            book.Ledger(self.path, clock=clock).status()
            hostname.assert_not_called()

        token = records[0]['processToken']
        self.assertRegex(token, r'^[0-9a-f]{32}$')
        labels = [dict(lane='M2', unit='U11a'), {}, dict(lane='M2'),
                  dict(lane='M2', unit='U11a'), dict(lane='M2'), {}, {}]
        self.assertEqual(records, [dict(processToken=token, **fields) for fields in labels])
        self.assertNotIn('synthetic-host-identity', json.dumps(records))
        self.assertFalse(lock.exists())

    def test_partial_or_corrupt_ledger_is_not_repaired_or_appended(self):
        for raw in ('{"unfinished":', '{}\n', 'null\n'):
            self.path.write_text(raw)
            with self.assertRaisesRegex(ValueError, 'ledger'):
                self.request()
            self.assertEqual(self.path.read_text(), raw)
            self.assertFalse(self.path.with_name('ledger.jsonl.lock').exists())

    def active_contract(self):
        self.now = time.time() - 1
        ident = self.request()
        self.ledger.start(ident, 'M2', 'run', 'epoch')
        lease = dict(runID='run', epoch='epoch', notBefore=self.now, expiresAt=self.now + 1200,
                     guardianHeartbeatAt=time.time(), ownerPreempted=False, exclusive=True, guardian=True)
        release = lease | dict(m1Released=True, approval='https://example.test/coordinator#issuecomment-1')
        lease_path = self.root / 'issued-lease.json'; lease_path.write_text(json.dumps(lease))
        release_path = self.root / 'release.json'; release_path.write_text(json.dumps(release))
        return dict(profile='synthetic', lease=lease, release=release,
                    runID='run', epoch='epoch', start=self.now, expiresAt=lease['expiresAt'],
                    leasePath=str(lease_path), releasePath=str(release_path),
                    requiredSeconds=690, stop=False, argv=['unused'], binarySHA256='a' * 64,
                    booking=dict(id=ident, lane='M2', unit='U11a', scenario='cold', ledger=str(self.path)))

    def test_grouped_scenarios_share_one_deadline_and_bound_run_identity(self):
        c = self.active_contract()
        for scenario in ('cold', 'repeat'):
            c['booking']['scenario'] = scenario
            self.assertEqual(book.admit(c)['runID'], 'run')
        for fields in (dict(scenario='foreign'), dict(unit='U5'), dict(lane='M3')):
            with self.assertRaises(ValueError):
                book.admit(c | dict(booking=c['booking'] | fields))
        for fields in (dict(epoch='old'), dict(runID='other'), dict(expiresAt=self.now + 1201),
                       dict(notBefore=self.now - 1)):
            with self.assertRaises(ValueError):
                book.admit(c | dict(lease=c['lease'] | fields))
        with self.assertRaises(ValueError):
            book.admit(c | dict(requiredSeconds=1200))
        self.now += book.MAX_SECONDS
        with self.assertRaises(ValueError):
            self.ledger.admit(c['booking'], c['lease'], 1)

    def test_live_admission_requires_explicit_ledger_or_environment(self):
        c = self.active_contract()
        del c['booking']['ledger']
        with patch.dict(os.environ, {}, clear=True):
            with self.assertRaisesRegex(ValueError, 'shared ledger required'):
                book.admit(c)
            with patch.dict(os.environ, dict(MODELPLAN_BOOKING_LEDGER=str(self.path))):
                self.assertEqual(book.admit(c)['id'], c['booking']['id'])

    def test_drive_refuses_invalid_external_release_before_any_child_or_resource(self):
        c = self.active_contract()
        release = self.root / 'release.json'
        binary = self.root / 'synthetic-binary'; binary.write_bytes(b'synthetic')
        inputs = self.root / 'inputs'; inputs.mkdir(); (inputs / 'index.html').write_text('synthetic')
        locks = self.root / 'locks'; locks.mkdir()
        cfg = c | dict(runID='run', epoch='epoch', GO=True, announcementID='synthetic',
                       start=c['lease']['notBefore'], expiresAt=c['lease']['expiresAt'],
                       batch=str(self.root / 'batch'), scratch=str(self.root / 'scratch'),
                       releasePath=str(release), binary=str(binary),
                       binarySHA256=hashlib.sha256(b'synthetic').hexdigest(), head='synthetic',
                       inputRoot=str(inputs), entry='index.html', locks=str(locks),
                       buildRoots=[], resourceRoot=str(self.root), scripts=[])
        records = [None, False, c['release'] | dict(m1Released=False, guardianGO=True),
                   c['release'] | dict(approval='http://example.test/coordinator')]
        records += [c['release'] | {k: v} for k, v in
                    (('runID', 'other'), ('epoch', 'old'), ('notBefore', 1), ('expiresAt', 2))]
        for record in records:
            with self.subTest(record=record):
                release.unlink(missing_ok=True)
                if record is not None:
                    release.write_text(json.dumps(record))
                attempt = drive.Attempt(cfg)
                with patch.object(drive.subprocess, 'Popen', side_effect=AssertionError('child launched without release')) as popen, \
                        patch.object(shutil, 'disk_usage', return_value=Mock(free=100 * 1024**3)):
                    with self.assertRaises((OSError, ValueError)):
                        attempt.run()
                    popen.assert_not_called()
                self.assertFalse(attempt.out.exists()); self.assertFalse(attempt.scratch.exists())
                self.assertEqual(list(locks.iterdir()), [])

    def test_drive_rereads_release_before_each_subject_launch(self):
        c = self.active_contract()
        release = self.root / 'release.json'; release.write_text(json.dumps(c['release']))
        c.update(runID='run', epoch='epoch', batch=str(self.root / 'batch'), scratch=str(self.root / 'scratch'),
                 binary='unused', scripts=[], resourceRoot=str(self.root), releasePath=str(release))
        attempt = drive.Attempt(c)
        attempt.out.mkdir(); attempt.scratch.mkdir()
        attempt.lease.write_text(json.dumps(c['lease'])); attempt.entry = 'http://127.0.0.1/synthetic'
        with patch.object(drive.subprocess, 'Popen', return_value=Mock(pid=123)) as popen, \
                patch.object(drive.cleanup, 'identity', return_value=dict(pid=123)):
            attempt.launch('preflight')
            popen.assert_called_once()
            release.write_text(json.dumps(c['release'] | dict(epoch='revoked')))
            with self.assertRaisesRegex(ValueError, 'lease/release identity mismatch'):
                attempt.launch('measure')
            popen.assert_called_once()

    def test_launch_execute_refuses_without_booking_before_home_or_process(self):
        c = self.active_contract()
        del c['booking']
        c.update(leasePath=str(self.root / 'lease.json'), releasePath=str(self.root / 'release.json'),
                 stopPath=str(self.root / 'stop'), syntheticHome=str(self.root / 'home'),
                 syntheticTmp=str(self.root / 'tmp'))
        Path(c['leasePath']).write_text(json.dumps(c['lease']))
        Path(c['releasePath']).write_text(json.dumps(c['release']))
        config = self.root / 'run.json'; config.write_text(json.dumps(c))
        with patch.object(sys, 'argv', ['launch', '--config', str(config), '--execute']), patch.object(launch.subprocess, 'Popen') as popen:
            with self.assertRaisesRegex(ValueError, 'head booking'):
                launch.main()
            popen.assert_not_called()
        self.assertFalse((self.root / 'home').exists())

    def test_drive_external_mode_defers_to_guardian_and_fails_closed_on_its_loss(self):
        # M1 flow: Drive must not heartbeat the external lease; a lost guardian or its stop file stops Drive.
        c = self.active_contract()
        lease_path = Path(c['leasePath']); stop_path = self.root / 'external-STOP'
        cfg = dict(c, batch=str(self.root / 'batch'), scratch=str(self.root / 'scratch'), stopPath=str(stop_path))
        attempt = drive.Attempt(cfg)
        self.assertTrue(attempt.external); self.assertEqual(attempt.stop, stop_path)
        lease_path.write_text(json.dumps(c['lease'] | dict(guardianHeartbeatAt=time.time())))
        attempt.live()  # fresh heartbeat from the independent guardian
        lease_path.write_text(json.dumps(c['lease'] | dict(guardianHeartbeatAt=time.time() - 5)))
        with self.assertRaisesRegex(RuntimeError, 'guardian-not-live'):
            attempt.live()  # guardian killed: Drive stops instead of keeping the heartbeat alive
        lease_path.write_text(json.dumps(c['lease'] | dict(guardianHeartbeatAt=time.time())))
        stop_path.write_text('{}')
        with self.assertRaisesRegex(RuntimeError, 'stop-or-expiry'):
            attempt.live()

    def test_launch_rechecks_booking_after_hash_work_before_spawn(self):
        c = self.active_contract()
        binary = self.root / 'synthetic-binary'; binary.write_bytes(b'synthetic')
        c.update(argv=[str(binary)], binarySHA256=hashlib.sha256(b'synthetic').hexdigest(),
                 leasePath=str(self.root / 'lease.json'), releasePath=str(self.root / 'release.json'),
                 stopPath=str(self.root / 'stop'), syntheticHome=str(self.root / 'home'), syntheticTmp=str(self.root / 'tmp'))
        Path(c['leasePath']).write_text(json.dumps(c['lease']))
        Path(c['releasePath']).write_text(json.dumps(c['release']))
        config = self.root / 'run.json'; config.write_text(json.dumps(c))
        with patch.object(sys, 'argv', ['launch', '--config', str(config), '--execute']), patch.object(launch.subprocess, 'Popen', return_value=Mock(pid=123)) as popen:
            with patch.object(launch, 'load_and_admit', side_effect=[c, ValueError('booking finished')]):
                with self.assertRaisesRegex(ValueError, 'booking finished'):
                    launch.main()
                popen.assert_not_called()
        # The allowed path invokes a mock only, never an executable.
        c['syntheticHome'] += '-allowed'; c['syntheticTmp'] += '-allowed'
        config.write_text(json.dumps(c))
        child = Mock(pid=123, returncode=0); child.poll.return_value = 0  # the child exits by itself
        c['subjectPidPath'] = str(self.root / 'subject.pid'); config.write_text(json.dumps(c))
        with patch.object(sys, 'argv', ['launch', '--config', str(config), '--execute']), patch.object(launch.subprocess, 'Popen', return_value=child) as popen, patch.object(launch, 'register', return_value={}):
            with self.assertRaises(SystemExit) as done:
                launch.main()
            popen.assert_called_once()
        self.assertEqual(done.exception.code, 0)

    def test_drive_refuses_missing_booking_before_any_resource_or_process(self):
        c = self.active_contract()
        del c['booking']
        attempt = drive.Attempt(c | dict(GO=True, announcementID='synthetic', binary='unused',
                                        batch=str(self.root / 'batch'), scratch=str(self.root / 'scratch')))
        with patch.object(drive.subprocess, 'Popen') as popen:
            with self.assertRaisesRegex(ValueError, 'head booking'):
                attempt.run()
            popen.assert_not_called()
        self.assertFalse(attempt.out.exists()); self.assertFalse(attempt.scratch.exists())

    def test_drive_rechecks_ended_booking_before_subject_launch(self):
        c = self.active_contract()
        c.update(runID='run', epoch='epoch', batch=str(self.root / 'batch'), scratch=str(self.root / 'scratch'),
                 binary='unused', scripts=[], resourceRoot=str(self.root), releasePath=str(self.root / 'release.json'))
        Path(c['releasePath']).write_text(json.dumps(c['release']))
        attempt = drive.Attempt(c)
        attempt.out.mkdir(); attempt.scratch.mkdir()
        (attempt.scratch / 'home').mkdir(); (attempt.scratch / 'tmp').mkdir()
        attempt.lease.write_text(json.dumps(c['lease']))
        attempt.entry = 'http://127.0.0.1/synthetic'
        self.ledger.finish(c['booking']['id'], 'M2', 'run', 'epoch', cleaned=True)
        with patch.object(drive.subprocess, 'Popen') as popen:
            with self.assertRaisesRegex(ValueError, 'head booking'):
                attempt.launch('preflight')
            popen.assert_not_called()

    def test_drive_busy_resource_is_single_attempt_and_preserves_foreign_slot(self):
        c = self.active_contract()
        binary = self.root / 'synthetic-binary'; binary.write_bytes(b'synthetic')
        inputs = self.root / 'inputs'; inputs.mkdir(); (inputs / 'index.html').write_text('synthetic')
        locks = self.root / 'locks'; locks.mkdir(); (locks / 'slot2').mkdir()
        (locks / 'slot2' / 'owner.json').write_text('{"runID":"foreign"}')
        cfg = dict(runID='run', epoch='epoch', GO=True, announcementID='synthetic', start=c['lease']['notBefore'],
                   expiresAt=c['lease']['expiresAt'], booking=c['booking'], head='synthetic',
                   binary=str(binary), binarySHA256=hashlib.sha256(b'synthetic').hexdigest(),
                   inputRoot=str(inputs), entry='index.html', batch=str(self.root / 'batch'),
                   scratch=str(self.root / 'scratch'), locks=str(locks), releasePath=str(self.root / 'release.json'),
                   leasePath=c['leasePath'])
        Path(cfg['releasePath']).write_text(json.dumps(c['release']))
        config = self.root / 'drive.json'; config.write_text(json.dumps(cfg))
        with patch.object(sys, 'argv', ['drive', '--config', str(config)]), patch.object(drive.time, 'sleep') as sleep, patch.object(drive.subprocess, 'Popen') as popen:
            with self.assertRaisesRegex(RuntimeError, 'resource-busy'):
                drive.main()
            sleep.assert_not_called(); popen.assert_not_called()
        self.assertTrue((locks / 'slot2' / 'owner.json').exists())
        self.assertFalse((locks / 'M1-candidate-gui').exists())
        self.assertFalse((locks / 'slot1').exists())
        self.assertFalse(json.loads((self.root / 'batch' / 'result.json').read_text())['AppLaunched'])


if __name__ == '__main__':
    unittest.main()
