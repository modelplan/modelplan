# SPDX-License-Identifier: MIT
"""Fail-closed V-01 capture transaction for a trusted native capture adapter.

The caller supplies an adapter implementing observe(pid) and capture(pid, kind,
identifier, rect, path). This module does not launch a candidate or grant any
screen, accessibility, network, or account access. Observations must be obtained
independently from the OS, not from the candidate or a caller-supplied fixture.
"""
import hashlib
import json
import math
import os
import re
import shutil
import subprocess
import tempfile
from datetime import datetime, timezone
from pathlib import Path

SHA = re.compile(r"[0-9a-f]{40}(?:[0-9a-f]{24})?\Z")


def _rect(value):
    if not isinstance(value, dict) or set(value) != {'x', 'y', 'width', 'height'}:
        raise ValueError('invalid rectangle')
    if any(isinstance(v, bool) or not isinstance(v, (int, float)) or not math.isfinite(v) for v in value.values()):
        raise ValueError('invalid rectangle')
    if value['width'] <= 0 or value['height'] <= 0:
        raise ValueError('empty rectangle')
    return value


def _contains(outer, inner):
    a, b = _rect(outer), _rect(inner)
    return (a['x'] <= b['x'] and a['y'] <= b['y'] and
            b['x'] + b['width'] <= a['x'] + a['width'] and
            b['y'] + b['height'] <= a['y'] + a['height'])


def _validate_observation(obs, pid):
    if not isinstance(obs, dict) or obs.get('pid') != pid or obs.get('processVerified') is not True:
        raise ValueError('candidate identity not verified')
    if obs.get('scale') not in (1, 2) or obs.get('appearance') not in ('light', 'dark'):
        raise ValueError('display state unavailable')
    display, band, crop, status = (obs.get(k) for k in ('displayFrame', 'menuBarFrame', 'cropFrame', 'statusFrame'))
    if not (_contains(display, band) and _contains(band, crop) and _contains(crop, status)):
        raise ValueError('crop outside candidate menu bar')
    # Restrict the crop to the item and a small margin, never a whole screen.
    if crop['width'] > status['width'] + 96 or crop['height'] > band['height']:
        raise ValueError('crop too large')
    neighbours = obs.get('neighbourFrames')
    if not isinstance(neighbours, list) or len(neighbours) != 2 or any(not _contains(band, n) for n in neighbours):
        raise ValueError('two menu-bar neighbour frames required')
    windows = obs.get('windows')
    if not isinstance(windows, list) or len(windows) > 64:
        raise ValueError('invalid candidate windows')
    ids = set()
    for window in windows:
        if not isinstance(window, dict) or window.get('ownerPID') != pid or type(window.get('id')) is not int or window['id'] <= 0:
            raise ValueError('non-candidate window')
        _rect(window.get('frame'))
        if window['id'] in ids:
            raise ValueError('duplicate window')
        ids.add(window['id'])
    return obs


class NativeAdapter:
    """Native OS-backed adapter; no permission prompt or application launch."""
    def __init__(self, executable, *, swift='/usr/bin/swift', runner=subprocess.run):
        self.executable = str(Path(executable).resolve(strict=True))
        self.swift = swift
        self.runner = runner
        self.script = str(Path(__file__).with_name('candidate_capture_adapter.swift'))

    def _run(self, args):
        try:
            result = self.runner(args, capture_output=True, text=True, timeout=20, check=False)
        except (OSError, subprocess.TimeoutExpired) as exc:
            raise ValueError('native capture unavailable') from exc
        if result.returncode != 0 or len(result.stdout) > 1048576:
            raise ValueError('native capture unavailable: permission or observation')
        return result.stdout

    def observe(self, pid):
        try:
            return json.loads(self._run([self.swift, self.script, 'inspect', str(pid), self.executable]))
        except (ValueError, json.JSONDecodeError) as exc:
            raise ValueError('native capture unavailable: permission or observation') from exc

    def capture(self, pid, kind, ident, rect, path):
        if kind == 'window' and type(ident) is int and ident > 0:
            args = ['/usr/sbin/screencapture', '-x', '-o', '-l', str(ident), str(path)]
        elif kind == 'menuBar' and ident is None:
            values = [rect[k] for k in ('x', 'y', 'width', 'height')]
            if any(int(v) != v for v in values):
                raise ValueError('fractional crop unsupported')
            region = ','.join(str(int(v)) for v in values)
            args = ['/usr/sbin/screencapture', '-x', '-R', region, str(path)]
        else:
            raise ValueError('unsupported capture')
        self._run(args)
        try:
            size = json.loads(self._run([self.swift, self.script, 'check-image', str(path)]))
            return size['width'], size['height']
        except (ValueError, KeyError, TypeError) as exc:
            raise ValueError('capture unavailable: blank or invalid image') from exc


