# SPDX-License-Identifier: MIT
"""C2.3 U6 synthetic evidence chain. Reads receipts; never authors native proof."""
import datetime,hashlib,json,math
from pathlib import Path

CODES={'engine-disabled','engine-error','consent-required','timeout','not-delivered','wrong-subject','out-of-window','unknown'}
class Missing(Exception):pass
class Contradiction(Exception):pass
def need(value,code='not-delivered'):
    if not value:raise Missing(code)
def reject(value,code='unknown'):
    if value:raise Contradiction(code)
def number(value):return type(value) in (int,float) and math.isfinite(value)
def read(path,limit=8_000_000):
    path=Path(path)
    need(path.is_file() and not path.is_symlink() and path.stat().st_size<=limit)
    try:return json.loads(path.read_text())
    except (OSError,ValueError) as e:raise Missing('not-delivered') from e
def lines(path,limit=8_000_000):
    path=Path(path);need(path.is_file() and not path.is_symlink() and path.stat().st_size<=limit)
    try:return [json.loads(line) for line in path.read_text().splitlines() if line.strip()]
    except (OSError,ValueError) as e:raise Missing('not-delivered') from e
def matching(row,run,epoch,pid):
    return row.get('runID')==run and row.get('epoch')==epoch and row.get('pid')==pid
def native_rows(batch,run,epoch,pid):
    rows=[r for r in lines(batch/'native-observations.jsonl') if isinstance(r,dict) and matching(r,run,epoch,pid)]
    need(rows)
    previous=0
    for row in rows:
        need(type(row.get('seq')) is int and row['seq']>previous and number(row.get('mono')) and number(row.get('at')))
        previous=row['seq']
    return rows
def events(rows,name):return [r for r in rows if r.get('event')==name]
def checks(row):return row.get('checks') if isinstance(row.get('checks'),dict) else {}
def posted(batch,stem,run,epoch,pid):
    plan=read(batch/(stem+'-plan.json'));need(plan.get('runID')==run and plan.get('epoch')==epoch and plan.get('subjectPID')==pid)
    rows=lines(batch/(stem+'.jsonl'))
    filtered=[r for r in rows if isinstance(r,dict) and r.get('runID')==run and r.get('epoch')==epoch
              and r.get('targetPID')==pid and number(r.get('mono')) and number(r.get('at'))]
    need(any(r.get('event')=='pointer-result' and r.get('outcome')=='posted' and r.get('runID')==run
             and r.get('epoch')==epoch and r.get('targetPID')==pid for r in rows))
    return plan,filtered
def one(rows,predicate):
    found=[r for r in rows if predicate(r)]
    reject(len(found)>1,'unknown');need(found)
    return found[0]
def click(rows):
    down=one(rows,lambda r:r.get('event')=='mouse-button-down-posted' and r.get('kind')=='click')
    up=one(rows,lambda r:r.get('event')=='mouse-button-up-posted' and r.get('kind')=='click')
    need(down['mono']<=up['mono'])
    return down,up
def closure_ok(closure,run,epoch):
    need(closure.get('schema')=='launch-cleanup/1' and closure.get('runID')==run and closure.get('epoch')==epoch)
    fields=('subjectGone','helpersGone','leaseClosable','locksReleased','syntheticHomeRemoved','syntheticTmpRemoved','stopPathPresent')
    status=('controllerStatus','guardianStatus','scenarioStatus')
    c=closure.get('checks');need(isinstance(c,dict) and all(type(c.get(k)) is bool for k in fields)
                                and all(type(c.get(k)) is int for k in status) and isinstance(closure.get('at'),str))
    need(c['controllerStatus'] in (0,3) and c['guardianStatus']==0 and c['scenarioStatus']==0)
    failures=[k for k in fields if not c[k]]
    need(isinstance(closure.get('failures'),list) and all(isinstance(x,str) for x in closure['failures']))
    reject(sorted(closure['failures'])!=sorted(failures) or closure.get('ok')!=(not failures))
    need(closure.get('ok') is True)
    try:return datetime.datetime.fromisoformat(closure['at'].replace('Z','+00:00')).timestamp()
    except ValueError as e:raise Missing('out-of-window') from e

