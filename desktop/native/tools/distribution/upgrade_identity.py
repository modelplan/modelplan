# SPDX-License-Identifier: MIT
"""Validate synthetic G4-12 observations without accessing real installations."""


def validate(value, interim, candidate, helper_version, approved_version):
    if not isinstance(value, dict) or set(value) != {'schemaVersion', 'profile', 'interimBundleID', 'candidateBundleID', 'installations', 'scenarios'}:
        raise ValueError('invalid synthetic receipt')
    if type(value['schemaVersion']) is not int or value['schemaVersion'] != 1 or value['profile'] != 'synthetic':
        raise ValueError('not a synthetic receipt')
    if not interim or not candidate or interim == candidate or value['interimBundleID'] != interim or value['candidateBundleID'] != candidate:
        raise ValueError('bundle identity mismatch')
    if not helper_version or helper_version != approved_version:
        raise ValueError('helper pin mismatch')
    installs = value['installations']
    if not isinstance(installs, list) or len(installs) != 2:
        raise ValueError('incomplete installation observations')
    seen = set()
    for entry in installs:
        if not isinstance(entry, dict) or set(entry) != {'bundleID', 'loginItemNames'}:
            raise ValueError('invalid installation observation')
        bundle, names = entry['bundleID'], entry['loginItemNames']
        if bundle not in (interim, candidate) or bundle in seen or names != [bundle]:
            raise ValueError('login item identity or count mismatch')
        seen.add(bundle)
    scenarios = value['scenarios']
    if not isinstance(scenarios, list) or len(scenarios) != 2:
        raise ValueError('incomplete coexistence observations')
    kinds = set()
    for scenario in scenarios:
        if not isinstance(scenario, dict) or set(scenario) != {'kind', 'dockCount', 'engineCount', 'loginCount', 'settingsWritable'}:
            raise ValueError('invalid coexistence observation')
        if scenario['kind'] not in ('install-over', 'side-by-side') or scenario['kind'] in kinds:
            raise ValueError('invalid coexistence scenario')
        kinds.add(scenario['kind'])
        if any(type(scenario[name]) is not int or scenario[name] != 1 for name in ('dockCount', 'engineCount', 'loginCount')) or scenario['settingsWritable'] is not True:
            raise ValueError('duplicate or unavailable component')
    return True
