# SPDX-License-Identifier: MIT
"""U6 receipt contract (C2.4 as amended by C2.6): shape (schemas), meaning (replay oracle) and invocation (real CLIs).

Batches are written in the producers' current encoding (C2.6 F; schema/verification/fixtures/provenance.json says
which files are producer captures); every negative trace states its expected outcome independently of the oracle."""
import copy
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

VERIFICATION = Path(__file__).resolve().parents[1]
REPO = VERIFICATION.parents[2]
SCHEMAS = REPO / 'schema' / 'verification'
FIXTURES = SCHEMAS / 'fixtures'
sys.path.insert(0, str(VERIFICATION / 'U6'))
sys.path.insert(0, str(VERIFICATION / 'bin'))
import check_launch_cleanup as clc  # noqa: E402
import receipt_schema  # noqa: E402
import replay  # noqa: E402
import synthetic_batch as sb  # noqa: E402

REG = receipt_schema.registry()
ENVELOPE = ('runID', 'epoch', 'pid', 'seq', 'mono', 'at')
FILE_SCHEMAS = {'dock-capture.json': 'capture-receipt.json', 'consent-reset.json': 'consent-reset.json',
                'operator-finish.json': 'u6-actions.json', 'launch-cleanup.json': 'launch-cleanup.json',
                'context.json': 'replay-context.json'}
LINE_SCHEMAS = {'runtime-calls.jsonl': 'runtime-calls.json'}  # per-line receipts besides native and pointer rows
COMPLETED_ONLY = ('rowsSequenceAfter', 'copilotAccountsAfter', 'readingSHA256')
# Fixed reading-digest vector for the Swift side (README, Reading digest): two windows out of id order, a
# fractional percent, an ISO and a null reset.
READING_VECTOR = ({'route': 'runtime', 'plan': {'id': 'copilot-pro'}, 'windows': [
    {'id': 'premium_interactions', 'limitKey': 'premium_interactions', 'poolKey': 'copilot', 'remainingPercent': 62.5,
     'resetsAt': '2099-01-01T00:00:00Z'},
    {'id': 'chat', 'limitKey': 'chat', 'poolKey': 'copilot', 'remainingPercent': None, 'resetsAt': None}]},
    '{"plan":"copilot-pro","route":"runtime","windows":[{"id":"chat","limitKey":"chat","poolKey":"copilot",'
    '"remainingBp":null,"resetsAt":null},{"id":"premium_interactions","limitKey":"premium_interactions",'
    '"poolKey":"copilot","remainingBp":6250,"resetsAt":4070908800}]}')
POINTER_FILES = ('dock-pointer.jsonl', 'status-pointer.jsonl', 'status-pointer-clear.jsonl')
CLOSURE = sb.closure()  # one real launch-cleanup/1 receipt shared by the traces that do not vary it


def rows_of(data):
    return [json.loads(line) for line in data.decode().splitlines() if line.strip()]


def walk(node, where='$'):
    """Every schema object node (for static keyword checks)."""
    if isinstance(node, dict):
        yield where, node
        for key, value in node.items():
            if key in ('properties', '$defs'):
                for name, sub in value.items():
                    yield from walk(sub, '%s.%s.%s' % (where, key, name))
            elif key in ('items', 'not', 'if', 'then', 'else', 'additionalProperties'):
                yield from walk(value, where + '.' + key)
            elif key in ('allOf', 'anyOf', 'oneOf', 'prefixItems'):
                for index, sub in enumerate(value):
                    yield from walk(sub, '%s.%s[%d]' % (where, key, index))


