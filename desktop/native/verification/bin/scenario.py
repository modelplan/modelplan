# SPDX-License-Identifier: MIT
"""Launch-mode scenario registry (scenarios.json). Usage: scenario.py name|prepare|drive --config <run.json>.
`name` prints the run config's registered scenario, or nothing for an unregistered launch. `prepare`/`drive`
run that scenario's step (a script beside the registry) with `--config` and exit with its status.
launch.py uses `resolve` to require a scenario's preparation receipt; any ambiguity refuses."""
import argparse,json,shlex,subprocess,sys
from pathlib import Path
REGISTRY=Path(__file__).resolve().with_name('scenarios.json')
def load(path=None):
    reg=json.loads(Path(path or REGISTRY).read_text())
    if not isinstance(reg,dict):raise ValueError('scenario registry invalid')
    for name,e in reg.items():
        if not isinstance(e,dict) or not all(isinstance(e.get(k),str) and e[k] for k in ('prepare','drive')) \
                or not isinstance(e.get('receipt'),bool) or not isinstance(e.get('argvFlag',''),str):raise ValueError('scenario registry invalid')
    return reg
def resolve(c,path=None):
    """(name, entry) of a run config's registered scenario, or None for an unregistered launch.
    Triggered by the config's `scenario` OR any registered argvFlag in argv; a disagreement refuses."""
    argv=c.get('argv') if isinstance(c.get('argv'),list) else []
    try:reg=load(path)
    except (OSError,ValueError,TypeError):
        # Without the registry no flag can be matched: refuse anything that could be a registered scenario.
        if 'scenario' in c or any(isinstance(x,str) and x.startswith('--') for x in argv):raise ValueError('scenario registry unreadable')
        return None
    flagged=[n for n,e in reg.items() if e.get('argvFlag') and e['argvFlag'] in argv]
    if 'scenario' not in c and not flagged:return None
    if 'scenario' in c and (not isinstance(c['scenario'],str) or c['scenario'] not in reg):raise ValueError('unknown scenario')
    name=c['scenario'] if 'scenario' in c else flagged[0]
    if flagged!=([name] if reg[name].get('argvFlag') else []):raise ValueError('scenario/argv mismatch')
    return name,reg[name]
def command(c,step,config,path=None):
    found=resolve(c,path)
    if not found:raise ValueError('no registered scenario')
    script,*args=shlex.split(found[1][step]);base=Path(path or REGISTRY).resolve().parent
    if Path(script).name!=script or not (base/script).is_file():raise ValueError('scenario step must be a script beside the registry')
    return [sys.executable,str(base/script),*args,'--config',str(config)]
def main(argv=None,path=None):
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('step',choices=('name','prepare','drive'));p.add_argument('--config',type=Path,required=True);a=p.parse_args(argv)
    c=json.loads(a.config.read_text())
    if a.step=='name':found=resolve(c,path);print(found[0] if found else '');return 0
    return subprocess.run(command(c,a.step,a.config,path)).returncode
if __name__=='__main__':sys.exit(main())
