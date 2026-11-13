#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Bounded packaged integration measurement in synthetic homes. No user account data.
Counts only the owned app and direct children whose executable is the bundled helper.
20ms samples are diagnostic peak estimates, not proof that a shorter spike did not occur.
"""
import ctypes, datetime, hashlib, json, os, pathlib, statistics, subprocess, sys, time
class Usage(ctypes.Structure):
    _fields_=[('uuid',ctypes.c_ubyte*16)]+[(n,ctypes.c_uint64) for n in ('user','system','wake','interrupt','pageins','wired','rss','footprint','birth','exit')]
class Timebase(ctypes.Structure):
    _fields_=[('numer',ctypes.c_uint32),('denom',ctypes.c_uint32)]
lib=ctypes.CDLL('/usr/lib/libSystem.B.dylib',use_errno=True)
lib.proc_pid_rusage.argtypes=[ctypes.c_int,ctypes.c_int,ctypes.c_void_p]
lib.proc_listchildpids.argtypes=[ctypes.c_int,ctypes.c_void_p,ctypes.c_int]
lib.proc_pidpath.argtypes=[ctypes.c_int,ctypes.c_void_p,ctypes.c_uint32]
base=Timebase();lib.mach_timebase_info(ctypes.byref(base))
def usage(pid):
    r=Usage()
    if lib.proc_pid_rusage(pid,0,ctypes.byref(r)): return None
    return {'pid':pid,'birth':r.birth,'cpuNs':(r.user+r.system)*base.numer/base.denom,'bytes':r.footprint}
def children(pid,helper):
    ids=(ctypes.c_int*64)();n=lib.proc_listchildpids(pid,ids,ctypes.sizeof(ids))
    result=[]
    # libproc's convenience wrapper returns a PID count, unlike proc_listpids' byte count.
    for child in list(ids)[:max(0,min(64,n))]:
        if child<=0: continue
        path=ctypes.create_string_buffer(4096)
        if lib.proc_pidpath(child,path,len(path))>0 and pathlib.Path(path.value.decode()).resolve()==helper:
            value=usage(child)
            if value: result.append(value)
    return result
app=pathlib.Path(sys.argv[1]).resolve();out=pathlib.Path(sys.argv[2]).resolve();out.mkdir(parents=True,exist_ok=False)
exe=app/'Contents/MacOS/ModelPlanCommunity';helper=(app/'Contents/Helpers/modelplan').resolve()
enumeration_probe=subprocess.Popen(['/bin/sleep','1'])
try:
    time.sleep(.05)
    assert any(r['pid']==enumeration_probe.pid for r in children(os.getpid(),pathlib.Path('/bin/sleep').resolve())), 'owned-child enumeration self-check failed'
finally:
    enumeration_probe.terminate();enumeration_probe.wait(timeout=3)
receipt={'schemaVersion':1,'method':'proc_pid_rusage / Mach timebase / monotonic; associated direct helper only',
         'sampleIntervalMs':20,'childEnumerationSelfCheck':True,'executableSHA256':hashlib.sha256(exe.read_bytes()).hexdigest(),'runs':[]}
for i in range(3):
    home=out/f'synthetic-home-{i}';now=datetime.datetime.now(datetime.timezone.utc)
    folder=home/'codex/sessions'/now.strftime('%Y/%m/%d');folder.mkdir(parents=True)
    stamp=(now-datetime.timedelta(seconds=10)).strftime('%Y-%m-%dT%H:%M:%SZ')
    rows=[{'timestamp':stamp,'type':'session_meta','payload':{'id':'synthetic','originator':'codex_cli_rs'}},
          {'timestamp':stamp,'type':'event_msg','payload':{'type':'token_count','info':None,'rate_limits':{'limit_id':'codex','primary':{'used_percent':20,'window_minutes':300,'resets_at':int(now.timestamp())+7200},'plan_type':'plus'}}}]
    log=folder/'rollout-synthetic.jsonl';log.write_text(''.join(json.dumps(r)+'\n' for r in rows));before=log.read_bytes()
    probe=out/f'probe-{i}.json';child=subprocess.Popen([str(exe),'--runtime-probe',str(home),str(probe),'92'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    samples=[];start=time.monotonic();buckets=[];previous=None;next_second=start+1
    try:
        while child.poll() is None and time.monotonic()-start<100:
            host=usage(child.pid)
            if not host: break
            related=children(child.pid,helper);t=time.monotonic()
            row={'elapsed':t-start,'host':host,'children':related,'familyBytes':host['bytes']+sum(r['bytes'] for r in related)}
            samples.append(row)
            if t>=next_second:
                if previous and host['birth']==previous['host']['birth']:
                    buckets.append({'elapsed':t-start,'hostCPUPercent':(host['cpuNs']-previous['host']['cpuNs'])/1e9/(t-previous['time'])*100,'hostBytes':host['bytes'],'familyBytes':row['familyBytes']})
                previous={'time':t,'host':host};next_second=t+1
            time.sleep(.02)
        assert child.wait(timeout=5)==0 and probe.exists(),'probe did not complete'
        assert log.read_bytes()==before,'personal fixture was modified'
        p=json.loads(probe.read_text());assert p['peakConcurrent']==1 and p['active']==0 and p['stoppedIdle']
        assert p['quotaWindows']>0 and p['actionable'],'synthetic observation was not usable'
        assert all(c['arguments'] in [['desktop','--json','--read-only'],['publication','--json','--offline'],['publication','--json']] for c in p['commands'])
        desktop=[c for c in p['commands'] if c['command']=='desktop'];assert len(desktop)>=2,'60s refresh not observed'
        assert any(59000<=b['startMs']-a['startMs']<=62000 for a,b in zip(desktop,desktop[1:])),'personal cadence'
        steady=[r for r in buckets if 30<=r['elapsed']<=91];cpu=sorted(r['hostCPUPercent'] for r in steady)
        summary={'medianHostCPU':statistics.median(cpu),'p95HostCPU':cpu[min(len(cpu)-1,int(.95*len(cpu)))],
            'medianHostBytes':statistics.median(r['hostBytes'] for r in steady),'peakFamilyBytes':max(r['familyBytes'] for r in samples),
            'maxConcurrentSampledChildren':max(len(r['children']) for r in samples),'personalLogUnchanged':True,
            'heartbeatMaxMs':p['heartbeatMaxMs'],'firstActionableProjectionMs':p['firstActionableProjectionMs'],
            'publicJoined':p['joinedPublication']}
        last_child=max((r['elapsed'] for r in samples if r['children']),default=None)
        assert last_child is not None, 'no helper observed; family peak proof is unavailable'
        if last_child is not None:
            settled=[r['familyBytes'] for r in samples if last_child+4.5<=r['elapsed']<=last_child+5.5]
            summary['familyBytesFiveSecondsAfterLastChild']=max(settled) if settled else None
        receipt['runs'].append({'summary':summary,'samples':samples,'oneSecondBuckets':buckets,'probe':p})
        (out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps(summary),flush=True)
    finally:
        if child.poll() is None:
            child.terminate()
            try:child.wait(timeout=3)
            except subprocess.TimeoutExpired:child.kill();child.wait(timeout=3)
