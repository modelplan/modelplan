# SPDX-License-Identifier: MIT
"""U6-only physical pointer plan and native arrival check for one admitted subject."""
import argparse, datetime, json, math, sys
from pathlib import Path
from admission import load_and_admit
from guardian import cleanup, identity, launcher_lost

def rows(path):
    data = Path(path).read_bytes()
    if len(data) > 8_000_000: raise ValueError('receipt-limit')
    return [json.loads(line) for line in data.splitlines() if line.strip()]

def latest_frame(observations, event, run, epoch, state=None):
    for row in reversed(observations):
        if row.get('event') != event or row.get('runID') != run or row.get('epoch') != epoch: continue
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

def make(config, kind):
    load_and_admit(config)
    batch = Path(config['batch'])
    lease = config['expectedLease']
    reg = json.loads(Path(config['subjectPidPath']).read_text())
    pid = reg.get('pid')
    if type(pid) is not int or pid <= 0 or reg.get('state') != 'running' or not cleanup.matches(identity(pid),reg) or launcher_lost(Path(config['subjectPidPath'])):
        raise ValueError('subject-registration-invalid')
    event = 'dock-surface-frame' if kind == 'dock' else 'status-item-frame'
    observation, rect = latest_frame(rows(batch/'native-observations.jsonl'),event,lease['runID'],lease['epoch'],'sliver' if kind == 'dock' else None)
    x,y,w,h = rect
    window = observation['checks'].get('windowNumber') if kind == 'dock' else None
    if kind == 'dock' and (type(window) is not int or window <= 0): raise ValueError('owned-window-missing')
    bundle = Path(config['argv'][0]).resolve().parent.parent.parent
    plan = dict(profile='synthetic',runID=lease['runID'],epoch=lease['epoch'],lease=config['leasePath'],stop=config['stopPath'],
        output=str(batch/(kind+'-pointer.jsonl')),subjectPID=pid,subjectBundle=str(bundle),allowedRectangles=[[x,y,w,h]],
        steps=[dict(x=x+w/2,y=y+h/2,seconds=0,dwell=0.25,**({'action':'click'} if kind == 'status' else {}))],
        u6OwnedWindowNumber=window)
    path = batch/(kind+'-pointer-plan.json')
    with path.open('x') as stream: json.dump(plan,stream,indent=2);stream.write('\n')
    print(path)

def check(config, kind):
    batch = Path(config['batch']); lease = config['expectedLease']
    plan = json.loads((batch/(kind+'-pointer-plan.json')).read_text())
    pointer = rows(plan['output'])
    event = 'mouse-moved-posted' if kind == 'dock' else 'mouse-button-up-posted'
    delivered = [r for r in pointer if r.get('event') == event and r.get('runID') == lease['runID'] and r.get('epoch') == lease['epoch'] and r.get('subjectPID') == plan['subjectPID']]
    if not delivered or not any(r.get('event') == 'pointer-result' and r.get('outcome') == 'posted' for r in pointer): raise ValueError('physical-input-not-delivered')
    at = datetime.datetime.fromisoformat(delivered[0]['timestamp'].replace('Z','+00:00')).timestamp()
    native = rows(batch/'native-observations.jsonl')
    event = 'dock-surface-frame' if kind == 'dock' else 'menu-begin'
    observed = [r for r in native if r.get('event') == event and r.get('runID') == lease['runID'] and r.get('epoch') == lease['epoch'] and type(r.get('timestamp')) in (int,float) and r['timestamp'] >= at - 0.5]
    if kind == 'dock': observed = [r for r in observed if r.get('checks',{}).get('state') == 'expanded']
    else: observed = [r for r in observed if r.get('checks',{}).get('surface') == 'status']
    if not observed: raise ValueError('native-arrival-missing')
    print(json.dumps(dict(input=kind,outcome='arrived',runID=lease['runID'],epoch=lease['epoch'])))

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('mode',choices=('make','check','window'))
    p.add_argument('--config',type=Path,required=True)
    p.add_argument('--kind',choices=('dock','status'),required=True)
    a=p.parse_args(); c=json.loads(a.config.read_text())
    if a.mode == 'make': make(c,a.kind)
    elif a.mode == 'check': check(c,a.kind)
    else:
        if a.kind != 'dock': raise ValueError('only-owned-dock-window-can-be-captured')
        load_and_admit(c)
        plan=json.loads((Path(c['batch'])/'dock-pointer-plan.json').read_text())
        number=plan.get('u6OwnedWindowNumber')
        if type(number) is not int or number <= 0: raise ValueError('owned-window-missing')
        print(number)
if __name__ == '__main__': main()
