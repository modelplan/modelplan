# SPDX-License-Identifier: MIT
"""Pre-flight for a scripted GUI verification run (verification plan v2, section 4). Fail closed.

Every check PF-01..PF-12 records PASS or FAIL in a `preflight.json` receipt; anything unknown is FAIL.
A check that needs a macOS tool (codesign, ditto, the display probe) FAILs with `requires-macos` on any
other host: it never passes silently. Tests inject a fake `Host`; a real run uses `Host()`.

Inputs: the batch manifest (see VERIFY-RUN.md), the lane, the requested layout and IDs, and a directory
holding each flavour's GitHub artifact archive as `<artifact name>.zip`, downloaded unmodified, e.g.
`gh api repos/modelplan/modelplan/actions/artifacts/<id>/zip > <dir>/<name>.zip`. Nothing is launched.
"""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import platform
import plistlib
import posixpath
import re
import shutil
import stat
import struct
import subprocess
import sys
import zipfile

BIN = Path(__file__).resolve().parent
VERIFICATION = BIN.parent
REPO = 'modelplan/modelplan'
CONTROL_PREFIX = 'desktop/native/verification/'
SHA = re.compile(r'[0-9a-f]{40}\Z')
SHA256 = re.compile(r'[0-9a-f]{64}\Z')
ID = re.compile(r'[A-Z][A-Z0-9]{0,3}-[0-9]{2}\Z')
ARTIFACT = re.compile(r'native-app-(unverified|test|verify)-([0-9a-f]{40})\Z')
ARTIFACT_FLAVOUR = {'unverified': 'release', 'test': 'test', 'verify': 'verify'}
FLAVOURS = ('release', 'test', 'verify')
LEGACY_TAURI = 'Model-Plan-Community-macOS-arm64-unsigned'
WORKFLOWS = {'.github/workflows/desktop.yml': 'app-smoke', '.github/workflows/v1-test-build.yml': None,
             '.github/workflows/verify-batch.yml': None}
INNER = 'ModelPlan-Community-native.zip'
EXECUTABLE = 'ModelPlanCommunity'
BUNDLE_ID = 'org.modelplan.community.swift.scaffold'
RESOURCE_BUNDLES = ('ModelPlanAppIntegration_ModelPlanAppIntegration.bundle',
                    'ModelPlanOfficialDock_ModelPlanOfficialDock.bundle',
                    'ModelPlanDockResources_ModelPlanDockResources.bundle')
COCKPIT_BUNDLE = 'Cockpit'  # the verified page CockpitConsoleOwner loads; package-neutral.sh --owner-test copies it
VF_MARKER = 'ModelPlanVerificationFlavour'
UPDATER_KEYS = ('SUFeedURL', 'SUPublicEDKey', 'SUEnableAutomaticChecks')
LANE_HOST = {'V1': 'macci', 'M1': 'dev-mac'}
PROFILES = ('synthetic', 'real')
GUI_TIERS = ('T3', 'T4')
DISK_FLOOR = 8 * 1024 ** 3
CHECKS = tuple(f'PF-{n:02d}' for n in range(1, 13))
CPU = {0x0100000C: 'arm64', 0x01000007: 'x86_64', 0x0000000C: 'arm', 0x00000007: 'i386'}


class Unsupported(Exception):
    """A probe this host cannot perform. The check FAILs; it never passes."""


