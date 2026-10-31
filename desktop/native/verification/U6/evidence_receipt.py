# SPDX-License-Identifier: MIT
"""Build one U6 evidence receipt from native, pointer, operator and closure proof."""
import argparse, datetime, hashlib, importlib.util, json, sys, time
from pathlib import Path

BIN=Path(__file__).resolve().parents[1]/'bin'
sys.path.insert(0,str(BIN))
def module(name,path):
    spec=importlib.util.spec_from_file_location(name,path)
    value=importlib.util.module_from_spec(spec);spec.loader.exec_module(value)
    return value
pointer=module('u6_pointer_plan',BIN/'u6-pointer-plan.py')
evidence=module('u6_evidence',BIN/'evidence-u6.py')
REQUIRED=('run.json','prepared.json','native-observations.jsonl','dock-pointer.jsonl','status-pointer.jsonl',
          'menu-request.json','menu-drive.jsonl','dock-owned.png','consent-reset.json',
          'launch-cleanup.json','result.json','launch.json')

def safe_rows(path):
    if not path.is_file() or path.is_symlink() or path.stat().st_size>8_000_000:return []
    try:return [json.loads(line) for line in path.read_text().splitlines() if line.strip()]
    except (OSError,ValueError):return []

def record_operator(config, now=None):
    batch=Path(config['batch']);run=config['expectedLease']
    # M1 invokes this only after observing the actual owned Dock reading/reason and private title.
    reg=json.loads(Path(config['subjectPidPath']).read_text())
    if type(reg.get('pid')) is not int or reg['pid'] <= 0:raise ValueError('subject-pid-missing')
    value=dict(runID=run['runID'],epoch=run['epoch'],subjectPID=reg['pid'],at=time.time() if now is None else now,
               dockReadingOrReasonVisible=True,
               privateTitleVisibleBeforeClear=True,observationMethod='owned-CUA-plus-single-owned-window')
    with (batch/'operator-observations.json').open('x') as stream:json.dump(value,stream,indent=2);stream.write('\n')
    print('M1 visual observations recorded; native and cleanup receipts remain independent gates.')

