#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Run the real app/helper offline in a synthetic HOME; evaluate observed facts without waivers."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import signal
import subprocess
import tempfile
import time

STEPS = range(1, 9)


def row_invariant(facts):
    observation = facts.get('rowInvariant')
    if not isinstance(observation, dict) or observation.get('canonicalKnown') is not True:
        return False
    allowed, counts = observation.get('allowedTools'), observation.get('rowCounts')
    return (isinstance(allowed, list) and all(isinstance(x, str) and re.fullmatch(r'[a-z][a-z0-9-]{0,47}', x) for x in allowed)
            and len(set(allowed)) == len(allowed) and isinstance(counts, dict) and set(counts) == set(allowed)
            and all(type(counts[tool]) is int and counts[tool] == 1 for tool in allowed))


def human_age(value):
    if not human(value):
        return False
    unit = r'(?<![0-9A-Za-z])\d+(?:\.\d+)?\s*(?:(?:m|min|mins|minute|minutes|h|hr|hrs|hour|hours)(?![A-Za-z])|分钟|分鐘|小时|小時)'
    seconds = r'\d+(?:\.\d+)?\s*(?:s(?:ec(?:ond)?s?)?(?![A-Za-z])|秒)'
    return re.search(unit, value, re.I) is not None and re.search(seconds, value, re.I) is None


def human(value):
    return (isinstance(value, str) and bool(value.strip()) and value.strip() not in ('?', '？')
            and re.fullmatch(r'[A-Za-z_][A-Za-z0-9_-]*', value.strip()) is None
            and re.search(r'\b[a-z][a-z0-9]*(?:_[A-Za-z0-9]+|[A-Z][A-Za-z0-9]*)+\b', value, re.A) is None)


def passes(step, facts):
    if not isinstance(facts, dict) or not row_invariant(facts):
        return False
    if step in (2, 3, 4, 5, 7) and 'codex' not in facts['rowInvariant']['allowedTools']:
        return False
    if step == 1:
        return (facts.get('detected') is True and facts.get('grokDetected') is True and facts.get('listedInFirstRun') is True
                and facts.get('backendBound') is True and type(facts.get('providerReadsBeforeGrant')) is int
                and facts['providerReadsBeforeGrant'] == 0)
    if step == 2:
        return (facts.get('granted') is True and facts.get('apiAvailable') is True
                and facts.get('releaseIdentityVerified') is False and facts.get('debugAdmission') is True)
    if step == 3:
        return (type(facts.get('providerReads')) is int and facts['providerReads'] > 0
                and facts.get('postProviderSnapshot') is True and facts.get('nativePanelsVisible') is False)
    values = facts.get('values')
    if step == 4:
        rows = facts.get('renderedRows')
        return isinstance(rows, list) and any(isinstance(row, dict)
            and row.get('provider') == 'codex' and row.get('accountAssociated') is True
            and row.get('readout') == '37%' and type(row.get('remainingPercent')) in (int, float)
            and abs(row['remainingPercent'] - 37) < 0.01 for row in rows)
    if step == 5:
        return facts.get('freshBoundRow') is True and facts.get('cardOpened') is True and human_age(facts.get('ageText'))
    if step == 6:
        return (facts.get('revoked') is True and facts.get('valueSeenBefore') is True
                and facts.get('postRevokeSnapshot') is True and values == [])
    if step == 7:
        reasons = facts.get('reasonRows')
        return (facts.get('regranted') is True and facts.get('unreadableObserved') is True
                and facts.get('postErrorSnapshot') is True and type(facts.get('rows')) is int and facts['rows'] > 0
                and values == [] and facts.get('rowActionDispatched') is True
                and facts.get('settingsDestinationReached') is True
                and isinstance(reasons, list) and any(isinstance(x, dict) and human(x.get('reason'))
                    and human(x.get('nextStep')) for x in reasons))
    if step == 8:
        rows = facts.get('renderedRows')
        return (facts.get('granted') is True and facts.get('nativeErrorObserved') is True
                and facts.get('postGrantSnapshot') is True and type(facts.get('accountCount')) is int
                and facts['accountCount'] == 0 and type(facts.get('connectionCount')) is int
                and facts['connectionCount'] == 0 and 'grok' in facts['rowInvariant']['allowedTools']
                and isinstance(rows, list) and len(rows) == 1 and isinstance(rows[0], dict)
                and isinstance(rows[0].get('providers'), list) and 'grok' in rows[0]['providers'] and rows[0].get('readout') == '--'
                and rows[0].get('remainingPercent') is None and human(rows[0].get('reason'))
                and human(rows[0].get('nextStep')))
    return False


def print_step(step, facts):
    result = passes(step, facts)
    print(f'e2e step {step} {"PASS" if result else "FAIL"} {json.dumps(facts, ensure_ascii=False, sort_keys=True)}', flush=True)
    return result