DISPLAY_PROBE = r"""ObjC.import('AppKit');
var out = {displays: [], settings: {}};
var screens = $.NSScreen.screens;
for (var i = 0; i < screens.count; i++) {
  var s = screens.objectAtIndex(i), f = s.frame;
  out.displays.push({x: f.origin.x, y: f.origin.y, width: f.size.width, height: f.size.height,
                     scale: s.backingScaleFactor, main: i == 0});
}
var ws = $.NSWorkspace.sharedWorkspace;
out.settings.reduceMotion = ws.accessibilityDisplayShouldReduceMotion;
out.settings.voiceOver = ws.isVoiceOverEnabled;
var style = $.NSUserDefaults.standardUserDefaults.stringForKey('AppleInterfaceStyle');
out.settings.appearance = (style.isNil() || ObjC.unwrap(style).toLowerCase() != 'dark') ? 'light' : 'dark';
var dock = $.NSUserDefaults.alloc.initWithSuiteName('com.apple.dock');
var o = dock.stringForKey('orientation');
out.settings.dockOrientation = o.isNil() ? 'bottom' : ObjC.unwrap(o);
out.settings.dockAutohide = dock.boolForKey('autohide');
ObjC.import('CoreGraphics');
var wins = ObjC.castRefToObject($.CGWindowListCopyWindowInfo(1, 0));
var extras = {};
for (var i = 0; i < wins.count; i++) {
  var w = wins.objectAtIndex(i);
  var b = w.objectForKey('kCGWindowBounds');
  if (b.isNil()) continue;
  var d = ObjC.castRefToObject(b);
  var y = ObjC.unwrap(d.objectForKey('Y')), h = ObjC.unwrap(d.objectForKey('Height'));
  if (typeof y !== 'number' || typeof h !== 'number' || y < 0 || y > 8 || h < 4 || h > 40) continue;
  var owner = ObjC.unwrap(w.objectForKey('kCGWindowOwnerName'));
  if (owner) extras[owner] = (extras[owner] || 0) + 1;
}
out.settings.menuExtras = extras;
JSON.stringify(out);"""


class Host:
    """Real probes. Every method either answers or raises; callers turn errors into FAIL."""

    def __init__(self, repo_root=None, environ=None):
        self.repo_root = Path(repo_root) if repo_root else VERIFICATION.parents[2]
        self.environ = os.environ if environ is None else environ

    @property
    def is_macos(self):
        return platform.system() == 'Darwin'

    def env(self, name):
        return self.environ.get(name)

    def gh_api(self, path):
        result = subprocess.run(['gh', 'api', path], capture_output=True, text=True, timeout=60)
        if result.returncode != 0:
            raise RuntimeError('gh api failed: ' + path)
        return json.loads(result.stdout)

    def control_file(self, ref, path):
        """A file from main's control revision, never from the candidate or the working tree."""
        result = subprocess.run(['git', '-C', str(self.repo_root), 'show', f'{ref}:{path}'],
                                capture_output=True, timeout=60)
        if result.returncode != 0:
            return None
        return result.stdout.decode('utf-8')

    def extract_app(self, archive, destination):
        if not self.is_macos:
            raise Unsupported('requires-macos')
        subprocess.run(['/usr/bin/ditto', '-x', '-k', '--noqtn', str(archive), str(destination)],
                       check=True, capture_output=True, timeout=300)

    def codesign(self, app):
        if not self.is_macos:
            raise Unsupported('requires-macos')
        verify = subprocess.run(['/usr/bin/codesign', '--verify', '--deep', '--strict', str(app)],
                                capture_output=True, text=True, timeout=300)
        from launch import signature_kind
        kind = signature_kind(subprocess.run(['/usr/bin/codesign', '-dv', str(app)], capture_output=True, text=True))
        return verify.returncode == 0, kind

    def display_state(self):
        if not self.is_macos:
            raise Unsupported('requires-macos')
        result = subprocess.run(['/usr/bin/osascript', '-l', 'JavaScript', '-e', DISPLAY_PROBE],
                                capture_output=True, text=True, timeout=30)
        if result.returncode != 0:
            raise RuntimeError('display probe failed')
        return json.loads(result.stdout)

    def executables(self):
        """(pid, executable path) of this user's processes; paths only, never environments or arguments."""
        import process_scan
        if self.is_macos:
            return list(process_scan._darwin_candidates())
        if platform.system() == 'Linux':
            return list(process_scan._linux_candidates())
        raise Unsupported('process listing unsupported')

    def disk_free(self, path):
        return shutil.disk_usage(path).free

    def booking_status(self):
        import book
        return book.Ledger(self.environ.get('MODELPLAN_BOOKING_LEDGER')).status()


def check(results, ident, ok, detail, **extra):
    results.append(dict(id=ident, status='PASS' if ok is True else 'FAIL', detail=detail, **extra))
    return ok is True


def sha256_bytes(data):
    return hashlib.sha256(data).hexdigest()


def sha256_file(path):
    digest = hashlib.sha256()
    with open(path, 'rb') as stream:
        for block in iter(lambda: stream.read(1 << 20), b''):
            digest.update(block)
    return digest.hexdigest()


