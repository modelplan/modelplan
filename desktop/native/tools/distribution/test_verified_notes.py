# SPDX-License-Identifier: MIT
from datetime import date
import json
from pathlib import Path
import tempfile
import unittest
from verified_notes import render


class VerifiedNotesTests(unittest.TestCase):
    def test_empty_list_and_strict_handoff(self):
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / 'ledger.json'
            path.write_text(json.dumps({'date': '2026-11-05', 'verified': []}))
            self.assertEqual(render(path, date(2026, 11, 5)), 'Verified fixes\n\n')
            with self.assertRaises(ValueError):
                render(path, date(2026, 11, 6))
            path.write_text(json.dumps({'date': '2026-11-05', 'verified': ['G3-1', 'arbitrary text']}))
            with self.assertRaises(ValueError):
                render(path, date(2026, 11, 5))

class LedgerSnapshotTests(unittest.TestCase):
    def test_only_verified_status_is_exported(self):
        from update_verified_handoff import snapshot
        text = '''| G3-01 | private | x | x | x | x | VERIFIED (evidence) |
| G3-02 | VERIFIED | x | x | x | x | TEST-PASS |
| G3-03 | private | x | x | x | x | OPEN |
'''
        self.assertEqual(snapshot(text, date(2026, 11, 5)), {'date': '2026-11-05', 'verified': ['G3-01']})
        with self.assertRaises(ValueError):
            snapshot(text + text, date(2026, 11, 5))
        with self.assertRaises(ValueError):
            snapshot('missing', date(2026, 11, 5))
