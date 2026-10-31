# SPDX-License-Identifier: MIT
"""Shared file-backed release, live lease and booking admission."""
import json
import math
from pathlib import Path
import time

import book
from guardian import MIN_RESERVE, quit_grace
from release import IDENTITY_FIELDS, validate_release


def budget(config):
    """Seconds a launch needs before `expiresAt` (C2.2 section 4), as ONE sum: `requiredSeconds` (the scenario's
    action phase only, not quit or cleanup) + `quitGraceSeconds` (default 5, capped at 10) + MIN_RESERVE (25 s for
    TERM, KILL and the closure checks). Admission refuses below it and admits at or above it."""
    return config['requiredSeconds'] + closing_budget(config)


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
    if config['requiredSeconds'] <= 0:
        raise ValueError('requiredSeconds must be positive (the action phase only)')
    if lease['expiresAt'] - now < budget(config):
        raise ValueError('insufficient time for action phase plus quit grace plus cleanup reserve')
    if not config.get('argv') or not all(isinstance(x, str) and x for x in config['argv']):
        raise ValueError('explicit executable arguments required')
    return True


def live_records(config):
    """The run's live lease, release and stop state, reread from the files the run config names."""
    current = dict(config)
    current['lease'] = json.loads(Path(config['leasePath']).read_text())
    current['release'] = json.loads(Path(config['releasePath']).read_text())
    current['stop'] = Path(config['stopPath']).exists()
    if current['lease'].get('guardian') is not True:
        # book.py start issues only an initial heartbeat; execution needs a live guardian (bin/guardian.py).
        raise ValueError('guardian not running')
    return current


def load_and_admit(config):
    """Launch admission: the full additive budget (`budget`), checked before the subject starts (launch.py, and the
    scenario's `prepare` before it). Never call it again once the action phase has begun; use `still_admitted`."""
    current = live_records(config)
    validate(current, time.time())
    book.admit(current)
    return current


def closing_budget(config):
    """Seconds an admitted run must keep before `expiresAt` to still close inside its lease: quit grace + MIN_RESERVE."""
    return quit_grace(config.get('quitGraceSeconds')) + MIN_RESERVE


def still_admitted(config, clock=time.time):
    """Between action steps of a run that launch admission already admitted (macrev-332-18). The additive budget
    was spent on purpose by the steps before this one, so it is not checked again. Instead, on every call: the lease
    identity is still the one the run config bound (`expectedLease`), the release still matches it, nothing revoked
    or stopped the run, the guardian heartbeat is fresh, the booking still owns the Mac, and at least the closing
    budget (quit grace + 25 s) remains, so the run can still quit and close inside the lease."""
    current = live_records(config)
    lease, expected = current['lease'], config.get('expectedLease')
    if not isinstance(expected, dict) or any(not expected.get(k) or lease.get(k) != expected.get(k) for k in IDENTITY_FIELDS):
        raise ValueError('run/lease identity mismatch')
    validate_release(lease, current['release'])
    now = clock()
    if any(type(x) not in (int, float) or not math.isfinite(x)
           for x in (now, lease['notBefore'], lease['expiresAt'], lease.get('guardianHeartbeatAt'))):
        raise ValueError('invalid timing')
    if not lease['notBefore'] <= now < lease['expiresAt']:
        raise ValueError('outside window')
    if not 0 <= now - lease['guardianHeartbeatAt'] <= 2:
        raise ValueError('heartbeat stale')
    if current['stop'] is not False or lease.get('ownerPreempted') is not False or lease.get('exclusive') is not True:
        raise ValueError('stopped/not exclusive')
    need = closing_budget(config)
    if lease['expiresAt'] - now < need:
        raise ValueError('insufficient time to quit and close inside the lease')
    book.admit(dict(current, requiredSeconds=need))  # the booking still owns the Mac and covers the closing budget
    return current