class SchemaShapeTests(unittest.TestCase):
    def test_schemas_are_draft_2020_12_with_ids_and_supported_keywords_only(self):
        self.assertGreaterEqual(len(REG.documents), 20)
        for relative, identifier in REG.paths.items():
            document = REG.documents[identifier]
            self.assertEqual(document['$schema'], 'https://json-schema.org/draft/2020-12/schema', relative)
            self.assertEqual(identifier, 'https://modelplan.ai/schema/verification/' + relative)
            self.assertIn('SPDX-License-Identifier: MIT', document['$comment'])
            for where, node in walk(document):
                unknown = {k for k in node if not k.startswith('x-')} - receipt_schema.KEYWORDS - receipt_schema.ANNOTATIONS
                self.assertFalse(unknown, '%s %s %s' % (relative, where, unknown))
                if '$ref' in node:
                    REG.resolve(identifier, node['$ref'])  # every reference resolves

    def test_every_native_kind_schema_carries_the_envelope_and_its_own_kind(self):
        kinds = receipt_schema.native_kinds()
        for kind, relative in kinds.items():  # C2.6 F: the App's envelope; refresh rows stay flat
            schema = REG.documents[REG.id_for(relative)]
            name = 'kind' if kind == 'refresh' else 'event'
            required = set(ENVELOPE) | ({'kind'} if kind == 'refresh' else {'event', 'timestamp', 'checks'})
            self.assertTrue(required <= set(schema['required']), kind)
            self.assertIs(schema['additionalProperties'], False, kind)
            if kind != 'refresh':
                self.assertIs(schema['properties']['checks']['additionalProperties'], False, kind)
            declared = schema['properties'][name]
            self.assertIn(kind, declared.get('enum', [declared.get('const')]), kind)
        self.assertEqual(set(kinds), {
            'started', 'doctor', 'dock-surface-frame', 'status-item-frame', 'menu-begin', 'menu-end',
            'menu-private-title-visible', 'status-menu-action-arrived', 'refresh', 'clear-initiated',
            'accepted-clear', 'menu-scrubbed', 'stop-or-lease-expired', 'owner-preempted', 'terminate-completed'})

    def test_positive_fixtures_validate_and_cover_every_schema(self):
        used, kinds = set(), set()
        for name in sb.BATCHES:
            directory = FIXTURES / 'batches' / name
            for row in rows_of((directory / 'native-observations.jsonl').read_bytes()):
                kind = receipt_schema.native_kind(row)
                self.assertEqual(receipt_schema.native_errors(row), [], (name, kind))
                kinds.add(kind)
            for file in POINTER_FILES:
                for row in rows_of((directory / file).read_bytes()):
                    self.assertEqual(REG.errors(row, 'pointer-receipt.json'), [], (name, file, row['event']))
                    kinds.add(row['event'])
            for file, schema in LINE_SCHEMAS.items():
                for row in rows_of((directory / file).read_bytes()):
                    self.assertEqual(REG.errors(row, schema), [], (name, file))
                used.add(schema)
            for file, schema in FILE_SCHEMAS.items():
                self.assertEqual(REG.errors(json.loads((directory / file).read_text()), schema), [], (name, file))
                used.add(schema)
        self.assertEqual(set(receipt_schema.native_kinds()) - kinds, {'owner-preempted'})  # shares stop.json
        self.assertTrue({'pointer-host-permission', 'mouse-moved-posted', 'mouse-button-down-posted',
                         'mouse-button-up-posted', 'pointer-result'} <= kinds)
        self.assertEqual(used | {'pointer-receipt.json', 'native-row.json', 'common.json'}
                         | set(receipt_schema.native_kinds().values()), set(REG.paths))

    def test_committed_fixtures_match_the_builder(self):
        with tempfile.TemporaryDirectory() as directory:
            sb.write(directory)
            for name in sb.BATCHES:
                fresh, committed = Path(directory, 'batches', name), FIXTURES / 'batches' / name
                self.assertEqual(sorted(p.name for p in fresh.iterdir()), sorted(p.name for p in committed.iterdir()))
                for path in fresh.iterdir():
                    self.assertEqual(path.read_bytes(), (committed / path.name).read_bytes(),
                                     'fixture drift: regenerate with U6/synthetic_batch.py --write ' + path.name)

    def test_provenance_marks_authored_native_fixtures_pending_producer_capture(self):
        provenance = json.loads((FIXTURES / 'provenance.json').read_text())
        entries = {e['file']: e for e in provenance['entries']}
        files = {p.relative_to(FIXTURES).as_posix() for p in FIXTURES.rglob('*') if p.is_file()} - {'provenance.json'}
        self.assertEqual(set(entries), files)
        for file, entry in entries.items():
            if file.endswith(('launch-cleanup.json', 'dock-capture.json', 'consent-reset.json', 'operator-finish.json')):
                self.assertEqual((entry['generated'], entry['status']), (True, 'real-producer'), file)
            elif file.endswith(('native-observations.jsonl', '-pointer.jsonl', '-pointer-clear.jsonl',
                                'runtime-calls.jsonl', 'result.json')):
                self.assertEqual((entry['generated'], entry['status']), (False, 'pending-producer-capture'), file)
                self.assertTrue(entry['captureCommand'], file)

    def test_required_identity_clock_session_and_proof_fields_cannot_be_absent(self):
        trace = sb.valid(closure_receipt=CLOSURE)
        app, errors = sb.app_native_row, receipt_schema.native_errors
        for flat in trace.native:
            row = app(flat)
            kind = flat['kind']
            self.assertEqual(errors(row), [], kind)
            schema = REG.documents[REG.id_for(receipt_schema.native_kinds()[kind])]
            for key in schema['required']:
                self.assertTrue(errors({k: v for k, v in row.items() if k != key}), (kind, key))
            for key in schema['properties'].get('checks', {}).get('required', []):
                broken = dict(row, checks={k: v for k, v in row['checks'].items() if k != key})
                self.assertTrue(errors(broken), (kind, 'checks.' + key))
            self.assertTrue(errors(dict(row, extra=1)), kind)
            if 'checks' in row:
                self.assertTrue(errors(dict(row, checks=dict(row['checks'], extra=1))), kind)
                self.assertTrue(errors(dict(row, kind=kind)), kind)  # one encoding per row
            self.assertTrue(errors(dict(row, seq=True)), kind)  # bool is not an integer
            self.assertTrue(errors(dict(row, seq=0)), kind)
        self.assertTrue(errors(dict(trace.one('started'))), 'a flat C2.4 row is not the App envelope')
        end = trace.one('menu-end', sessionID=sb.SESSION_B)
        self.assertTrue(errors(app({k: v for k, v in end.items() if k != 'clearID'})))
        self.assertTrue(errors(app(dict(trace.one('menu-end', sessionID=sb.SESSION_A), clearID=sb.CLEAR))))
        requested = trace.one('refresh', phase='requested')
        self.assertTrue(errors(dict(requested, rowsSequenceAfter=9)))
        self.assertTrue(errors(dict(requested, phase='failed', reason='engine-error')))
        self.assertTrue(errors(dict(requested, phase='failed', reason='free engine text', rowsSequenceBefore=None)))
        self.assertTrue(errors({k: v for k, v in requested.items() if k != 'copilotAccountsBefore'}))
        self.assertTrue(errors(dict(requested, dispositions=dict(sb.DISPOSITIONS))))  # the reply belongs to accepted
        accepted = trace.one('refresh', phase='accepted')
        for key in ('engineRequestID', 'dispositions'):
            self.assertTrue(errors({k: v for k, v in accepted.items() if k != key}), key)
        self.assertTrue(errors(dict(accepted, dispositions={'claude.account_usage.saved_login': 'scheduled'})))
        self.assertTrue(errors(dict(accepted, dispositions={'copilot.runtime_usage': 'later'})))
        completed = trace.one('refresh', phase='completed')
        for key in COMPLETED_ONLY:
            self.assertTrue(errors({k: v for k, v in completed.items() if k != key}), key)
        self.assertTrue(errors(dict(completed, readingSHA256='synthetic reading')))  # a digest, never the reading
        self.assertTrue(errors({k: v for k, v in requested.items() if k != 'engineRequestID'}))
        abandoned = {k: v for k, v in completed.items() if k not in COMPLETED_ONLY}
        self.assertEqual(errors(dict(abandoned, phase='abandoned', cause='stop')), [])
        self.assertTrue(errors(dict(abandoned, phase='abandoned', cause='other')))
        self.assertEqual(errors(dict(abandoned, phase='deferred')), [])
        title = trace.one('menu-private-title-visible', sessionID=sb.SESSION_B)
        self.assertTrue(errors(app(dict(title, privateItemIDs=[]))))
        self.assertTrue(errors(app(dict(title, titleSHA256='SYNTHETIC'))))
        for flat in trace.dock + trace.status:
            row = sb.pointer_drive_row(flat)
            self.assertEqual(REG.errors(row, 'pointer-receipt.json'), [], flat['kind'])
            if flat['kind'] == 'pointer-host-permission':
                continue  # written without run binding today; never bound evidence
            for key in ('runID', 'epoch', 'targetPID', 'mono', 'at'):
                self.assertTrue(REG.errors({k: v for k, v in row.items() if k != key}, 'pointer-receipt.json'), (flat['kind'], key))
        reset = trace.reset
        self.assertTrue(REG.errors(dict(reset, storeEpochAfter=None), 'consent-reset.json'))
        self.assertEqual(REG.errors(dict(reset, exitCode=1, storeEpochAfter=None, generationAfter=None), 'consent-reset.json'), [])
        self.assertTrue(REG.errors(dict(reset, exitCode=1), 'consent-reset.json'))

    def test_validator_subset(self):
        self.assertFalse(receipt_schema._is_type(True, 'integer'))
        self.assertFalse(receipt_schema._is_type(float('nan'), 'number'))
        self.assertTrue(receipt_schema._equal(1, 1.0))
        self.assertFalse(receipt_schema._equal(True, 1))
        with self.assertRaises(receipt_schema.UnsupportedSchema):
            REG._check(1, {'format': 'date-time'}, REG.id_for('common.json'), '$', [])


class LaunchCleanupSchemaTests(unittest.TestCase):
    """check_launch_cleanup.check() output, validate_receipt and launch-cleanup.json agree."""
    SHAPE_CODES = {'closure-schema', 'closure-keys', 'closure-run-type', 'closure-field-type', 'closure-checks',
                   'closure-check-type', 'closure-failures', 'closure-timing-type'}

    def test_schema_keys_match_the_checker_exactly(self):
        schema = REG.documents[REG.id_for('launch-cleanup.json')]
        self.assertEqual(set(schema['required']), set(clc.KEYS))
        self.assertEqual(set(schema['properties']), set(clc.KEYS))
        self.assertEqual(set(schema['properties']['checks']['required']), set(clc.CHECKS))
        self.assertEqual(set(schema['properties']['checks']['properties']), set(clc.CHECKS))
        self.assertEqual(schema['properties']['failures']['items']['enum'], list(clc.CHECKS))
        for key in clc.TIMING:
            self.assertEqual(schema['properties'][key]['type'], ['number', 'null'], key)
        for key in clc.STATUSES:
            self.assertEqual(schema['properties']['checks']['properties'][key]['type'], ['integer', 'null'], key)
        self.assertEqual(schema['properties']['at']['pattern'], '^' + clc.AT.pattern + '$')

    def receipts(self):
        yield 'closed', CLOSURE
        yield 'controller-failed', sb.closure(controller=1)
        yield 'statuses-missing', sb.closure(controller=None, guardian_status=None, scenario_status=None)
        yield 'late', sb.closure(now_offset=sb.LEASE_SECONDS + 5)
        yield 'started-before-lease', sb.closure(started_offset=-5)

    def test_real_checker_receipts_satisfy_schema_and_validator(self):
        for name, receipt in self.receipts():
            self.assertEqual(REG.errors(receipt, 'launch-cleanup.json'), [], name)
            self.assertIs(clc.validate_receipt(receipt), receipt, name)
        self.assertEqual(dict(self.receipts())['controller-failed']['failures'], ['controllerStatus'])

    def mutations(self, r):
        yield 'schema', dict(r, schema='launch-cleanup/2')
        for key in clc.KEYS:
            yield 'drop-' + key, {k: v for k, v in r.items() if k != key}
        yield 'extra', dict(r, extra=True)
        yield 'run-type', dict(r, runID=7)
        yield 'ok-type', dict(r, ok=1)
        yield 'at-format', dict(r, at='2030-03-17 17:47:30')
        yield 'checks-extra', dict(r, checks=dict(r['checks'], other=True))
        yield 'checks-missing', dict(r, checks={k: v for k, v in r['checks'].items() if k != 'helpersGone'})
        yield 'status-bool', dict(r, checks=dict(r['checks'], guardianStatus=False))
        yield 'check-int', dict(r, checks=dict(r['checks'], helpersGone=1))
        yield 'failures-duplicate', dict(r, ok=False, failures=['helpersGone', 'helpersGone'])
        yield 'failures-unknown', dict(r, ok=False, failures=['notACheck'])
        yield 'timing-string', dict(r, closedAt='soon')
        yield 'failures-inconsistent', dict(r, ok=False, failures=['helpersGone'])
        yield 'ok-inconsistent', dict(r, ok=False)
        yield 'closed-without-subject-gone', dict(r, checks=dict(r['checks'], subjectGone=False), ok=False,
                                                  failures=['subjectGone'])
        yield 'window-inconsistent', dict(r, closedWithinLease=False)
        yield 'controller-3-without-reason', dict(r, stopReasonRecorded=False)

    def test_schema_rejection_implies_validator_rejection_and_shape_codes_imply_schema_rejection(self):
        for name, receipt in self.mutations(CLOSURE):
            shape_ok = REG.valid(receipt, 'launch-cleanup.json')
            try:
                clc.validate_receipt(receipt)
                code = None
            except ValueError as error:
                code = str(error)
            self.assertIsNotNone(code, name)  # every mutation is rejected by the checker
            if not shape_ok:
                self.assertIsNotNone(code, name)
            if code in self.SHAPE_CODES:
                self.assertFalse(shape_ok, '%s: %s' % (name, code))
            else:  # meaning: consistency only the validator (and the oracle through it) can judge
                self.assertIn(code, {'closure-failures-inconsistent', 'closure-ok-inconsistent',
                                     'closure-time-inconsistent', 'closure-window-inconsistent'}, name)


