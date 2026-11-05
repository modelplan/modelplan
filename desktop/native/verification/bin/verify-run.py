# SPDX-License-Identifier: MIT
"""One scripted GUI verification run (verification plan v2, section 5). Lanes run it; they do not interpret it.

    python3 desktop/native/verification/bin/verify-run.py --batch <manifest.json> --lane V1|M1 \
      --layout single|abc --scenarios <IDs or @file> --out <exchange>/batch-NNN/<lane> \
      --artifacts-dir <dir> --scratch-parent <local dir>

Sequence: preflight (any failure stops before booking), then one segment per launch: book, start, prepare,
guardian, release with the manifest's coordinator GO, packaged_candidate run, each ID's step file, restore
the system settings it changed, stop, closure, `book.py finish --cleaned` only on confirmed closure. Then
results.txt and README.md. The run never asks a question: a missing precondition makes that ID
`NOT-RUN reason=...` and the run goes on. It stops only on the stop list (system dialog, account data in a
synthetic run, guardian stop, unconfirmed closure). The contract is in VERIFY-RUN.md.
"""
import argparse
import json
import math
import os
from pathlib import Path
import pwd
import re
import secrets
import shutil
import subprocess
import sys
import time

BIN = Path(__file__).resolve().parent
sys.path.insert(0, str(BIN))
import preflight  # noqa: E402
import verify_steps  # noqa: E402

SEGMENT_SECONDS = 1200
SEGMENT_OVERHEAD = 180  # start, guardian, release, launch, cleanup reserve
OUTCOMES = ('PASS', 'FAIL', 'REVIEW', 'NOT-RUN')
ISOLATION_SYNTHETIC = (
    "Synthetic HOME and CFFIXED_USER_HOME under run scratch; no consent grant exists, so no personal reader "
    "starts; no Keychain, credential or owner profile is read; network to providers is not used. The run never "
    "clicks consent, Keychain, password, TCC or Gatekeeper dialogs (I-01/I-05/S-12/S-13 only in an owner-approved "
    "run). Any system dialog: record its title as text, do not image it, mark the scenario NOT-RUN and stop the "
    "segment. Any real account name, email or quota on screen: stop, delete that segment's images, report.")
ISOLATION_REAL = (
    "Real-account run (owner decision 2026-11-05): the test Mac's own HOME and accounts are used (real Codex; "
    "ZCode shows detected-only in v1), on the M1 or V1 host only. ModelPlan's own consent may be granted and "
    "macOS Keychain prompts for ModelPlan may be accepted; no other dialog is clicked (TCC, Gatekeeper, password "
    "or another app's prompt). Any other system dialog: record its title as text, do not image it, mark the "
    "scenario NOT-RUN and stop the segment. Images and receipts may show real account names, emails and quotas: "
    "this evidence stays on the shared disk only and must never be attached to or quoted in public PRs.")
PRIVATE_EVIDENCE = ("PRIVATE EVIDENCE: real-account images and receipts. Keep them on the shared disk only; "
                    "never attach them to or quote them in public PRs, issues or comments.")
DIALOG_OWNERS = {'SecurityAgent', 'UserNotificationCenter', 'CoreServicesUIAgent', 'universalAccessAuthWarn',
                 'System Settings', 'System Preferences', 'coreautha', 'Installer', 'Keychain Access'}
KEYCHAIN_OWNERS = {'SecurityAgent'}  # a real-account run may meet ModelPlan's own Keychain prompt
EMAIL = re.compile(r'[\w.+-]+@[\w-]+\.[\w.-]+')


class NotRun(Exception):
    """This ID cannot run here; the reason goes into results.txt."""


class StopRun(Exception):
    """Stop list: end the segment and the run. `isolation` marks an ISOLATION FAIL."""

    def __init__(self, reason, isolation=False):
        super().__init__(reason)
        self.isolation = isolation


def slug(text):
    return re.sub(r'\s+', '-', str(text).strip())[:200] or '-'


