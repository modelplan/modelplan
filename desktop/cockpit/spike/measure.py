#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# THROWAWAY SPIKE (session C, 2026-11-06): run PortholeHarness once per porthole mode and record
# CPU (cumulative CPU-time deltas per phase), energy impact (top POWER), GPU/energy (powermetrics,
# best effort), memory (footprint + RSS) and rAF frame rate. Synthetic data only.
import json, os, re, subprocess, sys, threading, time, statistics
from pathlib import Path

HARNESS, BUNDLE_ROOT, MESSAGES, OUT = sys.argv[1:5]
MODES = sys.argv[5].split(',') if len(sys.argv) > 5 else ['off', 'still', 'live']
OUT = Path(OUT); OUT.mkdir(parents=True, exist_ok=True)
PAGE = '00000000-0000-4000-8000-000000000001'

def sh(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, **kw)

def cputime(pids):
    """Cumulative CPU seconds per pid (ps TIME, user+system)."""
    out = {}
    r = sh(['sudo', 'ps', '-o', 'pid=,time=', '-p', ','.join(map(str, pids))])
    for line in r.stdout.splitlines():
        pid, t = line.split()
        parts = [float(x) for x in t.replace('-', ':').split(':')]
        secs = 0.0
        for p in parts: secs = secs * 60 + p
        out[int(pid)] = secs
    return out

def rss(pids):
    r = sh(['ps', '-o', 'pid=,rss=', '-p', ','.join(map(str, pids))])
    return {int(a): int(b) / 1024 for a, b in (l.split() for l in r.stdout.splitlines())}

def footprint(pids, tag):
    r = sh(['sudo', 'footprint'] + [str(p) for p in pids])
    (OUT / f'footprint-{tag}.txt').write_text(r.stdout + r.stderr)
    found = {}
    for m in re.finditer(r'\[(\d+)\].*?(?:phys_footprint|Footprint):\s*([\d.]+)\s*(KB|MB|GB)', r.stdout, re.S):
        v = float(m.group(2)) * {'KB': 1 / 1024, 'MB': 1, 'GB': 1024}[m.group(3)]
        found[int(m.group(1))] = round(v, 1)
    return found

def webkit_pids(after):
    r = sh(['ps', '-A', '-o', 'pid=,lstart=,comm='])
    pids = {}
    for line in r.stdout.splitlines():
        m = re.match(r'\s*(\d+)\s+(\w{3} \w{3}\s+\d+ [\d:]+ \d{4})\s+(.*)$', line)
        if not m or 'com.apple.WebKit' not in m.group(3): continue
        started = time.mktime(time.strptime(m.group(2), '%a %b %d %H:%M:%S %Y'))
        if started >= after - 2: pids[int(m.group(1))] = m.group(3).rsplit('/', 1)[-1]
    return pids

def powermetrics(tag, n):
    r = sh(['sudo', 'powermetrics', '-i', '1000', '-n', str(n), '--samplers', 'tasks,gpu_power',
            '--show-process-gpu', '--show-process-energy'])
    (OUT / f'powermetrics-{tag}.txt').write_text(r.stdout + '\n--- stderr ---\n' + r.stderr)

