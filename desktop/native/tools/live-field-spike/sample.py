#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Measurement only (cockpit-full-v1 spike). Launches the driver app, then samples the app and the WebKit
# helpers it is responsible for once a second: cumulative Mach CPU time and physical footprint
# (proc_pid_rusage), plus the IOAccelerator utilisation the OS reports. Same counters as measure-field.py.
import argparse, ctypes, json, os, pathlib, re, subprocess, time

parser = argparse.ArgumentParser()
parser.add_argument('app'); parser.add_argument('root'); parser.add_argument('out')
parser.add_argument('--plan', default='full'); parser.add_argument('--seconds', default='20')
args = parser.parse_args()
out = pathlib.Path(args.out).resolve(); out.mkdir(parents=True, exist_ok=False)
app = pathlib.Path(args.app).resolve()

class Usage(ctypes.Structure):
    _fields_ = [('uuid', ctypes.c_ubyte * 16)] + [(n, ctypes.c_uint64) for n in ('user', 'system', 'idle', 'interrupt', 'pageins', 'wired', 'rss', 'footprint', 'birth', 'exit')]
class TB(ctypes.Structure): _fields_ = [('numer', ctypes.c_uint32), ('denom', ctypes.c_uint32)]
lib = ctypes.CDLL('/usr/lib/libSystem.B.dylib', use_errno=True)
lib.proc_pid_rusage.argtypes = [ctypes.c_int, ctypes.c_int, ctypes.c_void_p]
tb = TB(); lib.mach_timebase_info(ctypes.byref(tb))
try:
    lib.responsibility_get_pid_responsible_for_pid.argtypes = [ctypes.c_int]
    lib.responsibility_get_pid_responsible_for_pid.restype = ctypes.c_int
    responsible = lib.responsibility_get_pid_responsible_for_pid
except AttributeError:
    responsible = None

def usage(pid):
    u = Usage()
    if lib.proc_pid_rusage(pid, 0, ctypes.byref(u)): return None
    return {'pid': pid, 'birth': u.birth, 'footprint': u.footprint, 'cpuNs': (u.user + u.system) * tb.numer / tb.denom}

def webkit():
    rows = subprocess.check_output(['ps', '-axo', 'pid=,comm='], text=True).splitlines()
    return {int(r.split()[0]): r.split()[-1].split('/')[-1] for r in rows if 'com.apple.WebKit.' in r}

def gpu():
    try:
        text = subprocess.check_output(['ioreg', '-r', '-d', '1', '-w', '0', '-c', 'IOAccelerator'], text=True, timeout=5)
    except Exception:
        return None
    found = {k: int(v) for k, v in re.findall(r'"(Device Utilization %|Renderer Utilization %|Tiler Utilization %)"=(\d+)', text)}
    return found or None

subprocess.run(['open', '-n', '-a', str(app), '--args', '--root', str(pathlib.Path(args.root).resolve()), '--out', str(out), '--plan', args.plan, '--seconds', args.seconds], check=True)
pidfile = out / 'pid'
for _ in range(300):
    if pidfile.exists() and pidfile.read_text().strip(): break
    time.sleep(0.1)
pid = int(pidfile.read_text().strip()); birth = usage(pid)['birth']
known = {}; t0 = time.time(); fallback = responsible is None
with open(out / 'samples.jsonl', 'w') as f:
    while True:
        me = usage(pid)
        if me is None or me['birth'] != birth or time.time() - t0 > 1500: break
        for p, name in webkit().items():
            if p in known: continue
            r = responsible(p) if responsible else -1
            if r == pid or (fallback and (usage(p) or {}).get('birth', 0) >= birth):
                known[p] = name
        helpers = []
        for p, name in list(known.items()):
            u = usage(p)
            if u is None: continue
            helpers.append(dict(u, role=name.replace('com.apple.WebKit.', '')))
        f.write(json.dumps({'t': time.time(), 'app': me, 'helpers': helpers, 'gpu': gpu()}) + '\n'); f.flush()
        time.sleep(1)
(out / 'sampler.json').write_text(json.dumps({'pid': pid, 'attribution': 'responsibility_get_pid_responsible_for_pid' if not fallback else 'birth-after-app', 'helpers': known}))