def run(build, output):
    output.mkdir(parents=True, exist_ok=False)
    app = build / 'neutral/ModelPlan Community.app'
    helper = app / 'Contents/Helpers/modelplan'
    subprocess.run(['/usr/bin/codesign', '--verify', '--deep', '--strict', str(app)], check=True)
    receipt = json.loads((build / 'build-receipt.json').read_text())
    info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    if info.get('ModelPlanPublicSource') != receipt['sourceCommit'] or 'ModelPlanHelperVersion' in info:
        raise ValueError('journey requires same-source unverified metadata')
    if hashlib.sha256(helper.read_bytes()).hexdigest() != (app / 'Contents/Resources/modelplan.sha256').read_text().strip():
        raise ValueError('sealed helper pin mismatch')
    with tempfile.TemporaryDirectory(prefix='e2e-journey-') as temporary:
        root = Path(temporary).resolve(); home = root / 'home'; home.mkdir()
        profile = home / '.codex'; profile.mkdir()
        grok = home / '.grok'; grok.mkdir()
        # Existing native Grok reader fails parsing before any credential or HTTP request.
        (grok / 'auth.json').write_text('{malformed synthetic fixture\n')
        (grok / 'auth.json').chmod(0o600)
        (profile / 'e2e-mode').write_text('readable\n')
        binary = home / 'bin'; binary.mkdir(); (binary / 'codex').write_bytes((build / 'codex').read_bytes())
        (binary / 'codex').chmod(0o755)
        scratch = home / 'tmp'; scratch.mkdir()
        report = output / 'journey.json'
        environment = {'HOME': str(home), 'CFFIXED_USER_HOME': str(home), 'TMPDIR': str(scratch) + '/',
            'CODEX_HOME': str(profile), 'CLAUDE_CONFIG_DIR': str(home / '.claude'),
            'GROK_HOME': str(grok), 'GROK_AUTH_PATH': str(grok / 'auth.json'),
            'MODELPLAN_CACHE': str(home / 'cache'), 'XDG_CONFIG_HOME': str(home / '.config'),
            'PATH': str(binary) + ':/usr/bin:/bin', 'MODELPLAN_CODEX': str(binary / 'codex'),
            'MODELPLAN_CODEXBAR': 'off', 'MODELPLAN_HISTORY': 'off', 'MODELPLAN_BASE': 'http://127.0.0.1:9',
            'MODELPLAN_APP_SMOKE': '1', 'MODELPLAN_E2E_JOURNEY': '1', 'MODELPLAN_E2E_REPORT': str(report), 'NO_COLOR': '1'}
        # The fixture uses stdio only. Denying all network is stricter than localhost-only.
        sandbox = root / 'journey.sb'; sandbox.write_text('(version 1)\n(allow default)\n(deny network*)\n')
        command = ['/usr/bin/sandbox-exec', '-f', str(sandbox), str(app / 'Contents/MacOS/ModelPlanCommunity')]
        printed, results = set(), []
        with (output / 'process.stderr').open('wb') as error:
            process = subprocess.Popen(command, env=environment, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                                       stderr=error, start_new_session=True)
            try:
                deadline = time.monotonic() + 780
                while process.poll() is None and time.monotonic() < deadline:
                    if report.is_file():
                        for facts in json.loads(report.read_text()).get('steps', []):
                            step = facts.get('step')
                            if step in STEPS and step not in printed:
                                printed.add(step); results.append(print_step(step, facts))
                    time.sleep(0.2)
                if process.poll() is None:
                    os.killpg(process.pid, signal.SIGKILL); process.wait()
                facts_by_step = {x.get('step'): x for x in json.loads(report.read_text()).get('steps', [])} if report.is_file() else {}
                for step in STEPS:
                    if step not in printed:
                        results.append(print_step(step, facts_by_step.get(step, {'blocked': 'app-report-missing'})))
                (output / 'result.json').write_text(json.dumps({'sourceCommit': receipt['sourceCommit'],
                    'stepsPassed': sum(results), 'stepCount': len(STEPS), 'exitCode': process.returncode}, indent=2) + '\n')
                return process.returncode == 0 and len(results) == len(STEPS) and all(results)
            finally:
                if process.poll() is None:
                    os.killpg(process.pid, signal.SIGKILL); process.wait()
                # Detached workers belong exclusively to this fresh bundle path, never a real tool/user.
                subprocess.run(['/usr/bin/pkill', '-f', '^' + re.escape(str(helper)) + r' (quota|sync|connections)( |$)'], check=False)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('build', type=Path); parser.add_argument('output', type=Path)
    args = parser.parse_args()
    try:
        okay = run(args.build.resolve(), args.output.resolve())
    except (OSError, ValueError, subprocess.SubprocessError):
        for step in STEPS:
            print_step(step, {'blocked': 'journey-launch-failed'})
        okay = False
    raise SystemExit(0 if okay else 1)