def assemble(config, package):
    batch=Path(config['batch']);run=config['expectedLease'];run_id,epoch=run['runID'],run['epoch']
    if not batch.is_dir() or batch.is_symlink():raise ValueError('batch-invalid')
    if not package.is_file() or package.is_symlink():raise ValueError('package-missing')
    package_hash=hashlib.sha256(package.read_bytes()).hexdigest()
    if package_hash!=config.get('packageSHA256'):raise ValueError('package-pin-mismatch')
    if hashlib.sha256(Path(config['argv'][0]).read_bytes()).hexdigest()!=config['binarySHA256']:
        raise ValueError('binary-pin-mismatch')
    prepared=json.loads((batch/'prepared.json').read_text()) if (batch/'prepared.json').is_file() else {}
    if (prepared.get('runID')!=run_id or prepared.get('epoch')!=epoch
        or prepared.get('homeSeedSHA256')!=config.get('syntheticHomeSeedSHA256')):
        raise ValueError('profile-preparation-pin-mismatch')
    native=safe_rows(batch/'native-observations.jsonl')
    started=next((r['timestamp'] for r in native if r.get('event')=='started' and r.get('runID')==run_id
                  and r.get('epoch')==epoch and type(r.get('timestamp')) in (int,float)),None)
    closure_path=batch/'launch-cleanup.json'
    closure=json.loads(closure_path.read_text()) if closure_path.is_file() and not closure_path.is_symlink() else {}
    closed=(closure.get('schema')=='launch-cleanup/1' and closure.get('runID')==run_id and closure.get('epoch')==epoch
            and closure.get('ok') is True and closure.get('failures')==[])
    ended=None
    if closed:
        try:ended=datetime.datetime.fromisoformat(closure['at'].replace('Z','+00:00')).timestamp()
        except (KeyError,TypeError,ValueError):closed=False
    duration=ended-started if closed and started is not None else None
    if type(duration) not in (int,float) or not 0<duration<=1200: duration=None;closed=False
    result=json.loads((batch/'result.json').read_text()) if (batch/'result.json').is_file() else {}
    launched=json.loads((batch/'launch.json').read_text()) if (batch/'launch.json').is_file() else {}
    app_started=(result.get('runID')==run_id and result.get('epoch')==epoch and result.get('appStarted') is True
                 and launched.get('runID')==run_id and launched.get('epoch')==epoch
                 and launched.get('sourceHead')==config['head'] and started is not None)
    dock=status=False
    for kind in ('dock','status'):
        try:pointer.check(config,kind)
        except (OSError,ValueError,KeyError,TypeError):continue
        if kind=='dock':dock=True
        else:status=True
    visual=json.loads((batch/'operator-observations.json').read_text()) if (batch/'operator-observations.json').is_file() else {}
    clear_at=next((r.get('timestamp') for r in native if r.get('event')=='accepted-clear' and r.get('runID')==run_id
                   and r.get('epoch')==epoch and type(r.get('timestamp')) in (int,float)),None)
    observed=(visual.get('runID')==run_id and visual.get('epoch')==epoch and
              visual.get('subjectPID')==launched.get('ownedPID') and type(visual.get('at')) in (int,float)
              and clear_at is not None and visual['at']<clear_at)
    refresh,clear,_=evidence.native_outcomes(native,run_id,epoch)
    request=json.loads((batch/'menu-request.json').read_text()) if (batch/'menu-request.json').is_file() else {}
    menu=safe_rows(batch/'menu-drive.jsonl')
    menu_arrived=any(r.get('event')=='status-menu-result' and r.get('outcome')=='arrived' and
                     r.get('runID')==run_id and r.get('epoch')==epoch and r.get('requestID')==request.get('requestID')
                     for r in menu)
    quit_proof=result.get('quit') if isinstance(result.get('quit'),dict) else {}
    refs=[name for name in REQUIRED if (batch/name).is_file() and not (batch/name).is_symlink()]
    if (batch/'operator-observations.json').is_file():refs.append('operator-observations.json')
    receipt=dict(profile='synthetic',runID=run_id,epoch=epoch,headSHA=config['head'],
        binarySHA256=config['binarySHA256'],packageSHA256=package_hash,
        profileSHA256=config['syntheticHomeSeedSHA256'],durationSeconds=duration,actionEvidenceFiles=refs,
        appStarted=app_started,dockInputDelivered=dock,
        dockRowsOrReasonVisible=observed and visual.get('dockReadingOrReasonVisible') is True and (batch/'dock-owned.png').is_file(),
        menuInputDelivered=status and menu_arrived,menuStateVisible=status and observed and visual.get('privateTitleVisibleBeforeClear') is True,
        quitDelivered=quit_proof.get('requested')=='native-contract-stop' and quit_proof.get('appAcknowledged') is True,
        ownedCleanupVerified=closed,privateTitleObservedBeforeClear=observed and visual.get('privateTitleVisibleBeforeClear') is True,
        trackedMenuClearObserved=clear=='pass',refreshCompleted=refresh)
    outcome=evidence.qualify(receipt,native)
    with (batch/'evidence-receipt.json').open('x') as stream:json.dump(receipt,stream,indent=2);stream.write('\n')
    print(json.dumps(dict(outcome=outcome,refreshCompleted=refresh,trackedClear=clear,durationSeconds=duration)))

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('mode',choices=('record-operator','assemble'))
    p.add_argument('--config',type=Path,required=True);p.add_argument('--package',type=Path)
    a=p.parse_args();config=json.loads(a.config.read_text())
    if a.mode=='record-operator':record_operator(config)
    else:
        if a.package is None:raise ValueError('package-required')
        assemble(config,a.package)
