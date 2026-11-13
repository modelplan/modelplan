#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""B05 Release probe: 30s warm + 60s at 1Hz, three runs per state.
No personal reader, screenshots of other windows, permission changes or system reconfiguration.
CPU is cumulative Mach user+system time, converted to ns / monotonic wall / one core.
"""
import argparse,ctypes,hashlib,json,math,pathlib,statistics,subprocess,time
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
p=argparse.ArgumentParser();p.add_argument('app');p.add_argument('output');p.add_argument('--runs',type=int,default=3);p.add_argument('--warm',type=int,default=30);p.add_argument('--seconds',type=int,default=60);p.add_argument('--modes',default='base,jets1,jets2,jets6,steady,lamp,cursor');a=p.parse_args()
app=pathlib.Path(a.app).resolve();exe=app/'Contents/MacOS/ModelPlanPrimitiveProbe';out=pathlib.Path(a.output).resolve();out.mkdir(parents=True,exist_ok=False)
receipt={'schemaVersion':1,'executableSHA256':hashlib.sha256(exe.read_bytes()).hexdigest(),'warmSeconds':a.warm,'sampleSeconds':a.seconds,'sampleHz':1,'runs':[]}
for repeat in range(a.runs):
 for mode in a.modes.split(','):
    report=out/f'{repeat}-{mode}.json';duration=a.warm+a.seconds+2
    child=subprocess.Popen([str(exe),'--mode',mode,'--seconds',str(duration),'--receipt',str(report)],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    try:
        start=time.monotonic();time.sleep(a.warm);previous=sample(child.pid);rows=[]
        for i in range(a.seconds):
            time.sleep(1);current=sample(child.pid);assert current['birth']==previous['birth']
            current['cpuPercent']=(current['cpuNs']-previous['cpuNs'])/1e9/(current['time']-previous['time'])*100;rows.append(current);previous=current
        assert child.wait(timeout=12)==0 and report.exists(),'probe did not finish'
        probe=json.loads(report.read_text());assert not probe['interrupted'],'occluded/closed run is invalid; do not accept it'
        assert probe['cachePeakBytes']<=4_000_000 and probe['cacheAfterDispose']==0 and probe['cacheRefusals']==0
        expected=int(mode[4:]) if mode.startswith('jets') else 0
        assert probe['workingCount']==expected and len(set(probe['workingIDs']))==expected
        if expected:assert probe['animatingCount']==expected and probe['poseCount']==9
        cpu=sorted(r['cpuPercent'] for r in rows);memory=[r['bytes'] for r in rows]
        summary={'repeat':repeat,'mode':mode,'medianCPU':statistics.median(cpu),'p95CPU':cpu[max(0,math.ceil(.95*len(cpu))-1)],'peakCPU':max(cpu),'medianBytes':statistics.median(memory),'peakBytes':max(memory)}
        receipt['runs'].append({'summary':summary,'probe':probe,'samples':rows});(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps(summary),flush=True)
        # Fail early for a resource regression. Full interpretation compares matched on/off states.
        assert summary['medianCPU']<1.0,'unexpected whole-probe CPU; inspect before continuing'
    finally:
        if child.poll() is None:
            child.terminate()
            try:child.wait(timeout=3)
            except subprocess.TimeoutExpired:child.kill();child.wait(timeout=3)
print('Completed all requested cases; evaluate paired deltas and non-host limitations separately',flush=True)
