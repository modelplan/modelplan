# SPDX-License-Identifier: MIT
"""Evaluate scenario-specific supplied observations; never probe or activate the host."""
import argparse,json
from pathlib import Path

BASE_REQUIREMENTS=('running','disk','lease')
SCENARIO_REQUIREMENTS={
    'cockpit':BASE_REQUIREMENTS+('active','key','visible','WebKitPID'),
    'native-dock':BASE_REQUIREMENTS+('visible','onScreen','nonActivating'),
    'settings':BASE_REQUIREMENTS+('key','visible'),
}
# Compatibility for the existing helper tests/importers: the default scope is cockpit.
CONDITIONS=SCENARIO_REQUIREMENTS['cockpit']
ALIASES={'U11a':'cockpit','U5':'native-dock','U6':'native-dock','U8':'settings'}
OBSERVATION_ALIASES={'active':'appActive','key':'keyWindow','visible':'windowVisible',
                     'WebKitPID':'webContentPID','onScreen':'onScreenFrame','nonActivating':'nonActivatingPanel'}

def requirements_for(scenario):
    if not isinstance(scenario,str):raise ValueError('unknown Doctor scenario')
    scope=ALIASES.get(scenario,scenario)
    if scope not in SCENARIO_REQUIREMENTS:raise ValueError('unknown Doctor scenario')
    return scope,SCENARIO_REQUIREMENTS[scope]

def observed(observation,key):
    return observation.get(key,observation.get(OBSERVATION_ALIASES.get(key,'')))

def satisfied(observation,key):
    value=observed(observation,key)
    if key=='WebKitPID':
        return type(value) is int and value>0 and observation.get('WebKit',True) is True
    if key=='nonActivating':
        return value is True and observed(observation,'key') is not True
    return value is True

def doctor(observation,scenario=None):
    timestamp=observation.get('timestamp')
    if not isinstance(timestamp,str) or not timestamp:raise ValueError('native timestamp required')
    call=observation.get('activationCall')
    if not isinstance(call,str) or not call:raise ValueError('actual activation call or not-invoked required')
    scope,requirements=requirements_for(scenario or observation.get('scenario','cockpit'))
    checks={key:{'status':'pass' if satisfied(observation,key) else 'fail',
                 'required':True,'timestamp':timestamp} for key in requirements}
    # Keep non-required native observations visible without turning them into
    # a blanket gate (a Dock is intentionally non-key and has no WebKit view).
    extra={key:{'value':observed(observation,key) if type(observed(observation,key)) in (bool,int) else None,'required':False,'timestamp':timestamp}
           for key in dict.fromkeys(k for values in SCENARIO_REQUIREMENTS.values() for k in values)
           if key not in requirements}
    return {'scenario':scope,'requirements':list(requirements),'checks':checks,'observations':extra,
            'activationCall':call,'timestamp':timestamp,
            'outcome':'pass' if all(x['status']=='pass' for x in checks.values()) else 'not-run'}

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('input',type=Path);p.add_argument('--output',type=Path,required=True)
    p.add_argument('--scenario',choices=tuple(SCENARIO_REQUIREMENTS)+tuple(ALIASES))
    a=p.parse_args();result=doctor(json.loads(a.input.read_text()),a.scenario)
    with a.output.open('x') as f:json.dump(result,f,indent=2)
if __name__=='__main__':main()
