# SPDX-License-Identifier: MIT
"""MacCI host role (V1 + coordinator GO release), launch modes and never-registered closure.

Synthetic ledgers and fixtures only. The LaunchServices leg replaces /usr/bin/open with a fake that
starts the bundle executable the way LaunchServices would (fresh environment from --env only), so
the bundle, PID discovery by exact executable path, registration and guardian closure run for real
on Linux. Whether a LaunchServices launch actually becomes key/active can only be checked on MacCI.
"""
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

BIN = Path(__file__).resolve().parents[1] / 'bin'
sys.path.insert(0, str(BIN))
import admission  # noqa: E402
import book  # noqa: E402
import guardian  # noqa: E402
import launch  # noqa: E402
import process_scan  # noqa: E402
import release  # noqa: E402

PY = sys.executable
GO = 'https://github.com/example-owner/example-repo/issues/570#issuecomment-3456789012'
APPROVAL = 'https://example.test/coordinator#issuecomment-1'
MACCI = {release.HOST_ENV: 'macci'}
FAKE_OPEN = '''import os, plistlib, subprocess, sys
args = sys.argv[1:]; env = {}; out = err = None; rest = []
while args:
    a = args.pop(0)
    if a in ('-n', '-W'): continue
    if a == '--env': k, _, v = args.pop(0).partition('='); env[k] = v; continue
    if a == '--stdout': out = args.pop(0); continue
    if a == '--stderr': err = args.pop(0); continue
    if a == '--args': rest = args; break
    bundle = a
if MODE == 'fail': sys.exit(1)  # LaunchServices refused: the subject never starts
if MODE == 'lserr':  # what open prints on MacCI for the ad-hoc app
    sys.stderr.write('_LSOpenURLsWithCompletionHandler() failed for the application ' + bundle + ' with error -10810.\\n'); sys.exit(1)
info = plistlib.loads(open(os.path.join(bundle, 'Contents', 'Info.plist'), 'rb').read())
exe = os.path.join(bundle, 'Contents', 'MacOS', info['CFBundleExecutable'])
open(out + '.env.json', 'w').write(__import__('json').dumps(env))  # what open was asked to pass
with open(out, 'ab') as o, open(err, 'ab') as e:
    sys.exit(subprocess.Popen([exe, *rest], env=env, stdout=o, stderr=e, start_new_session=True).wait())
'''
FAKE_UNZIP = '''import os, stat, sys, zipfile
archive, out = sys.argv[-2:]
with zipfile.ZipFile(archive) as z:
    for info in z.infolist():
        mode = info.external_attr >> 16; target = os.path.join(out, info.filename)
        os.makedirs(os.path.dirname(target), exist_ok=True)
        if stat.S_ISLNK(mode): os.symlink(z.read(info).decode(), target); continue
        if info.is_dir(): os.makedirs(target, exist_ok=True); continue
        open(target, 'wb').write(z.read(info)); os.chmod(target, mode & 0o777 or 0o644)
'''
FAKE_CODESIGN = '''import sys
if '-dv' in sys.argv:
    sys.stderr.write(globals().get('DV_TEXT', 'Executable=x\\nSignature=adhoc\\n')); sys.exit(globals().get('DV_RC', 0))
sys.exit(0 if VALID else 1)
'''


def write_app_zip(archive, app_name='FakeApp', executable=None, extra=(), links=()):
    """A zip of `<app_name>.app` with Info.plist and MacOS/<app_name>; `extra` adds top-level names."""
    import zipfile
    with zipfile.ZipFile(archive, 'w') as z:
        info = plistlib.dumps(dict(CFBundleExecutable=app_name, CFBundleIdentifier='org.example.synthetic', CFBundlePackageType='APPL'))
        z.writestr(f'{app_name}.app/Contents/Info.plist', info)
        entry = zipfile.ZipInfo(f'{app_name}.app/Contents/MacOS/{app_name}'); entry.external_attr = (0o100755 << 16)
        z.writestr(entry, Path(executable).read_bytes() if executable else b'#!/bin/sh\n')
        for name in extra:
            z.writestr(name, b'x')
        for name, target in links:
            link = zipfile.ZipInfo(f'{app_name}.app/{name}'); link.external_attr = (0o120777 << 16)
            z.writestr(link, target)
    return archive


def native_sleeper(test, path):
    """A real native binary at `path` (never a script: its executable would be the interpreter).
    Linux copies /bin/sleep; macOS compiles one, because launch constraints stop copied system
    binaries from running outside their original location."""
    path.parent.mkdir(parents=True, exist_ok=True)
    if sys.platform != 'darwin':
        shutil.copyfile('/bin/sleep', path); path.chmod(0o755)
        return path
    source = path.with_name(path.name + '.c')
    source.write_text('#include <unistd.h>\nint main(void) { sleep(60); return 0; }\n')
    compiler = shutil.which('cc') or shutil.which('clang')
    if compiler is None or subprocess.run([compiler, '-o', str(path), str(source)], capture_output=True).returncode != 0:
        test.skipTest('no C compiler for a native in-scope binary')
    source.unlink()
    return path


def alive(pid):
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    return guardian.identity(pid) is not None  # not a zombie


def wait_until(condition, timeout, message):
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        value = condition()
        if value:
            return value
        time.sleep(0.05)
    raise AssertionError(message)


