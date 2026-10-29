# SPDX-License-Identifier: MIT
"""Engine scenarios driven through the actual CLI and anonymous pipes."""
from pathlib import Path

from contracts import digest
from candidate import regular_bytes
from engine_process import EngineFailure, EngineProcess
from shape_home import safe_relative


def require(condition, code):
    if not condition:
        raise EngineFailure(code)


def verify_baseline(home, baseline):
    home = Path(home).absolute()
    for item in baseline['files']:
        safe_relative(item['path'])
        try:
            data = regular_bytes(home / item['path'])
        except (ValueError, OSError) as exc:
            raise EngineFailure('baseline-file-unavailable') from exc
        require(digest(data) == item['sha256'], 'baseline-file-changed')


def plain_smoke(binary, home):
    with EngineProcess(binary, home, 'u14-plain') as engine:
        hello = engine.initialize()
        require(hello['data']['capabilities'] == ['diagnostics', 'rows'], 'unexpected-plain-capabilities')
        response = engine.request('rows/subscribe')
        require('error' not in response, 'plain-rows-error')
        projection = response['result']['data']['projection']
        require(projection['rows'] == [], 'plain-private-rows')
        summary = projection['rowsSummary']
        require(summary['state'] == 'readers_off', 'plain-empty-state')
        require(bool(summary['text']['en']) and bool(summary['text']['zh']), 'empty-state-without-guidance')
        diagnostics = engine.request('diagnostics/get')
        require('error' not in diagnostics, 'plain-diagnostics-error')
        rejected = engine.request('diagnostics/get', {'accessToken': 'U14-SYNTHETIC-CANARY'})
        require(rejected.get('error', {}).get('code') == -32602, 'plain-token-params-not-rejected')
        engine.shutdown()
        return {'outcome': 'pass', 'emptyState': summary['state'], 'rowIds': [],
                'capabilities': hello['data']['capabilities'], 'serverVersion': hello['data']['serverVersion'], 'wireMessages': engine.messages,
                'stderrBytes': engine.stderr_bytes, 'cleanup': 'exited'}

# These are fixture-owned files, never a consent/budget/credential store.
CONFIG = '.u14-engine-fixture.json'
STATE = '.u14-engine-state.json'
EVENTS = '.u14-engine-events.jsonl'


def fixture_input(home, mode='omitted', empty=''):
    from contracts import encoded, load_json, write_private
    home = Path(home).absolute()
    require(home.resolve() == home, 'fixture-home-symlink')
    verify_baseline(home, load_json(home / '.u14-baseline.json'))
    for name in (CONFIG, STATE, EVENTS):
        path = home / name
        require(not path.is_symlink(), 'fixture-file-symlink')
        if path.exists():
            path.unlink()
    write_private(home / CONFIG, encoded({'modelMode': mode, 'emptyState': empty}))


def events(home):
    import json
    path = Path(home) / EVENTS
    if not path.exists():
        return []
    raw = regular_bytes(path)
    require(len(raw) <= 64 << 10, 'fixture-event-bound')
    # Only complete atomic event records are observations.
    return [json.loads(line)['event'] for line in raw.split(b'\n')[:-1] if line]


def fixture_hello(engine):
    hello = engine.initialize()
    require('u14_fixture' in hello['data']['capabilities'], 'fixture-constructor-not-linked')
    return hello


def row_projection(message):
    require('error' not in message, 'rows-request-error')
    return message['result']['data']['projection']


def zero_rows(binary, home, mode):
    fixture_input(home, mode)
    with EngineProcess(binary, home, 'u14-model-' + mode) as engine:
        fixture_hello(engine)
        before = row_projection(engine.request('rows/subscribe'))
        ids = [r['id'] for r in before['rows']]
        require(set(ids) == {'codex', 'declared:synthetic-team'} and len(ids) == 2, 'missing-fixture-rows')
        history = engine.request('history/query', {'kind': 'tokens', 'tool': 'codex', 'limit': 1})
        unavailable = mode == 'corrupt'
        if unavailable:
            require(history.get('error', {}).get('code') == -32050, 'history-failure-not-isolated')
        else:
            require('error' not in history, 'optional-model-rejected')
            items = history['result']['data']['items']
            require(len(items) == 1, 'history-items-lost')
            require((items[0].get('model') is None) == (mode != 'reported'), 'unknown-model-not-nullable')
        after = row_projection(engine.request('rows/subscribe'))
        require(after == before, 'history-changed-row-projection')
        engine.shutdown()
        calls = events(home).count('provider-history-get')
        require(calls == 1, 'unexpected-provider-request-count')
        return {'outcome': 'pass', 'modelMode': mode, 'rowIds': ids,
                'historyUnavailable': unavailable, 'recordedProviderCalls': calls,
                'proofScope': 'transport/engine fixture proof',
                'wireMessages': engine.messages, 'cleanup': 'exited'}


