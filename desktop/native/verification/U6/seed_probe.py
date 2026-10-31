# SPDX-License-Identifier: MIT
"""Read the real released CLI using exactly Launch's four child-environment keys."""
import argparse,hashlib,json,os,subprocess,sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[4]
sys.path.insert(0,str(ROOT/'tools/u14'))
from engine_process import EngineProcess
from engine_runner import fresh_rows

def probe_seed(helper,home,tmp,tool='copilot',mode='first',expected_title_hash=None):
    home=Path(home).resolve()
    candidates=[home/'.local/bin/copilot',home/'bin/copilot']
    resolved=next((p for p in candidates if p.is_file() and os.access(p,os.X_OK)),None)
    if resolved!=home/'bin/copilot' or resolved.is_symlink():raise ValueError('synthetic-stub-not-resolved')
    cache=home/('Library/Caches/modelplan' if sys.platform=='darwin' else '.cache/modelplan')
    if mode=='first' and any((cache/name).exists() for name in ('observed/native.json','observed/copilot-v1.json')):
        raise ValueError('first-attempt-reading-or-cooldown-present')
    if mode=='first' and (home/'runtime-calls').exists():raise ValueError('first-attempt-stub-already-called')
    env=dict(PATH='/usr/bin:/bin',HOME=str(Path(home).resolve()),TMPDIR=str(Path(tmp).resolve()),LANG='en_US.UTF-8')
    result=subprocess.run([str(helper),'quota','--json','--offline'],env=env,text=True,capture_output=True,timeout=20)
    if result.returncode!=0:raise ValueError('launch-environment-quota-failed')
    report=json.loads(result.stdout)
    if mode=='refreshed' and not report.get('accounts'):raise ValueError('launch-environment-seeded-account-missing')
    if mode=='first' and report.get('accounts'):raise ValueError('first-attempt-reading-present')
    engine=EngineProcess(helper,home,'u6-seed-probe',arguments=('--offline','--read-only'))
    engine.environment=env
    with engine:
        engine.initialize()
        consent=engine.request('consent/get')['result']['data']
        if not any(x.get('scope')=='copilot.runtime_usage' and x.get('state')=='allowed' for x in consent.get('scopes',[])):
            raise ValueError('synthetic-grant-missing')
        projection=fresh_rows(engine)
        row=next((row for row in projection['rows'] if row['id']==tool),None)
        if row is None:raise ValueError('launch-environment-private-row-missing')
        if mode=='first' and row.get('accounts'):raise ValueError('first-attempt-row-present')
        if mode=='refreshed' and not row.get('accounts'):raise ValueError('refreshed-row-missing')
        title=row['name']['en']
        if not isinstance(title,str) or not title:raise ValueError('catalogue-title-missing')
        if expected_title_hash is not None and hashlib.sha256(title.encode()).hexdigest()!=expected_title_hash:
            raise ValueError('catalogue-title-hash-mismatch')
        return title

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    for name in ('helper','home','tmp'):p.add_argument('--'+name,type=Path,required=True)
    p.add_argument('--tool',default='copilot');p.add_argument('--mode',choices=('first','refreshed'),default='first');a=p.parse_args()
    title=probe_seed(a.helper,a.home,a.tmp,a.tool,mode=a.mode)
    print(json.dumps(dict(tool=a.tool,mode=a.mode,verified=True,titleSHA256=hashlib.sha256(title.encode()).hexdigest())))