def plan_segments(ids, steps, flavours):
    """Group by flavour (manifest order), one launch per segment: a `fresh` ID opens a new segment and runs
    first; `running` IDs fill segments up to 1200 s including the fixed overhead."""
    segments = []
    for flavour in flavours:
        mine = [i for i in ids if i in steps and flavour in steps[i]['flavours']
                and not any(i in s['ids'] for s in segments)]
        fresh = [i for i in mine if steps[i]['launch'] == 'fresh']
        running = [i for i in mine if steps[i]['launch'] == 'running']
        current = []
        def flush():
            if current:
                segments.append(dict(flavour=flavour, ids=list(current)))
                current.clear()
        for ident in fresh:
            flush(); current.append(ident)
            while running and seconds(current + running[:1], steps) <= SEGMENT_SECONDS:
                current.append(running.pop(0))
        flush()
        for ident in running:
            if current and seconds(current + [ident], steps) > SEGMENT_SECONDS:
                flush()
            current.append(ident)
        flush()
    return segments


def seconds(ids, steps):
    return SEGMENT_OVERHEAD + sum(steps[i]['estimatedSeconds'] for i in ids)


class Actions:
    """Real step actions on macOS. Each returns a step record or raises NotRun / StopRun."""

    def __init__(self, ctx):
        self.ctx = ctx
        self.probe = None

    def ensure_probe(self):
        if self.probe is None:
            source = BIN.parents[3] / 'tools' / 'u14' / 'macos_ax.swift'
            target = Path(self.ctx['tools']) / 'macos-ax'
            if not target.exists():
                result = subprocess.run(['xcrun', 'swiftc', '-parse-as-library', str(source), '-o', str(target)],
                                        capture_output=True, timeout=300)
                if result.returncode != 0:
                    raise NotRun('ax-probe-build-failed')
            self.probe = target
        return self.probe

    def capture(self, subject, directory, wait):
        probe = self.ensure_probe()
        directory.mkdir(parents=True, exist_ok=False)
        env = dict(PATH='/usr/bin:/bin', HOME=subject.get('home') or os.environ.get('HOME', ''))
        subprocess.run([str(probe), str(subject['pid']), str(subject['bundle']), str(directory), str(max(1, wait))],
                       env=env, capture_output=True, timeout=wait + 60)
        try:
            return json.loads((directory / 'report.json').read_text())
        except (OSError, ValueError):
            raise NotRun('ax-probe-no-report')

    def menubar(self, rect, png):
        x, y, w, h = rect
        result = subprocess.run(['/usr/sbin/screencapture', '-x', f'-R{x},{y},{w},{h}', str(png)],
                                capture_output=True, timeout=30)
        if result.returncode != 0 or not png.exists():
            raise NotRun('menubar-capture-failed')

    def dialogs(self):
        probe = r"""ObjC.import('CoreGraphics'); var a = ObjC.castRefToObject($.CGWindowListCopyWindowInfo(1, 0));
var out = []; for (var i = 0; i < a.count; i++) { var w = a.objectAtIndex(i);
var n = w.objectForKey('kCGWindowName'); out.push({owner: ObjC.unwrap(w.objectForKey('kCGWindowOwnerName')),
title: n.isNil() ? null : ObjC.unwrap(n)}); } JSON.stringify(out);"""
        result = subprocess.run(['/usr/bin/osascript', '-l', 'JavaScript', '-e', probe],
                                capture_output=True, text=True, timeout=30)
        if result.returncode != 0:
            raise StopRun('dialog-watch-unavailable')
        return [w for w in json.loads(result.stdout) if w.get('owner') in DIALOG_OWNERS]

    def set_appearance(self, value):
        # Needs a one-time Automation grant for System Events on the test Mac; without the lane's recorded
        # grant the switch would raise a TCC prompt, which this run never clicks.
        if os.environ.get('MODELPLAN_VERIFICATION_APPEARANCE_SWITCH') != 'granted':
            raise NotRun('appearance-switch-not-granted-on-this-host')
        script = ("Application('System Events').appearancePreferences.darkMode = " + ('true' if value == 'dark' else 'false'))
        if subprocess.run(['/usr/bin/osascript', '-l', 'JavaScript', '-e', script], capture_output=True,
                          timeout=30).returncode != 0:
            raise NotRun('appearance-switch-failed')

    def status_menu(self, subject, item, action, directory):
        if action not in verify_steps.STATUS_MENU_ACTIONS:
            raise NotRun(f'status-menu-action-{action}-has-no-arrival-receipt')
        # The fixed actions need pointer_drive --status-menu-plan plus the in-app arrival observer, which only a
        # test build compiled with MODELPLAN_TEST_ONLY_SPI carries (StatusMenu/README.md). Not wired here yet.
        raise NotRun('status-menu-drive-not-wired')

    def relaunch(self, subject):
        raise NotRun('relaunch-with-the-same-home-not-supported-by-packaged_candidate')

    def sleep(self, value):
        time.sleep(value)

    def clock(self):
        return time.time()


