#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""D57/D321: the packaged app is one product named ModelPlan.

Checks a packaged .app: its folder, executable, bundle identifier and edition, and that no
file in the bundle (Info.plist, localized strings, notices or executable bytes) still carries
the retired product name. Internal Swift module names are not product names and are allowed.
"""
import argparse
import plistlib
import sys
from pathlib import Path

APP_NAME = 'ModelPlan.app'
EXECUTABLE = 'ModelPlan'
BUNDLE_ID = 'ai.modelplan.app'
DISPLAY_NAMES = {'official': 'ModelPlan', 'neutral': 'ModelPlan (self-built)'}
# The retired user-visible names, in every spelling a bundle could carry them.
FORBIDDEN = [s.encode('utf-8') for s in ('ModelPlan Community', 'ModelPlan-Community', '社区版')]
FORBIDDEN += [s.encode('utf-16-le') for s in ('ModelPlan Community', '社区版')]
FORBIDDEN += [s.encode('utf-16-be') for s in ('ModelPlan Community', '社区版')]


def problems(app, edition):
    found = []
    app = Path(app)
    if app.name != APP_NAME:
        found.append(f'app folder is {app.name!r}, not {APP_NAME!r}')
    try:
        info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    except (OSError, ValueError) as error:
        return found + [f'unreadable Info.plist: {error}']
    expected = {'CFBundleName': 'ModelPlan', 'CFBundleExecutable': EXECUTABLE, 'CFBundleIdentifier': BUNDLE_ID,
                'CFBundleDisplayName': DISPLAY_NAMES[edition], 'ModelPlanEdition': edition}
    for key, value in expected.items():
        if info.get(key) != value:
            found.append(f'Info.plist {key} is {info.get(key)!r}, not {value!r}')
    for key, value in info.items():
        if isinstance(value, str) and 'community' in value.lower():
            found.append(f'Info.plist {key} still says {value!r}')
    if not (app / 'Contents/MacOS' / EXECUTABLE).is_file():
        found.append(f'missing Contents/MacOS/{EXECUTABLE}')
    official_files = [(app / 'Contents/Resources/VISUAL-LICENSE.md').is_file(),
                      (app / 'Contents/Resources/AppIcon.icns').is_file()]
    if edition == 'official' and not all(official_files):
        found.append('official edition without VISUAL-LICENSE.md and AppIcon.icns')
    if edition == 'neutral' and any(official_files):
        found.append('neutral edition carries the official icon or visuals licence')
    for path in sorted(p for p in app.rglob('*') if p.is_file() and not p.is_symlink()):
        data = path.read_bytes()
        for needle in FORBIDDEN:
            if needle in data:
                found.append(f'{path.relative_to(app)} contains a retired product name')
                break
    return found


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--app', required=True, type=Path)
    parser.add_argument('--edition', required=True, choices=sorted(DISPLAY_NAMES))
    args = parser.parse_args(argv)
    found = problems(args.app, args.edition)
    for line in found:
        print('release names: ' + line, file=sys.stderr)
    if found:
        return 1
    print(f'release names ok: {args.app.name} ({args.edition})')
    return 0


if __name__ == '__main__':
    sys.exit(main())
