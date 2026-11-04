#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Advisory PR-open checks; never posts a review or fails the PR."""
import json
import os
import re
import sys
import urllib.error
import urllib.request

# Equivalent to coordinator design-paths.conf at dd643a2; exclusions precede
# inclusions and mechanical cockpit manifest-pin-only changes are excluded.
EXCLUDES = [re.compile(p) for p in (
    r'(^|/)(Tests|[A-Za-z]+Tests|__tests__|tests?|verification|Verification|Acceptance|[A-Za-z]*Proof|[A-Za-z]*Checks)/',
    r'(^|/)[A-Za-z0-9_-]+(Tests?|Spec)\.swift$|\.(test|spec)\.[cm]?[jt]sx?$|(^|/)check-[a-z0-9-]+\.sh$',
    r'^docs/|\.md$|(^|/)(README|LICENSE|NOTICE|HISTORICAL-MIT)[^/]*$|(^|/)Package\.(swift|resolved)$',
    r'^desktop/official-visuals/[a-z-]*baselines/',
)]
INCLUDES = [(name, re.compile(pattern)) for name, pattern in (
    ('dock', r'^desktop/native/ModelPlanDock/'),
    ('integration', r'^desktop/native/ModelPlanAppIntegration/'),
    ('settings', r'^desktop/native/ModelPlanSettings/'),
    ('cockpit', r'^desktop/cockpit/(src|web)/'),
    ('visuals', r'^desktop/official-visuals/'),
    ('strings', r'\.(strings|stringsdict|xcstrings)$|\.lproj/|(^|/)Localizable[^/]*$|(^|/)(i18n|l10n|locales?)(/|\.[a-z]+$)'),
)]
PIN_PATH = 'desktop/native/ModelPlanAppIntegration/Sources/ModelPlanAppIntegration/CommunityCockpitApplicationFactory.swift'
PIN_LINE = re.compile(r'^\s*(public\s+)?(static\s+let\s+webSource\s*=\s*"[0-9a-f]{40}"|"(community|official)"\s*:\s*"[0-9a-f]{64}",?)\s*$')
REQUIREMENT = re.compile(r'\b(?:DOCK|MENU|COL|MOT|THM|HINT|LBL|SET|FR|CKP)(?:-[A-Z0-9.]+)*-[0-9]{2,3}[a-z]?\b')
STAGING = re.compile(r'(?is)(?:\bstag(?:e[ds]?|ing)\b.{0,120}(?:#470\b|/issues/470\b)|(?:#470\b|/issues/470\b).{0,120}\bstag(?:e[ds]?|ing)\b)')


def pin_only(file):
    patch = file.get('patch') or ''
    lines = [line[1:] for line in patch.splitlines() if line.startswith(('+', '-')) and not line.startswith(('+++', '---'))]
    return bool(lines) and all(PIN_LINE.fullmatch(line) for line in lines)


def surfaces(files):
    found = set()
    for file in files:
        for path in (file.get('filename', ''), file.get('previous_filename', '')):
            if not path or any(rx.search(path) for rx in EXCLUDES):
                continue
            if path == PIN_PATH and pin_only(file):
                continue
            for name, rx in INCLUDES:
                if rx.search(path):
                    found.add(name)
                    break
    return found


def staged_prs(issue):
    match = re.search(r'(?im)^##\s+Staged PRs\s*$([\s\S]*?)(?=^##\s|\Z)', issue)
    if not match:
        raise ValueError('issue #470 has no staged-PR section')
    return {int(n) for n in re.findall(r'(?m)^\s*[-*]\s+\[[ xX]\]\s+#(\d+)\b', match.group(1))}


def warnings(files, body, number, issue):
    touched = surfaces(files)
    messages = []
    if touched and not REQUIREMENT.search(body):
        messages.append('Design-touching PR: add the requirement IDs implemented to the PR body.')
    if 'cockpit' in touched and STAGING.search(body):
        if issue is None:
            messages.append('Could not check issue #470 staged PRs; verify the staging list manually.')
        else:
            try:
                if number not in staged_prs(issue):
                    messages.append('Cockpit staging claimed: add this PR to the staged list in issue #470.')
            except ValueError:
                messages.append('Could not read the staged list in issue #470; verify it manually.')
    return messages


def api(path):
    req = urllib.request.Request('https://api.github.com' + path, headers={
        'Accept': 'application/vnd.github+json', 'Authorization': 'Bearer ' + os.environ['GH_TOKEN'],
        'User-Agent': 'modelplan-pr-open-lint', 'X-GitHub-Api-Version': '2022-11-28',
    })
    with urllib.request.urlopen(req, timeout=20) as response:
        return json.load(response)


def run():
    with open(os.environ['GITHUB_EVENT_PATH'], encoding='utf-8') as stream:
        event = json.load(stream)
    number = int(event['pull_request']['number'])
    body = event['pull_request'].get('body') or ''
    files = []
    for page in range(1, 32):
        batch = api(f'/repos/modelplan/modelplan/pulls/{number}/files?per_page=100&page={page}')
        if not isinstance(batch, list):
            raise ValueError('unexpected PR file response')
        files.extend(batch)
        if len(batch) < 100:
            break
    else:
        raise ValueError('PR file list may be truncated')
    issue = None
    if 'cockpit' in surfaces(files) and STAGING.search(body):
        try:
            issue = api('/repos/modelplan/modelplan/issues/470').get('body')
        except (OSError, ValueError, KeyError):
            pass
    return warnings(files, body, number, issue)


if __name__ == '__main__':
    try:
        for message in run():
            print('::warning::' + message)
    except (OSError, ValueError, KeyError, TypeError, json.JSONDecodeError):
        print('::warning::Could not complete PR gate lint; verify design IDs and #470 staging manually.')
    sys.exit(0)
