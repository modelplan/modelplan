#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Sample only explicitly supplied probe/receiver PIDs. No process enumeration or input injection."""
import argparse,ctypes,json,pathlib,statistics,time
class Usage(ctypes.Structure):
    _fields_=[('uuid',ctypes.c_ubyte*16)]+[(n,ctypes.c_uint64) for n in ('user','system','idle','interrupt','pageins','wired','rss','footprint','birth','exit')]
class Timebase(ctypes.Structure):
    _fields_=[('numer',ctypes.c_uint32),('denom',ctypes.c_uint32)]
lib=ctypes.CDLL('/usr/lib/libSystem.B.dylib',use_errno=True);lib.proc_pid_rusage.argtypes=[ctypes.c_int,ctypes.c_int,ctypes.c_void_p]
base=Timebase();lib.mach_timebase_info(ctypes.byref(base))
def sample(pid):
    value=Usage()
    if lib.proc_pid_rusage(pid,0,ctypes.byref(value)):raise OSError(ctypes.get_errno(),'proc_pid_rusage')
    return {'pid':pid,'birth':value.birth,'time':time.monotonic(),'cpuNs':(value.user+value.system)*base.numer/base.denom,'bytes':value.footprint}
p=argparse.ArgumentParser();p.add_argument('--pid',type=int,action='append',required=True);p.add_argument('--seconds',type=int,default=60);p.add_argument('--output',type=pathlib.Path,required=True);a=p.parse_args()
last={pid:sample(pid) for pid in a.pid};rows=[]
for _ in range(a.seconds):
    time.sleep(1)
    for pid in a.pid:
        current=sample(pid);prev=last[pid];assert current['birth']==prev['birth']
        current['cpuPercent']=(current['cpuNs']-prev['cpuNs'])/1e9/(current['time']-prev['time'])*100
        rows.append(current);last[pid]=current
summary=[]
for pid in a.pid:
    samples=[r for r in rows if r['pid']==pid];cpu=sorted(r['cpuPercent'] for r in samples)
    summary.append({'pid':pid,'medianCPU':statistics.median(cpu),'p95CPU':cpu[max(0,__import__('math').ceil(.95*len(cpu))-1)],'peakBytes':max(r['bytes'] for r in samples),'medianBytes':statistics.median(r['bytes'] for r in samples)})
a.output.write_text(json.dumps({'schemaVersion':1,'seconds':a.seconds,'cpuUnit':'one-core percent','memoryUnit':'physical footprint bytes','scope':'owned probe and receiver; excludes WindowServer','summary':summary,'samples':rows},indent=2)+'\n')
print(json.dumps(summary))