def release_arguments(ctx):
    """The release authority differs by host role: MacCI (V1) releases on the coordinator GO
    comment; the dev Mac (M1) releases only on M1's own approval comment (release.py refuses a
    coordinator GO there). Both are https URLs the lane verified before releasing."""
    if ctx.get('host') == 'macci':
        return ['--coordinator-go', str(ctx.get('go') or '')]
    return ['--approval', str(ctx.get('approval') or '')]


class Session:
    """One booked, guardian-supervised launch of the prepared candidate (SKILL.md section 1 sequence)."""

    def __init__(self, ctx, segment, index):
        self.ctx, self.segment, self.index = ctx, segment, index
        self.procs = {}
        self.booking = None

    def tool(self, name, *args, capture=True):
        result = subprocess.run([sys.executable, str(BIN / name), *args], capture_output=capture, text=True, timeout=120)
        if result.returncode != 0:
            raise NotRun(f'{name}-refused')
        return json.loads(result.stdout) if capture and result.stdout.strip() else None

    def open(self):
        ctx = self.ctx
        if ctx['profile'] != 'synthetic':
            # The shared launch helpers (admission, launch.py, packaged_candidate) admit only profile synthetic.
            raise NotRun('real-profile-launch-not-supported-by-shared-helpers')
        lane, minutes = ctx['lane'], min(20, math.ceil(seconds(self.segment['ids'], ctx['steps']) / 60))
        local = Path(ctx['scratchParent']) / f'verify-{ctx["batch"]}-{self.index:02d}-{secrets.token_hex(4)}'
        local.mkdir()
        self.local = local
        request = self.tool('book.py', 'request', '--lane', lane, '--unit', ctx['batch'],
                            *[x for i in self.segment['ids'] for x in ('--scenario', i)], '--minutes', str(minutes))
        self.booking = request['id']
        head = (self.tool('book.py', 'status').get('head') or {})
        if head.get('id') != self.booking:
            self.tool('book.py', 'withdraw', '--id', self.booking, '--lane', lane, '--reason', 'verify-run not at head')
            self.booking = None
            raise NotRun('booking-not-at-head')
        self.run_id, self.epoch = f'{ctx["batch"]}-s{self.index:02d}', secrets.token_hex(8)
        lease = self.tool('book.py', 'start', '--id', self.booking, '--lane', lane, '--run-id', self.run_id,
                          '--epoch', self.epoch)
        self.started = True
        paths = {k: str(local / v) for k, v in (('leasePath', 'lease.json'), ('releasePath', 'release.json'),
                 ('stopPath', 'STOP'), ('subjectPidPath', 'subject.json'), ('candidateCleanupReceipt', 'cleanup.json'))}
        Path(paths['leasePath']).write_text(json.dumps(lease))
        archive = Path(ctx['work']) / self.segment['flavour'] / preflight.INNER
        digest = preflight.sha256_file(archive)
        (local / 'pin.json').write_text(json.dumps(dict(sourceSHA=ctx['sha'], sha256=digest)))
        template = dict(profile='synthetic', host=ctx['host'], launchMode='direct', requiredSeconds=60,
                        expectedLease={k: lease[k] for k in ('runID', 'epoch', 'notBefore', 'expiresAt')},
                        booking=dict(id=self.booking, lane=lane, unit=ctx['batch'], scenario=self.segment['ids'][0]),
                        **paths)
        (local / 'template.json').write_text(json.dumps(template))
        parent = local / 'candidate'; parent.mkdir()
        self.paths, self.registry = paths, local / 'registry.json'
        self.tool('packaged_candidate.py', 'prepare', '--archive', str(archive), '--manifest', str(local / 'pin.json'),
                  '--template', str(local / 'template.json'), '--scratch-parent', str(parent), '--registry', str(self.registry))
        self.procs['guardian'] = subprocess.Popen(
            [sys.executable, str(BIN / 'guardian.py'), '--lease', paths['leasePath'], '--stop', paths['stopPath'],
             '--subject-pid-file', paths['subjectPidPath'], '--candidate-registry', str(self.registry),
             '--candidate-parent', str(parent), '--candidate-cleanup-receipt', paths['candidateCleanupReceipt']],
            stdout=(local / 'guardian.out').open('w'), stderr=subprocess.DEVNULL)
        deadline = time.time() + 5
        while json.loads(Path(paths['leasePath']).read_text()).get('guardian') is not True:
            if time.time() > deadline:
                raise StopRun('guardian-did-not-start')
            time.sleep(0.2)
        self.tool('release.py', '--lane', lane, '--host', ctx['host'], '--id', self.booking, '--lease',
                  paths['leasePath'], *release_arguments(ctx), '--output', paths['releasePath'])
        self.procs['run'] = subprocess.Popen(
            [sys.executable, str(BIN / 'packaged_candidate.py'), 'run', '--registry', str(self.registry),
             '--receipt', str(local / 'candidate-receipt.json')],
            stdout=(local / 'launch.out').open('w'), stderr=subprocess.DEVNULL)
        deadline = time.time() + 30
        while time.time() < deadline:
            try:
                record = json.loads(Path(paths['subjectPidPath']).read_text())
                lines = [json.loads(x) for x in (local / 'launch.out').read_text().splitlines() if x.startswith('{')]
                started = next((x for x in lines if 'ownedPID' in x and 'bundle' in x), None)
                if record.get('state') == 'running' and started:
                    home = json.loads(self.registry.read_text())['registry']['root'] + '/home'
                    return dict(pid=record['pid'], bundle=started['bundle'], home=home, registeredAt=time.time())
            except (OSError, ValueError, KeyError):
                pass
            if self.procs['run'].poll() is not None:
                break
            time.sleep(0.2)
        raise StopRun('subject-never-registered')

    def close(self):
        """Stop, wait for both supervisors, finish only on confirmed closure. Returns a closure record."""
        if not self.procs:
            if getattr(self, 'started', False):  # booked and started, but no guardian ever ran: cannot attest closure
                return dict(cleaned=False, detail='booking started before any launch; coordinator to finish or expire it')
            return dict(cleaned=True, detail='nothing launched')
        from guardian import stop
        stop(Path(self.paths['stopPath']), 'verify-run-segment-ended', time.time())
        codes = {}
        for name in ('run', 'guardian'):
            if name not in self.procs:
                continue
            try:
                codes[name] = self.procs[name].wait(timeout=90)
            except subprocess.TimeoutExpired:
                codes[name] = None
        try:
            guardian = json.loads((self.local / 'guardian.out').read_text().strip().splitlines()[-1])
        except (OSError, ValueError, IndexError):
            guardian = {}
        cleaned = codes.get('guardian') == 0 and codes.get('run') in (0, 3) and guardian.get('candidateCleaned') is True
        if cleaned:
            self.tool('book.py', 'finish', '--id', self.booking, '--lane', self.ctx['lane'], '--run-id', self.run_id,
                      '--epoch', self.epoch, '--cleaned')
        return dict(cleaned=cleaned, detail=f'run={codes.get("run")} guardian={codes.get("guardian")} '
                    f'subject={guardian.get("subject")}', booking=self.booking)


