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


def verify_baseline(home, baseline, mutable=()):
    home = Path(home).absolute()
    for item in baseline['files']:
        safe_relative(item['path'])
        if item['path'] in mutable:
            continue
        try:
            data = regular_bytes(home / item['path'])
        except (ValueError, OSError) as exc:
            raise EngineFailure('baseline-file-unavailable') from exc
        require(digest(data) == item['sha256'], 'baseline-file-changed')


def cli(binary, home, args, payload=None, environment=None):
    import json, subprocess
    env = {'HOME': str(home), 'PATH': str(Path(home) / 'bin'), 'LANG': 'C.UTF-8'}
    env.update(environment or {})
    result = subprocess.run([str(binary), *args], input=None if payload is None else json.dumps(payload),
                            text=True, capture_output=True, env=env, timeout=15)
    require(result.returncode == 0, 'independent-cli-failed')
    return json.loads(result.stdout) if result.stdout.strip() else {}


def state(home):
    from contracts import load_json
    return load_json(Path(home) / '.config/modelplan/consent.json')


def decision(home, **actions):
    import uuid
    current = state(home)
    return {'requestId': str(uuid.uuid4()), 'expectStoreEpoch': current['storeEpoch'],
            'expectGeneration': current['generation'], 'consentTextVersion': 2, 'allow': [], 'deny': [], **actions}


def tighten(binary, home, **actions):
    result = cli(binary, home, ['consent', 'grant', '--json'], decision(home, **actions))
    require(result.get('committed'), 'external-tightening-not-committed')
    return result


def plain_smoke(binary, home):
    with EngineProcess(binary, home, 'u14-plain') as engine:
        hello = engine.initialize()
        require({'consent', 'rows', 'diagnostics', 'history', 'refresh', 'publication', 'plugin_install'} <=
                set(hello['data']['capabilities']), 'production-handlers-not-linked')
        require(hello['storeEpoch'] not in ('unavailable', ''), 'production-epoch-missing')
        projection = row_projection(engine.request('rows/subscribe'))
        report = cli(binary, home, ['detect', '--json'])
        expected = {tool['providerId'] for tool in report['tools'] if tool['detected']} | set(state(home)['tools'])
        require({row['id'] for row in projection['rows']} == expected, 'production-row-membership')
        require(all(not row['accounts'] for row in projection['rows']), 'unexpected-initial-private-values')
        summary = projection['rowsSummary']
        require(bool(summary['text']['en']) and bool(summary['text']['zh']), 'empty-state-without-guidance')
        require('error' not in engine.request('diagnostics/get'), 'plain-diagnostics-error')
        rejected = engine.request('diagnostics/get', {'accessToken': 'U14-SYNTHETIC-CANARY'})
        require(rejected.get('error', {}).get('code') == -32602, 'plain-token-params-not-rejected')
        rejected = engine.request('credentials/result', {'operationId': 'unknown', 'outcome': 'ok', 'accessToken': 'U14-SYNTHETIC-CANARY'})
        require(rejected.get('error', {}).get('code') == -32030, 'unknown-credential-operation-used')
        require('U14-SYNTHETIC-CANARY' not in str(engine.messages), 'token-reflected')
        engine.shutdown()
        return {'outcome': 'pass', 'emptyState': summary['state'], 'rowIds': sorted(expected),
                'capabilities': hello['data']['capabilities'], 'serverVersion': hello['data']['serverVersion'], 'wireMessages': engine.messages,
                'proofScope': 'ordinary production constructor', 'stderrBytes': engine.stderr_bytes, 'cleanup': 'exited'}

# These are fixture-owned files, never a consent/budget/credential store.
CONFIG = '.u14-engine-fixture.json'
EVENTS = '.u14-engine-events.jsonl'


def fixture_input(home, mode='omitted', empty='', pressure=False, **extra):
    from contracts import encoded, load_json, write_private
    home = Path(home).absolute()
    require(home.resolve() == home, 'fixture-home-symlink')
    verify_baseline(home, load_json(home / '.u14-baseline.json'), mutable=('.config/modelplan/consent.json',))
    for name in (CONFIG, EVENTS):
        path = home / name
        require(not path.is_symlink(), 'fixture-file-symlink')
        if path.exists():
            path.unlink()
    write_private(home / CONFIG, encoded({'modelMode': mode, 'emptyState': empty, 'pressure': pressure, **extra}))


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
    require('consent' in hello['data']['capabilities'] and hello['storeEpoch'] != 'unavailable', 'production-consent-not-linked')
    return hello


