#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Joins the driver's phase events with the sampler's counters: per phase, CPU as % of one core
# (delta CPU time / wall time) per role and summed, median summed footprint, achieved frame rate
# and IOAccelerator utilisation. Prints Markdown and writes summary.json next to each run.
import json, pathlib, statistics, sys

def load(path): return [json.loads(l) for l in open(path) if l.strip()]

def run(dirpath):
    d = pathlib.Path(dirpath)
    events, samples = load(d / 'events.jsonl'), load(d / 'samples.jsonl')
    env = next((e for e in events if e['event'] == 'env'), {})
    phases, open_ = [], {}
    for e in events:
        key = (e.get('phase'), e.get('cycle'))
        if e['event'] == 'phase-start': open_[key] = e
        elif e['event'] == 'phase-end' and key in open_:
            phases.append((open_.pop(key), e))
    rows = []
    for s, e in phases:
        inside = [x for x in samples if s['t'] <= x['t'] <= e['t']]
        if len(inside) < 2: continue
        a, b = inside[0], inside[-1]; wall = b['t'] - a['t']
        def cpu_of(get):
            first, last = get(a), get(b); total = {}
            for pid, (role, ns) in last.items():
                if pid in first and first[pid][0] == role: total[role] = total.get(role, 0) + (ns - first[pid][1])
            return {k: round(100 * v / 1e9 / wall, 2) for k, v in total.items()}
        get = lambda x: {x['app']['pid']: ('App', x['app']['cpuNs']), **{h['pid']: (h['role'], h['cpuNs']) for h in x['helpers']}}
        roles = cpu_of(get)
        foot = statistics.median(x['app']['footprint'] + sum(h['footprint'] for h in x['helpers']) for x in inside)
        gpus = [x['gpu'].get('Device Utilization %') for x in inside if x.get('gpu') and 'Device Utilization %' in x['gpu']]
        s0, s1 = s.get('stats') or {}, e.get('stats') or {}
        fps = None
        if isinstance(s0.get('frames'), (int, float)) and isinstance(s1.get('frames'), (int, float)) and s1.get('t') and s0.get('t'):
            fps = round((s1['frames'] - s0['frames']) / ((s1['t'] - s0['t']) / 1000), 1)
        name = s['phase'] + (f"#{s['cycle']}" if s.get('cycle') else '')
        rows.append({'phase': name, 'seconds': round(wall, 1), 'cpuTotal': round(sum(roles.values()), 2), 'cpuByRole': roles,
                     'footprintMiB': round(foot / 2**20, 1), 'gpuDeviceUtilMedian': statistics.median(gpus) if gpus else None,
                     'fps': fps, 'canvas': f"{s0.get('canvasW')}x{s0.get('canvasH')}" if s0.get('canvasW') else None,
                     'failed': s0.get('failed'), 'renderer': s0.get('renderer'), 'active': s1.get('active'), 'scheduled': s1.get('scheduled')})
    (d / 'summary.json').write_text(json.dumps({'env': env, 'phases': rows}, indent=1))
    print(f"## {d.name}\n\nenv: {json.dumps({k: v for k, v in env.items() if k not in ('event', 't')})}\n")
    print('| phase | CPU % of one core (sum) | by role | footprint MiB | GPU util % | fps | canvas |')
    print('|---|---:|---|---:|---:|---:|---|')
    for r in rows:
        roles = ', '.join(f"{k} {v}" for k, v in sorted(r['cpuByRole'].items()))
        print(f"| {r['phase']} | {r['cpuTotal']} | {roles} | {r['footprintMiB']} | {r['gpuDeviceUtilMedian']} | {r['fps']} | {r['canvas']} |")
    print()

for p in sys.argv[1:]: run(p)
