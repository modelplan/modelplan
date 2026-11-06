# SPDX-License-Identifier: MIT
"""Synthetic candidate archives and a fake host for the preflight and verify-run tests. No real app."""
import hashlib
import io
import json
from pathlib import Path
import plistlib
import stat
import struct
import sys
import zipfile

VERIFICATION = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(VERIFICATION / 'bin'))
import preflight  # noqa: E402

SHA = 'a' * 40
APP = 'ModelPlan Community.app'
ARM64, X86_64 = 0x0100000C, 0x01000007


def fat(*cpus):
    head = struct.pack('>II', 0xCAFEBABE, len(cpus))
    return head + b''.join(struct.pack('>IIIII', cpu, 0, 0, 0, 0) for cpu in cpus) + b'\0' * 64


def info(**changes):
    values = dict(CFBundleExecutable='ModelPlanCommunity', CFBundleIdentifier=preflight.BUNDLE_ID,
                  ModelPlanCockpitEntryEnabled=False, ModelPlanPublicSource=SHA)
    values.update(changes)
    return {k: v for k, v in values.items() if v is not None}


def inner_zip(plist=None, exe=None, bundles=preflight.RESOURCE_BUNDLES, marks=1, helper=b'helper',
              pin=None, extra=(), symlink=None, top=(APP,)):
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, 'w') as archive:
        for app in top:
            contents = app + '/Contents/'
            archive.writestr(contents + 'Info.plist', plistlib.dumps(plist if plist is not None else info()))
            archive.writestr(contents + 'MacOS/ModelPlanCommunity', exe if exe is not None else fat(ARM64, X86_64))
            for bundle in bundles:
                archive.writestr(contents + 'Resources/' + bundle + '/placeholder.txt', 'x')
            for n in range(marks):
                archive.writestr(contents + f'Resources/{preflight.RESOURCE_BUNDLES[2]}/m{n}/zai-white.svg', '<svg/>')
            archive.writestr(contents + 'Helpers/modelplan', helper)
            archive.writestr(contents + 'Resources/modelplan.sha256',
                             (pin or hashlib.sha256(helper).hexdigest()) + '\n')
            for name in extra:
                archive.writestr(contents + name, 'x')
            if symlink:
                link = zipfile.ZipInfo(contents + 'Resources/link')
                link.external_attr = (stat.S_IFLNK | 0o777) << 16
                archive.writestr(link, symlink)
    return buffer.getvalue()


def write_artifact(directory, name, inner=None, build=None, members=None):
    inner = inner if inner is not None else inner_zip()
    build = build if build is not None else (
        f'sourceSHA={SHA}\nrunID=42\nrunAttempt=1\n{hashlib.sha256(inner).hexdigest()}  {preflight.INNER}\n')
    path = Path(directory) / (name + '.zip')
    with zipfile.ZipFile(path, 'w') as archive:
        for member, data in (members or {'BUILD.txt': build, preflight.INNER: inner}).items():
            archive.writestr(member, data)
    return 'sha256:' + hashlib.sha256(path.read_bytes()).hexdigest()


class FakeHost:
    is_macos = True

    def __init__(self, digest, *, run=None, jobs=None, pr_head=SHA, compare='ahead', displays=None, settings=None,
                 executables=(), environ=None, booking=None, codesign=(True, 'adhoc'), files=None, macos=True):
        self.digest, self.pr_head, self.compare = digest, pr_head, compare
        self.run = run if run is not None else dict(repository=dict(full_name=preflight.REPO),
                                                     path='.github/workflows/desktop.yml', head_sha=SHA, run_attempt=1)
        self.jobs = jobs if jobs is not None else [dict(name='app-smoke', conclusion='success')]
        self.displays = displays if displays is not None else [dict(x=0, y=0, width=1512, height=982, scale=2, main=True)]
        self.settings = settings if settings is not None else dict(dockOrientation='bottom', dockAutohide=False,
                                                                     reduceMotion=False, appearance='light', voiceOver=False,
                                                                     menuExtras={'Clock': 1, 'Control Center': 1})
        self._executables = list(executables)
        self.environ = {'MODELPLAN_VERIFICATION_HOST': 'macci'} if environ is None else environ
        self.booking = booking or {'head': None}
        self._codesign = codesign
        self.files = files or {}
        self.is_macos = macos

    def env(self, name):
        return self.environ.get(name)

    def gh_api(self, path):
        if path.endswith('/actions/runs/42'):
            return self.run
        if '/jobs' in path:
            return dict(jobs=self.jobs)
        if '/artifacts?name=' in path:
            return dict(artifacts=[dict(name=path.split('name=')[1], expired=False, digest=self.digest)])
        if '/pulls/' in path:
            return dict(head=dict(sha=self.pr_head))
        if '/compare/' in path:
            return dict(status=self.compare)
        raise RuntimeError('unexpected ' + path)

    def control_file(self, ref, path):
        if path in self.files:
            return self.files[path]
        local = VERIFICATION.parents[2] / path
        return local.read_text(encoding='utf-8') if local.exists() else None

    def extract_app(self, archive, destination):
        if not self.is_macos:
            raise preflight.Unsupported('requires-macos')
        with zipfile.ZipFile(archive) as source:
            source.extractall(destination)

    def codesign(self, app):
        if not self.is_macos:
            raise preflight.Unsupported('requires-macos')
        return self._codesign

    def display_state(self):
        if not self.is_macos:
            raise preflight.Unsupported('requires-macos')
        return dict(displays=self.displays, settings=dict(self.settings))

    def executables(self):
        return self._executables

    def disk_free(self, path):
        return 64 * 1024 ** 3

    def booking_status(self):
        return self.booking


def manifest(digest, profile='synthetic', flavour='release', name=None):
    return dict(schemaVersion=1, batch='batch-001', profile=profile, integrationSHA=SHA, tree='b' * 40,
                prs=[dict(pr=551, head=SHA, ids=['D-01', 'V-01'])],
                artifacts={flavour: dict(name=name or f'native-app-unverified-{SHA}', digest=digest)},
                coordinatorGo='https://github.com/modelplan/modelplan/issues/570#issuecomment-1')
