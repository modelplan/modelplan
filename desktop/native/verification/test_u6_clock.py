# SPDX-License-Identifier: MIT
import importlib.util,types,unittest
from pathlib import Path

spec=importlib.util.spec_from_file_location('u6_clock',Path(__file__).parent/'U6/u6_clock.py')
clock=importlib.util.module_from_spec(spec);spec.loader.exec_module(clock)

class U6ClockTests(unittest.TestCase):
    def test_mac_uses_raw_uptime(self):
        calls=[]
        source=types.SimpleNamespace(CLOCK_UPTIME_RAW=8,clock_gettime=lambda value:(calls.append(value) or 12.5),
                                     monotonic=lambda:self.fail('raw uptime available'))
        self.assertEqual(clock.system_uptime(source),12.5)
        self.assertEqual(calls,[8])
    def test_offline_host_without_raw_uptime_uses_monotonic(self):
        source=types.SimpleNamespace(monotonic=lambda:42.25)
        self.assertEqual(clock.system_uptime(source),42.25)

if __name__=='__main__':unittest.main()
