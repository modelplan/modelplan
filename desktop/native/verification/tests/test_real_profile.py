# SPDX-License-Identifier: MIT
"""Real-profile mode (owner decision 2026-11-05): admission gating, real-HOME isolation in
launch.py, packaged_candidate's real template, the relaunch supervision seam, and the status-menu
fixed action IDs. Linux-safe: every macOS-only path is injected or faked."""
import hashlib
import json
import os
from pathlib import Path
import sys
import tempfile
import time
import unittest
from unittest import mock

BIN = Path(__file__).resolve().parents[1] / 'bin'
sys.path.insert(0, str(BIN))

import admission  # noqa: E402
import launch  # noqa: E402
import packaged_candidate  # noqa: E402
import verify_steps  # noqa: E402


def contract(profile, host):
    now = time.time()
    lease = dict(runID='run-1', epoch='epoch-1', notBefore=now - 1, expiresAt=now + 600,
                 guardianHeartbeatAt=now - 1, ownerPreempted=False, exclusive=True, guardian=True)
    release = dict(lease, **({'m1Released': True, 'approval': 'https://github.com/owner/repo/issues/1#issuecomment-1'}
                             if host == 'dev-mac'
                             else {'host': 'macci', 'releasedBy': 'V1',
                                   'coordinatorGo': 'https://github.com/owner/repo/issues/1#issuecomment-2'}))
    return dict(profile=profile, host=host, binarySHA256='a' * 64, argv=['subject'], requiredSeconds=60,
                lease=lease, release=release, stop=False,
                leasePath='lease.json', releasePath='release.json', stopPath='STOP')


class AdmissionRealProfileTests(unittest.TestCase):
    def test_real_profile_admits_only_on_the_m1_and_v1_hosts(self):
        now = time.time()
        for host in ('dev-mac', 'macci'):  # dev-mac is M1, macci is V1
            self.assertTrue(admission.validate(contract('real', host), now))
            self.assertTrue(admission.validate(contract('synthetic', host), now))
        bad = contract('real', 'dev-mac')
        bad['host'] = 'guest'  # a future host must not inherit the real mode silently
        with self.assertRaisesRegex(ValueError, 'real profile is allowed only'):
            admission.validate(bad, time.time())

    def test_unknown_profile_is_refused(self):
        with self.assertRaisesRegex(ValueError, 'profile must be synthetic or real'):
            admission.validate(contract('guest', 'dev-mac'), time.time())

    def test_relaunch_marker_needs_an_absolute_path_in_direct_mode(self):
        now = time.time()
        good = contract('synthetic', 'dev-mac') | dict(relaunchPath='/run/relaunch')
        self.assertTrue(admission.validate(good, now))
        for bad in ('relative', '', 5):
            with self.assertRaisesRegex(ValueError, 'relaunchPath'):
                admission.validate(contract('synthetic', 'dev-mac') | dict(relaunchPath=bad), now)
        mixed = contract('synthetic', 'dev-mac') | dict(relaunchPath='/run/relaunch', launchMode='launchservices')
        with self.assertRaisesRegex(ValueError, 'relaunch needs direct launch mode'):
            admission.validate(mixed, now)


class LaunchRealHomeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.scratch = Path(self.temp.name) / 'run' / 'tmp'

    def test_real_home_is_the_users_own_and_never_inside_scratch(self):
        home = Path(self.temp.name) / 'Users' / 'tester'
        home.mkdir(parents=True)
        with mock.patch.dict(os.environ, HOME=str(home), CFFIXED_USER_HOME='/stray', PROVIDER_KEY='k'):
            self.assertEqual(launch.real_home(self.scratch), home.resolve())
            env = launch.real_env()
            self.assertEqual(env['HOME'], str(home))
            self.assertEqual(env['PROVIDER_KEY'], 'k')  # the user's own variables pass through
            self.assertNotIn('CFFIXED_USER_HOME', env)  # a stray override must never half-redirect
        with mock.patch.dict(os.environ, HOME=str(self.scratch / 'deep' / 'home')):
            self.assertRaisesRegex(ValueError, 'outside run scratch', launch.real_home, self.scratch)
        with mock.patch.dict(os.environ, HOME=str(self.scratch)):
            self.assertRaisesRegex(ValueError, 'outside run scratch', launch.real_home, self.scratch)
        for bad in ('', 'relative', '/'):
            with mock.patch.dict(os.environ, HOME=bad):
                self.assertRaisesRegex(ValueError, 'absolute HOME', launch.real_home, self.scratch)

    def test_synthetic_env_still_redirects_home_and_cffixed(self):
        env = launch.subject_env(Path('/run/home'), Path('/run/tmp'))
        self.assertEqual(env, {'PATH': '/usr/bin:/bin', 'HOME': '/run/home',
                               'CFFIXED_USER_HOME': '/run/home', 'TMPDIR': '/run/tmp', 'LANG': 'en_US.UTF-8'})


class FakeChild:
    def __init__(self, pid=0):
        self.pid, self.lives, self.returncode = pid, 2, None

    def poll(self):
        return None if self.lives > 0 else 0

    def terminate(self):
        self.lives -= 1

    def wait(self, timeout=None):
        self.lives = 0


class SuperviseRelaunchTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.marker = Path(self.temp.name) / 'relaunch'
        self.marker.write_text('0')

    def test_relaunch_marker_respawns_and_announces_the_same_slot(self):
        child = FakeChild(pid=111)
        c = dict(stopPath='STOP', relaunchPath=str(self.marker))
        replacements, announced = [], []

        def spawn():
            new = FakeChild(pid=4242)
            replacements.append(new)
            return new

        def sleep(_):
            if not replacements:
                self.marker.write_text('1')  # the step requests one relaunch
            else:
                replacements[-1].lives = 0  # the relaunched subject then ends by itself

        with mock.patch.object(launch, 'stop_reason', return_value=None):
            outcome = launch.supervise(child, c, poll=0, clock=lambda: 1.0, sleep=sleep,
                                       spawn=spawn, announce=lambda token, pid: announced.append((token, pid)))
        self.assertIsNone(outcome)  # exit 0 semantics: the subject ended by itself
        self.assertEqual([new.pid for new in replacements], [4242])
        self.assertEqual(announced, [(1, 4242)])
        self.assertLessEqual(child.lives, 0)  # the first launch was ended deliberately, not leaked

    def test_stop_reason_still_wins_over_a_pending_relaunch(self):
        child = FakeChild()
        c = dict(stopPath='STOP', relaunchPath=str(self.marker))
        self.marker.write_text('3')
        with mock.patch.object(launch, 'stop_reason', return_value='deadline'):
            outcome = launch.supervise(child, c, poll=0, clock=lambda: 1.0, sleep=lambda _: None,
                                       spawn=lambda: FakeChild(), announce=lambda *a: (_ for _ in ()).throw(AssertionError()))
        self.assertEqual(outcome, 'deadline')

    def test_without_spawn_the_marker_is_ignored(self):
        child = FakeChild()
        c = dict(stopPath='STOP', relaunchPath=str(self.marker))
        self.marker.write_text('9')
        with mock.patch.object(launch, 'stop_reason', return_value=None):
            outcome = launch.supervise(child, c, poll=0, clock=lambda: 1.0,
                                       sleep=lambda _: setattr(child, 'lives', 0))
        self.assertIsNone(outcome)


class PackagedCandidateRealTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.archive = self.root / 'candidate.zip'; self.archive.write_bytes(b'synthetic')
        self.manifest = self.root / 'manifest.json'
        self.manifest.write_text(json.dumps({'sourceSHA': 'a' * 40, 'sha256': hashlib.sha256(b'synthetic').hexdigest()}))
        self.parent = self.root / 'scratch'; self.parent.mkdir()

    def template(self, profile, name='template.json'):
        path = self.root / name
        path.write_text(json.dumps(dict(profile=profile, host='dev-mac', launchMode='direct', requiredSeconds=60,
                                        leasePath=str(self.root / 'lease.json'), releasePath=str(self.root / 'release.json'),
                                        stopPath=str(self.root / 'STOP'), subjectPidPath=str(self.root / 'subject.json'),
                                        candidateCleanupReceipt=str(self.root / 'cleanup.json'),
                                        expectedLease=dict(runID='r', epoch='e'))))
        return path

    def test_real_template_records_mode_and_never_creates_a_home(self):
        home = self.root / 'Users' / 'tester'; home.mkdir(parents=True)
        with mock.patch.dict(os.environ, HOME=str(home)):
            record = packaged_candidate.prepare(self.archive, self.manifest, self.template('real'),
                                                self.parent, self.root / 'registry.json')
        self.assertEqual(record['profile'], 'real')
        config = json.loads(Path(record['launchConfig']).read_text())
        self.assertEqual(config['profile'], 'real')
        self.assertNotIn('syntheticHome', config)  # the real HOME is the user's own, never created here
        self.assertTrue(config['syntheticTmp'].startswith(record['registry']['root']))
        self.assertFalse(Path(home, 'tmp').exists())
        inside = self.parent / 'home-inside'
        with mock.patch.dict(os.environ, HOME=str(inside)):
            self.assertRaisesRegex(ValueError, 'outside candidate scratch',
                                   packaged_candidate.prepare, self.archive, self.manifest,
                                   self.template('real', 'template2.json'), self.parent, self.root / 'registry2.json')

    def test_synthetic_template_still_gets_its_throwaway_home(self):
        record = packaged_candidate.prepare(self.archive, self.manifest, self.template('synthetic'),
                                            self.parent, self.root / 'registry.json')
        config = json.loads(Path(record['launchConfig']).read_text())
        self.assertEqual(config['syntheticHome'], str(Path(record['registry']['root']) / 'home'))
        self.assertEqual(record['profile'], 'synthetic')

    def test_unknown_profile_or_launch_mode_is_refused(self):
        cases = (self.template('guest', 'guest.json'),)
        for path in cases:
            self.assertRaisesRegex(ValueError, 'direct synthetic or real',
                                   packaged_candidate.prepare, self.archive, self.manifest,
                                   path, self.parent, self.root / 'r3.json')
        mixed = json.loads(self.template('real', 'mixed.json').read_text())
        mixed['launchMode'] = 'launchservices'
        self.root.joinpath('mixed.json').write_text(json.dumps(mixed))
        self.assertRaisesRegex(ValueError, 'direct synthetic or real',
                               packaged_candidate.prepare, self.archive, self.manifest,
                               self.root / 'mixed.json', self.parent, self.root / 'r4.json')


class StepFileMenuActionTests(unittest.TestCase):
    def test_status_menu_menu_action_is_a_slug_and_fixed_ids_are_documented(self):
        def step(action):
            return dict(schemaVersion=1, id='V-02', spec='spec-cockpit', summary='s', flavours=['test'],
                        profiles=['synthetic'], layout='any', launch='running', estimatedSeconds=30,
                        systemSettings=[], steps=[dict(name='menu', action='status-menu',
                                                       item='Quit', menuAction=action)], review='r')
        self.assertEqual(verify_steps.problems(step('quit')), [])
        self.assertEqual(verify_steps.problems(step('hide')), [])  # valid slug; refused at run time instead
        self.assertTrue(any('lowercase slug' in p and 'no fixed action ID' in p
                            for p in verify_steps.problems(step('Not A Slug'))))
