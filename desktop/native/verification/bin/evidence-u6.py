# SPDX-License-Identifier: MIT
"""U6-only receipt qualification; shared Evidence remains the manifest/hash owner."""
import argparse, importlib.util, json, uuid
from pathlib import Path
REQUIRED = ('appStarted', 'dockInputDelivered', 'dockRowsOrReasonVisible', 'menuInputDelivered', 'menuStateVisible', 'quitDelivered', 'ownedCleanupVerified', 'privateTitleObservedBeforeClear', 'trackedMenuClearObserved')
def cleanup_outcome(closure, run, epoch):
    if not isinstance(closure,dict): return 'not-run',['missing-closure-receipt']
    if closure.get('schema')!='launch-cleanup/1' or closure.get('runID')!=run or closure.get('epoch')!=epoch:
        return 'not-run',['invalid-closure-receipt']
    failures=closure.get('failures')
    if not isinstance(failures,list) or any(not isinstance(x,str) or not x for x in failures):
        return 'not-run',['invalid-closure-failures']
    if closure.get('ok') is not True or failures:return 'not-run',failures or ['closure-not-ok']
    return 'pass',[]
def native_outcomes(rows, run, epoch):
    """Only app rows for this run can prove Refresh and tracked-menu clear."""
    if not isinstance(rows, list) or not run or not epoch: return ('not-run', 'not-run', None)
    delivered = {}
    requested = {}
    terminals = {}
    private_instances = set()
    status_instances = {}
    clear = 'not-run'
    for index, row in enumerate(rows):
        if not isinstance(row, dict) or row.get('runID') != run or row.get('epoch') != epoch: continue
        checks = row.get('checks') if isinstance(row.get('checks'), dict) else {}
        event = row.get('event')
        if event == 'status-menu-action-arrived' and checks.get('actionID') == 'refresh':
            key = checks.get('requestID')
            if isinstance(key, str):
                try: uuid.UUID(key)
                except ValueError: continue
                if (checks.get('deliveryMethod') == 'axpress-menu-item'
                    and checks.get('menuInstanceID') in status_instances
                    and type(checks.get('subjectPID')) is int
                    and checks['subjectPID'] == status_instances[checks['menuInstanceID']]):
                    delivered[key] = index
        elif event == 'menu-begin':
            key = checks.get('instanceID')
            if isinstance(key, str) and key:
                if checks.get('surface') == 'status' and type(checks.get('subjectPID')) is int and checks['subjectPID'] > 0:
                    status_instances[key] = checks['subjectPID']
                if checks.get('privateContent') is True: private_instances.add(key)
            if clear == 'pass' and checks.get('privateContent') is True: clear = 'not-run'
        elif event == 'accepted-clear':
            scrubbed = checks.get('scrubbedInstanceIDs')
            if (private_instances and isinstance(scrubbed, list) and private_instances.issubset(scrubbed)
                and checks.get('priorPrivateContent') is True and checks.get('oldItemTitlesScrubbed') is True
                and checks.get('oldItemPrivateAttributesScrubbed') is True): clear = 'pass'
        elif row.get('kind') == 'refresh':
            key = row.get('requestId')
            if not isinstance(key, str) or key not in delivered or type(row.get('at')) not in (float, int): continue
            if row.get('phase') == 'requested' and index > delivered[key] and type(row.get('rowsSequenceBefore')) is int:
                requested[key] = (index, row['rowsSequenceBefore'])
            elif row.get('phase') in ('completed', 'failed') and key in requested and index > requested[key][0]:
                terminals.setdefault(key, []).append(row)
    outcome, reason = 'not-run', None
    if len(delivered) != 1 or len(requested) != 1:
        return outcome, clear, reason
    for key, terminal in terminals.items():
        if len(terminal) != 1: continue
        item = terminal[0]
        if item['phase'] == 'failed' and isinstance(item.get('reason'), str) and item['reason']:
            outcome, reason = 'fail', item['reason']; break
        if item['phase'] == 'completed' and type(item.get('rowsSequenceAfter')) is int and item['rowsSequenceAfter'] > requested[key][1]:
            outcome = 'pass'; break
    return outcome, clear, reason
def qualify(receipt, rows=None, closure=None):
    if receipt.get('profile') != 'synthetic': raise ValueError('synthetic profile required')
    if receipt.get('timedOut') is True: return 'timeout'
    for key, size in [('headSHA',40),('binarySHA256',64),('packageSHA256',64),('profileSHA256',64)]:
        pin = receipt.get(key)
        if not isinstance(pin,str) or len(pin)!=size or any(c not in '0123456789abcdef' for c in pin): return 'not-run'
    if receipt.get('inputCapability') == 'unsupported': return 'unsupported'
    if receipt.get('stopped') is True: return 'not-run'
    cleanup, _ = cleanup_outcome(closure,receipt.get('runID'),receipt.get('epoch'))
    if cleanup != 'pass': return 'not-run'
    refresh, clear, _ = native_outcomes(rows, receipt.get('runID'), receipt.get('epoch'))
    if refresh == 'fail': return 'fail'
    if refresh != 'pass' or clear != 'pass': return 'not-run'
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
    native = args.batch/'native-observations.jsonl'
    try: rows = [json.loads(line) for line in native.read_text().splitlines() if line.strip()]
    except (OSError, ValueError): rows = []
    closure_path=args.batch/'launch-cleanup.json'
    try: closure=json.loads(closure_path.read_text())
    except (OSError,ValueError): closure=None
    outcome = qualify(receipt, rows, closure)
    refresh, tracked, refresh_reason = native_outcomes(rows, receipt.get('runID'), receipt.get('epoch'))
    cleanup,cleanup_failures=cleanup_outcome(closure,receipt.get('runID'),receipt.get('epoch'))
    spec = importlib.util.spec_from_file_location('shared_evidence',Path(__file__).with_name('evidence.py'))
    shared = importlib.util.module_from_spec(spec); spec.loader.exec_module(shared)
    config = dict(headSHA=receipt['headSHA'],profile='synthetic',attributionMethod='owned-native-surface-and-delivered-input',scenarios=[dict(id='U6-DockMenu-synthetic',outcome=outcome,refreshCompleted=refresh,trackedClear=tracked,refreshFailureReason=refresh_reason,cleanup=cleanup,cleanupFailures=cleanup_failures)],files=receipt.get('actionEvidenceFiles',[]))
    result = shared.manifest(config,args.batch)
    result['subject'] = {key:receipt.get(key) for key in ('headSHA','binarySHA256','packageSHA256','profileSHA256')}
    with (args.batch/'manifest.json').open('x') as stream: json.dump(result,stream,indent=2)
    print(json.dumps(dict(scenario='U6-DockMenu-synthetic',outcome=outcome,refreshCompleted=refresh,trackedClear=tracked,refreshFailureReason=refresh_reason,cleanup=cleanup,cleanupFailures=cleanup_failures)))
if __name__ == '__main__': main()