class Fixture(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.now = time.time()
        self.ledger = book.Ledger(self.root / 'ledger.jsonl', clock=lambda: self.now)
        self.ident = self.ledger.request('V1', 'U11a', ['cold'])['id']
        self.lease = self.ledger.start(self.ident, 'V1', 'run', 'epoch')
        self.output = self.root / 'release.json'


class MacCIRelease(Fixture):
    def issue(self, **fields):
        return release.issue(self.ledger, self.ident, self.lease, self.output,
                             **(dict(lane='V1', host='macci', go=GO) | fields))

    def contract(self):
        lease = self.lease | dict(guardian=True)
        lease_path = self.root / 'lease.json'; lease_path.write_text(json.dumps(lease))
        return dict(profile='synthetic', host='macci', binarySHA256='a' * 64, argv=['synthetic-app'],
                    requiredSeconds=60, leasePath=str(lease_path), releasePath=str(self.output),
                    stopPath=str(self.root / 'stop'),
                    booking=dict(id=self.ident, lane='V1', unit='U11a', scenario='cold', ledger=str(self.ledger.path)))

    def test_v1_with_coordinator_go_on_macci_is_released_and_admitted(self):
        record = self.issue()
        self.assertEqual(record, {k: self.lease[k] for k in release.IDENTITY_FIELDS}
                         | dict(host='macci', releasedBy='V1', coordinatorGo=GO))
        self.assertNotIn('m1Released', record)
        with self.assertRaises(FileExistsError):
            self.issue()  # never overwritten
        with patch.dict(os.environ, MACCI):
            self.assertEqual(admission.load_and_admit(self.contract())['release'], record)

    def test_v1_cannot_release_on_the_dev_mac(self):
        for fields in (dict(host='dev-mac', go=None, approval=APPROVAL), dict(host='dev-mac'),
                       dict(host='dev-mac', go=None)):
            with self.subTest(fields=fields), self.assertRaisesRegex(ValueError, 'only lane M1'):
                self.issue(**fields)
        with self.assertRaisesRegex(ValueError, 'only V1 on MacCI'):
            self.issue(lane='M1')  # M1 does not run on MacCI either
        with self.assertRaisesRegex(ValueError, 'does not replace the M1 release'):
            self.issue(lane='M1', host='dev-mac', approval=APPROVAL)
        self.assertFalse(self.output.exists())
        # Declaring --host macci on a machine whose role is the dev Mac is refused (CLI, env unset).
        lease_path = self.root / 'cli-lease.json'; lease_path.write_text(json.dumps(self.lease))
        env = {k: v for k, v in os.environ.items() if k != release.HOST_ENV}
        command = [PY, str(BIN / 'release.py'), '--ledger', str(self.ledger.path), '--id', self.ident,
                   '--lease', str(lease_path), '--output', str(self.output)]
        for flags in (['--lane', 'V1', '--host', 'macci', '--coordinator-go', GO],
                      ['--lane', 'V1', '--coordinator-go', GO], ['--lane', 'V1', '--approval', APPROVAL]):
            result = subprocess.run(command + flags, capture_output=True, text=True, env=env)
            self.assertEqual(result.returncode, 2, result.stdout)
            self.assertFalse(self.output.exists())
        result = subprocess.run(command + ['--lane', 'V1', '--host', 'macci', '--coordinator-go', GO],
                                capture_output=True, text=True, env=env | MACCI)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(self.output.read_text())['coordinatorGo'], GO)

    def test_missing_or_malformed_go_is_refused(self):
        for go in (None, '', '3456789012', '#issuecomment-1', 'http://github.com/o/r/issues/570#issuecomment-1',
                   'https://example.test/o/r/issues/570#issuecomment-1', 'https://github.com/o/r/pull/570#issuecomment-1',
                   'https://github.com/o/r/issues/570#issuecomment-', 'https://github.com/o/r/issues/570#issuecomment-1x',
                   'https://github.com/o/r/issues/570#issuecomment-1 ', 'https://user@github.com/o/r/issues/570#issuecomment-1'):
            with self.subTest(go=go), self.assertRaisesRegex(ValueError, 'coordinatorGo'):
                self.issue(go=go)
        with self.assertRaisesRegex(ValueError, 'not an approval URL'):
            self.issue(approval=APPROVAL)
        self.assertFalse(self.output.exists())

    def test_admission_checks_host_and_go_format(self):
        record = self.issue()
        c = self.contract()
        for bad in (record | dict(coordinatorGo='12345'), {k: v for k, v in record.items() if k != 'coordinatorGo'},
                    record | dict(releasedBy='M1'), record | dict(m1Released=True), record | dict(epoch='other')):
            self.output.write_text(json.dumps(bad))
            with self.subTest(bad=bad), patch.dict(os.environ, MACCI), self.assertRaises(ValueError):
                admission.load_and_admit(c)
        self.output.write_text(json.dumps(record))
        with patch.dict(os.environ, {release.HOST_ENV: ''}), self.assertRaisesRegex(ValueError, 'host role mismatch'):
            admission.load_and_admit(c)  # a MacCI run config on a dev-Mac host
        with patch.dict(os.environ, {release.HOST_ENV: ''}), self.assertRaisesRegex(ValueError, 'M1 release missing'):
            admission.load_and_admit(c | dict(host='dev-mac'))  # a MacCI receipt never admits on the dev Mac
        self.output.write_text(json.dumps({k: self.lease[k] for k in release.IDENTITY_FIELDS}
                                          | dict(m1Released=True, approval=APPROVAL)))
        with patch.dict(os.environ, MACCI), self.assertRaisesRegex(ValueError, 'MacCI V1 release missing'):
            admission.load_and_admit(c)  # and an M1 receipt never admits on MacCI