# Expected step outcomes (outcome, reason, detail) of the non-PASS steps; every other step must PASS.
PRE = ('not-run', 'not-delivered', 'prerequisite-not-met')
UNUSABLE = ('not-run', 'unknown', 'native-unusable')


def replay_trace(trace, ctx=None, drop=()):
    files = {k: v for k, v in trace.files().items() if k not in drop}
    return replay.replay(ctx or sb.context(), files)


def shift(rows, seconds):
    for row in rows:
        row['mono'] = sb.m(row['mono'] - sb.MONO0 + seconds)
        row['at'] = sb.at(row['mono'])


def set_mono(trace, row, offset):
    row['mono'], row['at'] = sb.m(offset), sb.at(sb.m(offset))
    trace.native.remove(row)
    trace.insert(row)


def clear_before_b(t):
    """Clear runs after menu A closed and before menu B is clicked (macrev-332-8)."""
    for kind in ('clear-initiated', 'accepted-clear', 'menu-scrubbed'):
        row = t.one(kind)
        t.native.remove(row)
        row['mono'], row['at'] = sb.m(row['mono'] - sb.MONO0 - 10), sb.at(sb.m(row['mono'] - sb.MONO0 - 10))
        if kind == 'clear-initiated':
            row['openSessionIDs'] = []
        if kind == 'accepted-clear':
            row['scrubbedSessionIDs'] = []
        if kind != 'menu-scrubbed':
            t.insert(row)
    t.remove('menu-end', sessionID=sb.SESSION_B)
    t.reset.update(startMono=sb.m(25.0), endMono=sb.m(25.6))


def other_instance_cleared(t):
    other = '6B1F0D2A-0000-4000-8000-0000000000DD'
    t.remove('menu-end', sessionID=sb.SESSION_B)
    t.one('clear-initiated')['openSessionIDs'] = [other]
    t.one('accepted-clear')['scrubbedSessionIDs'] = [other]
    t.one('menu-scrubbed')['sessionID'] = other


def single_menu(t):
    """macrev2-332-1 / codex-kit-3: only menu A, closed by Refresh, then the clear."""
    for kind in ('menu-begin', 'menu-private-title-visible', 'menu-end'):
        t.remove(kind, sessionID=sb.SESSION_B)
    t.one('clear-initiated')['openSessionIDs'] = []
    t.one('accepted-clear')['scrubbedSessionIDs'] = [sb.SESSION_A]
    t.one('menu-scrubbed').update(sessionID=sb.SESSION_A, itemStates=[dict(id=sb.ITEM_A, state='cleared')])
    t.clear = []


def user_close_before_clear(t):
    t.remove('menu-end', sessionID=sb.SESSION_B)
    t.insert(t.row('menu-end', 34.0, menuObjectID=sb.MENU, sessionID=sb.SESSION_B, cause='other'))


def stale_title(t):
    t.insert(t.row('menu-private-title-visible', 37.0, menuObjectID=sb.MENU, sessionID=sb.SESSION_B,
                   titleSHA256=sb.sha(sb.SEED_TITLE), privateItemIDs=[sb.ITEM_B]))


def delayed_clear(t):
    """codex-kit-3: scrub 190 s after initiation; C2.6 E makes it FAIL timeout (bound 5 s)."""
    for kind, offset in (('menu-end', 225.3), ('accepted-clear', 225.35), ('menu-scrubbed', 225.36),
                         ('doctor', 226.0), ('stop-or-lease-expired', 240.5), ('terminate-completed', 240.7)):
        row = t.find(kind, **({'sessionID': sb.SESSION_B} if kind == 'menu-end' else {}))[-1]
        set_mono(t, row, offset)
    t.finish.update(mono=sb.m(240.0))
    t.closure = sb.closure(now_offset=260.0)


def defer(t, disposition):
    """accepted shows Copilot not scheduled; the App writes deferred (C2.6 D)."""
    t.one('refresh', phase='accepted')['dispositions']['copilot.runtime_usage'] = disposition
    row = t.one('refresh', phase='completed')
    for key in COMPLETED_ONLY:
        row.pop(key)
    row['phase'] = 'deferred'
    set_mono(t, row, 21.2)


def abandon(t, cause, offset):
    """The App watchdog's terminal instead of completed (C2.6 D)."""
    row = t.one('refresh', phase='completed')
    for key in COMPLETED_ONLY:
        row.pop(key)
    row.update(phase='abandoned', cause=cause)
    set_mono(t, row, offset)


def duplicate(t, kind, offset, **changes):
    row = copy.deepcopy(t.one(kind, **{k: v for k, v in changes.pop('match', {}).items()}))
    row.update(changes)
    row['mono'], row['at'] = sb.m(offset), sb.at(sb.m(offset))
    t.insert(row)


def swap_seq(t):
    a, b = t.one('menu-begin', sessionID=sb.SESSION_A), t.one('menu-private-title-visible', sessionID=sb.SESSION_A)
    a['seq'], b['seq'] = b['seq'], a['seq']


