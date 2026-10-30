#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""One non-GUI verification Drive entry: ordinary engine, synthetic homes, evidence."""
import argparse
import json
import os
from pathlib import Path
import platform
import re
import shutil
import signal
import subprocess
import sys
import threading
import time
import uuid

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from contracts import encoded, load_json, new_directory, validate
from release import regular, sha, verify
from scenarios import Home, IDS, fixture, run

ROOT = Path(__file__).resolve().parents[3]
STOP = False


def stopped(*_):
    global STOP
    STOP = True


def atomic(path, value):
    temporary = path.with_suffix('.pending')
    with temporary.open('wb') as stream:
        os.chmod(temporary, 0o600)
        stream.write(encoded(value))
        stream.flush()
        os.fsync(stream.fileno())
    temporary.replace(path)


def worker(config_path):
    config = load_json(config_path)
    # Keep the session leader alive through the TERM grace period. On Darwin,
    # signalling a group containing only dead/zombie members can return EPERM.
    # A real handler resets to the default in exec'd children (unlike SIG_IGN).
    signal.signal(signal.SIGTERM, lambda *_: None)
    def stop_owned_group():
        sys.stdin.buffer.read(1)
        try:
            if os.getpgrp() != os.getpid():
                raise RuntimeError('worker-not-session-leader')
            os.killpg(os.getpgrp(), signal.SIGKILL)
        except Exception as exc:
            atomic(Path(config['cleanupResult']), dict(outcome='failed', failureClass=type(exc).__name__,
                  errno=getattr(exc, 'errno', None)))
            os._exit(127)
    threading.Thread(target=stop_owned_group, daemon=True).start()
    trap = fixture.http.server.ThreadingHTTPServer(('127.0.0.1', 0), fixture.Trap)
    threading.Thread(target=trap.serve_forever, daemon=True).start()
    result = dict(outcome='fail', reason='scenario-assertion')
    # Survives loss of the parent: this worker owns its session, and never lets
    # a stalled child run beyond the declared scenario bound plus cleanup grace.
    watchdog = threading.Timer(config['watchdogSeconds'], lambda: os.killpg(os.getpgrp(), signal.SIGKILL))
    watchdog.daemon = True
    watchdog.start()
    try:
        h = Home(Path(config['home']), Path(config['binary']),
                 'http://127.0.0.1:%d' % trap.server_port, load_json(config['shape']))
        old = config.get('old')
        details = run(config['scenario'], h, (old['tag'], Path(old['binary'])) if old else None)
        from engine_runner import require
        require((h.root / '.claude/.credentials.json').read_bytes() == b'', 'credential-placeholder-changed')
        require(not fixture.Trap.calls, 'unexpected-network-io')
        require(not (h.root / '.u14-claude-calls').exists(), 'unexpected-claude-vendor-io')
        details['placeholderIsolation'] = dict(credentialBytes=0, networkCalls=0, claudeVendorCalls=0)
        result = dict(outcome='pass', reason='observed', details=details,
                      baseline=h.baseline, provider='fixed synthetic Copilot stdio runtime')
    except Exception as exc:
        # Never export exception text, subprocess output, shape values or paths.
        result = dict(outcome='fail', reason='scenario-assertion', failureClass=type(exc).__name__)
        if type(exc).__name__ in ('EngineFailure', 'EngineTimeout') and re.fullmatch(r'[a-z0-9-]{1,100}', str(exc)):
            result['checkCode'] = str(exc)
    finally:
        atomic(Path(config['result']), result)
        trap.shutdown()
        trap.server_close()
    return 0 if result['outcome'] == 'pass' else 1


def terminate(process):
    # Worker stays alive after its result, retaining the owned process-group ID.
    # Signal the complete group before reaping its leader, preventing PID reuse.
    if process.returncode is not None:
        raise RuntimeError('worker-identity-lost')
    try:
        os.killpg(process.pid, signal.SIGTERM)
    except PermissionError:
        # Some macOS hosts restrict parent-to-session group signalling. Ask the
        # still-owned worker to stop its own verified session instead.
        process.stdin.write(b'S')
        process.stdin.flush()
        if process.wait(timeout=3) != -signal.SIGKILL:
            raise RuntimeError('worker-group-cleanup-unconfirmed')
        process.stdin.close()
        return
    time.sleep(.05)
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    process.wait(timeout=3)
    process.stdin.close()


def qualification(level, shape, subject, old, context):
    reasons = []
    if level == 'L2':
        if platform.system() != 'Darwin' or os.environ.get('GITHUB_ACTIONS') == 'true':
            reasons.append('dedicated-test-mac-required')
        if subject.get('kind') != 'released':
            reasons.append('released-subject-required')
        if shape['fidelity'] != 'approved-shape-export' or not (shape['approvalRef'] or '').strip():
            reasons.append('coordinator-shape-approval-required')
        if not context or context.get('dedicatedTestMac') is not True or not context.get('approvalRef', '').strip():
            reasons.append('dedicated-mac-run-approval-required')
        if set(old) != {'v0.5.46', 'v0.5.47'}:
            reasons.append('both-old-releases-required')
    return reasons


