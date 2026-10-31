# SPDX-License-Identifier: MIT
"""U6-only Refresh request after physical status-item click was natively observed."""
import argparse, json, sys, time, uuid
from pathlib import Path

BIN=Path(__file__).resolve().parents[1]/'bin'
sys.path.insert(0,str(BIN))
from admission import load_and_admit
from guardian import cleanup, identity, launcher_lost
import importlib.util
spec=importlib.util.spec_from_file_location('u6_pointer_plan', BIN/'u6-pointer-plan.py')
pointer=importlib.util.module_from_spec(spec);spec.loader.exec_module(pointer)

def prepare(config):
    load_and_admit(config)
    batch=Path(config['batch']);run=config['expectedLease']
    record=json.loads(Path(config['subjectPidPath']).read_text())
    pid=record.get('pid')
    if type(pid) is not int or pid <= 0 or record.get('state') != 'running' or not cleanup.matches(identity(pid),record) or launcher_lost(Path(config['subjectPidPath'])):
        raise ValueError('registered-subject-unavailable')
    pointer.check(config,'status') # physical click plus owned menu-begin, not AXPress on status item
    observation=batch/'native-observations.jsonl'
    request=dict(profile='synthetic',runID=run['runID'],epoch=run['epoch'],subjectPID=pid,
                 requestID=str(uuid.uuid4()).upper(),action='refresh',notBefore=run['notBefore'],expiresAt=run['expiresAt'])
    plan=dict(profile='synthetic',runID=run['runID'],epoch=run['epoch'],lease=config['leasePath'],stop=config['stopPath'],
              output=str(batch/'menu-drive.jsonl'),subjectPID=pid,subjectBundle=str(Path(config['argv'][0]).resolve().parent.parent.parent),
              allowedRectangles=[],steps=[],statusMenu=dict(itemName='Refresh / 刷新',openMenu=False,timeoutSeconds=5,
              arrivals=str(observation),request=request))
    for name,object in [('menu-request.json',request),('menu-plan.json',plan)]:
        with (batch/name).open('x') as stream:json.dump(object,stream,indent=2);stream.write('\n')
    print('U6 Refresh request prepared after physical status click and native menu begin; no new input sent.')

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--config',type=Path,required=True)
    a=p.parse_args();prepare(json.loads(a.config.read_text()))