R = sb
CASES = [
    # id, sources, mutate(trace), ctx changes, dropped files, {step: expected}, overall
    ('production-handler-bypassed', 'macrev-332-4, codex-kit-4', lambda t: t.remove('refresh', phase='requested'), {}, (),
     {3: ('not-run', 'not-delivered', 'requested-missing')}, 'not-run'),
    ('separate-client-request', 'macrev-332-4', lambda t: duplicate(t, 'refresh', 21.06, match=dict(phase='requested')), {}, (),
     {3: ('fail', 'unknown', 'requested-duplicate')}, 'fail'),
    ('closure-missing', 'macrev-332-5, codex-kit-1', None, {}, ('launch-cleanup.json',),
     {8: ('not-run', 'not-delivered', 'subject-not-gone'), 9: ('not-run', 'not-delivered', 'closure-missing')}, 'not-run'),
    ('closure-failed', 'macrev-332-5', lambda t: setattr(t, 'closure', sb.closure(controller=1)), {}, (),
     {9: ('not-run', 'unknown', 'closure-not-ok')}, 'not-run'),
    ('closure-other-run', 'macrev-332-5', lambda t: setattr(t, 'closure', dict(CLOSURE, runID='u6-run-0002')), {}, (),
     {8: ('not-run', 'not-delivered', 'subject-not-gone'), 9: ('not-run', 'wrong-subject', 'closure-other-run')}, 'not-run'),
    ('closure-inconsistent', 'macrev-332-5, SKILLS-CONSULT 7', lambda t: setattr(t, 'closure', dict(CLOSURE, failures=['helpersGone'])),
     {}, (), {8: ('not-run', 'not-delivered', 'subject-not-gone'), 9: ('fail', 'unknown', 'closure-inconsistent')}, 'fail'),
    ('closure-truncated', 'macrev-332-5', 'closure-truncated', {}, (),
     {8: ('not-run', 'not-delivered', 'subject-not-gone'), 9: ('not-run', 'unknown', 'closure-malformed')}, 'not-run'),
    ('clear-click-after-clear', 'macrev-332-8', clear_before_b, {}, (),
     {6: ('not-run', 'not-delivered', 'clear-initiated-missing')}, 'not-run'),
    ('clear-of-another-instance', 'macrev-332-8', other_instance_cleared, {}, (),
     {6: ('not-run', 'wrong-subject', 'menu-b-not-open-at-clear')}, 'not-run'),
    ('pointer-for-another-pid', 'macrev-332-10, codex-kit-5', lambda t: [r.update(targetPID=R.FOREIGN_PID) for r in t.status], {}, (),
     {2: ('not-run', 'not-delivered', 'click-missing'), 3: PRE, 4: PRE, 5: PRE, 6: PRE}, 'not-run'),
    ('menu-begin-from-another-pid', 'macrev-332-10, codex-kit-2',
     lambda t: (t.one('menu-begin', sessionID=R.SESSION_A).update(pid=R.FOREIGN_PID), t.reseq()), {}, (),
     {2: ('not-run', 'out-of-window', 'menu-begin-out-of-window'), 3: PRE, 4: PRE, 5: PRE, 6: PRE}, 'not-run'),
    ('menu-b-closed-before-clear', 'macrev2-332-1, macrev-332-10', user_close_before_clear, {}, (),
     {6: ('fail', 'unknown', 'menu-b-ended-before-clear')}, 'fail'),
    ('single-closed-menu-clear', 'macrev2-332-1, codex-kit-3', single_menu, {}, (),
     {4: ('not-run', 'not-delivered', 'click-missing'), 5: PRE, 6: PRE}, 'not-run'),
    ('stale-title-after-clear', 'macrev-332-10, codex-kit-3', stale_title, {}, (),
     {6: ('fail', 'unknown', 'title-after-clear')}, 'fail'),
    ('private-item-unreported', 'macrev-332-10', lambda t: t.one('menu-private-title-visible', sessionID=R.SESSION_B).update(
        privateItemIDs=[R.ITEM_B, '105553116309504']), {}, (), {6: ('fail', 'unknown', 'private-item-unreported')}, 'fail'),
    ('retained-original-item-private', 'codex-kit-3 (C2 wrong-PASS trace)', lambda t: t.one('menu-scrubbed').update(
        itemStates=[dict(id=R.ITEM_B, state='private')]), {}, (), {6: ('fail', 'unknown', 'private-item-retained')}, 'fail'),
    ('current-menu-still-private', 'macrev-332-10', lambda t: t.one('menu-scrubbed').update(privateTitlePresent=True), {}, (),
     {6: ('fail', 'unknown', 'private-content-present')}, 'fail'),
    ('reset-receipt-missing', 'macrev-332-12, codex-kit-8', None, {}, ('consent-reset.json',),
     {6: ('not-run', 'not-delivered', 'reset-missing')}, 'not-run'),
    ('reset-failed', 'macrev-332-12, codex-kit-8', lambda t: t.reset.update(exitCode=1, storeEpochAfter=None, generationAfter=None,
                                                                             outcome='failed', reason='engine-error'),
     {}, (), {6: ('not-run', 'unknown', 'reset-failed')}, 'not-run'),
    ('reset-other-run', 'macrev-332-12', lambda t: t.reset.update(epoch='u6-epoch-0002'), {}, (),
     {6: ('not-run', 'wrong-subject', 'reset-other-run')}, 'not-run'),
    ('reset-other-home', 'macrev-332-12 (wrong operation)', lambda t: t.reset.update(homeSHA256=R.sha('owner home')), {}, (),
     {6: ('not-run', 'wrong-subject', 'reset-unbound')}, 'not-run'),
    ('reset-other-helper', 'macrev-332-12, codex-kit-10', lambda t: t.reset.update(helperSHA256=R.sha('other helper')), {}, (),
     {6: ('not-run', 'wrong-subject', 'reset-unbound')}, 'not-run'),
    ('same-generation-other-store-epoch', 'codex-kit-8, SKILLS-CONSULT 7', lambda t: t.reset.update(storeEpochAfter='7a' * 16), {}, (),
     {6: ('not-run', 'wrong-subject', 'pair-mismatch')}, 'not-run'),
    ('same-store-epoch-other-generation', 'codex-kit-8', lambda t: t.reset.update(generationAfter=2), {}, (),
     {6: ('not-run', 'wrong-subject', 'pair-mismatch')}, 'not-run'),
    ('clear-initiated-other-pair', 'codex-kit-8', lambda t: t.one('clear-initiated').update(storeEpochAfter='7a' * 16), {}, (),
     {6: ('not-run', 'wrong-subject', 'pair-mismatch')}, 'not-run'),
    ('accepted-clear-other-pair', 'codex-kit-8',lambda t: t.one('accepted-clear').update(generationAfter=2), {}, (),
     {6: ('not-run', 'wrong-subject', 'pair-mismatch')}, 'not-run'),
    ('clear-initiated-outside-reset-window', 'codex-kit-8', lambda t: t.reset.update(startMono=R.m(20.0), endMono=R.m(20.6)), {}, (),
     {6: ('not-run', 'out-of-window', 'clear-initiated-out-of-window')}, 'not-run'),
    ('old-accepted-clear-shape', 'macrev-332-14', lambda t: t.one('accepted-clear').update(
        scrubbedInstanceIDs=[R.MENU], oldItemTitlesScrubbed=True, oldItemPrivateAttributesScrubbed=True), {}, (),
     {1: UNUSABLE, 2: UNUSABLE, 3: UNUSABLE, 4: UNUSABLE, 5: UNUSABLE, 6: UNUSABLE, 8: UNUSABLE,
      10: ('not-run', 'unknown', 'native-row-malformed')}, 'not-run'),
    ('flat-c2.4-rows', 'C2.6 F (the App envelope is the format)', lambda t: setattr(t, 'flat', True),
     {}, (), {1: UNUSABLE, 2: UNUSABLE, 3: UNUSABLE, 4: UNUSABLE, 5: UNUSABLE, 6: UNUSABLE, 8: UNUSABLE,
              10: ('not-run', 'unknown', 'native-row-malformed')}, 'not-run'),
    ('closure-observed-after-expiry', 'macrev-332-15, codex-kit-9', lambda t: setattr(t, 'closure', sb.closure(now_offset=R.LEASE_SECONDS + 5)),
     {}, (), {9: ('fail', 'out-of-window', 'closure-late')}, 'fail'),
    ('subject-started-before-lease', 'codex-kit-9', lambda t: setattr(t, 'closure', sb.closure(started_offset=-5)), {}, (),
     {9: ('fail', 'out-of-window', 'closure-late')}, 'fail'),
    ('closure-other-lease-window', 'codex-kit-9, C2.6 F', None, dict(leaseExpiresAt=R.T0 + 1200), (),
     {8: ('not-run', 'not-delivered', 'subject-not-gone'), 9: ('not-run', 'wrong-subject', 'lease-window-mismatch')},
     'not-run'),
    ('physical-receipts-missing-runner-says-pass', 'codex-kit-1', None, {}, ('dock-pointer.jsonl', 'dock-capture.json'),
     {1: ('not-run', 'not-delivered', 'dock-move-missing')}, 'not-run'),
    ('capture-file-name-only', 'codex-kit-5', None, {}, ('dock-capture.json',),
     {1: ('not-run', 'not-delivered', 'capture-missing')}, 'not-run'),
    ('capture-bound-to-other-frame', 'codex-kit-5', lambda t: t.capture.update(frameSeq=t.one('dock-surface-frame', state='sliver')['seq']),
     {}, (), {1: ('not-run', 'wrong-subject', 'capture-unbound')}, 'not-run'),
    ('capture-hash-mismatch', 'codex-kit-5', lambda t: setattr(t, 'image', t.image + b'\0'), {}, (),
     {1: ('fail', 'unknown', 'capture-hash-mismatch')}, 'fail'),
    ('dock-frame-late', 'codex-kit-5', lambda t: shift(t.dock, -6.0), {}, (),
     {1: ('not-run', 'out-of-window', 'dock-frame-out-of-window')}, 'not-run'),
    ('menu-begin-before-button-down', 'codex-kit-5', lambda t: (
        set_mono(t, t.one('menu-begin', sessionID=R.SESSION_A), 19.98),
        set_mono(t, t.one('menu-private-title-visible', sessionID=R.SESSION_A), 19.981)), {}, (),
     {2: ('not-run', 'out-of-window', 'menu-begin-out-of-window'), 3: PRE, 4: PRE, 5: PRE, 6: PRE}, 'not-run'),
    ('menu-begin-after-click-deadline', 'codex-kit-5', lambda t: shift(t.status, -5.0), {}, (),
     {2: ('not-run', 'out-of-window', 'menu-begin-out-of-window'), 3: PRE, 4: PRE, 5: PRE, 6: PRE}, 'not-run'),
    ('foreign-pid-for-every-row', 'codex-kit-2', lambda t: [r.update(pid=R.FOREIGN_PID) for r in t.native], {}, (),
     {1: UNUSABLE, 2: UNUSABLE, 3: UNUSABLE, 4: UNUSABLE, 5: UNUSABLE, 6: UNUSABLE, 8: UNUSABLE,
      10: ('not-run', 'not-delivered', 'started-missing')}, 'not-run'),
    ('descending-seq', 'codex-kit-2', swap_seq, {}, (),
     {1: UNUSABLE, 2: UNUSABLE, 3: UNUSABLE, 4: UNUSABLE, 5: UNUSABLE, 6: UNUSABLE, 8: UNUSABLE,
      10: ('fail', 'unknown', 'native-order-contradiction')}, 'fail'),
    ('duplicate-seq', 'codex-kit-2, SKILLS-CONSULT 7', lambda t: t.one('menu-begin', sessionID=R.SESSION_B).update(
        seq=t.one('menu-begin', sessionID=R.SESSION_B)['seq'] - 1), {}, (),
     {1: UNUSABLE, 2: UNUSABLE, 3: UNUSABLE, 4: UNUSABLE, 5: UNUSABLE, 6: UNUSABLE, 8: UNUSABLE,
      10: ('fail', 'unknown', 'native-order-contradiction')}, 'fail'),
    ('truncated-native-record', 'codex-kit-2, SKILLS-CONSULT 7', 'native-truncated', {}, (),
     {1: UNUSABLE, 2: UNUSABLE, 3: UNUSABLE, 4: UNUSABLE, 5: UNUSABLE, 6: UNUSABLE, 8: UNUSABLE,
      10: ('not-run', 'unknown', 'native-truncated')}, 'not-run'),
    ('unsupported-native-protocol', 'SKILLS-CONSULT 1', lambda t: t.one('started').update(protocol='u6-native/2'), {}, (),
     {1: UNUSABLE, 2: UNUSABLE, 3: UNUSABLE, 4: UNUSABLE, 5: UNUSABLE, 6: UNUSABLE, 8: UNUSABLE,
      10: ('not-run', 'unknown', 'protocol-unsupported')}, 'not-run'),
    ('native-observations-missing', 'codex-kit-1', None, {}, ('native-observations.jsonl',),
     {1: UNUSABLE, 2: UNUSABLE, 3: UNUSABLE, 4: UNUSABLE, 5: UNUSABLE, 6: UNUSABLE, 8: UNUSABLE,
      10: ('not-run', 'not-delivered', 'native-missing')}, 'not-run'),
    ('terminate-before-stop', 'codex-kit-2', lambda t: set_mono(t, t.one('terminate-completed'), 40.4), {}, (),
     {8: ('not-run', 'not-delivered', 'terminate-missing')}, 'not-run'),
    ('terminate-completed-missing', 'C2.4 step 8', lambda t: t.remove('terminate-completed'), {}, (),
     {8: ('not-run', 'not-delivered', 'terminate-missing')}, 'not-run'),
    ('stop-row-from-another-pid', 'codex-kit-2', lambda t: (t.one('stop-or-lease-expired').update(pid=R.FOREIGN_PID), t.reseq()), {}, (),
     {8: ('not-run', 'not-delivered', 'stop-missing')}, 'not-run'),
    ('owner-preempted-instead-of-stop', 'codex-kit-2', lambda t: t.one('stop-or-lease-expired').update(kind='owner-preempted'), {}, (),
     {8: ('not-run', 'unknown', 'owner-preempted')}, 'not-run'),
    ('refresh-terminal-late', 'codex-kit-4', lambda t: set_mono(t, t.one('refresh', phase='completed'), 82.0), {}, (),
     {3: ('not-run', 'timeout', 'terminal-late')}, 'not-run'),
    ('refresh-terminal-missing', 'codex-kit-4', lambda t: t.remove('refresh', phase='completed'), {}, (),
     {3: ('not-run', 'timeout', 'terminal-missing')}, 'not-run'),
    ('refresh-arrival-duplicate', 'codex-kit-4', lambda t: duplicate(t, 'status-menu-action-arrived', 21.01), {}, (),
     {3: ('fail', 'unknown', 'arrival-duplicate')}, 'fail'),
    ('refresh-terminal-duplicate', 'codex-kit-4, codex-kit-12', lambda t: duplicate(
        t, 'refresh', 23.5, match=dict(phase='completed'), phase='failed', reason='engine-error', rowsSequenceAfter=None)
     or [t.find('refresh', phase='failed')[0].pop(k) for k in COMPLETED_ONLY], {}, (),
     {3: ('fail', 'unknown', 'terminal-duplicate')}, 'fail'),
    ('refresh-terminal-duplicate-outside-window', 'codex-kit-12', lambda t: duplicate(t, 'refresh', 39.0, match=dict(phase='completed'))
     or set_mono(t, t.find('refresh', phase='completed')[-1], 90.0), {}, (),
     {3: ('fail', 'unknown', 'terminal-duplicate')}, 'fail'),
    ('refresh-failed', 'C2.4 step 3', lambda t: t.one('refresh', phase='completed').update(phase='failed', reason='engine-error')
     or [t.one('refresh', phase='failed').pop(k) for k in COMPLETED_ONLY], {}, (),
     {3: ('fail', 'engine-error', 'refresh-failed')}, 'fail'),
    ('refresh-rows-unchanged', 'C2.4 step 3, C2.6 D (completed without the qualifying projection)',
     lambda t: t.one('refresh', phase='completed').update(rowsSequenceAfter=3), {}, (),
     {3: ('fail', 'unknown', 'projection-not-qualifying')}, 'fail'),
] + [(name, 'C2.6 D (deferred %s)' % disposition, (lambda d: lambda t: defer(t, d))(disposition), {}, (),
      {3: ('not-run', reason, 'refresh-deferred')}, 'not-run')
     for name, disposition, reason in (('deferred-cooldown', 'cooldown', 'cooldown'),
                                       ('deferred-read-only', 'read_only', 'engine-disabled'),
                                       ('deferred-offline', 'offline', 'engine-disabled'),
                                       ('deferred-policy-pending', 'policy_pending', 'consent-required'))] + [
    ('refresh-abandoned-deadline', 'C2.6 D (watchdog deadline; also the unrelated-only advance: no completed)',
     lambda t: abandon(t, 'deadline', 81.05), {}, (), {3: ('not-run', 'timeout', 'refresh-abandoned-deadline')}, 'not-run'),
    ('refresh-abandoned-stop', 'C2.6 D (watchdog stop)', lambda t: abandon(t, 'stop', 23.0), {}, (),
     {3: ('not-run', 'not-delivered', 'refresh-abandoned-stop')}, 'not-run'),
    ('accepted-missing', 'C2.6 D (no per-call reply)', lambda t: t.remove('refresh', phase='accepted'), {}, (),
     {3: ('not-run', 'not-delivered', 'accepted-missing')}, 'not-run'),
    ('accepted-stale-snapshot', 'C2.7 D FAIL: "`accepted` with another `engineRequestID`" (a stale scheduled value)',
     lambda t: t.one('refresh', phase='accepted').update(engineRequestID=16), {}, (),
     {3: ('fail', 'unknown', 'accepted-other-engine-request')}, 'fail'),
    ('accepted-duplicate', 'C2.6 D, C2.6 F', lambda t: duplicate(t, 'refresh', 21.07, match=dict(phase='accepted')), {}, (),
     {3: ('fail', 'unknown', 'accepted-duplicate')}, 'fail'),
    ('copilot-accounts-before-nonzero', 'C2.6 D (not a first attempt)', lambda t: t.one('refresh', phase='requested').update(
        copilotAccountsBefore=1), {}, (), {3: ('fail', 'unknown', 'copilot-accounts-before')}, 'fail'),
    ('completed-on-unrelated-projection', 'C2.6 D (unrelated-only advance reported as completed)',
     lambda t: t.one('refresh', phase='completed').update(copilotAccountsAfter=0), {}, (),
     {3: ('fail', 'unknown', 'projection-not-qualifying')}, 'fail'),
    ('completed-other-reading', 'C2.6 D (readingSHA256 mismatch)', lambda t: t.one('refresh', phase='completed').update(
        readingSHA256=sb.reading_sha256(dict(sb.SEED_READING_ACCOUNT, route='other'))),
     {}, (), {3: ('fail', 'unknown', 'projection-not-qualifying')}, 'fail'),
    ('completed-two-accounts', 'C2.6 D (more than one Copilot account)', lambda t: t.one('refresh', phase='completed').update(
        copilotAccountsAfter=2), {}, (), {3: ('fail', 'unknown', 'projection-not-qualifying')}, 'fail'),
    ('unrelated-then-valid', 'C2.6 D (earlier unrelated projections are ignored)',
     lambda t: t.one('refresh', phase='completed').update(rowsSequenceAfter=6), {}, (), {}, 'pass'),
    ('copilot-not-scheduled-but-completed', 'C2.6 D, C2.6 F', lambda t: t.one('refresh', phase='accepted')['dispositions'].update(
        {'copilot.runtime_usage': 'cooldown'}), {}, (), {3: ('fail', 'unknown', 'copilot-not-scheduled')}, 'fail'),
    ('stub-call-missing', 'C2.6 D', lambda t: setattr(t, 'runtime', sb.stub_calls(['connect', 'auth.getStatus'], 21.065)),
     {}, (), {3: ('fail', 'unknown', 'quota-call-missing')}, 'fail'),
    ('quota-call-after-completed', 'C2.6 D', lambda t: setattr(t, 'runtime', sb.stub_calls(
        ['connect', 'auth.getStatus', 'account.getQuota'], 23.5)), {}, (), {3: ('fail', 'unknown', 'quota-call-missing')}, 'fail'),
    ('quota-call-before-accepted', 'C2.7 D (the worker is woken before the reply returns)', lambda t: setattr(
        t, 'runtime', sb.stub_calls(['connect', 'auth.getStatus', 'account.getQuota'], 21.051, step=0.002)), {}, (),
     {}, 'pass'),
    ('call-before-requested', 'C2.7 D', lambda t: setattr(t, 'runtime', sb.stub_calls(['account.getQuota'], 21.04)
        + sb.stub_calls(['connect', 'auth.getStatus', 'account.getQuota'], 21.065, first_seq=2)), {}, (),
     {3: ('fail', 'unknown', 'call-before-requested')}, 'fail'),
    ('connect-before-accepted', 'C2.6 D (connect before the reply)', lambda t: setattr(
        t, 'runtime', sb.stub_calls(['connect', 'auth.getStatus'], 21.051, step=0.002)
        + sb.stub_calls(['account.getQuota'], 21.065, first_seq=3)), {}, (), {}, 'pass'),
    ('auth-before-accepted-is-legal', 'C2.6 coordinator clarification (only quota is ordered after accepted)',
     lambda t: setattr(t,'runtime',sb.stub_calls(['connect','auth.getStatus'],21.051,step=0.002)
                        +sb.stub_calls(['account.getQuota'],21.075,first_seq=3)), {}, (), {}, 'pass'),
    ('accepted-other-engine-request', 'C2.7 D FAIL: "`accepted` with another `engineRequestID`"',
     lambda t:t.one('refresh',phase='accepted').update(engineRequestID=999), {}, (),
     {3:('fail','unknown','accepted-other-engine-request')}, 'fail'),
    ('runtime-calls-preseeded', 'C2.6 C-D (the log must be absent in the seed)', lambda t: setattr(t, 'runtime', sb.stub_calls(
        ['connect', 'auth.getStatus', 'account.getQuota'], 1.0) + sb.stub_calls(
        ['connect', 'auth.getStatus', 'account.getQuota'], 21.065, first_seq=4)), {}, (),
     {3: ('fail', 'unknown', 'call-before-requested')}, 'fail'),
    ('runtime-calls-foreign', 'C2.6 D, C2.4 section 1', lambda t: setattr(t, 'runtime', sb.stub_calls(
        ['connect', 'auth.getStatus', 'account.getQuota'], 21.065, run='u6-run-0002')), {}, (),
     {3: ('not-run', 'wrong-subject', 'runtime-calls-foreign')}, 'not-run'),
    ('runtime-calls-missing', 'C2.6 D', None, {}, ('runtime-calls.jsonl',),
     {3: ('not-run', 'not-delivered', 'runtime-calls-missing')}, 'not-run'),
    ('runtime-calls-digest-mismatch', 'C2.6 D', lambda t: setattr(t, 'digest', 'ab' * 32), {}, (),
     {3: ('not-run', 'not-delivered', 'runtime-calls-undigested')}, 'not-run'),
    ('runtime-calls-undigested', 'C2.6 D (result.json without the digest)', None, {}, ('result.json',),
     {3: ('not-run', 'not-delivered', 'runtime-calls-undigested')}, 'not-run'),
    ('accepted-clear-late', 'C2.6 E', lambda t: (set_mono(t, t.one('accepted-clear'), 40.31),
                                                set_mono(t, t.one('menu-scrubbed'), 40.32), t.finish.update(mono=R.m(40.4))),
     {}, (),
     {6: ('fail', 'timeout', 'clear-late')}, 'fail'),
    ('menu-scrubbed-late', 'C2.6 E', lambda t: (set_mono(t, t.one('menu-scrubbed'), 40.31), t.finish.update(mono=R.m(40.4))),
     {}, (),
     {6: ('fail', 'timeout', 'clear-late')}, 'fail'),
    ('menu-a-ended-before-arrival', 'codex-kit-12', lambda t: set_mono(t, t.one('menu-end', sessionID=R.SESSION_A), 20.5), {}, (),
     {3: ('fail', 'unknown', 'arrival-after-menu-end')}, 'fail'),
    ('menu-b-reuses-session-a', 'codex-kit-6', lambda t: t.one('menu-begin', sessionID=R.SESSION_B).update(sessionID=R.SESSION_A), {}, (),
     {4: ('not-run', 'wrong-subject', 'session-reused'), 5: PRE, 6: PRE}, 'not-run'),
    ('click-b-before-a-ended', 'C2.4 step 4', lambda t: set_mono(t, t.one('menu-end', sessionID=R.SESSION_A), 30.02), {}, (),
     {4: ('not-run', 'out-of-window', 'click-b-before-a-ended'), 5: PRE, 6: PRE}, 'not-run'),
    ('title-hash-not-seed', 'C2.4 step 5', lambda t: t.one('menu-private-title-visible', sessionID=R.SESSION_B).update(
        titleSHA256=R.sha('other title')), {}, (), {5: ('not-run', 'wrong-subject', 'title-hash-mismatch'), 6: PRE}, 'not-run'),
    ('title-only-in-session-a', 'C2.4 steps 5-6', lambda t: t.remove('menu-private-title-visible', sessionID=R.SESSION_B), {}, (),
     {5: ('not-run', 'not-delivered', 'title-missing'), 6: PRE}, 'not-run'),
    ('finish-missing', 'codex-kit-7', None, {}, ('operator-finish.json',),
     {7: ('not-run', 'not-delivered', 'finish-missing')}, 'not-run'),
    ('runner-reported-failure', 'codex-kit-7', lambda t: (t.finish['steps'].update(trackedClear='fail'),
                                                          t.finish.update(outcome='fail', reason='not-delivered')), {}, (),
     {7: ('not-run', 'not-delivered', 'runner-reported-fail')}, 'not-run'),
    ('runner-reported-not-run', 'codex-kit-7 (what U6/action_runner.py writes on a failed action)',
     lambda t: (t.finish['steps'].update(trackedClear='not-run'), t.finish.update(outcome='not-run', reason='not-delivered')),
     {}, (), {7: ('not-run', 'not-delivered', 'runner-reported-not-run')}, 'not-run'),
    ('finish-before-receipts', 'codex-kit-7', lambda t: t.finish.update(mono=R.m(30.0)), {}, (),
     {7: ('not-run', 'out-of-window', 'finish-before-receipts')}, 'not-run'),
    ('engine-pin-changed', 'codex-kit-10', None, dict(launchedPins=dict(R.PINS, engine=R.sha('changed engine'))), (),
     {10: ('fail', 'unknown', 'pin-changed')}, 'fail'),
]
# codex-kit-11 (exclusive final inventory) concerns inventory_evidence.py's writes, not receipt meaning; the
# replay never writes and is not the place to test it.


