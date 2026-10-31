# SPDX-License-Identifier: MIT
"""M1-only capture of the admitted App's Dock panel, bound to its native frame row."""
import argparse, hashlib, json, subprocess, sys, time
from pathlib import Path

BIN=Path(__file__).resolve().parents[1]/'bin'
sys.path.insert(0,str(BIN))
from admission import still_admitted # action phase: launch admission already checked the full budget
from guardian import cleanup,identity,launcher_lost

def system_uptime(): return time.clock_gettime(time.CLOCK_UPTIME_RAW)

def capture(config, run_capture=subprocess.run, now=system_uptime):
    still_admitted(config)
    batch=Path(config['batch']);lease=config['expectedLease']
    reg=json.loads(Path(config['subjectPidPath']).read_text())
    pid=reg.get('pid')
    if type(pid) is not int or pid<=0 or reg.get('state')!='running' or not cleanup.matches(identity(pid),reg) or launcher_lost(Path(config['subjectPidPath'])):
        raise ValueError('registered-subject-unavailable')
    native=batch/'native-observations.jsonl'
    if not native.is_file() or native.is_symlink() or native.stat().st_size>8_000_000:raise ValueError('native-rows-unavailable')
    rows=[json.loads(line) for line in native.read_text().splitlines() if line.strip()]
    frames=[row for row in rows if row.get('event')=='dock-surface-frame' and row.get('runID')==lease['runID']
            and row.get('epoch')==lease['epoch'] and row.get('pid')==pid
            and row.get('checks',{}).get('state')=='expanded' and type(row.get('seq')) is int
            and type(row.get('mono')) in (int,float) and type(row.get('checks',{}).get('windowNumber')) is int]
    if not frames:raise ValueError('owned-expanded-frame-missing')
    frame=frames[-1];window=frame['checks']['windowNumber']
    if window<=0 or not 0<=now()-frame['mono']<=5:raise ValueError('owned-frame-stale')
    image=batch/'dock-owned.png';receipt=batch/'dock-capture.json'
    if image.exists() or receipt.exists():raise ValueError('capture-not-fresh')
    result=run_capture(['screencapture','-x','-l',str(window),str(image)],capture_output=True,timeout=5)
    if result.returncode!=0 or not image.is_file() or image.is_symlink() or image.stat().st_size==0:
        raise ValueError('owned-capture-unavailable')
    value=dict(schema='u6-capture/1',runID=lease['runID'],epoch=lease['epoch'],pid=pid,
               windowNumber=window,frameSeq=frame['seq'],mono=now(),file=image.name,
               sha256=hashlib.sha256(image.read_bytes()).hexdigest())
    with receipt.open('x') as stream:json.dump(value,stream,sort_keys=True);stream.write('\n')
    print(json.dumps(dict(capture='owned-dock',frameSeq=frame['seq'])))

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--config',type=Path,required=True)
    a=p.parse_args();capture(json.loads(a.config.read_text()))