def capture(adapter, *, pid, source_sha, package_sha256, scratch_parent, batch, name):
    """Publish one native-scale observation, or leave no capture on failure.

    The trusted adapter must capture a single owner-verified window by window ID,
    and a bounded screen rectangle only for the menu-bar crop. It must create a
    regular PNG and return its pixel dimensions. All coordinate values are CG
    screen points. Scratch must be private, outside the batch, on the same volume.
    """
    if type(pid) is not int or pid <= 0 or not isinstance(source_sha, str) or not SHA.fullmatch(source_sha):
        raise ValueError('invalid candidate identity')
    if not isinstance(package_sha256, str) or not re.fullmatch(r'[0-9a-f]{64}', package_sha256):
        raise ValueError('invalid package hash')
    if not isinstance(name, str) or not re.fullmatch(r'[A-Za-z0-9_-]{1,64}', name):
        raise ValueError('invalid output name')
    scratch, root = Path(scratch_parent).resolve(strict=True), Path(batch).resolve(strict=True)
    if not scratch.is_dir() or not root.is_dir() or scratch == root or root in scratch.parents or scratch.stat().st_dev != root.stat().st_dev:
        raise ValueError('scratch must be outside batch on the same volume')
    destination = root / name
    if destination.exists() or destination.is_symlink():
        raise ValueError('output already exists')
    stage = Path(tempfile.mkdtemp(prefix='.candidate-capture-', dir=scratch))
    os.chmod(stage, 0o700)
    try:
        first = _validate_observation(adapter.observe(pid), pid)
        paths = []
        operations = [('window', w['id'], w['frame'], 'window-%d.png' % w['id']) for w in first['windows']]
        operations.append(('menuBar', None, first['cropFrame'], 'status-menu-bar.png'))
        for kind, ident, rect, filename in operations:
            if _validate_observation(adapter.observe(pid), pid) != first:
                raise ValueError('candidate geometry changed before capture')
            output = stage / filename
            dimensions = adapter.capture(pid, kind, ident, rect, output)
            if output.is_symlink() or not output.is_file() or output.stat().st_size == 0:
                raise ValueError('capture missing or unsafe')
            if kind == 'menuBar':
                expected = (round(rect['width'] * first['scale']), round(rect['height'] * first['scale']))
                if tuple(dimensions) != expected:
                    raise ValueError('capture is not at native scale')
            paths.append(filename)
            if _validate_observation(adapter.observe(pid), pid) != first:
                raise ValueError('candidate geometry changed during capture')
        receipt = {
            'scenario': 'V-01', 'sourceSHA': source_sha, 'packageSHA256': package_sha256,
            'displayScale': first['scale'], 'appearance': first['appearance'],
            'capturePaths': paths, 'statusItemFrame': first['statusFrame'],
            'neighbourStatusItemFrames': first['neighbourFrames'], 'menuBarCropFrame': first['cropFrame'],
            'timestampUTC': datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z'),
            'captureSHA256': {p: hashlib.sha256((stage / p).read_bytes()).hexdigest() for p in paths},
        }
        with (stage / 'receipt.json').open('x', encoding='utf-8') as f:
            json.dump(receipt, f, sort_keys=True, indent=2)
        if _validate_observation(adapter.observe(pid), pid) != first:
            raise ValueError('candidate geometry changed before publication')
        os.rename(stage, destination)
        return receipt
    finally:
        if stage.exists():
            shutil.rmtree(stage)
