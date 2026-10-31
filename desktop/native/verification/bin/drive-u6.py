# SPDX-License-Identifier: MIT
"""U6 Dock/menu scenario for CONTROLLER_MODE=launch; --config is the same run config launch.py executes.
`prepare` (before launch.py): live admission, then slot/contention/disk-floor resources and the native contract.
`drive` (after launch.py): drives only the subject launch.py registered with the guardian; it never starts or
signals a process. Closing is the stop file, acted on by launch.py and bin/guardian.py; Drive only observes it,
also requesting it when the disk floor is breached mid-run."""
import argparse,hashlib,json,shutil,sys,time,uuid
from pathlib import Path
from admission import load_and_admit
from guardian import cleanup,identity,launcher_lost
import homeseed
FLAG='--u6-drive-contract';LOCKS=('M1-candidate-gui','slot1')
DISK_RESERVE=2*3430940672;DISK_FLOOR=8589934592
REGISTER_SECONDS=15;CLOSE_SECONDS=25 # launch.py TERM 10 s + KILL; guardian TERM 10 s + KILL 5 s
QUIT_EVENTS=('stop-or-lease-expired','owner-preempted') # U6DriveGuard.finish rows: the app's own NSApplication.terminate
def write(path,data):
    path=Path(path);temp=path.with_suffix(path.suffix+'.tmp');temp.write_text(json.dumps(data));temp.replace(path)
def read(path):return json.loads(Path(path).read_text())
def run_identity(c):e=c['expectedLease'];return e['runID'],e['epoch'],e['notBefore'],e['expiresAt']
def native_contract(c):return Path(c['scratch']).resolve()/'native-guard.json'
def failure(e):return str(e) if isinstance(e,RuntimeError) else type(e).__name__ # OS messages can carry paths
def admit(c,now):
    if c.get('profile')!='synthetic':raise ValueError('synthetic-profile-required')
    if c.get('scenario')!='u6':raise ValueError('scenario-must-be-u6') # bin/scenarios.json entry
    e=c.get('expectedLease');start,end=(e.get('notBefore'),e.get('expiresAt')) if isinstance(e,dict) else (None,None)
    if any(type(x) not in (int,float) for x in (start,end)) or not start<=now<end or not 0<end-start<=1200:raise ValueError('invalid-window')
    for name,n in [('head',40),('binarySHA256',64)]:
        value=c.get(name,'')
        if not isinstance(value,str) or len(value)!=n or any(x not in '0123456789abcdef' for x in value):raise ValueError('invalid-subject')
    scratch=Path(c['scratch']).resolve()
    if Path(c['syntheticHome']).resolve()!=scratch/'home' or Path(c['syntheticTmp']).resolve()!=scratch/'tmp':raise ValueError('synthetic-root-mismatch')
    argv=c.get('argv') # launch.py passes the U6 flag; Drive never builds its own argv
    if not isinstance(argv,list) or len(argv)!=3 or argv[1]!=FLAG or Path(argv[2]).resolve()!=native_contract(c):raise ValueError('u6-argv-mismatch')
    if Path(c['stopPath']).resolve()!=(Path(c['batch'])/'stop.json').resolve():raise ValueError('stop-path-mismatch')
    if Path(c.get('preparedReceiptPath') or '').resolve()!=(Path(c['batch'])/'prepared.json').resolve():raise ValueError('prepared-receipt-required') # launch.py refuses without it
    if not isinstance(c.get('subjectPidPath'),str) or not c['subjectPidPath']:raise ValueError('subject-registration-required')
    if c.get('syntheticHomeSeed') is not None and Path(c['syntheticHomeSeed']).resolve()!=scratch/'home-seed':raise ValueError('home-seed-path-mismatch') # removed after closure
    return True
def scratch_names(c):return ['home','tmp']+(['home-seed'] if c.get('syntheticHomeSeed') is not None else []) # removed only after closure
def request_stop(c,reason):
    stop=Path(c['stopPath']);run,epoch,_,_=run_identity(c)
    try:
        if not stop.exists():write(stop,dict(runID=run,epoch=epoch,stop=True,reason=reason))
    except OSError:pass # a missing batch has no launchable receipt either
def low_disk(c):return shutil.disk_usage(c['resourceRoot']).free-DISK_RESERVE<DISK_FLOOR
def owner(lock):
    try:return read(lock/'owner.json').get('attempt')
    except (OSError,ValueError,AttributeError):return None