def parse_build(text):
    """#551's BUILD.txt: key=value lines (sourceSHA, runID, runAttempt, optional flavour) plus one
    `shasum -a 256` line `<64 hex>  ModelPlan-Community-native.zip`."""
    fields, sums = {}, {}
    for line in text.splitlines():
        if not line.strip():
            continue
        match = re.fullmatch(r'([0-9a-f]{64})\s+\*?(\S.*)', line.strip())
        if match:
            sums[match.group(2)] = match.group(1)
        elif '=' in line:
            key, value = line.split('=', 1)
            if key.strip() in fields:
                raise ValueError('duplicate BUILD.txt field ' + key.strip())
            fields[key.strip()] = value.strip()
        else:
            raise ValueError('unrecognised BUILD.txt line')
    return fields, sums


def macho_archs(data):
    if len(data) < 8:
        return None
    magic = struct.unpack('>I', data[:4])[0]
    if magic in (0xCAFEBABE, 0xCAFEBABF):
        count = struct.unpack('>I', data[4:8])[0]
        size = 20 if magic == 0xCAFEBABE else 32
        if count == 0 or count > 16 or len(data) < 8 + count * size:
            return None
        return [CPU.get(struct.unpack('>I', data[8 + i * size:12 + i * size])[0], 'unknown') for i in range(count)]
    if magic in (0xFEEDFACF, 0xFEEDFACE):
        return [CPU.get(struct.unpack('>I', data[4:8])[0], 'unknown')]
    if magic in (0xCFFAEDFE, 0xCEFAEDFE):
        return [CPU.get(struct.unpack('<I', data[4:8])[0], 'unknown')]
    return None


def app_shape(archive):
    """PF-05 on the zip itself: exactly one top-level .app and no symlink leaving it."""
    names = [i for i in archive.infolist() if not i.filename.startswith('__MACOSX/')]
    tops = {PurePosixPath(i.filename).parts[0] for i in names if i.filename.strip('/')}
    if any(i.filename.startswith('/') or '..' in PurePosixPath(i.filename).parts for i in names):
        raise ValueError('archive path escapes')
    if len(tops) != 1 or not next(iter(tops)).endswith('.app'):
        raise ValueError('archive must contain exactly one top-level .app')
    app = next(iter(tops))
    for info in names:
        if stat.S_ISLNK(info.external_attr >> 16):
            target = archive.read(info).decode('utf-8', 'replace')
            resolved = posixpath.normpath(posixpath.join(posixpath.dirname(info.filename), target))
            if target.startswith('/') or not (resolved == app or resolved.startswith(app + '/')):
                raise ValueError('app symlink leaves the bundle')
    return app


def read_member(archive, name):
    try:
        return archive.read(name)
    except KeyError:
        return None


# Where configure_beta_zai (tools/distribution/release.py) finds the Dock resource manifest.
DOCK_MANIFESTS = ('Resources/manifest.json', 'Contents/Resources/Resources/manifest.json',
                  'Contents/Resources/manifest.json', 'manifest.json')


def mark_problems(inner, info, names, dock):
    """PF-07's Z.ai mark policy, matching the producers: package-neutral.sh always removes the
    beta-only mark and writes no `zaiMarkEnabled`; release.py configure_beta_zai sets the boolean and,
    only when true, restores exactly one mark at the manifest's path with the manifest's bytes."""
    marks = sorted(n for n in names if n.startswith(dock) and n.endswith('/zai-white.svg'))
    enabled = info.get('zaiMarkEnabled', False)
    if type(enabled) is not bool:
        return ['zaiMarkEnabled is not a boolean']
    if not enabled:
        return [] if not marks else [f'{len(marks)} zai-white.svg mark(s) without zaiMarkEnabled '
                                     '(neutral builds exclude the beta-only mark)']
    if len(marks) != 1:
        return [f'{len(marks)} zai-white.svg marks with zaiMarkEnabled (need exactly one)']
    manifests = [dock + m for m in DOCK_MANIFESTS if dock + m in names]
    if len(manifests) != 1:
        return ['beta mark without exactly one Dock resource manifest']
    try:
        record = json.loads(read_member(inner, manifests[0]) or b'')['files']['logo-zai-white']
    except (ValueError, KeyError, TypeError):
        return ['beta mark manifest record unreadable']
    root = manifests[0][:-len('manifest.json')]
    if (not isinstance(record, dict) or record.get('betaOnly') is not True
            or record.get('path') != 'Marks/zai-white.svg' or marks[0] != root + record['path']):
        return ['beta mark is not at the manifest path']
    data = read_member(inner, marks[0])
    if data is None or len(data) != record.get('bytes') or sha256_bytes(data) != record.get('sha256'):
        return ['beta mark bytes do not match the manifest record']
    return []


