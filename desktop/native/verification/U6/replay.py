# SPDX-License-Identifier: MIT
"""Offline C2.4/C2.6 replay oracle for one U6 batch: receipts in, per-step outcomes out.

Pure: no GUI, process, clock or network access, and no writes. It is an independent specification of
`U6-DockMenu-Drive.md` sections "Contract revision C2.6" and "Evidence and timing contract (C2.4)" and deliberately does not import or
share code with `bin/evidence-u6.py`; the tests compare the two. Shapes come from `schema/verification/`
(via `receipt_schema`), the closure receipt's meaning from `check_launch_cleanup.validate_receipt`.

    replay(context, files) -> {'schema': 'u6-replay/1', 'outcome': ..., 'steps': [...]}

`context` is a `u6-replay-context/1` object (registered subject, lease window, seed title hash, synthetic
HOME hash, manifest and launched pins). `files` maps batch file names to their bytes (absent = missing).
Each step reports `outcome` (pass | fail | not-run), a C2.4 section 5 scenario `reason` (null on pass) and
a `detail` code from DETAILS naming the assertion that decided it.

CLI: replay.py --context <context.json> --batch <dir>   (prints the result; exit 0 pass, 1 otherwise)."""
import argparse
import hashlib
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent / 'bin'))
import receipt_schema  # noqa: E402
import check_launch_cleanup  # noqa: E402

SCHEMA = 'u6-replay/1'
PROTOCOL = 'u6-native/1'
NAMES = ('dock-reveal', 'menu-a', 'refresh', 'menu-b', 'private-title', 'tracked-clear', 'hand-off', 'quit',
         'closure', 'evidence')
FILES = dict(native='native-observations.jsonl', dock='dock-pointer.jsonl', status='status-pointer.jsonl',
             clear='status-pointer-clear.jsonl', capture='dock-capture.json', reset='consent-reset.json',
             finish='operator-finish.json', closure='launch-cleanup.json', runtime='runtime-calls.jsonl', result='result.json')
DOCK_SECONDS, CLICK_SECONDS, REFRESH_SECONDS, CLEAR_SECONDS = 5, 3, 60, 5
SCRUB_SECONDS = 5  # C2.6 E: accepted-clear and menu-scrubbed within 5 s of clear-initiated
COPILOT = 'copilot.runtime_usage'
DEFERRED_REASONS = {'cooldown': 'cooldown', 'read_only': 'engine-disabled', 'offline': 'engine-disabled',
                    'policy_pending': 'consent-required'}  # C2.6 D

