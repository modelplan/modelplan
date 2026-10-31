# SPDX-License-Identifier: MIT
"""M1-only bounded U6 actions against Launch's registered synthetic subject."""
import argparse,json,os,subprocess,sys,time
from pathlib import Path

BIN=Path(__file__).resolve().parents[1]/'bin'
U6=Path(__file__).resolve().parent
sys.path.insert(0,str(BIN))
from admission import load_and_admit

def uptime():return time.clock_gettime(time.CLOCK_UPTIME_RAW)
def native(batch,run,epoch,pid):
    try:
        return [r for line in (batch/'native-observations.jsonl').read_text().splitlines() if line.strip()
                for r in [json.loads(line)] if r.get('runID')==run and r.get('epoch')==epoch and r.get('pid')==pid]
    except (OSError,ValueError,AttributeError):return []
def await_row(batch,run,epoch,pid,predicate,seconds):
    deadline=time.monotonic()+seconds
    while time.monotonic()<deadline:
        found=next((r for r in native(batch,run,epoch,pid) if predicate(r)),None)
        if found:return found
        time.sleep(.05)
    raise ValueError('not-delivered')
def command(args,config,timeout=20):
    load_and_admit(config)
    env=os.environ.copy();env['PYTHONDONTWRITEBYTECODE']='1'
    result=subprocess.run(args,env=env,text=True,capture_output=True,timeout=timeout)
    if result.returncode:raise ValueError('not-delivered')
    return result
def finish(batch,run,epoch,pid,steps,reason):
    receipt=dict(schema='u6-actions/1',runID=run,epoch=epoch,pid=pid,mono=uptime(),steps=steps,
                 outcome='pass' if reason is None else 'not-run',reason=reason)
    with (batch/'operator-finish.json').open('x') as stream:json.dump(receipt,stream,sort_keys=True);stream.write('\n')
def request_stop(config):
    path=Path(config['stopPath'])
    try:
        with path.open('x') as stream:json.dump(dict(runID=config['expectedLease']['runID'],
            epoch=config['expectedLease']['epoch'],stop=True,reason='u6-action-refused'),stream)
    except FileExistsError:pass
def run(config_path,pointer_binary):
    config=json.loads(Path(config_path).read_text());batch=Path(config['batch']);lease=config['expectedLease']
    run,epoch=lease['runID'],lease['epoch']
    pid=0
    steps={key:'not-run' for key in ('dock','menuA','refresh','menuB','privateTitle','trackedClear')}
    current='dock'
    def py(path,*args):return command([sys.executable,'-B',str(path),*map(str,args)],config)
    try:
        load_and_admit(config)
        reg=json.loads(Path(config['subjectPidPath']).read_text());pid=reg.get('pid')
        if type(pid) is not int or pid<=0 or reg.get('runID')!=run or reg.get('epoch')!=epoch:raise ValueError('registered-subject-invalid')
        await_row(batch,run,epoch,pid,lambda r:r.get('event')=='started',15)
        py(BIN/'u6-pointer-plan.py','make','--config',config_path,'--kind','dock')
        command([str(pointer_binary),'--plan',str(batch/'dock-pointer-plan.json')],config)
        py(BIN/'u6-pointer-plan.py','check','--config',config_path,'--kind','dock')
        py(U6/'capture_owned.py','--config',config_path)
        steps['dock']='pass';current='menuA'

        py(BIN/'u6-pointer-plan.py','make','--config',config_path,'--kind','status')
        command([str(pointer_binary),'--plan',str(batch/'status-pointer-plan.json')],config)
        py(BIN/'u6-pointer-plan.py','check','--config',config_path,'--kind','status')
        a=await_row(batch,run,epoch,pid,lambda r:r.get('event')=='menu-begin' and r.get('checks',{}).get('surface')=='status',3)
        a_session=a['checks']['sessionID'];steps['menuA']='pass';current='refresh'
        py(U6/'prepare_menu_plan.py','--config',config_path)
        command([str(pointer_binary),'--status-menu-plan',str(batch/'menu-plan.json')],config,timeout=10)
        refresh=await_row(batch,run,epoch,pid,lambda r:r.get('kind')=='refresh' and r.get('phase') in ('completed','failed')
                          and r.get('sessionID')==a_session,60)
        if refresh.get('phase')!='completed':raise ValueError('engine-error')
        await_row(batch,run,epoch,pid,lambda r:r.get('event')=='menu-end' and r.get('checks',{}).get('sessionID')==a_session,5)
        steps['refresh']='pass';current='menuB'

        py(BIN/'u6-pointer-plan.py','make','--config',config_path,'--kind','status','--purpose','clear')
        command([str(pointer_binary),'--plan',str(batch/'status-pointer-clear-plan.json')],config)
        py(BIN/'u6-pointer-plan.py','check','--config',config_path,'--kind','status','--purpose','clear')
        b=await_row(batch,run,epoch,pid,lambda r:r.get('event')=='menu-begin' and r.get('checks',{}).get('surface')=='status'
                    and r.get('checks',{}).get('sessionID')!=a_session,3)
        b_session=b['checks']['sessionID'];steps['menuB']='pass';current='privateTitle'
        seed=json.loads((batch/'synthetic-seed.json').read_text())
        await_row(batch,run,epoch,pid,lambda r:r.get('event')=='menu-private-title-visible'
                  and r.get('checks',{}).get('sessionID')==b_session
                  and r.get('checks',{}).get('titleSHA256')==seed.get('titleSHA256'),3)
        steps['privateTitle']='pass';current='trackedClear'
        py(U6/'consent_reset.py','--config',config_path)
        clear=await_row(batch,run,epoch,pid,lambda r:r.get('event')=='accepted-clear'
                        and b_session in r.get('checks',{}).get('scrubbedSessionIDs',[]),5)
        await_row(batch,run,epoch,pid,lambda r:r.get('event')=='menu-scrubbed' and r.get('seq',0)>clear.get('seq',0)
                  and r.get('checks',{}).get('sessionID')==b_session,5)
        steps['trackedClear']='pass';finish(batch,run,epoch,pid,steps,None)
    except (OSError,ValueError,subprocess.TimeoutExpired,KeyError) as error:
        steps[current]='not-run';request_stop(config)
        if not (batch/'operator-finish.json').exists():finish(batch,run,epoch,pid,steps,'not-delivered')
        raise SystemExit(3) from error

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--config',type=Path,required=True)
    p.add_argument('--pointer-binary',type=Path,required=True)
    a=p.parse_args();run(a.config,a.pointer_binary)
