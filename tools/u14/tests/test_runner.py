# SPDX-License-Identifier: MIT
import copy
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent.parent
sys.path.insert(0, str(ROOT))
from engine_process import EngineProcess, EngineFailure, build_binary
from engine_runner import plain_smoke, verify_baseline, zero_rows, empty_states, backpressure, admission, evaluate_admission, shared_state, null_selectors
from engine_build import build_tools
from shape_home import build_home
from contracts import load_json, encoded, write_private
import run as engine_cli


def valid_admission_observation():
    return {
        'sharedSyntheticHome': True, 'unexpectedCalls': 0,
        'postScopes': {p: {'calls': 0, 'disabledReason': 'policy_pending', 'syntheticLoginPresent': True}
                       for p in ('gemini', 'cursor')},
        'localHistory': {p: {'before': 2, 'after': 2, 'beforeSha256': 'a' * 64, 'afterSha256': 'a' * 64}
                         for p in ('gemini', 'cursor')},
        'legacyControl': {'calls': 2, 'statuses': [404, 200], 'readingAvailable': True},
        'minimax': {status: {'calls': 1, 'statuses': [int(status)], 'legacyReplyAvailable': True,
                             'legacyCalls': 0, 'budgetBeforeSha256': 'b' * 64, 'budgetAfterSha256': 'b' * 64}
                    for status in ('401', '403')},
    }


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

    def test_admission_build_uses_the_unchanged_production_constructor(self):
        self.assertIn('providers', self.tools)
        metadata = self.tools['metadata']['binaries']['providers']
        self.assertFalse(metadata['constructorChanged'])
        self.assertFalse(metadata['linksHistoryFixture'])
        replacements = {entry['path'] for entry in metadata['overlay']['replacements']}
        self.assertEqual(replacements, {'cli/internal/quota/quota_native.go',
                                       'cli/internal/quota/u14_http_provider.go'})

    def test_plain_app_server_smoke_uses_production_shared_constructor(self):
        report = plain_smoke(self.binary, self.home)
        self.assertEqual(report['outcome'], 'pass')
        self.assertEqual(report['emptyState'], 'empty')
        self.assertTrue({'claude', 'codex', 'gemini'} <= set(report['rowIds']))
        self.assertTrue({'consent', 'history', 'refresh', 'publication'} <= set(report['capabilities']))
        verify_baseline(self.home, self.baseline, mutable=('.config/modelplan/consent.json',))

    def test_registered_handler_rejects_null_selectors_before_admission_or_read(self):
        result = null_selectors(self.tools['fixture'], self.home)
        self.assertEqual(result['outcome'], 'pass')
        self.assertEqual(result['admissionCallsAfter'], result['admissionCallsBefore'])
        self.assertEqual(result['providerCallsAfter'], result['providerCallsBefore'])

    def test_null_selector_regression_detects_a_removed_production_guard(self):
        # A temporary fault overlay removes only the producer's null guard.
        # It proves this regression reaches the registered executable handler.
        source = REPO / 'cli/internal/appserver/queries/history.go'
        original = source.read_text()
        start = original.index('\t// Optional string fields distinguish omission')
        end = original.index('\n\tswitch p.Kind', start)
        temporary = Path(self.work.name)
        weakened = temporary / 'history_without_null_guard.go'
        write_private(weakened, (original[:start] + original[end:]).encode())
        overlay = load_json(Path(type(self).work.name) / 'fixture-overlay.json')
        overlay['Replace'][str(source)] = str(weakened)
        overlay_path = temporary / 'negative-null-overlay.json'
        write_private(overlay_path, encoded(overlay))
        binary = temporary / 'modelplan-without-null-guard'
        build_binary(REPO, binary, overlay_path)
        with self.assertRaisesRegex(EngineFailure, 'null-selector-not-invalid-params'):
            null_selectors(binary, self.home)

    def test_unknown_history_model_variants_keep_real_binary_rows(self):
        for mode in ('omitted', 'null', 'reported', 'corrupt'):
            with self.subTest(mode=mode):
                result = zero_rows(self.tools['fixture'], self.home, mode)
                self.assertEqual(result['outcome'], 'pass')
                self.assertTrue({'claude', 'codex', 'gemini'} <= set(result['rowIds']))
                self.assertGreater(result['recordedProviderCalls'], 0)
                self.assertEqual(result['historyUnavailable'], mode == 'corrupt')

    def test_engine_empty_states_remain_distinct(self):
        result = empty_states(self.binary, self.home, self.tools['fixture'])
        self.assertEqual(result['outcome'], 'pass')
        self.assertEqual(set(result['states']), {'readers_off', 'pending', 'no_consent', 'empty'})
        self.assertEqual({case['state']: case['binaryRole'] for case in result['cases']},
                         {'readers_off': 'plain', 'pending': 'fixture', 'no_consent': 'plain', 'empty': 'plain'})

    def test_backpressure_exits_at_real_timeout_and_replays_receipt(self):
        result = backpressure(self.tools['fixture'], self.home)
        self.assertEqual(result['outcome'], 'pass')
        self.assertEqual(result['completedQueries'], 2)
        self.assertTrue(result['revokeCommitted'])
        self.assertTrue(result['receiptReplayed'])
        self.assertTrue(result['healthChanged'])
        self.assertGreaterEqual(result['elapsedSeconds'], 9)
        self.assertLess(result['elapsedSeconds'], 13)

    def test_admission_runs_production_gates_and_reports_missing_cursor_source(self):
        plan = load_json(ROOT / 'examples/admission-plan.json')
        result = admission(self.tools['providers'], self.home, plan)
        self.assertEqual(result['outcome'], 'unsupported')
        self.assertTrue(result['productionU2Executed'])
        self.assertIn('Cursor', result['unsupported'][0])
        self.assertTrue(result['productionConstructorUnchanged'])
        self.assertEqual({id: check['outcome'] for id, check in result['subscenarios'].items()},
                         {'U2a-post-veto': 'pass', 'U2a-minimax-auth-stop': 'pass',
                          'U2a-minimax-legacy-control': 'pass', 'U2a-local-history-gemini': 'pass',
                          'U2a-local-history-cursor': 'unsupported'})

    def test_external_revoke_reset_cursor_and_off_tightening(self):
        result = shared_state(self.tools['fixture'], self.home)
        self.assertEqual(result['outcome'], 'pass')
        self.assertTrue(result['externalCLIRevoke'])
        self.assertTrue(result['resetAcrossEpochs'])
        self.assertTrue(result['queryCapAndCancellation'])

    def test_admission_acceptance_rejects_each_forbidden_event(self):
        observation = valid_admission_observation()
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

    def test_history_preservation_rejects_changed_values_with_the_same_row_count(self):
        observation = valid_admission_observation()
        observation['localHistory']['gemini']['afterSha256'] = 'b' * 64
        with self.assertRaises(EngineFailure):
            evaluate_admission(observation)

    def test_invalid_run_selection_and_in_checkout_output_are_rejected_before_creation(self):
        output = Path(self.work.name) / 'rejected'
        with self.assertRaises(EngineFailure):
            engine_cli.run(output, ['invented-scenario'])
        self.assertFalse(output.exists())
        with self.assertRaises(EngineFailure):
            engine_cli.run(REPO / 'u14-uncreated-output', ['U3-backpressure'])
        self.assertFalse((REPO / 'u14-uncreated-output').exists())

    def test_git_ignored_worktree_scratch_is_allowed_before_clean_source_check(self):
        output = REPO / '.tmp/uncreated-output-probe'
        with mock.patch.object(engine_cli, 'git', return_value='dirty'):
            with self.assertRaisesRegex(EngineFailure, 'source-must-be-clean-and-committed'):
                engine_cli.run(output, ['U3-backpressure'])
        self.assertFalse(output.exists())

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


