#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Owns two synthetic native processes and always tears them down. No event injection."""
import argparse,hashlib,json,pathlib,signal,subprocess,sys,time
p=argparse.ArgumentParser();p.add_argument('--build',type=pathlib.Path,required=True);p.add_argument('--evidence',type=pathlib.Path,required=True);p.add_argument('--measure',action='store_true');p.add_argument('--seconds',type=int,default=600);p.add_argument('--reveal-after',type=float,default=30);a=p.parse_args()
a.evidence.mkdir(parents=True,exist_ok=True)
children=[];stopped=False;launch=[]
def stop(sig,frame):
    global stopped
    stopped=True
signal.signal(signal.SIGINT,stop);signal.signal(signal.SIGTERM,stop)
try:
    for name,extra in [('ModelPlanInputReceiver',['--receiver']),('ModelPlanWindowProbe',['--auto-reveal-after',str(a.reveal_after)])]:
        executable=a.build/(name+'.app')/'Contents/MacOS'/name
        args=[str(executable),*extra,'--seconds',str(min(1800,max(100,a.seconds))),'--receipt',str(a.evidence/(name+'-events.json'))]
        if a.measure:args+=['--no-activate']
        child=subprocess.Popen(args,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL);children.append(child)
        launch.append({'name':name,'pid':child.pid,'executableSHA256':hashlib.sha256(executable.read_bytes()).hexdigest()})
        time.sleep(1)
    (a.evidence/'launch.json').write_text(json.dumps({'schemaVersion':1,'processes':launch,'mode':'idle-resource' if a.measure else 'manual-input'},indent=2)+'\n')
    print('Synthetic processes:',[p.pid for p in children],flush=True)
    if a.measure:
        # A controlled idle resource sample, separate from manual input. No claim about WindowServer/GPU.
        for _ in range(30):
            if stopped or any(c.poll() is not None for c in children):raise RuntimeError('interrupted warmup')
            time.sleep(1)
        command=[sys.executable,str(pathlib.Path(__file__).with_name('sample-owned.py')),'--seconds','60','--output',str(a.evidence/'resource.json')]
        for c in children:command+=['--pid',str(c.pid)]
        sampler=subprocess.Popen(command)
        while sampler.poll() is None:
            if stopped:
                sampler.terminate();sampler.wait();raise RuntimeError('interrupted sample')
            time.sleep(.2)
        if sampler.returncode:raise RuntimeError('sampler failed')
    else:
        deadline=time.monotonic()+min(1800,max(10,a.seconds))
        while not stopped and time.monotonic()<deadline and all(c.poll() is None for c in children):time.sleep(.2)
finally:
    for c in children:
        if c.poll() is None:c.terminate()
    for c in children:
        try:c.wait(timeout=5)
        except subprocess.TimeoutExpired:c.kill();c.wait()
    (a.evidence/'cleanup.json').write_text(json.dumps({'schemaVersion':1,'ownedProcessesExited':all(c.poll() is not None for c in children),'exitCodes':[c.returncode for c in children]})+'\n')