class LaunchModes(unittest.TestCase):
    def contract(self, **fields):
        lease = dict(runID='r', epoch='e', notBefore=1000, expiresAt=1900, guardianHeartbeatAt=1019.5,
                     ownerPreempted=False, exclusive=True)
        return dict(profile='synthetic', lease=lease, release=lease | dict(m1Released=True, approval=APPROVAL),
                    requiredSeconds=60, stop=False, argv=['synthetic-app'], binarySHA256='a' * 64) | fields

    def test_launch_mode_is_validated(self):
        for mode in (None, 'direct', 'launchservices'):
            c = self.contract() if mode is None else self.contract(launchMode=mode)
            self.assertTrue(launch.validate(c, 1020))
        for mode in ('', 'open', 'LaunchServices', 1):
            with self.subTest(mode=mode), self.assertRaisesRegex(ValueError, 'launchMode'):
                launch.validate(self.contract(launchMode=mode), 1020)
        with self.assertRaisesRegex(ValueError, 'host'):
            launch.validate(self.contract(host='laptop'), 1020)

    def test_evidence_manifest_records_launch_mode(self):
        import evidence
        with tempfile.TemporaryDirectory() as d:
            c = dict(headSHA='a' * 40, profile='synthetic', attributionMethod='fixture',
                     scenarios=[dict(id='U5-A', outcome='pass')])
            self.assertEqual(evidence.manifest(c, Path(d))['launchMode'], 'direct')
            self.assertEqual(evidence.manifest(c | dict(launchMode='launchservices'), Path(d))['launchMode'], 'launchservices')
            with self.assertRaises(ValueError):
                evidence.manifest(c | dict(launchMode='other'), Path(d))

    def test_launchservices_refused_without_open_before_any_resource(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d); cfg = root / 'run.json'
            c = dict(launchMode='launchservices', syntheticHome=str(root / 'home'), syntheticTmp=str(root / 'tmp'))
            cfg.write_text(json.dumps(c))
            with patch.object(sys, 'argv', ['launch', '--config', str(cfg), '--execute']), \
                    patch.object(launch, 'load_and_admit', side_effect=lambda x: x), \
                    patch.object(launch, 'OPEN', [str(root / 'no-open')]), \
                    patch.object(launch.subprocess, 'Popen') as popen:
                with self.assertRaisesRegex(ValueError, 'needs macOS'):
                    launch.main()
                popen.assert_not_called()
            self.assertFalse((root / 'home').exists())

    def test_bundle_is_a_verified_copy_with_minimal_info_plist(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d); binary = root / 'FakeApp'; binary.write_bytes(b'synthetic-binary'); tmp = root / 'tmp'; tmp.mkdir()
            c = dict(binarySHA256=hashlib.sha256(b'synthetic-binary').hexdigest())
            bundle = launch.make_bundle(c, binary, tmp)
            self.assertEqual(bundle['exe'], tmp / '.launchservices' / 'FakeApp.app' / 'Contents' / 'MacOS' / 'FakeApp')
            self.assertFalse(bundle['exe'].is_symlink())
            info = plistlib.loads((bundle['app'] / 'Contents' / 'Info.plist').read_bytes())
            self.assertEqual((info['CFBundleExecutable'], info['CFBundlePackageType'], info['LSUIElement']), ('FakeApp', 'APPL', True))
            self.assertEqual(bundle['evidence']['bundledSHA256'], c['binarySHA256'])
            for bad in (dict(bundleIdentifier='bad id'), dict(bundleUIElement='yes'), dict(bundleSign='developer-id'),
                        dict(bundleResources=['relative'])):
                with self.subTest(bad=bad), self.assertRaises(ValueError):
                    launch.make_bundle(c | bad, binary, root / 'other')
            with self.assertRaisesRegex(ValueError, 'bundled binary identity'):
                launch.make_bundle(dict(binarySHA256='b' * 64), binary, root / 'tmp2')

    def test_direct_mode_records_mode_and_scan_scope_in_the_registration(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d); pid_file = root / 'subject.pid'
            c = dict(syntheticHome=str(root / 'home'), syntheticTmp=str(root / 'tmp'), subjectPidPath=str(pid_file),
                     argv=[PY, '-c', 'pass'], binarySHA256=hashlib.sha256(Path(PY).resolve().read_bytes()).hexdigest(),
                     lease=dict(runID='r', epoch='e'), stopPath=str(root / 'STOP'), leasePath=str(root / 'lease.json'))
            cfg = root / 'run.json'; cfg.write_text(json.dumps(c))
            with patch.object(sys, 'argv', ['launch', '--config', str(cfg), '--execute']), \
                    patch.object(launch, 'load_and_admit', side_effect=lambda x: x), \
                    patch.object(launch, 'stop_reason', return_value=None), \
                    patch('builtins.print') as printed, self.assertRaises(SystemExit) as done:
                launch.main()
            self.assertEqual(done.exception.code, 0)
            lines = [json.loads(call.args[0]) for call in printed.call_args_list]
            self.assertEqual([x['launchMode'] for x in lines], ['direct', 'direct'])
            record = json.loads(pid_file.read_text())
            self.assertEqual((record['state'], record['launchMode']), ('running', 'direct'))
            self.assertNotIn('executable', record['scan'])  # the pinned binary may run outside the run
            self.assertEqual(record['scan']['prefix'], os.path.realpath(root / 'tmp'))
            self.assertNotIn('home', record['scan'])
            gate = record['scan']['helpers']  # the exec gate, recorded by PID plus start time at spawn
            self.assertEqual([h['pid'] for h in gate], [lines[0]['ownedPID']])
            self.assertEqual(set(gate[0]), {'pid', 'startSeconds', 'startMicroseconds'})

    def test_direct_scope_never_matches_the_pinned_binary_running_outside_the_run(self):
        # The launcher dies before registering; a same-user process of the same pinned binary outside
        # this run must survive the guardian's never-started closure.
        with tempfile.TemporaryDirectory() as d:
            root = Path(d); pid_file = root / 'subject.pid'
            binary = native_sleeper(self, root / 'build' / 'App')
            outsider = subprocess.Popen([str(binary), '60'])
            self.addCleanup(lambda: (outsider.kill(), outsider.wait()))
            wait_until(lambda: guardian.identity(outsider.pid), 5, 'outsider not visible')
            c = dict(syntheticHome=str(root / 'home'), syntheticTmp=str(root / 'tmp'), subjectPidPath=str(pid_file),
                     argv=[str(binary), '60'], binarySHA256=hashlib.sha256(binary.read_bytes()).hexdigest(),
                     lease=dict(runID='r', epoch='e'), stopPath=str(root / 'STOP'), leasePath=str(root / 'lease.json'))
            cfg = root / 'run.json'; cfg.write_text(json.dumps(c))
            with patch.object(sys, 'argv', ['launch', '--config', str(cfg), '--execute']), \
                    patch.object(launch, 'load_and_admit', side_effect=lambda x: x), \
                    patch.object(launch, 'register', side_effect=ValueError('launcher lost before registering')), \
                    self.assertRaises(SystemExit):
                launch.main()
            record = json.loads(pid_file.read_text())
            self.assertEqual(record['state'], 'launching')
            self.assertEqual([p['pid'] for p in process_scan.scan(record['scan'], guardian.identity)], [])
            dead = subprocess.Popen([PY, '-c', 'pass']); gone = guardian.identity(dead.pid) or dict(pid=dead.pid, startSeconds=-1, startMicroseconds=0); dead.wait()
            pid_file.write_text(json.dumps(record | dict(launcher=gone)))
            self.assertEqual(guardian.close(pid_file, settle=0), (True, 'never-started'))
            self.assertIsNone(outsider.poll())  # never signalled


