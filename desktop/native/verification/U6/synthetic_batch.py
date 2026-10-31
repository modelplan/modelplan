# SPDX-License-Identifier: MIT
"""Synthetic C2.4/C2.5 U6 batches for the offline replay and the receipt-schema fixtures.

A trace is edited as flat records and written in the encoding the producers use today (C2.5 F): native rows
in the App's envelope (`app_native_row`), pointer rows as pointer_drive writes them (`pointer_drive_row`).
Native and pointer rows are authored (Swift producers); `launch-cleanup.json` comes from the real
`check_launch_cleanup.check()`, and the committed fixtures' capture, consent-reset and finish receipts from the
shipped writers (`capture_owned`, `consent_reset`, `action_runner`) run on the trace with fakes for the screen,
helper, clock and admission. Expected verdicts are never derived from the oracle under test.

`kit_batch()` adds what `bin/evidence-u6.py` needs beyond the batch (run files prepare and launch write, the
menu helper's result, a launched bundle, a pinned package and kit manifest), so the tests run the same bytes
through both the oracle and the real final entry point.

    synthetic_batch.py --write <schema/verification/fixtures>   regenerate the committed batches"""
import argparse
import contextlib
import datetime
import io
import hashlib
import importlib.util
import json
import struct
import subprocess
import sys
import tempfile
import zipfile
import zlib
from pathlib import Path

BIN = Path(__file__).resolve().parents[1] / 'bin'
sys.path.insert(0, str(BIN))
import book  # noqa: E402
import check_launch_cleanup  # noqa: E402
import guardian  # noqa: E402

RUN, EPOCH, PID, FOREIGN_PID = 'u6-run-0001', 'u6-epoch-0001', 4242, 999
T0, MONO0, LEASE_SECONDS = 1900000000.0, 86400.0, 600
MENU = '105553116266496'
ITEM_A, ITEM_B = '105553116301312', '105553116305408'
SESSION_A, SESSION_B = '6B1F0D2A-0000-4000-8000-00000000000A', '6B1F0D2A-0000-4000-8000-00000000000B'
REQUEST, CLEAR = '6B1F0D2A-0000-4000-8000-0000000000F1', '6B1F0D2A-0000-4000-8000-0000000000C1'
STORE_EPOCH, GENERATION = '5e' * 16, 1
SEED_TITLE = 'Synthetic private title 7'
WINDOW, CAPTURE = 311, 'dock-owned.png'


def sha(data):
    return hashlib.sha256(data if isinstance(data, bytes) else data.encode()).hexdigest()


# The kit ships one `Contents/Helpers/modelplan` as both the bundled engine and the consent helper
# (U6/prepare_config.py, U6/evidence_chain.verify_bundle_members), so both pins name the same bytes.
BLOBS = {sha(text): text.encode() for text in ('synthetic main executable', 'synthetic bundled helper',
                                                'changed engine', 'changed main executable')}
PINS = dict(mainExecutable=sha('synthetic main executable'), engine=sha('synthetic bundled helper'),
            consentHelper=sha('synthetic bundled helper'))


def png():
    """A deterministic 1x1 grey PNG standing in for the owned-window capture."""
    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff)
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', 1, 1, 8, 0, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(b'\x00\x80', 9)) + chunk(b'IEND', b''))


def context(**changes):
    value = dict(schema='u6-replay-context/1', runID=RUN, epoch=EPOCH, subjectPID=PID, leaseNotBefore=T0,
                 leaseExpiresAt=T0 + LEASE_SECONDS, seedTitleSHA256=sha(SEED_TITLE),
                 homeSHA256=sha('<scratch>/home'), pins=dict(PINS), launchedPins=dict(PINS))
    value.update(changes)
    return value


def at(mono):
    return round(T0 + (mono - MONO0), 6)


def m(offset):
    return round(MONO0 + offset, 6)


