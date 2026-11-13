# SPDX-License-Identifier: MIT
"""Export genuine own-process counters; canonical reducer computes statistics."""
import argparse,json
from pathlib import Path

def export(rows,run):
    out=[];previous={}
    for r in rows:
        if r.get('event')!='app-sample':continue
        key=(r['pid'],r['cycle']);old=previous.get(key);cpu=None
        if old is not None and r.get('cpuSeconds') is not None and old.get('cpuSeconds') is not None:
            dt=r['elapsedSeconds']-old['elapsedSeconds'];dc=r['cpuSeconds']-old['cpuSeconds']
            if dt>0 and dc>=0:cpu=100*dc/dt
        previous[key]=r
        row=dict(run_id=run,scenario='A-cycle'+str(r['cycle']),timestamp=r['timestampUnix'],role='App',phase=r['phase'],pid=r['pid'],cpu_percent=cpu,rss_bytes=r.get('rssBytes'),energy_impact=None)
        out.append(row)
        out.append(row|dict(scenario='A-repeated',phase='repeated-open-close',cycle=r['cycle']))
    return out

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('input',type=Path);p.add_argument('--run',required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    rows=export([json.loads(x) for x in a.input.read_text().splitlines()],a.run)
    with a.output.open('x') as f:
        for r in rows:f.write(json.dumps(r)+'\n')
if __name__=='__main__':main()
