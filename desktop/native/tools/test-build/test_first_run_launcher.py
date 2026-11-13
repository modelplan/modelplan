# SPDX-License-Identifier: MIT
"""PROF-02: the owner test zip's "ModelPlan First Run.command", run through the real script with shimmed macOS tools."""
import os
import re
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
LAUNCHER = HERE / 'ModelPlan First Run.command'
ROOT = HERE.parents[3]

SHIMS = {
    'osascript': 'echo "quit $*" >> "$LOG"',
    'pgrep': 'exit 1',
    'pkill': 'echo "pkill $*" >> "$LOG"',
    'defaults': '[ "${OWNER_TEST:-1}" = 1 ] && echo 1 || exit 1',
    'open': ('echo "open $*" >> "$LOG"\n'
             'root="${MODELPLAN_PROFILE_ROOT_SEEN:-}"\n'
             'for a in "$@"; do case "$a" in MODELPLAN_PROFILE_ROOT=*) root="${a#*=}";; esac; done\n'
             'echo "$root" > "$ROOTFILE"; touch "$root/settings.json"; [ "${OPEN_FAILS:-0}" = 1 ] && exit 3; exit 0'),
}


class FirstRunLauncher(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='prof2-')
        self.addCleanup(self.temp.cleanup)
        self.dir = Path(self.temp.name)
        self.bin = self.dir / 'bin'; self.bin.mkdir()
        for name, body in SHIMS.items():
            shim = self.bin / name
            shim.write_text('#!/bin/bash\n' + body + '\n')
            shim.chmod(0o755)
        self.zip = self.dir / 'zip'; self.zip.mkdir()
        (self.zip / 'ModelPlan Community.app').mkdir()
        self.script = self.zip / LAUNCHER.name
        self.script.write_bytes(LAUNCHER.read_bytes()); self.script.chmod(0o755)
        self.tmpdir = self.dir / 'tmp'; self.tmpdir.mkdir()
        self.log = self.dir / 'log'; self.rootfile = self.dir / 'root'

    def run_launcher(self, **env):
        base = {'PATH': f'{self.bin}:/usr/bin:/bin', 'TMPDIR': str(self.tmpdir), 'LOG': str(self.log),
                'ROOTFILE': str(self.rootfile), 'HOME': str(self.dir / 'home')}
        return subprocess.run(['bash', str(self.script)], env=base | env, capture_output=True, text=True, timeout=60)

    def logged(self):
        return self.log.read_text().splitlines() if self.log.exists() else []

    def test_quits_runs_a_first_run_in_a_temporary_profile_and_deletes_it(self):
        result = self.run_launcher()
        self.assertEqual(result.returncode, 0, result.stderr)
        lines = self.logged()
        kinds = [line.split()[0] for line in lines]
        self.assertLess(kinds.index('quit'), kinds.index('open'))  # ModelPlan is quit before the new start
        opened = next(line for line in lines if line.startswith('open'))
        for flag in ('-W', '-n', '-F', '-ApplePersistenceIgnoreState YES'):
            self.assertIn(flag, opened)
        root = Path(self.rootfile.read_text().strip())
        self.assertEqual(root.parent, self.tmpdir.resolve())
        self.assertRegex(root.name, r'^modelplan-first-run\.')
        self.assertFalse(root.exists(), 'the profile must be deleted when ModelPlan quits')
        self.assertFalse((self.dir / 'home').exists())  # nothing written to the real HOME

    def test_profile_is_deleted_even_when_the_app_fails(self):
        result = self.run_launcher(OPEN_FAILS='1')
        self.assertEqual(result.returncode, 3)
        self.assertFalse(Path(self.rootfile.read_text().strip()).exists())
        self.assertTrue(any(line.startswith('pkill') and 'Helpers/modelplan' in line for line in self.logged()))

    def test_every_launch_gets_a_new_profile(self):
        self.run_launcher(); first = self.rootfile.read_text()
        self.run_launcher(); self.assertNotEqual(first, self.rootfile.read_text())

    def test_a_production_app_refuses_and_nothing_starts(self):
        result = self.run_launcher(OWNER_TEST='0')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('not an owner test build', result.stderr)
        self.assertEqual(self.logged(), [])
        self.assertFalse(self.rootfile.exists())

    def test_needs_the_app_beside_it(self):
        (self.zip / 'ModelPlan Community.app').rmdir()
        self.assertNotEqual(self.run_launcher().returncode, 0)
        self.assertEqual(self.logged(), [])

    def test_the_file_is_executable_and_the_owner_test_zip_alone_ships_it(self):
        self.assertTrue(LAUNCHER.stat().st_mode & stat.S_IXUSR)
        workflow = (ROOT / '.github/workflows/desktop.yml').read_text()
        stage = workflow.split('Zip the packaged native app', 1)[1].split('upload-artifact', 1)[0]
        branch = re.search(r'if \[ "\$\{\{ inputs\.owner_test.*?\n(.*?)\n\s*else\n(.*?)\n\s*fi\n', stage, re.S)
        self.assertIn('ModelPlan First Run.command', branch.group(1))
        self.assertNotIn('First Run', branch.group(2))
        # No packaging script, release script or other workflow copies it.
        for path in [ROOT / 'desktop/native/tools/package-neutral.sh', ROOT / 'desktop/native/tools/distribution/release.py']:
            self.assertNotIn('First Run', path.read_text(), path.name)


if __name__ == '__main__':
    unittest.main()