# detail -> scenario reason (C2.4 section 5). Fixed list: nothing else is ever reported.
DETAILS = {
    'ok': None,
    'prerequisite-not-met': 'not-delivered',
    'native-missing': 'not-delivered', 'native-truncated': 'unknown', 'native-row-malformed': 'unknown',
    'native-order-contradiction': 'unknown', 'started-missing': 'not-delivered',
    'protocol-unsupported': 'unknown', 'native-unusable': 'unknown', 'pin-changed': 'unknown',
    'pointer-unreadable': 'unknown',
    'dock-move-missing': 'not-delivered', 'dock-frame-missing': 'not-delivered',
    'dock-frame-out-of-window': 'out-of-window', 'capture-missing': 'not-delivered',
    'capture-unbound': 'wrong-subject', 'capture-hash-mismatch': 'unknown',
    'click-missing': 'not-delivered', 'menu-begin-missing': 'not-delivered',
    'menu-begin-out-of-window': 'out-of-window',
    'arrival-missing': 'not-delivered', 'arrival-duplicate': 'unknown', 'arrival-after-menu-end': 'unknown',
    'requested-missing': 'not-delivered', 'requested-duplicate': 'unknown',
    'requested-out-of-order': 'unknown', 'requested-wrong-session': 'wrong-subject',
    'terminal-missing': 'timeout', 'terminal-late': 'timeout', 'terminal-duplicate': 'unknown',
    'terminal-out-of-order': 'unknown', 'terminal-wrong-session': 'wrong-subject',
    'refresh-failed': None,  # failed carries the row's own bounded reason
    'refresh-deferred': None,  # C2.6 D: the reason follows the Copilot disposition (DEFERRED_REASONS)
    'refresh-abandoned-deadline': 'timeout', 'refresh-abandoned-stop': 'not-delivered',
    'accepted-missing': 'not-delivered', 'accepted-stale': 'not-delivered', 'accepted-duplicate': 'unknown',
    'deferred-but-scheduled': 'unknown', 'copilot-not-scheduled': 'unknown', 'copilot-accounts-before': 'unknown',
    'projection-not-qualifying': 'unknown', 'runtime-calls-missing': 'not-delivered',
    'runtime-calls-malformed': 'unknown', 'runtime-calls-undigested': 'not-delivered',
    'runtime-calls-foreign': 'wrong-subject', 'call-before-accepted': 'unknown', 'quota-call-missing': 'unknown',
    'menu-a-not-ended': 'not-delivered', 'click-b-before-a-ended': 'out-of-window',
    'session-reused': 'wrong-subject',
    'title-missing': 'not-delivered', 'title-hash-mismatch': 'wrong-subject', 'title-wrong-menu': 'wrong-subject',
    'reset-missing': 'not-delivered', 'reset-malformed': 'unknown', 'reset-other-run': 'wrong-subject',
    'reset-unbound': 'wrong-subject', 'reset-failed': 'unknown',
    'clear-initiated-missing': 'not-delivered', 'clear-initiated-out-of-window': 'out-of-window',
    'pair-mismatch': 'wrong-subject', 'menu-b-not-open-at-clear': 'wrong-subject',
    'menu-b-ended-before-clear': 'unknown', 'menu-end-cause-mismatch': 'unknown',
    'accepted-clear-missing': 'not-delivered', 'accepted-clear-duplicate': 'unknown', 'clear-late': 'timeout',
    'session-not-scrubbed': 'wrong-subject', 'menu-scrubbed-missing': 'not-delivered',
    'menu-scrubbed-duplicate': 'unknown', 'menu-scrubbed-wrong-menu': 'wrong-subject',
    'private-item-unreported': 'unknown', 'private-item-retained': 'unknown',
    'private-content-present': 'unknown', 'title-after-clear': 'unknown',
    'finish-missing': 'not-delivered', 'finish-malformed': 'unknown', 'finish-other-run': 'wrong-subject',
    'finish-before-receipts': 'out-of-window', 'finish-after-stop': 'out-of-window',
    'runner-reported-fail': None, 'runner-reported-not-run': None,  # the runner's own bounded reason (NOT-RUN, C2.6 F)
    'stop-missing': 'not-delivered', 'owner-preempted': 'unknown', 'terminate-missing': 'not-delivered',
    'subject-not-gone': 'not-delivered',
    'closure-missing': 'not-delivered', 'closure-malformed': 'unknown', 'closure-inconsistent': 'unknown',
    'closure-other-run': 'wrong-subject',
    'closure-not-ok': 'unknown', 'lease-window-mismatch': 'wrong-subject', 'closure-late': 'out-of-window',
}
# validate_receipt codes for a well-formed receipt that contradicts itself (C2.4 step 10: "contradiction → FAIL");
# every other code is a shape problem (unusable receipt, NOT-RUN).
CLOSURE_CONTRADICTIONS = frozenset(('closure-failures-inconsistent', 'closure-ok-inconsistent',
                                    'closure-time-inconsistent', 'closure-window-inconsistent'))
SCENARIO_REASONS = frozenset(receipt_schema.registry().documents[
    receipt_schema.registry().id_for('common.json')]['$defs']['scenarioReason']['enum'])


def _step(outcome, detail, reason=None):
    if detail not in DETAILS:
        raise AssertionError('undeclared detail ' + detail)
    reason = reason if DETAILS[detail] is None and outcome != 'pass' else DETAILS[detail]
    if outcome != 'pass' and reason not in SCENARIO_REASONS:
        reason = 'unknown'
    return dict(outcome=outcome, reason=None if outcome == 'pass' else reason, detail=detail)


PASS = lambda: _step('pass', 'ok')  # noqa: E731
NOT_RUN = lambda detail, reason=None: _step('not-run', detail, reason)  # noqa: E731
FAIL = lambda detail, reason=None: _step('fail', detail, reason)  # noqa: E731


def _jsonl(data):
    """(rows, problem): every line must be one JSON object; a final line without newline is truncation."""
    if data is None:
        return None, 'missing'
    text = data.decode('utf-8', 'replace') if isinstance(data, bytes) else data
    if text and not text.endswith('\n'):
        return None, 'truncated'
    rows = []
    for line in text.splitlines():
        if not line.strip():
            continue
        try:
            row = json.loads(line)
        except ValueError:
            return None, 'malformed'
        if not isinstance(row, dict):
            return None, 'malformed'
        rows.append(row)
    return rows, None


