# SPDX-License-Identifier: MIT
"""Negative controls for every journey stage and the real stdio provider fixture; synthetic only."""
import copy
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

HERE = Path(__file__).parent
spec = importlib.util.spec_from_file_location('journey', HERE / 'run.py')
journey = importlib.util.module_from_spec(spec); spec.loader.exec_module(journey)


class JourneyOracleTests(unittest.TestCase):
    def setUp(self):
        self.facts = {
            1: dict(detected=True, listedInFirstRun=True, backendBound=True, providerReadsBeforeGrant=0),
            2: dict(granted=True, apiAvailable=True, releaseIdentityVerified=False, debugAdmission=True),
            3: dict(providerReads=1, postProviderSnapshot=True, nativePanelsVisible=False),
            4: dict(subscriptionRows=1, values=[37]),
            5: dict(revoked=True, valueSeenBefore=True, postRevokeSnapshot=True, values=[]),
            6: dict(regranted=True, unreadableObserved=True, postErrorSnapshot=True, rows=1, values=[],
                    settingsActionBound=True, reasonRows=[dict(reason='Reader could not obtain a reading / 读取组件未能取得读数',
                        nextStep='Open Settings to check this tool / 打开设置检查此工具')]),
        }

    def test_complete_observed_journey_passes(self):
        self.assertTrue(all(journey.passes(n, facts) for n, facts in self.facts.items()))

    def test_missing_or_empty_steps_never_pass(self):
        for step in range(1, 7):
            self.assertFalse(journey.passes(step, {}))
            self.assertFalse(journey.passes(step, None))

    def test_each_step_requires_its_actual_production_evidence(self):
        for step, key, value in [(1, 'backendBound', False), (1, 'listedInFirstRun', False),
                (1, 'providerReadsBeforeGrant', 1), (2, 'granted', False), (2, 'releaseIdentityVerified', True),
                (2, 'debugAdmission', False), (3, 'providerReads', 0), (3, 'postProviderSnapshot', False),
                (3, 'nativePanelsVisible', True), (4, 'subscriptionRows', 0), (4, 'values', [0]),
                (5, 'valueSeenBefore', False), (5, 'postRevokeSnapshot', False), (5, 'values', [37]),
                (6, 'unreadableObserved', False), (6, 'postErrorSnapshot', False), (6, 'rows', 0),
                (6, 'values', [37]), (6, 'settingsActionBound', False)]:
            with self.subTest(step=step, key=key):
                facts = copy.deepcopy(self.facts[step]); facts[key] = value
                self.assertFalse(journey.passes(step, facts))

    def test_unreadable_row_needs_human_reason_and_next_step(self):
        for reason, next_step in [('?', 'Open Settings'), ('？', 'Open Settings'), ('reader_error', 'Open Settings'),
                                  ('此构建componentUnverified尚未核验', 'Open Settings'), ('Reading unavailable', ''),
                                  ('Reading unavailable', 'not_connected_yet')]:
            facts = copy.deepcopy(self.facts[6]); facts['reasonRows'] = [dict(reason=reason, nextStep=next_step)]
            self.assertFalse(journey.passes(6, facts))


class FakeProviderTests(unittest.TestCase):
    def test_stdio_protocol_and_unreadable_transition(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary); profile = root / '.codex'; profile.mkdir()
            binary = root / 'codex'
            subprocess.run(['go', 'build', '-o', str(binary), str(HERE / 'fake-codex.go')], check=True)
            environment = {'HOME': str(root), 'CODEX_HOME': str(profile), 'PATH': '/usr/bin:/bin'}
            requests = '\n'.join(json.dumps(dict(id=n, method=method)) for n, method in
                [(1, 'initialize'), (2, 'account/rateLimits/read'), (3, 'account/read')]) + '\n'
            (profile / 'e2e-mode').write_text('readable\n')
            result = subprocess.run([str(binary), 'app-server'], input=requests, text=True, capture_output=True,
                                    env=environment, check=True, timeout=5)
            responses = [json.loads(line) for line in result.stdout.splitlines()]
            self.assertEqual(responses[1]['result']['rateLimits']['primary']['usedPercent'], 63)
            self.assertEqual(responses[2]['result']['account']['type'], 'chatgpt')
            (profile / 'e2e-mode').write_text('unreadable\n')
            result = subprocess.run([str(binary), 'app-server'], input=requests, text=True, capture_output=True,
                                    env=environment, check=True, timeout=5)
            self.assertIn('error', json.loads(result.stdout.splitlines()[1]))
            events = [json.loads(line) for line in (profile / 'e2e-calls.jsonl').read_text().splitlines()]
            self.assertEqual([x['failed'] for x in events], [False, True])
            self.assertTrue(all(set(x) == {'failed', 'at'} for x in events))


if __name__ == '__main__':
    unittest.main()
