# SPDX-License-Identifier: MIT
"""Shared file-backed release, live lease and booking admission."""
import json
import math
import os
from pathlib import Path
import time

import book
from release import HOSTS, IDENTITY_FIELDS, host_role, validate_release

LAUNCH_MODES = ('direct', 'launchservices')
# Real-profile runs (owner decision 2026-11-05) are admitted only on the dedicated test hosts:
# dev-mac is M1, macci is V1. The tuple is explicit so a future host never inherits the mode.
REAL_PROFILE_HOSTS = ('dev-mac', 'macci')


def validate(config, now):
    profile = config.get('profile', 'synthetic')
    if profile not in ('synthetic', 'real'):
        raise ValueError('profile must be synthetic or real')
    host = config.get('host', 'dev-mac')
    if profile == 'real' and host not in REAL_PROFILE_HOSTS:
        raise ValueError('real profile is allowed only on the M1/V1 test hosts')
    pin = config.get('binarySHA256', '')
    if not isinstance(pin, str) or len(pin) != 64 or any(c not in '0123456789abcdef' for c in pin):
        raise ValueError('explicit binary SHA256 required')
    if host not in HOSTS:
        raise ValueError(f'host must be one of {", ".join(HOSTS)}')
    if config.get('launchMode', 'direct') not in LAUNCH_MODES:
        raise ValueError(f'launchMode must be one of {", ".join(LAUNCH_MODES)}')
    if config.get('subjectKind', 'binary') not in ('binary', 'app-zip'):
        raise ValueError('subjectKind must be binary or app-zip')
    relaunch = config.get('relaunchPath')
    if relaunch is not None:
        # Relaunch keeps one supervised slot with the same HOME across launches; only the exec-gated
        # direct child can be respawned with proven identity.
        if not isinstance(relaunch, str) or not relaunch or not os.path.isabs(relaunch):
            raise ValueError('relaunchPath must be an absolute path')
        if config.get('launchMode', 'direct') != 'direct':
            raise ValueError('relaunch needs direct launch mode')
    lease = config['lease']
    validate_release(lease, config['release'], host)  # dev-mac: M1 receipt; macci: V1 + coordinator GO
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
    host_role(config.get('host'))  # the run config's host role must be this machine's role
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
