# SPDX-License-Identifier: MIT
"""One pre-click capture, restricted to the admitted owned status-button rectangle."""
import argparse,hashlib,importlib.util,json,math,subprocess,sys
from pathlib import Path
BIN=Path(__file__).resolve().parents[1]/'bin'
sys.path.insert(0,str(BIN));sys.path.insert(0,str(Path(__file__).resolve().parent))
from admission import still_admitted
from guardian import cleanup,identity,launcher_lost
from u6_clock import system_uptime
spec=importlib.util.spec_from_file_location('u6_capture_status_pointer',BIN/'u6-pointer-plan.py')
pointer=importlib.util.module_from_spec(spec);spec.loader.exec_module(pointer)

def capture(config,run_capture=subprocess.run,now=system_uptime):
    batch=Path(config['batch']);lease=config['expectedLease']
    reg=json.loads(Path(config['subjectPidPath']).read_text());pid=reg.get('pid')
    plan=json.loads((batch/'status-pointer-plan.json').read_text())
    def current():
        still_admitted(config)
        if (type(pid) is not int or pid<=0 or reg.get('state')!='running'
            or (reg.get('runID'),reg.get('epoch'))!=(lease['runID'],lease['epoch'])
            or not cleanup.matches(identity(pid),reg) or launcher_lost(Path(config['subjectPidPath']))):
            raise ValueError('registered-subject-unavailable')
        if (plan.get('runID'),plan.get('epoch'),plan.get('subjectPID'))!=(lease['runID'],lease['epoch'],pid):
            raise ValueError('wrong-subject')
        row,rect=pointer.latest_frame(pointer.rows(batch/'native-observations.jsonl'),'status-item-frame',lease['runID'],lease['epoch'],pid,now=now())
        c=row['checks']
        if (c.get('frameGeneration')!=plan.get('u6StatusFrameGeneration') or c.get('windowNumber')!=plan.get('u6StatusWindowNumber')
            or plan.get('statusWindowCheck')!=pointer.window_mode(c.get('windowNumber'))):raise ValueError('owned-frame-changed')
        return row,rect
    frame,rect=current();x,y,w,h=rect;band=frame['checks']['menuBarBand']
    # An inward integer crop never includes pixels outside the owned native frame.
    crop=[math.ceil(x),math.ceil(y),math.floor(x+w)-math.ceil(x),math.floor(y+h)-math.ceil(y)]
    if (crop[2]<=0 or crop[3]<=0 or h>24 or not pointer.contains(band,(x,y))
        or x+w>band[0]+band[2] or y+h>band[1]+band[3]):raise ValueError('owned-status-rectangle-unavailable')
    image=batch/'status-preclick.png';receipt=batch/'status-preclick-capture.json'
    if image.exists() or receipt.exists():raise ValueError('capture-not-fresh')
    started=now()
    result=run_capture(['screencapture','-x','-R',','.join(map(str,crop)),str(image)],capture_output=True,timeout=5)
    if result.returncode or not image.is_file() or image.is_symlink() or not image.stat().st_size:raise ValueError('owned-capture-unavailable')
    after,after_rect=current()
    if after_rect!=rect or after['checks']['frameGeneration']!=frame['checks']['frameGeneration']:raise ValueError('owned-frame-changed')
    value=dict(schema='u6-status-capture/1',runID=lease['runID'],epoch=lease['epoch'],pid=pid,
        frameSeq=frame['seq'],planFrameSeq=plan['u6FrameSeq'],frameGeneration=frame['checks']['frameGeneration'],
        windowNumber=frame['checks']['windowNumber'],statusWindowCheck=plan['statusWindowCheck'],
        captureMethod='owned-status-rectangle',rectangle=crop,monoStart=started,mono=now(),file=image.name,
        sha256=hashlib.sha256(image.read_bytes()).hexdigest())
    with receipt.open('x') as out:json.dump(value,out,sort_keys=True);out.write('\n')
    print(json.dumps(dict(capture='owned-status-preclick',frameSeq=frame['seq'])))

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--config',type=Path,required=True)
    a=p.parse_args();capture(json.loads(a.config.read_text()))