def bundle_public_source(inner_bytes):
    """The source commit the bundle itself records (Info.plist ModelPlanPublicSource, written by
    package-neutral.sh from the checkout's real `git rev-parse HEAD`), or None when it cannot be read.
    This is what binds the BUILD.txt label to the tree that was actually built."""
    try:
        with zipfile.ZipFile(io.BytesIO(inner_bytes)) as inner:
            plists = [n for n in inner.namelist()
                      if n.count('/') == 2 and n.endswith('.app/Contents/Info.plist')]
            if len(plists) != 1:
                return None
            info = plistlib.loads(read_member(inner, plists[0]) or b'')
    except Exception:
        return None
    value = info.get('ModelPlanPublicSource') if isinstance(info, dict) else None
    return value if isinstance(value, str) else None


def candidate_checks(results, host, flavour, entry, expected_sha, artifacts_dir, work):
    """PF-01..PF-09 for one flavour. Returns the extracted .app path (or None)."""
    name = entry.get('name') if isinstance(entry, dict) else None
    tag = dict(flavour=flavour)
    match = ARTIFACT.fullmatch(name or '')
    named_ok = bool(match) and ARTIFACT_FLAVOUR[match.group(1)] == flavour and match.group(2) == expected_sha
    if not check(results, 'PF-01', named_ok and name != LEGACY_TAURI,
                 f'artifact {name!r}' + ('' if named_ok else ': need native-app-(unverified|test|verify)-<sha> '
                                         'for this flavour and SHA; the legacy Tauri DMG and any .dmg are refused'), **tag):
        return None
    outer = Path(artifacts_dir) / (name + '.zip')
    digest = str(entry.get('digest', '')).removeprefix('sha256:')
    try:
        if outer.is_symlink() or not outer.is_file():
            raise ValueError(f'missing artifact archive {outer.name}')
        outer_sha = sha256_file(outer)
        with zipfile.ZipFile(outer) as wrapper:
            members = sorted(i.filename for i in wrapper.infolist() if not i.is_dir())
            if any(m.lower().endswith('.dmg') for m in members):
                raise ValueError('artifact holds a .dmg; refused')
            if members != sorted(['BUILD.txt', INNER]):
                raise ValueError(f'artifact must hold exactly BUILD.txt and {INNER}')
            build_text = wrapper.read('BUILD.txt').decode('utf-8')
            inner_bytes = wrapper.read(INNER)
        fields, sums = parse_build(build_text)
    except (OSError, ValueError, zipfile.BadZipFile, UnicodeDecodeError) as error:
        check(results, 'PF-02', False, str(error), **tag)
        return None
    run_id = fields.get('runID', '')
    api_digest = None
    try:
        if not run_id.isdigit():
            raise ValueError('BUILD.txt runID missing')
        run = host.gh_api(f'repos/{REPO}/actions/runs/{run_id}')
        path = str(run.get('path', '')).split('@', 1)[0]
        problems = []
        if (run.get('repository') or {}).get('full_name') != REPO:
            problems.append('run not in ' + REPO)
        if path not in WORKFLOWS:
            problems.append('workflow not allowed: ' + path)
        if run.get('head_sha') != expected_sha:
            problems.append('run head_sha differs from the expected SHA')
        attempt = fields.get('runAttempt', str(run.get('run_attempt', '')))
        job = entry.get('job') or WORKFLOWS.get(path)
        if not job:
            problems.append('producing job unknown for ' + path)
        else:
            jobs = host.gh_api(f'repos/{REPO}/actions/runs/{run_id}/attempts/{attempt}/jobs?per_page=100').get('jobs', [])
            named = [j for j in jobs if j.get('name') == job]
            if len(named) != 1 or named[0].get('conclusion') != 'success':
                problems.append(f'producing job {job} did not succeed')
        listed = host.gh_api(f'repos/{REPO}/actions/runs/{run_id}/artifacts?name={name}').get('artifacts', [])
        if len(listed) != 1:
            problems.append('artifact not found on the run')
        else:
            artifact = listed[0]
            if artifact.get('expired') is not False:
                problems.append('artifact expired')
            api_digest = str(artifact.get('digest') or '').removeprefix('sha256:')
        check(results, 'PF-02', not problems, '; '.join(problems) or f'run {run_id} {path} job {job}', **tag)
    except Exception as error:  # unknown is FAIL
        check(results, 'PF-02', False, 'provenance unknown: ' + (str(error) or type(error).__name__), **tag)
        api_digest = None
    inner_sha = sha256_bytes(inner_bytes)
    digest_ok = SHA256.fullmatch(digest) and outer_sha == digest and api_digest == digest and sums.get(INNER) == inner_sha
    check(results, 'PF-03', bool(digest_ok),
          'artifact archive matches the manifest and GitHub digests; inner zip matches BUILD.txt' if digest_ok else
          'sha256 mismatch between artifact archive, manifest digest, GitHub digest or BUILD.txt', **tag)
    source = fields.get('sourceSHA', '')
    build_flavour = fields.get('flavour')
    # The label alone is not provenance: a pull_request run that built the synthetic merge commit
    # can still be labelled with the PR head. The bundle's own recorded source (the built tree's
    # HEAD) must equal both the label and the expected SHA; unreadable or different fails closed.
    built = bundle_public_source(inner_bytes)
    source_ok = (source == expected_sha and built == expected_sha
                 and (build_flavour is None or build_flavour == flavour))
    check(results, 'PF-04', source_ok, f'BUILD.txt sourceSHA={source or "missing"} '
          f'bundle ModelPlanPublicSource={built or "missing"}'
          + (f' flavour={build_flavour}' if build_flavour else '')
          + ('' if built in (None, source) else ': the bundle was built from a different tree than its label'), **tag)
    try:
        inner = zipfile.ZipFile(io.BytesIO(inner_bytes))
        app = app_shape(inner)
        check(results, 'PF-05', True, 'one top-level ' + app, **tag)
    except (ValueError, zipfile.BadZipFile) as error:
        check(results, 'PF-05', False, str(error), **tag)
        return None
    contents = app + '/Contents/'
    try:
        info = plistlib.loads(read_member(inner, contents + 'Info.plist') or b'')
    except Exception:
        info = {}
    exe = read_member(inner, contents + 'MacOS/' + EXECUTABLE) or b''
    archs = macho_archs(exe)
    want_id = entry.get('bundleIdentifier', BUNDLE_ID)
    exact = entry.get('exactArm64') is True
    shape = (info.get('CFBundleExecutable') == EXECUTABLE and archs is not None and 'arm64' in archs
             and (not exact or archs == ['arm64']) and info.get('CFBundleIdentifier') == want_id)
    check(results, 'PF-06', shape, f'CFBundleExecutable={info.get("CFBundleExecutable")!r} '
          f'archs={archs} bundleID={info.get("CFBundleIdentifier")!r}', **tag)
    names = set(inner.namelist())
    resources = contents + 'Resources/'
    wanted = list(RESOURCE_BUNDLES) + ([COCKPIT_BUNDLE] if flavour in ('test', 'verify') else [])
    missing = [b for b in wanted if not any(n.startswith(resources + b + '/') for n in names)]
    helper = read_member(inner, contents + 'Helpers/modelplan')
    pin = (read_member(inner, resources + 'modelplan.sha256') or b'').decode('ascii', 'replace').strip()
    helper_ok = helper is not None and SHA256.fullmatch(pin) and sha256_bytes(helper) == pin
    problems = ([f'missing {", ".join(missing)}'] if missing else []) + \
               mark_problems(inner, info, names, resources + RESOURCE_BUNDLES[2] + '/') + \
               ([] if helper_ok else ['Helpers/modelplan does not match Resources/modelplan.sha256'])
    check(results, 'PF-07', not problems, '; '.join(problems) or 'resource bundles and helper pin present', **tag)
    entry_flag = info.get('ModelPlanCockpitEntryEnabled')
    want_flag = flavour != 'release'
    marker = VF_MARKER in info
    updater = [k for k in UPDATER_KEYS if k in info] + \
              (['Sparkle.framework'] if any('/Sparkle.framework/' in n for n in names) else [])
    flavour_ok = type(entry_flag) is bool and entry_flag == want_flag and marker == (flavour == 'verify') and not updater
    check(results, 'PF-08', flavour_ok, f'ModelPlanCockpitEntryEnabled={entry_flag!r} (want {want_flag}); '
          f'VF marker {"present" if marker else "absent"}; updater {updater or "none"}', **tag)
    try:
        destination = Path(work) / flavour
        destination.mkdir(parents=True, exist_ok=False)
        staged = destination / INNER
        staged.write_bytes(inner_bytes)
        host.extract_app(staged, destination / 'app')
        extracted = destination / 'app' / app
        ok, kind = host.codesign(extracted)
        check(results, 'PF-09', ok, f'codesign --verify --deep --strict {"passed" if ok else "failed"}; signature {kind}',
              signature=kind, **tag)
        return extracted if ok else None
    except Unsupported as error:
        check(results, 'PF-09', False, str(error), **tag)
    except Exception as error:
        check(results, 'PF-09', False, 'signature unknown: ' + (str(error) or type(error).__name__), **tag)
    return None


