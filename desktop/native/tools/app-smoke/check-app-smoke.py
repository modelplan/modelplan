#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Launch the actual packaged Community entry, with no network and an isolated home.
Known production wiring failures stay red; this is not an expected-success fixture.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import tempfile
import time


def assertions(report, helper, home):
    """Return all results so one bad component cannot hide the remaining wiring facts."""
    dock = report.get('dockHostType')
    available = report.get('connectionAvailable')
    service = report.get('connectionServicePresent')
    port = report.get('consentPortPresent')
    api = report.get('consentAPIAvailable')
    status = report.get('firstRunConnectionStatus')
    help_text = report.get('cliHelp', '')
    # Global flags are printed even for unknown subcommands. Require an advertised command
    # and JSON support, not just a successful/parseable generic help response.
    consent = (report.get('cliHelpExitCode') == 0 and isinstance(help_text, str)
               and re.search(r'(?m)^\s*modelplan\s+consent\b', help_text) is not None
               and '--json' in help_text)
    defaults = {key: report.get(key) for key in ('showDock', 'autoHide', 'edge')}
    return [
        ('report-schema', report.get('schemaVersion') == 1, report.get('schemaVersion')),
        ('dock-host', isinstance(dock, str) and bool(dock) and not re.search(r'preview|self.?test|probe', dock, re.I), dock),
        ('connection-service', service is True, service),
        ('connection-availability', type(available) is bool and available == service == consent,
         {'service': service, 'available': available, 'cliConsentJSON': consent}),
        ('first-run-status', isinstance(status, str) and bool(status.strip())
         and re.fullmatch(r'[a-z_]+', status.strip()) is None
         and 'unavailable: unavailable' not in status.lower(), status),
        ('consent-port', port is True and type(api) is bool, {'present': port, 'apiAvailable': api}),
        ('consent-capability', type(api) is bool and (not api or consent),
         {'apiAvailable': api, 'cliConsentJSON': consent}),
        ('bundled-cli', report.get('cliPath') == str(helper) and report.get('cliHelpExitCode') == 0
         and type(report.get('cliSupportsConsentJSON')) is bool and report['cliSupportsConsentJSON'] == consent,
         {'path': report.get('cliPath'), 'helpExit': report.get('cliHelpExitCode'), 'consentJSON': consent}),
        ('dock-defaults', defaults == {'showDock': True, 'autoHide': True, 'edge': 'right'}, defaults),
        ('synthetic-home', report.get('home') == str(home), report.get('home')),
        ('no-visible-ui', report.get('visibleWindows') == 0, report.get('visibleWindows')),
    ]


def print_results(results):
    for name, passed, value in results:
        print(f'app-smoke {name} {"PASS" if passed else "FAIL"} {json.dumps(value, ensure_ascii=False, sort_keys=True)}', flush=True)
    return all(passed for _, passed, _ in results)


def launch(app, output):
    executable = app / 'Contents/MacOS/ModelPlanCommunity'
    helper = app / 'Contents/Helpers/modelplan'
    subprocess.run(['/usr/bin/codesign', '--verify', '--deep', '--strict', str(app)], check=True)
    expected = (app / 'Contents/Resources/modelplan.sha256').read_text().strip()
    if hashlib.sha256(helper.read_bytes()).hexdigest() != expected:
        raise ValueError('Bundled helper does not match its signed resource hash')
    output.mkdir(parents=True, exist_ok=False)
    with tempfile.TemporaryDirectory(prefix='app-smoke-', dir=output) as temporary:
        root = Path(temporary).resolve()
        home = root / 'home'; home.mkdir()
        scratch = root / 'tmp'; scratch.mkdir()
        report_path = output / 'self-report.json'
        # Keep the configured runner home untouched. Only this fresh child process uses
        # HOME/CFFIXED_USER_HOME; no test identity, session token or credential is inherited.
        environment = {'HOME': str(home), 'CFFIXED_USER_HOME': str(home), 'TMPDIR': str(scratch) + '/',
                       'CODEX_HOME': str(home / 'codex'), 'CLAUDE_CONFIG_DIR': str(home / 'claude'),
                       'MODELPLAN_CACHE': str(home / 'cache'), 'XDG_CONFIG_HOME': str(home / 'config'),
                       'PATH': '/usr/bin:/bin', 'NO_COLOR': '1', 'MODELPLAN_APP_SMOKE': '1',
                       'MODELPLAN_APP_SMOKE_REPORT': str(report_path)}
        # The app and its --help child inherit network denial. Synthetic HOME and
        # CFFIXED_USER_HOME redirect all app-owned preferences and CLI locations;
        # system AppKit/launch services retain their ordinary read access.
        profile = root / 'smoke.sb'
        profile.write_text('(version 1)\n(allow default)\n(deny network*)\n')
        started = time.time()
        process = subprocess.Popen(['/usr/bin/sandbox-exec', '-f', str(profile), str(executable)],
                                   env=environment, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                                   stderr=subprocess.PIPE, start_new_session=True)
        try:
            stdout, stderr = process.communicate(timeout=45)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.communicate()
            raise RuntimeError('Packaged smoke process timed out') from None
        (output / 'process.stdout').write_bytes(stdout)
        (output / 'process.stderr').write_bytes(stderr)
        if process.returncode != 0 or not report_path.is_file():
            # Retain only diagnostics for this test executable from this launch.
            # No general user/system log dump or credential/environment discovery.
            diagnostics = Path.home() / 'Library/Logs/DiagnosticReports'
            for _ in range(5):
                reports = [path for path in diagnostics.glob('ModelPlanCommunity*.ips')
                           if path.stat().st_mtime >= started and path.stat().st_size <= 2 * 1024 * 1024]
                if reports:
                    for index, path in enumerate(reports):
                        (output / f'crash-{index}.ips').write_bytes(path.read_bytes())
                    break
                time.sleep(1)
            try:
                diagnostic = subprocess.run(['/usr/bin/log', 'show', '--last', '2m', '--style', 'compact',
                                             '--predicate', f'processIdentifier == {process.pid}'],
                                            capture_output=True, timeout=10)
                (output / 'process.system.log').write_bytes(diagnostic.stdout + diagnostic.stderr)
            except (OSError, subprocess.TimeoutExpired):
                pass
            raise RuntimeError(f'Packaged entry failed to report (exit {process.returncode}); inspect process.stderr artifact')
        report = json.loads(report_path.read_text())
        results = assertions(report, helper, home)
        (output / 'assertions.json').write_text(json.dumps(
            [{'name': name, 'passed': bool(passed), 'value': value} for name, passed, value in results],
            indent=2, ensure_ascii=False) + '\n')
        return print_results(results)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('app', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    try:
        passed = launch(args.app.resolve(), args.output.resolve())
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print(f'app-smoke launch FAIL {error}', flush=True)
        return 1
    if not passed:
        print('Packaged production wiring failed. Fix the app composition in its owning lane; do not waive these assertions.', flush=True)
    return 0 if passed else 1


if __name__ == '__main__':
    sys.exit(main())
