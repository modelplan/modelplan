# SPDX-License-Identifier: MIT
"""Bounded WebKit-family snapshots and identity-checked resident counters."""
import ctypes,json,os,subprocess,time
from pathlib import Path

def executable(pid):
    lib=ctypes.CDLL('/usr/lib/libproc.dylib');buf=ctypes.create_string_buffer(4096)
    return Path(buf.value.decode()).name if lib.proc_pidpath(pid,buf,len(buf))>0 else None

def snapshot(session,lookup):
    # Explicitly authorized WebKit-family filter in the effective-user session.
    # Only PIDs are returned; no argv/environment or unrelated process inventory.
    r=subprocess.run(['/usr/bin/pgrep','-u',str(os.geteuid()),'-f',r'(^|/)com\.apple\.WebKit\.[A-Za-z.]+( |$)'],capture_output=True,text=True)
    processes=[]
    if r.returncode not in (0,1):return dict(scope='unsupported',sessionID=session,processes=[],reason='WebKit-filter-unavailable')
    for token in r.stdout.split():
        if not token.isdecimal():continue
        pid=int(token);name=executable(pid)
        if not name or not name.startswith('com.apple.WebKit.'):continue
        ident=lookup(pid)
        if ident is None:continue
        kind='GPU' if name=='com.apple.WebKit.GPU' else 'WebContent' if name.startswith('com.apple.WebKit.WebContent') else 'OtherWebKit'
        processes.append(ident|dict(kind=kind,helper=name))
    return dict(scope='effective-user-WebKit-family',sessionID=session,timestamp=time.time(),processes=processes)

def qualify(before,after,logged,known=()):
    wc={'status':'unsupported'};gpu={'status':'unsupported'};aux=[]
    key=lambda p:(p.get('pid'),p.get('startSeconds'),p.get('startMicroseconds'))
    if logged.get('status')=='attributed':wc={'status':'attributed',**{k:logged[k] for k in ('pid','startSeconds','startMicroseconds')}}
    if before.get('scope')!='effective-user-WebKit-family' or after.get('scope')!=before['scope'] or before.get('sessionID')!=after.get('sessionID'):
        return dict(WebContent=wc,GPU=gpu,auxiliary=aux,reason='scoped-snapshot-unavailable')
    owned={key(p) for p in known};foreign=[p for p in before['processes'] if key(p) not in owned]
    if foreign:return dict(WebContent=wc,GPU=gpu,auxiliary=aux,reason='preexisting-WebKit-host-prevents-isolation')
    old={key(p) for p in before['processes']};new=[p for p in after['processes'] if key(p) not in old or key(p) in owned]
    candidates=[p for p in new if p['kind']=='GPU']
    unassigned=[p for p in new if p['kind']=='WebContent' and key(p)!=key(logged) and key(p) not in owned]
    other=[p for p in new if p['kind']=='OtherWebKit']
    names=[p['helper'] for p in other]
    if len(set(names))!=len(names):unassigned+=other
    else:aux=[dict(status='attributed',**p) for p in other]
    reason=None
    if unassigned:aux=[]
    if len(candidates)==1 and not unassigned:gpu=dict(status='attributed',**candidates[0])
    elif not candidates:reason='no-attributable-GPU-helper; WindowServer-GPU-work-not-attributable'
    else:reason='ambiguous-or-unattributed-WebKit-host'
    return dict(WebContent=wc,GPU=gpu,auxiliary=aux,reason=reason,method='pre/post WebKit-family PID+start diff; logged own-view WebContent; registered retained helpers')

def rss(expected,lookup):
    # ps RSS is resident KiB, unlike top MEM's physical footprint. Preserve a
    # separate ps-rss provenance; never merge/relabel it as a top memory reading.
    matches=lambda p:p is not None and all(p.get(k)==expected.get(k) for k in ('pid','startSeconds','startMicroseconds'))
    if not matches(lookup(expected['pid'])):return None
    p=subprocess.run(['/bin/ps','-p',str(expected['pid']),'-o','rss='],capture_output=True,text=True,timeout=3)
    value=p.stdout.strip()
    if p.returncode or not value.isdecimal() or not matches(lookup(expected['pid'])):return None
    return int(value)*1024
