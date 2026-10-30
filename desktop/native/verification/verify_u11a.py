# SPDX-License-Identifier: MIT
"""Validate observation evidence, not performance statistics or a GUI lease."""
import argparse
import json
from pathlib import Path

GROUPS=('indicator','session','HUD')

def context(row):
    view=row.get("viewID");gen=row.get("generation")
    return (view,gen) if isinstance(view,str) and view and type(gen) is int and gen>=0 else None

def verify_context(rows):
    windows=[x for x in rows if x.get('event')=='window-observation']
    keys=('appActive','keyWindow','windowVisible','occlusionVisible')
    valid=[x for x in windows if all(type(x.get(k)) is bool for k in keys)]
    activation=bool(valid) and any(all(x[k] for k in keys) for x in valid)
    frames=[x for x in rows if x.get('event')=='animation-frames' and x.get('documentVisible') is True]
    groups={}
    for group in GROUPS:
        values=[x.get('groups',{}).get(group,{}).get('advancingFrames') for x in frames]
        values=[v for v in values if type(v) is int and v>=0]
        groups[group]='pass' if len(values)>=2 and all(b>=a for a,b in zip(values,values[1:])) and values[-1]>values[0] else 'unproven'
    pids=[x for x in rows if x.get('event')=='process-attribution' and x.get('role')=='WebContent']
    attributed=[x for x in pids if x.get('status')=='attributed' and type(x.get('pid')) is int and x['pid']>0
                and all(type(x.get(k)) is int and x[k]>=0 for k in ('generation','startSeconds','startMicroseconds'))]
    return {'activation':'pass' if activation else 'unproven','windowObservations':valid,
            'animationGroups':groups,'WebContent':'attributed' if attributed else 'unsupported',
            'budgetVerdict':'unproven; use the canonical reducer and complete role/phase coverage',
            'observationReady':activation and all(v=='pass' for v in groups.values()) and bool(attributed)
                and len({(x['pid'],x['startSeconds'],x['startMicroseconds']) for x in attributed})==1}

def verify(rows):
    contexts={}
    for row in rows:
        key=context(row)
        if key is not None:contexts.setdefault(key,[]).append(row)
    results=[dict(viewID=k[0],generation=k[1],**verify_context(v)) for k,v in contexts.items()]
    return {'contexts':results,'observationReady':any(r['observationReady'] for r in results),
            'budgetVerdict':'unproven; observation evidence does not establish the performance budget'}

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('evidence',type=Path);p.add_argument('--output',required=True,type=Path)
    a=p.parse_args();rows=[json.loads(x) for x in a.evidence.read_text().splitlines() if x.strip()]
    with a.output.open('x') as f:json.dump(verify(rows),f,indent=2)

if __name__=='__main__':main()