def run_scenarios(args, output, scratch, manifest, binary, old, deadline):
    cleanup_errors = []
    interrupted = None
    for entry in manifest['scenarios']:
        scenario = entry['id']
        if manifest['qualification']:
            entry.update(outcome='unsupported', reason='l2-prerequisite-missing')
            continue
        if STOP or (args.stop_file and args.stop_file.exists()):
            interrupted = 'caller-stop'
        elif time.monotonic() >= deadline:
            interrupted = 'run-deadline'
        if interrupted:
            entry.update(reason=interrupted)
            continue
        if scenario.startswith('U2-old-writer-') and scenario.removeprefix('U2-old-writer-') not in old:
            entry.update(outcome='unsupported', reason='old-release-not-supplied')
            continue
        result_path = scratch / (scenario + '.json')
        config_path = scratch / (scenario + '-config.json')
        config = dict(binary=str(binary), shape=str((output / 'profile.json').resolve()),
                      home=str((scratch / (scenario + '-home')).resolve()), scenario=scenario,
                      result=str(result_path.resolve()), cleanupResult=str((scratch / (scenario + '-cleanup.json')).resolve()),
                      watchdogSeconds=args.scenario_timeout + 5,
                      old=old.get(scenario.removeprefix('U2-old-writer-')))
        atomic(config_path, config)
        process = subprocess.Popen([sys.executable, str(Path(__file__).resolve()), '--worker', str(config_path)],
                                   start_new_session=True, stdin=subprocess.PIPE,
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        began = time.monotonic()
        try:
            while not result_path.exists():
                if process.poll() is not None:
                    break
                if STOP or (args.stop_file and args.stop_file.exists()):
                    interrupted = 'caller-stop'
                    break
                if time.monotonic() >= min(deadline, began + args.scenario_timeout):
                    interrupted = 'run-deadline' if time.monotonic() >= deadline else None
                    entry.update(outcome='timeout', reason='scenario-deadline')
                    break
                time.sleep(.05)
            if interrupted == 'caller-stop':
                entry.update(outcome='not-run', reason=interrupted)
            elif interrupted == 'run-deadline':
                entry.update(outcome='timeout', reason='run-deadline')
            elif result_path.exists() and entry['outcome'] != 'timeout':
                result = load_json(result_path)
                entry.update(outcome=result['outcome'], reason=result['reason'])
                evidence_name = scenario + '.json'
                atomic(output / evidence_name, result)
                entry['evidence'] = dict(path=evidence_name, sha256=sha(regular(output / evidence_name)))
            elif entry['outcome'] != 'timeout':
                entry.update(outcome='fail', reason='worker-result-missing')
        finally:
            # Outcome is durable BEFORE termination/removal. Cleanup has its own
            # receipt and never replaces scenario results.
            entry['durationSeconds'] = round(time.monotonic() - began, 3)
            try:
                atomic(output / 'manifest.json', manifest)
            finally:
                try:
                    terminate(process)
                except Exception as exc:
                    cleanup_errors.append('owned-process-cleanup-unconfirmed')
                    cleanup_errors.append(type(exc).__name__ + '-errno-' + str(getattr(exc, 'errno', 'none')))
    return cleanup_errors


def execute(args):
    output = new_directory(args.output)
    scratch = output / '.work'
    scratch.mkdir(mode=0o700)
    # Even preflight failures have a machine-readable per-scenario record.
    manifest = dict(schemaVersion=1, driveScenario='U2-U3-engine', runId=args.run_id,
                    attempt=args.attempt, epoch=args.epoch, requestedLevel=args.level,
                    earnedLevel=None, outcome='not-run', cleanup=dict(outcome='not-run'),
                    scenarios=[dict(id=id, outcome='not-run', reason='pending') for id in IDS])
    atomic(output / 'manifest.json', manifest)
    start = time.monotonic()
    cleanup_errors = []
    try:
        shape = load_json(args.shape)
        validate(shape, 'shape.schema.json')
        head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
        if args.source_sha and not re.fullmatch(r'[0-9a-f]{40}', args.source_sha):
            raise ValueError('full-source-sha-required')
        binary = args.binary.resolve()
        subject = dict(kind='source-build', binarySHA256=sha(regular(binary)), commit=args.source_sha)
        if args.release:
            released_binary, identity = verify(args.release)
            if regular(released_binary) != regular(binary):
                raise ValueError('subject-does-not-match-release')
            subject = dict(kind='released', **identity)
        elif not args.source_sha:
            raise ValueError('source-build-commit-required')
        old = {}
        for record in args.old_release:
            executable, identity = verify(record)
            if identity['tag'] in old:
                raise ValueError('duplicate-old-release')
            old[identity['tag']] = dict(binary=str(executable), **identity)
        if set(old) - {'v0.5.46', 'v0.5.47'}:
            raise ValueError('unsupported-old-release')
        context = load_json(args.context) if args.context else None
        if context and (set(context) != {'dedicatedTestMac', 'approvalRef'} or
                        type(context['dedicatedTestMac']) is not bool or not isinstance(context['approvalRef'], str)):
            raise ValueError('invalid-run-context')
        prereqs = qualification(args.level, shape, subject, old, context)
        manifest.update(harnessHead=head, subject=subject,
                        oldSubjects=[{k: v for k, v in o.items() if k != 'binary'} for o in old.values()],
                        profile=dict(id=shape['baselineVersion'], sha256=sha(encoded(shape)), fidelity=shape['fidelity'],
                                     approvalRef=shape['approvalRef'], syntheticOnly=True,
                                     variants=['coexistence', 'schema-1 migration', 'fixed synthetic Copilot runtime',
                                               'blocked/completed capture', 'retired reader cache', 'corrupt store']),
                        qualification=prereqs, attribution=dict(platform=platform.system(), architecture=platform.machine(),
                            hosted=os.environ.get('GITHUB_ACTIONS') == 'true', context=context))
        atomic(output / 'profile.json', shape)
        atomic(output / 'manifest.json', manifest)
        limit = min(args.timeout, max(0, args.deadline - time.time())) if args.deadline else args.timeout
        cleanup_errors = run_scenarios(args, output, scratch, manifest, binary, old, start + max(0, limit - 15))
    except Exception as exc:
        manifest.update(reason='preflight-or-harness-failed', failureClass=type(exc).__name__)
        for item in manifest['scenarios']:
            if item['outcome'] == 'not-run':
                item['reason'] = 'preflight-or-harness-failed'
    finally:
        states = {e['outcome'] for e in manifest['scenarios']}
        manifest['outcome'] = ('fail' if 'fail' in states else 'timeout' if 'timeout' in states else
                               'not-run' if 'not-run' in states else 'unsupported' if 'unsupported' in states else 'pass')
        manifest['earnedLevel'] = args.level if manifest['outcome'] == 'pass' else None
        manifest['durationSeconds'] = round(time.monotonic() - start, 3)
        atomic(output / 'manifest.json', manifest)
        if not cleanup_errors:
            try:
                shutil.rmtree(scratch)
            except OSError:
                cleanup_errors.append('scratch-removal-failed')
        manifest['cleanup'] = dict(outcome='failed' if cleanup_errors else 'cleaned', reasons=cleanup_errors,
                                   retained=['manifest.json', 'profile.json', 'scenario evidence'])
        if cleanup_errors:
            manifest['earnedLevel'] = None
        atomic(output / 'cleanup.json', manifest['cleanup'])
        atomic(output / 'manifest.json', manifest)
    print(json.dumps(dict(outcome=manifest['outcome'], earnedLevel=manifest['earnedLevel'], cleanup=manifest['cleanup']['outcome'])))
    return 0 if manifest['outcome'] == 'pass' and not cleanup_errors else 1


def main():
    if len(sys.argv) == 3 and sys.argv[1] == '--worker':
        status = worker(Path(sys.argv[2]))
        # The stop thread alone reads control stdin and retains this leader until
        # evidence is durable; it also handles parent loss (pipe EOF).
        while True:
            time.sleep(1)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary', required=True, type=Path)
    parser.add_argument('--source-sha', help='full source commit; L1 only without --release')
    parser.add_argument('--release', type=Path, help='verified release.json from release.py')
    parser.add_argument('--old-release', type=Path, action='append', default=[])
    parser.add_argument('--shape', type=Path, default=Path(__file__).with_name('profile.json'))
    parser.add_argument('--context', type=Path, help='dedicatedTestMac boolean and approvalRef; no host identity')
    parser.add_argument('--level', choices=['L1', 'L2'], default='L1')
    parser.add_argument('--output', required=True, type=Path, help='new evidence directory; parent must exist')
    parser.add_argument('--timeout', type=int, default=900)
    parser.add_argument('--scenario-timeout', type=int, default=60)
    parser.add_argument('--deadline', type=float, help='caller fixed UNIX expiry; cannot extend local bound')
    parser.add_argument('--stop-file', type=Path, help='caller guardian stop marker; no GUI lease required')
    parser.add_argument('--run-id', default=str(uuid.uuid4()))
    parser.add_argument('--attempt', default='1')
    parser.add_argument('--epoch', default=str(uuid.uuid4()))
    args = parser.parse_args()
    if not 20 <= args.timeout <= 1200 or not 1 <= args.scenario_timeout <= 120:
        parser.error('run timeout must be 20..1200s and scenario timeout 1..120s')
    for sig in (signal.SIGINT, signal.SIGTERM):
        signal.signal(sig, stopped)
    try:
        return execute(args)
    except Exception as exc:
        print(json.dumps(dict(outcome='not-run', reason='output-unavailable', failureClass=type(exc).__name__)))
        return 2


if __name__ == '__main__':
    sys.exit(main())