def dump(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'))


def jsonl(rows):
    return ''.join(dump(r) + '\n' for r in rows).encode()


class Trace:
    """One batch as editable records. `files()` serializes it the way the producers write."""

    def __init__(self):
        self.native, self.dock, self.status, self.clear = [], [], [], []
        self.capture = self.reset = self.finish = self.closure = self.runtime = None
        self.image = png()
        self.flat = False  # True writes the flat C2.4 rows instead of the producers' encoding

    # native rows -------------------------------------------------------------------------------------
    def row(self, kind, offset, pid=PID, **fields):
        return dict(runID=RUN, epoch=EPOCH, pid=pid, seq=0, mono=m(offset), at=at(m(offset)), kind=kind, **fields)

    def add(self, kind, offset, **fields):
        row = self.row(kind, offset, **fields)
        self.native.append(row)
        return row

    def insert(self, row):
        """Insert by mono (stable) and renumber each process's sequence."""
        index = next((i for i, r in enumerate(self.native) if r['mono'] > row['mono']), len(self.native))
        self.native.insert(index, row)
        self.reseq()
        return row

    def reseq(self):
        """Each process numbers its own rows; only the subject's numbering matters to the replay."""
        seq = {}
        for row in self.native:
            seq[row['pid']] = row['seq'] = seq.get(row['pid'], 0) + 1

    def find(self, kind, **match):
        return [r for r in self.native if r['kind'] == kind and all(r.get(k) == v for k, v in match.items())]

    def one(self, kind, **match):
        rows = self.find(kind, **match)
        assert len(rows) == 1, (kind, match, len(rows))
        return rows[0]

    def remove(self, kind, **match):
        self.native = [r for r in self.native if not (r['kind'] == kind and all(r.get(k) == v for k, v in match.items()))]
        self.reseq()

    # files -------------------------------------------------------------------------------------------
    def files(self):
        native, pointer = (dict, dict) if self.flat else (app_native_row, pointer_drive_row)
        out = {'native-observations.jsonl': jsonl([native(r) for r in self.native]),
               'dock-pointer.jsonl': jsonl([pointer(r) for r in self.dock]),
               'status-pointer.jsonl': jsonl([pointer(r) for r in self.status]),
               'status-pointer-clear.jsonl': jsonl([pointer(r) for r in self.clear]), CAPTURE: self.image}
        for name, value in (('dock-capture.json', self.capture), ('consent-reset.json', self.reset),
                            ('operator-finish.json', self.finish), ('launch-cleanup.json', self.closure),
                            ('runtime-calls.json', self.runtime)):
            if value is not None:
                out[name] = (json.dumps(value, sort_keys=True) + '\n').encode()
        return out


def pointer_rows(start, click, x, y):
    """pointer_drive rows for one plan: permission, one move, an optional click, the posted result."""
    base = dict(runID=RUN, epoch=EPOCH, targetPID=PID)
    rows = [dict(base, kind='pointer-host-permission', protocol='u6-pointer/1', postEvents=True, helperPID=7001,
                 requestsPermission=False, mono=m(start - 0.05), at=at(m(start - 0.05))),
            dict(base, kind='mouse-moved-posted', step=0, x=x, y=y, tap='kCGHIDEventTap', mono=m(start), at=at(m(start)))]
    if click:
        for kind, offset in (('mouse-button-down-posted', 0.01), ('mouse-button-up-posted', 0.05)):
            rows.append(dict(base, kind=kind, step=0, x=x, y=y, button='left', clickCount=1, tap='kCGHIDEventTap',
                             mono=m(start + offset), at=at(m(start + offset))))
    rows.append(dict(base, kind='pointer-result', outcome='posted', arrivalProof='requires-correlated-native-receipts',
                     mono=m(start + 0.3), at=at(m(start + 0.3))))
    return rows


def closure(now_offset=50.0, controller=3, guardian_status=0, scenario_status=0, started_offset=1.5):
    """A launch-cleanup/1 receipt from the real checker for a closed synthetic run on a fixed clock."""
    def exited():
        child = subprocess.Popen([sys.executable, '-c', 'import sys; sys.stdin.read()'], stdin=subprocess.PIPE)
        ident = guardian.identity(child.pid)
        child.stdin.close(); child.wait()
        return ident
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        ledger_path = root / 'ledger.jsonl'
        booking = book.Ledger(ledger_path, clock=lambda: T0 - 10).request('M1', 'U6', ['u6'], LEASE_SECONDS)['id']
        lease = book.Ledger(ledger_path, clock=lambda: T0).start(booking, 'M1', RUN, EPOCH)
        batch, scratch, locks = root / 'batch', root / 'scratch', root / 'locks'
        for d in (batch, scratch, locks):
            d.mkdir()
        (root / 'lease.json').write_text(json.dumps(lease))
        c = dict(profile='synthetic', scenario='u6', argv=['synthetic-app', '--u6-drive-contract', str(scratch / 'native-guard.json')],
                 expectedLease={k: lease[k] for k in check_launch_cleanup.IDENTITY},
                 booking=dict(id=booking, lane='M1', unit='U6', scenario='u6', ledger=str(ledger_path)),
                 leasePath=str(root / 'lease.json'), stopPath=str(batch / 'stop.json'),
                 subjectPidPath=str(root / 'subject.pid'), preparedReceiptPath=str(batch / 'prepared.json'),
                 syntheticHome=str(scratch / 'home'), syntheticTmp=str(scratch / 'tmp'),
                 syntheticHomeSeed=str(scratch / 'home-seed'), batch=str(batch), scratch=str(scratch), locks=str(locks))
        Path(c['stopPath']).write_text(json.dumps(dict(runID=RUN, epoch=EPOCH, stop=True, reason='operator-finished')))
        Path(c['subjectPidPath']).write_text(json.dumps(dict(state='running', launcher=exited(), runID=RUN, epoch=EPOCH,
                                                             startedAt=T0 + started_offset, **exited())))
        Path(c['preparedReceiptPath']).write_text(json.dumps(dict(prepared=True, runID=RUN, epoch=EPOCH, attempt='token-1',
                                                                  locks=[str(locks / 'M1-candidate-gui')])))
        receipt, _ = check_launch_cleanup.check(c, controller, guardian_status, scenario_status, now=T0 + now_offset)
        return receipt


def valid(variant='main', closure_receipt=None):
    """A complete C2.4 trace. `interleaved` is the legitimate alternative ordering: menu A begins during the
    press, the Refresh terminal precedes A's end, B has no (optional) clear-caused end, B's private item is
    deallocated rather than cleared, and foreign-PID rows of the same run are interleaved (and ignored)."""
    alt = variant == 'interleaved'
    t = Trace()
    t.add('started', 2.0, protocol='u6-native/1')
    t.add('doctor', 2.2, visible=False, onScreen=False, nonActivating=False, ownerStopArmed=True)
    t.add('status-item-frame', 2.3, x=1200.0, y=1055.0, width=24.0, height=25.0, coordinateSpace='appkit-screen',
          cgX=1200.0, cgY=0.0)
    t.add('dock-surface-frame', 2.4, state='sliver', windowNumber=WINDOW, x=0.0, y=400.0, width=3.0, height=280.0,
          coordinateSpace='cg-screen')
    t.add('doctor', 5.0, visible=True, onScreen=True, nonActivating=True, ownerStopArmed=True)
    expanded = t.add('dock-surface-frame', 10.4, state='expanded', windowNumber=WINDOW, x=0.0, y=400.0, width=320.0,
                     height=280.0, coordinateSpace='cg-screen')
    begin_a = 20.03 if alt else 20.1
    t.add('menu-begin', begin_a, menuObjectID=MENU, sessionID=SESSION_A, surface='status', privateContent=True)
    t.add('menu-private-title-visible', begin_a + 0.001, menuObjectID=MENU, sessionID=SESSION_A,
          titleSHA256=sha(SEED_TITLE), privateItemIDs=[ITEM_A])
    t.add('status-menu-action-arrived', 21.0, menuObjectID=MENU, sessionID=SESSION_A, requestID=REQUEST,
          actionID='refresh', deliveryMethod='axpress-menu-item', source='NSMenu.didSendAction', scope='owned-status-menu')
    t.add('refresh', 21.05, phase='requested', requestId=REQUEST, rowsSequenceBefore=3, menuObjectID=MENU,
          sessionID=SESSION_A, dispositions=dict(DISPOSITIONS), copilotRow='absent')
    completed = dict(phase='completed', requestId=REQUEST, rowsSequenceAfter=4, menuObjectID=MENU, sessionID=SESSION_A,
                     copilotRow='present')
    if alt:
        t.add('refresh', 21.08, **completed)
        t.add('menu-end', 21.2, menuObjectID=MENU, sessionID=SESSION_A, cause='other')
    else:
        t.add('menu-end', 21.1, menuObjectID=MENU, sessionID=SESSION_A, cause='other')
        t.add('refresh', 23.0, **completed)
    t.add('status-item-frame', 23.01, x=1200.0, y=1055.0, width=24.0, height=25.0, coordinateSpace='appkit-screen',
          cgX=1200.0, cgY=0.0)
    begin_b = 30.4 if alt else 30.1
    t.add('menu-begin', begin_b, menuObjectID=MENU, sessionID=SESSION_B, surface='status', privateContent=True)
    t.add('menu-private-title-visible', begin_b + 0.001, menuObjectID=MENU, sessionID=SESSION_B,
          titleSHA256=sha(SEED_TITLE), privateItemIDs=[ITEM_B])
    t.add('clear-initiated', 35.3, clearID=CLEAR, storeEpochAfter=STORE_EPOCH, generationAfter=GENERATION,
          openSessionIDs=[SESSION_B])
    if not alt:
        t.add('menu-end', 35.32, menuObjectID=MENU, sessionID=SESSION_B, cause='clear', clearID=CLEAR)
    t.add('accepted-clear', 35.35, clearID=CLEAR, storeEpochAfter=STORE_EPOCH, generationAfter=GENERATION,
          scrubbedSessionIDs=[SESSION_B], priorPrivateContent=True, trackingClosed=not alt)
    t.add('menu-scrubbed', 35.36, clearID=CLEAR, sessionID=SESSION_B, menuObjectID=MENU, privateTitlePresent=False,
          privateAttributeCount=0, itemStates=[dict(id=ITEM_B, state='deallocated' if alt else 'cleared')])
    t.add('doctor', 36.0, visible=True, onScreen=True, nonActivating=True, ownerStopArmed=True)
    t.add('stop-or-lease-expired', 40.5)
    t.add('terminate-completed', 40.7)
    if alt:  # same run/epoch, another process: never evidence, never a contradiction
        t.insert(t.row('menu-begin', 30.2, pid=FOREIGN_PID, menuObjectID=MENU,
                                  sessionID='6B1F0D2A-0000-4000-8000-0000000000EE', surface='status', privateContent=True))
        t.insert(t.row('menu-private-title-visible', 36.5, pid=FOREIGN_PID, menuObjectID=MENU,
                                  sessionID=SESSION_B, titleSHA256=sha(SEED_TITLE), privateItemIDs=[ITEM_B]))
    t.reseq()
    t.dock = pointer_rows(10.0, False, 1.5, 540.0)
    t.status = pointer_rows(20.0, True, 1212.0, 12.5)
    t.clear = pointer_rows(30.0, True, 1212.0, 12.5)
    # Field sets of the shipped writers: U6/capture_owned.py, U6/consent_reset.py, U6/action_runner.py.
    t.capture = dict(schema='u6-capture/1', runID=RUN, epoch=EPOCH, pid=PID, windowNumber=WINDOW,
                     frameSeq=expanded['seq'], mono=m(11.0), file=CAPTURE, sha256=sha(t.image))
    t.reset = dict(schema='consent-reset/1', runID=RUN, epoch=EPOCH, targetPID=PID, menuObjectID=MENU,
                   sessionID=SESSION_B, operation='consent-reset-confirmed', homeSHA256=sha('<scratch>/home'),
                   helperSHA256=PINS['consentHelper'], startMono=m(35.0), endMono=m(35.6), exitCode=0,
                   storeEpochAfter=STORE_EPOCH, generationAfter=GENERATION, outcome='success', reason=None)
    t.finish = dict(schema='u6-actions/1', runID=RUN, epoch=EPOCH, pid=PID, mono=m(40.0),
                    steps={name: 'pass' for name in ACTION_STEPS}, outcome='pass', reason=None)
    t.closure = closure() if closure_receipt is None else closure_receipt
    t.runtime = runtime_calls(['connect', 'auth.getStatus', 'account.getQuota'])
    return t


def runtime_calls(calls):
    """Drive's run-bound copy of the stub's `$HOME/runtime-calls` log (C2.5 D)."""
    raw = ''.join(c + '\n' for c in calls)
    return dict(schema='u6-runtime-calls/1', runID=RUN, epoch=EPOCH, sourceSHA256=sha(raw), calls=list(calls))


BATCHES = ('valid', 'valid-interleaved')
DISPOSITIONS = {'copilot.runtime_usage': 'scheduled', 'claude.account_usage.saved_login': 'read_only'}
ACTION_STEPS = ('dock', 'menuA', 'refresh', 'menuB', 'privateTitle', 'trackedClear')


# producer encodings (C2.5 F) ---------------------------------------------------------------------------
KIT_HEAD, KIT_APP, KIT_BINARY = 'a' * 40, 'ModelPlan.app', 'ModelPlanCommunityApp'
KIT_SEED = sha('synthetic home seed tree')
_ENVELOPE = ('runID', 'epoch', 'pid', 'seq', 'mono', 'at')
_POINTER_ACTION = {'mouse-moved-posted': 'move', 'mouse-button-down-posted': 'click', 'mouse-button-up-posted': 'click'}


def app_native_row(row):
    """A flat row as U6DriveGuard.emitObject writes it: `refresh` flat, every other kind as {envelope, event,
    timestamp, checks: {fields}} plus the guard's extra identity fields (instanceID, subjectPID, menuInstanceID,
    nativeUptimeSeconds)."""
    if row.get('kind') == 'refresh':
        return dict(row)
    kind = row.get('kind')
    fields = {k: v for k, v in row.items() if k not in _ENVELOPE + ('kind',)}
    if kind in ('menu-begin', 'menu-end', 'menu-private-title-visible') and 'menuObjectID' in fields:
        fields['instanceID'] = fields['menuObjectID']
    if kind == 'menu-begin':
        fields['subjectPID'] = row.get('pid')
    if kind == 'status-menu-action-arrived':  # MenuContract fields plus the guard's menuInstanceID
        fields.update(subjectPID=row.get('pid'), menuInstanceID=fields.get('menuObjectID'),
                      nativeUptimeSeconds=row.get('mono'))
    out = {k: row[k] for k in _ENVELOPE if k in row}
    out.update(event=kind, timestamp=row.get('at'), checks=fields)
    return out


def _iso(at):
    return datetime.datetime.fromtimestamp(int(at), datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')


def pointer_drive_row(row):
    """A flat pointer row as pointer_drive writes it: `event` names the row, `kind` is move/click, plus its
    subjectPID, uptimeSeconds and ISO timestamp; the permission row carries no run binding."""
    out = {k: v for k, v in row.items() if k != 'kind'}
    out['event'] = row.get('kind')
    if row.get('kind') in _POINTER_ACTION:
        out.update(kind=_POINTER_ACTION[row['kind']], subjectPID=row.get('targetPID'), uptimeSeconds=row.get('mono'),
                   timestamp=_iso(row['at']))
    elif row.get('kind') == 'pointer-host-permission':
        out = dict(event=row['kind'], postEvents=row['postEvents'], helperPID=row['helperPID'],
                   requestsPermission=row['requestsPermission'], timestamp=_iso(row['at']))
    return out


def kit_batch(ctx, files, root):
    """Write one oracle batch (`ctx`, `files`, unchanged bytes) under `root` and return the `evidence-u6.py`
    arguments. Run-level inputs the oracle takes from `ctx` become the files the head's
    prepare/launch write: subject registration, launch.json, prepared.json, synthetic-seed.json, the three
    pointer plans and run.json; the pins become a launched bundle, a pinned package and a kit manifest. Nothing
    here decides a verdict."""
    root = Path(root)
    pins, launched = ctx['pins'], ctx['launchedPins']
    assert pins['engine'] == pins['consentHelper'], 'one bundled helper in the kit'
    run, epoch, pid = ctx['runID'], ctx['epoch'], ctx['subjectPID']
    batch, scratch = root / 'batch', root / 'scratch'
    contents = root / 'launched' / KIT_APP / 'Contents'
    binary, helper = contents / 'MacOS' / KIT_BINARY, contents / 'Helpers' / 'modelplan'
    for directory in (batch, scratch / 'home', binary.parent, helper.parent, root / 'kit'):
        directory.mkdir(parents=True)
    binary.write_bytes(BLOBS[launched['mainExecutable']])
    helper.write_bytes(BLOBS[launched['engine'] if launched['engine'] != pins['engine'] else launched['consentHelper']])
    package = root / 'kit' / 'ModelPlan-U6.zip'
    with zipfile.ZipFile(package, 'w') as archive:
        archive.writestr(KIT_APP + '/Contents/MacOS/' + KIT_BINARY, BLOBS[pins['mainExecutable']])
        archive.writestr(KIT_APP + '/Contents/Helpers/modelplan', BLOBS[pins['consentHelper']])
    package_sha = sha(package.read_bytes())
    members = dict(main=('Contents/MacOS/' + KIT_BINARY, pins['mainExecutable']),
                   engine=('Contents/Helpers/modelplan', pins['engine']),
                   consentHelper=('Contents/Helpers/modelplan', pins['consentHelper']))
    manifest = dict(sourceHead=KIT_HEAD, binarySHA256=pins['mainExecutable'], helperSHA256=pins['consentHelper'],
                    packageSHA256=package_sha,
                    bundleMembers={k: dict(path=path, sha256=digest) for k, (path, digest) in members.items()})
    home = scratch / 'home'
    config = dict(scenario='u6', profile='synthetic', head=KIT_HEAD, batch=str(batch), scratch=str(scratch),
                  argv=[str(binary), '--u6-drive-contract', str(scratch / 'native-guard.json')],
                  binarySHA256=pins['mainExecutable'], helperSHA256=pins['consentHelper'], packageSHA256=package_sha,
                  syntheticHome=str(home), syntheticTmp=str(scratch / 'tmp'), syntheticHomeSeedSHA256=KIT_SEED,
                  subjectPidPath=str(root / 'subject.json'), stopPath=str(batch / 'stop.json'),
                  expectedLease=dict(runID=run, epoch=epoch, notBefore=ctx['leaseNotBefore'],
                                     expiresAt=ctx['leaseExpiresAt']))
    put = lambda path, value: Path(path).write_text(json.dumps(value, sort_keys=True) + '\n')  # noqa: E731
    put(root / 'run.json', config)
    put(root / 'kit-manifest.json', manifest)
    put(config['subjectPidPath'], dict(pid=pid, runID=run, epoch=epoch, state='running'))
    put(batch / 'launch.json', dict(ownedPID=pid, runID=run, epoch=epoch, sourceHead=KIT_HEAD))
    put(batch / 'prepared.json', dict(prepared=True, runID=run, epoch=epoch, homeSeedSHA256=KIT_SEED))
    put(batch / 'synthetic-seed.json', dict(schema='u6-seed/1', runID=run, epoch=epoch, homeSeedSHA256=KIT_SEED,
                                            titleSHA256=ctx['seedTitleSHA256'], profileSHA256=sha('synthetic profile')))
    for stem in ('dock-pointer', 'status-pointer', 'status-pointer-clear'):
        put(batch / (stem + '-plan.json'), dict(profile='synthetic', runID=run, epoch=epoch, subjectPID=pid,
                                                targetPID=pid, output=str(batch / (stem + '.jsonl'))))
    arrivals = []
    for name, data in files.items():
        if name == 'native-observations.jsonl':  # the same bytes the oracle reads
            for line in data.decode('utf-8', 'replace').splitlines():
                try:
                    row = json.loads(line)
                except ValueError:
                    continue
                checks = row.get('checks') if isinstance(row.get('checks'), dict) else {}
                if (row.get('event') == 'status-menu-action-arrived' and (row.get('runID'), row.get('epoch'),
                        row.get('pid')) == (run, epoch, pid) and checks.get('actionID') == 'refresh'):
                    arrivals.append(checks.get('requestID'))
        elif name == 'consent-reset.json':
            try:
                value = json.loads(data)
            except ValueError:
                value = None
            if isinstance(value, dict) and value.get('homeSHA256') == ctx['homeSHA256']:
                value['homeSHA256'] = sha(str(home.resolve()))  # the head hashes the resolved HOME path
                data = (json.dumps(value, sort_keys=True) + '\n').encode()
        (batch / name).write_bytes(data)
    # status_menu_drive's arrival result for the first native Refresh arrival it observed
    (batch / 'menu-drive.jsonl').write_bytes(jsonl(
        [dict(event='status-menu-result', outcome='arrived', runID=run, epoch=epoch, subjectPID=pid,
              requestID=arrivals[0], actionID='refresh', arrivalProof='native-NSMenu.didSendAction')]
        if arrivals else []))
    return ['--config', str(root / 'run.json'), '--batch', str(batch), '--package', str(package),
            '--kit-manifest', str(root / 'kit-manifest.json')]


def _module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def shipped_receipts(trace):
    """(capture, reset, finish) as the shipped writers produce them for `trace`: capture_owned.capture,
    consent_reset.reset and action_runner.finish run on a batch holding the native rows written up to that
    moment, with fakes only for admission/subject identity, screencapture, the helper process and the uptime
    clock. The reset receipt's homeSHA256 (of the temporary HOME path) is rebased to the context's HOME hash."""
    u6 = Path(__file__).resolve().parent
    capture, reset, actions = (_module('u6_capture_fixture', u6 / 'capture_owned.py'),
                               _module('u6_reset_fixture', u6 / 'consent_reset.py'),
                               _module('u6_actions_fixture', u6 / 'action_runner.py'))
    original = guardian.cleanup.matches
    for module in (capture, reset):  # admission and subject identity are the launch's, not the writer's
        module.load_and_admit = module.still_admitted = lambda *_: True
        module.identity = lambda _: dict(pid=PID)
        module.launcher_lost = lambda _: False
    guardian.cleanup.matches = lambda *_: True
    try:
        with tempfile.TemporaryDirectory() as directory, contextlib.redirect_stdout(io.StringIO()):
            root = Path(directory)
            batch, scratch = root / 'batch', root / 'scratch'
            contents = root / 'Test.app' / 'Contents'
            for d in (batch, scratch / 'home', scratch / 'tmp', contents / 'MacOS', contents / 'Helpers'):
                d.mkdir(parents=True)
            (contents / 'MacOS' / 'App').write_bytes(BLOBS[PINS['mainExecutable']])
            (contents / 'Helpers' / 'modelplan').write_bytes(BLOBS[PINS['consentHelper']])
            (root / 'subject.json').write_text(json.dumps(dict(pid=PID, runID=RUN, epoch=EPOCH, state='running')))
            config = dict(batch=str(batch), scratch=str(scratch), syntheticHome=str(scratch / 'home'),
                          syntheticTmp=str(scratch / 'tmp'), subjectPidPath=str(root / 'subject.json'),
                          argv=[str(contents / 'MacOS' / 'App')], helperSHA256=PINS['consentHelper'],
                          expectedLease=dict(runID=RUN, epoch=EPOCH))
            native = batch / 'native-observations.jsonl'

            def rows_until(mono):
                native.write_bytes(jsonl([app_native_row(r) for r in trace.native if r['mono'] < mono]))

            def screencapture(command, **_):
                Path(command[4]).write_bytes(trace.image)
                return type('Done', (), {'returncode': 0})()
            rows_until(trace.capture['mono'])
            capture.capture(config, run_capture=screencapture, now=lambda: trace.capture['mono'])
            rows_until(trace.reset['startMono'])
            ticks = iter((trace.reset['startMono'], trace.reset['endMono']))
            helper_output = json.dumps(dict(storeEpoch=STORE_EPOCH, generation=GENERATION))
            reset.reset(config, run_helper=lambda *_, **__: type('Done', (), {'returncode': 0, 'stdout': helper_output})(),
                        now=lambda: next(ticks))
            actions.uptime = lambda: trace.finish['mono']
            actions.finish(batch, RUN, EPOCH, PID, {name: 'pass' for name in ACTION_STEPS}, None)
            out = [json.loads((batch / name).read_text())
                   for name in ('dock-capture.json', 'consent-reset.json', 'operator-finish.json')]
    finally:
        guardian.cleanup.matches = original
    out[1]['homeSHA256'] = trace.reset['homeSHA256']
    return tuple(out)


def write(fixtures):
    """Write the committed positive batches (each with its replay context) under `fixtures/batches/`."""
    receipt = closure()
    for name in BATCHES:
        trace = valid('interleaved' if name == 'valid-interleaved' else 'main', closure_receipt=receipt)
        trace.capture, trace.reset, trace.finish = shipped_receipts(trace)
        directory = Path(fixtures) / 'batches' / name
        directory.mkdir(parents=True, exist_ok=True)
        files = dict(trace.files(), **{'context.json': (json.dumps(context(), indent=2, sort_keys=True) + '\n').encode()})
        for stale in directory.iterdir():
            if stale.name not in files:
                stale.unlink()
        for file, data in files.items():
            (directory / file).write_bytes(data)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--write', type=Path, required=True)
    write(parser.parse_args().write)