def row_projection(message):
    require('error' not in message, 'rows-request-error')
    return message['result']['data']['projection']


def fresh_rows(engine):
    import time
    deadline = time.monotonic() + 3
    while True:
        result = engine.request('rows/subscribe')
        if result.get('error', {}).get('code') != -32023:
            return row_projection(result)
        require(time.monotonic() < deadline, 'rows-publication-did-not-stabilize')
        time.sleep(.01)


def null_selectors(binary, home):
    fixture_input(home)
    with EngineProcess(binary, home, 'u14-null-selectors') as engine:
        fixture_hello(engine)
        valid = {'kind': 'tokens', 'tool': 'codex', 'limit': 1}
        require('result' in engine.request('history/query', valid), 'history-positive-control-failed')
        before = events(home)
        require(before.count('history-admission') == 1 and before.count('provider-history-get') == 1,
                'history-source-not-observable')
        cases = ({'ref': None}, {'cursor': None}, {'ref': None, 'cursor': None})
        for selectors in cases:
            rejected = engine.request('history/query', {**valid, **selectors})
            require(rejected.get('error', {}).get('code') == -32602, 'null-selector-not-invalid-params')
            require(events(home) == before, 'null-selector-reached-admission-or-read')
        engine.shutdown()
        return {'outcome': 'pass', 'cases': ['ref:null', 'cursor:null', 'ref:null,cursor:null'],
                'admissionCallsBefore': 1, 'admissionCallsAfter': 1,
                'providerCallsBefore': 1, 'providerCallsAfter': 1,
                'proofScope': 'registered production history handler; recording history source',
                'wireMessages': engine.messages, 'cleanup': 'exited'}


def zero_rows(binary, home, mode):
    fixture_input(home, mode)
    with EngineProcess(binary, home, 'u14-model-' + mode) as engine:
        fixture_hello(engine)
        before = row_projection(engine.request('rows/subscribe'))
        ids = [r['id'] for r in before['rows']]
        require('codex' in ids and 'claude' in ids and len(ids) == len(set(ids)), 'missing-production-rows')
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
                'proofScope': 'production U2 with recording history provider',
                'wireMessages': engine.messages, 'cleanup': 'exited'}


def empty_states(binary, home, fault_binary):
    from shape_home import build_home
    from contracts import ROOT, load_json
    observations, messages, bindings = [], [], []
    for empty in ('readers_off', 'pending', 'no_consent', 'empty'):
        case = Path(home) / empty
        build_home(load_json(ROOT / 'examples/synthetic-shape.json'), case)
        if empty == 'pending':
            fixture_input(case, 'omitted', empty)
        if empty == 'no_consent':
            cli(binary, case, ['consent', 'init', '--json'])
            tighten(binary, case, deny=['codex.local_history', 'codex.runtime_usage', 'claude.local_history'])
        engine = EngineProcess(fault_binary if empty == 'pending' else binary, case, 'u14-empty-' + empty)
        if empty == 'readers_off':
            engine.environment['MODELPLAN_READERS'] = 'off'
        with engine:
            fixture_hello(engine)
            projection = row_projection(engine.request('rows/subscribe'))
            require(projection['rowsSummary']['state'] == empty, 'wrong-empty-summary-' + empty)
            require(bool(projection['rowsSummary']['text']['en']) and bool(projection['rowsSummary']['text']['zh']), 'empty-summary-without-text')
            if empty in ('readers_off', 'pending'):
                require(all(not row['accounts'] for row in projection['rows']), 'private-values-in-off-or-pending-state')
            observations.append(empty)
            bindings.append({'state': empty, 'binaryRole': 'fixture' if empty == 'pending' else 'plain'})
            engine.shutdown()
            messages.extend(engine.messages)
    return {'outcome': 'pass', 'states': observations, 'cases': bindings, 'wireMessages': messages,
            'proofScope': 'production U2; repeated-revoke fault only for pending', 'cleanup': 'exited'}


def _await_completed(home):
    import time
    from engine_process import EngineTimeout
    deadline = time.monotonic() + 3
    while events(home).count('query-completed') < 2:
        if time.monotonic() >= deadline:
            raise EngineTimeout('two-queries-did-not-complete')
        time.sleep(.01)


