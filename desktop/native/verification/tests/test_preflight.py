# SPDX-License-Identifier: MIT
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
from verify_fixtures import (APP, ARM64, SHA, X86_64, FakeHost, fat, info, inner_zip, manifest,  # noqa: E402
                             write_artifact)
import preflight  # noqa: E402
import verify_steps  # noqa: E402

NAME = f'native-app-unverified-{SHA}'
VERIFICATION = Path(__file__).resolve().parents[1]


class PreflightTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.artifacts = self.root / 'artifacts'; self.artifacts.mkdir()
        self.scratch = self.root / 'scratch'; self.scratch.mkdir()
        self.count = 0

    def run_preflight(self, digest=None, host=None, ids=('D-01', 'V-01'), lane='V1', layout='single', **kwargs):
        if digest is None:
            digest = write_artifact(self.artifacts, NAME)
        self.count += 1
        m = kwargs.pop('manifest', None) or manifest(digest, **kwargs)
        return preflight.run(m, lane=lane, layout=layout, ids=list(ids), artifacts_dir=self.artifacts,
                             work=self.root / f'work{self.count}', scratch_parent=self.scratch,
                             host=host or FakeHost(digest))

    def status(self, receipt):
        out = {}
        for check in receipt['checks']:
            out[check['id']] = 'FAIL' if out.get(check['id']) == 'FAIL' else check['status']
        return out

    def failed(self, receipt):
        return sorted(k for k, v in self.status(receipt).items() if v != 'PASS')

    def test_good_candidate_passes_every_check_and_records_profile(self):
        receipt = self.run_preflight()
        self.assertEqual(self.failed(receipt), [])
        self.assertEqual(receipt['outcome'], 'PASS')
        self.assertEqual(sorted(self.status(receipt)), list(preflight.CHECKS))
        self.assertEqual(receipt['profile'], 'synthetic')
        self.assertEqual(receipt['accepted'], ['D-01', 'V-01'])
        self.assertIn('release', receipt['apps'])

    def test_an_m1_batch_needs_the_approval_url_a_v1_batch_does_not(self):
        receipt = self.run_preflight(lane='M1')  # the manifest carries no approval URL
        self.assertEqual(receipt['outcome'], 'FAIL')
        detail = receipt['checks'][0]['detail']
        self.assertIn('an M1 batch needs approval', detail)
        with_approval = manifest(write_artifact(self.artifacts, NAME))
        with_approval['approval'] = 'https://github.com/modelplan/modelplan/issues/570#issuecomment-2'
        receipt = self.run_preflight(lane='M1', manifest=with_approval)
        self.assertNotIn('an M1 batch needs approval', ' '.join(c.get('detail', '') for c in receipt['checks']))
        receipt = self.run_preflight(lane='V1')  # V1 releases on the coordinator GO alone
        self.assertNotIn('an M1 batch needs approval', ' '.join(c.get('detail', '') for c in receipt['checks']))

    def test_legacy_tauri_artifact_and_any_dmg_are_refused(self):
        digest = write_artifact(self.artifacts, preflight.LEGACY_TAURI)
        receipt = self.run_preflight(digest, manifest=manifest(digest, name=preflight.LEGACY_TAURI))
        self.assertIn('PF-01', self.failed(receipt))
        self.assertEqual(receipt['outcome'], 'FAIL')
        digest = write_artifact(self.artifacts, NAME, members={'BUILD.txt': 'x', 'Model-Plan.dmg': 'x'})
        receipt = self.run_preflight(digest)
        self.assertIn('PF-02', self.failed(receipt))
        self.assertIn('.dmg', [c for c in receipt['checks'] if c['id'] == 'PF-02'][0]['detail'])
        for wrong in (f'native-app-test-{SHA}', 'native-app-unverified-' + 'b' * 40, 'native-app.dmg'):
            digest = write_artifact(self.artifacts, wrong)
            self.assertIn('PF-01', self.failed(self.run_preflight(digest, manifest=manifest(digest, name=wrong))))

    def test_digest_and_source_mismatches_fail(self):
        digest = write_artifact(self.artifacts, NAME)
        self.assertIn('PF-03', self.failed(self.run_preflight(digest, host=FakeHost('sha256:' + '0' * 64))))
        self.assertIn('PF-03', self.failed(self.run_preflight(digest, manifest=manifest('sha256:' + '0' * 64))))
        inner = inner_zip()
        digest = write_artifact(self.artifacts, NAME, inner=inner,
                                build=f'sourceSHA={SHA}\nrunID=42\nrunAttempt=1\n{"0" * 64}  {preflight.INNER}\n')
        self.assertIn('PF-03', self.failed(self.run_preflight(digest)))
        import hashlib
        digest = write_artifact(self.artifacts, NAME, inner=inner, build=(
            f'sourceSHA={"c" * 40}\nrunID=42\nrunAttempt=1\n{hashlib.sha256(inner).hexdigest()}  {preflight.INNER}\n'))
        self.assertIn('PF-04', self.failed(self.run_preflight(digest)))

    def test_a_merge_commit_build_labelled_with_the_pr_head_is_refused(self):
        # A pull_request run that checked out the synthetic merge commit M records M as the bundle's
        # ModelPlanPublicSource (package-neutral.sh: git rev-parse HEAD), while BUILD.txt, the
        # artifact name and the run's head_sha all say the PR head H. Matching labels are not
        # provenance: the built tree's own source must equal H, or PF-04 fails closed.
        import hashlib
        merge = 'd' * 40
        for recorded in (merge, None):
            inner = inner_zip(plist=info(ModelPlanPublicSource=recorded))
            digest = write_artifact(self.artifacts, NAME, inner=inner, build=(
                f'sourceSHA={SHA}\nrunID=42\nrunAttempt=1\n{hashlib.sha256(inner).hexdigest()}  {preflight.INNER}\n'))
            receipt = self.run_preflight(digest)
            self.assertEqual(receipt['outcome'], 'FAIL')
            self.assertEqual(self.failed(receipt), ['PF-04'])
            detail = [c for c in receipt['checks'] if c['id'] == 'PF-04' and c['status'] != 'PASS'][0]['detail']
            self.assertIn(f'ModelPlanPublicSource={recorded or "missing"}', detail)

    def test_an_exact_head_build_passes_source_binding(self):
        # Checkout of the exact PR head: label, run head_sha and the bundle's recorded source agree.
        receipt = self.run_preflight(write_artifact(self.artifacts, NAME, inner=inner_zip(plist=info(ModelPlanPublicSource=SHA))))
        self.assertEqual(self.failed(receipt), [])
        pf04 = [c for c in receipt['checks'] if c['id'] == 'PF-04']
        self.assertIn(f'bundle ModelPlanPublicSource={SHA}', pf04[0]['detail'])

    def test_provenance_requires_repo_workflow_head_and_successful_job(self):
        digest = write_artifact(self.artifacts, NAME)
        base = dict(repository=dict(full_name=preflight.REPO), path='.github/workflows/desktop.yml', head_sha=SHA)
        for run in (base | dict(repository=dict(full_name='fork/modelplan')),
                    base | dict(path='.github/workflows/other.yml'), base | dict(head_sha='d' * 40)):
            self.assertIn('PF-02', self.failed(self.run_preflight(digest, host=FakeHost(digest, run=run))))
        failed_job = FakeHost(digest, jobs=[dict(name='app-smoke', conclusion='failure')])
        self.assertIn('PF-02', self.failed(self.run_preflight(digest, host=failed_job)))

    def test_stale_batch_heads_fail(self):
        digest = write_artifact(self.artifacts, NAME)
        self.assertIn('PF-04', self.failed(self.run_preflight(digest, host=FakeHost(digest, pr_head='e' * 40))))
        self.assertIn('PF-04', self.failed(self.run_preflight(digest, host=FakeHost(digest, compare='diverged'))))

    def test_bundle_shape_executable_resources_and_flavour(self):
        cases = {
            'PF-05': dict(top=(APP, 'Other.app')),
            'PF-06': dict(plist=info(CFBundleExecutable='modelplan-desktop')),
        }
        cases_extra = [('PF-05', dict(symlink='../../../outside')), ('PF-06', dict(exe=fat(X86_64))),
                       ('PF-06', dict(exe=b'#!/bin/sh\n' * 4)), ('PF-07', dict(bundles=preflight.RESOURCE_BUNDLES[1:])),
                       ('PF-07', dict(marks=2)), ('PF-07', dict(pin='0' * 64)),
                       ('PF-08', dict(plist=info(ModelPlanCockpitEntryEnabled=True))),
                       ('PF-08', dict(plist=info(ModelPlanCockpitEntryEnabled=None))),
                       ('PF-08', dict(plist=info(SUFeedURL='https://example.invalid/feed'))),
                       ('PF-08', dict(extra=('Frameworks/Sparkle.framework/Sparkle',))),
                       ('PF-08', dict(plist=info(ModelPlanVerificationFlavour='verify'))),
                       ('PF-08', dict(plist=info(ModelPlanOwnerTestBuild=True)))]
        for check, kwargs in list(cases.items()) + cases_extra:
            with self.subTest(check=check, case=sorted(kwargs)):
                digest = write_artifact(self.artifacts, NAME, inner=inner_zip(**kwargs))
                self.assertIn(check, self.failed(self.run_preflight(digest)))
        digest = write_artifact(self.artifacts, NAME, inner=inner_zip(symlink='Info.plist'))
        self.assertEqual(self.failed(self.run_preflight(digest)), [])

    def test_test_flavour_needs_cockpit_bundle_and_entry_on(self):
        name = f'native-app-test-{SHA}'
        digest = write_artifact(self.artifacts, name, inner=inner_zip(plist=info(ModelPlanCockpitEntryEnabled=True)))
        receipt = self.run_preflight(digest, manifest=manifest(digest, flavour='test', name=name))
        self.assertIn('PF-07', self.failed(receipt))
        # Without the owner-test page admission marker the page could never load (Q1/Q2 on #611).
        digest = write_artifact(self.artifacts, name, inner=inner_zip(
            plist=info(ModelPlanCockpitEntryEnabled=True), bundles=preflight.RESOURCE_BUNDLES + (preflight.COCKPIT_BUNDLE,)))
        receipt = self.run_preflight(digest, manifest=manifest(digest, flavour='test', name=name))
        self.assertEqual(self.failed(receipt), ['PF-08'])
        digest = write_artifact(self.artifacts, name, inner=inner_zip(
            plist=info(ModelPlanCockpitEntryEnabled=True, ModelPlanOwnerTestBuild=True),
            bundles=preflight.RESOURCE_BUNDLES + (preflight.COCKPIT_BUNDLE,)))
        receipt = self.run_preflight(digest, manifest=manifest(digest, flavour='test', name=name))
        self.assertEqual(self.failed(receipt), [])

    def test_exact_arm64_once_required(self):
        m = manifest(write_artifact(self.artifacts, NAME))
        m['artifacts']['release']['exactArm64'] = True
        self.assertIn('PF-06', self.failed(self.run_preflight(manifest=m)))
        digest = write_artifact(self.artifacts, NAME, inner=inner_zip(exe=fat(ARM64)))
        m = manifest(digest); m['artifacts']['release']['exactArm64'] = True
        self.assertEqual(self.failed(self.run_preflight(digest, manifest=m)), [])

    def test_macos_only_checks_fail_closed_on_other_hosts(self):
        digest = write_artifact(self.artifacts, NAME)
        receipt = self.run_preflight(digest, host=FakeHost(digest, macos=False))
        self.assertEqual(self.failed(receipt), ['PF-09', 'PF-11'])
        self.assertTrue(all('requires-macos' in c['detail'] for c in receipt['checks'] if c['status'] == 'FAIL'))
        self.assertIn('requires-macos', [c for c in receipt['checks'] if c['id'] == 'PF-09'][0]['detail'])

    def test_real_host_never_passes_macos_checks_off_macos(self):
        if preflight.Host().is_macos:
            self.skipTest('this check is about non-macOS hosts')
        with self.assertRaises(preflight.Unsupported):
            preflight.Host().codesign(self.root)
        with self.assertRaises(preflight.Unsupported):
            preflight.Host().display_state()

    def test_failed_signature_fails(self):
        digest = write_artifact(self.artifacts, NAME)
        self.assertIn('PF-09', self.failed(self.run_preflight(digest, host=FakeHost(digest, codesign=(False, 'unknown')))))

    def test_scenarios_need_a_gui_tier_and_a_matching_step_file(self):
        receipt = self.run_preflight(ids=('D-01', 'D-09', 'D-02', 'Z-01'))
        self.assertEqual(receipt['accepted'], ['D-01'])
        self.assertIn('tier T0', receipt['refused']['D-09'])
        self.assertIn('no step file', receipt['refused']['D-02'])
        self.assertIn('tier unknown', receipt['refused']['Z-01'])
        self.assertEqual(self.failed(receipt), [])
        receipt = self.run_preflight(ids=('D-09',))
        self.assertIn('PF-10', self.failed(receipt))

    def test_step_file_profile_layout_and_flavour_must_match(self):
        digest = write_artifact(self.artifacts, NAME)
        receipt = self.run_preflight(digest, ids=('D-01', 'V-01'), profile='real',
                                     host=FakeHost(digest, environ={'MODELPLAN_VERIFICATION_HOST': 'macci'}))
        self.assertIn('profile real', receipt['refused']['D-01'])
        self.assertEqual(receipt['accepted'], ['V-01'])
        self.assertEqual(receipt['profile'], 'real')
        step = json.loads((VERIFICATION / 'scenarios' / 'V-01.json').read_text())
        step['layout'] = 'abc'
        host = FakeHost(digest, files={preflight.CONTROL_PREFIX + 'scenarios/V-01.json': json.dumps(step)})
        self.assertIn('layout', self.run_preflight(digest, host=host, ids=('V-01',))['refused']['V-01'])

    def test_control_revision_is_the_only_source_of_step_files(self):
        digest = write_artifact(self.artifacts, NAME)
        host = FakeHost(digest, files={preflight.CONTROL_PREFIX + 'scenarios/D-01.json': '{"id": "D-01"}'})
        self.assertIn('fields must be exactly', self.run_preflight(digest, host=host)['refused']['D-01'])

    def test_host_lane_layout_and_baseline(self):
        digest = write_artifact(self.artifacts, NAME)
        cases = [FakeHost(digest, environ={}), FakeHost(digest, environ={'MODELPLAN_VERIFICATION_HOST': 'dev-mac'}),
                 FakeHost(digest, settings=dict(dockOrientation='left', dockAutohide=False, reduceMotion=False,
                                                appearance='light', voiceOver=False)),
                 FakeHost(digest, settings=dict(dockOrientation='bottom', dockAutohide=False, reduceMotion=False,
                                                appearance='dark', voiceOver=False)),
                 FakeHost(digest, displays=[dict(x=0, y=0, width=1512, height=982, scale=2, main=True),
                                            dict(x=1512, y=0, width=1920, height=1080, scale=1, main=False)])]
        for host in cases:
            self.assertIn('PF-11', self.failed(self.run_preflight(digest, host=host)))
        receipt = self.run_preflight(digest, lane='M1', host=FakeHost(digest, environ={'MODELPLAN_VERIFICATION_HOST': 'dev-mac'}),
                                     manifest=self.m1_manifest(digest))
        self.assertEqual(self.failed(receipt), [])

    def test_a_menu_extra_beyond_the_recorded_baseline_fails_pf11(self):
        digest = write_artifact(self.artifacts, NAME)
        base = dict(dockOrientation='bottom', dockAutohide=False, reduceMotion=False, appearance='light', voiceOver=False)
        name_bearing = {'Clock': 1, 'Control Center': 1, 'SystemUIServer': 1}  # fast user switching item
        for extras in (name_bearing, {}):  # an added name-bearing extra, or the pinned items removed
            self.assertIn('PF-11', self.failed(self.run_preflight(digest, host=FakeHost(digest, settings=base | {'menuExtras': extras}))))

    def m1_manifest(self, digest):
        m = manifest(digest)
        m['approval'] = 'https://github.com/modelplan/modelplan/issues/570#issuecomment-3'
        return m

    def test_abc_layout_arrangement(self):
        digest = write_artifact(self.artifacts, NAME)
        a = dict(x=0, y=0, width=1512, height=982, scale=2, main=True)
        b = dict(x=1512, y=0, width=1920, height=1080, scale=1, main=False)
        c = dict(x=-1600, y=-900, width=1600, height=900, scale=1, main=False)
        env = {'MODELPLAN_VERIFICATION_HOST': 'dev-mac'}
        good = FakeHost(digest, displays=[a, b, c], environ=env)
        check = [x for x in self.run_preflight(digest, lane='M1', layout='abc', host=good,
                                               manifest=self.m1_manifest(digest))['checks'] if x['id'] == 'PF-11'][0]
        self.assertEqual(check['status'], 'PASS', check['detail'])
        for displays in ([a, b, c | dict(scale=2)], [a, b | dict(x=-1920), c], [a, b]):
            host = FakeHost(digest, displays=displays, environ=env)
            self.assertIn('PF-11', self.failed(self.run_preflight(digest, lane='M1', layout='abc', host=host,
                                                                  manifest=self.m1_manifest(digest))))

    def test_clean_state(self):
        digest = write_artifact(self.artifacts, NAME)
        for host in (FakeHost(digest, executables=[(9, '/Applications/X.app/Contents/MacOS/ModelPlanCommunity')]),
                     FakeHost(digest, executables=[(9, '/opt/runner/bin/Runner.Worker')]),
                     FakeHost(digest, booking={'head': dict(state='started', lane='M1')})):
            self.assertIn('PF-12', self.failed(self.run_preflight(digest, host=host)))
        (self.scratch / 'modelplan-candidate-old').mkdir()
        self.assertIn('PF-12', self.failed(self.run_preflight(digest)))

    def test_invalid_manifest_fails_every_check(self):
        digest = write_artifact(self.artifacts, NAME)
        bad = manifest(digest); bad['profile'] = 'owner'
        receipt = self.run_preflight(digest, manifest=bad)
        self.assertEqual(self.failed(receipt), list(preflight.CHECKS))

    def test_build_txt_format_from_pr_551(self):
        fields, sums = preflight.parse_build(f'sourceSHA={SHA}\nrunID=1\nrunAttempt=2\n{"f" * 64}  {preflight.INNER}\n')
        self.assertEqual(fields, dict(sourceSHA=SHA, runID='1', runAttempt='2'))
        self.assertEqual(sums, {preflight.INNER: 'f' * 64})
        with self.assertRaises(ValueError):
            preflight.parse_build('sourceSHA=a\nsourceSHA=b\n')


