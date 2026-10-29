# SPDX-License-Identifier: MIT
"""Bounded anonymous-pipe driver for the actual app-server binary."""
import hashlib
import json
import os
from pathlib import Path
import selectors
import subprocess
import threading
import time

MAX_FRAME = 8 << 20


class EngineFailure(Exception):
    pass


class EngineTimeout(EngineFailure):
    pass


def build_binary(repo, output, overlay=None):
    args = ['go', 'build', '-trimpath', '-o', str(output)]
    if overlay is not None:
        args += ['-overlay', str(overlay)]
    args += ['./cmd/modelplan']
    result = subprocess.run(args, cwd=Path(repo) / 'cli', capture_output=True, timeout=180)
    if result.returncode:
        raise EngineFailure('binary-build-failed')


def _unique(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise EngineFailure('duplicate-frame-key')
        result[key] = value
    return result


def _no_tokens(value):
    if isinstance(value, dict):
        if 'accessToken' in value:
            raise EngineFailure('unexpected-token-field')
        for item in value.values():
            _no_tokens(item)
    elif isinstance(value, list):
        for item in value:
            _no_tokens(item)


class EngineProcess:
    def __init__(self, binary, home, session, arguments=()):
        self.binary = Path(binary).absolute()
        self.home = Path(home).absolute()
        self.session = session
        self.arguments = tuple(arguments)
        self.buffer = bytearray()
        self.pending = []
        self.messages = []
        self.counter = 1
        self.sequence = 0
        self.changed_sequence = 0
        self.floor = 0
        self.epoch = None
        self.stderr_bytes = 0
        self.stderr_digest = hashlib.sha256()
        self.process = None
        self.environment = {'HOME': str(self.home), 'PATH': str(self.home / 'bin'),
                            'TMPDIR': str(self.home / '.u14-tmp'), 'LANG': 'C.UTF-8'}
        (self.home / '.u14-tmp').mkdir(mode=0o700, exist_ok=True)

    def __enter__(self):
        self.process = subprocess.Popen([str(self.binary), 'app-server', *self.arguments], env=self.environment,
                                        stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                        stderr=subprocess.PIPE, bufsize=0, close_fds=True)
        os.set_blocking(self.process.stdin.fileno(), False)
        self.stderr_thread = threading.Thread(target=self._drain_stderr, daemon=True)
        self.stderr_thread.start()
        return self

    def _drain_stderr(self):
        while True:
            data = self.process.stderr.read(4096)
            if not data:
                return
            self.stderr_bytes += len(data)
            self.stderr_digest.update(data)

    def __exit__(self, *_):
        if self.process is None:
            return
        if self.process.poll() is None:
            self.process.stdin.close()
            try:
                self.process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                self.process.kill()  # This run's child only.
                self.process.wait(timeout=2)
        for stream in (self.process.stdin, self.process.stdout):
            stream.close()
        self.stderr_thread.join(timeout=2)
        self.process.stderr.close()
        if self.stderr_thread.is_alive():
            raise EngineFailure('stderr-cleanup-unconfirmed')

    def send(self, id, method, params):
        request = {'jsonrpc': '2.0', 'method': method, 'params': params}
        if id is not None:
            request['id'] = id
        frame = json.dumps(request,
                           separators=(',', ':'), allow_nan=False).encode() + b'\n'
        if len(frame) > MAX_FRAME:
            raise EngineFailure('outbound-frame-too-large')
        deadline = time.monotonic() + 5
        view = memoryview(frame)
        try:
            with selectors.DefaultSelector() as selector:
                selector.register(self.process.stdin, selectors.EVENT_WRITE)
                while view:
                    remaining = deadline - time.monotonic()
                    if remaining <= 0 or not selector.select(remaining):
                        raise EngineTimeout('input-deadline')
                    written = self.process.stdin.write(view)
                    if written:
                        view = view[written:]
        except (BrokenPipeError, OSError) as exc:
            raise EngineFailure('input-pipe-closed') from exc

    def request(self, method, params=None):
        self.counter += 1
        self.send(self.counter, method, {} if params is None else params)
        return self.response(self.counter)

    def _bytes_ready(self, timeout):
        with selectors.DefaultSelector() as selector:
            selector.register(self.process.stdout, selectors.EVENT_READ)
            if not selector.select(timeout):
                raise EngineTimeout('output-deadline')

    def first_data_byte(self, timeout=3):
        # Backpressure tests deliberately read only this byte, then stop stdout reads.
        if self.buffer:
            del self.buffer[0]
            return
        self._bytes_ready(timeout)
        if not os.read(self.process.stdout.fileno(), 1):
            raise EngineFailure('no-data-frame-started')

    def read(self, timeout=5):
        deadline = time.monotonic() + timeout
        while b'\n' not in self.buffer:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise EngineTimeout('frame-deadline')
            self._bytes_ready(remaining)
            data = os.read(self.process.stdout.fileno(), min(65536, MAX_FRAME + 1 - len(self.buffer)))
            if not data:
                raise EngineFailure('unexpected-output-eof')
            self.buffer.extend(data)
            if len(self.buffer) > MAX_FRAME and b'\n' not in self.buffer:
                raise EngineFailure('frame-too-large')
        frame, _, tail = self.buffer.partition(b'\n')
        self.buffer = bytearray(tail)
        if len(frame) > MAX_FRAME:
            raise EngineFailure('frame-too-large')
        try:
            message = json.loads(frame, object_pairs_hook=_unique,
                                 parse_constant=lambda _: (_ for _ in ()).throw(EngineFailure('invalid-json-number')))
        except (ValueError, UnicodeError) as exc:
            raise EngineFailure('invalid-json-frame') from exc
        try:
            self._validate(message)
        except (KeyError, TypeError, AttributeError) as exc:
            raise EngineFailure('malformed-message-shape') from exc
        if len(self.messages) >= 256:
            raise EngineFailure('message-bound')
        self.messages.append(message)
        return message

    def _validate(self, message):
        if not isinstance(message, dict) or message.get('jsonrpc') != '2.0':
            raise EngineFailure('invalid-rpc-envelope')
        if 'result' in message and 'error' in message:
            raise EngineFailure('ambiguous-rpc-envelope')
        if 'error' in message:
            envelope = message['error'].get('data', {})
        else:
            envelope = message.get('result', message.get('params', {}))
        if envelope.get('sessionId') != self.session:
            raise EngineFailure('wrong-session')
        if 'storeEpoch' in envelope:
            gen = envelope.get('consentGeneration')
            if type(gen) is not int or gen < 0 or not envelope['storeEpoch']:
                raise EngineFailure('invalid-consent-context')
            if self.epoch != envelope['storeEpoch']:
                self.epoch, self.floor = envelope['storeEpoch'], gen
            else:
                self.floor = max(self.floor, gen)
        if 'result' in message or 'params' in message:
            if 'data' not in envelope:
                raise EngineFailure('missing-data')
        _no_tokens(message)
        data = envelope.get('data')
        if isinstance(data, dict) and ('projection' in data or 'items' in data):
            if envelope['consentGeneration'] < self.floor:
                raise EngineFailure('private-value-below-floor')
        if isinstance(data, dict) and 'projection' in data:
            projection = data['projection']
            ids = [r['id'] for r in projection.get('rows', [])]
            if len(ids) != len(set(ids)):
                raise EngineFailure('duplicate-row-identity')
            sequence = data.get('sequence')
            if type(sequence) is not int or sequence < self.sequence:
                raise EngineFailure('sequence-regressed')
            if message.get('method') == 'rows/changed':
                if sequence <= self.changed_sequence:
                    raise EngineFailure('notification-sequence-not-increasing')
                self.changed_sequence = sequence
            self.sequence = sequence
            if envelope['consentGeneration'] < self.floor:
                raise EngineFailure('private-value-below-floor')

    def _find(self, predicate, timeout=5):
        for i, message in enumerate(self.pending):
            if predicate(message):
                return self.pending.pop(i)
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            message = self.read(max(0.001, deadline - time.monotonic()))
            if predicate(message):
                return message
            self.pending.append(message)
        raise EngineTimeout('message-deadline')

    def response(self, id, timeout=5):
        return self._find(lambda message: message.get('id') == id, timeout)

    def initialize(self):
        self.send(1, 'initialize', {'sessionId': self.session, 'protocolVersion': '1.0',
                                   'appVersion': 'u14-synthetic',
                                   'capabilities': ['rows', 'consent', 'diagnostics', 'history', 'refresh', 'publication', 'credentials', 'plugin_install']})
        result = self.response(1)
        if 'error' in result:
            raise EngineFailure('handshake-rejected')
        self._find(lambda message: message.get('method') == 'engine/health')
        return result['result']

    def wait(self, timeout):
        try:
            result = self.process.wait(timeout=timeout)
        except subprocess.TimeoutExpired as exc:
            raise EngineTimeout('process-deadline') from exc
        self.stderr_thread.join(timeout=2)
        if self.stderr_bytes:
            raise EngineFailure('unexpected-stderr')
        return result

    def shutdown(self):
        message = self.request('shutdown')
        if 'error' in message or self.wait(3) != 0:
            raise EngineFailure('shutdown-failed')