def account_markers():
    """Strings that must never appear in a synthetic run's AX text: this host user's names and any email."""
    entry = pwd.getpwuid(os.getuid())
    names = {entry.pw_name, entry.pw_gecos.split(',')[0].strip()}
    return {n for n in names if len(n) >= 4}


def ax_strings(node):
    if isinstance(node, dict):
        for key, value in node.items():
            if isinstance(value, str) and key.startswith('AX'):
                yield value
            elif isinstance(value, (dict, list)):
                yield from ax_strings(value)
    elif isinstance(node, list):
        for item in node:
            yield from ax_strings(item)


def run_id(ident, step, segment, subject, ctx, actions, out):
    """Execute one ID's steps. Returns (outcome, reason, receipt)."""
    folder = out / ident
    folder.mkdir(exist_ok=True)
    records, outcome, reason, changed = [], 'PASS', None, []
    try:
        before = []  # any dialog on screen counts, including one that was already open
        for number, item in enumerate(step['steps'], 1):
            label = f'{number:02d}-{item["name"]}'
            record = dict(step=label, action=item['action'], startedAt=actions.clock())
            records.append(record)
            kind = item['action']
            if kind in ('wait-window', 'expect-no-window', 'capture-window'):
                wait = int(math.ceil(item.get('timeoutSeconds', 5)))
                report = actions.capture(subject, folder / (label + '.probe'), wait)
                windows = (report.get('ax') or {}).get('outcome') == 'pass'
                shot = report.get('screenshot') or {}
                png = folder / (label + '.probe') / 'window.png'
                if png.exists():
                    png.replace(folder / (label + '.png')); record['png'] = label + '.png'
                tree = folder / (label + '.probe') / 'ax-tree.json'
                if ctx['profile'] == 'synthetic' and tree.exists():
                    text = '\n'.join(ax_strings(json.loads(tree.read_text())))
                    if EMAIL.search(text) or any(re.search(r'\b' + re.escape(m) + r'\b', text) for m in ctx['markers']):
                        raise StopRun('account-data-on-screen', isolation=True)
                record.update(ax=(report.get('ax') or {}).get('outcome'), screenshot=shot.get('outcome'))
                elapsed = actions.clock() - subject['registeredAt']
                if kind == 'wait-window':
                    record['elapsedSinceRegistration'] = round(elapsed, 3)
                    if not windows:
                        outcome, reason = 'FAIL', f'{label}-no-owned-window'
                    elif 'budgetSeconds' in item and elapsed > item['budgetSeconds']:
                        outcome, reason = 'REVIEW', f'{label}-observed-after-{elapsed:.1f}s-including-probe'
                elif kind == 'expect-no-window' and windows:
                    outcome, reason = 'FAIL', f'{label}-window-still-shown'
                elif kind == 'capture-window':
                    if not png.exists() and not (folder / (label + '.png')).exists():
                        raise NotRun(f'{label}-no-window-image-{shot.get("reason", "unknown")}')
                    outcome = 'REVIEW' if outcome == 'PASS' else outcome
            elif kind == 'capture-menubar':
                main = next(d for d in ctx['displays'] if d.get('main'))
                rect = (int(main['width'] - item['width']), 0, item['width'], item['height'])
                actions.menubar(rect, folder / (label + '.png'))
                record.update(png=label + '.png', region=list(rect))
                outcome = 'REVIEW' if outcome == 'PASS' else outcome
            elif kind == 'set-appearance':
                changed.append(('appearance', ctx['baseline'].get('appearance', 'light')))
                actions.set_appearance(item['value'])
            elif kind == 'status-menu':
                actions.status_menu(subject, item['item'], item['menuAction'], folder / label)
            elif kind == 'relaunch':
                actions.relaunch(subject)
            elif kind == 'dwell':
                actions.sleep(item['seconds'])
            after = actions.dialogs()
            fresh = [d for d in after if d not in before]
            if fresh:
                titles = '; '.join(f'{d.get("owner")}: {d.get("title") or "(untitled)"}' for d in fresh)
                record['dialogs'] = titles
                if ctx['profile'] == 'real' and all(d.get('owner') in KEYCHAIN_OWNERS for d in fresh):
                    raise NotRun('keychain-prompt-open-grant-it-during-host-setup')
                raise StopRun('system-dialog: ' + titles, isolation=ctx['profile'] == 'synthetic')
            if outcome == 'FAIL':
                break
    except NotRun as error:
        outcome, reason = 'NOT-RUN', str(error)
    except StopRun as error:
        if error.isolation:
            purge_captures(folder)
        restore(changed, actions, records)
        write_receipt(folder, ident, ctx, segment, records, 'NOT-RUN', str(error))
        raise
    restore(changed, actions, records)
    write_receipt(folder, ident, ctx, segment, records, outcome, reason)
    return outcome, reason


