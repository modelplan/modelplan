# SPDX-License-Identifier: MIT
"""Attribute supplied isolated-session snapshots; never enumerate OS processes."""
import argparse,json
from pathlib import Path
def identity(p):return p.get('pid'),p.get('startSeconds'),p.get('startMicroseconds')
def attribute(before,after,webcontent):
    unknown={'WebContent':{'status':'unsupported'},'GPU':{'status':'unsupported'}}
    if before.get('scope')!='isolated-synthetic-WebKit' or after.get('scope')!=before['scope'] or not before.get('sessionID') or before['sessionID']!=after.get('sessionID'):
        return unknown|{'reason':'isolated-session-scope-unconfirmed'}
    if before.get('processes'):return unknown|{'reason':'other-preexisting-WebKit-host'}
    processes=after.get('processes',[])
    if any(type(p.get('pid')) is not int or p['pid']<=0 or any(type(p.get(k)) is not int or p[k]<0 for k in ('startSeconds','startMicroseconds')) for p in processes):
        return unknown|{'reason':'PID-start-identity-missing'}
    wc=[p for p in processes if p.get('kind')=='WebContent' and identity(p)==identity(webcontent)]
    gpu=[p for p in processes if p.get('kind')=='GPU']
    known=wc+gpu;unassigned=[p for p in processes if p not in known]
    result=unknown|{'method':'isolated-session-pre/post-PID-diff plus owned-view WebContent PID/start identity'}
    if len(wc)==1:result['WebContent']={'status':'attributed',**wc[0]}
    if len(gpu)==1 and not unassigned:result['GPU']={'status':'attributed',**gpu[0]}
    if unassigned or len(gpu)!=1:result['reason']='ambiguous-or-unattributed-WebKit-host'
    return result
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('input',type=Path);p.add_argument('--output',required=True,type=Path);a=p.parse_args();d=json.loads(a.input.read_text())
    with a.output.open('x') as f:json.dump(attribute(d['before'],d['after'],d['ownedWebContent']),f,indent=2)
if __name__=='__main__':main()
