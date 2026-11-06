# SPDX-License-Identifier: MIT
import importlib.util
import json
from pathlib import Path
import re
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parent))
from verify_fixtures import SHA, FakeHost, manifest, write_artifact  # noqa: E402

BIN = Path(__file__).resolve().parents[1] / 'bin'
spec = importlib.util.spec_from_file_location('verify_run', BIN / 'verify-run.py')
verify_run = importlib.util.module_from_spec(spec); spec.loader.exec_module(verify_run)
NAME = f'native-app-unverified-{SHA}'
LINE = re.compile(r'^(PASS|FAIL|REVIEW|NOT-RUN) ([A-Z][A-Z0-9]{0,3}-[0-9]{2}) @ ([0-9a-f]{40}) flavour=(\S+) '
                  r'layout=(\S+) evidence=\2/( reason=\S+)?$')


class FakeSession:
    opened, closed = [], []
    lease = None  # set by the harness per run: paths + snapshot of a live lease for the supervisor check

    def __init__(self, ctx, segment, index, fail=None, cleaned=True):
        self.segment, self.fail, self.cleaned = segment, fail, cleaned

    def open(self):
        FakeSession.opened.append(list(self.segment['ids']))
        if self.fail:
            raise self.fail
        subject = dict(pid=123, bundle='/synthetic/ModelPlan Community.app', home='/synthetic/home', registeredAt=100.0)
        subject.update(FakeSession.lease or {})  # without paths run_id fails closed on missing authority
        return subject

    def close(self):
        FakeSession.closed.append(list(self.segment['ids']))
        return dict(cleaned=self.cleaned, detail='fake')


class FakeActions:
    def __init__(self, windows=True, at=100.5, dialogs=(), ax_text='Quota Widget', appearance=True,
                 item_bounds=dict(x=1412, y=0, width=80, height=24), display=dict(width=1512, height=982)):
        self.windows, self.now, self.dialog_list = windows, at, list(dialogs)
        self.ax_text, self.appearance, self.calls = ax_text, appearance, []
        self.item_bounds = item_bounds  # raw kAXPosition/kAXSize: top-left origin, as the probe reports
        self.ctx = dict(profile='synthetic', markers=[], displays=[dict(main=True, x=0, y=0, **display)])

    # The production consumer, not a re-implementation: its coordinate handling is under test.
    status_item_rect = verify_run.Actions.status_item_rect

    def capture(self, subject, directory, wait):
        directory.mkdir(parents=True)
        shown = self.windows if not callable(self.windows) else self.windows(directory.name)
        if shown:
            (directory / 'window.png').write_bytes(b'png')
            (directory / 'ax-tree.json').write_text(json.dumps(dict(windows=[dict(AXTitle=self.ax_text)])))
        ax = dict(outcome='pass' if shown else 'timeout')
        if self.item_bounds:
            ax['statusItem'] = dict(self.item_bounds)  # the owned item's bounds
        return dict(ax=ax, screenshot=dict(outcome='pass' if shown else 'unsupported', reason='owned-app-unavailable'))

    def menubar(self, rect, png):
        self.calls.append(('menubar', rect)); png.write_bytes(b'png')

    def dialogs(self):
        return self.dialog_list

    def set_appearance(self, value):
        self.calls.append(('appearance', value))
        if not self.appearance:
            raise verify_run.NotRun('appearance-switch-not-granted-on-this-host')

    def status_menu(self, subject, item, action, directory):
        raise verify_run.NotRun(f'status-menu-action-{action}-has-no-arrival-receipt')

    def relaunch(self, subject):
        raise verify_run.NotRun('relaunch-unsupported')

    def sleep(self, value):
        self.calls.append(('sleep', value))

    def clock(self):
        return self.now


class VerifyRunTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.artifacts = self.root / 'artifacts'; self.artifacts.mkdir()
        self.scratch = self.root / 'scratch'; self.scratch.mkdir()
        self.digest = write_artifact(self.artifacts, NAME)
        FakeSession.opened, FakeSession.closed = [], []
        self.count = 0

    def go(self, ids=('D-01', 'V-01', 'D-14'), actions=None, host=None, session=FakeSession, profile='synthetic',
           lease_heartbeat=100.2, stopped=False, with_authority=True):
        self.count += 1
        self.out = self.root / f'out{self.count}'
        if with_authority:  # a live lease the runner's supervisor check accepts (FakeActions clock 100.5)
            lease_path, stop_path = self.root / f'lease{self.count}.json', self.root / f'STOP{self.count}'
            lease = dict(runID='r', epoch='e', notBefore=0, expiresAt=1e12, guardianHeartbeatAt=lease_heartbeat,
                         ownerPreempted=False, exclusive=True)
            lease_path.write_text(json.dumps(lease))
            if stopped:
                stop_path.write_text('stop')
            FakeSession.lease = dict(leasePath=str(lease_path), stopPath=str(stop_path),
                                     leaseSnapshot={k: lease[k] for k in ('runID', 'epoch', 'notBefore', 'expiresAt')})
        else:
            FakeSession.lease = None
        code = verify_run.execute(manifest(self.digest, profile=profile), lane='V1', layout='single', ids=list(ids),
                                  out=self.out, artifacts_dir=self.artifacts, scratch_parent=self.scratch,
                                  host=host or FakeHost(self.digest), actions=actions or FakeActions(), session=session)
        lines = (self.out / 'results.txt').read_text().splitlines()
        for line in lines:
            self.assertRegex(line, LINE)
        return code, {line.split()[1]: line for line in lines}, (self.out / 'README.md').read_text()

    def test_smoke_ring_outcomes_and_output_contract(self):
        code, lines, readme = self.go()
        self.assertEqual(code, 0)
        self.assertTrue(lines['D-01'].startswith(f'REVIEW D-01 @ {SHA} flavour=release layout=single evidence=D-01/'))
        self.assertTrue(lines['V-01'].startswith('REVIEW V-01'))
        self.assertTrue(lines['D-14'].startswith('NOT-RUN D-14'))
        self.assertIn('reason=status-menu-action-hide', lines['D-14'])
        self.assertTrue((self.out / 'D-01' / '01-widget-appears.png').exists())
        self.assertTrue((self.out / 'D-01' / '02-menubar.png').exists())
        self.assertTrue((self.out / 'V-01' / '05-dark.png').exists())
        receipt = json.loads((self.out / 'D-01' / 'receipt.json').read_text())
        self.assertEqual(receipt['sha'], SHA)
        self.assertEqual(receipt['steps'][0]['elapsedSinceRegistration'], 0.5)
        v01 = json.loads((self.out / 'V-01' / 'receipt.json').read_text())
        self.assertEqual(v01['steps'][-1], dict(step='restore', setting='appearance', value='light', restored=True))
        self.assertIn(verify_run.ISOLATION_SYNTHETIC, readme)
        self.assertNotIn('PRIVATE EVIDENCE', readme)
        self.assertTrue((self.out / 'preflight.json').exists())
        # D-01 is fresh: its own launch; V-01 and D-14 ride with it while time allows.
        self.assertEqual(FakeSession.opened, [['D-01', 'V-01', 'D-14']])
        self.assertEqual(FakeSession.closed, FakeSession.opened)

    def test_a_dead_guardian_heartbeat_stops_before_any_step(self):
        code, lines, readme = self.go(lease_heartbeat=96.0)  # the runner's clock reads 100.5: stale
        self.assertEqual(code, 2)
        self.assertIn('reason=supervisor-guardian-heartbeat-stale', lines['D-01'])
        self.assertIn('segment-stopped-supervisor-guardian-heartbeat-stale', lines['V-01'])
        self.assertEqual(FakeSession.closed, FakeSession.opened)  # bounded cleanup still ran

    def test_a_stop_receipt_stops_the_segment_before_any_step(self):
        code, lines, readme = self.go(stopped=True)
        self.assertEqual(code, 2)
        self.assertIn('reason=supervisor-stop-file', lines['D-01'])
        self.assertEqual(list(self.out.rglob('*.png')), [])  # no capture ran after the stop

    def test_a_subject_without_authority_fails_closed(self):
        code, lines, readme = self.go(with_authority=False)
        self.assertEqual(code, 2)
        self.assertIn('reason=supervisor-authority-missing', lines['D-01'])

    def test_capture_menubar_crops_only_the_owned_status_item(self):
        actions = FakeActions()
        code, lines, readme = self.go(ids=('V-01',), actions=actions)
        self.assertEqual(code, 0)
        rect = actions.calls[0][1]
        self.assertEqual(rect, (1412, 0, 80, 24))  # the item's AX bounds, top-left origin for capture
        receipt = json.loads((self.out / 'V-01' / 'receipt.json').read_text())
        crops = [s for s in receipt['steps'] if s.get('action') == 'capture-menubar']
        self.assertTrue(all(c.get('region') == [1412, 0, 80, 24] and c.get('source') == 'owned-status-item'
                            for c in crops))

    def test_capture_menubar_uses_raw_top_left_ax_bounds_on_a_1440_high_display(self):
        # The probe reports raw kAXPosition (top-left origin, global); screencapture -R uses the
        # same space, so the production crop and command must carry the AX rectangle unchanged.
        commands = []

        class RealCapture(FakeActions):
            def menubar(self, rect, png):
                def screencapture(command, **kwargs):
                    commands.append(command)
                    png.write_bytes(b'synthetic')
                    return SimpleNamespace(returncode=0)
                with patch.object(verify_run.subprocess, 'run', side_effect=screencapture):
                    verify_run.Actions.menubar(self, rect, png)

        actions = RealCapture(item_bounds=dict(x=2391.5, y=0, width=37.25, height=24),
                              display=dict(width=2560, height=1440))
        code, lines, readme = self.go(ids=('V-01',), actions=actions)
        self.assertEqual(code, 0)
        self.assertTrue(commands)
        for command in commands:
            self.assertEqual(command[:3], ['/usr/sbin/screencapture', '-x', '-R2391,0,38,24'])

    def test_capture_menubar_refuses_bounds_outside_the_menu_bar(self):
        # A bottom-of-screen rectangle (what a wrong y-flip would produce) is never captured.
        actions = FakeActions(item_bounds=dict(x=2400, y=1416, width=80, height=24), display=dict(width=2560, height=1440))
        code, lines, readme = self.go(ids=('V-01',), actions=actions)
        self.assertIn('reason=menubar-crop-outside-main-menu-bar', lines['V-01'])
        self.assertEqual([c for c in actions.calls if c[0] == 'menubar'], [])

    def test_stop_during_the_status_item_probe_takes_no_capture(self):
        # STOP lands while V-01's final (dark) bounds probe is in flight: no screenshot follows,
        # the probe output is discarded, the ID is stopped (not REVIEW/PASS) and the appearance
        # baseline is still restored as bounded cleanup.
        class StopDuringProbe(FakeActions):
            def capture(self, subject, directory, wait):
                report = super().capture(subject, directory, wait)
                if directory.name == '05-dark.item':
                    Path(subject['stopPath']).write_text('guardian-deadline')
                return report
        actions = StopDuringProbe()
        code, lines, readme = self.go(ids=('V-01',), actions=actions)
        self.assertEqual(code, 2)
        self.assertTrue(lines['V-01'].startswith('NOT-RUN V-01'))
        self.assertIn('reason=supervisor-stop-file', lines['V-01'])
        menubar = [c for c in actions.calls if c[0] == 'menubar']
        self.assertEqual(len(menubar), 1)  # only the light crop, taken before the STOP
        self.assertFalse((self.out / 'V-01' / '05-dark.png').exists())
        self.assertFalse((self.out / 'V-01' / '05-dark.item').exists())
        receipt = json.loads((self.out / 'V-01' / 'receipt.json').read_text())
        self.assertEqual(receipt['outcome'], 'NOT-RUN')
        self.assertIn(dict(step='restore', setting='appearance', value='light', restored=True), receipt['steps'])

    def test_stop_during_a_window_probe_discards_it_and_stops(self):
        class StopDuringWindow(FakeActions):
            def capture(self, subject, directory, wait):
                report = super().capture(subject, directory, wait)
                if directory.name.endswith('.probe'):
                    Path(subject['stopPath']).write_text('owner-stop')
                return report
        code, lines, readme = self.go(ids=('D-01',), actions=StopDuringWindow())
        self.assertEqual(code, 2)
        self.assertIn('reason=supervisor-stop-file', lines['D-01'])
        self.assertEqual(list(self.out.rglob('*.png')), [])

    def test_stop_during_the_final_dialog_query_is_not_a_completed_run(self):
        # STOP lands while the production dialog query (osascript) of V-01's LAST step is in
        # flight: the ID must not complete as REVIEW/PASS; it is NOT-RUN supervisor-*, exit 2,
        # and the appearance baseline is still restored.
        steps = len(json.loads((BIN.parent / 'scenarios' / 'V-01.json').read_text())['steps'])

        class StopDuringLastDialogs(FakeActions):
            queries = 0

            def dialogs(self):
                self.queries += 1
                def osascript(command, **kwargs):
                    self.calls.append(('osascript', command[0]))
                    if self.queries == steps:
                        Path(FakeSession.lease['stopPath']).write_text('guardian-deadline')
                    return SimpleNamespace(returncode=0, stdout='[]')
                with patch.object(verify_run.subprocess, 'run', side_effect=osascript):
                    return verify_run.Actions.dialogs(self)

        actions = StopDuringLastDialogs()
        code, lines, readme = self.go(ids=('V-01',), actions=actions)
        self.assertEqual(actions.queries, steps)  # the STOP really landed in the final query
        self.assertEqual(code, 2)
        self.assertTrue(lines['V-01'].startswith('NOT-RUN V-01'))
        self.assertIn('reason=supervisor-stop-file', lines['V-01'])
        receipt = json.loads((self.out / 'V-01' / 'receipt.json').read_text())
        self.assertEqual(receipt['outcome'], 'NOT-RUN')
        self.assertNotIn(receipt['outcome'], ('PASS', 'REVIEW'))
        self.assertEqual(receipt['reason'], 'supervisor-stop-file')
        self.assertIn(dict(step='restore', setting='appearance', value='light', restored=True), receipt['steps'])

    def test_capture_menubar_without_owned_bounds_takes_no_system_region(self):
        actions = FakeActions(item_bounds=False)
        code, lines, readme = self.go(ids=('V-01',), actions=actions)
        self.assertIn('reason=menubar-crop-needs-owned-status-item-bounds', lines['V-01'])
        self.assertEqual([c for c in actions.calls if c[0] == 'menubar'], [])  # no system region captured

    def test_failed_restore_fails_the_id_and_stops_later_segments(self):
        class HalfBroken(FakeActions):
            def set_appearance(self, value):
                self.calls.append(('appearance', value))
                if value == 'light':  # switching to dark works; restoring the light baseline fails
                    raise verify_run.NotRun('appearance-switch-failed')
        code, lines, readme = self.go(actions=HalfBroken())
        self.assertEqual(code, 2)
        self.assertTrue(lines['V-01'].startswith('FAIL V-01'))
        self.assertIn('reason=restore-failed-appearance', lines['V-01'])
        self.assertIn('baseline-restore-failed', lines['D-14'])  # no later segment until re-established
        self.assertIn('later segments stopped until the baseline is re-established', readme)
        receipt = json.loads((self.out / 'V-01' / 'receipt.json').read_text())
        self.assertTrue(any(s.get('restored') is False for s in receipt['steps']))

    def test_late_or_missing_window_is_review_or_fail(self):
        _, lines, _ = self.go(ids=('D-01',), actions=FakeActions(at=103.0))
        self.assertIn('reason=01-widget-appears-observed-after-3.0s-including-probe', lines['D-01'])
        self.assertTrue(lines['D-01'].startswith('REVIEW'))
        _, lines, _ = self.go(ids=('D-01',), actions=FakeActions(windows=False))
        self.assertTrue(lines['D-01'].startswith('FAIL D-01'))

    def test_preflight_failure_stops_before_any_booking(self):
        code, lines, readme = self.go(host=FakeHost(self.digest, macos=False))
        self.assertEqual(code, 1)
        self.assertEqual(FakeSession.opened, [])
        self.assertTrue(all(l.startswith('NOT-RUN') and 'reason=preflight-PF-09-PF-11' in l for l in lines.values()))
        self.assertIn('preflight failed: PF-09, PF-11', readme)
        self.assertIn(verify_run.ISOLATION_SYNTHETIC, readme)

    def test_refused_ids_are_not_run_and_the_rest_continue(self):
        code, lines, _ = self.go(ids=('D-09', 'D-01'))
        self.assertEqual(code, 0)
        self.assertIn('reason=PF-10-tier-T0-does-not-belong-in-a-GUI-run', lines['D-09'])
        self.assertTrue(lines['D-01'].startswith('REVIEW'))

    def test_system_dialog_is_an_isolation_fail_that_stops_the_run(self):
        actions = FakeActions(dialogs=[dict(owner='SecurityAgent', title='ModelPlan wants to use the keychain')])
        code, lines, readme = self.go(actions=actions)
        self.assertEqual(code, 2)
        self.assertIn('reason=ISOLATION-FAIL-system-dialog:', lines['D-01'])
        self.assertIn('segment-stopped', lines['V-01'])
        self.assertIn('ISOLATION FAIL: D-01: system-dialog: SecurityAgent: ModelPlan wants to use the keychain', readme)
        self.assertEqual(list((self.out / 'D-01').rglob('*.png')), [])
        self.assertEqual(FakeSession.closed, FakeSession.opened)

    def test_account_data_deletes_images_and_stops(self):
        code, lines, readme = self.go(actions=FakeActions(ax_text='signed in as someone@example.com'))
        self.assertEqual(code, 2)
        self.assertIn('ISOLATION-FAIL-account-data-on-screen', lines['D-01'])
        self.assertEqual(list(self.out.rglob('*.png')), [])
        # the account data was found in an AX tree, so everything the segment captured goes:
        # images, AX trees and probe reports; only the receipt (written after the purge) remains
        self.assertEqual([p.name for p in (self.out / 'D-01').iterdir()], ['receipt.json'])
        self.assertEqual(list((self.out / 'D-01').rglob('ax-tree.json')), [])

    def test_release_arguments_match_the_host_role(self):
        go = 'https://github.com/modelplan/modelplan/issues/570#issuecomment-1'
        self.assertEqual(verify_run.release_arguments(dict(host='macci', go=go)), ['--coordinator-go', go])
        approval = 'https://github.com/modelplan/modelplan/issues/570#issuecomment-2'
        self.assertEqual(verify_run.release_arguments(dict(host='dev-mac', approval=approval)), ['--approval', approval])
        for ctx in (dict(host='dev-mac', go=go), dict(host='dev-mac')):  # a GO never releases on the dev Mac
            self.assertEqual(verify_run.release_arguments(ctx), ['--approval', str(ctx.get('approval') or '')])

    def test_missing_appearance_grant_is_not_run_and_still_restored_list(self):
        _, lines, _ = self.go(ids=('V-01',), actions=FakeActions(appearance=False))
        self.assertIn('reason=appearance-switch-not-granted-on-this-host', lines['V-01'])

    def test_unconfirmed_closure_stops_later_segments(self):
        class Dirty(FakeSession):
            def __init__(self, *a):
                super().__init__(*a, cleaned=False)
        code, lines, readme = self.go(ids=('D-01',), session=Dirty)
        self.assertEqual(code, 2)
        self.assertIn('closure unconfirmed', readme)

    def test_real_profile_records_mode_private_statement_and_helper_gap(self):
        class Real(FakeSession):
            def __init__(self, *a):
                super().__init__(*a, fail=verify_run.NotRun('real-profile-launch-not-supported-by-shared-helpers'))
        code, lines, readme = self.go(ids=('V-01', 'D-14', 'D-01'), profile='real', session=Real)
        self.assertEqual(code, 0)
        self.assertEqual(json.loads((self.out / 'preflight.json').read_text())['profile'], 'real')
        self.assertIn('PRIVATE EVIDENCE', readme)
        self.assertIn(verify_run.ISOLATION_REAL, readme)
        self.assertNotIn(verify_run.ISOLATION_SYNTHETIC, readme)
        self.assertIn('never be attached to or quoted in public PRs', verify_run.ISOLATION_REAL)
        self.assertIn('reason=real-profile-launch-not-supported-by-shared-helpers', lines['V-01'])
        self.assertIn('profile-real', lines['D-01'])  # D-01 needs a fresh synthetic profile

    def test_real_session_refuses_real_profile_before_booking(self):
        session = verify_run.Session(dict(profile='real'), dict(flavour='release', ids=['V-01']), 1)
        with self.assertRaises(verify_run.NotRun):
            session.open()
        self.assertEqual(session.close(), dict(cleaned=True, detail='nothing launched'))

    def test_output_must_be_new_and_outside_a_checkout(self):
        out = self.root / 'used'; out.mkdir(); (out / 'x').write_text('x')
        with self.assertRaises(SystemExit):
            verify_run.execute(manifest(self.digest), lane='V1', layout='single', ids=['D-01'], out=out,
                               artifacts_dir=self.artifacts, scratch_parent=self.scratch, host=FakeHost(self.digest),
                               actions=FakeActions(), session=FakeSession)
        with self.assertRaises(SystemExit):
            verify_run.execute(manifest(self.digest), lane='V1', layout='single', ids=['D-01'],
                               out=Path(__file__).resolve().parent / 'never-created', artifacts_dir=self.artifacts,
                               scratch_parent=self.scratch, host=FakeHost(self.digest), actions=FakeActions(),
                               session=FakeSession)

    def test_segments_respect_the_1200_second_cap(self):
        steps = {f'D-{n:02d}': dict(flavours=['release'], launch='running', estimatedSeconds=300) for n in range(1, 8)}
        steps['V-01'] = dict(flavours=['release'], launch='fresh', estimatedSeconds=60)
        steps['V-02'] = dict(flavours=['release'], launch='fresh', estimatedSeconds=60)
        segments = verify_run.plan_segments(list(steps), steps, ['release'])
        self.assertEqual([s['ids'][0] for s in segments[:2]], ['V-01', 'V-02'])
        for segment in segments:
            self.assertLessEqual(verify_run.seconds(segment['ids'], steps), 1200)
            self.assertLessEqual(sum(steps[i]['launch'] == 'fresh' for i in segment['ids']), 1)
        self.assertEqual(sorted(i for s in segments for i in s['ids']), sorted(steps))


if __name__ == '__main__':
    unittest.main()