def backpressure(binary, home):
    import fcntl, os, time
    from shape_home import build_home
    from contracts import ROOT, load_json
    messages, elapsed = [], 0
    # Draining after a short pause proves health traversed the transport's
    # priority control queue. A separate run stops reading until the real timeout.
    for probe in (True, False):
        case = Path(home) / ('health-priority' if probe else 'timeout')
        build_home(load_json(ROOT / 'examples/synthetic-shape.json'), case)
        fixture_input(case, pressure=True)
        with EngineProcess(binary, case, 'u14-pressure-' + str(probe)) as engine:
            hello = fixture_hello(engine)
            revoke = decision(case, deny=['codex.local_history'])
            started = time.monotonic()
            for id in (10, 11):
                engine.send(id, 'history/query', {'kind': 'tokens', 'tool': 'codex', 'limit': 1})
            _await_completed(case)
            engine._bytes_ready(3)
            engine.buffer.extend(os.read(engine.process.stdout.fileno(), 1))
            with (case / '.config/modelplan/consent.json.readers.lock').open('a') as lock:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                engine.send(12, 'consent/grant', revoke)
                deadline = time.monotonic() + 3
                while state(case)['generation'] == hello['consentGeneration']:
                    require(time.monotonic() < deadline, 'revoke-stalled-behind-data')
                    time.sleep(.01)
                # Wait while stdout remains stopped: both completions and the
                # durable transaction precede the health/control observation.
                time.sleep(.4)
                if probe:
                    health = engine._find(lambda m: m.get('method') == 'engine/health' and m['params']['data']['code'] == 'cleanup_pending', 3)
                    require(health['params']['consentGeneration'] > hello['consentGeneration'], 'stale-health-context')
                    receipt = engine.response(12)
                    require(receipt['result']['data']['committed'], 'pressure-revoke-not-committed')
                    engine.shutdown()
                else:
                    require(engine.wait(13) == 0, 'pressure-process-failed')
                    elapsed = time.monotonic() - started
                    require(9 <= elapsed < 13, 'production-write-timeout-not-observed')
            messages.extend(engine.messages)
        require(events(case).count('query-completed') == 2, 'query-completion-count')
        with EngineProcess(binary, case, 'u14-pressure-restart-' + str(probe)) as restart:
            hello = fixture_hello(restart)
            receipt = restart.request('consent/grant', revoke)
            require('error' not in receipt and receipt['result']['data']['committed'], 'lost-receipt-not-replayed')
            require(receipt['result']['consentGeneration'] == hello['consentGeneration'], 'replayed-receipt-floor')
            projection = fresh_rows(restart)
            require(all(not row['accounts'] for row in projection['rows'] if row['id'] == 'codex'), 'revoked-values-after-restart')
            restart.shutdown(); messages.extend(restart.messages)
    return {'outcome': 'pass', 'completedQueries': 2, 'revokeCommitted': True, 'healthChanged': True,
            'healthControlObserved': True, 'receiptReplayed': True, 'stdoutPaused': True,
            'elapsedSeconds': round(elapsed, 3), 'u2PersistenceProof': True,
            'proofScope': 'production U2 receipts and transport; recording history provider', 'wireMessages': messages, 'cleanup': 'exited'}


ADMISSION_COMPONENTS = ('U2a-post-veto', 'U2a-minimax-auth-stop', 'U2a-minimax-legacy-control',
                        'U2a-local-history-gemini', 'U2a-local-history-cursor',
                        'U3b-refresh-shared-budget')


