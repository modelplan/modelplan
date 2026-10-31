# SPDX-License-Identifier: MIT
"""Verification tools must never author native arrival evidence (they only read it)."""
from pathlib import Path
import re
import unittest

BIN = Path(__file__).resolve().parents[1] / 'bin'
WRITE = re.compile(r'forWritingTo|forWritingAtPath|forUpdating|createFile|\.write\(|FileManager\.default\.createFile|open\([^)]*[\'"](?:a|w|x|r\+)')


class ArrivalWriters(unittest.TestCase):
    def test_only_status_menu_drive_touches_arrivals_and_only_reads(self):
        users = [p for p in sorted(BIN.iterdir()) if p.is_file() and p.suffix in ('.swift', '.py') and 'arrivals' in p.read_text()]
        self.assertEqual([p.name for p in users], ['status_menu_drive.swift'])
        lines = users[0].read_text().splitlines()
        for i, line in enumerate(lines):
            if 'arrivals' in line or 'path' in line and i and 's.arrivals' in lines[i - 1]:
                self.assertIsNone(WRITE.search(line), f'{users[0].name}:{i + 1} writes arrival evidence: {line.strip()}')
        text = users[0].read_text()
        self.assertIn('FileHandle(forReadingFrom: path)', text)
        self.assertNotRegex(text, r'FileHandle\((?:forWritingTo|forUpdating)[^)]*path\)')

    def test_driver_never_emits_receipt_rows(self):
        text = (BIN / 'status_menu_drive.swift').read_text()
        # The driver's own JSONL rows use status-menu-* events; receipt events come only from the in-app observer.
        self.assertNotIn('NSMenu.didSendAction"', re.sub(r'"arrivalProof": "native-NSMenu\.didSendAction"', '', text))


if __name__ == '__main__':
    unittest.main()
