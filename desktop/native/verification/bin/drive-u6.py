# SPDX-License-Identifier: MIT
"""U6-specific operator Drive controller using the unchanged shared lease/cleanup helpers."""
import argparse,hashlib,importlib.util,json,os,signal,subprocess,sys,time,shutil
from pathlib import Path
from admission import load_and_admit
BASE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('shared_cleanup',BASE/'cleanup-run.py');cleanup=importlib.util.module_from_spec(spec);spec.loader.exec_module(cleanup)
def write(path,data):
    path=Path(path);temp=path.with_suffix(path.suffix+'.tmp');temp.write_text(json.dumps(data));temp.replace(path)
def admit(c,now):
    if c.get('profile')!='synthetic':raise ValueError('synthetic-profile-required')
    if not c['start']<=now<c['expiresAt'] or not 0<c['expiresAt']-c['start']<=1200:raise ValueError('invalid-window')
    for name,n in [('head',40),('binarySHA256',64)]:
        value=c.get(name,'')
        if len(value)!=n or any(x not in '0123456789abcdef' for x in value):raise ValueError('invalid-subject')
    if Path(c['home']).resolve()!=Path(c['scratch']).resolve()/'home' or Path(c['tmp']).resolve()!=Path(c['scratch']).resolve()/'tmp':raise ValueError('synthetic-root-mismatch')
    if c['environment'].get('HOME')!=c['home'] or c['environment'].get('TMPDIR','').rstrip('/')!=c['tmp']:raise ValueError('profile-environment-mismatch')
    return True
def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--config',type=Path,required=True);a=parser.parse_args();c=json.loads(a.config.read_text());admit(c,time.time())
    out=Path(c['batch']);scratch=Path(c['scratch']);assert out.is_dir() and scratch.is_dir()
    binary=Path(c['binary']);assert hashlib.sha256(binary.read_bytes()).hexdigest()==c['binarySHA256']
    locks=Path(c['locks']);owned=[];app=None;guardian=None;identity=None
    stop=Path(c['stopPath']);lease=Path(c['leasePath']);finish=out/'operator-finish.json'
    if stop.resolve()!=(out/'stop.json').resolve():raise ValueError('stop-path-mismatch')
    contract=dict(profile='synthetic',binarySHA256=c['binarySHA256'],argv=[str(binary)],
                  leasePath=str(lease),releasePath=c['releasePath'],stopPath=str(stop),
                  expectedLease=dict(runID=c['runID'],epoch=c['epoch'],notBefore=c['start'],expiresAt=c['expiresAt']),
                  requiredSeconds=30,booking=c.get('booking'))
    load_and_admit(contract)
    result=dict(runID=c['runID'],epoch=c['epoch'],headSHA=c['head'],profile='synthetic',outcome='not-run',appStarted=False)
    try:
        if any((locks/f'slot{i}').exists() for i in (1,2)):raise RuntimeError('resource-busy-before-launch')
        for name in ['M1-candidate-gui','slot1']:
            lock=locks/name;lock.mkdir();write(lock/'owner.json',dict(runID=c['runID'],epoch=c['epoch'],pid=os.getpid()));owned.append(lock)
        if sum((locks/f'slot{i}').exists() for i in (1,2))!=1:raise RuntimeError('resource-contention')
        if shutil.disk_usage(c['resourceRoot']).free-2*3430940672<8589934592:raise RuntimeError('resource-disk-floor')
        gc=scratch/'guardian.json';write(gc,c|dict(controllerPID=os.getpid(),lease=str(lease),stop=str(stop)))
        guardian=subprocess.Popen([sys.executable,str(BASE/'drive-scenario.py'),'--guardian',str(gc)],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        deadline=time.monotonic()+3
        while not lease.exists() and time.monotonic()<deadline:time.sleep(.1)
        load_and_admit(contract)
        native_contract=scratch/'native-guard.json';write(native_contract,dict(runID=c['runID'],epoch=c['epoch'],start=c['start'],expiresAt=c['expiresAt'],lease=str(lease),stop=str(stop),observations=str(out/'native-observations.jsonl')))
        with (scratch/'app-stdout.log').open('w') as stdout,(scratch/'app-stderr.log').open('w') as stderr:
            app=subprocess.Popen([str(binary),'--u6-drive-contract',str(native_contract)],env=c['environment'],stdout=stdout,stderr=stderr,start_new_session=True)
            identity=cleanup.identity(app.pid);assert identity is not None
            result['appStarted']=True;write(out/'launch.json',dict(runID=c['runID'],epoch=c['epoch'],ownedPID=app.pid,sourceHead=c['head']))
            while app.poll() is None and not stop.exists() and not finish.exists() and time.time()<c['expiresAt']:
                if shutil.disk_usage(c['resourceRoot']).free-2*3430940672<8589934592:raise RuntimeError('resource-disk-floor')
                time.sleep(.2)
            if finish.exists():result['operatorReceipts']=json.loads(finish.read_text());result['outcome']='operator-finished'
            elif stop.exists():result['reason']='stop-hook'
            elif app.poll() is not None:result['reason']='subject-exited'
            else:result['outcome']='timeout';result['reason']='absolute-deadline'
    except Exception as e:result['reason']=str(e) if isinstance(e,RuntimeError) else type(e).__name__
    finally:
        if not stop.exists():write(stop,dict(runID=c['runID'],epoch=c['epoch'],stop=True,reason='run-ended'))
        if app is not None:
            try:app.wait(timeout=8)
            except subprocess.TimeoutExpired:
                if cleanup.matches(cleanup.identity(app.pid),identity):os.killpg(app.pid,signal.SIGTERM)
                try:app.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    if cleanup.matches(cleanup.identity(app.pid),identity):os.killpg(app.pid,signal.SIGKILL)
                    app.wait(timeout=5)
        if guardian is not None:
            try:guardian.wait(timeout=3)
            except subprocess.TimeoutExpired:guardian.terminate();guardian.wait(timeout=3)
        for lock in owned:
            if lock.exists() and json.loads((lock/'owner.json').read_text()).get('runID')==c['runID']:(lock/'owner.json').unlink();lock.rmdir()
        result['cleanup']=dict(ownedAppExited=app is None or app.poll() is not None,guardianExited=guardian is None or guardian.poll() is not None,leaseReleased=True,scratchRemoved=cleanup.remove_scratch(scratch,['home','tmp']))
        result['ownedExitCode']=None if app is None else app.returncode
        write(out/'result.json',result);print(json.dumps({'runID':c['runID'],'outcome':result['outcome'],'appStarted':result['appStarted'],'cleanup':result['cleanup']}),flush=True)
if __name__=='__main__':main()
