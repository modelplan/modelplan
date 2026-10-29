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
            1: dict(detected=True, grokDetected=True, listedInFirstRun=True, backendBound=True, providerReadsBeforeGrant=0),
            2: dict(granted=True, apiAvailable=True, releaseIdentityVerified=False, debugAdmission=True),
            3: dict(providerReads=1, postProviderSnapshot=True, nativePanelsVisible=False),
            4: dict(renderedRows=[dict(provider='codex', accountAssociated=True, hasSubscription=False,
                                      readout='37%', remainingPercent=37)]),
            5: dict(freshBoundRow=True, cardOpened=True, ageText='Observed 1 min ago / 1分钟前观测'),
            6: dict(revoked=True, valueSeenBefore=True, postRevokeSnapshot=True, values=[]),
            7: dict(regranted=True, unreadableObserved=True, postErrorSnapshot=True, rows=1, values=[],
                    rowActionDispatched=True, settingsDestinationReached=True,
                    reasonRows=[dict(reason='Reader could not obtain a reading / 读取组件未能取得读数',
                        nextStep='Open Settings to check this tool / 打开设置检查此工具')]),
            8: dict(granted=True, nativeErrorObserved=True, postGrantSnapshot=True, accountCount=0, connectionCount=0,
                    renderedRows=[dict(providers=['grok'], readout='--', remainingPercent=None,
                        reason='Reading unavailable / 读取暂不可用', nextStep='Check reader status in Settings / 在设置检查读取状态')]),
        }
        for step, facts in self.facts.items():
            allowed = [] if step in (1, 6) else ['codex', 'grok'] if step == 8 else ['codex']
            facts['rowInvariant'] = dict(canonicalKnown=True, allowedTools=allowed, rowCounts={tool: 1 for tool in allowed})

    def test_complete_observed_journey_passes(self):
        self.assertTrue(all(journey.passes(n, facts) for n, facts in self.facts.items()))

    def test_missing_or_empty_steps_never_pass(self):
        for step in journey.STEPS:
            self.assertFalse(journey.passes(step, {}))
            self.assertFalse(journey.passes(step, None))

    def test_each_step_requires_its_actual_production_evidence(self):
        for step, key, value in [(1, 'backendBound', False), (1, 'grokDetected', False), (1, 'listedInFirstRun', False),
                (1, 'providerReadsBeforeGrant', 1), (2, 'granted', False), (2, 'releaseIdentityVerified', True),
                (2, 'debugAdmission', False), (3, 'providerReads', 0), (3, 'postProviderSnapshot', False),
                (3, 'nativePanelsVisible', True), (4, 'renderedRows', []),
                (5, 'freshBoundRow', False), (5, 'cardOpened', False), (5, 'ageText', ''),
                (8, 'nativeErrorObserved', False), (8, 'accountCount', 1), (8, 'connectionCount', 1),
                (8, 'renderedRows', []), (8, 'postGrantSnapshot', False),
                (6, 'valueSeenBefore', False), (6, 'postRevokeSnapshot', False), (6, 'values', [37]),
                (7, 'unreadableObserved', False), (7, 'postErrorSnapshot', False), (7, 'rows', 0),
                (7, 'values', [37]), (7, 'rowActionDispatched', False), (7, 'settingsDestinationReached', False)]:
            with self.subTest(step=step, key=key):
                facts = copy.deepcopy(self.facts[step]); facts[key] = value
                self.assertFalse(journey.passes(step, facts))

    def test_fixture_value_must_belong_to_the_same_rendered_account_row(self):
        valid = self.facts[4]['renderedRows'][0]
        self.assertTrue(journey.passes(4, self.facts[4]), 'Absent membership is legitimate')
        for field, value in [('provider', 'other'), ('accountAssociated', False), ('readout', '--'),
                             ('remainingPercent', 0), ('remainingPercent', True)]:
            wrong = {**valid, field: value}
            self.assertFalse(journey.passes(4, {**self.facts[4], 'renderedRows': [wrong]}))
        # An unrelated verified subscription and an unbound 37% value cannot be combined.
        rows = [{**valid, 'hasSubscription': True, 'readout': '--', 'remainingPercent': None},
                {**valid, 'provider': 'other', 'hasSubscription': False}]
        self.assertFalse(journey.passes(4, {**self.facts[4], 'subscriptionRows': 1, 'values': [37], 'renderedRows': rows}))

    def test_unreadable_row_needs_human_reason_and_next_step(self):
        for reason, next_step in [('?', 'Open Settings'), ('？', 'Open Settings'), ('reader_error', 'Open Settings'),
                                  ('此构建componentUnverified尚未核验', 'Open Settings'), ('Reading unavailable', ''),
                                  ('读取失败reader_error请检查设置', 'Open Settings'),
                                  ('读取失败readerError请检查设置', 'Open Settings'),
                                  ('Reading unavailable', 'not_connected_yet')]:
            facts = copy.deepcopy(self.facts[7]); facts['reasonRows'] = [dict(reason=reason, nextStep=next_step)]
            self.assertFalse(journey.passes(7, facts))
        self.assertTrue(journey.human('Open ModelPlan Settings / 打开 ModelPlan 设置'))


    def test_every_checkpoint_requires_exactly_one_row_per_canonically_allowed_tool(self):
        for step in journey.STEPS:
            for bad in [None, {}, dict(canonicalKnown=False, allowedTools=[], rowCounts={}),
                        dict(canonicalKnown=True, allowedTools=['grok'], rowCounts={'grok': 0}),
                        dict(canonicalKnown=True, allowedTools=['grok'], rowCounts={'grok': 2}),
                        dict(canonicalKnown=True, allowedTools=['grok'], rowCounts={'grok': True}),
                        dict(canonicalKnown=True, allowedTools=['grok'], rowCounts={}),
                        dict(canonicalKnown=True, allowedTools=['grok', 'grok'], rowCounts={'grok': 1})]:
                facts = copy.deepcopy(self.facts[step]); facts['rowInvariant'] = bad
                self.assertFalse(journey.passes(step, facts), (step, bad))
        self.assertTrue(journey.row_invariant(dict(rowInvariant=dict(canonicalKnown=True, allowedTools=[], rowCounts={}))))
        self.assertTrue(journey.row_invariant(dict(rowInvariant=dict(canonicalKnown=True, allowedTools=['qwen'], rowCounts={'qwen': 1}))))

    def test_age_requires_actual_fresh_bound_card_and_minute_or_hour_units(self):
        for age in ['Observed 0 min ago', 'Observed 2 hours ago / 2小时前观测', '1h 5m', '不到1分钟前']:
            self.assertTrue(journey.passes(5, {**self.facts[5], 'ageText': age}), age)
        for age in ['', '?', 'Observation time unknown', 'Observed 7200s ago / 7200秒前观测',
                    'Observed 60 seconds ago', '2 min 3 sec', '2026-10-29T06:00:00Z', '1 month ago']:
            self.assertFalse(journey.passes(5, {**self.facts[5], 'ageText': age}), age)

    def test_first_failure_requires_one_grok_row_and_no_account_or_connection(self):
        valid = self.facts[8]
        for changes in [dict(accountCount=1), dict(connectionCount=1), dict(nativeErrorObserved=False),
                        dict(renderedRows=[]), dict(renderedRows=valid['renderedRows'] * 2),
                        dict(renderedRows=[{**valid['renderedRows'][0], 'providers': ['codex']}]),
                        dict(renderedRows=[{**valid['renderedRows'][0], 'reason': 'reader_error'}]),
                        dict(renderedRows=[{**valid['renderedRows'][0], 'nextStep': ''}])]:
            self.assertFalse(journey.passes(8, {**valid, **changes}), changes)


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
