#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Release accessory baseline; own process only. No screen capture or permission changes.
Uses Darwin proc_pid_rusage cumulative CPU (Mach absolute units) and physical footprint.
Run three 30s warm + 60s/1Hz samples; raw samples retain PID and process birth time.
"""
import argparse, ctypes, hashlib, json, os, pathlib, statistics, subprocess, time

class Usage(ctypes.Structure):
    _fields_ = [('uuid',ctypes.c_ubyte*16)] + [(name,ctypes.c_uint64) for name in
        ('user','system','idle_wakes','interrupt_wakes','pageins','wired','resident','footprint','birth','exit')]
class Timebase(ctypes.Structure):
    _fields_ = [('numer',ctypes.c_uint32),('denom',ctypes.c_uint32)]
lib = ctypes.CDLL('/usr/lib/libSystem.B.dylib',use_errno=True)
lib.proc_pid_rusage.argtypes = [ctypes.c_int,ctypes.c_int,ctypes.c_void_p]
base = Timebase(); lib.mach_timebase_info(ctypes.byref(base))
def reading(pid):
    value=Usage()
    if lib.proc_pid_rusage(pid,0,ctypes.byref(value)):
        raise OSError(ctypes.get_errno(),'proc_pid_rusage')
    return {'pid':pid,'birth':value.birth,'time':time.monotonic(),
        'cpuNs':(value.user+value.system)*base.numer/base.denom,'bytes':value.footprint}
def percentile(values,p):
    return sorted(values)[max(0,int(len(values)*p+0.9999)-1)]
p=argparse.ArgumentParser(); p.add_argument('app'); p.add_argument('output'); p.add_argument('--runs',type=int,default=3)
p.add_argument('--warm',type=int,default=30); p.add_argument('--seconds',type=int,default=60)
a=p.parse_args(); output=pathlib.Path(a.output); output.mkdir(parents=True,exist_ok=False)
exe=pathlib.Path(a.app)/'Contents/MacOS/ModelPlanCommunity'
receipt={'schemaVersion':1,'method':'proc_pid_rusage v0 / monotonic / one-core CPU',
         'timebase':{'numer':base.numer,'denom':base.denom},'executableSHA256':hashlib.sha256(exe.read_bytes()).hexdigest(),
         'scope':'neutral accessory, no runner; no physical first-pixel claim','runs':[]}
for run in range(a.runs):
    child=subprocess.Popen([str(exe)],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    try:
        start=time.monotonic(); cold=[]
        for deadline in (0.2,1,5,a.warm):
            time.sleep(max(0,start+deadline-time.monotonic())); cold.append(reading(child.pid))
        rows=[]; previous=reading(child.pid)
        for _ in range(a.seconds):
            time.sleep(1); current=reading(child.pid)
            if current['birth'] != previous['birth']: raise RuntimeError('PID reused')
            current['cpuPercent']=(current['cpuNs']-previous['cpuNs'])/1e9/(current['time']-previous['time'])*100
            rows.append(current); previous=current
        cpu=[r['cpuPercent'] for r in rows]; memory=[r['bytes'] for r in rows]
        receipt['runs'].append({'cold':cold,'samples':rows,'medianCPU':statistics.median(cpu),
            'p95CPU':percentile(cpu,.95),'peakCPU':max(cpu),'medianBytes':statistics.median(memory),'peakBytes':max(memory)})
        (output/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
        print(json.dumps({k:v for k,v in receipt['runs'][-1].items() if k not in ('cold','samples')}),flush=True)
    finally:
        child.terminate()
        try: child.wait(timeout=3)
        except subprocess.TimeoutExpired: child.kill(); child.wait(timeout=3)
