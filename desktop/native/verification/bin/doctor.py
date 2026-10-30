# SPDX-License-Identifier: MIT
"""Report each supplied native observation separately; never probe the host."""
import argparse,json
from pathlib import Path
CONDITIONS=('running','active','key','visible','WebKit','disk','lease')
def doctor(observation):
    timestamp=observation.get('timestamp')
    if not isinstance(timestamp,str) or not timestamp:raise ValueError('native timestamp required')
    call=observation.get('activationCall')
    if not isinstance(call,str) or not call:raise ValueError('actual activation call or not-invoked required')
    aliases={'active':'appActive','key':'keyWindow','visible':'windowVisible'}
    checks={k:{'status':'pass' if observation.get(k,observation.get(aliases.get(k,''))) is True else 'fail','timestamp':timestamp} for k in CONDITIONS}
    return {'checks':checks,'activationCall':call,'timestamp':timestamp,
            'outcome':'pass' if all(v['status']=='pass' for v in checks.values()) else 'not-run'}
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('input',type=Path);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    result=doctor(json.loads(a.input.read_text()))
    with a.output.open('x') as f:json.dump(result,f,indent=2)
if __name__=='__main__':main()
