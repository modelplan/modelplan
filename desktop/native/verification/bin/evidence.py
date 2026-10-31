# SPDX-License-Identifier: MIT
"""Create a new evidence manifest; no measurement reduction or upload."""
import argparse,hashlib,json,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from artifact_paths import is_appledouble
OUTCOMES={'pass','fail','not-run','unsupported','timeout'}
def manifest(config,root):
    for k in ('headSHA','profile','attributionMethod'):
        if not isinstance(config.get(k),str) or not config[k]:raise ValueError('missing '+k)
    if config['profile']!='synthetic':raise ValueError('synthetic evidence only')
    if not config.get('scenarios') or any(not x.get('id') or x.get('outcome') not in OUTCOMES for x in config['scenarios']):raise ValueError('explicit scenario outcomes required')
    root=root.resolve(strict=True)
    scenarios=[]
    for original in config['scenarios']:
        scenario=dict(original)
        if scenario['id'].startswith('U11a') and any(scenario.get(k) is not True for k in ('gate','frameProof','postClose')):
            scenario['outcome']='not-run'
        scenarios.append(scenario)
    files=[]
    for name in config.get('files',[]):
        p=Path(name)
        if p.is_absolute() or '..' in p.parts:raise ValueError('relative evidence path required')
        if is_appledouble(p):continue
        target=root/p
        if any((root/Path(*p.parts[:i])).is_symlink() for i in range(1,len(p.parts)+1)) or not target.is_file():raise ValueError('regular evidence file required')
        data=target.read_bytes();files.append({'path':p.as_posix(),'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()})
    return {'schemaVersion':1,**{k:config[k] for k in ('headSHA','profile','attributionMethod','scenarios')},'files':files,'scenarios':scenarios}
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--config',type=Path,required=True);p.add_argument('--batch',type=Path,required=True);a=p.parse_args()
    # Caller selects the approved exchange batch; no fallback/copy/upload route.
    if not a.batch.is_dir():raise ValueError('approved batch missing')
    r=manifest(json.loads(a.config.read_text()),a.batch)
    with (a.batch/'manifest.json').open('x') as f:json.dump(r,f,indent=2)
if __name__=='__main__':main()
