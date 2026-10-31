# SPDX-License-Identifier: MIT
"""Read the real released CLI using exactly Launch's four child-environment keys."""
import argparse,json,subprocess,sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[4]
sys.path.insert(0,str(ROOT/'tools/u14'))
from engine_process import EngineProcess
from engine_runner import fresh_rows

def probe_seed(helper,home,tmp,tool='copilot'):
    env=dict(PATH='/usr/bin:/bin',HOME=str(Path(home).resolve()),TMPDIR=str(Path(tmp).resolve()),LANG='en_US.UTF-8')
    result=subprocess.run([str(helper),'quota','--json','--offline'],env=env,text=True,capture_output=True,timeout=20)
    if result.returncode!=0:raise ValueError('launch-environment-quota-failed')
    report=json.loads(result.stdout)
    if not report.get('accounts'):raise ValueError('launch-environment-seeded-account-missing')
    engine=EngineProcess(helper,home,'u6-seed-probe',arguments=('--offline','--read-only'))
    engine.environment=env
    with engine:
        engine.initialize();projection=fresh_rows(engine)
        row=next((row for row in projection['rows'] if row['id']==tool and row.get('accounts')),None)
        if row is None:raise ValueError('launch-environment-private-row-missing')
        title=row['name']['en']
        if not isinstance(title,str) or not title:raise ValueError('catalogue-title-missing')
        return title

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    for name in ('helper','home','tmp'):p.add_argument('--'+name,type=Path,required=True)
    p.add_argument('--tool',default='copilot');a=p.parse_args()
    title=probe_seed(a.helper,a.home,a.tmp,a.tool)
    import hashlib
    print(json.dumps(dict(tool=a.tool,accountPresent=True,titleSHA256=hashlib.sha256(title.encode()).hexdigest())))