def build(case):
    name, sources, mutate, ctx, drop, expected, overall = case
    trace = sb.valid(closure_receipt=CLOSURE)
    files_override = {}
    if mutate == 'closure-truncated':
        files_override['launch-cleanup.json'] = json.dumps(CLOSURE)[:40].encode()
    elif mutate == 'native-truncated':
        files_override['native-observations.jsonl'] = trace.files()['native-observations.jsonl'][:-25]
    elif mutate is not None:
        mutate(trace)
    files = {k: v for k, v in dict(trace.files(), **files_override).items() if k not in drop}
    return sb.context(**ctx), files


class ReplayOracleTests(unittest.TestCase):
    def assert_steps(self, result, expected, overall):
        actual = {s['step']: (s['outcome'], s['reason'], s['detail']) for s in result['steps'] if s['outcome'] != 'pass'}
        self.assertEqual(actual, expected)
        self.assertEqual(result['outcome'], overall)
        for step in result['steps']:
            self.assertIn(step['detail'], replay.DETAILS)
            self.assertTrue(step['reason'] is None or step['reason'] in replay.SCENARIO_REASONS, step)

    def test_complete_valid_traces_pass_every_step(self):
        for variant in ('main', 'interleaved'):
            self.assert_steps(replay_trace(sb.valid(variant, closure_receipt=CLOSURE)), {}, 'pass')

    def test_committed_batches_pass_through_the_replay_cli(self):
        for name in sb.BATCHES:
            directory = FIXTURES / 'batches' / name
            run = subprocess.run([sys.executable, '-B', str(VERIFICATION / 'U6' / 'replay.py'), '--context',
                                  str(directory / 'context.json'), '--batch', str(directory)],
                                 capture_output=True, text=True, timeout=60)
            self.assertEqual(run.returncode, 0, run.stderr)
            self.assertEqual(json.loads(run.stdout)['outcome'], 'pass')

    def test_clear_caused_close_and_optional_end_both_pass(self):
        trace = sb.valid(closure_receipt=CLOSURE)  # macrev-332-10: a close caused by the clear is not a user close
        self.assertEqual(trace.one('menu-end', sessionID=sb.SESSION_B)['cause'], 'clear')
        self.assertEqual(replay_trace(trace)['outcome'], 'pass')
        trace.remove('menu-end', sessionID=sb.SESSION_B)
        self.assertEqual(replay_trace(trace)['outcome'], 'pass')

    def test_delayed_clear_fails_under_c2_6_e(self):
        """codex-kit-3: C2.6 E bounds accepted-clear and menu-scrubbed to 5 s after clear-initiated."""
        trace = sb.valid(closure_receipt=CLOSURE)
        delayed_clear(trace)
        self.assert_steps(replay_trace(trace), {6: ('fail', 'timeout', 'clear-late')}, 'fail')

    def test_reading_digest_vector(self):
        account, canonical = READING_VECTOR
        self.assertEqual(sb.reading_sha256(account), hashlib.sha256(canonical.encode()).hexdigest())
        self.assertEqual(sb._basis_points(12.345), 1235)  # half away from zero after scaling
        self.assertEqual(sb._basis_points(0.005), 1)

    def test_fixture_receipts_are_the_shipped_writers_output(self):
        """The authored capture/reset/finish receipts equal what capture_owned, consent_reset and action_runner
        write for the same trace, so in-memory traces and committed fixtures agree with the shipped writers."""
        for variant in ('main', 'interleaved'):
            trace = sb.valid(variant, closure_receipt=CLOSURE)
            self.assertEqual(sb.shipped_receipts(trace), (trace.capture, trace.reset, trace.finish), variant)

    def test_replay_rejects_an_invalid_context(self):
        with self.assertRaises(ValueError):
            replay.replay(dict(sb.context(), subjectPID=0), sb.valid(closure_receipt=CLOSURE).files())

    def test_every_detail_maps_to_a_scenario_reason(self):
        for detail, reason in replay.DETAILS.items():
            self.assertTrue(reason is None or reason in replay.SCENARIO_REASONS, detail)