results = {}
server = subprocess.Popen([sys.executable, '-m', 'http.server', '5731', '--bind', '127.0.0.1'], cwd=BUNDLE_ROOT,
                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
time.sleep(1)
ws = int(sh(['pgrep', '-x', 'WindowServer']).stdout.split()[0])
try:
    for run, mode in enumerate(MODES):
        tag = f'{mode}-{run}'
        url = f'http://127.0.0.1:5731/official/index.html?pageId={PAGE}&porthole={mode}'
        start = time.time()
        top = subprocess.Popen(['top', '-l', '0', '-s', '1', '-n', '400', '-o', 'cpu', '-stats', 'pid,command,cpu,power'],
                               stdout=open(OUT / f'top-{tag}.txt', 'w'), stderr=subprocess.DEVNULL)
        proc = subprocess.Popen([HARNESS, url, MESSAGES], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        log, marks, phases, pids = [], {}, {}, {}
        pm_threads = []
        for line in proc.stdout:
            line = line.rstrip(); log.append(line); print(mode, line, flush=True)
            if line.startswith('STATS'):
                pids = {proc.pid: 'harness', **webkit_pids(start), ws: 'WindowServer'}
                log.append('PIDS ' + json.dumps(pids))
            m = re.match(r'MARK (\w+) (begin|end) ([\d.]+)', line)
            if m and pids:
                phase, edge, at = m.group(1), m.group(2), float(m.group(3))
                ct = cputime(list(pids))
                if edge == 'begin':
                    marks[phase] = (at, ct)
                    if phase == 'focused' and mode == 'live':
                        sh(['screencapture', '-x', str(OUT / f'screen-{tag}.png')])
                    if phase in ('focused', 'unfocused'):
                        t = threading.Thread(target=powermetrics, args=(f'{tag}-{phase}', 15)); t.start(); pm_threads.append(t)
                elif phase in marks:
                    t0, c0 = marks[phase]
                    span = at - t0
                    cpu = {pids[p]: round(100 * (ct.get(p, 0) - c0.get(p, 0)) / span, 2) for p in pids if p in c0}
                    phases[phase] = {'seconds': round(span, 1), 'cpuPercentOfOneCore': cpu,
                                     'footprintMiB': {pids.get(p, str(p)): v for p, v in footprint(list(pids), f'{tag}-{phase}').items()},
                                     'rssMiB': {pids.get(p, str(p)): round(v, 1) for p, v in rss(list(pids)).items()}}
            f = re.match(r'FPS (\w+) (.*)', line)
            if f: phases.setdefault('fps', {})['raf'] = f.group(2)
        proc.wait(timeout=30); top.terminate()
        for t in pm_threads: t.join(timeout=60)
        # Energy impact (top POWER) medians per phase for the sampled pids.
        samples, stamp = [], None
        for line in (OUT / f'top-{tag}.txt').read_text(errors='replace').splitlines():
            m = re.match(r'(\d{4}/\d\d/\d\d \d\d:\d\d:\d\d)', line)
            if m: stamp = time.mktime(time.strptime(m.group(1), '%Y/%m/%d %H:%M:%S')); continue
            r = re.match(r'\s*(\d+)\s+(.+?)\s+([\d.]+)\s+([\d.]+)\s*$', line)
            if r and stamp and int(r.group(1)) in pids: samples.append((stamp, pids[int(r.group(1))], float(r.group(3)), float(r.group(4))))
        for phase, (t0, _) in marks.items():
            if phase not in phases or 'seconds' not in phases[phase]: continue
            t1 = t0 + phases[phase]['seconds']
            per = {}
            for at, name, cpu, power in samples:
                if t0 + 1 <= at <= t1: per.setdefault(name, []).append(power)
            phases[phase]['energyImpactMedian'] = {k: round(statistics.median(v), 2) for k, v in per.items()}
        results[tag] = {'phases': phases, 'log': [l for l in log if not l.startswith('MARK')]}
finally:
    server.terminate()
(OUT / 'results.json').write_text(json.dumps(results, indent=2))
lines = ['| mode | phase | CPU % (harness / WebContent / GPU / WindowServer) | energy impact median (sum of ours) | footprint MiB (sum of ours) | rAF |', '|---|---|---|---|---|---|']
for mode, r in results.items():
    for phase in ('focused', 'unfocused', 'minimized'):
        p = r['phases'].get(phase)
        if not p: continue
        c = p['cpuPercentOfOneCore']
        cpu = ' / '.join(str(round(sum(v for k, v in c.items() if needle in k), 2)) for needle in ('harness', 'WebContent', 'GPU', 'WindowServer'))
        ei = round(sum(v for k, v in p.get('energyImpactMedian', {}).items() if k != 'WindowServer'), 2)
        fp = round(sum(v for k, v in p['footprintMiB'].items() if k != 'WindowServer'), 1)
        lines.append(f"| {mode} | {phase} | {cpu} | {ei} | {fp} | {r['phases'].get('fps', {}).get('raf', '') if phase == 'focused' else ''} |")
(OUT / 'summary.md').write_text('\n'.join(lines) + '\n')
print('\n'.join(lines))
if os.environ.get('GITHUB_STEP_SUMMARY'):
    with open(os.environ['GITHUB_STEP_SUMMARY'], 'a') as s: s.write('\n'.join(lines) + '\n')