@unittest.skipUnless(sys.platform.startswith('linux') and Path('/bin/sleep').exists(),
                     'the fake LaunchServices leg needs /proc and a real executable to bundle')
class MacCISequence(unittest.TestCase):
    """book -> guardian -> V1 release with GO -> launch.py (launchservices) -> closure -> finish."""

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name); self.procs = []
        self.ledger = self.root / 'ledger.jsonl'
        self.app = self.root / 'FakeApp'; shutil.copyfile('/bin/sleep', self.app); self.app.chmod(0o755)
        self.env = dict(os.environ, **MACCI)
        self.paths = {k: self.root / v for k, v in dict(lease='lease.json', release='release.json',
                                                         stop='STOP', pid='subject.pid').items()}

    def tearDown(self):
        for proc in self.procs:
            if proc.poll() is None:
                proc.kill(); proc.wait(10)
        for found in process_scan.scan(process_scan.scope_for(prefix=self.root / 'tmp'), guardian.identity):
            os.kill(found['pid'], 9)
        self.temp.cleanup()

    def cli(self, *args):
        return subprocess.run([PY, *map(str, args)], capture_output=True, text=True, timeout=120, env=self.env)

    def book(self, *args):
        return self.cli(BIN / 'book.py', '--ledger', self.ledger, *args)

    def start(self, open_mode, subject='binary', mode='launchservices'):
        ident = json.loads(self.book('request', '--lane', 'V1', '--unit', 'U11a', '--scenario', 'cold', '--minutes', '2', '--host', 'macci').stdout)['id']
        started = self.book('start', '--id', ident, '--lane', 'V1', '--run-id', 'run-macci', '--epoch', 'epoch-macci', '--host', 'macci')
        self.assertEqual(started.returncode, 0, started.stderr)
        self.paths['lease'].write_text(started.stdout)
        self.guardian_out = self.root / 'guardian.out'
        with self.guardian_out.open('w') as out:
            self.guardian = subprocess.Popen([PY, str(BIN / 'guardian.py'), '--lease', str(self.paths['lease']),
                                              '--stop', str(self.paths['stop']), '--subject-pid-file', str(self.paths['pid'])],
                                             stdout=out, stderr=subprocess.DEVNULL, env=self.env)
        self.procs.append(self.guardian)
        wait_until(lambda: json.loads(self.paths['lease'].read_text()).get('guardian'), 10, 'guardian did not start')
        released = self.cli(BIN / 'release.py', '--ledger', self.ledger, '--id', ident, '--lane', 'V1', '--host', 'macci',
                            '--lease', self.paths['lease'], '--output', self.paths['release'], '--coordinator-go', GO)
        self.assertEqual(released.returncode, 0, released.stderr)
        fake_open = self.root / f'open-{open_mode}.py'; fake_open.write_text(f'MODE = {open_mode!r}\n' + FAKE_OPEN)
        fake_unzip = self.root / 'unzip.py'; fake_unzip.write_text(FAKE_UNZIP)
        fake_codesign = self.root / 'codesign.py'; fake_codesign.write_text('VALID = True\n' + FAKE_CODESIGN)
        target = write_app_zip(self.root / 'ModelPlan.zip', executable=self.app) if subject == 'app-zip' else self.app
        config = self.root / 'run.json'
        config.write_text(json.dumps(dict(
            profile='synthetic', host='macci', launchMode=mode, subjectKind=subject,
            binarySHA256=hashlib.sha256(target.read_bytes()).hexdigest(), argv=[str(target), '600'],
            leasePath=str(self.paths['lease']), releasePath=str(self.paths['release']), stopPath=str(self.paths['stop']),
            syntheticHome=str(self.root / 'home'), syntheticTmp=str(self.root / 'tmp'),
            subjectPidPath=str(self.paths['pid']), requiredSeconds=30,
            booking=dict(id=ident, lane='V1', unit='U11a', scenario='cold', ledger=str(self.ledger)))))
        runner = (f'import sys; sys.path.insert(0, {str(BIN)!r}); import launch; '
                  f'launch.OPEN = [sys.executable, {str(fake_open)!r}]; '
                  f'launch.UNZIP = [sys.executable, {str(fake_unzip)!r}]; '
                  f'launch.CODESIGN = [sys.executable, {str(fake_codesign)!r}]; '
                  f'sys.argv = ["launch.py", "--config", {str(config)!r}, "--execute"]; launch.main()')
        self.out, self.err = self.root / 'launch.out', self.root / 'launch.err'
        with self.out.open('w') as out, self.err.open('w') as err:
            self.controller = subprocess.Popen([PY, '-c', runner], stdout=out, stderr=err, env=self.env)
        self.procs.append(self.controller)
        return ident

    def finish(self, ident):
        return self.book('finish', '--id', ident, '--lane', 'V1', '--run-id', 'run-macci', '--epoch', 'epoch-macci', '--cleaned', '--host', 'macci')

    def test_launchservices_subject_registers_by_bundle_path_and_closes(self):
        ident = self.start('ok')
        def registered():
            try:
                record = json.loads(self.paths['pid'].read_text())
            except (OSError, ValueError):
                return None
            return record if record.get('state') == 'running' else None
        record = wait_until(registered, 15, 'LaunchServices subject never registered')
        bundled = self.root / 'tmp' / '.launchservices' / 'FakeApp.app' / 'Contents' / 'MacOS' / 'FakeApp'
        self.assertEqual(os.readlink(f'/proc/{record["pid"]}/exe'), str(bundled))  # found by exact path
        self.assertNotEqual(record['pid'], self.controller.pid)
        self.assertEqual(record['launchMode'], 'launchservices')
        first = wait_until(lambda: self.out.read_text().splitlines(), 10, 'no launch report')
        report = json.loads(first[0])
        self.assertEqual((report['launchMode'], report['ownedPID'], report['bundleSign']), ('launchservices', record['pid'], 'none'))
        self.paths['stop'].write_text('')
        self.assertEqual(self.controller.wait(30), 3, self.err.read_text())  # stopped by supervision
        self.assertEqual(self.guardian.wait(30), 0)
        self.assertEqual(json.loads(self.guardian_out.read_text()),
                         dict(guardian='stopped', subjectClosed=True, subject='registered'))
        self.assertFalse(alive(record['pid']))
        self.assertEqual(process_scan.scan(process_scan.scope_for(prefix=self.root / 'tmp'), guardian.identity), [])
        self.assertEqual(len(record['scan']['helpers']), 1)  # the open helper, by PID plus start time
        final = json.loads(self.out.read_text().splitlines()[-1])
        self.assertEqual((final['stoppedBy'], final['launchMode']), ('stop-file', 'launchservices'))
        self.assertEqual(self.finish(ident).returncode, 0)

    def test_full_app_zip_is_verified_extracted_and_launched_with_synthetic_home(self):
        ident = self.start('ok', subject='app-zip')
        def registered():
            try:
                record = json.loads(self.paths['pid'].read_text())
            except (OSError, ValueError):
                return None
            return record if record.get('state') == 'running' else None
        record = wait_until(registered, 15, 'app subject never registered')
        app = self.root / 'tmp' / '.launchservices' / 'app' / 'FakeApp.app'
        self.assertEqual(os.readlink(f'/proc/{record["pid"]}/exe'), str(app / 'Contents' / 'MacOS' / 'FakeApp'))
        self.assertEqual(record['scan']['prefix'], str(app))
        report = json.loads(wait_until(lambda: self.out.read_text().splitlines(), 10, 'no launch report')[0])
        self.assertEqual((report['subjectKind'], report['codeSignature'], report['bundleIdentifier']),
                         ('app-zip', 'adhoc', 'org.example.synthetic'))
        self.assertEqual(report['archiveSHA256'], hashlib.sha256((self.root / 'ModelPlan.zip').read_bytes()).hexdigest())
        env = json.loads((app.parent / 'subject.stdout.env.json').read_text())
        home = str(self.root / 'home')
        self.assertEqual((env['HOME'], env['CFFIXED_USER_HOME'], env['TMPDIR']), (home, home, str(self.root / 'tmp')))
        self.paths['stop'].write_text('')
        self.assertEqual(self.controller.wait(30), 3, self.err.read_text())
        self.assertEqual(self.guardian.wait(30), 0)
        self.assertFalse(alive(record['pid']))
        self.assertEqual(self.finish(ident).returncode, 0)

    def test_full_app_zip_in_direct_mode_execs_the_extracted_main_executable(self):
        ident = self.start('unused', subject='app-zip', mode='direct')
        def registered():
            try:
                record = json.loads(self.paths['pid'].read_text())
            except (OSError, ValueError):
                return None
            return record if record.get('state') == 'running' else None
        record = wait_until(registered, 15, 'direct app subject never registered')
        app = self.root / 'tmp' / '.launchservices' / 'app' / 'FakeApp.app'
        exe = app / 'Contents' / 'MacOS' / 'FakeApp'
        wait_until(lambda: os.readlink(f'/proc/{record["pid"]}/exe') == str(exe), 5, 'gate did not exec the bundle executable')
        self.assertEqual(record['pid'], json.loads(wait_until(lambda: self.out.read_text().splitlines(), 10, 'no report')[0])['ownedPID'])
        self.assertEqual((record['launchMode'], record['scan']['executable'], record['scan']['prefix']), ('direct', str(exe), str(app)))
        report = json.loads(self.out.read_text().splitlines()[0])
        self.assertEqual((report['subjectKind'], report['codeSignature']), ('app-zip', 'adhoc'))
        found = process_scan.scan(record['scan'], guardian.identity)
        self.assertEqual([x['pid'] for x in found], [record['pid']])  # the subject itself, by exact path
        self.paths['stop'].write_text('')
        self.assertEqual(self.controller.wait(30), 3, self.err.read_text())
        self.assertEqual(self.guardian.wait(30), 0)
        self.assertFalse(alive(record['pid']))
        self.assertEqual(self.finish(ident).returncode, 0)

    def test_launch_services_error_is_recorded_and_the_run_closes_as_never_started(self):
        ident = self.start('lserr', subject='app-zip')
        self.assertEqual(self.controller.wait(60), 3)
        failure = json.loads([x for x in self.err.read_text().splitlines() if x.startswith('{')][-1])
        self.assertEqual((failure['registered'], failure['openExit'], failure['launchServicesError']), (False, 1, -10810))
        self.assertEqual(self.guardian.wait(30), 0)
        self.assertEqual(json.loads(self.guardian_out.read_text())['subject'], 'never-started')
        self.assertEqual(self.finish(ident).returncode, 0)

    def test_subject_that_never_registers_is_scan_proven_and_finishes_cleaned(self):
        ident = self.start('fail')
        self.assertEqual(self.controller.wait(60), 3)
        self.assertIn('"registered": false', self.err.read_text())
        self.assertEqual(json.loads(self.paths['pid'].read_text())['state'], 'launching')
        # The launcher is gone before registering: the guardian ends the run, scans the project scope
        # (bundle path/prefix + recorded helpers) and reports the subject as never started.
        self.assertEqual(self.guardian.wait(30), 0)
        self.assertEqual(json.loads(self.guardian_out.read_text()),
                         dict(guardian='launcher-lost', subjectClosed=True, subject='never-started'))
        finish = self.finish(ident)
        self.assertEqual(finish.returncode, 0, finish.stderr)
        state = json.loads(self.book('status').stdout)
        self.assertEqual((state['head'], state['history'][-1]['state']), (None, 'finished'))