def evaluate_admission(observation):
    """Qualify measured subchecks; a missing typed producer cannot pass."""
    require(observation.get('sharedSyntheticHome') is True, 'admission-home-not-shared')
    require(observation.get('unexpectedCalls') == 0, 'unlisted-provider-called')
    for provider in ('gemini', 'cursor'):
        item = observation['postScopes'][provider]
        require(item['calls'] == 0 and item['disabledReason'] == 'policy_pending', 'unapproved-post-admitted')
        require(item['syntheticLoginPresent'] is True, 'post-zero-calls-without-valid-login')
    require('gemini' in observation['localHistory'] and 'cursor' in observation['localHistory'], 'history-evidence-missing')
    for provider in ('gemini', 'cursor'):
        history = observation['localHistory'][provider]
        require(history.get('outcome') != 'unsupported', 'supported-history-not-executed')
        require(history['before'] > 0 and history['after'] == history['before'], 'local-history-lost')
        require(len(history['beforeSha256']) == 64 and history['afterSha256'] == history['beforeSha256'],
                'local-history-values-changed')
    control = observation['legacyControl']
    require(control['calls'] == 2 and control['statuses'] == [404, 200] and control['readingAvailable'],
            'legacy-positive-control-failed')
    for status in ('401', '403'):
        item = observation['minimax'][status]
        require(item['calls'] == 1 and item['statuses'] == [int(status)] and
                item['legacyReplyAvailable'] is True and item['legacyCalls'] == 0,
                'minimax-retried-after-auth-failure')
        require(item['budgetBeforeSha256'] == item['budgetAfterSha256'], 'independent-cli-reset-budget')
    from datetime import datetime
    budgets = observation['sharedRefreshBudget']
    require(set(budgets) == {'404', '401', '403'}, 'shared-budget-case-missing')
    for budget in budgets.values():
        before, after = budget['beforeCli'], budget['afterCli']
        require(before.get('disabledReason') == after.get('disabledReason') == 'cooldown' and
                before['scope'] == after['scope'] == 'minimax.account_usage.api_key' and
                before['at'] == after['at'], 'shared-budget-deferral-changed')
        require(datetime.fromisoformat(before['at'].replace('Z', '+00:00')) >=
                datetime.fromisoformat(budget['nextAttemptAt'].replace('Z', '+00:00')),
                'shared-budget-deadline-bypassed')
        require(budget['budgetBeforeSha256'] == budget['budgetAfterSha256'] and
                budget['requestsBefore'] > 0 and budget['requestsBefore'] == budget['requestsAfter'],
                'independent-cli-reset-budget')
    components = {
        'U2a-post-veto': {'outcome': 'pass', 'providers': observation['postScopes']},
        'U2a-minimax-auth-stop': {'outcome': 'pass', 'cases': observation['minimax']},
        'U2a-minimax-legacy-control': {'outcome': 'pass', **control},
        'U2a-local-history-gemini': {'outcome': 'pass', **observation['localHistory']['gemini']},
        'U2a-local-history-cursor': {'outcome': 'pass', **observation['localHistory']['cursor']},
        'U3b-refresh-shared-budget': {'outcome': 'pass', 'cases': budgets},
    }
    return {'outcome': 'pass',
            'subscenarios': components, 'proofScope': 'production constructor and guarded readers; recording HTTP provider'}


def _http_events(home):
    from contracts import load_json
    import json
    path = Path(home) / '.u14-http-events.jsonl'
    if not path.exists():
        return []
    data = regular_bytes(path)
    require(len(data) < 64 << 10 and (not data or data.endswith(b'\n')), 'http-trace-incomplete-or-oversized')
    return [json.loads(line) for line in data.splitlines()]


def _history_items(engine, tool, wait=False):
    import time
    deadline = time.monotonic() + 5
    while True:
        result = engine.request('history/query', {'kind': 'tokens', 'tool': tool, 'limit': 10})
        if 'result' in result and (result['result']['data']['items'] or not wait):
            return result['result']['data']['items']
        if not wait:
            return result
        require(time.monotonic() < deadline, 'local-history-not-readable')
        time.sleep(.02)


def _seed_post_logins(home):
    import base64, platform, sqlite3
    from contracts import encoded, write_private
    canary = 'U14-SYNTHETIC-GEMINI-ACCESS'
    gemini = Path(home) / '.gemini/oauth_creds.json'
    write_private(gemini, encoded({'access_token': canary, 'expiry_date': 4070908800000}))
    root = Path(home) / ('Library/Application Support' if platform.system() == 'Darwin' else '.config')
    cursor = root / 'Cursor/User/globalStorage/state.vscdb'
    cursor.parent.mkdir(mode=0o700, parents=True)
    payload = base64.urlsafe_b64encode(encoded({'sub': 'auth|synthetic-u14-account', 'exp': 4070908800})).rstrip(b'=').decode()
    token = 'e30.' + payload + '.synthetic-signature'
    with sqlite3.connect(cursor) as database:
        database.execute('CREATE TABLE ItemTable (key TEXT PRIMARY KEY, value)')
        database.execute('INSERT INTO ItemTable VALUES (?, ?)', ('cursorAuth/accessToken', token))
    cursor.chmod(0o600)
    return {'gemini': {'path': gemini, 'sha256': digest(regular_bytes(gemini))},
            'cursor': {'path': cursor, 'sha256': digest(regular_bytes(cursor))}}, (canary, token)


