# SPDX-License-Identifier: MIT
"""U6-only physical pointer plan and native arrival check for one admitted subject."""
import argparse, json, math, sys
from pathlib import Path
from admission import load_and_admit
from guardian import cleanup, identity, launcher_lost

def rows(path):
    data = Path(path).read_bytes()
    if len(data) > 8_000_000: raise ValueError('receipt-limit')
    return [json.loads(line) for line in data.splitlines() if line.strip()]

def latest_frame(observations, event, run, epoch, pid, state=None):
    for row in reversed(observations):
        if (row.get('event') != event or row.get('runID') != run or row.get('epoch') != epoch
            or row.get('pid') != pid or type(row.get('seq')) is not int or type(row.get('mono')) not in (int,float)):continue
        checks = row.get('checks', {})
        if state is not None and checks.get('state') != state: continue
        x = checks.get('x' if event == 'dock-surface-frame' else 'cgX')
        y = checks.get('y' if event == 'dock-surface-frame' else 'cgY')
        width, height = checks.get('width'), checks.get('height')
        space = 'cg-screen' if event == 'dock-surface-frame' else 'appkit-screen'
        if (all(type(v) in (int, float) and math.isfinite(v) for v in (x,y,width,height))
            and width > 0 and height > 0 and checks.get('coordinateSpace') == space):
            return row, (x,y,width,height)
    raise ValueError('owned-frame-missing')

def prefix(kind, purpose):
    if kind == 'dock' and purpose != 'refresh': raise ValueError('dock-purpose-invalid')
    return kind+'-pointer'+('-clear' if kind == 'status' and purpose == 'clear' else '')

def make(config, kind, purpose='refresh'):
    load_and_admit(config)
    batch = Path(config['batch'])
    lease = config['expectedLease']
    reg = json.loads(Path(config['subjectPidPath']).read_text())
    pid = reg.get('pid')
    if type(pid) is not int or pid <= 0 or reg.get('state') != 'running' or not cleanup.matches(identity(pid),reg) or launcher_lost(Path(config['subjectPidPath'])):
        raise ValueError('subject-registration-invalid')
    event = 'dock-surface-frame' if kind == 'dock' else 'status-item-frame'
    observation, rect = latest_frame(rows(batch/'native-observations.jsonl'),event,lease['runID'],lease['epoch'],pid,'sliver' if kind == 'dock' else None)
    x,y,w,h = rect
    window = observation['checks'].get('windowNumber') if kind == 'dock' else None
    if kind == 'dock' and (type(window) is not int or window <= 0): raise ValueError('owned-window-missing')
    bundle = Path(config['argv'][0]).resolve().parent.parent.parent
    stem=prefix(kind,purpose)
    plan = dict(profile='synthetic',runID=lease['runID'],epoch=lease['epoch'],lease=config['leasePath'],stop=config['stopPath'],
        output=str(batch/(stem+'.jsonl')),subjectPID=pid,subjectBundle=str(bundle),allowedRectangles=[[x,y,w,h]],
        steps=[dict(x=x+w/2,y=y+h/2,seconds=0,dwell=0.25,**({'action':'click'} if kind == 'status' else {}))],
        targetPID=pid,u6OwnedWindowNumber=window,u6FrameSeq=observation['seq'])
    path = batch/(stem+'-plan.json')
    with path.open('x') as stream: json.dump(plan,stream,indent=2);stream.write('\n')
    print(path)

def check(config, kind, purpose='refresh'):
    batch = Path(config['batch']); lease = config['expectedLease']
    plan = json.loads((batch/(prefix(kind,purpose)+'-plan.json')).read_text())
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
    if not any(r.get('event')=='pointer-result' and r.get('outcome')=='posted' for r in pointer):
        raise ValueError('physical-input-not-delivered')
    anchor=moved[0]['mono'] if kind=='dock' else up[0]['mono']
    native = rows(batch/'native-observations.jsonl')
    event = 'dock-surface-frame' if kind == 'dock' else 'menu-begin'
    window=5 if kind=='dock' else 3
    observed = [r for r in native if r.get('event') == event and r.get('runID') == lease['runID']
                and r.get('epoch') == lease['epoch'] and r.get('pid')==plan['subjectPID']
                and type(r.get('seq')) is int and type(r.get('mono')) in (int,float)
                and math.isfinite(r['mono']) and 0<=r['mono']-anchor<=window]
    if kind == 'dock': observed = [r for r in observed if r.get('checks',{}).get('state') == 'expanded']
    else: observed = [r for r in observed if r.get('checks',{}).get('surface') == 'status'
                      and r.get('checks',{}).get('subjectPID') == plan['subjectPID']]
    if kind=='status' and purpose=='clear':
        first=json.loads((batch/'status-pointer-plan.json').read_text())
        original=rows(first['output'])
        first_up=next((r for r in original if posting(r,'mouse-button-up-posted','click')),None)
        if first_up is None: raise ValueError('first-menu-input-missing')
        a=next((r for r in native if r.get('event')=='menu-begin' and r.get('pid')==plan['subjectPID']
            and r.get('runID')==lease['runID'] and r.get('epoch')==lease['epoch']
            and r.get('checks',{}).get('surface')=='status' and type(r.get('mono')) in (int,float)
            and 0<=r['mono']-first_up['mono']<=3),None)
        if a is None: raise ValueError('first-menu-arrival-missing')
        a_id=a.get('checks',{}).get('sessionID');object_id=a.get('checks',{}).get('menuObjectID')
        ended=any(r.get('event')=='menu-end' and r.get('pid')==plan['subjectPID']
            and r.get('runID')==lease['runID'] and r.get('epoch')==lease['epoch']
            and r.get('checks',{}).get('sessionID')==a_id and type(r.get('mono')) in (int,float)
            and r['mono']<down[0]['mono'] for r in native)
        if not ended: raise ValueError('first-menu-not-ended')
        observed=[r for r in observed if r.get('checks',{}).get('sessionID') not in (None,a_id)
                  and r.get('checks',{}).get('menuObjectID')==object_id]
    if not observed: raise ValueError('native-arrival-missing')
    print(json.dumps(dict(input=kind,outcome='arrived',runID=lease['runID'],epoch=lease['epoch'])))

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('mode',choices=('make','check','window'))
    p.add_argument('--config',type=Path,required=True)
    p.add_argument('--kind',choices=('dock','status'),required=True)
    p.add_argument('--purpose',choices=('refresh','clear'),default='refresh')
    a=p.parse_args(); c=json.loads(a.config.read_text())
    if a.mode == 'make': make(c,a.kind,a.purpose)
    elif a.mode == 'check': check(c,a.kind,a.purpose)
    else:
        if a.kind != 'dock': raise ValueError('only-owned-dock-window-can-be-captured')
        load_and_admit(c)
        plan=json.loads((Path(c['batch'])/'dock-pointer-plan.json').read_text())
        number=plan.get('u6OwnedWindowNumber')
        if type(number) is not int or number <= 0: raise ValueError('owned-window-missing')
        print(number)
if __name__ == '__main__': main()
