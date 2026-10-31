# SPDX-License-Identifier: MIT
"""M1-only bounded U6 actions against Launch's registered synthetic subject."""
import argparse,json,os,re,subprocess,sys,time
from pathlib import Path

BIN=Path(__file__).resolve().parents[1]/'bin'
U6=Path(__file__).resolve().parent
sys.path.insert(0,str(BIN))
sys.path.insert(0,str(U6))
from admission import still_admitted # launch admission checked the full budget once; every action rechecks this
from guardian import reason_code,BOUNDED_CODES
from u6_clock import system_uptime

uptime=system_uptime # ProcessInfo.systemUptime's clock on macOS; time.monotonic on Linux test hosts
def native(batch,run,epoch,pid):
    try:
        return [r for line in (batch/'native-observations.jsonl').read_text().splitlines() if line.strip()
                for r in [json.loads(line)] if r.get('runID')==run and r.get('epoch')==epoch and r.get('pid')==pid]
    except (OSError,ValueError,AttributeError):return []
def await_row(batch,run,epoch,pid,predicate,seconds):
    deadline=uptime()+seconds
    while uptime()<deadline:
        found=next((r for r in native(batch,run,epoch,pid) if predicate(r)),None)
        if found:return found
        time.sleep(.05)
    raise ValueError('not-delivered')
def pointer_diagnostic(config,label,status,stderr='',timed_out=False):
    if label not in ('dock-pointer','status-pointer','status-pointer-clear','menu-refresh','park-start','park-end'):raise ValueError('unknown')
    raw=stderr if isinstance(stderr,bytes) else stderr.encode('utf-8',errors='replace')
    sample=raw[:4096];codes=[]
    if timed_out:codes.append('timeout')
    if status is not None and status<0:codes.append('process-signaled')
    if b'Not enough bits' in sample or b'out of range' in sample:codes.append('integer-out-of-range')
    if b'Fatal error' in sample:codes.append('runtime-trap')
    if sample and not codes:codes.append('stderr-present')
    lease=config['expectedLease']
    receipt=dict(schema='u6-pointer-exit/1',runID=lease['runID'],epoch=lease['epoch'],
        exitStatus=status,signal=-status if status is not None and status<0 else None,
        stderrCodes=codes,stderrBytesCaptured=len(sample),stderrTruncated=len(raw)>len(sample),mono=uptime())
    # Fixed classifications only: never persist arbitrary stderr, stack paths,
    # argv, provider values or other host information in the evidence batch.
    with (Path(config['batch'])/(label+'.stderr')).open('x') as out:
        json.dump(receipt,out,sort_keys=True);out.write('\n')
    return receipt

TOOL_CODES={'park-geometry-missing','dock-not-collapsed','owned-frame-missing','subject-registration-invalid',
            'native-arrival-missing','park-input-invalid','physical-input-not-delivered','owner-preempted'}
def action_log(config,step,phase,**fields):
    if not re.fullmatch(r'[A-Za-z0-9_-]{1,64}',step):raise ValueError('unknown')
    lease=config['expectedLease']
    row=dict(schema='u6-action-log/1',runID=lease['runID'],epoch=lease['epoch'],mono=uptime(),substep=step,phase=phase,**fields)
    data=(json.dumps(row,sort_keys=True)+'\n').encode()
    fd=os.open(Path(config['batch'])/'action-log.jsonl',os.O_WRONLY|os.O_CREAT|os.O_APPEND,0o600)
    try:
        if os.write(fd,data)!=len(data):raise OSError('action-log-write-incomplete')
        os.fsync(fd)
    finally:os.close(fd)
def refusal(config,step,reason,status=None):
    if not re.fullmatch(r'[A-Za-z0-9_-]{1,64}',step):raise ValueError('unknown')
    lease=config['expectedLease']
    try:
        with (Path(config['batch'])/('action-refusal-'+step+'.json')).open('x') as out:
            json.dump(dict(schema='u6-action-refusal/1',runID=lease['runID'],epoch=lease['epoch'],substep=step,
                           reason=reason,exitStatus=status,mono=uptime()),out);out.write('\n')
    except FileExistsError:pass
def command_label(args,diagnostic):
    if diagnostic:return diagnostic
    name=Path(args[2]).name if len(args)>2 else ''
    if name=='u6-pointer-plan.py':
        kind=args[args.index('--kind')+1];mode=args[3]
        purpose=args[args.index('--purpose')+1] if '--purpose' in args else 'refresh'
        if kind=='park':return 'park-'+purpose+('-plan' if mode=='make' else '-check')
        if kind=='dock':return 'sliver-wait' if mode=='make' else 'dock-arrival'
        return 'status-'+purpose+('-plan' if mode=='make' else '-arrival')
    return {'capture_owned.py':'dock-capture','prepare_menu_plan.py':'refresh-plan','consent_reset.py':'consent-reset'}.get(name,'command')
