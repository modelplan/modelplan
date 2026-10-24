#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Supplemental packaged read-only access proof, entirely in synthetic temporary homes.
Does not grant TCC permissions or replace full-toolchain/minimum-runtime acceptance.
"""
import datetime
import hashlib
import json
import os
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile

app = Path(sys.argv[1]).resolve()
output = Path(sys.argv[2]).resolve()
output.mkdir(parents=True, exist_ok=False)
exe = app / 'Contents/MacOS/ModelPlanCommunity'
helper = app / 'Contents/Helpers/modelplan'


def run(args, **kw):
    return subprocess.run([str(x) for x in args], capture_output=True, timeout=30, **kw)


def tree(root):
    result = {}
    for p in sorted(root.rglob('*')):
        stat = p.stat()
        result[str(p.relative_to(root))] = [stat.st_mode, stat.st_mtime_ns,
            hashlib.sha256(p.read_bytes()).hexdigest() if p.is_file() else None]
    return result


receipt = {'schemaVersion': 1, 'cases': [], 'toolchainAcceptance': 'pending-full-Xcode', 'intelRuntimeTested': False}
for binary in [exe, helper]:
    archs = run(['/usr/bin/lipo', '-archs', binary])
    assert archs.returncode == 0 and set(archs.stdout.decode().split()) == {'arm64', 'x86_64'}
    signature = run(['/usr/bin/codesign', '-dvvv', '--entitlements', ':-', binary])
    assert signature.returncode == 0 and b'runtime' in signature.stderr
    if signature.stdout.strip().startswith(b'<?xml'):
        entitlements = plistlib.loads(signature.stdout)
        assert not entitlements.get('com.apple.security.app-sandbox', False)
    receipt.setdefault('binaries', []).append({'pathInApp': str(binary.relative_to(app)),
        'sha256': hashlib.sha256(binary.read_bytes()).hexdigest(), 'archs': archs.stdout.decode().split(),
        'hardenedRuntime': True, 'appSandbox': False, 'signing': 'ad-hoc-test-only'})
assert run(['/usr/bin/codesign', '--verify', '--deep', '--strict', app]).returncode == 0
links = run(['/usr/bin/otool', '-L', exe]).stdout.decode()
assert 'WebKit.framework' not in links and 'RealityKit.framework' not in links
assert (app / 'Contents/Resources/CLI-THIRD-PARTY-NOTICES.md').exists()
receipt['directWebKitRealityKitLinks'] = False
receipt['minimumSystemVersion'] = plistlib.loads((app / 'Contents/Info.plist').read_bytes())['LSMinimumSystemVersion']
assert receipt['minimumSystemVersion'] == '14.0'

with tempfile.TemporaryDirectory(prefix='modelplan-access-proof-') as temporary:
    root = Path(temporary)
    for case in ['observed', 'unavailable', 'denied']:
        home = root / case
        home.mkdir()
        quota_file = None
        if case != 'unavailable':
            now = datetime.datetime.now(datetime.timezone.utc)
            sessions = home / 'codex' / 'sessions'
            folder = sessions / now.strftime('%Y/%m/%d')
            folder.mkdir(parents=True)
            stamp = (now - datetime.timedelta(seconds=10)).strftime('%Y-%m-%dT%H:%M:%SZ')
            rows = [
                {'timestamp': stamp, 'type': 'session_meta', 'payload': {'id': 'synthetic', 'originator': 'codex_cli_rs'}},
                {'timestamp': stamp, 'type': 'turn_context', 'payload': {'model': 'gpt-6-sol'}},
                {'timestamp': stamp, 'type': 'event_msg', 'payload': {'type': 'token_count', 'info': None,
                    'rate_limits': {'limit_id': 'codex', 'primary': {'used_percent': 20, 'window_minutes': 300,
                        'resets_at': int(now.timestamp()) + 7200}, 'plan_type': 'plus'}}}
            ]
            quota_file = folder / ('rollout-' + now.strftime('%Y-%m-%dT%H-%M-%S') + '-synthetic.jsonl')
            quota_file.write_text(''.join(json.dumps(x) + '\n' for x in rows))
        before = tree(home)
        denied_verified = False
        try:
            if case == 'denied':
                sessions.chmod(0)
                try:
                    quota_file.read_bytes()
                except PermissionError:
                    denied_verified = True
                assert denied_verified, 'test must actually deny access under the running UID'
            result_file = output / (case + '.json')
            result = run([exe, '--access-probe', home, result_file])
            assert result.returncode == 0 and result_file.exists(), 'packaged AppKit probe did not complete'
        finally:
            if case == 'denied':
                sessions.chmod(0o755)
        # Directory creation used the process umask; restore the exact original mode before comparing.
        if case == 'denied':
            original_mode = before['codex/sessions'][0] & 0o7777
            sessions.chmod(original_mode)
        assert tree(home) == before, 'read-only helper mutated its fixture home'
        value = json.loads(result_file.read_text())
        assert value['launchedFromApp'] and value['helperBundled']
        assert value['readOnlyArguments'] == ['desktop', '--json', '--read-only']
        if case == 'observed':
            assert value['outcome'] == 'observed' and 80 in value['remaining']
            assert value['cliVersion'] == '0.5.35'
            receipt['actualCLIVersion'] = value['cliVersion']
        else:
            assert value['outcome'] == 'unavailable' and not value['remaining']
        receipt['cases'].append({'case': case, 'expected': value['outcome'], 'homeUnchanged': True,
            'unixDenialVerified': denied_verified, 'tccSettingsChanged': False})
    isolated = root / 'publication-only'
    isolated.mkdir()
    environment = {'HOME': str(isolated), 'CODEX_HOME': str(isolated / 'codex'),
        'MODELPLAN_CACHE': str(isolated / 'cache'), 'PATH': '/usr/bin:/bin', 'NO_COLOR': '1'}
    before = tree(isolated)
    offline = run([helper, 'publication', '--json', '--offline'], env=environment)
    assert offline.returncode == 3 and offline.stdout == b''
    assert tree(isolated) == before
    receipt['offlinePublicationEmptyCache'] = {'exitCode': 3, 'stdoutBytes': 0, 'homeUnchanged': True}
(output / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
print('PASS packaged universal app/helper signatures and synthetic observed/unavailable/Unix-denied read-only access')
print('PASS actual CLI v0.5.35 and publication offline exit3 with no stdout or fixture writes')
print('Supplemental CLT-built access evidence; full Xcode tools, physical error UI and minimum-runtime gates are pending')
