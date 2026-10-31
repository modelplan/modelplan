# SPDX-License-Identifier: MIT
"""U6 must consult live admission before acquiring resources, and Drive never starts a process."""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from unittest.mock import patch

BIN = Path(__file__).resolve().parents[1] / 'bin'
sys.path.insert(0, str(BIN))
spec = importlib.util.spec_from_file_location('drive_u6', BIN / 'drive-u6.py')
drive = importlib.util.module_from_spec(spec)
spec.loader.exec_module(drive)


def run_config(root):
    batch = root / 'batch'; batch.mkdir()
    scratch = root / 'scratch'; scratch.mkdir()
    binary = root / 'subject'; binary.write_bytes(b'synthetic')
    now = time.time()
    return dict(profile='synthetic', scenario='u6', head='a'*40, binarySHA256=hashlib.sha256(b'synthetic').hexdigest(),
                argv=[str(binary), drive.FLAG, str(scratch / 'native-guard.json')],
                expectedLease=dict(runID='run', epoch='epoch', notBefore=now - 10, expiresAt=now + 290),
                syntheticHome=str(scratch / 'home'), syntheticTmp=str(scratch / 'tmp'), scratch=str(scratch),
                batch=str(batch), locks=str(root / 'locks'), resourceRoot=str(root), stopPath=str(batch / 'stop.json'),
                preparedReceiptPath=str(batch / 'prepared.json'),
                leasePath=str(root / 'lease'), releasePath=str(root / 'release'),
                subjectPidPath=str(root / 'subject.pid'), requiredSeconds=30)


class U6AdmissionTests(unittest.TestCase):
    def test_refused_admission_precedes_resource_and_process_creation(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); c = run_config(root)
            config = root / 'config.json'; config.write_text(json.dumps(c))
            with patch.object(drive, 'load_and_admit', side_effect=ValueError('booking denied')) as gate, \
                 patch.object(subprocess, 'Popen') as spawn:
                with self.assertRaisesRegex(ValueError, 'booking denied'):
                    drive.main(['prepare', '--config', str(config)])
            spawn.assert_not_called()
            self.assertFalse((root / 'locks').exists())
            self.assertFalse((root / 'scratch' / 'native-guard.json').exists())
            self.assertFalse((root / 'batch' / 'prepared.json').exists())
            self.assertTrue((root / 'batch' / 'stop.json').exists())
            self.assertEqual(gate.call_args.args[0]['expectedLease']['runID'], 'run')
            self.assertNotIn('release', gate.call_args.args[0])

    def test_revoked_booking_prevents_driving_the_registered_subject(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); c = run_config(root)
            config = root / 'config.json'; config.write_text(json.dumps(c))
            child = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(30)'])
            try:
                drive.write(c['subjectPidPath'], dict(state='running', launcher=drive.identity(os.getpid()), **drive.identity(child.pid)))
                def launch_py():  # stands in for launch.py: it stops its registered child on the stop file
                    while not Path(c['stopPath']).exists(): time.sleep(.05)
                    child.terminate(); child.wait()
                threading.Thread(target=launch_py, daemon=True).start()
                with patch.object(drive, 'still_admitted', side_effect=ValueError('booking ended')) as gate, \
                     patch.object(drive, 'load_and_admit', side_effect=AssertionError('full admission after launch')), \
                     patch.object(subprocess, 'Popen') as spawn:
                    status = drive.main(['drive', '--config', str(config)])
            finally:
                if child.poll() is None: child.kill()
                child.wait()
            self.assertEqual(gate.call_count, 1)
            spawn.assert_not_called()
            result = json.loads((root / 'batch' / 'result.json').read_text())
            self.assertEqual((result['appStarted'], result['reason']), (False, 'ValueError'))
            self.assertFalse((root / 'batch' / 'launch.json').exists())
            self.assertTrue(result['cleanup']['ownedAppExited'])
            self.assertFalse(result['cleanup']['leaseReleased'])
            self.assertEqual(status, 0)

if __name__ == '__main__':
    unittest.main()
