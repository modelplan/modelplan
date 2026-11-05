# SPDX-License-Identifier: MIT
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import unittest
from unittest import mock

MODULE = Path(__file__).resolve().parents[1] / 'bin' / 'candidate_isolation.py'
spec = importlib.util.spec_from_file_location('candidate_isolation', MODULE)
isolation = importlib.util.module_from_spec(spec)
spec.loader.exec_module(isolation)


class CandidateIsolationTests(unittest.TestCase):
    def test_profile_has_explicit_file_and_network_denials(self):
        profile = isolation.synthetic_profile('/private/tmp/synthetic sentinel')
        self.assertIn('(deny file-read* (literal "/private/tmp/synthetic sentinel"))', profile)
        self.assertIn('(deny network-outbound)', profile)

    def test_unproven_guards_refuse_even_after_successful_synthetic_probe(self):
        receipt = isolation.isolation_receipt({'status': 'completed', 'syntheticDeniedRead': 'denied',
                                               'scratchWrite': 'allowed', 'outboundNetwork': 'denied'})
        self.assertEqual(receipt['verdict'], 'refuse')
        self.assertEqual(receipt['proofResults']['keychainMonitoringD19'], 'not-verified')
        self.assertEqual(receipt['scratchPaths'], {})

    def test_monitor_rejects_unsafe_name(self):
        with self.assertRaises(ValueError):
            isolation.SecurityEventMonitor('security" OR true')

    def test_monitor_drops_message_and_ignores_other_clients(self):
        import io
        monitor = isolation.SecurityEventMonitor.__new__(isolation.SecurityEventMonitor)
        monitor._events = isolation.deque(maxlen=10)
        monitor._lock = isolation.threading.Lock()
        monitor._pid = 42
        events = [{'timestamp': 'synthetic', 'processID': 42, 'subsystem': 'com.apple.security',
                   'category': 'test', 'eventMessage': 'must not be retained'},
                  {'timestamp': 'synthetic', 'processID': 43, 'subsystem': 'com.apple.security', 'category': 'test'}]
        process = mock.Mock(stdout=io.StringIO('\n'.join(json.dumps(e) for e in events) + '\n'))
        monitor._collect(process)
        self.assertEqual(len(monitor.events()), 1)
        self.assertEqual(set(monitor.events()[0]), {'timestamp', 'processID', 'subsystem', 'category'})

    def test_keychain_metadata_requires_actual_client_identity(self):
        event = {'clientPID': 42, 'clientExecutable': '/synthetic/candidate', 'operation': 'query'}
        self.assertTrue(isolation.keychain_event_matches(event, 42, '/synthetic/candidate'))
        self.assertFalse(isolation.keychain_event_matches(event, 43, '/synthetic/candidate'))
        self.assertFalse(isolation.keychain_event_matches({'processID': 42}, 42, '/synthetic/candidate'))
        self.assertFalse(isolation.keychain_event_matches({'clientPID': True, 'clientExecutable': '/synthetic/candidate'}, 1, '/synthetic/candidate'))

    def test_probe_failure_includes_sanitized_stderr(self):
        result = subprocess.CompletedProcess([], 71, '', 'sandbox_apply: Operation not permitted')
        with mock.patch.object(isolation.subprocess, 'run', return_value=result):
            proof = isolation.synthetic_probe()
        self.assertEqual(proof['exitCode'], 71)
        self.assertEqual(proof['stderr'], 'sandbox_apply: Operation not permitted')

    def test_sandbox_failure_is_not_a_proof(self):
        with mock.patch.object(isolation.subprocess, 'run', side_effect=OSError('unavailable')):
            self.assertEqual(isolation.synthetic_probe()['status'], 'unavailable')

    def test_synthetic_sandbox_integration(self):
        proof = isolation.synthetic_probe()
        if proof['status'] == 'unavailable':
            self.skipTest('sandbox-exec unavailable in this execution context')
        self.assertEqual(proof['syntheticDeniedRead'], 'denied')
        self.assertEqual(proof['scratchWrite'], 'allowed')
        self.assertEqual(proof['outboundNetwork'], 'denied')

    def test_cli_emits_refusal_and_nonzero_exit(self):
        result = subprocess.run([sys.executable, str(MODULE)], capture_output=True, text=True, check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(json.loads(result.stdout)['verdict'], 'refuse')


if __name__ == '__main__':
    unittest.main()