def load_tiers(text):
    tiers = {}
    for line in (text or '').splitlines():
        if not line.strip() or line.startswith('#') or line.startswith('id\t'):
            continue
        parts = line.split('\t')
        if len(parts) >= 2 and ID.fullmatch(parts[0]):
            tiers[parts[0]] = parts[1]
    return tiers


def validate_steps(step, ident):
    """The scenario step-file contract (VERIFY-RUN.md). Returns a list of problems."""
    import verify_steps
    return verify_steps.problems(step, ident)


def scenario_checks(results, host, ids, control_ref, layout, flavours, profile):
    """PF-10: tier from main's control revision and a matching step file; per-ID refusals."""
    tiers = load_tiers(host.control_file(control_ref, CONTROL_PREFIX + 'scenario-tiers.tsv'))
    accepted, refused, steps = [], {}, {}
    for ident in ids:
        tier = tiers.get(ident)
        if tier not in GUI_TIERS:
            refused[ident] = f'tier {tier or "unknown"} does not belong in a GUI run'
            continue
        raw = host.control_file(control_ref, f'{CONTROL_PREFIX}scenarios/{ident}.json')
        try:
            step = json.loads(raw) if raw is not None else None
        except ValueError:
            step = None
        if step is None:
            refused[ident] = 'no step file on the control revision'
            continue
        problems = validate_steps(step, ident)
        if not problems and step['layout'] not in ('any', layout):
            problems.append(f'step layout {step["layout"]} differs from {layout}')
        if not problems and not set(step['flavours']) & set(flavours):
            problems.append('no manifest flavour matches the step file')
        if not problems and profile not in step['profiles']:
            problems.append(f'step file does not allow profile {profile}')
        if problems:
            refused[ident] = '; '.join(problems)
            continue
        accepted.append(ident); steps[ident] = step
    check(results, 'PF-10', bool(accepted) and tiers != {},
          f'{len(accepted)} accepted, {len(refused)} refused (refused IDs run as NOT-RUN)', accepted=accepted, refused=refused)
    return accepted, refused, steps


