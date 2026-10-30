# SPDX-License-Identifier: MIT
"""Scenario assertions only: ordinary CLI subject, fixed synthetic provider runtime."""
import concurrent.futures
import fcntl
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import time

U14 = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(U14))
from engine_process import EngineFailure, EngineProcess
from engine_runner import fresh_rows, require
from shape_home import build_home

_spec = importlib.util.spec_from_file_location('consent_fixture', U14.parents[1] / 'scripts/test-consent-engine.py')
fixture = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(fixture)

IDS = ['U2-empty-credentials-isolation', 'U2-migration', 'U2-revoke-in-flight', 'U2-reset-old-allow', 'U2-two-writers',
       'U2-completed-regrant', 'U2-completed-reset', 'U2-retired-deny', 'U2-retired-forget',
       'U2-old-writer-v0.5.46', 'U2-old-writer-v0.5.47',
       'U3-protocol', 'U3-major-mismatch', 'U3-eof', 'U3-shared-revoke-receipt', 'U3-backpressure-receipt']


class Home(fixture.Home):
    def __init__(self, root, binary, proxy, shape):
        baseline = build_home(shape, root)
        # Parent records the baseline. Only the fixed provider stub and scenario
        # mutations below change it; no account/profile is imported.
        self.baseline = baseline
        self.root, self.cli = root, binary
        (root / 'bin').mkdir(mode=0o700, exist_ok=True)
        (root / '.copilot').mkdir(mode=0o700, exist_ok=True)
        (root / '.u14-tmp').mkdir(mode=0o700, exist_ok=True)
        fake = root / 'bin/copilot'
        fake.write_text(fixture.FAKE_RUNTIME.replace('PYTHON', sys.executable, 1))
        fake.chmod(0o700)
        # Presence stays synthetic; any attempted Claude vendor execution is
        # recorded locally and rejected by every scenario's isolation assertion.
        claude = root / 'bin/claude'
        claude.write_text('#!/bin/sh\nprintf claude >> "$HOME/.u14-claude-calls"\nexit 69\n')
        claude.chmod(0o700)
        self.env = {'HOME': str(root), 'PATH': str(root / 'bin') + ':/usr/bin:/bin',
                    'TMPDIR': str(root / '.u14-tmp'), 'MODELPLAN_CACHE': str(root / 'cache'),
                    'MODELPLAN_COPILOT': str(fake), 'MODELPLAN_BASE': 'http://127.0.0.1:1',
                    'MODELPLAN_HISTORY': 'off', 'MODELPLAN_CODEX_ACCOUNT': 'off',
                    'MODELPLAN_CODEXBAR': 'off', 'MODELPLAN_TASK_BRIEF': 'off',
                    'NO_COLOR': '1', 'LANG': 'C', 'HTTP_PROXY': proxy, 'HTTPS_PROXY': proxy,
                    'NO_PROXY': '127.0.0.1,localhost'}
        self.store = root / '.config/modelplan/consent.json'
        # The structural builder intentionally emits scalar placeholders. This
        # declared scenario overlay supplies the parseable empty connections v1.
        connections = root / '.config/modelplan/connections.json'
        connections.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        connections.write_text(json.dumps(dict(schemaVersion=1, connections=[])))
        self.v1 = self.store.read_bytes() if self.store.exists() else None
        self.run(['consent', 'init', '--json'], check=True)

    def request(self, **decisions):
        return super().request(**{'allow': [], 'deny': [], **decisions})

    def refresh(self):
        return self.run(['connections', 'refresh', '--quiet'])

    def empty(self, absent=False):
        report = self.run(['quota', '--json', '--offline'], check=True)
        require(not json.loads(report.stdout)['accounts'], 'retired-private-reading-visible')
        if absent:
            require(not (self.root / 'cache/observed/native.json').exists(), 'retired-capture-published')

    def engine(self, session):
        engine = EngineProcess(self.cli, self.root, session)
        engine.environment.update(self.env)
        return engine


def transcript(engine):
    # No raw diagnostics, environment, local paths or arbitrary RPC data exported.
    result = []
    for message in engine.messages:
        envelope = message.get('result', message.get('params', message.get('error', {}).get('data', {})))
        record = dict(method=message.get('method'), id=message.get('id'),
                      code=message.get('error', {}).get('code'),
                      sha256=hashlib.sha256(json.dumps(message, sort_keys=True).encode()).hexdigest())
        for key in ('sessionId', 'storeEpoch', 'consentGeneration'):
            if key in envelope:
                record[key] = envelope[key]
        data = envelope.get('data', {})
        if isinstance(data, dict) and 'sequence' in data:
            record['sequence'] = data['sequence']
        result.append(record)
    return result