def _json(data):
    if data is None:
        return None, 'missing'
    try:
        value = json.loads(data.decode('utf-8') if isinstance(data, bytes) else data)
    except (ValueError, UnicodeDecodeError):
        return None, 'malformed'
    return value, None


class Native:
    """The registered subject's rows (run, epoch and PID bound), checked for shape and order."""

    def __init__(self, context, data):
        self.rows, self.problem = [], None
        rows, problem = _jsonl(data)
        if problem:
            self.problem = {'missing': 'native-missing', 'truncated': 'native-truncated'}.get(problem, 'native-row-malformed')
            return
        bound = (context['runID'], context['epoch'], context['subjectPID'])
        own = [r for r in rows if (r.get('runID'), r.get('epoch'), r.get('pid')) == bound]  # others are ignored
        for row in own:
            if receipt_schema.native_errors(row):
                self.problem = 'native-row-malformed'
                return
        own = [receipt_schema.flat_native(r) for r in own]
        for row in own:  # the App writes no protocol today, which is u6-native/1 (C2.6 F)
            if row['kind'] == 'started' and row.get('protocol', PROTOCOL) != PROTOCOL:
                self.problem = 'protocol-unsupported'
                return
        for before, after in zip(own, own[1:]):
            if after['seq'] <= before['seq'] or after['mono'] < before['mono']:
                self.problem = 'native-order-contradiction'
                return
        if not own or own[0]['kind'] != 'started':
            self.problem = 'started-missing'
            return
        known = receipt_schema.native_kinds()
        self.rows = [r for r in own if r['kind'] in known]

    def of(self, kind, **match):
        return [r for r in self.rows if r['kind'] == kind and all(r.get(k) == v for k, v in match.items())]


def _pointer(context, data):
    """Bound, schema-valid pointer rows (another run/epoch/PID never satisfies a step) or None if unreadable."""
    rows, problem = _jsonl(data)
    if problem == 'missing':
        return []
    if problem:
        return None
    registry = receipt_schema.registry()
    bound = (context['runID'], context['epoch'], context['subjectPID'])
    # pointer_drive names the row in `event` (its `kind` is move/click); decode to the row name.
    return [dict({k: v for k, v in r.items() if k != 'event'}, kind=r['event']) for r in rows
            if (r.get('runID'), r.get('epoch'), r.get('targetPID')) == bound and registry.valid(r, 'pointer-receipt.json')]


def _click(rows):
    """The first posted (down, up) pair of one plan step, in file order."""
    for index, down in enumerate(rows):
        if down['kind'] != 'mouse-button-down-posted':
            continue
        for up in rows[index + 1:]:
            if up['kind'] == 'mouse-button-up-posted' and up['step'] == down['step'] and up['mono'] >= down['mono']:
                return down, up
    return None


def _menu_begin(native, down, up, after_seq=0):
    """First status menu-begin with mono in [down, up + 3 s] (explicit C2.4 click interval)."""
    begins = [r for r in native.of('menu-begin', surface='status') if r['seq'] > after_seq]
    inside = [r for r in begins if down['mono'] <= r['mono'] <= up['mono'] + CLICK_SECONDS]
    if inside:
        return inside[0], None
    return None, 'menu-begin-out-of-window' if begins else 'menu-begin-missing'


def step1(context, native, files):
    rows = _pointer(context, files.get(FILES['dock']))
    if rows is None:
        return NOT_RUN('pointer-unreadable'), None
    moves = [r for r in rows if r['kind'] == 'mouse-moved-posted']
    if not moves:
        return NOT_RUN('dock-move-missing'), None
    frames = native.of('dock-surface-frame', state='expanded')
    candidates = [f for f in frames if any(0 <= f['mono'] - m['mono'] <= DOCK_SECONDS for m in moves)]
    if not candidates:
        return NOT_RUN('dock-frame-out-of-window' if frames else 'dock-frame-missing'), None
    capture, problem = _json(files.get(FILES['capture']))
    if problem or not receipt_schema.registry().valid(capture, 'capture-receipt.json'):
        return NOT_RUN('capture-missing' if problem == 'missing' else 'capture-unbound'), None
    if (capture['runID'], capture['epoch'], capture['pid']) != (context['runID'], context['epoch'], context['subjectPID']):
        return NOT_RUN('capture-unbound'), None
    frame = next((f for f in candidates if f['seq'] == capture['frameSeq']
                  and f['windowNumber'] == capture['windowNumber'] and capture['mono'] >= f['mono']), None)
    if frame is None:
        return NOT_RUN('capture-unbound'), None
    image = files.get(capture['file'])
    if image is None:
        return NOT_RUN('capture-missing'), None
    if hashlib.sha256(image).hexdigest() != capture['sha256']:
        return FAIL('capture-hash-mismatch'), None
    return PASS(), max(frame['mono'], capture['mono'])


