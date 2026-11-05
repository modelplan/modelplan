# SPDX-License-Identifier: MIT
"""Scenario step files (`verification/scenarios/<ID>.json`): the format and its validator.

The format is documented in VERIFY-RUN.md. preflight PF-10 and verify-run.py both use `problems()`;
an ID whose step file has any problem is refused (NOT-RUN), never guessed at.
"""
import re

ID = re.compile(r'[A-Z][A-Z0-9]{0,3}-[0-9]{2}\Z')
NAME = re.compile(r'[a-z0-9][a-z0-9-]{0,39}\Z')
FLAVOURS = ('release', 'test', 'verify')
PROFILES = ('synthetic', 'real')
LAYOUTS = ('any', 'single', 'abc')
LAUNCH = ('fresh', 'running')
SETTINGS = ('appearance',)
STATUS_MENU_ACTIONS = ('refresh', 'settings', 'console', 'quit')  # StatusMenu/README.md fixed IDs
# action -> (required fields with their types, optional fields with their types)
ACTIONS = {
    'wait-window': ({'timeoutSeconds': (int, float)}, {'budgetSeconds': (int, float)}),
    'expect-no-window': ({'timeoutSeconds': (int, float)}, {}),
    'capture-window': ({}, {}),
    'capture-menubar': ({'width': int, 'height': int}, {}),
    'set-appearance': ({'value': str}, {}),
    'status-menu': ({'item': str, 'menuAction': str}, {}),
    'relaunch': ({}, {}),
    'dwell': ({'seconds': (int, float)}, {}),
}
TOP = {'schemaVersion', 'id', 'spec', 'summary', 'flavours', 'profiles', 'layout', 'launch',
       'estimatedSeconds', 'systemSettings', 'steps', 'review'}


def problems(step, ident=None):
    out = []
    if not isinstance(step, dict):
        return ['step file must be an object']
    if set(step) != TOP:
        out.append('fields must be exactly: ' + ', '.join(sorted(TOP)))
        return out
    if step['schemaVersion'] != 1:
        out.append('schemaVersion must be 1')
    if not isinstance(step['id'], str) or not ID.fullmatch(step['id']) or (ident is not None and step['id'] != ident):
        out.append('id must match the file name')
    for key in ('spec', 'summary', 'review'):
        if not isinstance(step[key], str) or not step[key].strip():
            out.append(key + ' must be non-empty text')
    for key, allowed in (('flavours', FLAVOURS), ('profiles', PROFILES)):
        value = step[key]
        if not isinstance(value, list) or not value or any(v not in allowed for v in value) or len(set(value)) != len(value):
            out.append(f'{key} must be a non-empty list of {", ".join(allowed)}')
    if step['layout'] not in LAYOUTS:
        out.append('layout must be one of ' + ', '.join(LAYOUTS))
    if step['launch'] not in LAUNCH:
        out.append('launch must be fresh or running')
    seconds = step['estimatedSeconds']
    if type(seconds) is not int or not 1 <= seconds <= 900:
        out.append('estimatedSeconds must be an integer from 1 to 900')
    settings = step['systemSettings']
    if not isinstance(settings, list) or any(s not in SETTINGS for s in settings):
        out.append('systemSettings may list only: ' + ', '.join(SETTINGS))
    steps = step['steps']
    if not isinstance(steps, list) or not 1 <= len(steps) <= 32:
        out.append('steps must be a list of 1 to 32 steps')
        return out
    names = set()
    for index, item in enumerate(steps):
        where = f'step {index + 1}'
        if not isinstance(item, dict) or item.get('action') not in ACTIONS:
            out.append(f'{where}: unknown action'); continue
        required, optional = ACTIONS[item['action']]
        extra = set(item) - {'name', 'action'} - set(required) - set(optional)
        if extra or any(k not in item for k in required):
            out.append(f'{where}: {item["action"]} takes {", ".join(sorted(required) + sorted(optional)) or "no fields"}')
            continue
        for key, kind in {**required, **optional}.items():
            if key in item and (type(item[key]) is bool or not isinstance(item[key], kind)):
                out.append(f'{where}: {key} has the wrong type')
        name = item.get('name')
        if not isinstance(name, str) or not NAME.fullmatch(name) or name in names:
            out.append(f'{where}: name must be a unique lowercase slug')
        names.add(name)
        if item['action'] == 'set-appearance':
            if item.get('value') not in ('light', 'dark'):
                out.append(f'{where}: appearance must be light or dark')
            if 'appearance' not in settings:
                out.append(f'{where}: set-appearance needs "appearance" in systemSettings (restored after the ID)')
        if item['action'] == 'status-menu' and not NAME.fullmatch(str(item.get('menuAction', ''))):
            out.append(f'{where}: menuAction must be a lowercase slug; the fixed IDs are '
                       f'{", ".join(STATUS_MENU_ACTIONS)} (hide/show has no fixed action ID yet: the app menu '
                       'carries no such item, so those actions stay NOT-RUN at run time)')
        if item['action'] in ('wait-window', 'expect-no-window') and not 0 < item.get('timeoutSeconds', 0) <= 60:
            out.append(f'{where}: timeoutSeconds must be in (0, 60]')
        if item['action'] == 'dwell' and not 0 <= item.get('seconds', -1) <= 60:
            out.append(f'{where}: dwell seconds must be in [0, 60]')
        if item['action'] == 'capture-menubar' and not (0 < item.get('width', 0) <= 1200 and 0 < item.get('height', 0) <= 60):
            out.append(f'{where}: menu-bar crop must be at most 1200 x 60 points')
    return out