def release(locks,attempt):
    """Release only locks holding this attempt's token; True when none of them remain."""
    for lock in map(Path,locks):
        if attempt and owner(lock)==attempt:(lock/'owner.json').unlink();lock.rmdir()
    return not attempt or all(owner(Path(lock))!=attempt for lock in locks)
def prepared(c):
    """This attempt's receipt (token and locks), or None when preparation never succeeded."""
    try:r=read(c['preparedReceiptPath'])
    except (OSError,ValueError):return None
    return r if isinstance(r,dict) and isinstance(r.get('attempt'),str) and isinstance(r.get('locks'),list) else None
def prepare(c,now):
    """Before launch.py: admission and every resource check; only success writes the receipt launch.py requires."""
    admit(c,now);run,epoch,start,end=run_identity(c)
    out=Path(c['batch']);scratch=Path(c['scratch']);locks=Path(c['locks']);observations=out/'native-observations.jsonl'
    attempt=uuid.uuid4().hex;owned=[] # Attempts of one booking share run/epoch; locks are released by this token only.
    try:
        if not out.is_dir() or not scratch.is_dir():raise ValueError('batch-or-scratch-missing')
        if any(x.exists() for x in (Path(c['preparedReceiptPath']),observations,out/'result.json')):raise ValueError('batch-not-fresh')
        load_and_admit(c) # Live lease/release/booking before any resource; launch.py rechecks before spawning.
        if hashlib.sha256(Path(c['argv'][0]).read_bytes()).hexdigest()!=c['binarySHA256']:raise ValueError('binary identity changed')
        if any((locks/f'slot{i}').exists() for i in (1,2)):raise RuntimeError('resource-busy-before-launch')
        for name in LOCKS:lock=locks/name;lock.mkdir();owned.append(lock);write(lock/'owner.json',dict(runID=run,epoch=epoch,attempt=attempt,role='U6-prepare'))
        if sum((locks/f'slot{i}').exists() for i in (1,2))!=1:raise RuntimeError('resource-contention')
        if low_disk(c):raise RuntimeError('resource-disk-floor')
        write(native_contract(c),dict(runID=run,epoch=epoch,start=start,expiresAt=end,lease=c['leasePath'],stop=c['stopPath'],observations=str(observations),menuRequest=str(out/'menu-request.json')))
        homeseed.check(c) # the synthetic profile seed (if any) is pinned into the receipt
        write(c['preparedReceiptPath'],dict(prepared=True,runID=run,epoch=epoch,attempt=attempt,binarySHA256=c['binarySHA256'],homeSeedSHA256=c.get('syntheticHomeSeedSHA256'),locks=[str(x) for x in owned]))
    except Exception as e:
        # One attempt, no retry: no receipt, this invocation's locks released, and the stop file also makes admission refuse.
        release(owned,attempt);request_stop(c,'u6-prepare-refused')
        if out.is_dir() and not (out/'result.json').exists():
            write(out/'result.json',dict(runID=run,epoch=epoch,headSHA=c['head'],profile='synthetic',outcome='not-run',appStarted=False,reason=failure(e)))
        raise
    print(json.dumps(dict(runID=run,epoch=epoch,prepared=True)),flush=True)
def alive(record):return cleanup.matches(identity(record['pid']),record)
def registered(pid_path,wait=None,clock=time.monotonic,sleep=time.sleep):
    """The subject launch.py registered: state running, same start identity, its launcher still attached."""
    end=clock()+(REGISTER_SECONDS if wait is None else wait)
    while True:
        try:record=read(pid_path)
        except (OSError,ValueError):record=None
        if isinstance(record,dict) and record.get('state')=='running':break
        if clock()>=end:raise RuntimeError('no-registered-subject')
        sleep(.2)
    if type(record.get('pid')) is not int or record['pid']<=0 or not alive(record):raise RuntimeError('subject-identity-mismatch')
    if launcher_lost(pid_path):raise RuntimeError('subject-launcher-lost')
    return record
def bound(observations,run,epoch,record,wait=None,clock=time.monotonic,sleep=time.sleep):
    """The registered subject read this run's native contract: its 'started' receipt carries the run/epoch."""
    end=clock()+(REGISTER_SECONDS if wait is None else wait)
    while alive(record):
        try:rows=[json.loads(x) for x in Path(observations).read_text().splitlines() if x.strip()]
        except (OSError,ValueError):rows=[]
        if any(isinstance(r,dict) and r.get('event')=='started' and r.get('runID')==run and r.get('epoch')==epoch for r in rows):return True
        if clock()>=end:break
        sleep(.2)
    raise RuntimeError('subject-run-receipt-missing')
