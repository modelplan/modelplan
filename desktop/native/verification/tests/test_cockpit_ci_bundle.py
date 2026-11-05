# SPDX-License-Identifier: MIT
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[4]
WORKFLOW = ROOT / '.github/workflows/trusted-mac.yml'


class CockpitCIBundleTests(unittest.TestCase):
    def script(self):
        text = WORKFLOW.read_text()
        marker = '    - name: Build and verify the community cockpit for native GUI tests\n      run: |\n'
        self.assertEqual(text.count(marker), 1)
        block = text.split(marker, 1)[1].split('\n    - name:', 1)[0]
        self.assertLess(text.index(marker), text.index('    - name: App integration tests, GUI leg'))
        return '\n'.join(line[8:] for line in block.splitlines())

    def test_export_occurs_only_after_build_and_pin_check(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            for name in ('npm', 'python3'):
                executable = root / name
                executable.write_text('#!/bin/sh\nprintf "%s %s\\n" "$(basename "$0")" "$*" >> "$CALLS"\n'
                                      'if [ "$(basename "$0")" = python3 ] && [ "$FAIL_PIN" = 1 ]; then exit 1; fi\n')
                executable.chmod(0o755)
            calls, result = root / 'calls', root / 'env'
            env = {**os.environ, 'PATH': str(root) + os.pathsep + os.environ['PATH'],
                   'CALLS': str(calls), 'GITHUB_ENV': str(result), 'GITHUB_WORKSPACE': '/synthetic/workspace'}
            for fail in (True, False):
                calls.unlink(missing_ok=True)
                result.unlink(missing_ok=True)
                process = subprocess.run(['bash', '-e', '-c', self.script()], env={**env, 'FAIL_PIN': str(int(fail))})
                self.assertEqual(process.returncode == 0, not fail)
                self.assertEqual(calls.read_text().splitlines(), [
                    'npm ci --prefix desktop/cockpit --ignore-scripts',
                    'npm run build --prefix desktop/cockpit',
                    'python3 desktop/native/ModelPlanCockpitWeb/check-bundle-pins.py --edition community',
                ])
                if fail:
                    self.assertFalse(result.exists())
                else:
                    self.assertEqual(result.read_text(), 'MODELPLAN_COCKPIT_BUNDLE_DIR=/synthetic/workspace/desktop/cockpit/.tmp/community\n')


if __name__ == '__main__':
    unittest.main()