def step2(context, native, files):
    rows = _pointer(context, files.get(FILES['status']))
    if rows is None:
        return NOT_RUN('pointer-unreadable'), None
    pair = _click(rows)
    if pair is None:
        return NOT_RUN('click-missing'), None
    begin, problem = _menu_begin(native, *pair)
    return (NOT_RUN(problem), None) if begin is None else (PASS(), begin)


def _runtime_calls(context, files):
    """(calls, None) from Drive's copy of the stub log, or (None, detail): the copy must match the digest Drive
    recorded in result.json, every line must be schema-valid and bound to this run (C2.6 D)."""
    data = files.get(FILES['runtime'])
    rows, problem = _jsonl(data)
    if problem == 'missing':
        return None, 'runtime-calls-missing'
    result, _ = _json(files.get(FILES['result']))
    digest = result.get('runtimeCallsSHA256') if isinstance(result, dict) else None
    if digest != hashlib.sha256(data).hexdigest():
        return None, 'runtime-calls-undigested'
    registry = receipt_schema.registry()
    if problem or not all(registry.valid(r, 'runtime-calls.json') for r in rows):
        return None, 'runtime-calls-malformed'
    if any((r['runID'], r['epoch']) != (context['runID'], context['epoch']) for r in rows):
        return None, 'runtime-calls-foreign'
    return rows, None


def step3(context, native, files, a):
    """C2.6 D: requested, accepted (the call's own reply), one terminal; the qualifying stub call between them."""
    end = next(iter(native.of('menu-end', sessionID=a['sessionID'])), None)
    arrivals = [r for r in native.of('status-menu-action-arrived', sessionID=a['sessionID'], actionID='refresh',
                                     menuObjectID=a['menuObjectID']) if r['seq'] > a['seq']]
    if not arrivals:
        return NOT_RUN('arrival-missing'), None, end
    if len(arrivals) > 1:
        return FAIL('arrival-duplicate'), None, end
    arrival = arrivals[0]
    if end is not None and end['seq'] < arrival['seq']:
        return FAIL('arrival-after-menu-end'), None, end
    request = arrival['requestID']
    rows = native.of('refresh', requestId=request)
    requested = [r for r in rows if r['phase'] == 'requested']
    accepted = [r for r in rows if r['phase'] == 'accepted']
    terminals = [r for r in rows if r['phase'] not in ('requested', 'accepted')]
    if not requested:
        return NOT_RUN('requested-missing'), None, end
    if len(requested) > 1:
        return FAIL('requested-duplicate'), None, end
    requested = requested[0]
    if requested['seq'] < arrival['seq']:
        return FAIL('requested-out-of-order'), None, end
    if (requested['sessionID'], requested['menuObjectID']) != (a['sessionID'], a['menuObjectID']):
        return FAIL('requested-wrong-session'), None, end
    if requested['copilotAccountsBefore'] != 0:  # the seed was not a first attempt
        return FAIL('copilot-accounts-before'), None, end
    if len(accepted) > 1:
        return FAIL('accepted-duplicate'), None, end
    if len(terminals) > 1:  # anywhere in the subject log, even outside the window
        return FAIL('terminal-duplicate'), None, end
    if not terminals:
        return NOT_RUN('terminal-missing'), None, end
    terminal = terminals[0]
    if terminal['seq'] < requested['seq']:
        return FAIL('terminal-out-of-order'), None, end
    if (terminal['sessionID'], terminal['menuObjectID']) != (a['sessionID'], a['menuObjectID']):
        return FAIL('terminal-wrong-session'), None, end
    if not 0 <= terminal['mono'] - requested['mono'] <= REFRESH_SECONDS:
        return NOT_RUN('terminal-late'), None, end
    phase = terminal['phase']
    if phase == 'failed':  # only from a production refresh error, which may precede any reply
        return FAIL('refresh-failed', terminal['reason']), None, end
    if phase == 'abandoned':  # the App's watchdog, never failed
        return NOT_RUN('refresh-abandoned-' + terminal['cause']), None, end
    accepted = accepted[0] if accepted else None
    if accepted is None or not requested['seq'] < accepted['seq'] < terminal['seq']:
        return NOT_RUN('accepted-missing'), None, end  # a terminal without a matching accepted
    if (accepted['sessionID'], accepted['menuObjectID']) != (a['sessionID'], a['menuObjectID']) or any(
            r['engineRequestID'] == accepted['engineRequestID'] and r['requestId'] != request
            for r in native.of('refresh', phase='accepted')):
        return NOT_RUN('accepted-stale'), None, end  # another call's reply, not this call's
    disposition = accepted['dispositions'][COPILOT]
    if phase == 'deferred':
        if disposition == 'scheduled':
            return FAIL('deferred-but-scheduled'), None, end
        return NOT_RUN('refresh-deferred', DEFERRED_REASONS[disposition]), None, end
    if disposition != 'scheduled':  # completed although the call's reply did not schedule Copilot
        return FAIL('copilot-not-scheduled'), None, end
    if (terminal['copilotAccountsAfter'] < 1 or terminal['accountIDSHA256'] != context['seedAccountIDSHA256']
            or terminal['rowsSequenceAfter'] <= requested['rowsSequenceBefore']):
        return FAIL('projection-not-qualifying'), None, end
    calls, problem = _runtime_calls(context, files)
    if problem:
        return NOT_RUN(problem), None, end
    if any(c['mono'] < accepted['mono'] for c in calls):
        return FAIL('call-before-accepted'), None, end
    if not any(c['method'] == 'account.getQuota' and accepted['mono'] < c['mono'] < terminal['mono'] for c in calls):
        return FAIL('quota-call-missing'), None, end
    return PASS(), terminal['mono'], end