class RepositoryDataTests(unittest.TestCase):
    def test_tier_table_has_every_plan_scenario(self):
        tiers = preflight.load_tiers((VERIFICATION / 'scenario-tiers.tsv').read_text())
        self.assertEqual(len(tiers), 108)
        counts = {t: sum(1 for v in tiers.values() if v == t) for t in set(tiers.values())}
        self.assertEqual(counts, {'T0': 14, 'T1': 15, 'T1P': 12, 'T2': 20, 'T3': 39, 'T4': 8})
        self.assertEqual(sum(1 for i in tiers if i.startswith('C-')), 27)

    def test_every_step_file_is_valid_and_gui_tier(self):
        tiers = preflight.load_tiers((VERIFICATION / 'scenario-tiers.tsv').read_text())
        files = sorted((VERIFICATION / 'scenarios').glob('*.json'))
        self.assertTrue({'D-01', 'D-14', 'V-01'} <= {f.stem for f in files})
        for path in files:
            with self.subTest(path=path.name):
                self.assertEqual(verify_steps.problems(json.loads(path.read_text()), path.stem), [])
                self.assertIn(tiers[path.stem], preflight.GUI_TIERS)

    def test_step_validator_rejects_bad_files(self):
        good = json.loads((VERIFICATION / 'scenarios' / 'V-01.json').read_text())
        bad = [dict(good, id='V-02'), dict(good, flavours=['dmg']), dict(good, profiles=[]),
               dict(good, steps=[dict(name='x', action='click-anything')]),
               dict(good, steps=[dict(name='x', action='capture-menubar', width=5000, height=40)]),
               dict(good, systemSettings=[]),  # set-appearance without its restore declaration
               dict(good, steps=[dict(name='a', action='dwell', seconds=1), dict(name='a', action='dwell', seconds=1)]),
               dict(good, extra=True)]
        for step in bad:
            self.assertNotEqual(verify_steps.problems(step, 'V-01'), [])

    def test_layouts_file_names_both_layouts(self):
        layouts = json.loads((VERIFICATION / 'layouts.json').read_text())
        self.assertEqual(sorted(layouts['layouts']), ['abc', 'single'])
        self.assertEqual(sorted(layouts['systemBaseline']),
                         ['appearance', 'dockAutohide', 'dockOrientation', 'menuExtras', 'reduceMotion', 'voiceOver'])
        self.assertEqual(layouts['systemBaseline']['menuExtras'],
                         {'Clock': 1, 'Control Center': 1})  # Apple items only: no name-bearing extra


if __name__ == '__main__':
    unittest.main()
