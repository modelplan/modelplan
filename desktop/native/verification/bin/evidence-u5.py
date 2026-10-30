# SPDX-License-Identifier: MIT
"""Qualify U5-only receipts; shared Doctor/Evidence remain the gate/hash owners."""
import argparse,importlib.util,json,math
from pathlib import Path
BASE=Path(__file__).resolve().parent

def module(name,path):
    spec=importlib.util.spec_from_file_location(name,path);value=importlib.util.module_from_spec(spec);spec.loader.exec_module(value);return value
DOCTOR=module('u5_doctor',BASE/'doctor.py')
SPEC=json.loads((BASE.parent/'u5-real-input-scenario.json').read_text())
CASES={x['id']:x for x in SPEC['scenarios']}
COMMON=('appStarted','startAnnounced','leaseMatched','watchdogObserved','stopHookObserved','ownedCleanupVerified','helperIdentityVerified')
INPUT_METHODS=('computer-use','os-event-post','owned-ui-automation')

def pinned(receipt):
    for key,size in [('headSHA',40),('binarySHA256',64),('packageSHA256',64),('profileSHA256',64),('helperSHA256',64)]:
        value=receipt.get(key)
        if not isinstance(value,str) or len(value)!=size or any(c not in '0123456789abcdef' for c in value):return False
    version=receipt.get('cliVersion')
    return isinstance(version,str) and version.removeprefix('v')==SPEC['requiredNativeCLIVersion']

def qualify(receipt):
    if receipt.get('profile')!='synthetic':raise ValueError('synthetic profile required')
    outcome={name:'not-run' for name in CASES}
    duration=receipt.get('durationSeconds')
    if not pinned(receipt) or type(duration) not in (int,float) or not math.isfinite(duration) or not 0<duration<=1200:return outcome
    if any(receipt.get(key) is not True for key in COMMON) or receipt.get('stopped') is True:return outcome
    for name,spec in CASES.items():
        case=receipt.get('scenarios',{}).get(name,{})
        if case.get('attempted') is not True:continue
        if case.get('timedOut') is True:outcome[name]='timeout';continue
        if case.get('inputCapability')=='unsupported':outcome[name]='unsupported';continue
        if case.get('inputMethod') not in INPUT_METHODS or case.get('inputDelivered') is not True or case.get('resultObserved') is not True:continue
        native=case.get('nativeObservation')
        if not isinstance(native,dict):continue
        try:gate=DOCTOR.doctor(native,SPEC['doctorScenario'])
        except ValueError:continue
        if gate['outcome']!='pass':continue
        refs=case.get('actionEvidenceFiles')
        if not isinstance(refs,list) or len(refs)<2 or any(not isinstance(x,str) or not x for x in refs):continue
        assertions=case.get('assertions',{})
        if not isinstance(assertions,dict) or any(type(assertions.get(key)) is not bool for key in spec['assertions']):continue
        outcome[name]='pass' if all(assertions[key] for key in spec['assertions']) else 'fail'
    return outcome

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--receipts',type=Path,required=True);p.add_argument('--batch',type=Path,required=True);a=p.parse_args()
    receipt=json.loads(a.receipts.read_text());results=qualify(receipt)
    shared=module('u5_shared_evidence',BASE/'evidence.py')
    refs=list(dict.fromkeys(path for case in receipt.get('scenarios',{}).values() for path in case.get('actionEvidenceFiles',[])))
    config=dict(headSHA=receipt['headSHA'],profile='synthetic',attributionMethod='owned-native-candidate-real-input-and-stubbed-effects',
                scenarios=[dict(id=name,outcome=value) for name,value in results.items()],files=refs)
    result=shared.manifest(config,a.batch)
    result['run']={key:receipt.get(key) for key in COMMON+('durationSeconds','stopped','timedOut')}
    result['subject']={key:receipt.get(key) for key in ('headSHA','binarySHA256','packageSHA256','profileSHA256','helperSHA256','cliVersion','runID','epoch')}
    with (a.batch/'manifest.json').open('x') as f:json.dump(result,f,indent=2)
    print(json.dumps(results))
if __name__=='__main__':main()