def step4(context, native, files, a, end_a):
    if end_a is None:
        return NOT_RUN('menu-a-not-ended'), None
    rows = _pointer(context, files.get(FILES['clear']))
    if rows is None:
        return NOT_RUN('pointer-unreadable'), None
    pair = _click(rows)
    if pair is None:
        return NOT_RUN('click-missing'), None
    if not pair[0]['mono'] > end_a['mono']:
        return NOT_RUN('click-b-before-a-ended'), None
    begin, problem = _menu_begin(native, *pair, after_seq=end_a['seq'])
    if begin is None:
        return NOT_RUN(problem), None
    if begin['sessionID'] == a['sessionID']:
        return NOT_RUN('session-reused'), None
    return PASS(), begin


def step5(context, native, b):
    rows = [r for r in native.of('menu-private-title-visible', sessionID=b['sessionID']) if r['seq'] > b['seq']]
    if not rows:
        return NOT_RUN('title-missing'), None
    title = next((r for r in rows if r['titleSHA256'] == context['seedTitleSHA256']), None)
    if title is None:
        return NOT_RUN('title-hash-mismatch'), None
    if title['menuObjectID'] != b['menuObjectID']:
        return NOT_RUN('title-wrong-menu'), None
    return PASS(), title


def _reset(context, files):
    """(wrapper receipt, None) or (None, detail)."""
    value, problem = _json(files.get(FILES['reset']))
    if problem == 'missing':
        return None, 'reset-missing'
    if problem or not receipt_schema.registry().valid(value, 'consent-reset.json'):
        return None, 'reset-malformed'
    if (value['runID'], value['epoch']) != (context['runID'], context['epoch']):
        return None, 'reset-other-run'
    if value['homeSHA256'] != context['homeSHA256'] or value['helperSHA256'] != context['pins']['consentHelper']:
        return None, 'reset-unbound'
    if value['exitCode'] != 0:
        return None, 'reset-failed'
    return value, None