def _wait_native_capture(home, status):
    import json, time
    path = Path(home) / '.cache/modelplan/observed/native.json'
    deadline = time.monotonic() + 5
    while True:
        if path.exists():
            capture = json.loads(regular_bytes(path))
            for provider in capture.get('providers', []):
                if provider.get('provider') == 'minimax' and provider.get('status') == ('ok' if status == 404 else 'error'):
                    return
        require(time.monotonic() < deadline, 'minimax-capture-not-committed')
        time.sleep(.01)


def admission(binary, home, plan):
    from datetime import datetime, timezone
    from shape_home import build_home
    from contracts import ROOT, load_json, encoded, write_private
    observations = {'sharedSyntheticHome': True, 'unexpectedCalls': 0, 'postScopes': {},
                    'localHistory': {}, 'minimax': {}, 'sharedRefreshBudget': {}, 'cases': []}
    messages = []
    for status in (404, 401, 403):
        case = Path(home) / str(status)
        shape = load_json(ROOT / 'examples/synthetic-shape.json')
        shape['files'] = [entry for entry in shape['files'] if entry['path'] != '.config/modelplan/connections.json']
        baseline = build_home(shape, case)
        fixture_input(case, minimaxStatus=status)
        current = state(case)
        for tool in ('gemini', 'cursor', 'minimax'):
            current['tools'][tool] = {'allowed': True, 'readerId': 'native:' + tool, 'backend': 'native',
                                      'consentTextVersion': 2, 'at': '2000-01-01T00:00:00Z'}
        current['tools']['minimax'].update(region='international', keyEnv='MINIMAX_CODING_API_KEY')
        (case / '.config/modelplan/consent.json').unlink()
        write_private(case / '.config/modelplan/consent.json', encoded(current))
        (case / '.cursor').mkdir(mode=0o700)
        credentials, canaries = _seed_post_logins(case)
        stamp = datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z')
        for i in range(2):
            path = case / f'.gemini/tmp/project/chats/session-synthetic-{i}.json'
            path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
            write_private(path, encoded({'sessionId': f'synthetic-{i}', 'messages': [
                {'id': f'synthetic-{i}', 'type': 'gemini', 'timestamp': stamp,
                 'model': f'synthetic-model-{i}', 'tokens': {'input': 10, 'output': 2, 'total': 12}}]}))
        cursor_export = case / '.cursor/token-usage/usage.jsonl'
        cursor_export.parent.mkdir(mode=0o700)
        write_private(cursor_export, b''.join(encoded({'event': 'stop', 'ts': stamp,
            'conversation_id': 'synthetic-u14-cursor', 'generation_id': f'turn-{i}',
            'model': f'synthetic-cursor-{i}', 'tokens_present': True, 'total_tokens': 12 + i
        }).replace(b'\n', b'') + b'\n' for i in range(2)))
        cursor_export_sha = digest(regular_bytes(cursor_export))
        cli(binary, case, ['usage', 'gemini', 'enable', '--json'])
        cli(binary, case, ['consent', 'init', '--json'])
        cli(binary, case, ['consent', 'grant', '--json'], decision(case, allow=['cursor.local_history']))
        engine = EngineProcess(binary, case, 'u14-admission-' + str(status))
        engine.environment['MINIMAX_CODING_API_KEY'] = 'U14-SYNTHETIC-MINIMAX-KEY'
        with engine:
            hello = engine.initialize()
            require(hello['storeEpoch'] not in ('unavailable', 'u14-fixture-epoch'), 'admission-used-fake-consent-backend')
            external = cli(binary, case, ['consent', '--json'])
            require(external['storeEpoch'] == hello['storeEpoch'], 'independent-cli-not-sharing-store')
            facts = engine.request('consent/get')['result']['data']['scopes']
            for tool in ('gemini', 'cursor'):
                fact = next(item for item in facts if item['scope'] == tool + '.account_usage.saved_login')
                require(fact['state'] == 'allowed' and fact.get('disabledReason') == 'policy_pending', 'policy-pending-not-authoritative')
                rejected = engine.request('consent/grant', decision(case, allow=[fact['scope']]))
                require(rejected.get('error', {}).get('code') == -32021, 'unapproved-post-grant-accepted')
                observations['postScopes'].setdefault(tool, {'calls': 0, 'disabledReason': fact['disabledReason'], 'syntheticLoginPresent': True})
            local = engine.request('refresh/request', {'scopes': plan['localScopes']})
            require('error' not in local and len(local['result']['data']) == 2 and
                    all('disabledReason' not in item for item in local['result']['data']),
                    'production-local-dispatcher-not-linked')
            before = {}
            for tool, tokens in (('gemini', 24), ('cursor', 25)):
                before[tool] = _history_items(engine, tool, wait=True)
                require(len(before[tool]) == 2 and sum(item['tokens'] for item in before[tool]) == tokens,
                        tool + '-history-seed-not-readable')
            remote = engine.request('refresh/request', {'scopes': plan['accountScopes']})
            require('error' not in remote and all(item.get('disabledReason') for item in remote['result']['data']), 'policy-pending-refresh-accepted')
            scheduled = engine.request('refresh/request', {'scopes': ['minimax.account_usage.api_key']})
            require('error' not in scheduled and all('disabledReason' not in item for item in scheduled['result']['data']), 'production-minimax-dispatcher-not-linked')
            _wait_native_capture(case, status)
            budget = case / '.cache/modelplan/observed/reader-attempts/minimax.json'
            budget_before = digest(regular_bytes(budget))
            requests_before = len([item for item in _http_events(case) if item['provider'] == 'minimax'])
            deferred_before = engine.request('refresh/request', {'scopes': ['minimax.account_usage.api_key']})
            require('error' not in deferred_before and len(deferred_before['result']['data']) == 1,
                    'shared-budget-deferral-missing')
            cli(binary, case, ['connections', 'refresh', '--quiet'], environment=engine.environment)
            deferred_after = engine.request('refresh/request', {'scopes': ['minimax.account_usage.api_key']})
            require('error' not in deferred_after and len(deferred_after['result']['data']) == 1,
                    'shared-budget-deferral-missing')
            trace = _http_events(case)
            mini = [item for item in trace if item['provider'] == 'minimax']
            observations['sharedRefreshBudget'][str(status)] = {
                'beforeCli': deferred_before['result']['data'][0], 'afterCli': deferred_after['result']['data'][0],
                'nextAttemptAt': load_json(budget)['nextAttemptAt'],
                'budgetBeforeSha256': budget_before, 'budgetAfterSha256': digest(regular_bytes(budget)),
                'requestsBefore': requests_before, 'requestsAfter': len(mini)}
            require(all(item['method'] == 'GET' and item['host'] == 'api.minimax.io' and item['credentialMatched'] for item in mini), 'unexpected-minimax-request')
            observations['unexpectedCalls'] += sum(item['provider'] not in ('minimax', 'gemini', 'cursor') for item in trace)
            for tool in ('gemini', 'cursor'):
                observations['postScopes'][tool]['calls'] += sum(item['provider'] == tool for item in trace)
                require(digest(regular_bytes(credentials[tool]['path'])) == credentials[tool]['sha256'], 'tool-login-file-changed')
            local_history = {}
            for tool in ('gemini', 'cursor'):
                after = _history_items(engine, tool, wait=True)
                local_history[tool] = {'before': len(before[tool]), 'after': len(after),
                    'beforeTokens': sum(item['tokens'] for item in before[tool]),
                    'afterTokens': sum(item['tokens'] for item in after),
                    'beforeSha256': digest(encoded(before[tool])), 'afterSha256': digest(encoded(after))}
                require(local_history[tool]['beforeSha256'] == local_history[tool]['afterSha256'],
                        'local-history-values-changed')
                observations['localHistory'][tool] = local_history[tool]
            require(digest(regular_bytes(cursor_export)) == cursor_export_sha, 'cursor-export-changed')
            if status == 404:
                rows = fresh_rows(engine)
                reading = any(row['id'] == 'minimax' and any(window.get('remainingPercent') == 75
                              for account in row['accounts'] for window in account['windows']) for row in rows['rows'])
                observations['legacyControl'] = {'calls': len(mini), 'statuses': [item['status'] for item in mini],
                                                 'readingAvailable': reading}
            else:
                observations['minimax'][str(status)] = {'calls': len(mini), 'statuses': [item['status'] for item in mini],
                    'legacyReplyAvailable': observations['legacyControl']['readingAvailable'],
                    'legacyCalls': sum(item['event'] == 'minimax-legacy' for item in mini),
                    'budgetBeforeSha256': budget_before, 'budgetAfterSha256': digest(regular_bytes(budget))}
            require(all(canary not in str(engine.messages) for canary in (*canaries, 'U14-SYNTHETIC-MINIMAX-KEY')), 'synthetic-credential-reflected')
            for directory in (case / '.cache/modelplan', case / '.config/modelplan'):
                for file in directory.rglob('*'):
                    if file.is_file():
                        retained = regular_bytes(file)
                        require(all(canary.encode() not in retained for canary in (*canaries, 'U14-SYNTHETIC-MINIMAX-KEY')),
                                'synthetic-credential-copied-to-engine-storage')
            verify_baseline(case, baseline, mutable=('.config/modelplan/consent.json',))
            observations['cases'].append({'status': status, 'shapeSha256': baseline['shapeSha256'],
                'storeEpoch': hello['storeEpoch'], 'httpTraceSha256': digest(encoded(trace)), 'requests': trace,
                'localHistory': local_history, 'credentialInputsUnchanged': True, 'credentialCanariesAbsentFromEngineStorage': True})
            engine.shutdown()
            messages.extend(engine.messages)
    result = evaluate_admission(observations)
    return {**result, 'productionU2Executed': True, 'productionConstructorUnchanged': True,
            'testedLevel': 'L1 engine-only', 'L2DeviceOutcome': 'not-run',
            'observations': observations, 'wireMessages': messages, 'cleanup': 'exited'}