def arrangement_problems(state, spec):
    displays = state.get('displays') or []
    want = spec['displays']
    if len(displays) != len(want):
        return [f'{len(displays)} displays, layout needs {len(want)}']
    problems = []
    main = [d for d in displays if d.get('main')]
    if len(main) != 1:
        return ['main display unknown']
    named = {'A': main[0]}
    others = [d for d in displays if not d.get('main')]
    for relation in spec.get('relations', []):
        anchor = named[relation.get('rightOf') or relation.get('leftOf') or relation.get('below')]
        def fits(d):
            ok = True
            if 'rightOf' in relation:
                ok &= d['x'] >= anchor['x'] + anchor['width']
            if 'leftOf' in relation:
                ok &= d['x'] + d['width'] / 2 < anchor['x'] + anchor['width'] / 2
            if 'below' in relation:
                ok &= d['y'] + d['height'] <= anchor['y']
            return ok
        fit = [d for d in others if fits(d) and d not in named.values()]
        if len(fit) != 1:
            problems.append(f'display {relation["display"]} not found in its position')
        else:
            named[relation['display']] = fit[0]
    for item in want:
        actual = named.get(item['name'])
        if actual is not None and item.get('scale') is not None and actual.get('scale') != item['scale']:
            problems.append(f'display {item["name"]} scale {actual.get("scale")} (need {item["scale"]})')
    return problems


