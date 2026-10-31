# SPDX-License-Identifier: MIT
"""U6-only physical pointer plan and native arrival check for one admitted subject."""
import argparse, json, math, sys, time
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'U6'))
from u6_clock import system_uptime
from admission import still_admitted # action phase: launch admission already checked the full budget
from guardian import cleanup, identity, launcher_lost

def rows(path):
    data = Path(path).read_bytes()
    if len(data) > 8_000_000: raise ValueError('receipt-limit')
    return [json.loads(line) for line in data.splitlines() if line.strip()]

def rectangle(value):
    if (isinstance(value,list) and len(value)==4 and all(type(x) in (int,float) and math.isfinite(x) for x in value)
        and value[2]>0 and value[3]>0):return value
    return None

def contains(rect,point):
    x,y,w,h=rect;return x<=point[0]<x+w and y<=point[1]<y+h

def valid_window(number):return type(number) is int and 1<=number<=0xffffffff
def window_mode(number):
    if type(number) is not int:raise ValueError('owned-frame-missing')
    return 'required' if valid_window(number) else 'unavailable'

def settled_status(row,rect,now):
    c=row.get('checks',{});since=c.get('stableSinceMono');display=rectangle(c.get('displayBounds'));band=rectangle(c.get('menuBarBand'))
    if (c.get('settled') is not True or c.get('visible') is not True
        or type(c.get('frameGeneration')) is not int or c['frameGeneration']<1
        or type(c.get('windowNumber')) is not int
        or type(since) not in (int,float) or not math.isfinite(since)
        or not math.isfinite(row['mono']) or row['mono']-since<.5 or display is None or band is None):return False
    if not math.isfinite(now) or not 0<=now-row['mono']<=2:return False
    x,y,w,h=rect;point=(x+w/2,y+h/2)
    return (y<=display[1]+1 and y+h>=display[1]-1 and band[0]==display[0] and band[1]==display[1]
        and band[2]==display[2] and band[3]<=display[3] and contains(display,point) and contains(band,point))

def latest_frame(observations, event, run, epoch, pid, state=None,now=None):
    for row in reversed(observations):
        if (row.get('event') != event or row.get('runID') != run or row.get('epoch') != epoch
            or row.get('pid') != pid):continue
        if type(row.get('seq')) is not int or row['seq']<1 or type(row.get('mono')) not in (int,float):
            if event=='status-item-frame':raise ValueError('owned-frame-missing')
            continue
        checks = row.get('checks', {})
        if state is not None and checks.get('state') != state: continue
        x = checks.get('x' if event == 'dock-surface-frame' else 'cgX')
        y = checks.get('y' if event == 'dock-surface-frame' else 'cgY')
        width, height = checks.get('width'), checks.get('height')
        space = 'cg-screen' if event == 'dock-surface-frame' else 'appkit-screen'
        if (all(type(v) in (int, float) and math.isfinite(v) for v in (x,y,width,height))
            and width > 0 and height > 0 and checks.get('coordinateSpace') == space):
            if event=='status-item-frame' and not settled_status(row,(x,y,width,height),system_uptime() if now is None else now):
                raise ValueError('owned-frame-missing') # never fall back past a newer unready frame
            return row, (x,y,width,height)
        if event=='status-item-frame':raise ValueError('owned-frame-missing')
    raise ValueError('owned-frame-missing')

def prefix(kind, purpose):
    if kind=='park':
        if purpose not in ('start','end'):raise ValueError('park-purpose-invalid')
        return 'park-pointer-'+purpose
    if kind == 'dock' and purpose != 'refresh': raise ValueError('dock-purpose-invalid')
    return kind+'-pointer'+('-clear' if kind == 'status' and purpose == 'clear' else '')

def collapsed_dock(observations,run,epoch,pid,now):
    owned=[r for r in observations if r.get('event')=='dock-surface-frame' and r.get('runID')==run
           and r.get('epoch')==epoch and r.get('pid')==pid]
    if not owned:raise ValueError('dock-not-collapsed')
    latest=owned[-1];c=latest.get('checks',{})
    if c.get('state')!='sliver' or not valid_window(c.get('windowNumber')):raise ValueError('dock-not-collapsed')
    try:row,rect=latest_frame([latest],'dock-surface-frame',run,epoch,pid)
    except ValueError:raise ValueError('dock-not-collapsed') from None
    if not math.isfinite(row['mono']) or not math.isfinite(now) or row['mono']>now:raise ValueError('dock-not-collapsed')
    since=row['mono']
    for prior in reversed(owned[:-1]):
        pc=prior.get('checks',{})
        if pc.get('state')!='sliver' or pc.get('windowNumber')!=c['windowNumber']:break
        try:_,previous_rect=latest_frame([prior],'dock-surface-frame',run,epoch,pid)
        except ValueError:break
        if previous_rect!=rect or not math.isfinite(prior['mono']) or prior['mono']>since:break
        since=prior['mono']
    if now-since<.5:raise ValueError('dock-not-collapsed')
    return row,rect,since

