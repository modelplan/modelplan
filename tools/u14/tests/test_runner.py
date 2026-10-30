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
    pins = {
        'gemini': [('cloudcode-pa.googleapis.com', '/v1internal:loadCodeAssist'),
                   ('cloudcode-pa.googleapis.com', '/v1internal:retrieveUserQuota')],
        'cursor': [('cursor.com', '/api/dashboard/get-plan-info'),
                   ('api2.cursor.sh', '/aiserver.v1.DashboardService/GetCurrentPeriodUsage')],
    }
    post_scopes = {}
    for tool, requests in pins.items():
        cases = {}
        for status in ('404', '401', '403'):
            deadline = {'scope': tool + '.account_usage.saved_login', 'disabledReason': 'cooldown',
                        'at': '2100-01-01T00:00:00Z'}
            cases[status] = {'calls': 2, 'readingAvailable': True,
                'requests': [{'event': tool + '-post', 'method': 'POST', 'host': host, 'path': path,
                              'status': 200, 'bodyMatched': True, 'headersMatched': True, 'credentialMatched': True}
                             for host, path in requests],
                'beforeCli': dict(deadline), 'afterCli': dict(deadline),
                'nextAttemptAt': '2100-01-01T00:00:00Z',
                'budgetBeforeSha256': 'a' * 64, 'budgetAfterSha256': 'a' * 64}
        post_scopes[tool] = {'calls': 6, 'initialState': 'unset', 'defaultCheck': False,
                            'grantable': True, 'beforeConsentCalls': 0, 'syntheticLoginPresent': True, 'cases': cases}
    return {
        'sharedSyntheticHome': True, 'unexpectedCalls': 0,
        'postScopes': post_scopes,
        'localHistory': {p: {'before': 2, 'after': 2, 'beforeSha256': 'a' * 64, 'afterSha256': 'a' * 64}
                         for p in ('gemini', 'cursor')},
        'legacyControl': {'calls': 2, 'statuses': [404, 200], 'readingAvailable': True},
        'minimax': {status: {'calls': 1, 'statuses': [int(status)], 'legacyReplyAvailable': True,
                             'legacyCalls': 0, 'budgetBeforeSha256': 'b' * 64, 'budgetAfterSha256': 'b' * 64}
                    for status in ('401', '403')},
        'sharedRefreshBudget': {status: {
            'beforeCli': {'scope': 'minimax.account_usage.api_key', 'disabledReason': 'cooldown',
                          'at': '2100-01-01T00:00:00Z'},
            'afterCli': {'scope': 'minimax.account_usage.api_key', 'disabledReason': 'cooldown',
                         'at': '2100-01-01T00:00:00Z'},
            'nextAttemptAt': '2100-01-01T00:00:00Z', 'requestsBefore': 2, 'requestsAfter': 2,
            'budgetBeforeSha256': 'b' * 64, 'budgetAfterSha256': 'b' * 64}
            for status in ('404', '401', '403')},
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

    def test_admission_reads_cursor_and_qualifies_the_shared_refresh_budget(self):
        result = admission(self.tools['providers'], self.home,
                           load_json(ROOT / 'examples/admission-plan.json'))
        self.assertEqual(result['outcome'], 'pass')
        cursor = result['subscenarios']['U2a-local-history-cursor']
        self.assertEqual(cursor['outcome'], 'pass')
        self.assertEqual((cursor['before'], cursor['after']), (2, 2))
        self.assertEqual(cursor['beforeSha256'], cursor['afterSha256'])
        budget = result['subscenarios']['U3b-refresh-shared-budget']
        self.assertEqual(budget['outcome'], 'pass')
        self.assertEqual(set(budget['cases']), {'404', '401', '403'})
        for case in result['observations']['cases']:
            self.assertEqual(case['localHistory']['cursor']['beforeTokens'], 25)
            self.assertEqual(case['localHistory']['cursor']['afterTokens'], 25)

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

    def test_admission_rejects_a_disabled_real_cursor_producer(self):
        # Retain constructor/HTTP guard, but remove only Cursor's decoder.
        source = REPO / 'cli/internal/localusage/cursor_history.go'
        disabled = Path(self.work.name) / 'cursor_disabled.go'
        write_private(disabled, b'package localusage\nfunc decodeCursorCounts(b []byte) ([]historyDatum, error) { return nil, nil }\n')
        overlay = load_json(Path(type(self).work.name) / 'providers-overlay.json')
        overlay['Replace'][str(source)] = str(disabled)
        overlay_path = Path(self.work.name) / 'cursor-disabled-overlay.json'
        write_private(overlay_path, encoded(overlay))
        binary = Path(self.work.name) / 'modelplan-without-cursor-history'
        build_binary(REPO, binary, overlay_path)
        with self.assertRaisesRegex(EngineFailure, 'local-history-not-readable|cursor-history-seed-not-readable'):
            admission(binary, self.home, load_json(ROOT / 'examples/admission-plan.json'))

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
                       lambda x: x['postScopes']['cursor'].update(defaultCheck=True),
                       lambda x: x['postScopes']['gemini'].update(initialState='allowed'),
                       lambda x: x['postScopes']['gemini'].update(grantable=False),
                       lambda x: x['postScopes']['gemini'].update(beforeConsentCalls=1),
                       lambda x: x.update(unexpectedCalls=1),
                       lambda x: x['localHistory']['gemini'].update(after=0),
                       lambda x: x['localHistory']['cursor'].update(before=0, after=0),
                       lambda x: x['localHistory']['cursor'].update(outcome='unsupported'),
                       lambda x: x['minimax']['401'].update(calls=2),
                       lambda x: x['minimax']['403'].update(legacyCalls=1),
                       lambda x: x.update(sharedSyntheticHome=False)]:
            invalid = copy.deepcopy(observation)
            mutate(invalid)
            with self.assertRaises(EngineFailure):
                evaluate_admission(invalid)

    def test_post_evaluator_rejects_unpinned_bodies_routes_calls_and_budget_changes(self):
        mutations = [lambda c: c['requests'][0].update(method='GET'),
                     lambda c: c['requests'][0].update(host='unreviewed.invalid'),
                     lambda c: c['requests'][0].update(path='/generation'),
                     lambda c: c['requests'][0].update(bodyMatched=False),
                     lambda c: c['requests'][0].update(headersMatched=False),
                     lambda c: c['requests'][0].update(credentialMatched=False),
                     lambda c: c['requests'][0].update(event='unlisted-provider-request'),
                     lambda c: c['requests'][0].update(status=401),
                     lambda c: c.update(calls=3),
                     lambda c: c.update(readingAvailable=False),
                     lambda c: c['afterCli'].update(at='2099-01-01T00:00:00Z'),
                     lambda c: c.update(budgetAfterSha256='b' * 64)]
        for tool in ('gemini', 'cursor'):
            for mutate in mutations:
                observation = valid_admission_observation()
                mutate(observation['postScopes'][tool]['cases']['404'])
                with self.subTest(tool=tool, mutation=mutate), self.assertRaises(EngineFailure):
                    evaluate_admission(observation)

    def test_post_recorder_rejects_bad_body_even_when_production_guard_is_removed(self):
        # Fail the independent recorder if a producer and its guard both regress.
        source = REPO / 'cli/internal/quota/gemini.go'
        original = source.read_text()
        self.assertEqual(original.count('"mode": "HEALTH_CHECK"'), 1)
        bad = Path(self.work.name) / 'gemini_bad_body.go'
        write_private(bad, original.replace('"mode": "HEALTH_CHECK"', '"mode": "ONBOARD"').encode())
        client = Path(self.work.name) / 'unguarded_client.go'
        write_private(client, b'package quota\nimport "net/http"\nvar accountReadClient = func(_ string,c *http.Client)*http.Client{return c}\n')
        overlay = load_json(Path(type(self).work.name) / 'providers-overlay.json')
        overlay['Replace'][str(source)] = str(bad)
        overlay['Replace'][str(REPO / 'cli/internal/quota/reader_client.go')] = str(client)
        overlay_path = Path(self.work.name) / 'bad-post-overlay.json'
        write_private(overlay_path, encoded(overlay))
        binary = Path(self.work.name) / 'modelplan-bad-post'
        build_binary(REPO, binary, overlay_path)
        with self.assertRaisesRegex(EngineFailure, 'gemini-post-capture-not-committed'):
            admission(binary, self.home, load_json(ROOT / 'examples/admission-plan.json'))
        events = (self.home / '404/.u14-http-events.jsonl').read_text().splitlines()
        import json
        requests = [json.loads(line) for line in events]
        self.assertTrue(any(r['provider'] == 'gemini' and r['event'] == 'unlisted-provider-request'
                            and not r['bodyMatched'] for r in requests))

    def test_history_preservation_rejects_changed_values_with_the_same_row_count(self):
        for tool in ('gemini', 'cursor'):
            observation = valid_admission_observation()
            observation['localHistory'][tool]['afterSha256'] = 'b' * 64
            with self.subTest(tool=tool), self.assertRaises(EngineFailure):
                evaluate_admission(observation)

    def test_shared_budget_rejects_lost_deadline_retries_and_changed_store(self):
        for mutate in [lambda b: b['afterCli'].update(at='2099-01-01T00:00:00Z'),
                       lambda b: b['afterCli'].pop('disabledReason'),
                       lambda b: b.update(requestsAfter=3),
                       lambda b: b.update(budgetAfterSha256='c' * 64),
                       lambda b: b.update(nextAttemptAt='2101-01-01T00:00:00Z')]:
            observation = valid_admission_observation()
            mutate(observation['sharedRefreshBudget']['404'])
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
