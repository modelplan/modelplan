#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Fail-closed candidate isolation admission and synthetic sandbox probe.

This module never launches a candidate or touches a real Keychain. Passing the
synthetic probes is not sufficient to prove isolation of system services.
"""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

SANDBOX = '/usr/bin/sandbox-exec'


def synthetic_profile(forbidden):
    """Deny a synthetic sentinel and all outbound networking for the probe."""
    path = os.path.realpath(os.fspath(forbidden))
    if not os.path.isabs(path) or '\n' in path or '\r' in path:
        raise ValueError('invalid sentinel path')
    return '(version 1)\n(allow default)\n(deny file-read* (literal ' + json.dumps(path) + '))\n(deny network-outbound)\n'


PROBE = r'''import errno, json, os, socket, sys
result = {}
try:
    with open(sys.argv[1], 'rb') as f: f.read(1)
    result['syntheticDeniedRead'] = 'unexpected-success'
except OSError as e:
    result['syntheticDeniedRead'] = 'denied' if e.errno in (errno.EACCES, errno.EPERM) else 'error'
try:
    with open(sys.argv[2], 'w') as f: f.write('synthetic')
    result['scratchWrite'] = 'allowed'
except OSError:
    result['scratchWrite'] = 'error'
sock = socket.socket()
sock.settimeout(1)
try:
    result['outboundNetwork'] = 'denied' if sock.connect_ex(('127.0.0.1', 9)) in (errno.EACCES, errno.EPERM) else 'not-proven'
finally:
    sock.close()
print(json.dumps(result))
'''


def synthetic_probe():
    """Probe sandbox enforcement using only newly created synthetic files."""
    with tempfile.TemporaryDirectory(prefix='modelplan-isolation-probe-') as tmp:
        root = Path(tmp)
        sentinel = root / 'sentinel'
        sentinel.write_text('synthetic', encoding='utf-8')
        profile = root / 'probe.sb'
        profile.write_text(synthetic_profile(sentinel), encoding='utf-8')
        try:
            result = subprocess.run([SANDBOX, '-f', str(profile), sys.executable, '-c', PROBE,
                                     str(sentinel), str(root / 'scratch')],
                                    capture_output=True, text=True, timeout=10, check=False)
            if result.returncode:
                return {'status': 'unavailable', 'reason': 'sandbox probe failed', 'exitCode': result.returncode,
                        'stderr': result.stderr.replace(tmp, '<scratch>')[:4096]}
            proof = json.loads(result.stdout)
            if set(proof) != {'syntheticDeniedRead', 'scratchWrite', 'outboundNetwork'}:
                raise ValueError('unexpected probe response')
            return {'status': 'completed', **proof}
        except (OSError, subprocess.TimeoutExpired, ValueError):
            return {'status': 'unavailable', 'reason': 'sandbox probe could not be verified'}


def keychain_event_matches(metadata, candidate_pid, candidate_executable):
    """Match pre-extracted client metadata only; do not inspect event messages.

    The caller must separately establish that its source reports the actual
    client rather than the security service. This matcher is not a monitor.
    """
    if not isinstance(metadata, dict) or type(candidate_pid) is not int or candidate_pid <= 0:
        return False
    if not isinstance(candidate_executable, str) or not candidate_executable:
        return False
    return (type(metadata.get('clientPID')) is int and metadata['clientPID'] == candidate_pid
            and metadata.get('clientExecutable') == candidate_executable)


def isolation_receipt(probe=None):
    """A synthetic probe never authorizes a candidate or proves Keychain safety."""
    return {
        'verdict': 'refuse',
        'guards': {'syntheticInputs': 'not-enforced', 'credentialAndKeychainMutations': 'not-enforced',
                   'providerNetwork': 'not-enforced'},
        'proofResults': {'syntheticSandbox': probe if probe is not None else {'status': 'not-run'},
                         'keychainMonitoringD19': 'not-verified', 'candidateIsolation': 'not-run'},
        'scratchPaths': {},
        'reason': 'candidate filesystem, credential-service and network isolation have not been established',
    }


def main():
    if sys.argv[1:] not in ([], ['--probe']):
        print('usage: candidate_isolation.py [--probe]', file=sys.stderr)
        return 2
    print(json.dumps(isolation_receipt(synthetic_probe() if sys.argv[1:] else None), sort_keys=True))
    return 1


if __name__ == '__main__':
    sys.exit(main())