def step6(context, native, files, b, title):
    """Explicit FAIL predicates first (they dominate), then the receipts whose absence is NOT-RUN."""
    session, pair = b['sessionID'], lambda r: (r['storeEpochAfter'], r['generationAfter'])
    ends = native.of('menu-end', sessionID=session)
    initiated = [r for r in native.of('clear-initiated') if r['seq'] > title['seq']]
    clear = initiated[0] if initiated else None
    if clear is None:
        return NOT_RUN('clear-initiated-missing'), None
    if any(e['seq'] < clear['seq'] for e in ends):
        return FAIL('menu-b-ended-before-clear'), None
    if any(e['cause'] != 'clear' or e.get('clearID') != clear['clearID'] for e in ends):
        return FAIL('menu-end-cause-mismatch'), None
    accepted = [r for r in native.of('accepted-clear', clearID=clear['clearID']) if r['seq'] > clear['seq']]
    if len(accepted) > 1:
        return FAIL('accepted-clear-duplicate'), None
    accepted = accepted[0] if accepted else None
    scrubbed = [r for r in native.of('menu-scrubbed', clearID=clear['clearID'], sessionID=session)
                if r['seq'] > clear['seq']]
    if len(scrubbed) > 1:
        return FAIL('menu-scrubbed-duplicate'), None
    scrubbed = scrubbed[0] if scrubbed else None
    if scrubbed is not None:
        states = {}
        for item in scrubbed['itemStates']:
            if item['id'] in states:
                return FAIL('private-item-unreported'), None  # an ambiguous report is no report
            states[item['id']] = item['state']
        if any(i not in states for i in title['privateItemIDs']):
            return FAIL('private-item-unreported'), None
        if any(states[i] not in ('deallocated', 'cleared') for i in title['privateItemIDs']):
            return FAIL('private-item-retained'), None
        if scrubbed['privateTitlePresent'] or scrubbed['privateAttributeCount']:
            return FAIL('private-content-present'), None
    if accepted is not None:
        later = {r['sessionID'] for r in native.of('menu-begin') if r['seq'] >= b['seq']}
        if any(r['titleSHA256'] == context['seedTitleSHA256'] and r['sessionID'] in later and r['seq'] > accepted['seq']
               for r in native.of('menu-private-title-visible')):
            return FAIL('title-after-clear'), None
    if any(r is not None and r['mono'] - clear['mono'] > SCRUB_SECONDS for r in (accepted, scrubbed)):
        return FAIL('clear-late'), None  # C2.6 E: private content stayed up after the reset
    reset, problem = _reset(context, files)
    if problem:
        return NOT_RUN(problem), None
    if not reset['startMono'] <= clear['mono'] <= reset['endMono'] + CLEAR_SECONDS:
        return NOT_RUN('clear-initiated-out-of-window'), None
    if pair(clear) != pair(reset):
        return NOT_RUN('pair-mismatch'), None
    if session not in clear['openSessionIDs']:
        return NOT_RUN('menu-b-not-open-at-clear'), None
    if accepted is None:
        return NOT_RUN('accepted-clear-missing'), None
    if pair(accepted) != pair(reset):
        return NOT_RUN('pair-mismatch'), None
    if session not in accepted['scrubbedSessionIDs']:
        return NOT_RUN('session-not-scrubbed'), None
    if scrubbed is None:
        return NOT_RUN('menu-scrubbed-missing'), None
    if scrubbed['menuObjectID'] != b['menuObjectID']:
        return NOT_RUN('menu-scrubbed-wrong-menu'), None
    return PASS(), max(accepted['mono'], scrubbed['mono'])


def step7(context, files, receipts_mono, stop):
    value, problem = _json(files.get(FILES['finish']))
    if problem == 'missing':
        return NOT_RUN('finish-missing')
    if problem or not receipt_schema.registry().valid(value, 'u6-actions.json'):
        return NOT_RUN('finish-malformed')
    if (value['runID'], value['epoch']) != (context['runID'], context['epoch']):
        return NOT_RUN('finish-other-run')
    claims = list(value['steps'].values()) + [value['outcome']]  # the runner's own claims, never proof
    if 'fail' in claims:  # C2.6 F: a runner outcome is NOT-RUN with its bounded reason
        return NOT_RUN('runner-reported-fail', value['reason'])
    if 'not-run' in claims:
        return NOT_RUN('runner-reported-not-run', value['reason'])
    if receipts_mono is not None and value['mono'] < receipts_mono:
        return NOT_RUN('finish-before-receipts')
    if stop is not None and value['mono'] > stop['mono']:
        return NOT_RUN('finish-after-stop')
    return PASS()