class FullAppSubject(unittest.TestCase):
    def setUp(self):
        self.dir = Path(tempfile.mkdtemp()); self.addCleanup(shutil.rmtree, self.dir, True)
        unzip = self.dir / 'unzip.py'; unzip.write_text(FAKE_UNZIP)
        for valid in (True, False):
            (self.dir / f'codesign-{valid}.py').write_text(f'VALID = {valid}\n' + FAKE_CODESIGN)
        self.patches = [patch.object(launch, 'UNZIP', [PY, str(unzip)]), patch.object(launch, 'CODESIGN', [PY, str(self.dir / 'codesign-True.py')])]
        for item in self.patches:
            item.start(); self.addCleanup(item.stop)

    def extract(self, archive, run='run', pin=None):
        tmp = self.dir / run; tmp.mkdir()
        return launch.extract_app(dict(binarySHA256=pin or hashlib.sha256(archive.read_bytes()).hexdigest()), archive, tmp)

    def test_subject_env_redirects_foundation_home_in_both_modes(self):
        env = launch.subject_env(self.dir / 'home', self.dir / 'tmp')
        self.assertEqual(env['CFFIXED_USER_HOME'], env['HOME'])
        self.assertEqual(env['HOME'], str(self.dir / 'home'))
        self.assertEqual(set(env), {'PATH', 'HOME', 'CFFIXED_USER_HOME', 'TMPDIR', 'LANG'})
        # direct mode passes the same environment to its exec-gated child
        with patch.object(launch.subprocess, 'Popen', side_effect=RuntimeError('stop here')) as popen, \
                patch.object(launch, 'mark_launching', return_value={}), \
                patch.object(launch, 'load_and_admit', side_effect=lambda x: x):
            binary = self.dir / 'bin'; binary.write_bytes(b'x')
            cfg = self.dir / 'run.json'
            cfg.write_text(json.dumps(dict(syntheticHome=str(self.dir / 'h'), syntheticTmp=str(self.dir / 't'),
                                           argv=[str(binary)], binarySHA256=hashlib.sha256(b'x').hexdigest(),
                                           subjectPidPath=str(self.dir / 'pid'))))
            with patch.object(sys, 'argv', ['launch', '--config', str(cfg), '--execute']), self.assertRaises(RuntimeError):
                launch.main()
        env = popen.call_args.kwargs['env']
        self.assertEqual((env['HOME'], env['CFFIXED_USER_HOME']), (str(self.dir / 'h'), str(self.dir / 'h')))

    def test_verified_zip_extracts_one_app_and_records_its_signature(self):
        app = self.extract(write_app_zip(self.dir / 'a.zip'))
        self.assertEqual(app['exe'], self.dir / 'run' / '.launchservices' / 'app' / 'FakeApp.app' / 'Contents' / 'MacOS' / 'FakeApp')
        self.assertEqual((app['evidence']['subjectKind'], app['evidence']['codeSignature']), ('app-zip', 'adhoc'))
        self.assertTrue((self.dir / 'run' / '.launchservices' / 'subject.zip').exists())  # extracted from the local copy

    def test_bad_archives_are_refused(self):
        with self.assertRaisesRegex(ValueError, 'archive identity'):
            self.extract(write_app_zip(self.dir / 'pin.zip'), run='pin', pin='0' * 64)
        with self.assertRaisesRegex(ValueError, 'exactly one top-level .app'):
            self.extract(write_app_zip(self.dir / 'two.zip', extra=['Other.app/x']), run='two')
        with self.assertRaisesRegex(ValueError, 'exactly one top-level .app'):
            self.extract(write_app_zip(self.dir / 'loose.zip', extra=['README']), run='loose')
        with self.assertRaisesRegex(ValueError, 'symlink leaves the bundle'):
            self.extract(write_app_zip(self.dir / 'link.zip', links=[('Contents/Resources', '/etc')]), run='link')
        with patch.object(launch, 'CODESIGN', [PY, str(self.dir / 'codesign-False.py')]), \
                self.assertRaisesRegex(ValueError, 'code signature does not verify'):
            self.extract(write_app_zip(self.dir / 'sig.zip'), run='sig')

    def test_signature_kind_needs_a_successful_explicit_codesign_report(self):
        for rc, text, kind in ((0, 'Executable=x\nSignature=adhoc\n', 'adhoc'),
                               (0, 'Executable=x\nAuthority=Developer ID Application: Example\n', 'identity'),
                               (0, 'Executable=x\n', 'unknown'), (0, '', 'unknown'), (0, 'Authority=\n', 'unknown'),
                               (1, 'Signature=adhoc\n', 'unknown'), (1, 'Authority=Example\n', 'unknown')):
            script = self.dir / f'codesign-dv-{rc}-{abs(hash(text))}.py'
            script.write_text(f'VALID = True\nDV_RC = {rc}\nDV_TEXT = {text!r}\n' + FAKE_CODESIGN)
            with self.subTest(rc=rc, text=text), patch.object(launch, 'CODESIGN', [PY, str(script)]):
                archive = write_app_zip(self.dir / f'{script.stem}.zip')
                self.assertEqual(self.extract(archive, run=script.stem)['evidence']['codeSignature'], kind)

    def test_app_zip_requires_launchservices(self):
        lease = dict(runID='r', epoch='e', notBefore=1000, expiresAt=1900, guardianHeartbeatAt=1019.5, ownerPreempted=False, exclusive=True)
        c = dict(profile='synthetic', lease=lease, release=lease | dict(m1Released=True, approval=APPROVAL),
                 requiredSeconds=60, stop=False, argv=['ModelPlan.zip'], binarySHA256='a' * 64, subjectKind='app-zip')
        self.assertTrue(launch.validate(c, 1020))  # direct: the extracted main executable is exec'd
        self.assertTrue(launch.validate(c | dict(launchMode='launchservices'), 1020))
        with self.assertRaisesRegex(ValueError, 'subjectKind'):
            launch.validate(c | dict(launchMode='launchservices', subjectKind='dmg'), 1020)


