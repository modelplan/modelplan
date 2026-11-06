# SPDX-License-Identifier: MIT
"""Offline controls for the packaged normal-entry process harness."""
import importlib.util
from pathlib import Path
import sys
import os
import subprocess
import tempfile
import time
import unittest

spec = importlib.util.spec_from_file_location('normal_smoke', Path(__file__).with_name('check-normal-entry.py'))
smoke = importlib.util.module_from_spec(spec)
spec.loader.exec_module(smoke)


class NormalSmokeTests(unittest.TestCase):
    def process(self, body):
        return smoke.run_process([sys.executable, '-u', '-c', body], {}, timeout=2)

    def test_ready_rows_and_clean_quit(self):
        self.process("import sys; print('MODELPLAN_SMOKE_READY'); print('MODELPLAN_SMOKE_ROWS'); assert sys.stdin.read(1) == 'q'")

    def test_early_exit_missing_rows_or_wrong_order_fails(self):
        for body in ["print('MODELPLAN_SMOKE_READY')", "print('MODELPLAN_SMOKE_ROWS'); print('MODELPLAN_SMOKE_READY')", "raise SystemExit(3)"]:
            with self.subTest(body=body), self.assertRaises(RuntimeError):
                self.process(body)

    def test_timeout_and_unclean_exit_fail(self):
        for body in ["import time; time.sleep(10)", "import sys; print('MODELPLAN_SMOKE_READY'); print('MODELPLAN_SMOKE_ROWS'); sys.stdin.read(1); raise SystemExit(4)"]:
            with self.subTest(body=body), self.assertRaises(RuntimeError):
                self.process(body)

    def test_environment_is_isolated_and_legacy_route_unset(self):
        env = smoke.synthetic_environment(Path('/synthetic/home'), Path('/synthetic/tmp'))
        self.assertNotIn('MODELPLAN_APP_SMOKE', env)
        self.assertEqual(env['HOME'], '/synthetic/home')
        self.assertEqual(env['CFFIXED_USER_HOME'], '/synthetic/home')
        self.assertEqual(env['MODELPLAN_NORMAL_ENTRY_SMOKE'], '1')
        self.assertNotIn('GH_TOKEN', env)

    def test_exited_parent_does_not_leave_owned_child(self):
        with tempfile.TemporaryDirectory() as directory:
            marker = Path(directory) / 'child.pid'
            parent = ("import os,subprocess,sys; "
                      "child=subprocess.Popen([sys.executable,'-c','import time; time.sleep(30)'], "
                      "stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL); "
                      "open(sys.argv[1],'w').write(str(child.pid)); os._exit(3)")
            with self.assertRaises(RuntimeError):
                smoke.run_process([sys.executable, '-u', '-c', parent, str(marker)], {}, timeout=5)
            pid = int(marker.read_text())
            for _ in range(50):
                state = subprocess.run(['/bin/ps', '-p', str(pid), '-o', 'stat='],
                                       capture_output=True, text=True).stdout.strip()
                if not state or state.startswith('Z'):
                    break
                time.sleep(0.02)
            else:
                self.fail('owned child survived failed parent cleanup')
