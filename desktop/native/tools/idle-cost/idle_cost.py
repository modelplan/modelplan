#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Synthetic-only G4 measurement primitives. Installed-app admission is not implemented."""
import argparse
import json
import math
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time


def cpu_seconds(value):
    if not isinstance(value, str) or not value or value.startswith('-'):
        raise ValueError('invalid CPU time')
    pieces = value.split('-')
    if len(pieces) > 2 or (len(pieces) == 2 and not pieces[0].isdigit()):
        raise ValueError('invalid CPU time')
    days = int(pieces[0]) if len(pieces) == 2 else 0
    fields = pieces[-1].split(':')
    if len(fields) not in (2, 3) or any(not p.isdigit() for p in fields[:-1]):
        raise ValueError('invalid CPU time')
    try: seconds = float(fields[-1])
    except ValueError: raise ValueError('invalid CPU time') from None
    if not math.isfinite(seconds) or not 0 <= seconds < 60 or int(fields[-2]) >= 60 and len(fields) == 3:
        raise ValueError('invalid CPU time')
    minutes = int(fields[-2]); hours = int(fields[0]) if len(fields) == 3 else 0
    return days * 86400 + hours * 3600 + minutes * 60 + seconds


def valid_number(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value) and value >= 0


def assess(metrics, thresholds):
    names = set(metrics) | set(thresholds)
    out = {}
    for name in sorted(names):
        value, limit = metrics.get(name), thresholds.get(name)
        status = 'NOT_RUN' if not (valid_number(value) and valid_number(limit)) else ('PASS' if value <= limit else 'FAIL')
        out[name] = {'value': value if valid_number(value) else None,
                     'threshold': limit if valid_number(limit) else None, 'status': status}
    return out


def overall(results):
    states = {row['status'] for row in results.values()}
    return 'FAIL' if 'FAIL' in states else ('NOT_RUN' if not states or 'NOT_RUN' in states else 'PASS')


def delta(first, last):
    if first['pid'] != last['pid'] or first['start'] != last['start']:
        raise ValueError('process identity changed')
    cpu = last['cpu_seconds'] - first['cpu_seconds']
    if cpu < 0:
        raise ValueError('CPU counter regressed')
    return {'cpu_seconds': cpu, 'memory_growth_bytes': max(0, last['rss_bytes'] - first['rss_bytes'])}


def ps_sample(pid):
    result = subprocess.run(['/bin/ps', '-p', str(pid), '-o', 'lstart=', '-o', 'time=', '-o', 'rss='],
                            capture_output=True, text=True, timeout=5, check=True, env={'PATH': '/usr/bin:/bin', 'LC_ALL': 'C'})
    parts = result.stdout.strip().split()
    if len(parts) != 7 or not parts[-1].isdigit():
        raise ValueError('missing or malformed process observation')
    return {'pid': pid, 'start': ' '.join(parts[:5]), 'cpu_seconds': cpu_seconds(parts[5]),
            'rss_bytes': int(parts[6]) * 1024}


def synthetic_smoke(output):
    # This workload is intentionally not an installed application or a G4 acceptance run.
    with tempfile.TemporaryDirectory(prefix='modelplan-idle-synthetic-') as directory:
        env = {'PATH': '/usr/bin:/bin', 'HOME': directory, 'TMPDIR': directory}
        worker = subprocess.Popen(['/bin/sleep', '210'], env=env, stdin=subprocess.DEVNULL,
                                  stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        samples = []
        started = time.monotonic()
        try:
            for target in (0, 60, 120, 180):
                delay = started + target - time.monotonic()
                if delay > 0: time.sleep(delay)
                samples.append(ps_sample(worker.pid))
            elapsed = time.monotonic() - started
            values = delta(samples[0], samples[-1])
        finally:
            if worker.poll() is None:
                worker.terminate()
                try: worker.wait(timeout=5)
                except subprocess.TimeoutExpired: worker.kill(); worker.wait()
        # Thresholds and request diagnostics must come from owner-approved app sources.
        values.update(network_requests=None, wakeups=None)
        measurements = assess(values, {})
        result = {'schema_version': 1, 'mode': 'synthetic-smoke', 'acceptance': False,
                  'elapsed_seconds': elapsed, 'sample_interval_seconds': 60, 'sample_count': len(samples),
                  'measurements': measurements, 'status': overall(measurements),
                  'limitations': ['Synthetic sleep process only; installed application is not measured',
                                  'No approved thresholds or app-owned network diagnostics']}
        flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, 'O_NOFOLLOW', 0)
        with os.fdopen(os.open(output, flags, 0o600), 'w') as stream:
            json.dump(result, stream, indent=2, allow_nan=False); stream.write('\n')
        return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--synthetic-smoke', action='store_true', help='three-minute synthetic harness smoke only')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if not args.synthetic_smoke:
        parser.error('installed-app measurement is not yet implemented')
    if args.output.exists() or args.output.is_symlink():
        parser.error('output must be a new file')
    synthetic_smoke(args.output)
    print('synthetic harness finished; G4 outcome NOT_RUN')


if __name__ == '__main__':
    main()