class EpochFloorTests(unittest.TestCase):
    def setUp(self):
        self.work = tempfile.TemporaryDirectory(prefix='u14-epoch-')
        self.addCleanup(self.work.cleanup)
        self.engine = EngineProcess('/nonexistent', self.work.name, 'epoch-test')

    def frame(self, epoch, generation, data):
        return {'jsonrpc': '2.0', 'id': 1, 'result': {'sessionId': 'epoch-test',
                'storeEpoch': epoch, 'consentGeneration': generation, 'data': data}}

    def test_retired_epoch_history_cannot_restore_the_old_floor(self):
        self.engine._validate(self.frame('old', 7, {'items': []}))
        self.engine._validate(self.frame('new', 1, {'items': []}))
        with self.assertRaises(EngineFailure):
            self.engine._validate(self.frame('old', 7, {'items': []}))
        self.assertEqual((self.engine.epoch, self.engine.floor), ('new', 1))

    def test_late_old_epoch_receipt_does_not_change_the_current_context(self):
        self.engine._validate(self.frame('old', 7, {'items': []}))
        self.engine._validate(self.frame('new', 1, {'items': []}))
        self.engine._validate(self.frame('old', 8, {'committed': True}))
        self.assertEqual((self.engine.epoch, self.engine.floor), ('new', 1))

    def test_same_epoch_floor_never_decreases_and_stale_history_is_rejected(self):
        self.engine._validate(self.frame('current', 7, {'items': []}))
        self.engine._validate(self.frame('current', 3, {'committed': True}))
        self.assertEqual(self.engine.floor, 7)
        with self.assertRaises(EngineFailure):
            self.engine._validate(self.frame('current', 6, {'items': []}))


if __name__ == '__main__':
    unittest.main()