def empty_states(binary, home):
    observations, messages = [], []
    for empty in ('readers_off', 'pending', 'no_consent', 'empty'):
        fixture_input(home, 'omitted', empty)
        with EngineProcess(binary, home, 'u14-empty-' + empty) as engine:
            fixture_hello(engine)
            projection = row_projection(engine.request('rows/subscribe'))
            require(projection['rowsSummary']['state'] == empty, 'wrong-empty-summary')
            require(bool(projection['rowsSummary']['text']['en']) and
                    bool(projection['rowsSummary']['text']['zh']), 'empty-summary-without-text')
            if empty in ('readers_off', 'pending'):
                require(projection['rows'] == [], 'private-rows-in-off-state')
            if empty == 'no_consent':
                require(all('dock' not in r['surfaces'] and r['accounts'] == []
                            for r in projection['rows']), 'no-consent-dock-values')
            observations.append(empty)
            engine.shutdown()
            messages.extend(engine.messages)
    return {'outcome': 'pass', 'states': observations, 'wireMessages': messages,
            'proofScope': 'transport/engine fixture proof', 'cleanup': 'exited'}


def backpressure(binary, home):
    import time
    from engine_process import EngineTimeout
    fixture_input(home)
    revoke = {'requestId': 'u14-lost-receipt', 'expectStoreEpoch': 'u14-fixture-epoch',
              'expectGeneration': 1, 'consentTextVersion': 2, 'allow': [],
              'deny': ['codex.runtime_usage']}
    with EngineProcess(binary, home, 'u14-pressure-first') as engine:
        fixture_hello(engine)
        started = time.monotonic()
        for id, ref in ((10, 'pressure-first'), (11, 'pressure-second')):
            engine.send(id, 'history/query', {'kind': 'tokens', 'tool': 'codex', 'ref': ref, 'limit': 1})
        deadline = time.monotonic() + 3
        while events(home).count('query-completed') < 2:
            if time.monotonic() >= deadline:
                raise EngineTimeout('two-queries-did-not-complete')
            time.sleep(0.01)
        engine.first_data_byte()  # A real data write has begun; stop stdout reads now.
        engine.send(12, 'consent/grant', revoke)
        deadline = time.monotonic() + 3
        while not {'revoke-committed', 'health-observed'}.issubset(events(home)):
            if time.monotonic() >= deadline:
                raise EngineTimeout('control-stalled-behind-data')
            time.sleep(0.01)
        require(engine.wait(13) == 0, 'pressure-process-failed')
        elapsed = time.monotonic() - started
        require(9 <= elapsed < 13, 'production-write-timeout-not-observed')
        messages = list(engine.messages)
    observed = events(home)
    require(observed.count('query-completed') == 2, 'query-completion-count')
    with EngineProcess(binary, home, 'u14-pressure-restart') as restart:
        hello = fixture_hello(restart)
        require(hello['consentGeneration'] == 2, 'revoke-undone-on-restart')
        receipt = restart.request('consent/grant', revoke)
        require('error' not in receipt, 'lost-receipt-not-replayed')
        env = receipt['result']
        require(env['storeEpoch'] == 'u14-fixture-epoch' and env['consentGeneration'] == 2,
                'receipt-context-not-preserved')
        require(env['data']['committed'] and env['data']['committedGeneration'] == 2,
                'receipt-commit-not-preserved')
        facts = restart.request('consent/get')['result']['data']['scopes']
        require(facts and all(s['state'] == 'denied' for s in facts), 'grant-restored-on-replay')
        projection = row_projection(restart.request('rows/subscribe'))
        require(all(r['accounts'] == [] for r in projection['rows']), 'values-restored-after-revoke')
        restart.shutdown()
        messages.extend(restart.messages)
    require('receipt-replayed' in events(home), 'receipt-replay-not-observed')
    return {'outcome': 'pass', 'completedQueries': 2, 'revokeCommitted': True,
            'healthChanged': True, 'receiptReplayed': True, 'stdoutPaused': True,
            'elapsedSeconds': round(elapsed, 3), 'productionWriteTimeoutSeconds': 10,
            'proofScope': 'transport/engine fixture proof', 'u2PersistenceProof': False,
            'wireMessages': messages, 'cleanup': 'exited'}


def evaluate_admission(observation):
    """Acceptance assertions for the future production-U2/provider adapter."""
    require(observation.get('sharedSyntheticHome') is True, 'admission-home-not-shared')
    for provider in ('gemini', 'cursor'):
        item = observation['postScopes'][provider]
        require(item['calls'] == 0 and item['disabledReason'] == 'policy_pending', 'unapproved-post-admitted')
        history = observation['localHistory'][provider]
        require(history['before'] > 0 and history['after'] == history['before'], 'local-history-lost')
    for status in ('401', '403'):
        item = observation['minimax'][status]
        require(item['calls'] == 1 and item['legacyReplyAvailable'] is True and
                item['legacyCalls'] == 0, 'minimax-retried-after-auth-failure')
    return {'outcome': 'pass', 'proofScope': 'production U2 admission with recording providers'}


def admission(binary, home, plan):
    # Probe the *ordinary* constructor, not the fixture's synthetic receipt store.
    # A new producer constructor requires a deliberate rebind before this can pass.
    with EngineProcess(binary, home, 'u14-admission-probe') as engine:
        hello = engine.initialize()
        capabilities = hello['data']['capabilities']
        require('u14_fixture' not in capabilities, 'admission-used-fake-consent-backend')
        if 'consent' in capabilities:
            raise EngineFailure('u2-constructor-arrived-admission-adapter-must-be-bound')
        engine.shutdown()
        return {'outcome': 'not-run', 'dependency': 'production U2 constructor and recording-provider binding',
                'requiredAssertions': plan['assertions'], 'observedCapabilities': capabilities,
                'productionU2Executed': False, 'wireMessages': engine.messages, 'cleanup': 'exited'}