def _negative(case):
    def test(self):
        ctx, files = build(case)
        self.assert_steps(replay.replay(ctx, files), case[5], case[6])
    test.__doc__ = '%s (%s)' % (case[0], case[1])
    return test


for _case in CASES:
    setattr(ReplayOracleTests, 'test_negative_' + _case[0].replace('-', '_'), _negative(_case))


def differential_traces():
    """Every trace the oracle judges, as (name, context, files): the positive batches, the open-timing trace and
    each negative case."""
    yield 'valid', sb.context(), sb.valid(closure_receipt=CLOSURE).files()
    yield 'valid-interleaved', sb.context(), sb.valid('interleaved', closure_receipt=CLOSURE).files()
    trace = sb.valid(closure_receipt=CLOSURE)
    delayed_clear(trace)
    yield 'delayed-clear', sb.context(), trace.files()
    for case in CASES:
        yield (case[0],) + build(case)


def evidence_u6(ctx, files):
    """The real final entry point on the same batch bytes plus the run files sb.kit_batch adds."""
    with tempfile.TemporaryDirectory() as directory:
        args = sb.kit_batch(ctx, files, directory)
        run = subprocess.run([sys.executable, '-B', str(VERIFICATION / 'bin' / 'evidence-u6.py'), *args],
                             capture_output=True, text=True, timeout=60, env=dict(os.environ, PYTHONDONTWRITEBYTECODE='1'))
        if run.returncode != 0:
            raise AssertionError(run.stderr)
        return json.loads(run.stdout.strip().splitlines()[-1])