def run(scenario, h, old=None):
    details = {}
    if scenario == 'U2-empty-credentials-isolation':
        # Even an explicit saved-login grant must not turn the empty placeholder
        # into an authenticated network read, or launch the vendor CLI.
        h.mutate(allow=['claude.account_usage.saved_login'])
        h.refresh()
        report = h.run(['quota', '--json', '--offline'], check=True)
        require(not json.loads(report.stdout)['accounts'], 'empty-credentials-produced-reading')
        details['explicitSavedLoginGrant'] = True
    elif scenario == 'U2-migration':
        require(h.v1 is not None and h.state()['schemaVersion'] == 2, 'migration-not-exercised')
        require((h.store.parent / 'consent.v1.bak').read_bytes() == h.v1, 'migration-backup-not-identical')
        before = h.store.read_bytes()
        h.run(['consent', '--json'], check=True)
        require(h.store.read_bytes() == before, 'migration-not-idempotent')
        details['originalSHA256'] = hashlib.sha256(h.v1).hexdigest()
    elif scenario in ('U2-revoke-in-flight', 'U2-reset-old-allow'):
        h.allow()
        old_epoch = h.state()['storeEpoch']
        old_allow = h.request(allow=['copilot.runtime_usage'])
        (h.root / 'block').touch()
        with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
            reading = pool.submit(h.refresh)
            try:
                fixture.await_file(h.root / 'reading')
                if scenario == 'U2-revoke-in-flight':
                    receipt = h.mutate(deny=['copilot.runtime_usage'])
                    require(receipt['code'] == 'cleanup_pending', 'missing-inflight-cleanup-pending')
                else:
                    require(json.loads(h.run(['consent', 'grant', '--json'], old_allow, check=True).stdout)['committed'], 'old-allow-not-committed')
                    h.store.write_text('damaged synthetic store')
                    reset = json.loads(h.run(['consent', 'reset', 'confirmed', '--json'], check=True).stdout)
                    require(reset['generation'] == 1 and reset['storeEpoch'] != old_epoch, 'reset-not-new-epoch')
                    retry = json.loads(h.run(['consent', 'grant', '--json'], old_allow).stdout)
                    require(retry.get('error') == 'consent_stale', 'old-allow-replayed-after-reset')
            finally:
                (h.root / 'release').touch()
            reading.result(timeout=15)
        h.empty(absent=True)
        details['inflightReadObserved'] = True
    elif scenario == 'U2-two-writers':
        requests = [h.request(deny=[s]) for s in ('claude.account_usage.saved_login', 'retired.old_path')]
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            futures = [pool.submit(h.run, ['consent', 'grant', '--json'], request) for request in requests]
            replies = [json.loads(f.result().stdout) for f in futures]
        require(sum(bool(r.get('committed')) for r in replies) == 1, 'writer-commit-count')
        require(sum(r.get('error') == 'stale_generation' for r in replies) == 1, 'writer-stale-count')
        details.update(commits=1, stale=1)
    elif scenario in ('U2-completed-regrant', 'U2-completed-reset'):
        h.allow(); h.refresh()
        require(len(json.loads(h.run(['quota', '--json', '--offline'], check=True).stdout)['accounts']) == 1, 'missing-positive-capture')
        calls = h.calls()
        require(calls.count('account.getQuota') == 1, 'positive-provider-call-count')
        if scenario.endswith('regrant'):
            with Path(str(h.store) + '.readers.lock').open('a') as lock:
                fcntl.flock(lock, fcntl.LOCK_EX)
                require(h.mutate(deny=['copilot.runtime_usage'])['code'] == 'cleanup_pending', 'cleanup-not-pending')
        else:
            epoch = h.state()['storeEpoch']
            h.store.write_text('damaged synthetic capture store')
            h.run(['consent', 'reset', 'confirmed', '--json'], check=True)
            require(h.state()['storeEpoch'] != epoch, 'reset-reused-epoch')
            h.empty()
        h.allow(); h.empty(); h.refresh()
        require(h.calls() == calls, 'grant-reset-bypassed-shared-budget')
        details.update(positiveCapture=True, retiredCaptureHidden=True, budgetRetained=True)
    elif scenario.startswith('U2-retired-'):
        action = scenario.rsplit('-', 1)[1]
        scope = 'retired-tool.account_usage.saved_login'
        state = h.state()
        state['scopes'][scope] = dict(allowed=True, consentTextVersion=2)
        h.store.write_text(json.dumps(state))
        readers = h.root / 'cache/observed/readers'
        readers.mkdir(parents=True, exist_ok=True)
        retained = readers / 'retired-tool.json'
        retained.write_text(json.dumps(dict(schemaVersion=1, provider='retired-tool',
            nextAttemptAt='2099-01-01T00:00:00Z', entries=[dict(status='ok', profileKey='synthetic',
            account=dict(source='retired-tool', windows=[]))])))
        h.env['MODELPLAN_READERS'] = 'off'
        h.mutate(**{action: [scope]})
        require(not retained.exists() and not h.state()['scopes'][scope]['allowed'], 'retired-scope-not-cleared')
        require(not h.calls(), 'cleanup-started-runtime')
    elif scenario.startswith('U2-old-writer-'):
        require(old is not None, 'old-release-required')
        version, binary = old
        reported = h.run(['version'], binary=binary, check=True).stdout.strip()
        require(reported.endswith(version.lstrip('v')), 'old-version-mismatch')
        h.allow(); h.refresh()
        require('account.getQuota' in h.calls(), 'old-writer-positive-control-missing')
        h.mutate(deny=['copilot.runtime_usage'])
        store, observed, calls = h.store.read_bytes(), h.observed(), h.calls()
        proxy_calls = len(fixture.Trap.calls)
        legacy = dict(requestId='synthetic-old-writer', expectGeneration=h.state()['generation'],
                      consentTextVersion=2, allow=['copilot'], deny=[], keychain={})
        commands = [(['consent', 'grant', '--json'], legacy), (['connect', 'copilot'], 'y\n'),
                    (['connections', 'refresh', '--quiet'], None), (['quota', '--refresh-account', '--json'], None),
                    (['disconnect', 'copilot', '--json'], None)]
        exits = []
        for command, payload in commands:
            result = h.run(command, payload, binary=binary)
            exits.append(result.returncode)
            if command[0] in ('consent', 'connect', 'disconnect'):
                require(result.returncode == 1, 'old-writer-did-not-refuse')
            require(h.store.read_bytes() == store and h.observed() == observed, 'old-writer-mutated-state')
            require(h.calls() == calls and len(fixture.Trap.calls) == proxy_calls, 'old-writer-called-provider')
            h.empty()
        details.update(commands=[c for c, _ in commands], exits=exits, providerCalls=0)
    elif scenario == 'U3-protocol':
        with h.engine('drive-protocol') as engine:
            hello = engine.initialize()
            require({'rows', 'consent', 'diagnostics', 'credentials', 'history', 'refresh', 'publication'} <= set(hello['data']['capabilities']), 'production-handler-missing')
            require(hello['storeEpoch'] == h.state()['storeEpoch'], 'engine-cli-epoch-mismatch')
            projection = fresh_rows(engine)
            ids = [r['id'] for r in projection['rows']]
            require(len(ids) == len(set(ids)), 'duplicate-stable-row-id')
            detected = json.loads(h.run(['detect', '--json'], check=True).stdout)
            expected = {t['providerId'] for t in detected['tools'] if t['detected']} | set(h.state()['tools'])
            require(set(ids) == expected, 'row-membership-mismatch')
            require(all(projection['rowsSummary']['text'].get(lang) for lang in ('en', 'zh')), 'summary-guidance-missing')
            require(all(not r['accounts'] for r in projection['rows']), 'unexpected-private-account')
            require('result' in engine.request('diagnostics/get'), 'diagnostics-failed')
            rejected = engine.request('diagnostics/get', {'accessToken': 'ENGINE-DRIVE-CANARY'})
            require(rejected.get('error', {}).get('code') == -32602, 'token-on-wrong-method-accepted')
            rejected = engine.request('credentials/result', {'operationId': 'unknown', 'outcome': 'ok', 'accessToken': 'ENGINE-DRIVE-CANARY'})
            require(rejected.get('error', {}).get('code') == -32030, 'unknown-credential-result-accepted')
            require('ENGINE-DRIVE-CANARY' not in str(engine.messages), 'token-canary-reflected')
            engine.shutdown()
            details.update(rowIds=ids, serverVersion=hello['data']['serverVersion'], rpc=transcript(engine))
    elif scenario == 'U3-major-mismatch':
        with h.engine('drive-mismatch') as engine:
            engine.send(1, 'initialize', dict(sessionId=engine.session, protocolVersion='2.0', appVersion='synthetic', capabilities=[]))
            reply = engine.response(1)
            require(reply.get('error', {}).get('code') == -32010, 'major-mismatch-not-rejected')
            engine.wait(3)
            details['rpc'] = transcript(engine)
    elif scenario == 'U3-eof':
        with h.engine('drive-eof') as engine:
            engine.initialize()
            engine.process.stdin.close()
            require(engine.wait(3) == 0, 'eof-not-graceful')
            details['rpc'] = transcript(engine)
    elif scenario == 'U3-shared-revoke-receipt':
        h.allow(); h.refresh()
        require('account.getQuota' in h.calls(), 'positive-runtime-read-missing')
        with h.engine('drive-shared') as engine:
            engine.initialize()
            before = fresh_rows(engine)
            require(any(r['id'] == 'copilot' and r['accounts'] for r in before['rows']), 'positive-runtime-row-missing')
            stale = h.request(deny=['copilot.runtime_usage'])
            receipt = h.mutate(deny=['copilot.runtime_usage'])
            engine._find(lambda m: m.get('method') == 'consent/changed' and m['params']['consentGeneration'] == receipt['committedGeneration'])
            rejected = engine.request('consent/grant', stale)
            require(rejected.get('error', {}).get('code') == -32020, 'stale-request-not-rejected')
            require(rejected['error']['data']['consentGeneration'] == receipt['committedGeneration'], 'error-context-not-current')
            require(all(not r['accounts'] for r in fresh_rows(engine)['rows'] if r['id'] == 'copilot'), 'revoked-reading-projected')
            request = h.request(forget=['copilot.runtime_usage'])
            engine.send(90, 'consent/grant', request)
            committed = engine.response(90)['result']['data']
            require(committed['committed'], 'forget-not-committed')
            engine.shutdown()
            details['rpc'] = transcript(engine)
        h.mutate(deny=['retired.old_path'])
        current = h.state()
        before_replay = h.store.read_bytes()
        with h.engine('drive-replay') as engine:
            engine.initialize()
            response = engine.request('consent/grant', request)['result']
            replay = response['data']
            require(engine.floor == current['generation'], 'historical-receipt-lowered-current-floor')
            require(h.store.read_bytes() == before_replay, 'historical-receipt-mutated-store')
            require(replay['committedGeneration'] == committed['committedGeneration'], 'receipt-replay-recommitted')
            require(all(not r['accounts'] for r in fresh_rows(engine)['rows'] if r['id'] == 'copilot'), 'replay-restored-private-value')
            engine.shutdown()
            details['rpc'] += transcript(engine)
        details.update(independentCLIRevoke=True, durableReceiptReplay=True)
    elif scenario == 'U3-backpressure-receipt':
        # Real bounded writer, no history/provider overlay. Stop stdout after hello,
        # fill it with ordinary diagnostics, then commit a revoke via independent CLI.
        h.allow()
        with h.engine('drive-pressure') as engine:
            engine.initialize()
            sent = 0
            for id in range(100, 1124):
                try:
                    engine.send(id, 'diagnostics/get', {})
                    sent += 1
                except EngineFailure:
                    break
            require(sent >= 24, 'pressure-input-not-delivered')
            receipt_request = h.request(deny=['copilot.runtime_usage'])
            committed = json.loads(h.run(['consent', 'grant', '--json'], receipt_request, check=True).stdout)
            require(committed['committed'], 'pressure-revoke-not-committed')
            engine.wait(12)
        with h.engine('drive-pressure-replay') as engine:
            engine.initialize()
            replay = engine.request('consent/grant', receipt_request)['result']['data']
            require(replay['committedGeneration'] == committed['committedGeneration'], 'pressure-receipt-recommitted')
            engine.shutdown()
            details['rpc'] = transcript(engine)
        details.update(unreadRequests=sent, durableReceiptReplay=True, independentCLIRevoke=True)
    else:
        raise EngineFailure('unknown-scenario')
    return details