def shared_state(binary, home):
    fixture_input(home)
    with EngineProcess(binary, home, 'u14-shared-state') as engine:
        hello = fixture_hello(engine)
        from contracts import encoded, write_private
        from datetime import datetime, timezone
        allowed_runtime = engine.request('consent/grant', decision(home, allow=['codex.runtime_usage']))
        require(allowed_runtime.get('result', {}).get('data', {}).get('committed'), 'runtime-grant-failed')
        captured = state(home)
        observed = datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z')
        cache = Path(home) / '.cache/modelplan/observed/codex-account.json'
        cache.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        write_private(cache, encoded({'schemaVersion': 1, 'status': 'ok', 'observedAt': observed,
                                     'admission': {'storeEpoch': captured['storeEpoch'], 'generation': captured['generation'], 'scope': 'codex.runtime_usage'},
                                     'windows': [{'kind': 'five_hour', 'observedAt': observed, 'usedPercent': 25}]}))
        before = row_projection(engine.request('rows/subscribe'))
        page = engine.request('history/query', {'kind': 'tokens', 'tool': 'codex', 'limit': 1})
        require('error' not in page, 'initial-history-unavailable')
        cursor = page['result']['data']['nextCursor']
        failure = engine.request('history/query', {'kind': 'sessions', 'tool': 'codex', 'limit': 1})
        require(failure.get('error', {}).get('code') == -32050, 'query-error-not-isolated')
        require(row_projection(engine.request('rows/subscribe')) == before, 'failed-query-changed-rows')
        require(any(row['id'] == 'codex' and any(account['route'] == 'runtime_rpc' and account['windows'] for account in row['accounts']) for row in before['rows']), 'positive-runtime-reading-not-projected')
        stale = decision(home, deny=['codex.local_history', 'codex.runtime_usage'])
        receipt = tighten(binary, home, deny=['codex.local_history', 'codex.runtime_usage'])
        changed = engine._find(lambda m: m.get('method') == 'consent/changed' and
                               m['params']['consentGeneration'] == receipt['committedGeneration'])
        require(changed['params']['storeEpoch'] == hello['storeEpoch'], 'external-revoke-epoch')
        stale_error = engine.request('consent/grant', stale)
        context = stale_error['error']['data']
        require(stale_error['error']['code'] == -32020 and context['consentGeneration'] == receipt['committedGeneration'], 'rejection-context-not-authoritative')
        denied = engine.request('history/query', {'kind': 'tokens', 'tool': 'codex', 'cursor': cursor, 'limit': 1})
        require('error' in denied, 'cursor-survived-revoke')
        after = row_projection(engine.request('rows/subscribe'))
        require(all(not r['accounts'] for r in after['rows'] if r['id'] == 'codex'), 'stale-values-after-revoke')
        reset = cli(binary, home, ['consent', 'reset', 'confirmed', '--json'])
        require(reset['storeEpoch'] != hello['storeEpoch'], 'reset-reused-epoch')
        engine._find(lambda m: m.get('method') == 'consent/changed' and m['params']['storeEpoch'] == reset['storeEpoch'])
        allowed = cli(binary, home, ['consent', 'grant', '--json'], decision(home, allow=['codex.local_history']))
        require(allowed['committed'], 'regrant-after-reset-failed')
        engine._find(lambda m: m.get('method') == 'consent/changed' and m['params']['consentGeneration'] == allowed['committedGeneration'] and m['params']['storeEpoch'] == reset['storeEpoch'])
        old_cursor = engine.request('history/query', {'kind': 'tokens', 'tool': 'codex', 'cursor': cursor, 'limit': 1})
        require(old_cursor.get('error', {}).get('code') == -32051, 'cursor-not-bound-to-epoch')
        page = engine.request('history/query', {'kind': 'tokens', 'tool': 'codex', 'limit': 1})
        require('error' not in page and page['result']['storeEpoch'] == reset['storeEpoch'], 'new-epoch-history-failed')
        cursor = page['result']['data']['nextCursor']
        engine.shutdown(); messages = list(engine.messages)
    with EngineProcess(binary, home, 'u14-other-session') as engine:
        engine.initialize()
        old_cursor = engine.request('history/query', {'kind': 'tokens', 'tool': 'codex', 'cursor': cursor, 'limit': 1})
        require(old_cursor.get('error', {}).get('code') == -32051, 'cursor-not-bound-to-session')
        engine.shutdown(); messages.extend(engine.messages)
    # Two held query slots reject the third promptly, while cancellation stays
    # on the control lane and yields a terminal response for each canceled ID.
    from contracts import encoded, write_private
    fixture_input(home, block=True)
    with EngineProcess(binary, home, 'u14-query-cap') as engine:
        import time
        engine.initialize()
        for id in (30, 31):
            engine.send(id, 'history/query', {'kind': 'tokens', 'tool': 'codex', 'limit': 1})
        deadline = time.monotonic() + 3
        while events(home).count('query-started') < 2:
            require(time.monotonic() < deadline, 'query-slots-not-held'); time.sleep(.01)
        third = engine.request('history/query', {'kind': 'tokens', 'tool': 'codex', 'limit': 1})
        require(third.get('error', {}).get('code') == -32013, 'query-cap-not-busy')
        for id in (30, 31):
            engine.send(None, '$/cancel', {'id': id})
            require(engine.response(id).get('error', {}).get('code') == -32800, 'query-cancel-not-terminal')
        engine.send(32, 'history/query', {'kind': 'tokens', 'tool': 'codex', 'limit': 1})
        deadline = time.monotonic() + 3
        while events(home).count('query-started') < 3:
            require(time.monotonic() < deadline, 'late-query-not-started'); time.sleep(.01)
        receipt = tighten(binary, home, deny=['codex.local_history'])
        engine._find(lambda m: m.get('method') == 'consent/changed' and m['params']['consentGeneration'] == receipt['committedGeneration'])
        write_private(Path(home) / '.u14-release', b'')
        rejected = engine.response(32)
        require(rejected.get('error', {}).get('code') == -32023, 'late-query-escaped-real-publication-fence')
        engine.shutdown(); messages.extend(engine.messages)
    off = EngineProcess(binary, home, 'u14-tighten-off')
    off.environment['MODELPLAN_READERS'] = 'off'
    with off:
        off.initialize()
        for action, scope in [('deny', 'retired.runtime_usage'), ('forget', 'retired.runtime_usage')]:
            receipt = off.request('consent/grant', decision(home, **{action: [scope]}))
            require(receipt.get('result', {}).get('data', {}).get('committed'), 'tightening-refused-with-readers-off')
        projection = row_projection(off.request('rows/subscribe'))
        require(projection['rowsSummary']['state'] == 'readers_off', 'readers-off-not-retained')
        off.shutdown(); messages.extend(off.messages)
    return {'outcome': 'pass', 'externalCLIRevoke': True, 'authoritativeRejectionContext': True,
            'resetAcrossEpochs': True, 'positiveRuntimeReadingRevoked': True, 'queryCapAndCancellation': True, 'cursorBindings': ['epoch', 'session', 'scope'],
            'tighteningWithReadersOff': ['deny', 'forget'], 'wireMessages': messages,
            'proofScope': 'production shared store and transport; recording history provider', 'cleanup': 'exited'}
