# SPDX-License-Identifier: MIT
"""Launch-mode scenario registry (scenarios.json), used by SKILL.md's launch branch.
  name --config C           print the run config's registered scenario, or nothing for an unregistered launch
  prepare|drive --config C  run that scenario's step with `--config C` and exit with its status
  build --scenario S --config C [-- ARGS]
                            before `book.py start`: run S's `config` builder, which creates C (it must not exist)
  has-actions --config C    print `actions` when the scenario registers an action runner, else nothing
  started --config C        wait at most 15 s for the registered subject's native `started` row (`observations`)
  actions --config C [-- ARGS]
                            run the scenario's action runner (ARGS from the unit's doc) and exit with its status
Steps are scripts inside the verification kit (relative to the registry). launch.py uses `resolve` to require a
scenario's preparation receipt; any ambiguity refuses."""
import argparse,json,shlex,signal,subprocess,sys,time
from pathlib import Path
REGISTRY=Path(__file__).resolve().with_name('scenarios.json')
OPTIONAL=('config','actions','observations')
STARTED_SECONDS=15 # C2.4 section 7: the bounded wait for the native `started` row
def load(path=None):
    reg=json.loads(Path(path or REGISTRY).read_text())
    if not isinstance(reg,dict):raise ValueError('scenario registry invalid')
    for name,e in reg.items():
        if not isinstance(e,dict) or not all(isinstance(e.get(k),str) and e[k] for k in ('prepare','drive')) \
                or not isinstance(e.get('receipt'),bool) or not isinstance(e.get('argvFlag',''),str) \
                or any(k in e and not (isinstance(e[k],str) and e[k]) for k in OPTIONAL):raise ValueError('scenario registry invalid')
    return reg
def resolve(c,path=None):
    """(name, entry) of a run config's registered scenario, or None for an unregistered launch.
    Triggered by the config's `scenario` OR any registered argvFlag in argv; a disagreement refuses."""
    argv=c.get('argv') if isinstance(c.get('argv'),list) else []
    try:reg=load(path)
    except (OSError,ValueError,TypeError):raise ValueError('scenario registry unreadable')  # cannot prove a run is unregistered
    flagged=[n for n,e in reg.items() if e.get('argvFlag') and any(isinstance(x,str) and (x==e['argvFlag'] or x.startswith(e['argvFlag']+'=')) for x in argv)]
    if 'scenario' not in c and not flagged:return None
    if 'scenario' in c and (not isinstance(c['scenario'],str) or c['scenario'] not in reg):raise ValueError('unknown scenario')
    name=c['scenario'] if 'scenario' in c else flagged[0]
    if flagged!=([name] if reg[name].get('argvFlag') else []):raise ValueError('scenario/argv mismatch')
    return name,reg[name]
def script_command(entry,step,config,extra=(),path=None):
    """The step's script, resolved relative to the registry and confined to the verification kit."""
    if step not in entry:raise ValueError(f'scenario has no {step} step')
    script,*args=shlex.split(entry[step]);base=Path(path or REGISTRY).resolve().parent;kit=base.parent
    target=(base/script).resolve()
    if Path(script).is_absolute() or not target.is_relative_to(kit) or not target.is_file():
        raise ValueError('scenario step must be a script inside the verification kit')
    return [sys.executable,str(target),*args,*extra,'--config',str(config)]
def command(c,step,config,path=None,extra=()):
    found=resolve(c,path)
    if not found:raise ValueError('no registered scenario')
    return script_command(found[1],step,config,extra,path)
def run_step(cmd):
    """Run the step and pass TERM/INT/HUP on to it, so stopping this recorded PID never orphans the step."""
    child=subprocess.Popen(cmd);signals=(signal.SIGTERM,signal.SIGINT,signal.SIGHUP)
    prior=[signal.signal(s,lambda sig,_:child.send_signal(sig)) for s in signals]
    try:return child.wait()
    finally:
        for s,h in zip(signals,prior):signal.signal(s,h)
def read(path):
    try:return json.loads(Path(path).read_text())
    except (OSError,ValueError):return None
def started(c,path=None,seconds=STARTED_SECONDS,clock=time.monotonic,sleep=time.sleep):
    """True once the subject launch.py registered for this run/epoch wrote its native `started` row; False after
    at most STARTED_SECONDS. Reads only; the drive step (monitor) keeps checking the subject's identity."""
    found=resolve(c,path)
    if not found or 'observations' not in found[1]:raise ValueError('scenario declares no native observations')
    e=c.get('expectedLease') or {};run,epoch=e.get('runID'),e.get('epoch')
    rows_path=Path(c['batch'])/found[1]['observations'];end=clock()+min(seconds,STARTED_SECONDS)
    while True:
        reg=read(c['subjectPidPath'])
        pid=reg.get('pid') if isinstance(reg,dict) and reg.get('state')=='running' and reg.get('runID')==run and reg.get('epoch')==epoch else None
        if type(pid) is int and pid>0:
            try:rows=[json.loads(x) for x in rows_path.read_text().splitlines() if x.strip()]
            except (OSError,ValueError):rows=[]
            if any(isinstance(r,dict) and r.get('event')=='started' and (r.get('runID'),r.get('epoch'),r.get('pid'))==(run,epoch,pid) for r in rows):return True
        if clock()>=end:return False
        sleep(.1)
def build(name,config,extra,path=None):
    """Run the scenario's config builder before the booking starts; it must create exactly `config` for `name`."""
    reg=load(path)
    if name not in reg:raise ValueError('unknown scenario')
    config=Path(config)
    if config.exists() or config.is_symlink():raise ValueError('run config exists: use a new attempt directory')
    status=run_step(script_command(reg[name],'config',config,extra,path))
    if status:return status
    built=read(config)
    try:ok=isinstance(built,dict) and (resolve(built,path) or (None,))[0]==name
    except ValueError:ok=False
    if not ok:raise ValueError('builder did not create this scenario\'s run config')
    return 0
def main(argv=None,path=None):
    p=argparse.ArgumentParser(description=__doc__,formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('step',choices=('name','prepare','drive','build','has-actions','started','actions'))
    p.add_argument('--config',type=Path,required=True);p.add_argument('--scenario')
    argv=list(sys.argv[1:] if argv is None else argv);cut=argv.index('--') if '--' in argv else len(argv)
    a=p.parse_args(argv[:cut]);a.extra=argv[cut+1:] # everything after -- goes to the step unchanged
    if a.extra and a.step not in ('build','actions'):p.error('extra arguments are only for build and actions')
    if (a.scenario is not None)!=(a.step=='build'):p.error('--scenario is required for build and only for build')
    if a.step=='build':return build(a.scenario,a.config,a.extra,path)
    c=json.loads(a.config.read_text())
    if a.step=='name':found=resolve(c,path);print(found[0] if found else '');return 0
    if a.step=='has-actions':found=resolve(c,path);print('actions' if found and 'actions' in found[1] else '');return 0
    if a.step=='started':return 0 if started(c,path) else 3
    return run_step(command(c,a.step,a.config,path,a.extra))
if __name__=='__main__':sys.exit(main())