def make(config, kind, purpose='refresh',clock=system_uptime,sleep=time.sleep):
    still_admitted(config)
    batch = Path(config['batch'])
    lease = config['expectedLease']
    reg = json.loads(Path(config['subjectPidPath']).read_text())
    pid = reg.get('pid')
    if type(pid) is not int or pid <= 0 or reg.get('state') != 'running' or not cleanup.matches(identity(pid),reg) or launcher_lost(Path(config['subjectPidPath'])):
        raise ValueError('subject-registration-invalid')
    event = 'dock-surface-frame' if kind in ('dock','park') else 'status-item-frame'
    deadline=clock()+(10 if kind=='dock' else 5)
    while True:
        still_admitted(config)
        if not cleanup.matches(identity(pid),reg) or launcher_lost(Path(config['subjectPidPath'])):
            raise ValueError('subject-registration-invalid')
        try:
            observations=rows(batch/'native-observations.jsonl')
            if kind=='park':
                observation,display,exclusions=park_geometry(observations,lease['runID'],lease['epoch'],pid)
                cx,cy=display[0]+display[2]/2,display[1]+display[3]/2;rect=(cx-1,cy-1,2,2)
            elif kind=='dock':observation,rect,sliver_since=collapsed_dock(observations,lease['runID'],lease['epoch'],pid,clock())
            else:observation,rect=latest_frame(observations,event,lease['runID'],lease['epoch'],pid,now=clock())
            break
        except ValueError as error:
            expected='dock-not-collapsed' if kind=='dock' else 'park-geometry-missing' if kind=='park' else 'owned-frame-missing'
            if str(error)!=expected or clock()>=deadline:
                if kind=='dock' and str(error)==expected:
                    try:
                        with (batch/'dock-plan-refusal.json').open('x') as out:
                            json.dump(dict(schema='u6-dock-plan-refusal/1',runID=lease['runID'],epoch=lease['epoch'],reason=expected,mono=clock()),out)
                    except OSError:pass
                raise
            sleep(max(0,min(.05,deadline-clock())))
    x,y,w,h = rect
    window = observation['checks'].get('windowNumber') if kind == 'dock' else None
    if kind == 'dock' and not valid_window(window): raise ValueError('owned-window-missing')
    bundle = Path(config['argv'][0]).resolve().parent.parent.parent
    stem=prefix(kind,purpose)
    plan = dict(profile='synthetic',runID=lease['runID'],epoch=lease['epoch'],lease=config['leasePath'],stop=config['stopPath'],
        output=str(batch/(stem+'.jsonl')),subjectPID=pid,subjectBundle=str(bundle),allowedRectangles=[[x,y,w,h]],
        steps=[dict(x=x+w/2,y=y+h/2,seconds=0,dwell=0.25,**({'action':'click'} if kind == 'status' else {}))],
        targetPID=pid,u6OwnedWindowNumber=window,u6FrameSeq=observation['seq'])
    if kind=='dock':plan['u6DockSliverSinceMono']=sliver_since
    if kind=='park':
        plan.update(purpose='park',parkPhase=purpose,u6InputKind='park',u6Observations=str(batch/'native-observations.jsonl'),
                    parkDisplayBounds=display,parkExclusions=exclusions)
        plan['steps'][0]['action']='move'
    if kind=='status':
        plan.update(u6InputKind='status',u6Observations=str(batch/'native-observations.jsonl'),
                    u6StatusFrameGeneration=observation['checks']['frameGeneration'],
                    u6StatusWindowNumber=observation['checks']['windowNumber'],
                    statusWindowCheck=window_mode(observation['checks']['windowNumber']))
    path = batch/(stem+'-plan.json')
    with path.open('x') as stream: json.dump(plan,stream,indent=2);stream.write('\n')
    print(path)

