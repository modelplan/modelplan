# SPDX-License-Identifier: MIT
"""M1-only run-bound synthetic consent reset; emits a bounded result receipt."""
import argparse,hashlib,json,os,subprocess,sys
from pathlib import Path

BIN=Path(__file__).resolve().parents[1]/'bin';sys.path.insert(0,str(BIN))
sys.path.insert(0,str(Path(__file__).resolve().parent))
from admission import load_and_admit
from guardian import cleanup,identity,launcher_lost
from u6_clock import system_uptime

uptime=system_uptime

def open_status_session(batch,run,epoch,pid):
    path=batch/'native-observations.jsonl'
    if not path.is_file() or path.is_symlink() or path.stat().st_size>8_000_000:raise ValueError('native-rows-unavailable')
    rows=[json.loads(line) for line in path.read_text().splitlines() if line.strip()]
    openings=[];ended=set();visible=set()
    for row in rows:
        if row.get('runID')!=run or row.get('epoch')!=epoch or row.get('pid')!=pid:continue
        checks=row.get('checks',{})
        if row.get('event')=='menu-begin' and checks.get('surface')=='status':
            openings.append((checks.get('menuObjectID'),checks.get('sessionID')))
        elif row.get('event')=='menu-end':ended.add(checks.get('sessionID'))
        elif row.get('event')=='menu-private-title-visible':visible.add(checks.get('sessionID'))
    if len(openings)<2:raise ValueError('second-status-menu-missing')
    first,current=openings[0],openings[-1]
    if (not all(isinstance(x,str) and x for x in current) or current[0]!=first[0]
        or current[1]==first[1] or first[1] not in ended or current[1] in ended or current[1] not in visible):
        raise ValueError('tracked-private-menu-missing')
    return current

def reset(config,run_helper=subprocess.run,now=uptime):
    load_and_admit(config)
    batch=Path(config['batch']);run=config['expectedLease'];scratch=Path(config['scratch']).resolve()
    home_arg=Path(config['syntheticHome']);tmp_arg=Path(config['syntheticTmp'])
    home=home_arg.resolve();tmp=tmp_arg.resolve()
    if (home_arg.is_symlink() or tmp_arg.is_symlink() or home!=scratch/'home' or tmp!=scratch/'tmp'
        or not home.is_dir() or not tmp.is_dir()):
        raise ValueError('synthetic-root-invalid')
    reg=json.loads(Path(config['subjectPidPath']).read_text());pid=reg.get('pid')
    if type(pid) is not int or pid<=0 or reg.get('state')!='running' or not cleanup.matches(identity(pid),reg) or launcher_lost(Path(config['subjectPidPath'])):
        raise ValueError('registered-subject-unavailable')
    menu_object,session=open_status_session(batch,run['runID'],run['epoch'],pid)
    binary=Path(config['argv'][0]).resolve();helper=binary.parent.parent/'Helpers/modelplan'
    if helper.is_symlink() or not helper.is_file() or hashlib.sha256(helper.read_bytes()).hexdigest()!=config.get('helperSHA256'):
        raise ValueError('helper-pin-mismatch')
    receipt=batch/'consent-reset.json'
    if receipt.exists():raise ValueError('reset-receipt-not-fresh')
    start=now();env=os.environ.copy();env['HOME']=str(home);env['TMPDIR']=str(tmp)
    code=-1;result={};reason='unknown'
    try:
        completed=run_helper([str(helper),'consent','reset','confirmed','--json'],env=env,text=True,capture_output=True,timeout=15)
        code=completed.returncode
        if code==0:
            result=json.loads(completed.stdout)
            if not isinstance(result,dict):raise ValueError('helper-result-invalid')
            reason=None
        else:reason='engine-error'
    except subprocess.TimeoutExpired:reason='timeout'
    except (ValueError,json.JSONDecodeError):reason='engine-error'
    end=now()
    store_epoch=result.get('storeEpoch') if code==0 else None
    generation=result.get('generation') if code==0 else None
    if not isinstance(store_epoch,str) or not store_epoch or type(generation) is not int or generation<0:
        reason='engine-error'
    value=dict(schema='consent-reset/1',runID=run['runID'],epoch=run['epoch'],targetPID=pid,
               menuObjectID=menu_object,sessionID=session,operation='consent-reset-confirmed',
               homeSHA256=hashlib.sha256(str(home).encode()).hexdigest(),helperSHA256=config['helperSHA256'],
               startMono=start,endMono=end,exitCode=code,storeEpochAfter=store_epoch,generationAfter=generation,
               outcome='success' if reason is None else 'failed',reason=reason)
    with receipt.open('x') as stream:json.dump(value,stream,sort_keys=True);stream.write('\n')
    print(json.dumps(dict(reset=value['outcome'],reason=reason,runID=run['runID'],epoch=run['epoch'])))
    if reason is not None:raise SystemExit(3)

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--config',type=Path,required=True)
    a=p.parse_args();reset(json.loads(a.config.read_text()))