def host_checks(results, host, lane, layout, profile, layouts, scratch_parent):
    """PF-11 host, layout and system baseline; PF-12 clean state."""
    declared = (host.env('MODELPLAN_VERIFICATION_HOST') or '').strip() or 'dev-mac'
    problems = []
    if LANE_HOST.get(lane) != declared:
        problems.append(f'lane {lane} needs MODELPLAN_VERIFICATION_HOST={LANE_HOST.get(lane)} (this host: {declared})')
    if profile == 'real' and lane not in LANE_HOST:
        problems.append('real-account runs are allowed only on M1 and V1 hosts')
    state = None
    spec = (layouts.get('layouts') or {}).get(layout)
    if spec is None:
        problems.append('unknown layout ' + str(layout))
    try:
        state = host.display_state()
        if spec is not None:
            problems += arrangement_problems(state, spec)
        baseline = layouts.get('systemBaseline') or {}
        settings = state.get('settings') or {}
        for key, value in baseline.items():
            if settings.get(key) != value:
                problems.append(f'{key}={settings.get(key)!r} (baseline {value!r})')
    except Unsupported as error:
        problems.append(str(error))
    except Exception as error:
        problems.append('display/system state unknown: ' + (str(error) or type(error).__name__))
    check(results, 'PF-11', not problems, '; '.join(problems) or f'{declared} {layout} at baseline',
          host=declared, systemState=state)
    problems = []
    try:
        running = [path for _, path in host.executables()
                   if path.endswith('/Contents/MacOS/' + EXECUTABLE) or path.endswith('/Contents/Helpers/modelplan')]
        if running:
            problems.append(f'{len(running)} ModelPlan process(es) already running')
        if any(path.endswith('/bin/Runner.Worker') for _, path in host.executables()):
            problems.append('a CI job is running on this machine')
    except Exception as error:
        problems.append('process state unknown: ' + (str(error) or type(error).__name__))
    parent = Path(scratch_parent) if scratch_parent else None
    if parent is None or not parent.is_dir() or parent.is_symlink():
        problems.append('scratch parent must be an existing local directory')
    else:
        if profile == 'synthetic' and any(parent.glob('modelplan-candidate-*')):
            problems.append('stale candidate scratch under the scratch parent (synthetic HOME must be fresh)')
        try:
            if host.disk_free(parent) < DISK_FLOOR:
                problems.append('less than 8 GiB free')
        except OSError:
            problems.append('free disk unknown')
    try:
        status = host.booking_status()
        head = status.get('head')
        if head and head.get('state') == 'started':
            problems.append(f'another GUI booking is started ({head.get("lane")})')
    except Exception as error:
        problems.append('booking ledger unknown: ' + (str(error) or type(error).__name__))
    home = ('fresh synthetic HOME (created by packaged_candidate prepare; no consent grant)' if profile == 'synthetic'
            else 'real account HOME of the test Mac (owner decision 2026-11-05)')
    check(results, 'PF-12', not problems, '; '.join(problems) or 'clean: ' + home, home=home)


def manifest_checks(results, host, manifest):
    """Part of PF-04: every PR head is in the integration SHA and is still the PR's current head."""
    expected = manifest.get('integrationSHA', '')
    problems = []
    for pr in manifest.get('prs', []):
        number, head = pr.get('pr'), pr.get('head', '')
        if type(number) is not int or not SHA.fullmatch(head or ''):
            problems.append(f'bad PR entry {number!r}'); continue
        try:
            current = host.gh_api(f'repos/{REPO}/pulls/{number}')['head']['sha']
            if current != head:
                problems.append(f'#{number} head moved (batch is stale)')
            compare = host.gh_api(f'repos/{REPO}/compare/{head}...{expected}')
            if compare.get('status') not in ('ahead', 'identical'):
                problems.append(f'#{number} head is not an ancestor of the integration SHA')
        except Exception as error:
            problems.append(f'#{number} unknown: ' + (str(error) or type(error).__name__))
    check(results, 'PF-04', not problems, '; '.join(problems) or f'{len(manifest.get("prs", []))} PR heads current',
          scope='batch')


def validate_manifest(manifest, lane=None):
    problems = []
    if not isinstance(manifest, dict):
        return ['manifest must be an object']
    if not SHA.fullmatch(str(manifest.get('integrationSHA', ''))):
        problems.append('integrationSHA must be 40 lowercase hex')
    if manifest.get('profile') not in PROFILES:
        problems.append('profile must be synthetic or real')
    artifacts = manifest.get('artifacts')
    if not isinstance(artifacts, dict) or not artifacts or set(artifacts) - set(FLAVOURS):
        problems.append('artifacts must map release/test/verify to {name, digest}')
    if not str(manifest.get('coordinatorGo', '')).startswith('https://github.com/'):
        problems.append('coordinatorGo must be the GitHub URL of the coordinator GO comment')
    if lane == 'M1' and not str(manifest.get('approval', '')).startswith('https://'):
        # M1 releases on its own approval comment (release.py refuses a coordinator GO on dev-mac).
        problems.append('an M1 batch needs approval: the https URL of the coordinator OK comment')
    if not isinstance(manifest.get('prs', []), list):
        problems.append('prs must be a list')
    return problems