class NeverRegisteredClosure(unittest.TestCase):
    def setUp(self):
        self.dir = Path(tempfile.mkdtemp()); self.addCleanup(shutil.rmtree, self.dir, True)
        self.pid_file = self.dir / 'subject.pid'; self.home = self.dir / 'home'
        dead = subprocess.Popen([PY, '-c', 'pass']); self.dead = guardian.identity(dead.pid) or dict(pid=dead.pid, startSeconds=-1, startMicroseconds=0); dead.wait()

    def reserve(self, launcher, scope=True):
        record = dict(state='launching', launcher=launcher)
        if scope:
            record['scan'] = process_scan.scope_for(self.dir / 'App.app/Contents/MacOS/App', prefix=self.dir / 'App.app')
        self.pid_file.write_text(json.dumps(record))

    def test_empty_scope_scan_is_never_started_and_finishable(self):
        self.reserve(self.dead)
        closed, subject = guardian.close(self.pid_file, settle=0)
        self.assertEqual((closed, subject), (True, 'never-started'))
        self.assertTrue(guardian.finishable('launcher-lost', closed, subject))

    def test_unregistered_process_in_scope_is_stopped_but_not_reported_as_never_started(self):
        helper = native_sleeper(self, self.dir / 'App.app' / 'Contents' / 'MacOS' / 'Helper')
        stray = subprocess.Popen([str(helper), '60'])  # under the bundle prefix, not the exact subject path
        self.addCleanup(lambda: stray.poll() is None and stray.kill())
        self.reserve(self.dead)
        wait_until(lambda: process_scan.scan(process_scan.scope_for(prefix=self.dir / 'App.app'), guardian.identity),
                   5, 'stray not visible')
        closed, subject = guardian.close(self.pid_file, settle=0)
        self.assertEqual((closed, subject), (True, 'unregistered-stopped'))
        self.assertIsNotNone(stray.wait(5))
        self.assertFalse(guardian.finishable('launcher-lost', closed, subject))
        self.assertTrue(guardian.finishable('stopped', closed, subject))

    def test_unscoped_or_live_launcher_or_failed_scan_stays_unconfirmed(self):
        self.reserve(self.dead, scope=False)
        self.assertEqual(guardian.close(self.pid_file, settle=0), (False, 'unregistered-unscoped'))
        self.reserve(guardian.identity(os.getpid()))  # this process: a live launcher
        self.assertEqual(guardian.close(self.pid_file, settle=0, launcher_wait=0.2), (False, 'unregistered-launcher-alive'))
        self.reserve(self.dead)
        def broken(scope): raise OSError('process table unreadable')
        self.assertEqual(guardian.close(self.pid_file, settle=0, scan=broken), (False, 'unregistered-scan-failed'))
        survivor = dict(pid=4242, startSeconds=1, startMicroseconds=0)
        self.assertEqual(guardian.close(self.pid_file, settle=0, scan=lambda s: [survivor], send=lambda *a: None,
                                        lookup=lambda pid: survivor if pid == 4242 else None, grace=0.1),
                         (False, 'unregistered-still-running'))

    def test_registered_but_not_closed_never_finishes(self):
        subject = dict(pid=4242, startSeconds=1, startMicroseconds=0)
        self.pid_file.write_text(json.dumps(dict(state='running', launcher=self.dead,
                                                 scan=process_scan.scope_for(prefix=self.dir / 'App.app'), **subject)))
        sent = []
        clock = [0.0]
        def sleep(s): clock[0] += s
        closed, state = guardian.close(self.pid_file, lookup=lambda pid: subject if pid == 4242 else None,
                                       send=lambda *a: sent.append(a), clock=lambda: clock[0], sleep=sleep,
                                       scan=lambda s: self.fail('a registered subject is never closed by scan'))
        self.assertEqual((closed, state), (False, 'registered'))
        self.assertEqual([sig for _, sig in sent], [15, 9])
        for outcome in ('stopped', 'signalled', 'deadline', 'launcher-lost'):
            self.assertFalse(guardian.finishable(outcome, closed, state))
        self.assertFalse(guardian.finishable('launcher-lost', True, 'registered'))
        self.assertFalse(guardian.finishable('stopped', False, 'never-started'))

    def test_scan_never_matches_by_process_name(self):
        same_name = native_sleeper(self, self.dir / 'other' / 'App')
        ours = native_sleeper(self, self.dir / 'App.app' / 'Contents' / 'MacOS' / 'App')
        other = subprocess.Popen([str(same_name), '60']); mine = subprocess.Popen([str(ours), '60'])
        try:
            found = wait_until(lambda: process_scan.scan(process_scan.scope_for(ours), guardian.identity), 5, 'not found')
            self.assertEqual([(x['pid'], x['matchedBy']) for x in found], [(mine.pid, 'executable')])
        finally:
            other.kill(); mine.kill(); other.wait(); mine.wait()
        with self.assertRaises(ValueError):
            process_scan.scope_for()
        self.assertFalse(process_scan.valid_scope(dict(home='/')))
        self.assertFalse(process_scan.valid_scope(dict(name='App')))