def purge_captures(folder):
    """An isolation stop deletes everything this ID captured — images, AX trees, probe reports,
    plans and drive outputs — not only the PNGs: account data was found in one of them. Only the
    receipt, written afterwards, survives."""
    for path in sorted(folder.iterdir()):
        if path.is_dir():
            shutil.rmtree(path, ignore_errors=True)
        else:
            path.unlink(missing_ok=True)


def restore(changed, actions, records):
    for setting, value in reversed(changed):
        try:
            if setting == 'appearance':
                actions.set_appearance(value)
            records.append(dict(step='restore', setting=setting, value=value, restored=True))
        except (NotRun, StopRun) as error:
            records.append(dict(step='restore', setting=setting, value=value, restored=False, reason=str(error)))


def write_receipt(folder, ident, ctx, segment, records, outcome, reason):
    receipt = dict(schemaVersion=1, id=ident, sha=ctx['sha'], flavour=segment['flavour'], layout=ctx['layout'],
                   profile=ctx['profile'], outcome=outcome, reason=reason, steps=records)
    (folder / 'receipt.json').write_text(json.dumps(receipt, indent=1, sort_keys=True))


def result_line(outcome, ident, sha, flavour, layout, reason):
    assert outcome in OUTCOMES
    line = f'{outcome} {ident} @ {sha} flavour={flavour or "-"} layout={layout} evidence={ident}/'
    return line + (f' reason={slug(reason)}' if reason else '')