def park_geometry(observations,run,epoch,pid):
    owned=[r for r in observations if r.get('runID')==run and r.get('epoch')==epoch and r.get('pid')==pid]
    docks=[r for r in owned if r.get('event')=='dock-surface-frame']
    if not docks:raise ValueError('park-geometry-missing')
    latest=docks[-1];display=rectangle(latest.get('checks',{}).get('displayBounds'))
    if display is None:raise ValueError('park-geometry-missing')
    statuses=[r for r in owned if r.get('event')=='status-item-frame']
    if (not statuses or statuses[-1].get('checks',{}).get('settled') is not True or statuses[-1].get('checks',{}).get('visible') is not True
        or rectangle([statuses[-1].get('checks',{}).get(k) for k in ('cgX','cgY','width','height')]) is None):
        raise ValueError('park-geometry-missing')
    point=(display[0]+display[2]/2,display[1]+display[3]/2);exclusions=[];kinds=set()
    for row in owned:
        event=row.get('event');c=row.get('checks',{})
        if event not in ('dock-surface-frame','status-item-frame'):continue
        rect=rectangle([c.get(k) for k in (('x','y','width','height') if event=='dock-surface-frame' else ('cgX','cgY','width','height'))])
        if rect is None:continue
        kinds.add(event);exclusions.append(rect)
        dx=max(rect[0]-point[0],0,point[0]-rect[0]-rect[2]);dy=max(rect[1]-point[1],0,point[1]-rect[1]-rect[3])
        if math.hypot(dx,dy)<200:raise ValueError('park-geometry-missing')
    c=latest.get('checks',{});dock=rectangle([c.get(k) for k in ('x','y','width','height')])
    if kinds!={'dock-surface-frame','status-item-frame'} or dock is None or not contains(display,(dock[0]+dock[2]/2,dock[1]+dock[3]/2)):
        raise ValueError('park-geometry-missing')
    return latest,display,exclusions

class ArrivalMissing(ValueError):
    def __init__(self,deadline):
        super().__init__('native-arrival-missing');self.deadline=deadline

