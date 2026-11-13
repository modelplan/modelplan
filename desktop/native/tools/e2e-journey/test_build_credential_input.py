# SPDX-License-Identifier: MIT
"""Journey packaging consumes a reviewed artifact before compiling any CLI/App."""
import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('journey_build_credential_test', Path(__file__).with_name('build.py'))
build = importlib.util.module_from_spec(spec)
spec.loader.exec_module(build)


class JourneyCredentialInputTests(unittest.TestCase):
    def test_no_approved_artifact_stops_before_git_compiler_or_packager(self):
        with tempfile.TemporaryDirectory() as temporary, \
             patch.object(build.credential_artifact, 'acquire', side_effect=ValueError('approval missing')), \
             patch.object(build.subprocess, 'check_output') as git, \
             patch.object(build.subprocess, 'run') as command:
            with self.assertRaisesRegex(ValueError, 'approval missing'):
                build.build(Path(temporary) / 'output')
            git.assert_not_called()
            command.assert_not_called()

    def test_verified_binding_reaches_packager_without_download_auth(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            binding = {'environment': {'MODELPLAN_CREDENTIAL_AGENT_ARTIFACT': str(root / 'verified'),
                                       'MODELPLAN_CREDENTIAL_AGENT_SHA256': 'b' * 64},
                       'approval': {'runID': '12345', 'artifactName': 'synthetic-approved', 'sha256': 'b' * 64}}
            calls = []
            def command(args, **kwargs):
                calls.append((args, kwargs))
                if args[:2] == ['go', 'build']:
                    output = Path(args[args.index('-o') + 1]); output.parent.mkdir(parents=True, exist_ok=True)
                    output.write_bytes(b'synthetic CLI output')
                return subprocess.CompletedProcess(args, 0)
            with patch.object(build.credential_artifact, 'acquire', return_value=binding), \
                 patch.object(build.subprocess, 'check_output', return_value='a' * 40), \
                 patch.object(build.subprocess, 'run', side_effect=command), \
                 patch.dict(os.environ, {'GH_TOKEN': 'synthetic-download-auth', 'GITHUB_TOKEN': 'synthetic-download-auth'}):
                build.build(root / 'output')
            package = next(kwargs for args, kwargs in calls if args[0] == 'bash')
            self.assertEqual(package['env']['MODELPLAN_CREDENTIAL_AGENT_SHA256'], 'b' * 64)
            self.assertEqual(package['env']['MODELPLAN_CREDENTIAL_AGENT_ARTIFACT'], str(root / 'verified'))
            for _, kwargs in calls:
                self.assertNotIn('GH_TOKEN', kwargs['env'])
                self.assertNotIn('GITHUB_TOKEN', kwargs['env'])
            self.assertEqual(sum(args[:2] == ['go', 'build'] for args, _ in calls), 3)
            self.assertFalse(any('build_fixed_helper.py' in str(args) for args, _ in calls))


if __name__ == '__main__':
    unittest.main()