class ScopeIsPathOnly(unittest.TestCase):
    """The scan reads executable paths and owned start identities only, never any environment."""

    def setUp(self):
        self.dir = Path(tempfile.mkdtemp()); self.addCleanup(shutil.rmtree, self.dir, True)
        self.home = self.dir / 'home'; self.home.mkdir()
        self.scope = process_scan.scope_for(self.dir / 'App.app/Contents/MacOS/App', prefix=self.dir / 'App.app')

    def spawn(self, env=None):
        child = subprocess.Popen([PY, '-c', 'import time; time.sleep(60)'], env=env)
        self.addCleanup(lambda: (child.kill(), child.wait()))
        wait_until(lambda: guardian.identity(child.pid), 5, 'child not visible')
        return child

    def test_matching_home_with_a_different_executable_is_not_matched(self):
        child = self.spawn(env=dict(PATH='/usr/bin:/bin', HOME=str(self.home)))
        self.assertNotIn(child.pid, [x['pid'] for x in process_scan.scan(self.scope, guardian.identity)])
        self.assertFalse(process_scan.valid_scope(dict(self.scope, home=str(self.home))))  # not a scope key
        with self.assertRaises(TypeError):
            process_scan.scope_for(self.dir / 'App', home=self.home)

    def test_no_code_path_reads_another_process_environment(self):
        for name in ('process_scan.py', 'guardian.py', 'launch.py', 'cleanup-run.py'):
            source = (BIN / name).read_text()
            for needle in (r'\benviron\b', 'PROCARGS', 'cmdline', 'sysctl', 'KERN_'):
                self.assertIsNone(re.search(needle, source), f'{name} mentions {needle}')
        if not sys.platform.startswith('linux'):
            return
        opened = []
        real_open, real_read = os.open, Path.read_bytes
        def watch_open(path, *a, **k): opened.append(str(path)); return real_open(path, *a, **k)
        def watch_read(self_, *a, **k): opened.append(str(self_)); return real_read(self_, *a, **k)
        self.spawn(env=dict(PATH='/usr/bin:/bin', HOME=str(self.home)))
        with patch('builtins.open', side_effect=lambda *a, **k: self.fail(f'opened {a[0]}')), \
                patch.object(os, 'open', side_effect=watch_open), patch.object(Path, 'read_bytes', watch_read), \
                patch.object(Path, 'read_text', side_effect=lambda *a, **k: self.fail('read_text')):
            process_scan.scan(self.scope, lambda pid: None)
        self.assertEqual([p for p in opened if p.startswith('/proc/')], [])

    def test_paths_compare_canonicalised_through_symlinked_components(self):
        # macOS reports /private/var/folders/... while a scope may be written via /var/folders/...
        real = self.dir / 'real'; (real / 'App.app' / 'Contents' / 'MacOS').mkdir(parents=True)
        link = self.dir / 'link'; link.symlink_to(real)
        exe = real / 'App.app' / 'Contents' / 'MacOS' / 'App'; exe.write_bytes(b'x')
        ident = lambda pid: dict(pid=pid, startSeconds=1, startMicroseconds=0)
        for scope in (dict(executable=str(link / 'App.app/Contents/MacOS/App')), dict(prefix=str(link / 'App.app')),
                      process_scan.scope_for(link / 'App.app/Contents/MacOS/App', prefix=link / 'App.app')):
            for reported in (str(exe), str(link / 'App.app/Contents/MacOS/App')):
                with self.subTest(scope=scope, reported=reported):
                    self.assertEqual([x['pid'] for x in process_scan.scan(scope, ident, candidates=[(7, reported)])], [7])
        self.assertEqual(process_scan.scan(dict(prefix=str(link / 'App.app')), ident,
                                           candidates=[(7, str(self.dir / 'App.app-other/App'))]), [])

    def test_spawned_helper_is_matched_by_recorded_pid_and_start_time(self):
        child = self.spawn()  # its executable is the interpreter, outside every path in the scope
        scope = process_scan.with_helper(self.scope, guardian.identity(child.pid))
        found = process_scan.scan(scope, guardian.identity)
        self.assertEqual([(x['pid'], x['matchedBy']) for x in found], [(child.pid, 'helper')])
        self.assertEqual(process_scan.scan(self.scope, guardian.identity), [])

    def test_reused_pid_with_a_different_start_time_is_not_matched(self):
        child = self.spawn()
        ident = guardian.identity(child.pid)
        stale = process_scan.with_helper(self.scope, ident | dict(startSeconds=ident['startSeconds'] - 1))
        self.assertEqual(process_scan.scan(stale, guardian.identity), [])
        recorded = dict(pid=4242, startSeconds=10, startMicroseconds=0)
        reused = lambda pid: dict(pid=pid, startSeconds=99, startMicroseconds=0) if pid == 4242 else None
        self.assertEqual(process_scan.scan(process_scan.with_helper(self.scope, recorded), reused, candidates=[]), [])
        same = lambda pid: dict(recorded) if pid == 4242 else None
        self.assertEqual([x['pid'] for x in process_scan.scan(process_scan.with_helper(self.scope, recorded), same, candidates=[])], [4242])


if __name__ == '__main__':
    unittest.main()
