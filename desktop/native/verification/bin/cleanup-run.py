# SPDX-License-Identifier: MIT
"""Cleanup only registered owned identities and explicitly disposable scratch."""
import argparse,ctypes,json,os,shutil,signal,time
from pathlib import Path
class BSDInfo(ctypes.Structure):
    _fields_=[('header',ctypes.c_uint32*12),('comm',ctypes.c_char*16),('name',ctypes.c_char*32),('tail',ctypes.c_uint32*6),('startSeconds',ctypes.c_uint64),('startMicroseconds',ctypes.c_uint64)]
def identity(pid):
    if type(pid) is not int or pid<=0:return None
    lib=ctypes.CDLL('/usr/lib/libproc.dylib');info=BSDInfo()
    if lib.proc_pidinfo(pid,3,0,ctypes.byref(info),ctypes.sizeof(info))!=ctypes.sizeof(info):return None
    if info.header[3]!=pid or info.header[5]!=os.geteuid():return None
    return dict(pid=pid,startSeconds=info.startSeconds,startMicroseconds=info.startMicroseconds)
def matches(actual,expected):return actual is not None and all(actual.get(k)==expected.get(k) for k in ('pid','startSeconds','startMicroseconds'))
def stop_owned(expected,lookup=identity,send=os.kill):
    actual=lookup(expected['pid'])
    if actual is None:return 'exited'
    if not matches(actual,expected):return 'unknown-identity-changed'
    send(expected['pid'],signal.SIGTERM)
    deadline=time.monotonic()+3
    while time.monotonic()<deadline:
        if lookup(expected['pid']) is None:return 'exited'
        time.sleep(.05)
    if matches(lookup(expected['pid']),expected):send(expected['pid'],signal.SIGKILL)
    return 'exited' if lookup(expected['pid']) is None else 'unknown'
def remove_scratch(root,names):
    root=Path(root).resolve(strict=True);removed=[]
    for name in names:
        p=Path(name)
        if p.is_absolute() or '..' in p.parts or not p.parts or p.parts[0] not in ('home','tmp'):raise ValueError('scratch allowlist rejected')
        if any((root/Path(*p.parts[:i])).is_symlink() for i in range(1,len(p.parts)+1)):raise ValueError('scratch symlink rejected')
        target=root/p
        if target.exists():shutil.rmtree(target) if target.is_dir() else target.unlink()
        removed.append(p.as_posix())
    return removed
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--registry',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();r=json.loads(a.registry.read_text())
    results=[dict(role=x['role'],status=stop_owned(x)) for x in r['owned']]
    out=dict(runID=r['runID'],epoch=r['epoch'],processes=results,cleaned=all(x['status']=='exited' for x in results))
    with a.output.open('x') as f:json.dump(out,f,indent=2)
if __name__=='__main__':main()
