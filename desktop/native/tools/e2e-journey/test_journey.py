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
    def row(self, tool, reason='Reading unavailable / 读取暂不可用', next_step='Check reader status in Settings / 在设置检查读取状态'):
        return dict(providers=[tool], dataState='unavailable', readout='--', remainingPercent=None,
                    cardOpened=True, reason=reason, nextStep=next_step)

    def setUp(self):
        self.facts = {
            1: dict(detected=True, grokDetected=True, listedInFirstRun=True, backendBound=True, providerReadsBeforeGrant=0),
            2: dict(granted=True, apiAvailable=True, releaseIdentityVerified=False, debugAdmission=True),
            3: dict(granted=True, connectionPresent=True, connectionNoReading=True, accountCount=0,
                    renderedRows=[self.row('codex', 'Waiting for first reading / 等待首次读取')]),
            4: dict(providerReads=1, postProviderSnapshot=True, visibleRefreshAttempts=0, visibleRefreshSuccesses=0,
                    postVisibleRefreshSnapshot=False),
            5: dict(renderedRows=[dict(provider='codex', providers=['codex'], accountAssociated=True,
                    hasSubscription=False, dataState='fresh', readout='37%', remainingPercent=37)]),
            6: dict(freshBoundRow=True, cardOpened=True, ageText='Observed 1 min ago / 1分钟前观测'),
            7: dict(revoked=True, valueSeenBefore=True, postRevokeSnapshot=True, values=[]),
            8: dict(regranted=True, unreadableObserved=True, postErrorSnapshot=True, rows=1, values=[],
                    rowActionDispatched=True, settingsDestinationReached=True, reasonRows=[self.row('codex')]),
            9: dict(granted=True, nativeErrorObserved=True, postGrantSnapshot=True, accountCount=0, connectionCount=0,
                    renderedRows=[self.row('grok')]),
            10: dict(granted=True, keychainUnset=True, credentialsFileAbsent=True, nativeConsentRequired=True,
                     keychainChoiceNeeded=True, postGrantSnapshot=True, accountCount=0,
                     renderedRows=[self.row('claude', 'Keychain permission required / 需要钥匙串许可',
                                           'Allow Keychain for Claude Code in Settings')]),
            11: dict(granted=True, keyEnvUnset=True, missingKeyObserved=True, postGrantSnapshot=True,
                     cliReason=journey.MISSING_KEY_REASON,
                     renderedRows=[self.row('zai', 'Missing key / 缺少密钥', journey.MISSING_KEY_REASON)]),
        }
        for step, facts in self.facts.items():
            allowed = [] if step in (1, 7) else ['codex']
            if step >= 9: allowed = ['codex', 'grok']
            if step >= 10: allowed.append('claude')
            if step >= 11: allowed.append('zai')
            facts['rowInvariant'] = dict(canonicalKnown=True, allowedTools=allowed, rowCounts={tool: 1 for tool in allowed})
            facts.update(variant='headless', nativePanelsEnabled=False, nativePanelsVisible=False)
            facts['guidanceRows'] = [] if step in (1, 4, 5, 6, 7) else [self.row(tool) for tool in allowed]
            facts['nonFreshRowCount'] = len(facts['guidanceRows'])

    def test_all_eleven_headless_checkpoints_can_pass(self):
        self.assertTrue(all(journey.passes(n, facts) for n, facts in self.facts.items()))

    def test_native_requires_normal_panels_and_successful_visible_refresh(self):
        facts = copy.deepcopy(self.facts)
        for value in facts.values():
            value.update(variant='native', nativePanelsEnabled=True, nativePanelsVisible=True)
        facts[4].update(visibleRefreshAttempts=2, visibleRefreshSuccesses=1, postVisibleRefreshSnapshot=True)
        self.assertTrue(all(journey.passes(n, value, 'native') for n, value in facts.items()))
        for change in [dict(nativePanelsEnabled=False), dict(nativePanelsVisible=False), dict(visibleRefreshAttempts=0),
                       dict(visibleRefreshSuccesses=0), dict(postVisibleRefreshSnapshot=False), dict(variant='headless')]:
            self.assertFalse(journey.passes(4, {**facts[4], **change}, 'native'), change)
        self.assertFalse(journey.passes(4, {**self.facts[4], 'visibleRefreshAttempts': 1}))

    def test_missing_or_empty_checkpoints_never_pass(self):
        for step in journey.STEPS:
            self.assertFalse(journey.passes(step, {})); self.assertFalse(journey.passes(step, None))

    def test_each_checkpoint_requires_actual_production_evidence(self):
        controls = [(1, 'backendBound', False), (1, 'grokDetected', False), (1, 'listedInFirstRun', False),
                    (1, 'providerReadsBeforeGrant', 1), (2, 'granted', False), (2, 'releaseIdentityVerified', True),
                    (2, 'debugAdmission', False), (3, 'connectionNoReading', False), (3, 'accountCount', 1),
                    (4, 'providerReads', 0), (4, 'postProviderSnapshot', False), (5, 'renderedRows', []),
                    (6, 'freshBoundRow', False), (6, 'cardOpened', False), (6, 'ageText', ''),
                    (7, 'valueSeenBefore', False), (7, 'postRevokeSnapshot', False), (7, 'values', [37]),
                    (8, 'unreadableObserved', False), (8, 'postErrorSnapshot', False), (8, 'rows', 0),
                    (8, 'values', [37]), (8, 'rowActionDispatched', False), (8, 'settingsDestinationReached', False),
                    (9, 'nativeErrorObserved', False), (9, 'accountCount', 1), (9, 'connectionCount', 1),
                    (9, 'renderedRows', []), (9, 'postGrantSnapshot', False),
                    (10, 'keychainUnset', False), (10, 'credentialsFileAbsent', False), (10, 'accountCount', 1),
                    (10, 'nativeConsentRequired', False), (10, 'keychainChoiceNeeded', False),
                    (11, 'keyEnvUnset', False), (11, 'missingKeyObserved', False), (11, 'cliReason', '')]
        for step, key, value in controls:
            facts = copy.deepcopy(self.facts[step]); facts[key] = value
            self.assertFalse(journey.passes(step, facts), (step, key))

    def test_same_rendered_account_must_own_the_fixture_value(self):
        valid = self.facts[5]['renderedRows'][0]
        for field, value in [('provider', 'other'), ('accountAssociated', False), ('readout', '--'),
                             ('remainingPercent', 0), ('remainingPercent', True)]:
            self.assertFalse(journey.passes(5, {**self.facts[5], 'renderedRows': [{**valid, field: value}]}))
        rows = [{**valid, 'hasSubscription': True, 'readout': '--', 'remainingPercent': None}, {**valid, 'provider': 'other'}]
        self.assertFalse(journey.passes(5, {**self.facts[5], 'renderedRows': rows}))

    def test_every_allowed_tool_requires_exactly_one_row_at_every_checkpoint(self):
        for step in journey.STEPS:
            for bad in [None, {}, dict(canonicalKnown=False, allowedTools=[], rowCounts={}),
                        dict(canonicalKnown=True, allowedTools=['grok'], rowCounts={'grok': 0}),
                        dict(canonicalKnown=True, allowedTools=['grok'], rowCounts={'grok': 2}),
                        dict(canonicalKnown=True, allowedTools=['grok'], rowCounts={'grok': True}),
                        dict(canonicalKnown=True, allowedTools=['grok'], rowCounts={})]:
                self.assertFalse(journey.passes(step, {**self.facts[step], 'rowInvariant': bad}), (step, bad))

    def test_all_nonfresh_cards_need_actual_reason_and_next_step(self):
        for step in journey.STEPS:
            for bad in [dict(nonFreshRowCount=1, guidanceRows=[]),
                        dict(nonFreshRowCount=1, guidanceRows=[self.row('codex', '?')]),
                        dict(nonFreshRowCount=1, guidanceRows=[self.row('codex', next_step='')]),
                        dict(nonFreshRowCount=1, guidanceRows=[{**self.row('codex'), 'cardOpened': False}]),
                        dict(nonFreshRowCount=1, guidanceRows=[self.row('codex', '读取失败reader_error请检查')])]:
                self.assertFalse(journey.passes(step, {**self.facts[step], **bad}), (step, bad))

    def test_age_requires_minutes_or_hours_and_a_fresh_bound_card(self):
        for age in ['Observed 0 min ago', 'Observed 2 hours ago / 2小时前观测', '1h 5m', '不到1分钟前']:
            self.assertTrue(journey.passes(6, {**self.facts[6], 'ageText': age}), age)
        for age in ['', '?', 'Observation time unknown', 'Observed 7200s ago / 7200秒前观测', '60 seconds ago', '2 min 3 sec']:
            self.assertFalse(journey.passes(6, {**self.facts[6], 'ageText': age}), age)

    def test_pending_reason_is_matched_on_quota_reason_not_generic_copy(self):
        valid = self.facts[3]
        self.assertFalse(journey.passes(3, {**valid, 'renderedRows': [self.row('codex', 'No current reading')]}))
        self.assertFalse(journey.passes(3, {**valid, 'connectionNoReading': False}))

    def test_claude_unset_cannot_pass_without_the_keychain_next_step(self):
        valid = self.facts[10]
        self.assertFalse(journey.passes(10, {**valid, 'renderedRows': [self.row('claude')]}))
        self.assertFalse(journey.passes(10, {**valid, 'renderedRows': [self.row('codex')]}))
        self.assertFalse(journey.passes(10, {**valid, 'renderedRows': [{**valid['renderedRows'][0], 'remainingPercent': 37}]}))

    def test_missing_key_cannot_pass_as_an_endless_wait_or_lost_cli_reason(self):
        valid = self.facts[11]
        self.assertFalse(journey.passes(11, {**valid, 'renderedRows': [self.row('zai', 'Waiting for first reading')]}))
        self.assertFalse(journey.passes(11, {**valid, 'renderedRows': [self.row('zai')]}))
        self.assertFalse(journey.passes(11, {**valid, 'renderedRows': [self.row('codex', next_step=journey.MISSING_KEY_REASON)]}))

    def test_raw_codes_adjoining_cjk_are_not_human_guidance(self):
        for reason in ['reader_error', '此构建componentUnverified尚未核验', '读取失败readerError请检查设置']:
            self.assertFalse(journey.passes(8, {**self.facts[8], 'reasonRows': [self.row('codex', reason)]}))
        self.assertTrue(journey.human('Open ModelPlan Settings / 打开 ModelPlan 设置'))

    def test_first_grok_failure_never_invents_membership_or_a_connection(self):
        valid = self.facts[9]
        for changes in [dict(accountCount=1), dict(connectionCount=1), dict(nativeErrorObserved=False),
                        dict(renderedRows=[]), dict(renderedRows=valid['renderedRows'] * 2)]:
            self.assertFalse(journey.passes(9, {**valid, **changes}), changes)

    def test_runtime_jail_denies_keychain_paths_daemons_and_security_executable(self):
        profile = journey.journey_sandbox()
        for required in ['(deny network*)', '(deny process-exec (literal "/usr/bin/security"))',
                         '(deny file-read* file-write*', '/Keychains(/|$)', '(deny mach-lookup',
                         'com.apple.securityd', 'com.apple.SecurityServer']:
            self.assertIn(required, profile)


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