def run(manifest, *, lane, layout, ids, artifacts_dir, work, scratch_parent, host=None,
        control_ref='origin/main', layouts=None):
    host = host or Host()
    results = []
    problems = validate_manifest(manifest, lane)
    profile = manifest.get('profile') if isinstance(manifest, dict) else None
    receipt = dict(schemaVersion=1, lane=lane, layout=layout, profile=profile,
                   expectedSHA=manifest.get('integrationSHA') if isinstance(manifest, dict) else None,
                   controlRef=control_ref, requested=list(ids), checks=results)
    if problems:
        for ident in CHECKS:
            check(results, ident, False, 'manifest invalid: ' + '; '.join(problems))
        receipt.update(outcome='FAIL', accepted=[], refused={i: 'manifest invalid' for i in ids}, apps={})
        return receipt
    expected = manifest['integrationSHA']
    if layouts is None:
        raw = host.control_file(control_ref, CONTROL_PREFIX + 'layouts.json')
        layouts = json.loads(raw) if raw else {}
    apps = {}
    for flavour, entry in manifest['artifacts'].items():
        app = candidate_checks(results, host, flavour, entry, expected, artifacts_dir, work)
        if app is not None:
            apps[flavour] = str(app)
    manifest_checks(results, host, manifest)
    accepted, refused, steps = scenario_checks(results, host, ids, control_ref, layout, list(manifest['artifacts']), profile)
    host_checks(results, host, lane, layout, profile, layouts, scratch_parent)
    seen = {r['id'] for r in results}
    for ident in CHECKS:  # a check that never ran is unknown, so FAIL
        if ident not in seen:
            check(results, ident, False, 'not evaluated')
    outcome = 'PASS' if all(r['status'] == 'PASS' for r in results) else 'FAIL'
    receipt.update(outcome=outcome, accepted=accepted, refused=refused, apps=apps, steps=steps,
                   systemBaseline=layouts.get('systemBaseline') or {})
    return receipt


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--batch', type=Path, required=True, help='batch manifest JSON')
    parser.add_argument('--lane', choices=sorted(LANE_HOST), required=True)
    parser.add_argument('--layout', required=True)
    parser.add_argument('--scenarios', required=True, help='comma-separated IDs or @file')
    parser.add_argument('--artifacts-dir', type=Path, required=True)
    parser.add_argument('--scratch-parent', type=Path, required=True)
    parser.add_argument('--work', type=Path, required=True, help='new directory for extracted candidates')
    parser.add_argument('--control-ref', default='origin/main')
    parser.add_argument('--output', type=Path, required=True, help='new preflight.json path')
    args = parser.parse_args(argv)
    ids = parse_ids(args.scenarios)
    manifest = json.loads(args.batch.read_text(encoding='utf-8'))
    args.work.mkdir(parents=True, exist_ok=False)
    receipt = run(manifest, lane=args.lane, layout=args.layout, ids=ids, artifacts_dir=args.artifacts_dir,
                  work=args.work, scratch_parent=args.scratch_parent, control_ref=args.control_ref)
    with args.output.open('x', encoding='utf-8') as stream:
        json.dump(receipt, stream, indent=1, sort_keys=True)
    print(json.dumps(dict(outcome=receipt['outcome'], failed=[r['id'] for r in receipt['checks'] if r['status'] != 'PASS'])))
    return 0 if receipt['outcome'] == 'PASS' else 1


def parse_ids(value):
    if value.startswith('@'):
        value = Path(value[1:]).read_text(encoding='utf-8')
    ids = [x for x in re.split(r'[\s,]+', value) if x]
    bad = [x for x in ids if not ID.fullmatch(x)]
    if bad:
        raise ValueError('bad scenario IDs: ' + ', '.join(bad))
    return list(dict.fromkeys(ids))


if __name__ == '__main__':
    sys.exit(main())
