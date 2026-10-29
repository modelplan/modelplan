# SPDX-License-Identifier: MIT
import copy
import os
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent.parent
sys.path.insert(0, str(ROOT))
from engine_process import EngineProcess, EngineFailure
from engine_runner import plain_smoke, verify_baseline, zero_rows, empty_states, backpressure, admission, evaluate_admission
from engine_build import build_tools
from shape_home import build_home
from contracts import load_json
import run as engine_cli


class RealBinaryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.work = tempfile.TemporaryDirectory(prefix='u14-real-binary-')
        cls.addClassCleanup(cls.work.cleanup)
        cls.tools = build_tools(REPO, Path(cls.work.name))
        cls.binary = cls.tools['plain']

    def setUp(self):
        self.work = tempfile.TemporaryDirectory(prefix='u14-runner-test-')
        self.addCleanup(self.work.cleanup)
        self.home = Path(self.work.name) / 'home'
        self.baseline = build_home(load_json(ROOT / 'examples/synthetic-shape.json'), self.home)

    def test_plain_app_server_smoke_reaches_real_cli_and_stays_inert(self):
        report = plain_smoke(self.binary, self.home)
        self.assertEqual(report['outcome'], 'pass')
        self.assertEqual(report['emptyState'], 'readers_off')
        self.assertEqual(report['rowIds'], [])
        self.assertEqual(report['capabilities'], ['diagnostics', 'rows'])
        verify_baseline(self.home, self.baseline)

    def test_unknown_history_model_variants_keep_real_binary_rows(self):
        for mode in ('omitted', 'null', 'reported', 'corrupt'):
            with self.subTest(mode=mode):
                result = zero_rows(self.tools['fixture'], self.home, mode)
                self.assertEqual(result['outcome'], 'pass')
                self.assertEqual(set(result['rowIds']), {'codex', 'declared:synthetic-team'})
                self.assertGreater(result['recordedProviderCalls'], 0)
                self.assertEqual(result['historyUnavailable'], mode == 'corrupt')

    def test_engine_empty_states_remain_distinct(self):
        result = empty_states(self.tools['fixture'], self.home)
        self.assertEqual(result['outcome'], 'pass')
        self.assertEqual(set(result['states']), {'readers_off', 'pending', 'no_consent', 'empty'})

    def test_backpressure_exits_at_real_timeout_and_replays_receipt(self):
        result = backpressure(self.tools['fixture'], self.home)
        self.assertEqual(result['outcome'], 'pass')
        self.assertEqual(result['completedQueries'], 2)
        self.assertTrue(result['revokeCommitted'])
        self.assertTrue(result['receiptReplayed'])
        self.assertTrue(result['healthChanged'])
        self.assertGreaterEqual(result['elapsedSeconds'], 9)
        self.assertLess(result['elapsedSeconds'], 13)

    def test_admission_waits_for_production_u2_and_never_uses_fixture_receipts(self):
        plan = load_json(ROOT / 'examples/admission-plan.json')
        result = admission(self.binary, self.home, plan)
        self.assertEqual(result['outcome'], 'not-run')
        self.assertFalse(result['productionU2Executed'])

    def test_admission_acceptance_rejects_each_forbidden_event(self):
        observation = {
            'sharedSyntheticHome': True,
            'postScopes': {p: {'calls': 0, 'disabledReason': 'policy_pending'} for p in ('gemini', 'cursor')},
            'localHistory': {p: {'before': 2, 'after': 2} for p in ('gemini', 'cursor')},
            'minimax': {s: {'calls': 1, 'legacyReplyAvailable': True, 'legacyCalls': 0} for s in ('401', '403')},
        }
        self.assertEqual(evaluate_admission(observation)['outcome'], 'pass')
        for mutate in [lambda x: x['postScopes']['gemini'].update(calls=1),
                       lambda x: x['postScopes']['cursor'].update(disabledReason='ok'),
                       lambda x: x['localHistory']['gemini'].update(after=0),
                       lambda x: x['minimax']['401'].update(calls=2),
                       lambda x: x['minimax']['403'].update(legacyCalls=1),
                       lambda x: x.update(sharedSyntheticHome=False)]:
            invalid = copy.deepcopy(observation)
            mutate(invalid)
            with self.assertRaises(EngineFailure):
                evaluate_admission(invalid)

    def test_invalid_run_selection_and_in_checkout_output_are_rejected_before_creation(self):
        output = Path(self.work.name) / 'rejected'
        with self.assertRaises(EngineFailure):
            engine_cli.run(output, ['invented-scenario'])
        self.assertFalse(output.exists())
        with self.assertRaises(EngineFailure):
            engine_cli.run(REPO / 'u14-uncreated-output', ['U3-backpressure'])
        self.assertFalse((REPO / 'u14-uncreated-output').exists())

    def test_baseline_tampering_is_rejected(self):
        (self.home / '.claude/.credentials.json').write_text('synthetic tamper')
        with self.assertRaises(EngineFailure):
            verify_baseline(self.home, self.baseline)

    def test_allowlisted_child_environment_ignores_parent_keys_and_real_home(self):
        prior = os.environ.get('U14_SECRET_CANARY')
        os.environ['U14_SECRET_CANARY'] = 'must-not-be-forwarded'
        try:
            with EngineProcess(self.binary, self.home, 'u14-environment') as engine:
                self.assertEqual(engine.environment['HOME'], str(self.home))
                self.assertNotIn('U14_SECRET_CANARY', engine.environment)
                self.assertFalse(any('API_KEY' in key for key in engine.environment))
                engine.initialize()
                engine.shutdown()
        finally:
            if prior is None:
                del os.environ['U14_SECRET_CANARY']
            else:
                os.environ['U14_SECRET_CANARY'] = prior

    def test_protocol_mismatch_is_observed_and_not_restarted(self):
        with EngineProcess(self.binary, self.home, 'u14-version') as engine:
            engine.send(1, 'initialize', {'sessionId': engine.session, 'protocolVersion': '99.0',
                                         'appVersion': 'synthetic', 'capabilities': []})
            result = engine.response(1)
            self.assertEqual(result['error']['code'], -32010)
            self.assertEqual(engine.wait(3), 0)


if __name__ == '__main__':
    unittest.main()
