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
