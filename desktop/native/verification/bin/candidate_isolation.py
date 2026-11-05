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
import re
import threading
from collections import deque
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


class SecurityEventMonitor:
    """Collect bounded client-process metadata; no event message is retained.

    Construct before launch, then bind the actual PID immediately after launch.
    A live log process alone is not a proof that all security activity is logged.
    """
    FIELDS = ('timestamp', 'processID', 'subsystem', 'category')

    def __init__(self, executable_name):
        if not isinstance(executable_name, str) or not re.fullmatch(r'[A-Za-z0-9._-]+', executable_name):
            raise ValueError('invalid executable name')
        self._events = deque(maxlen=4096)
        self._lock = threading.Lock()
        self._streams = []
        self._pid = None
        self._start('process == "' + executable_name + '"')

    def _start(self, client_predicate):
        predicate = client_predicate + ' AND (subsystem BEGINSWITH "com.apple.security" OR subsystem == "com.apple.securityd")'
        process = subprocess.Popen(['/usr/bin/log', 'stream', '--style', 'ndjson', '--level', 'debug',
                                    '--predicate', predicate], stdout=subprocess.PIPE,
                                   stderr=subprocess.DEVNULL, text=True, bufsize=1)
        self._streams.append(process)
        threading.Thread(target=self._collect, args=(process,), daemon=True).start()

    def _collect(self, process):
        for line in process.stdout:
            try:
                event = json.loads(line)
                if not isinstance(event, dict):
                    continue
                metadata = {key: event[key] for key in self.FIELDS if key in event}
                del event, line
                if set(metadata) == set(self.FIELDS) and type(metadata['processID']) is int:
                    with self._lock:
                        self._events.append(metadata)
            except (TypeError, ValueError):
                continue

    def bind(self, pid):
        if type(pid) is not int or pid <= 0 or self._pid is not None:
            raise ValueError('one positive client PID is required')
        self._pid = pid
        self._start('processIdentifier == ' + str(pid))

    def events(self):
        if self._pid is None:
            return []
        with self._lock:
            return [dict(item) for item in self._events if item['processID'] == self._pid]

    def running(self):
        return bool(self._streams) and all(process.poll() is None for process in self._streams)

    def close(self):
        for process in self._streams:
            if process.poll() is None:
                process.terminate()
        for process in self._streams:
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()


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