def check_once(config, kind, purpose='refresh'):
    batch = Path(config['batch']); lease = config['expectedLease']
    plan = json.loads((batch/(prefix(kind,purpose)+'-plan.json')).read_text())
    if kind=='status' and plan.get('statusWindowCheck')!=window_mode(plan.get('u6StatusWindowNumber')):raise ValueError('owned-frame-missing')
    pointer = rows(plan['output'])
    def posting(row,event,kind):
        return (row.get('event')==event and row.get('kind')==kind and row.get('runID')==lease['runID']
            and row.get('epoch')==lease['epoch'] and row.get('targetPID')==plan['subjectPID']
            and type(row.get('mono')) in (int,float) and math.isfinite(row['mono']))
    moved=[r for r in pointer if posting(r,'mouse-moved-posted','move')]
    down=[r for r in pointer if posting(r,'mouse-button-down-posted','click')]
    up=[r for r in pointer if posting(r,'mouse-button-up-posted','click')]
    if not moved or (kind=='status' and (len(down)!=1 or len(up)!=1 or down[0]['mono']>up[0]['mono'])):
        raise ValueError('physical-input-not-delivered')
    if not any(r.get('event')=='pointer-result' and r.get('outcome')=='posted' and
               r.get('runID')==lease['runID'] and r.get('epoch')==lease['epoch']
               and r.get('targetPID')==plan['subjectPID'] for r in pointer):
        raise ValueError('physical-input-not-delivered')
    if kind=='park':
        if (plan.get('purpose')!='park' or len(plan.get('steps',[]))!=1 or plan['steps'][0].get('action')!='move'
            or len(moved)!=1 or any(r.get('event') in ('mouse-button-down-posted','mouse-button-up-posted') for r in pointer)
            or moved[0].get('purpose')!='park' or not any(r.get('event')=='pointer-result' and r.get('purpose')=='park' and r.get('outcome')=='posted' for r in pointer)):
            raise ValueError('park-input-invalid')
        print(json.dumps(dict(input='park',purpose='park',outcome='posted',runID=lease['runID'],epoch=lease['epoch'])));return
    anchor=moved[0]['mono'] if kind=='dock' else down[0]['mono']
    native = rows(batch/'native-observations.jsonl')
    if kind=='status':
        frame=next((r for r in native if r.get('event')=='status-item-frame' and r.get('runID')==lease['runID']
                    and r.get('epoch')==lease['epoch'] and r.get('pid')==plan['subjectPID'] and r.get('seq')==plan.get('u6FrameSeq')),None)
        number=(frame or {}).get('checks',{}).get('windowNumber')
        if type(number) is not int or number!=plan['u6StatusWindowNumber']:raise ValueError('owned-frame-missing')
        expected='verified' if plan['statusWindowCheck']=='required' else 'unavailable'
        if any(r.get('statusWindowCheck')!=expected for r in down+up):raise ValueError('physical-input-not-delivered')
    event = 'dock-surface-frame' if kind == 'dock' else 'menu-begin'
    upper=anchor+5 if kind=='dock' else up[0]['mono']+3
    observed = [r for r in native if r.get('event') == event and r.get('runID') == lease['runID']
                and r.get('epoch') == lease['epoch'] and r.get('pid')==plan['subjectPID']
                and type(r.get('seq')) is int and type(r.get('mono')) in (int,float)
                and math.isfinite(r['mono']) and anchor<=r['mono']<=upper]
    if kind == 'dock':
        prior=[r for r in native if type(r.get('mono')) in (int,float) and r['mono']<=anchor]
        sliver,_,_=collapsed_dock(prior,lease['runID'],lease['epoch'],plan['subjectPID'],anchor)
        if sliver['seq']<plan.get('u6FrameSeq',0):raise ValueError('dock-not-collapsed')
        observed=[r for r in observed if r.get('checks',{}).get('state')=='expanded'
                  and r['seq']>sliver['seq'] and r['mono']>anchor]
    else: observed = [r for r in observed if r.get('checks',{}).get('surface') == 'status'
                      and r.get('checks',{}).get('subjectPID') == plan['subjectPID']]
    if kind=='status' and purpose=='clear':
        first=json.loads((batch/'status-pointer-plan.json').read_text())
        original=rows(first['output'])
        first_down=next((r for r in original if posting(r,'mouse-button-down-posted','click')),None)
        first_up=next((r for r in original if posting(r,'mouse-button-up-posted','click')),None)
        if first_down is None or first_up is None: raise ValueError('first-menu-input-missing')
        a=next((r for r in native if r.get('event')=='menu-begin' and r.get('pid')==plan['subjectPID']
            and r.get('runID')==lease['runID'] and r.get('epoch')==lease['epoch']
            and r.get('checks',{}).get('surface')=='status' and type(r.get('mono')) in (int,float)
            and first_down['mono']<=r['mono']<=first_up['mono']+3),None)
        if a is None: raise ValueError('first-menu-arrival-missing')
        a_id=a.get('checks',{}).get('sessionID');object_id=a.get('checks',{}).get('menuObjectID')
        ended=any(r.get('event')=='menu-end' and r.get('pid')==plan['subjectPID']
            and r.get('runID')==lease['runID'] and r.get('epoch')==lease['epoch']
            and r.get('checks',{}).get('sessionID')==a_id and type(r.get('mono')) in (int,float)
            and r['mono']<down[0]['mono'] for r in native)
        if not ended: raise ValueError('first-menu-not-ended')
        observed=[r for r in observed if r.get('checks',{}).get('sessionID') not in (None,a_id)
                  and r.get('checks',{}).get('menuObjectID')==object_id]
    if not observed: raise ArrivalMissing(upper)
    print(json.dumps(dict(input=kind,outcome='arrived',runID=lease['runID'],epoch=lease['epoch'])))

def check(config,kind,purpose='refresh',clock=system_uptime,sleep=time.sleep):
    # One input only. Wait for its owned receipt through the contract's existing
    # event deadline; never repost input, renew admission or extend that deadline.
    while True:
        still_admitted(config)
        try:return check_once(config,kind,purpose)
        except ArrivalMissing as error:
            remaining=error.deadline-clock()
            if remaining<=0:raise
            sleep(min(.05,remaining))

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('mode',choices=('make','check','window'))
    p.add_argument('--config',type=Path,required=True)
    p.add_argument('--kind',choices=('dock','status','park'),required=True)
    p.add_argument('--purpose',choices=('refresh','clear','start','end'),default='refresh')
    a=p.parse_args(); c=json.loads(a.config.read_text())
    if a.mode == 'make': make(c,a.kind,a.purpose)
    elif a.mode == 'check': check(c,a.kind,a.purpose)
    else:
        if a.kind != 'dock': raise ValueError('only-owned-dock-window-can-be-captured')
        still_admitted(c)
        plan=json.loads((Path(c['batch'])/'dock-pointer-plan.json').read_text())
        number=plan.get('u6OwnedWindowNumber')
        if type(number) is not int or number <= 0: raise ValueError('owned-window-missing')
        print(number)
if __name__ == '__main__': main()