def diagnostic_code(stderr):
    text=stderr.decode(errors='replace') if isinstance(stderr,bytes) else str(stderr or '')
    return next((code for code in sorted(TOOL_CODES) if code in text[:4096]),'not-delivered')
def command(args,config,timeout=20,diagnostic=None):
    step=command_label(args,diagnostic);action_log(config,step,'started')
    env=os.environ.copy();env['PYTHONDONTWRITEBYTECODE']='1'
    try:
        still_admitted(config)
        result=subprocess.run(args,env=env,text=True,errors='replace',capture_output=True,timeout=timeout)
    except Exception as error:
        code='timeout' if isinstance(error,subprocess.TimeoutExpired) else str(error) if isinstance(error,ValueError) and str(error) in TOOL_CODES else 'command-error'
        detail=pointer_diagnostic(config,diagnostic,None,getattr(error,'stderr','') or '',timed_out=isinstance(error,subprocess.TimeoutExpired)) if diagnostic else None
        refusal(config,step,code);action_log(config,step,'refused',reason=code,exitStatus=None,stderrCodes=detail['stderrCodes'] if detail else [code])
        raise
    detail=pointer_diagnostic(config,diagnostic,result.returncode,result.stderr) if diagnostic else None
    code=diagnostic_code(result.stderr) if result.returncode else None
    action_log(config,step,'refused' if result.returncode else 'completed',exitStatus=result.returncode,
               reason=code,stderrCodes=detail['stderrCodes'] if detail else ([code] if code else ['stderr-present'] if result.stderr else []))
    if result.returncode:
        refusal(config,step,code,result.returncode);raise ValueError('not-delivered')
    return result
def finish(batch,run,epoch,pid,steps,reason):
    reason=None if reason is None else reason_code(reason,BOUNDED_CODES)
    receipt=dict(schema='u6-actions/1',runID=run,epoch=epoch,pid=pid,mono=uptime(),steps=steps,
                 outcome='pass' if reason is None else 'not-run',reason=reason)
    with (batch/'operator-finish.json').open('x') as stream:json.dump(receipt,stream,sort_keys=True);stream.write('\n')
def request_stop(config,reason='not-delivered'):
    path=Path(config['stopPath'])
    try:
        with path.open('x') as stream:json.dump(dict(runID=config['expectedLease']['runID'],
            epoch=config['expectedLease']['epoch'],stop=True,reason=reason_code(reason,BOUNDED_CODES)),stream)
    except FileExistsError:pass
