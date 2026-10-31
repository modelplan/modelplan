# SPDX-License-Identifier: MIT
"""Read the real released CLI using exactly Launch's four child-environment keys."""
import argparse,hashlib,json,os,subprocess,sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[4]
sys.path.insert(0,str(ROOT/'tools/u14'))
sys.path.insert(0,str(Path(__file__).resolve().parent))
from engine_process import EngineProcess
from engine_runner import fresh_rows
from stub_runtime import verify_selection
from reading_fingerprint import reading_sha256

def probe_seed(helper,home,tmp,tool='copilot',mode='first',expected_title_hash=None,expected_stub_hash=None,details=False):
    home=Path(home).resolve()
    verify_selection(home,expected_stub_hash) # paths and bytes only, before any helper/provider execution
    cache=home/('Library/Caches/modelplan' if sys.platform=='darwin' else '.cache/modelplan')
    if mode=='first' and any((cache/name).exists() for name in ('observed/native.json','observed/copilot-v1.json')):
        raise ValueError('first-attempt-reading-or-cooldown-present')
    if mode=='first' and (home/'.modelplan-stub/runtime-calls.jsonl').exists():raise ValueError('first-attempt-stub-already-called')
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
        if details:
            return dict(title=title,readingSHA256=reading_sha256(row['accounts']))
        return title

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    for name in ('helper','home','tmp'):p.add_argument('--'+name,type=Path,required=True)
    p.add_argument('--tool',default='copilot');p.add_argument('--mode',choices=('first','refreshed'),default='first')
    p.add_argument('--stub-sha256',required=True);a=p.parse_args()
    title=probe_seed(a.helper,a.home,a.tmp,a.tool,mode=a.mode,expected_stub_hash=a.stub_sha256)
    print(json.dumps(dict(tool=a.tool,mode=a.mode,verified=True,titleSHA256=hashlib.sha256(title.encode()).hexdigest())))
