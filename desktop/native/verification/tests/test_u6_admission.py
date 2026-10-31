# SPDX-License-Identifier: MIT
"""U6 must consult live admission before acquiring resources or starting a process."""
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

BIN = Path(__file__).resolve().parents[1] / 'bin'
sys.path.insert(0, str(BIN))
spec = importlib.util.spec_from_file_location('drive_u6', BIN / 'drive-u6.py')
drive = importlib.util.module_from_spec(spec)
spec.loader.exec_module(drive)

class U6AdmissionTests(unittest.TestCase):
    def test_refused_admission_precedes_resource_and_process_creation(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            batch = root / 'batch'; batch.mkdir()
            scratch = root / 'scratch'; scratch.mkdir()
            binary = root / 'subject'; binary.write_bytes(b'synthetic')
            home = scratch / 'home'; tmp = scratch / 'tmp'
            c = dict(profile='synthetic', start=100, expiresAt=300, head='a'*40,
                     binarySHA256=hashlib.sha256(b'synthetic').hexdigest(), binary=str(binary),
                     home=str(home), tmp=str(tmp), scratch=str(scratch), batch=str(batch),
                     environment=dict(HOME=str(home), TMPDIR=str(tmp)), locks=str(root/'locks'),
                     stopPath=str(batch/'stop.json'), leasePath=str(root/'lease'),
                     releasePath=str(root/'release'), runID='run', epoch='epoch')
            config = root / 'config.json'; config.write_text(json.dumps(c))
            with patch.object(sys, 'argv', ['drive-u6', '--config', str(config)]), \
                 patch.object(drive.time, 'time', return_value=110), \
                 patch.object(drive, 'load_and_admit', side_effect=ValueError('booking denied')) as gate, \
                 patch.object(drive.subprocess, 'Popen') as spawn:
                with self.assertRaisesRegex(ValueError, 'booking denied'):
                    drive.main()
            spawn.assert_not_called()
            self.assertFalse((root/'locks').exists())
            self.assertEqual(gate.call_args.args[0]['expectedLease']['runID'], 'run')
            self.assertNotIn('release', gate.call_args.args[0])


    def test_revoked_booking_prevents_app_launch_after_setup(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            batch = root / 'batch'; batch.mkdir()
            scratch = root / 'scratch'; scratch.mkdir()
            locks = root / 'locks'; locks.mkdir()
            binary = root / 'subject'; binary.write_bytes(b'synthetic')
            home = scratch / 'home'; tmp = scratch / 'tmp'
            c = dict(profile='synthetic', start=100, expiresAt=300, head='a'*40,
                     binarySHA256=hashlib.sha256(b'synthetic').hexdigest(), binary=str(binary),
                     home=str(home), tmp=str(tmp), scratch=str(scratch), batch=str(batch),
                     environment=dict(HOME=str(home), TMPDIR=str(tmp)), locks=str(locks),
                     resourceRoot=str(root), stopPath=str(batch/'stop.json'), leasePath=str(root/'lease'),
                     releasePath=str(root/'release'), runID='run', epoch='epoch')
            config = root / 'config.json'; config.write_text(json.dumps(c))
            with patch.object(sys, 'argv', ['drive-u6', '--config', str(config)]), \
                 patch.object(drive.time, 'time', return_value=110), \
                 patch.object(drive.shutil, 'disk_usage', return_value=type('Disk', (), {'free': 30 * 1024**3})()), \
                 patch.object(drive.cleanup, 'remove_scratch', return_value=True), \
                 patch.object(drive, 'load_and_admit', side_effect=[{}, ValueError('booking ended')]) as gate, \
                 patch.object(drive.subprocess, 'Popen') as spawn:
                drive.main()
            self.assertEqual(gate.call_count, 2)
            spawn.assert_not_called()
            result = json.loads((batch/'result.json').read_text())
            self.assertFalse(result['appStarted'])
            self.assertFalse(result['cleanup']['leaseReleased'])
            self.assertEqual(list(locks.iterdir()), [])

if __name__ == '__main__':
    unittest.main()
