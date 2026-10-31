# SPDX-License-Identifier: MIT
"""Authored synthetic C2.4 U6 batches for the offline replay and the receipt-schema fixtures.

The native, pointer, capture, reset and finish files are hand-authored to the C2.4 shapes (their real
producers do not emit these shapes yet; see schema/verification/README.md, "Required producer changes").
`launch-cleanup.json` is produced by the real `check_launch_cleanup.check()` against a synthetic run on a
fixed clock. Expected verdicts are never derived from the oracle under test.

    synthetic_batch.py --write <schema/verification/fixtures>   regenerate the committed batches"""
import argparse
import hashlib
import json
import struct
import subprocess
import sys
import tempfile
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


PINS = dict(mainExecutable=sha('synthetic main executable'), engine=sha('synthetic bundled engine'),
            consentHelper=sha('synthetic consent helper'))


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
        self.capture = self.reset = self.finish = self.closure = None
        self.image = png()

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
        out = {'native-observations.jsonl': jsonl(self.native), 'dock-pointer.jsonl': jsonl(self.dock),
               'status-pointer.jsonl': jsonl(self.status), 'status-pointer-clear.jsonl': jsonl(self.clear),
               CAPTURE: self.image}
        for name, value in (('dock-capture.json', self.capture), ('consent-reset.json', self.reset),
                            ('operator-finish.json', self.finish), ('launch-cleanup.json', self.closure)):
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
          sessionID=SESSION_A)
    completed = dict(phase='completed', requestId=REQUEST, rowsSequenceAfter=4, menuObjectID=MENU, sessionID=SESSION_A)
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
    t.capture = dict(schema='u6-capture/1', runID=RUN, epoch=EPOCH, pid=PID, windowNumber=WINDOW,
                     frameSeq=expanded['seq'], mono=m(11.0), at=at(m(11.0)), file=CAPTURE, sha256=sha(t.image))
    t.reset = dict(schema='consent-reset/1', runID=RUN, epoch=EPOCH, homeSHA256=sha('<scratch>/home'),
                   helperSHA256=PINS['consentHelper'], startMono=m(35.0), endMono=m(35.6), exitCode=0,
                   storeEpochAfter=STORE_EPOCH, generationAfter=GENERATION)
    t.finish = dict(schema='u6-actions/1', runID=RUN, epoch=EPOCH, mono=m(40.0), at=at(m(40.0)),
                    steps=[dict(step=n, outcome='pass', reason=None) for n in range(1, 7)])
    t.closure = closure() if closure_receipt is None else closure_receipt
    return t


BATCHES = ('valid', 'valid-interleaved')


def write(fixtures):
    """Write the committed positive batches (each with its replay context) under `fixtures/batches/`."""
    receipt = closure()
    for name in BATCHES:
        trace = valid('interleaved' if name == 'valid-interleaved' else 'main', closure_receipt=receipt)
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