def evaluate(config,batch,package,kit_manifest):
    """Return bounded outcome plus the first failed contract step; no caller assertion is trusted."""
    step='pins'
    try:
        batch=Path(batch);package=Path(package)
        run=config['expectedLease']['runID'];epoch=config['expectedLease']['epoch']
        start_window=config['expectedLease']['notBefore'];end_window=config['expectedLease']['expiresAt']
        need(number(start_window) and number(end_window) and start_window<end_window)
        reg=read(config['subjectPidPath']);launch=read(batch/'launch.json');prepared=read(batch/'prepared.json')
        pid=reg.get('pid')
        need(type(pid) is int and pid>0 and reg.get('runID')==run and reg.get('epoch')==epoch
             and launch.get('ownedPID')==pid and launch.get('runID')==run and launch.get('epoch')==epoch
             and launch.get('sourceHead')==config['head'])
        need(prepared.get('runID')==run and prepared.get('epoch')==epoch
             and prepared.get('homeSeedSHA256')==config['syntheticHomeSeedSHA256'])
        need(kit_manifest.get('sourceHead')==config['head'] and
             kit_manifest.get('binarySHA256')==config['binarySHA256'] and
             kit_manifest.get('packageSHA256')==config['packageSHA256'] and
             kit_manifest.get('helperSHA256')==config['helperSHA256'])
        binary=Path(config['argv'][0]);helper=binary.parent.parent/'Helpers/modelplan'
        need(binary.is_file() and helper.is_file() and package.is_file())
        reject(hashlib.sha256(binary.read_bytes()).hexdigest()!=config['binarySHA256'] or
               hashlib.sha256(helper.read_bytes()).hexdigest()!=config['helperSHA256'] or
               hashlib.sha256(package.read_bytes()).hexdigest()!=config['packageSHA256'],'wrong-subject')
        native=native_rows(batch,run,epoch,pid)
        started=one(native,lambda r:r.get('event')=='started')
        reject(not start_window<=started['at']<=end_window,'out-of-window')

        step='dock'
        dock_plan,dock_pointer=posted(batch,'dock-pointer',run,epoch,pid)
        move=one(dock_pointer,lambda r:r.get('event')=='mouse-moved-posted' and r.get('kind')=='move')
        expanded=one(native,lambda r:r.get('event')=='dock-surface-frame' and checks(r).get('state')=='expanded'
                     and 0<=r['mono']-move['mono']<=5)
        capture=read(batch/'dock-capture.json');image=batch/capture.get('file','')
        need(capture.get('schema')=='u6-capture/1' and capture.get('runID')==run and capture.get('epoch')==epoch
             and capture.get('pid')==pid and capture.get('frameSeq')==expanded['seq']
             and capture.get('windowNumber')==checks(expanded).get('windowNumber')
             and number(capture.get('mono')) and capture['mono']>=expanded['mono']
             and image.name=='dock-owned.png' and image.is_file() and not image.is_symlink())
        reject(hashlib.sha256(image.read_bytes()).hexdigest()!=capture.get('sha256'),'wrong-subject')

        step='menu-a'
        _,first_pointer=posted(batch,'status-pointer',run,epoch,pid);down_a,up_a=click(first_pointer)
        a=one(native,lambda r:r.get('event')=='menu-begin' and checks(r).get('surface')=='status'
              and down_a['mono']<=r['mono']<=up_a['mono']+3)
        a_session=checks(a).get('sessionID');object_id=checks(a).get('menuObjectID')
        need(isinstance(a_session,str) and a_session and isinstance(object_id,str) and object_id)

        step='refresh'
        arrival=one(native,lambda r:r.get('event')=='status-menu-action-arrived' and r['seq']>a['seq']
                    and checks(r).get('actionID')=='refresh' and checks(r).get('sessionID')==a_session
                    and checks(r).get('menuObjectID')==object_id and checks(r).get('subjectPID')==pid
                    and checks(r).get('deliveryMethod')=='axpress-menu-item')
        request_id=checks(arrival).get('requestID');need(isinstance(request_id,str) and request_id)
        menu_drive=lines(batch/'menu-drive.jsonl')
        need(any(r.get('event')=='status-menu-result' and r.get('outcome')=='arrived' and r.get('runID')==run
                 and r.get('epoch')==epoch and r.get('subjectPID')==pid and r.get('requestID')==request_id for r in menu_drive))
        requested=one(native,lambda r:r.get('kind')=='refresh' and r.get('phase')=='requested'
                      and r.get('requestId')==request_id and r.get('sessionID')==a_session and r['seq']>arrival['seq'])
        before=requested.get('rowsSequenceBefore');need(type(before) is int and before>=0)
        terminal=one(native,lambda r:r.get('kind')=='refresh' and r.get('phase') in ('completed','failed')
                     and r.get('requestId')==request_id and r.get('sessionID')==a_session and r['seq']>requested['seq'])
        reject(not 0<=terminal['mono']-requested['mono']<=60,'out-of-window')
        if terminal['phase']=='failed':
            reason=terminal.get('reason');raise Contradiction(reason if reason in CODES else 'unknown')
        need(type(terminal.get('rowsSequenceAfter')) is int and terminal['rowsSequenceAfter']>before)
        end_a=one(native,lambda r:r.get('event')=='menu-end' and checks(r).get('sessionID')==a_session
                  and checks(r).get('menuObjectID')==object_id and r['seq']>arrival['seq'])

        step='menu-b'
        _,second_pointer=posted(batch,'status-pointer-clear',run,epoch,pid);down_b,up_b=click(second_pointer)
        need(down_b['mono']>end_a['mono'])
        b=one(native,lambda r:r.get('event')=='menu-begin' and checks(r).get('surface')=='status'
              and checks(r).get('menuObjectID')==object_id and checks(r).get('sessionID') not in (None,a_session)
              and down_b['mono']<=r['mono']<=up_b['mono']+3)
        b_session=checks(b)['sessionID']

        step='private-title'
        seed=read(batch/'synthetic-seed.json')
        need(seed.get('runID')==run and seed.get('epoch')==epoch and seed.get('homeSeedSHA256')==config['syntheticHomeSeedSHA256'])
        title_hash=seed.get('titleSHA256');need(isinstance(title_hash,str) and len(title_hash)==64)
        title=one(native,lambda r:r.get('event')=='menu-private-title-visible' and r['seq']>b['seq']
                  and checks(r).get('sessionID')==b_session and checks(r).get('titleSHA256')==title_hash)
        item_ids=checks(title).get('privateItemIDs')
        need(isinstance(item_ids,list) and item_ids and len(item_ids)==len(set(item_ids))
             and all(isinstance(x,str) and x for x in item_ids))

        step='tracked-clear'
        reset=read(batch/'consent-reset.json')
        need(reset.get('schema')=='consent-reset/1' and reset.get('runID')==run and reset.get('epoch')==epoch
             and reset.get('targetPID')==pid and reset.get('sessionID')==b_session
             and reset.get('operation')=='consent-reset-confirmed' and reset.get('exitCode')==0
             and reset.get('outcome')=='success' and reset.get('helperSHA256')==config['helperSHA256']
             and reset.get('homeSHA256')==hashlib.sha256(str(Path(config['syntheticHome']).resolve()).encode()).hexdigest()
             and number(reset.get('startMono')) and number(reset.get('endMono')) and reset['startMono']<=reset['endMono'])
        pair=(reset.get('storeEpochAfter'),reset.get('generationAfter'))
        need(isinstance(pair[0],str) and pair[0] and type(pair[1]) is int and pair[1]>=0)
        initiated=one(native,lambda r:r.get('event')=='clear-initiated' and r['seq']>title['seq']
                      and checks(r).get('storeEpochAfter')==pair[0] and checks(r).get('generationAfter')==pair[1]
                      and b_session in checks(r).get('openSessionIDs',[])
                      and reset['startMono']<=r['mono']<=reset['endMono']+5)
        clear_id=checks(initiated).get('clearID');need(isinstance(clear_id,str) and clear_id)
        reject(any(r.get('event')=='menu-end' and checks(r).get('sessionID')==b_session
                   and r['seq']<initiated['seq'] for r in native),'not-delivered')
        accepted=one(native,lambda r:r.get('event')=='accepted-clear' and r['seq']>initiated['seq']
                     and checks(r).get('clearID')==clear_id and checks(r).get('storeEpochAfter')==pair[0]
                     and checks(r).get('generationAfter')==pair[1]
                     and b_session in checks(r).get('scrubbedSessionIDs',[]))
        reject(any(r.get('event')=='menu-end' and checks(r).get('sessionID')==b_session
                   and r['seq']>=initiated['seq'] and (checks(r).get('cause')!='clear'
                   or checks(r).get('clearID')!=clear_id) for r in native),'not-delivered')
        scrubbed=one(native,lambda r:r.get('event')=='menu-scrubbed' and r['seq']>accepted['seq']
                     and checks(r).get('clearID')==clear_id and checks(r).get('sessionID')==b_session)
        states=checks(scrubbed).get('itemStates');need(isinstance(states,list))
        actual={x.get('id'):x.get('state') for x in states if isinstance(x,dict)}
        reject(any(actual.get(item) not in ('cleared','deallocated') for item in item_ids)
               or checks(scrubbed).get('privateTitlePresent') is not False
               or checks(scrubbed).get('privateAttributeCount')!=0,'not-delivered')
        reject(any(r.get('event')=='menu-private-title-visible' and r['seq']>accepted['seq']
                   and checks(r).get('titleSHA256')==title_hash for r in native),'not-delivered')

        step='handoff'
        action=read(batch/'operator-finish.json');need(action.get('schema')=='u6-actions/1'
             and action.get('runID')==run and action.get('epoch')==epoch and number(action.get('mono'))
             and action['mono']>=scrubbed['mono'])
        outcomes=action.get('steps');need(isinstance(outcomes,dict) and all(outcomes.get(x)=='pass' for x in
            ('dock','menuA','refresh','menuB','privateTitle','trackedClear')))

        step='quit'
        stopped=one(native,lambda r:r.get('event')=='stop-or-lease-expired' and r['seq']>scrubbed['seq']
                    and r['mono']>=action['mono'])
        terminated=one(native,lambda r:r.get('event')=='terminate-completed' and r['seq']>stopped['seq'])

        step='closure'
        closure=read(batch/'launch-cleanup.json');ended=closure_ok(closure,run,epoch)
        reject(not start_window<=ended<=end_window or ended<started['at'],'out-of-window')

        return dict(outcome='pass',step='complete',reason=None,durationSeconds=ended-started['at'],
                    runID=run,epoch=epoch,pid=pid)
    except Missing as error:return dict(outcome='not-run',step=step,reason=str(error))
    except Contradiction as error:return dict(outcome='fail',step=step,reason=str(error))
    except (KeyError,TypeError,ValueError,IndexError) as error:
        return dict(outcome='not-run',step=step,reason='unknown')