def readme(ctx, manifest, receipt, lines, segments, deviations, before, after):
    profile = ctx['profile']
    parts = [f'# Verification run {ctx["batch"]} / {ctx["lane"]}', '']
    if profile == 'real':
        parts += [f'**{PRIVATE_EVIDENCE}**', '']
    parts += ['## Candidate', '', f'- integration SHA: `{ctx["sha"]}`', f'- tree: `{manifest.get("tree", "-")}`',
              f'- profile: {profile}', f'- layout: {ctx["layout"]}', f'- coordinator GO: {ctx["go"]}']
    for flavour, entry in manifest.get('artifacts', {}).items():
        parts.append(f'- {flavour}: `{entry.get("name")}` digest `{entry.get("digest")}`')
    for pr in manifest.get('prs', []):
        parts.append(f'- PR #{pr.get("pr")} at `{pr.get("head")}`: {", ".join(pr.get("ids", []))}')
    parts += ['', f'Preflight: {receipt.get("outcome")} (preflight.json)', '', '## Segments', '']
    parts += [f'- {i + 1}: {s["flavour"]} {", ".join(s["ids"])} - {s.get("closure", "not started")}'
              for i, s in enumerate(segments)] or ['- none']
    parts += ['', '## System settings', '', f'- before: `{json.dumps(before, sort_keys=True)}`',
              f'- after: `{json.dumps(after, sort_keys=True)}`', '', '## Isolation statement', '',
              ISOLATION_REAL if profile == 'real' else ISOLATION_SYNTHETIC, '', '## Deviations', '']
    parts += [f'- {d}' for d in deviations] or ['- none']
    parts += ['', '## Results', '', '```', *lines, '```', '',
              'PASS and FAIL come only from machine assertions; REVIEW means the coordinator judges the images.']
    return '\n'.join(parts) + '\n'


