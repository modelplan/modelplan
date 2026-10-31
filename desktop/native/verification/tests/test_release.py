# SPDX-License-Identifier: MIT
"""M1 release issuance and real file-backed admission, synthetic fixtures only."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest

BIN = Path(__file__).parents[1] / 'bin'
sys.path.insert(0, str(BIN))
import admission
import book
import release

APPROVAL = 'https://example.test/coordinator#issuecomment-1'


class Releases(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.now = time.time()
        self.ledger = book.Ledger(self.root / 'ledger.jsonl', clock=lambda: self.now)
        self.ident = self.ledger.request('M2', 'U11a', ['cold'])['id']
        self.lease = self.ledger.start(self.ident, 'M2', 'run', 'epoch')
        self.output = self.root / 'release.json'

    def issue(self, **fields):
        return release.issue(self.ledger, self.ident, self.lease, self.output,
                             **(dict(lane='M1', approval=APPROVAL) | fields))

    def test_release_contains_only_one_issued_lease_identity_and_m1_approval(self):
        record = self.issue()
        self.assertEqual(record, {k: self.lease[k] for k in release.IDENTITY_FIELDS}
                         | dict(m1Released=True, approval=APPROVAL))
        self.assertEqual(json.loads(self.output.read_text()), record)
        with self.assertRaises(FileExistsError):
            self.issue()
        self.assertEqual(json.loads(self.output.read_text()), record)

    def test_release_refuses_wrong_lane_missing_or_non_https_approval(self):
        for fields in (dict(lane='M2'), dict(approval=None), dict(approval=''),
                       dict(approval='http://example.test/comment'), dict(approval='https://'),
                       dict(approval='https://user:secret@example.test/comment')):
            with self.subTest(fields=fields), self.assertRaises(ValueError):
                self.issue(**fields)
            self.assertFalse(self.output.exists())

    def test_release_refuses_mismatched_expired_and_finished_lease(self):
        for fields in (dict(runID='other'), dict(epoch='other'),
                       dict(notBefore=self.now + 1), dict(expiresAt=self.now + 1199)):
            with self.subTest(fields=fields), self.assertRaises(ValueError):
                release.issue(self.ledger, self.ident, self.lease | fields, self.output,
                              lane='M1', approval=APPROVAL)
            self.assertFalse(self.output.exists())
        self.now = self.lease['expiresAt']
        with self.assertRaises(ValueError):self.issue()
        self.now = self.lease['notBefore']
        self.ledger.finish(self.ident, 'M2', 'run', 'epoch', cleaned=True)
        with self.assertRaises(ValueError):self.issue()
        self.assertFalse(self.output.exists())

    def test_cli_requires_explicit_approval_and_writes_real_receipt(self):
        path = self.root / 'cli-ledger.jsonl'
        book_command = [sys.executable, str(BIN / 'book.py'), '--ledger', str(path)]
        request = subprocess.run(book_command + ['request', '--lane', 'M1', '--unit', 'U11a', '--scenario', 'cold'],
                                 capture_output=True, text=True, check=True)
        ident = json.loads(request.stdout)['id']
        start = subprocess.run(book_command + ['start', '--id', ident, '--lane', 'M1', '--run-id', 'cli-run', '--epoch', 'cli-epoch'],
                               capture_output=True, text=True, check=True)
        lease_path = self.root / 'lease.json'; lease_path.write_text(start.stdout)
        command = [sys.executable, str(BIN / 'release.py'), '--ledger', str(path),
                   '--id', ident, '--lane', 'M1', '--lease', str(lease_path), '--output', str(self.output)]
        for flags in ([], ['--approval', 'http://example.test/comment']):
            result = subprocess.run(command + flags, capture_output=True, text=True)
            self.assertEqual(result.returncode, 2, result.stderr)
            self.assertFalse(self.output.exists())
        result = subprocess.run(command + ['--approval', APPROVAL], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(self.output.read_text())['approval'], APPROVAL)
        self.assertEqual(json.loads(self.output.read_text())['runID'], 'cli-run')

    def test_shared_loader_ignores_inline_approval_and_enforces_live_files(self):
        self.issue()
        self.lease = self.lease | dict(guardian=True)  # bin/guardian.py has taken over
        lease_path = self.root / 'lease.json'; lease_path.write_text(json.dumps(self.lease))
        c = dict(profile='synthetic', binarySHA256='a' * 64, argv=['synthetic-app'], requiredSeconds=60,
                 leasePath=str(lease_path), releasePath=str(self.output), stopPath=str(self.root / 'stop'),
                 booking=dict(id=self.ident, lane='M2', unit='U11a', scenario='cold', ledger=str(self.ledger.path)))
        self.assertEqual(admission.load_and_admit(c)['lease']['runID'], 'run')
        original = json.loads(self.output.read_text())
        for record in (dict(guardianGO=True, m0DirectedAnnouncementConfirmed=True),
                       original | dict(m1Released=False), original | dict(approval=None),
                       original | dict(approval='http://example.test/comment'), original | dict(epoch='other')):
            self.output.write_text(json.dumps(record))
            with self.assertRaises(ValueError):
                admission.load_and_admit(c | dict(release=original))
        self.output.write_text(json.dumps(original))
        for fields in (dict(guardianHeartbeatAt=self.now - 3), dict(ownerPreempted=True), dict(exclusive=False)):
            lease_path.write_text(json.dumps(self.lease | fields))
            with self.assertRaises(ValueError):admission.load_and_admit(c)
        lease_path.write_text(json.dumps({k: v for k, v in self.lease.items() if k != 'guardian'}))
        with self.assertRaisesRegex(ValueError, 'guardian not running'):admission.load_and_admit(c)
        lease_path.write_text(json.dumps(self.lease))
        self.ledger.finish(self.ident, 'M2', 'run', 'epoch', cleaned=True)
        with self.assertRaisesRegex(ValueError, 'head booking'):admission.load_and_admit(c)
