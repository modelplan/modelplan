#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Engine-only consent scenarios using real binaries and disposable homes.

Build cli/cmd/modelplan, then pass --cli /path/to/modelplan. Repeat --old
VERSION=/checksum-verified/released/modelplan for the releases actually tested.
No network download, user HOME or real login is used by this runner.
"""
import argparse
import concurrent.futures
import hashlib
import http.server
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import time
import uuid


FAKE_RUNTIME = r'''#!PYTHON
import json,os,sys,time
from pathlib import Path
home=Path(os.environ['HOME'])
while True:
    length=None
    while True:
        line=sys.stdin.buffer.readline()
        if not line:sys.exit(0)
        if line==b'\r\n':break
        if line.lower().startswith(b'content-length:'):length=int(line.split(b':')[1])
    request=json.loads(sys.stdin.buffer.read(length))
    method=request['method']
    with (home/'runtime-calls').open('a') as log:log.write(method+'\n')
    if method=='connect':result={'protocolVersion':3}
    elif method=='auth.getStatus':result={'isAuthenticated':True,'authType':'user'}
    elif method=='account.getQuota':
        if (home/'block').exists():
            (home/'reading').touch()
            deadline=time.monotonic()+12
            while not (home/'release').exists():
                if time.monotonic()>deadline:sys.exit(3)
                time.sleep(.01)
        result={'quotaSnapshots':{'premium_interactions':{'usedRequests':75,'entitlementRequests':300,'remainingPercentage':75,'resetDate':'2099-01-01T00:00:00Z'}}}
    else:sys.exit(4)
    body=json.dumps({'jsonrpc':'2.0','id':request['id'],'result':result}).encode()
    sys.stdout.buffer.write(('Content-Length: %d\r\n\r\n'%len(body)).encode()+body)
    sys.stdout.buffer.flush()
'''


class Trap(http.server.BaseHTTPRequestHandler):
    calls = []

    def do_CONNECT(self):
        self.calls.append('CONNECT')
        self.send_error(502)

    def do_GET(self):
        self.calls.append('GET')
        self.send_error(502)

    do_POST = do_GET

    def log_message(self, *_):
        pass


class Home:
    def __init__(self, root, cli, proxy):
        self.root, self.cli = root, cli
        (root / 'bin').mkdir(parents=True)
        (root / '.copilot').mkdir()
        fake = root / 'bin' / 'copilot'
        fake.write_text(FAKE_RUNTIME.replace('PYTHON', sys.executable, 1))
        fake.chmod(0o700)
        self.env = {
            'HOME': str(root), 'PATH': str(root / 'bin') + ':/usr/bin:/bin',
            'MODELPLAN_CACHE': str(root / 'cache'), 'MODELPLAN_COPILOT': str(fake),
            'MODELPLAN_BASE': 'http://127.0.0.1:1', 'MODELPLAN_HISTORY': 'off',
            'MODELPLAN_CODEX_ACCOUNT': 'off', 'MODELPLAN_CODEXBAR': 'off',
            'MODELPLAN_TASK_BRIEF': 'off', 'NO_COLOR': '1', 'LANG': 'C',
            'HTTP_PROXY': proxy, 'HTTPS_PROXY': proxy, 'NO_PROXY': '127.0.0.1,localhost',
        }
        self.store = root / '.config' / 'modelplan' / 'consent.json'
        self.run(['consent', 'init', '--json'], check=True)

    def run(self, args, payload=None, binary=None, check=False):
        data = json.dumps(payload) if isinstance(payload, dict) else payload
        r = subprocess.run([str(binary or self.cli), *args], input=data,
                           text=True, capture_output=True, env=self.env, timeout=18)
        if check and r.returncode:
            raise AssertionError((args, r.returncode, r.stdout, r.stderr))
        return r

    def state(self):
        return json.loads(self.store.read_text())

    def request(self, **decisions):
        s = self.state()
        return dict(requestId=str(uuid.uuid4()), expectStoreEpoch=s['storeEpoch'],
                    expectGeneration=s['generation'], consentTextVersion=2, **decisions)

    def mutate(self, **decisions):
        r = self.run(['consent', 'grant', '--json'], self.request(**decisions))
        response = json.loads(r.stdout)
        assert response.get('committed'), response
        return response

    def allow(self):
        return self.mutate(allow=['copilot.runtime_usage'])

    def refresh(self):
        return self.run(['connections', 'refresh', '--quiet'])

    def calls(self):
        path = self.root / 'runtime-calls'
        return path.read_text() if path.exists() else ''

    def observed(self):
        directory = self.root / 'cache' / 'observed'
        return {str(p.relative_to(directory)): hashlib.sha256(p.read_bytes()).hexdigest()
                for p in directory.rglob('*') if p.is_file() and not p.name.endswith('.lock')}


def await_file(path):
    deadline = time.monotonic() + 10
    while not path.exists():
        if time.monotonic() > deadline:
            raise AssertionError('runtime did not reach in-flight read')
        time.sleep(.01)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--cli', required=True, type=Path)
    ap.add_argument('--old', action='append', default=[])
    ap.add_argument('--output', type=Path)
    args = ap.parse_args()
    outcomes = []
    trap = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Trap)
    threading.Thread(target=trap.serve_forever, daemon=True).start()
    proxy = 'http://127.0.0.1:%d' % trap.server_port
    try:
        with tempfile.TemporaryDirectory(prefix='modelplan-u2-engine-') as directory:
            root = Path(directory)
            with concurrent.futures.ThreadPoolExecutor() as pool:
                h = Home(root / 'revoke-race', args.cli, proxy)
                h.allow()
                (h.root / 'block').touch()
                reading = pool.submit(h.refresh)
                await_file(h.root / 'reading')
                receipt = h.mutate(deny=['copilot.runtime_usage'])
                assert receipt['code'] == 'cleanup_pending', receipt
                (h.root / 'release').touch()
                reading.result(timeout=15)
                report = h.run(['quota', '--json', '--offline'], check=True)
                assert not json.loads(report.stdout)['accounts'], report.stdout
                assert not (h.root / 'cache/observed/native.json').exists()
                outcomes.append(dict(scenario='U2-revoke-in-flight', outcome='pass'))

                h = Home(root / 'reset-race', args.cli, proxy)
                h.allow()
                old_epoch = h.state()['storeEpoch']
                old_allow = h.request(allow=['copilot.runtime_usage'])
                (h.root / 'block').touch()
                reading = pool.submit(h.refresh)
                await_file(h.root / 'reading')
                h.store.write_text('damaged synthetic store')
                r = h.run(['consent', 'reset', 'confirmed', '--json'], check=True)
                reset = json.loads(r.stdout)
                assert reset['generation'] == 1 and reset['storeEpoch'] != old_epoch
                assert h.run(['consent', '--json'], check=True).returncode == 0
                retry = h.run(['consent', 'grant', '--json'], old_allow)
                assert json.loads(retry.stdout)['error'] == 'consent_stale'
                (h.root / 'release').touch()
                reading.result(timeout=15)
                report = h.run(['quota', '--json', '--offline'], check=True)
                assert not json.loads(report.stdout)['accounts'], report.stdout
                assert not (h.root / 'cache/observed/native.json').exists()
                h.allow()  # the new epoch remains usable
                outcomes.append(dict(scenario='U2-reset-same-generation-and-old-allow', outcome='pass'))

                h = Home(root / 'two-writers', args.cli, proxy)
                requests = [h.request(deny=[scope]) for scope in
                            ['claude.account_usage.saved_login', 'retired.old_path']]
                writes = [pool.submit(h.run, ['consent', 'grant', '--json'], r) for r in requests]
                replies = [json.loads(f.result().stdout) for f in writes]
                assert sum(bool(r.get('committed')) for r in replies) == 1, replies
                assert sum(r.get('error') == 'stale_generation' for r in replies) == 1, replies
                outcomes.append(dict(scenario='U2-two-process-writers', outcome='pass'))

            for old in args.old:
                version, path = old.split('=', 1)
                h = Home(root / version, args.cli, proxy)
                reported=h.run(['version'],binary=Path(path),check=True).stdout.strip()
                assert reported.endswith(version.lstrip('v')), (version,reported)
                h.allow()
                h.refresh()
                assert 'account.getQuota' in h.calls(), 'negative control did not read'
                h.mutate(deny=['copilot.runtime_usage'])
                store, observed, calls = h.store.read_bytes(), h.observed(), h.calls()
                proxy_calls = len(Trap.calls)
                legacy = dict(requestId=str(uuid.uuid4()), expectGeneration=h.state()['generation'],
                              consentTextVersion=2, allow=['copilot'], deny=[], keychain={})
                commands = [(['consent', 'grant', '--json'], legacy),
                            (['connect', 'copilot'], 'y\n'),
                            (['connections', 'refresh', '--quiet'], None),
                            (['quota', '--refresh-account', '--json'], None),
                            (['disconnect', 'copilot', '--json'], None)]
                exits = []
                for command, payload in commands:
                    r = h.run(command, payload, binary=Path(path))
                    exits.append(r.returncode)
                    if command[0] in ('consent','connect','disconnect'):
                        assert r.returncode == 1, (version,command,'mutation did not refuse')
                    assert h.store.read_bytes() == store, (version, command, 'store changed')
                    assert h.observed() == observed, (version, command, 'readings changed')
                    assert h.calls() == calls and len(Trap.calls) == proxy_calls, (version, command, 'remote call')
                    assert not json.loads(h.run(['quota', '--json', '--offline'], check=True).stdout)['accounts']
                outcomes.append(dict(scenario='U2-old-writer', version=version, outcome='pass',
                                     commands=[c for c, _ in commands], exits=exits,
                                     binarySHA256=hashlib.sha256(Path(path).read_bytes()).hexdigest()))
        source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=Path(__file__).resolve().parents[1],text=True).strip()
        result = dict(sourceSHA=source,profile='synthetic-home, Linux real CLI binaries; engine only',
                      binarySHA256=hashlib.sha256(args.cli.read_bytes()).hexdigest(), scenarios=outcomes)
        text = json.dumps(result, indent=2) + '\n'
        if args.output:
            args.output.write_text(text)
        print(text, end='')
    finally:
        trap.shutdown()
        trap.server_close()


if __name__ == '__main__':
    main()
