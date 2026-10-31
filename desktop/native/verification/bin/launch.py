# SPDX-License-Identifier: MIT
"""Validate an explicit synthetic run; execute only with an existing fresh lease."""
import argparse,hashlib,json,subprocess,time
from pathlib import Path
from admission import validate,load_and_admit
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--config',type=Path,required=True);p.add_argument('--execute',action='store_true');a=p.parse_args()
    c=json.loads(a.config.read_text())
    if not a.execute:validate(c,time.time());print('Run contract valid; no process launched');return
    c=load_and_admit(c) # Read external records before creating synthetic resources.
    home=Path(c['syntheticHome']);tmp=Path(c['syntheticTmp'])
    home.mkdir(exist_ok=False);tmp.mkdir(exist_ok=False)
    binary=Path(c['argv'][0]).resolve(strict=True)
    if hashlib.sha256(binary.read_bytes()).hexdigest()!=c['binarySHA256']:raise ValueError('binary identity changed')
    c=load_and_admit(c) # Reread lease/release after filesystem/hash work, immediately before spawn.
    child=subprocess.Popen(c['argv'],env={'PATH':'/usr/bin:/bin','HOME':str(home),'TMPDIR':str(tmp),'LANG':'en_US.UTF-8'})
    print(json.dumps({'runID':c['lease']['runID'],'epoch':c['lease']['epoch'],'ownedPID':child.pid}),flush=True)
    if c.get('subjectPidPath'):write_pid(Path(c['subjectPidPath']),child.pid)
    # Stay attached: stop the child on the stop file, a stale guardian heartbeat, revocation or the deadline,
    # so a dead guardian still fails closed. Exit status 0 only when the child ended by itself.
    reason=supervise(child,c)
    print(json.dumps({'ownedPID':child.pid,'exit':child.returncode,'stoppedBy':reason}))
    raise SystemExit(0 if reason is None else 3)
def write_pid(path,pid):
    tmp=path.with_name(path.name+'.tmp');tmp.write_text(json.dumps({'pid':pid})+'\n');tmp.replace(path)
def stop_reason(c,now):
    if Path(c['stopPath']).exists():return 'stop-file'
    try:lease=json.loads(Path(c['leasePath']).read_text())
    except (OSError,ValueError):return 'lease-unreadable'
    if any(lease.get(k)!=c['lease'].get(k) for k in ('runID','epoch','notBefore','expiresAt')):return 'lease-identity-changed'
    if lease.get('ownerPreempted') is not False or lease.get('exclusive') is not True:return 'lease-revoked'
    if not isinstance(lease.get('guardianHeartbeatAt'),(int,float)) or now-lease['guardianHeartbeatAt']>3:return 'guardian-heartbeat-stale'
    if now>=lease['expiresAt']:return 'deadline'
    return None
def supervise(child,c,poll=0.5,clock=time.time,sleep=time.sleep):
    while child.poll() is None:
        reason=stop_reason(c,clock())
        if reason:
            child.terminate()
            try:child.wait(10)
            except subprocess.TimeoutExpired:child.kill();child.wait()
            return reason
        sleep(poll)
    return None
if __name__=='__main__':main()
