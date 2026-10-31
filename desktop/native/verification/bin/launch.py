# SPDX-License-Identifier: MIT
"""Validate an explicit synthetic run; execute only with an existing fresh lease."""
import argparse,hashlib,json,signal,subprocess,sys,time
from pathlib import Path
from admission import validate,load_and_admit
from guardian import register,mark_launching
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--config',type=Path,required=True);p.add_argument('--execute',action='store_true');a=p.parse_args()
    c=json.loads(a.config.read_text())
    if not a.execute:validate(c,time.time());print('Run contract valid; no process launched');return
    c=load_and_admit(c) # Read external records before creating synthetic resources.
    check_prepared(c)
    home=Path(c['syntheticHome']);tmp=Path(c['syntheticTmp'])
    home.mkdir(exist_ok=False);tmp.mkdir(exist_ok=False)
    binary=Path(c['argv'][0]).resolve(strict=True)
    if hashlib.sha256(binary.read_bytes()).hexdigest()!=c['binarySHA256']:raise ValueError('binary identity changed')
    c=load_and_admit(c) # Reread lease/release after filesystem/hash work, immediately before spawn.
    check_prepared(c)
    pid_path=Path(c['subjectPidPath']) # Required: the guardian supervises this subject.
    launcher=mark_launching(pid_path) # Until registered, the guardian reports closure unconfirmed.
    # Exec gate: the child waits for one byte on stdin before exec'ing the subject (same PID). If launch
    # dies before releasing it, stdin reaches EOF and the child exits without ever running the subject.
    gate=[sys.executable,'-I','-c',GATE,*c['argv']]
    child=subprocess.Popen(gate,stdin=subprocess.PIPE,env={'PATH':'/usr/bin:/bin','HOME':str(home),'TMPDIR':str(tmp),'LANG':'en_US.UTF-8'})
    def stop_child(*_):
        child.terminate()
        try:child.wait(10)
        except subprocess.TimeoutExpired:child.kill();child.wait()
        raise SystemExit(3)
    for sig in (signal.SIGTERM,signal.SIGINT,signal.SIGHUP):signal.signal(sig,stop_child)
    try:
        register(pid_path,child.pid,launcher)
        child.stdin.write(b'g');child.stdin.close() # Registered: release the gate.
    except BaseException:
        stop_child() # Never leave an unregistered child running.
    print(json.dumps({'runID':c['lease']['runID'],'epoch':c['lease']['epoch'],'ownedPID':child.pid}),flush=True)
    # Stay attached: stop the child on the stop file, a stale guardian heartbeat, revocation or the deadline,
    # so a dead guardian still fails closed. Exit status 0 only when the child ended by itself.
    reason=supervise(child,c)
    print(json.dumps({'ownedPID':child.pid,'exit':child.returncode,'stoppedBy':reason}))
    raise SystemExit(0 if reason is None else 3)
def check_prepared(c):
    """Optional scenario preparation: a run config naming `preparedReceiptPath` launches only on that receipt
    (same run/epoch and binary), while every lock it lists is still held by the receipt's attempt token."""
    if 'preparedReceiptPath' not in c:return
    try:r=json.loads(Path(c['preparedReceiptPath']).read_text())
    except (OSError,ValueError,TypeError):raise ValueError('preparation receipt missing')
    if not isinstance(r,dict) or r.get('prepared') is not True or r.get('runID')!=c['lease'].get('runID') or r.get('epoch')!=c['lease'].get('epoch') \
            or r.get('binarySHA256')!=c['binarySHA256'] or not isinstance(r.get('attempt'),str) or not r['attempt'] or not isinstance(r.get('locks'),list) or not r['locks']:
        raise ValueError('preparation receipt mismatch')
    for lock in r['locks']:
        try:o=json.loads((Path(lock)/'owner.json').read_text())
        except (OSError,ValueError,TypeError):o=None
        if not isinstance(o,dict) or (o.get('attempt'),o.get('runID'),o.get('epoch'))!=(r['attempt'],r['runID'],r['epoch']):raise ValueError('prepared resources not held')
GATE='import os,sys\nif sys.stdin.buffer.read(1)!=b"g":sys.exit(97)\nos.execv(sys.argv[1],sys.argv[1:])'
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
