# SPDX-License-Identifier: MIT
"""U6-only receipt qualification; shared Evidence remains the manifest/hash owner."""
import argparse, importlib.util, json
from pathlib import Path
REQUIRED = ('appStarted', 'dockInputDelivered', 'dockRowsOrReasonVisible', 'menuInputDelivered', 'menuStateVisible', 'quitDelivered', 'ownedCleanupVerified', 'privateTitleObservedBeforeClear', 'trackedMenuClearObserved')
def qualify(receipt):
    if receipt.get('profile') != 'synthetic': raise ValueError('synthetic profile required')
    if receipt.get('timedOut') is True: return 'timeout'
    for key, size in [('headSHA',40),('binarySHA256',64),('packageSHA256',64),('profileSHA256',64)]:
        pin = receipt.get(key)
        if not isinstance(pin,str) or len(pin)!=size or any(c not in '0123456789abcdef' for c in pin): return 'not-run'
    if receipt.get('inputCapability') == 'unsupported': return 'unsupported'
    if receipt.get('stopped') is True: return 'not-run'
    duration = receipt.get('durationSeconds')
    if type(duration) not in (int,float) or not 0 < duration <= 1200: return 'not-run'
    if any(receipt.get(key) is not True for key in REQUIRED): return 'not-run'
    refs = receipt.get('actionEvidenceFiles')
    if not isinstance(refs,list) or len(refs) < 2 or any(not isinstance(x,str) or not x for x in refs): return 'not-run'
    return 'pass'
def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--receipts',type=Path,required=True); parser.add_argument('--batch',type=Path,required=True)
    args = parser.parse_args(); receipt = json.loads(args.receipts.read_text())
    outcome = qualify(receipt)
    spec = importlib.util.spec_from_file_location('shared_evidence',Path(__file__).with_name('evidence.py'))
    shared = importlib.util.module_from_spec(spec); spec.loader.exec_module(shared)
    config = dict(headSHA=receipt['headSHA'],profile='synthetic',attributionMethod='owned-native-surface-and-delivered-input',scenarios=[dict(id='U6-DockMenu-synthetic',outcome=outcome)],files=receipt.get('actionEvidenceFiles',[]))
    result = shared.manifest(config,args.batch)
    result['subject'] = {key:receipt.get(key) for key in ('headSHA','binarySHA256','packageSHA256','profileSHA256')}
    with (args.batch/'manifest.json').open('x') as stream: json.dump(result,stream,indent=2)
    print(json.dumps(dict(scenario='U6-DockMenu-synthetic',outcome=outcome)))
if __name__ == '__main__': main()
