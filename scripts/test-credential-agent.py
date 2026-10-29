#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Real app-server/CLI credential scenarios; synthetic app agent and TLS vendor.

The engine is unmodified. A local HTTPS proxy serves only the compiled Claude
host and two GET paths under a temporary CA. No real login or Keychain is used.
"""
import argparse
import hashlib
import http.server
import json
import os
from pathlib import Path
import queue
import ssl
import subprocess
import sys
import tempfile
import threading
import time
import uuid

SCOPE = 'claude.account_usage.saved_login'
CANARY = 'U7-access-token-canary-never-persist'


class Vendor(http.server.BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'

    def do_GET(self):
        allowed = self.path in ('/api/oauth/profile', '/api/oauth/usage')
        authenticated = self.headers.get('Authorization') == 'Bearer ' + CANARY
        self.server.reads.append((self.path, authenticated))
        if not allowed or not authenticated:
            self.send_error(400)
            return
        if self.path.endswith('/profile'):
            body = {'account': {'uuid': 'synthetic-u7-account'},
                    'organization': {'uuid': 'synthetic-u7-org'}}
        else:
            body = {'five_hour': {'utilization': 25, 'resets_at': '2099-01-01T00:00:00Z'}}
        raw = json.dumps(body).encode()
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def log_message(self, *_):
        pass


class Proxy(http.server.BaseHTTPRequestHandler):
    def do_CONNECT(self):
        if self.path != 'api.anthropic.com:443':
            self.server.unexpected.append('host')
            self.send_error(502)
            return
        self.send_response(200)
        self.end_headers()
        try:
            connection = self.server.tls.wrap_socket(self.connection, server_side=True)
            Vendor(connection, self.client_address, self.server)
        except (ssl.SSLError, ConnectionError, OSError):
            pass
        self.close_connection = True

    def do_GET(self):
        self.server.unexpected.append('plain_http')
        self.send_error(502)

    do_POST = do_GET

    def log_message(self, *_):
        pass


class Agent:
    def __init__(self, home, binary, proxy, ca):
        self.home = home
        (home / '.claude').mkdir(parents=True, exist_ok=True)
        self.env = {
            'HOME': str(home), 'PATH': '/usr/bin:/bin', 'LANG': 'C',
            'MODELPLAN_CACHE': str(home / 'cache'), 'MODELPLAN_HISTORY': 'off',
            'MODELPLAN_CODEX_ACCOUNT': 'off', 'MODELPLAN_CODEXBAR': 'off',
            'MODELPLAN_TASK_BRIEF': 'off', 'MODELPLAN_BASE': 'http://127.0.0.1:1',
            'HTTPS_PROXY': proxy, 'HTTP_PROXY': proxy, 'NO_PROXY': '127.0.0.1,localhost',
            'SSL_CERT_FILE': str(ca),
        }
        self.binary = binary
        self.cli('consent', 'init', '--json')
        self.process = subprocess.Popen([str(binary), 'app-server'], stdin=subprocess.PIPE,
                                        stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=self.env)
        self.messages, self.pending, self.output, self.errors = queue.Queue(), [], [], bytearray()
        self.identifier = 0
        self.session = 's-u7-' + uuid.uuid4().hex
        threading.Thread(target=self._read, daemon=True).start()
        self.stderr_thread = threading.Thread(target=self._stderr, daemon=True)
        self.stderr_thread.start()
        self.request('initialize', dict(sessionId=self.session, protocolVersion='1.0',
                     appVersion='synthetic-u7', capabilities=['rows', 'consent', 'credentials', 'diagnostics', 'refresh']))

    def _read(self):
        for line in self.process.stdout:
            self.output.append(line)
            try:
                self.messages.put(json.loads(line))
            except ValueError:
                self.messages.put({'invalid': True})
        self.messages.put({'eof': True})

    def _stderr(self):
        self.errors.extend(self.process.stderr.read(65537))

    def cli(self, *args, payload=None):
        result = subprocess.run([str(self.binary), *args], input=json.dumps(payload) if payload else None,
                                capture_output=True, text=True, env=self.env, timeout=15)
        assert CANARY not in result.stdout + result.stderr, 'CLI credential exposure'
        return result

    def state(self):
        return json.loads((self.home / '.config/modelplan/consent.json').read_text())

    def wait(self, predicate, timeout=8):
        for i, message in enumerate(self.pending):
            if predicate(message):
                return self.pending.pop(i)
        end = time.monotonic() + timeout
        while True:
            message = self.messages.get(timeout=max(.001, end-time.monotonic()))
            assert not message.get('eof') and not message.get('invalid'), 'engine closed or emitted invalid JSON'
            if predicate(message):
                return message
            self.pending.append(message)

    def send(self, method, params):
        self.identifier += 1
        self.process.stdin.write((json.dumps(dict(jsonrpc='2.0', id=self.identifier,
                                 method=method, params=params)) + '\n').encode())
        self.process.stdin.flush()
        return self.identifier

    def request(self, method, params):
        end = time.monotonic() + 3
        while True:
            identifier = self.send(method, params)
            result = self.wait(lambda message: message.get('id') == identifier)
            # A concurrent fenced reader commit may refuse a read publication.
            # Retry only this recoverable read error, within one bounded window.
            code = result.get('error', {}).get('code')
            if method in ('rows/subscribe', 'diagnostics/get') and code == -32023 and time.monotonic() < end:
                time.sleep(.01)
                continue
            assert 'error' not in result, 'unexpected RPC error: ' + method + ' code=' + str(code)
            return result['result']

    def grant(self, keychain=True):
        state = self.state()
        params = dict(requestId=str(uuid.uuid4()), expectStoreEpoch=state['storeEpoch'],
                      expectGeneration=state['generation'], consentTextVersion=2,
                      allow=[SCOPE], deny=[])
        if keychain:
            params['keychain'] = {SCOPE: 'allow'}
        return self.request('consent/grant', params)

    def credential(self, interactive):
        message = self.wait(lambda message: message.get('method') == 'credentials/request')
        request = message['params']
        assert request['sessionId'] == self.session, 'wrong credential session'
        assert request['storeEpoch'] == self.state()['storeEpoch'], 'wrong credential epoch'
        assert request['consentGeneration'] == self.state()['generation'], 'wrong credential generation'
        assert request['data']['interactive'] is interactive, 'wrong interaction admission'
        assert request['data']['scope'] == SCOPE and request['data']['provider'] == 'claude', 'wrong credential scope'
        return request['data']['operationId']

    def result(self, operation, outcome='ok', rejected=False):
        params = dict(operationId=operation, outcome=outcome)
        if outcome == 'ok':
            params['accessToken'] = CANARY
            params['expiresAt'] = '2099-01-01T00:00:00Z'
        identifier = self.send('credentials/result', params)
        result = self.wait(lambda message: message.get('id') == identifier)
        if rejected:
            assert result.get('error', {}).get('code') == -32030, 'mismatched or late result accepted'
        else:
            assert 'error' not in result, 'credential outcome was not recoverable'

    def verify(self):
        self.request('diagnostics/get', {})
        self.request('rows/subscribe', {})
        assert all(CANARY.encode() not in line for line in self.output), 'token in outbound message'
        assert CANARY.encode() not in self.errors, 'token on stderr'
        for name in ('cmdline', 'environ'):
            path = Path('/proc') / str(self.process.pid) / name
            if path.exists():
                assert CANARY.encode() not in path.read_bytes(), 'token in argv/environment'
        for file in self.home.rglob('*'):
            if file.is_file():
                try:
                    raw = file.read_bytes()
                except FileNotFoundError:
                    continue
                assert CANARY.encode() not in raw, 'token persisted'

    def close(self):
        if self.process.poll() is None:
            self.process.stdin.close()
            try:
                self.process.wait(timeout=4)
            except subprocess.TimeoutExpired:
                self.process.kill()
                self.process.wait()
                raise AssertionError('engine shutdown hung')
        self.stderr_thread.join(timeout=1)
        assert all(CANARY.encode() not in line for line in self.output), 'token on shutdown stdout'
        assert CANARY.encode() not in self.errors, 'token on shutdown stderr'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cli', type=Path, required=True)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--skip-deadline', action='store_true', help='omit the real 31-second expiry case')
    args = parser.parse_args()
    binary = args.cli.resolve()
    results = []
    with tempfile.TemporaryDirectory(prefix='u7-agent-') as temporary:
        root = Path(temporary)
        ca, key = root/'ca.pem', root/'key.pem'
        subprocess.run(['openssl', 'req', '-x509', '-nodes', '-newkey', 'rsa:2048', '-days', '1',
                        '-subj', '/CN=api.anthropic.com', '-addext', 'subjectAltName=DNS:api.anthropic.com',
                        '-keyout', str(key), '-out', str(ca)], check=True, capture_output=True)
        server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Proxy)
        server.reads, server.unexpected = [], []
        server.tls = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        server.tls.load_cert_chain(ca, key)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        proxy = 'http://127.0.0.1:' + str(server.server_port)

        def scenario(name, run):
            print('Running U7-' + name, file=sys.stderr, flush=True)
            agent = Agent(root/name, binary, proxy, ca)
            start = len(server.reads)
            replacement = agent
            try:
                replacement = run(agent, start) or agent
                replacement.verify()
                results.append(dict(scenario='U7-'+name, outcome='pass'))
            finally:
                replacement.close()
                if replacement is not agent:
                    agent.close()

        def outcome(agent, start, value):
            agent.grant()
            operation = agent.credential(True)
            agent.result(operation, value)
            expected = 2 if value == 'ok' else 0
            assert len(server.reads)-start == expected, 'unexpected remote read count'
            agent.result(operation, value, rejected=True)
        for value in ('ok', 'canceled', 'denied', 'not_found', 'interaction_required', 'timeout', 'error'):
            scenario(value, lambda agent, start, value=value: outcome(agent, start, value))

        def background(agent, start):
            agent.grant()
            agent.result(agent.credential(True), 'not_found')
            agent.request('refresh/request', dict(scopes=[SCOPE]))
            agent.result(agent.credential(False))
            end = time.monotonic() + 8
            while len(server.reads)-start < 2 and time.monotonic() < end:
                time.sleep(.01)
            assert len(server.reads)-start == 2, 'background result did not feed one reading'
        scenario('background-no-prompt', background)

        def budget(agent, start):
            agent.grant()
            agent.result(agent.credential(True))
            floor = agent.home/'cache/observed/reader-attempts/claude.json'
            before = floor.read_bytes()
            agent.grant()
            agent.result(agent.credential(True))
            assert len(server.reads)-start == 2, 'grant bypassed remote budget'
            assert floor.read_bytes() == before, 'credential operation changed remote budget'
        scenario('interactive-closed-budget', budget)

        def revoke(agent, start, reset=False):
            agent.grant()
            operation = agent.credential(True)
            if reset:
                result = agent.cli('consent', 'reset', 'confirmed', '--json')
                assert result.returncode == 0, 'reset failed'
            else:
                state = agent.state()
                payload = dict(requestId=str(uuid.uuid4()), expectStoreEpoch=state['storeEpoch'],
                               expectGeneration=state['generation'], consentTextVersion=2, deny=[SCOPE])
                result = agent.cli('consent', 'grant', '--json', payload=payload)
                assert json.loads(result.stdout)['committed'], 'revoke did not commit'
            agent.result(operation, rejected=True)
            assert len(server.reads) == start, 'old operation used after revoke/reset'
        scenario('revoke-during-operation', revoke)
        scenario('reset-during-operation', lambda agent, start: revoke(agent, start, True))

        def wrong(agent, start):
            agent.grant()
            operation = agent.credential(True)
            agent.result('wrong-operation', rejected=True)
            agent.result(operation)
            assert len(server.reads)-start == 2, 'matching operation lost after wrong result'
        scenario('wrong-operation', wrong)

        def changed_generation(agent, start):
            agent.grant()
            operation = agent.credential(True)
            agent.grant(keychain=False)
            agent.result(operation, rejected=True)
            assert len(server.reads) == start, 'old generation used while scope remained allowed'
        scenario('wrong-generation', changed_generation)

        def restart(agent, start):
            agent.grant()
            old_operation = agent.credential(True)
            agent.close()
            next_agent = Agent(agent.home, binary, proxy, ca)
            try:
                next_agent.result(old_operation, rejected=True)
                next_agent.request('refresh/request', dict(scopes=[SCOPE]))
                next_agent.result(next_agent.credential(False))
                # The matching background RPC wakes an already-budgeted reader;
                # its acknowledgment precedes that reader's asynchronous I/O.
                end = time.monotonic() + 8
                while len(server.reads)-start < 2 and time.monotonic() < end:
                    time.sleep(.01)
                assert len(server.reads)-start == 2, 'new session failed after rejecting old callback'
                return next_agent
            except BaseException:
                next_agent.close()
                raise
        scenario('old-session-result', restart)

        if not args.skip_deadline:
            def deadline(agent, start):
                agent.grant()
                operation = agent.credential(True)
                time.sleep(31)
                agent.result(operation, rejected=True)
                assert len(server.reads) == start, 'expired result used'
            scenario('expired-late-result', deadline)
        assert not server.unexpected and all(auth for _, auth in server.reads), 'unexpected destination/authentication'
        server.shutdown()
    evidence = dict(sourceSHA=subprocess.check_output(['git', 'rev-parse', 'HEAD'],
                    cwd=Path(__file__).resolve().parent.parent, text=True).strip(),
                    binarySHA256=hashlib.sha256(binary.read_bytes()).hexdigest(),
                    profile='synthetic-home, real CLI/app-server, fake app agent, local TLS Claude proxy; engine only',
                    scenarios=results)
    if args.output:
        args.output.write_text(json.dumps(evidence, indent=2)+'\n')
    print(json.dumps(evidence, indent=2))


if __name__ == '__main__':
    main()
