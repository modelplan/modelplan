# SPDX-License-Identifier: MIT
"""Shared file-backed release, live lease and booking admission."""
import json
import math
from pathlib import Path
import time

import book
from release import IDENTITY_FIELDS, validate_release


def validate(config, now):
    if config.get('profile') != 'synthetic':
        raise ValueError('synthetic profile required')
    pin = config.get('binarySHA256', '')
    if not isinstance(pin, str) or len(pin) != 64 or any(c not in '0123456789abcdef' for c in pin):
        raise ValueError('explicit binary SHA256 required')
    lease = config['lease']
    validate_release(lease, config['release'])
    expected = config.get('expectedLease')
    if expected is not None and any(lease.get(k) != expected.get(k) for k in IDENTITY_FIELDS):
        raise ValueError('run/lease identity mismatch')
    values = [now, lease['notBefore'], lease['expiresAt'], lease.get('guardianHeartbeatAt'), config.get('requiredSeconds')]
    if any(type(x) not in (int, float) or not math.isfinite(x) for x in values):
        raise ValueError('invalid timing')
    if not 0 < lease['expiresAt'] - lease['notBefore'] <= 1200:
        raise ValueError('absolute window invalid')
    if not lease['notBefore'] <= now < lease['expiresAt']:
        raise ValueError('outside window')
    if not 0 <= now - lease['guardianHeartbeatAt'] <= 2:
        raise ValueError('heartbeat stale')
    if config.get('stop') is not False or lease.get('ownerPreempted') is not False or lease.get('exclusive') is not True:
        raise ValueError('stopped/not exclusive')
    if config['requiredSeconds'] <= 0 or lease['expiresAt'] - now < config['requiredSeconds']:
        raise ValueError('insufficient phase+cleanup time')
    if not config.get('argv') or not all(isinstance(x, str) and x for x in config['argv']):
        raise ValueError('explicit executable arguments required')
    return True


def load_and_admit(config):
    current = dict(config)
    current['lease'] = json.loads(Path(config['leasePath']).read_text())
    current['release'] = json.loads(Path(config['releasePath']).read_text())
    current['stop'] = Path(config['stopPath']).exists()
    if current['lease'].get('guardian') is not True:
        # book.py start issues only an initial heartbeat; execution needs a live guardian (bin/guardian.py).
        raise ValueError('guardian not running')
    validate(current, time.time())
    book.admit(current)
    return current