def quit_receipt(observations,run,epoch):
    """Read only: the app's own row that it began its normal terminate on the native contract's stop path."""
    try:rows=[json.loads(x) for x in Path(observations).read_text().splitlines() if x.strip()]
    except (OSError,ValueError):rows=[]
    return next((r['event'] for r in rows if isinstance(r,dict) and r.get('runID')==run and r.get('epoch')==epoch and r.get('event') in QUIT_EVENTS),None)
def closed(pid_path):
    """Observed only: no registration means nothing launched; a registered subject must be gone."""
    try:record=read(pid_path)
    except FileNotFoundError:return True
    except (OSError,ValueError):return False
    return isinstance(record,dict) and record.get('state')=='running' and type(record.get('pid')) is int and not alive(record)
def drive(c,now,poll=.2,sleep=time.sleep):
    admit(c,now);run,epoch,_,end=run_identity(c)
    out=Path(c['batch']);scratch=Path(c['scratch']);stop=Path(c['stopPath']);finish=out/'operator-finish.json';pid_path=Path(c['subjectPidPath'])
    result=dict(runID=run,epoch=epoch,headSHA=c['head'],profile='synthetic',outcome='not-run',appStarted=False,launchedBy='launch.py')
    try:
        record=registered(pid_path) # first, so a refusal below is judged after launch.py registered or gave up
        load_and_admit(c);bound(out/'native-observations.jsonl',run,epoch,record)
        result['appStarted']=True;write(out/'launch.json',dict(runID=run,epoch=epoch,ownedPID=record['pid'],sourceHead=c['head'],registeredBy='launch.py'))
        breach=False
        while alive(record) and not stop.exists() and not finish.exists() and time.time()<end:
            if low_disk(c):breach=True;request_stop(c,'resource-disk-floor');break # closing stays with launch.py/guardian
            sleep(poll)
        if breach:result['reason']='resource-disk-floor'
        elif finish.exists():result['operatorReceipts']=read(finish);result['outcome']='operator-finished'
        elif stop.exists():result['reason']='stop-hook'
        elif not alive(record):result['reason']='subject-exited'
        else:result['outcome']='timeout';result['reason']='absolute-deadline'
    except Exception as e:result['reason']=failure(e)
    finally:
        running=result['appStarted'] and alive(record) # was there still a subject to ask to quit?
        request_stop(c,'run-ended') # launch.py and the guardian stop the registered subject on this file
        deadline=time.monotonic()+CLOSE_SECONDS
        while not closed(pid_path) and time.monotonic()<deadline:sleep(.2)
        gone=closed(pid_path);removed=[];r=prepared(c);prep=(r['locks'],r['attempt']) if r else None
        if gone: # resources and scratch are released only after closure is observed; otherwise they stay held
            try:removed=cleanup.remove_scratch(scratch,scratch_names(c))
            except (OSError,ValueError):pass
        if result['appStarted']: # normal quit: requested through the contract's stop path, acknowledged only by the app's own row
            event=quit_receipt(out/'native-observations.jsonl',run,epoch);result['quit']=dict(requested='native-contract-stop' if running else 'none-subject-already-exited',appAcknowledged=event is not None,appEvent=event)
        result['cleanup']=dict(ownedAppExited=gone,closedBy='launch.py+guardian',guardian='external-M1',
                               resourcesReleased=gone and release(*prep) if prep else gone,leaseReleased=False,scratchRemoved=removed)
        write(out/'result.json',result);print(json.dumps({'runID':run,'outcome':result['outcome'],'appStarted':result['appStarted'],'quit':result.get('quit'),'cleanup':result['cleanup']}),flush=True)
    return result
def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('step',choices=('prepare','drive'));parser.add_argument('--config',type=Path,required=True)
    a=parser.parse_args(argv);c=json.loads(a.config.read_text())
    if a.step=='prepare':prepare(c,time.time());return 0
    k=drive(c,time.time())['cleanup'] # 0 only when closure was observed and this run's resources are released
    return 0 if k['ownedAppExited'] and k['resourcesReleased'] and set(scratch_names(c))<=set(k['scratchRemoved']) else 3
if __name__=='__main__':sys.exit(main())