# C2.7 G.3 asks for no expectedFailure; until M4 lands C2.7 in bin/evidence-u6.py, every trace on which it (at
# #332 6a063beb, unchanged since 8f857aa6) disagrees with the oracle on the overall outcome is listed here:
# trace -> (oracle, evidence-u6, deciding contract text). Each is an expected failure; a fix in evidence-u6 shows
# up as an unexpected success, and a new divergence fails a test, until this table and the README are updated.
_F_IGNORED = 'C2.6 F: "A receipt that fails its schema, names another run/epoch/PID or lease window → NOT-RUN"'
_F_CONTRADICTION = 'C2.6 F: "Two valid receipts that contradict each other (including ... descending/duplicate seq) → FAIL"'
_D_NOT_RUN = 'C2.6 D NOT-RUN: "no accepted, or a missing/foreign/undigested runtime-call receipt"'
_D_ACCEPTED = 'C2.6 D: accepted is "written from the completion of that refresh/request call (the per-call reply, never store.snapshot or any cached value)"'
_D_FAIL_COMPLETED = 'C2.6 D FAIL: "completed without the qualifying projection or without a matching account.getQuota call"'
_D_FAIL_BEFORE = 'C2.7 D FAIL: an account.getQuota call before requested'
_D_PASS_WINDOW = ('C2.7 D PASS: "account.getQuota with mono after requested and before completed (... the call may '
                  'precede accepted)"')