def execute(manifest, *, lane, layout, ids, out, artifacts_dir, scratch_parent, host=None, actions=None,
            session=None, control_ref='origin/main', layouts=None):
    """Returns the process exit code: 0 run complete, 1 preflight failed, 2 stopped (stop list)."""
    out = Path(out).absolute()
    if any((p / '.git' / 'HEAD').is_file() or (p / '.git').is_file() for p in [out, *out.parents]):
        raise SystemExit('evidence must not be written inside a git checkout')
    out.mkdir(parents=True, exist_ok=True)
    if any(out.iterdir()):
        raise SystemExit('output directory must be new or empty')
    work = Path(scratch_parent) / f'verify-work-{secrets.token_hex(4)}'
    work.mkdir()
    receipt = preflight.run(manifest, lane=lane, layout=layout, ids=ids, artifacts_dir=artifacts_dir, work=work,
                            scratch_parent=scratch_parent, host=host, control_ref=control_ref, layouts=layouts)
    (out / 'preflight.json').write_text(json.dumps(receipt, indent=1, sort_keys=True))
    sha = manifest.get('integrationSHA', '-') if isinstance(manifest, dict) else '-'
    profile = manifest.get('profile') if isinstance(manifest, dict) else None
    host_state = next((c.get('systemState') for c in receipt['checks'] if c['id'] == 'PF-11'), None) or {}
    ctx = dict(lane=lane, layout=layout, sha=sha, profile=profile if profile in preflight.PROFILES else 'synthetic',
               batch=slug((manifest or {}).get('batch', 'batch')), go=(manifest or {}).get('coordinatorGo'),
               approval=(manifest or {}).get('approval'),
               host=preflight.LANE_HOST.get(lane), steps=receipt.get('steps', {}), work=str(work),
               scratchParent=str(scratch_parent), tools=str(work), markers=account_markers(),
               displays=host_state.get('displays') or [], baseline=receipt.get('systemBaseline') or {})
    results, deviations, segments = {}, [], []
    for ident, why in receipt.get('refused', {}).items():
        results[ident] = ('NOT-RUN', None, 'PF-10 ' + why)
    code = 0
    if receipt['outcome'] != 'PASS':
        failed = [c['id'] for c in receipt['checks'] if c['status'] != 'PASS']
        deviations.append('preflight failed: ' + ', '.join(sorted(set(failed))))
        for ident in ids:
            results.setdefault(ident, ('NOT-RUN', None, 'preflight-' + '-'.join(sorted(set(failed)))))
        code = 1
    else:
        actions = actions or Actions(ctx)
        segments = plan_segments(receipt['accepted'], ctx['steps'], list(manifest['artifacts']))
        stopped = None
        for index, segment in enumerate(segments, 1):
            if stopped:
                for ident in segment['ids']:
                    results[ident] = ('NOT-RUN', segment['flavour'], 'run-stopped-' + stopped)
                continue
            current = (session or Session)(ctx, segment, index)
            try:
                subject = current.open()
                for ident in segment['ids']:
                    if stopped:
                        results[ident] = ('NOT-RUN', segment['flavour'], 'segment-stopped-' + stopped); continue
                    try:
                        outcome, reason = run_id(ident, ctx['steps'][ident], segment, subject, ctx, actions, out)
                        results[ident] = (outcome, segment['flavour'], reason)
                    except StopRun as error:
                        stopped = ('ISOLATION-FAIL-' if error.isolation else '') + slug(error)
                        results[ident] = ('NOT-RUN', segment['flavour'], stopped)
                        deviations.append(('ISOLATION FAIL: ' if error.isolation else 'stopped: ') + f'{ident}: {error}')
            except NotRun as error:
                for ident in segment['ids']:
                    results.setdefault(ident, ('NOT-RUN', segment['flavour'], str(error)))
            except StopRun as error:
                stopped = slug(error)
                deviations.append(f'segment {index} stopped: {error}')
                for ident in segment['ids']:
                    results.setdefault(ident, ('NOT-RUN', segment['flavour'], stopped))
            finally:
                closure = current.close()
                segment['closure'] = ('cleaned, booking finished' if closure.get('cleaned') else
                                      'CLOSURE UNCONFIRMED, booking left started: ' + closure.get('detail', ''))
                if not closure.get('cleaned'):
                    stopped = stopped or 'closure-unconfirmed'
                    deviations.append(f'segment {index}: closure unconfirmed ({closure.get("detail")}); report to the coordinator')
        if stopped:
            code = 2
    try:
        after_state = (host or preflight.Host()).display_state().get('settings', {})
    except Exception:
        after_state = {'state': 'unknown'}
    lines = [result_line(results[i][0], i, sha, results[i][1], layout, results[i][2]) for i in ids if i in results]
    lines += [result_line('NOT-RUN', i, sha, None, layout, 'not-scheduled') for i in ids if i not in results]
    (out / 'results.txt').write_text('\n'.join(lines) + '\n')
    (out / 'README.md').write_text(readme(ctx, manifest if isinstance(manifest, dict) else {}, receipt, lines, segments,
                                          deviations, host_state.get('settings', {}), after_state))
    shutil.rmtree(work, ignore_errors=True)
    return code


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--batch', type=Path, required=True)
    parser.add_argument('--lane', choices=sorted(preflight.LANE_HOST), required=True)
    parser.add_argument('--layout', required=True)
    parser.add_argument('--scenarios', required=True)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--artifacts-dir', type=Path, required=True)
    parser.add_argument('--scratch-parent', type=Path, required=True, help='local (not shared) directory for run scratch')
    parser.add_argument('--control-ref', default='origin/main')
    args = parser.parse_args(argv)
    manifest = json.loads(args.batch.read_text(encoding='utf-8'))
    return execute(manifest, lane=args.lane, layout=args.layout, ids=preflight.parse_ids(args.scenarios), out=args.out,
                   artifacts_dir=args.artifacts_dir, scratch_parent=args.scratch_parent, control_ref=args.control_ref)


if __name__ == '__main__':
    sys.exit(main())