def run(config_path,pointer_binary):
    config=json.loads(Path(config_path).read_text());batch=Path(config['batch']);lease=config['expectedLease']
    run,epoch=lease['runID'],lease['epoch']
    pid=0
    steps={key:'not-run' for key in ('dock','menuA','refresh','menuB','privateTitle','trackedClear')}
    current='dock'
    def py(path,*args):return command([sys.executable,'-B',str(path),*map(str,args)],config)
    def park(phase):
        py(BIN/'u6-pointer-plan.py','make','--config',config_path,'--kind','park','--purpose',phase)
        command([str(pointer_binary),'--plan',str(batch/('park-pointer-'+phase+'-plan.json'))],config,diagnostic='park-'+phase)
        py(BIN/'u6-pointer-plan.py','check','--config',config_path,'--kind','park','--purpose',phase)
    def wait(predicate,seconds):
        label='native-wait-'+current;action_log(config,label,'started')
        try:value=await_row(batch,run,epoch,pid,predicate,seconds)
        except Exception:
            refusal(config,label,'not-delivered');action_log(config,label,'refused',reason='not-delivered');raise
        action_log(config,label,'completed');return value
    try:
        action_log(config,'runner-admission','started')
        still_admitted(config)
        action_log(config,'runner-admission','completed')
        reg=json.loads(Path(config['subjectPidPath']).read_text());pid=reg.get('pid')
        if type(pid) is not int or pid<=0 or reg.get('runID')!=run or reg.get('epoch')!=epoch:raise ValueError('registered-subject-invalid')
        action_log(config,'native-started-wait','started')
        wait(lambda r:r.get('event')=='started',15)
        action_log(config,'native-started-wait','completed')
        park('start')
        py(BIN/'u6-pointer-plan.py','make','--config',config_path,'--kind','dock')
        action_log(config,'dock-plan','completed')
        command([str(pointer_binary),'--plan',str(batch/'dock-pointer-plan.json')],config,diagnostic='dock-pointer')
        py(BIN/'u6-pointer-plan.py','check','--config',config_path,'--kind','dock')
        py(U6/'capture_owned.py','--config',config_path)
        steps['dock']='pass';current='menuA'

        py(BIN/'u6-pointer-plan.py','make','--config',config_path,'--kind','status')
        command([str(pointer_binary),'--plan',str(batch/'status-pointer-plan.json')],config,diagnostic='status-pointer')
        py(BIN/'u6-pointer-plan.py','check','--config',config_path,'--kind','status')
        a=wait(lambda r:r.get('event')=='menu-begin' and r.get('checks',{}).get('surface')=='status',3)
        a_session=a['checks']['sessionID'];steps['menuA']='pass';current='refresh'
        py(U6/'prepare_menu_plan.py','--config',config_path)
        command([str(pointer_binary),'--status-menu-plan',str(batch/'menu-plan.json')],config,timeout=10,diagnostic='menu-refresh')
        refresh=wait(lambda r:r.get('kind')=='refresh' and r.get('phase') in ('completed','failed','deferred','abandoned')
                          and r.get('sessionID')==a_session,60)
        if refresh.get('phase')=='deferred':
            reply=wait(lambda r:r.get('kind')=='refresh' and r.get('phase')=='accepted'
                            and r.get('requestId')==refresh.get('requestId'),1)
            disposition=reply.get('dispositions',{}).get('copilot.runtime_usage')
            raise ValueError('cooldown' if disposition=='cooldown' else 'consent-required' if disposition=='policy_pending' else 'engine-disabled')
        if refresh.get('phase')=='abandoned':raise ValueError('timeout' if refresh.get('cause')=='deadline' else 'not-delivered')
        if refresh.get('phase')=='failed':raise ValueError(reason_code(refresh.get('reason'),BOUNDED_CODES))
        wait(lambda r:r.get('event')=='menu-end' and r.get('checks',{}).get('sessionID')==a_session,5)
        steps['refresh']='pass';current='menuB'

        py(BIN/'u6-pointer-plan.py','make','--config',config_path,'--kind','status','--purpose','clear')
        command([str(pointer_binary),'--plan',str(batch/'status-pointer-clear-plan.json')],config,diagnostic='status-pointer-clear')
        py(BIN/'u6-pointer-plan.py','check','--config',config_path,'--kind','status','--purpose','clear')
        b=wait(lambda r:r.get('event')=='menu-begin' and r.get('checks',{}).get('surface')=='status'
                    and r.get('checks',{}).get('sessionID')!=a_session,3)
        b_session=b['checks']['sessionID'];steps['menuB']='pass';current='privateTitle'
        seed=json.loads((batch/'synthetic-seed.json').read_text())
        wait(lambda r:r.get('event')=='menu-private-title-visible'
                  and r.get('checks',{}).get('sessionID')==b_session
                  and r.get('checks',{}).get('titleSHA256')==seed.get('titleSHA256'),3)
        steps['privateTitle']='pass';current='trackedClear'
        py(U6/'consent_reset.py','--config',config_path)
        clear=wait(lambda r:r.get('event')=='accepted-clear'
                        and b_session in r.get('checks',{}).get('scrubbedSessionIDs',[]),5)
        wait(lambda r:r.get('event')=='menu-scrubbed' and r.get('seq',0)>clear.get('seq',0)
                  and r.get('checks',{}).get('sessionID')==b_session,5)
        steps['trackedClear']='pass';park('end');finish(batch,run,epoch,pid,steps,None)
    except Exception as error:
        refusal(config,'runner-'+current,reason_code(str(error) if isinstance(error,ValueError) else 'unknown',BOUNDED_CODES))
        action_log(config,'runner-'+current,'refused',reason=reason_code(str(error) if isinstance(error,ValueError) else 'unknown',BOUNDED_CODES))
        reason=reason_code(str(error) if isinstance(error,ValueError) else 'unknown',BOUNDED_CODES)
        # One end park only if the existing admission/stop guards still allow it.
        if not (batch/'park-pointer-end-plan.json').exists():
            try:park('end')
            except Exception:pass
        steps[current]='not-run';request_stop(config,reason)
        if not (batch/'operator-finish.json').exists():finish(batch,run,epoch,pid,steps,reason)
        raise SystemExit(3) from error

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--config',type=Path,required=True)
    p.add_argument('--pointer-binary',type=Path,required=True)
    a=p.parse_args();run(a.config,a.pointer_binary)