def _closure(context, files):
    """(receipt, step 9 result)."""
    value, problem = _json(files.get(FILES['closure']))
    if problem == 'missing':
        return None, NOT_RUN('closure-missing')
    try:
        if problem or not receipt_schema.registry().valid(value, 'launch-cleanup.json'):
            raise ValueError('closure-shape')
        check_launch_cleanup.validate_receipt(value)
    except ValueError as error:
        if str(error) in CLOSURE_CONTRADICTIONS:  # well-formed, so its run binding is readable
            if (value['runID'], value['epoch']) != (context['runID'], context['epoch']):
                return None, NOT_RUN('closure-other-run')  # another run's receipt is ignored (section 1)
            return None, FAIL('closure-inconsistent')
        return None, NOT_RUN('closure-malformed')
    if (value['runID'], value['epoch']) != (context['runID'], context['epoch']):
        return None, NOT_RUN('closure-other-run')
    if value['ok'] is not True:
        return value, NOT_RUN('closure-not-ok')
    if (value['leaseNotBefore'], value['leaseExpiresAt']) != (context['leaseNotBefore'], context['leaseExpiresAt']):
        return None, NOT_RUN('lease-window-mismatch')  # another lease's receipt is ignored (C2.6 F)
    if not check_launch_cleanup.lease_window_ok(value):
        return value, FAIL('closure-late')
    return value, PASS()


def step8(native, closure):
    stops = native.of('stop-or-lease-expired')
    if not stops:
        return NOT_RUN('owner-preempted' if native.of('owner-preempted') else 'stop-missing'), None
    stop = stops[0]
    if not any(r['seq'] > stop['seq'] for r in native.of('terminate-completed')):
        return NOT_RUN('terminate-missing'), stop
    if closure is None or closure['checks']['subjectGone'] is not True:
        return NOT_RUN('subject-not-gone'), stop
    return PASS(), stop


def replay(context, files):
    if not receipt_schema.registry().valid(context, 'replay-context.json'):
        raise ValueError('replay-context-invalid')
    files = {k: (v.encode() if isinstance(v, str) else v) for k, v in files.items() if v is not None}
    native = Native(context, files.get(FILES['native']))
    steps = {}
    closure, steps[9] = _closure(context, files)
    if native.problem:
        unusable = NOT_RUN('native-unusable')
        for n in (1, 2, 3, 4, 5, 6, 8):
            steps[n] = unusable
        steps[7] = step7(context, files, None, None)
        fail = native.problem in ('native-order-contradiction',)
        steps[10] = (FAIL if fail else NOT_RUN)(native.problem)
    else:
        later = []  # mono of the step 1-6 receipts, for the hand-off ordering
        steps[1], mono = step1(context, native, files); later.append(mono)
        steps[2], a = step2(context, native, files)
        steps[3] = steps[4] = steps[5] = steps[6] = NOT_RUN('prerequisite-not-met')
        if a is not None:
            later.append(a['mono'])
            steps[3], mono, end_a = step3(context, native, files, a); later.append(mono)
            steps[4], b = step4(context, native, files, a, end_a)
            if b is not None:
                later.append(b['mono'])
                steps[5], title = step5(context, native, b)
                if title is not None:
                    later.append(title['mono'])
                    steps[6], mono = step6(context, native, files, b, title); later.append(mono)
        steps[8], stop = step8(native, closure)
        later = [m for m in later if m is not None]
        steps[7] = step7(context, files, max(later) if later else None, stop)
        steps[10] = FAIL('pin-changed') if context['pins'] != context['launchedPins'] else PASS()
    ordered = [dict(step=n, name=NAMES[n - 1], **steps[n]) for n in range(1, 11)]
    outcomes = {s['outcome'] for s in ordered}
    outcome = 'fail' if 'fail' in outcomes else 'not-run' if 'not-run' in outcomes else 'pass'
    return dict(schema=SCHEMA, outcome=outcome, steps=ordered)


def read_batch(batch):
    """{file name: bytes} for the regular files directly in `batch` (symlinks are not evidence)."""
    batch = Path(batch)
    return {p.name: p.read_bytes() for p in sorted(batch.iterdir()) if p.is_file() and not p.is_symlink()}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--context', type=Path, required=True)
    parser.add_argument('--batch', type=Path, required=True)
    args = parser.parse_args(argv)
    result = replay(json.loads(args.context.read_text()), read_batch(args.batch))
    print(json.dumps(result, sort_keys=True))
    return 0 if result['outcome'] == 'pass' else 1


if __name__ == '__main__':
    sys.exit(main())