_D_FAIL_OTHER_REQUEST = 'C2.7 D FAIL: "`accepted` with another `engineRequestID`"'
_E = 'C2.6 E: "accepted-clear and menu-scrubbed for B within 5 s of clear-initiated. Late → FAIL timeout"'
BASELINE_DISAGREEMENTS = {
    'closure-other-run': ('not-run', 'fail', _F_IGNORED),
    'closure-other-lease-window': ('not-run', 'pass', _F_IGNORED),
    'old-accepted-clear-shape': ('not-run', 'pass', _F_IGNORED + ' (closed checks schema)'),
    'unsupported-native-protocol': ('not-run', 'pass', 'C2.6 F: "An unknown native protocol version → NOT-RUN unknown"'),
    'descending-seq': ('fail', 'not-run', _F_CONTRADICTION),
    'duplicate-seq': ('fail', 'not-run', _F_CONTRADICTION),
    'menu-a-ended-before-arrival': ('fail', 'not-run', 'C2.4 step 3: "menu-end for A ... must follow the action arrival"; '
                                    'C2.4 step 10: "contradiction → FAIL"'),
    'refresh-terminal-late': ('not-run', 'fail', 'C2.6 D: "Exactly one terminal row for R within 60 s"; NOT-RUN: "no terminal"'),
    'refresh-rows-unchanged': ('fail', 'not-run', _D_FAIL_COMPLETED),
    'accepted-missing': ('not-run', 'pass', _D_NOT_RUN),
    'accepted-stale-snapshot': ('fail', 'pass', _D_FAIL_OTHER_REQUEST),
    'accepted-other-engine-request': ('fail', 'not-run', _D_FAIL_OTHER_REQUEST),
    'accepted-duplicate': ('fail', 'pass', _F_CONTRADICTION),
    'copilot-accounts-before-nonzero': ('fail', 'pass', 'C2.6 D FAIL: "copilotAccountsBefore ≠ 0"'),
    'completed-on-unrelated-projection': ('fail', 'pass', _D_FAIL_COMPLETED),
    'completed-other-reading': ('fail', 'pass', _D_FAIL_COMPLETED),
    'completed-two-accounts': ('fail', 'pass', 'C2.6 D (binding decision): copilotAccountsAfter must be 1'),
    'copilot-not-scheduled-but-completed': ('fail', 'pass', 'C2.6 D PASS needs accepted "scheduled"; ' + _F_CONTRADICTION),
    'stub-call-missing': ('fail', 'pass', _D_FAIL_COMPLETED),
    'quota-call-after-completed': ('fail', 'pass', _D_FAIL_COMPLETED),
    'call-before-requested': ('fail', 'pass', _D_FAIL_BEFORE),
    'quota-call-before-accepted': ('pass', 'fail', _D_PASS_WINDOW),
    'runtime-calls-preseeded': ('fail', 'pass', _D_FAIL_BEFORE + '; C2.6 C: "The log is absent in the seed"'),
    'runtime-calls-foreign': ('not-run', 'pass', _D_NOT_RUN),
    'runtime-calls-missing': ('not-run', 'pass', _D_NOT_RUN),
    'runtime-calls-digest-mismatch': ('not-run', 'pass', _D_NOT_RUN),
    'runtime-calls-undigested': ('not-run', 'pass', _D_NOT_RUN),
    'delayed-clear': ('fail', 'pass', _E),
    'accepted-clear-late': ('fail', 'pass', _E),
    'menu-scrubbed-late': ('fail', 'pass', _E),
}

# Every historical divergence remains a regression through the real final CLI. The ones evidence-u6 (at #332
# a1d746fc) still decides against C2.7 are expected failures: trace -> (C2.7 outcome, evidence-u6 now, contract).
DISAGREEMENTS = {
    # evidence-u6 change: an accepted whose engineRequestID differs from requested's is FAIL, not NOT-RUN.
    'accepted-stale-snapshot': ('fail', 'not-run', _D_FAIL_OTHER_REQUEST),
    'accepted-other-engine-request': ('fail', 'not-run', _D_FAIL_OTHER_REQUEST),
    # evidence-u6 change: only an account.getQuota call before requested fails; one between requested and
    # accepted counts towards PASS (window is requested < mono < completed).
    'quota-call-before-accepted': ('pass', 'fail', _D_PASS_WINDOW),
}


class EvidenceU6CLITests(unittest.TestCase):
    """The real final entry point (bin/evidence-u6.py --config --batch --package --kit-manifest) on every oracle
    trace. Both read the same batch bytes (the producers' encoding, C2.6 F); sb.kit_batch adds only the run files,
    the menu helper's result, a launched bundle, a pinned package and the kit manifest."""

    def compare(self, name, ctx, files):
        oracle = replay.replay(ctx, files)['outcome']
        evidence = evidence_u6(ctx, files)['outcome']
        self.assertEqual(evidence, oracle, '%s: evidence-u6.py disagrees with the C2.7 oracle' % name)

    def test_valid_batch(self):
        """Agrees (an expected failure at a98b25a3: legacy CLI and accepted-clear fields)."""
        self.compare('valid', sb.context(), sb.valid(closure_receipt=CLOSURE).files())

    def test_refresh_failed_batch(self):
        """Agrees: FAIL engine-error (an expected failure at a98b25a3)."""
        self.compare('refresh-failed', *build(next(c for c in CASES if c[0] == 'refresh-failed')))

    def test_closure_missing_batch(self):
        """Agrees: both report not-run when launch-cleanup.json is absent (macrev-332-5)."""
        self.compare('closure-missing', *build(next(c for c in CASES if c[0] == 'closure-missing')))

    def test_disagreement_table_is_exact(self):
        """Outside the expected failures: each tabled trace exists and both sides give exactly the tabled outcome."""
        traces = {name: (ctx, files) for name, ctx, files in differential_traces()}
        self.assertLessEqual(set(BASELINE_DISAGREEMENTS), set(traces))
        self.assertLessEqual(set(DISAGREEMENTS), set(BASELINE_DISAGREEMENTS))
        for name, (expected, old_evidence, quote) in BASELINE_DISAGREEMENTS.items():
            self.assertNotEqual(expected, old_evidence, name)
            self.assertTrue(quote.startswith(('C2.7', 'C2.6', 'C2.4')), name)
            ctx, files = traces[name]
            self.assertEqual(replay.replay(ctx, files)['outcome'], expected, name + ': independent oracle')
            # A still-open divergence pins evidence-u6's current outcome; every other one is a regression.
            current = DISAGREEMENTS[name][1] if name in DISAGREEMENTS else expected
            self.assertEqual(evidence_u6(ctx, files)['outcome'], current, name + ': real final CLI')
        for name, (oracle, evidence, quote) in DISAGREEMENTS.items():
            self.assertEqual(oracle, BASELINE_DISAGREEMENTS[name][0], name)
            self.assertNotEqual(oracle, evidence, name)

    def test_oracle_and_evidence_read_the_same_batch(self):
        """C2.6 F: the oracle reads the batch evidence-u6 reads, byte for byte (kit_batch adds run files only)."""
        files = sb.valid(closure_receipt=CLOSURE).files()
        with tempfile.TemporaryDirectory() as directory:
            sb.kit_batch(sb.context(), files, directory)
            batch = replay.read_batch(Path(directory, 'batch'))
        for name, data in files.items():
            if name != 'consent-reset.json':  # kit_batch rebases homeSHA256 to the real temporary HOME
                self.assertEqual(batch[name], data, name)
        batch['consent-reset.json'] = files['consent-reset.json']
        self.assertEqual(replay.replay(sb.context(), batch)['outcome'], 'pass')


def _differential(name, ctx, files):
    def test(self):
        self.compare(name, ctx, files)
    entry = DISAGREEMENTS.get(name)
    test.__doc__ = '%s: %s' % (name, 'agrees' if entry is None else 'evidence-u6 change required by C2.7 (%s): %s'
                                % ('%s, not %s' % entry[:2], entry[2]))
    return test if entry is None else unittest.expectedFailure(test)


for _name, _ctx, _files in differential_traces():
    setattr(EvidenceU6CLITests, 'test_differential_' + _name.replace('-', '_'), _differential(_name, _ctx, _files))


if __name__ == '__main__':
    unittest.main()
