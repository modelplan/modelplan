# SPDX-License-Identifier: MIT
"""Exercise the verifier with a forged builder workspace and helper environment."""
import hashlib
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[4]


class CandidateTrustTests(unittest.TestCase):
    def test_builder_cannot_make_wrong_helper_pass_fresh_guard(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            builder = root / 'builder/control'
            verifier = root / 'fresh/control'
            builder.mkdir(parents=True)
            verifier.mkdir(parents=True)
            (builder / 'check_app_architectures.py').write_text('raise SystemExit(0)\n')
            guard = verifier / 'check_app_architectures.py'
            shutil.copyfile(ROOT / 'desktop/native/tools/distribution/check_app_architectures.py', guard)
            app = root / 'fresh/candidate.app'
            (app / 'Contents/Helpers').mkdir(parents=True)
            (app / 'Contents/MacOS').mkdir()
            (app / 'Contents/Info.plist').write_bytes(plistlib.dumps({}))
            (app / 'Contents/MacOS/ModelPlanCommunity').write_bytes(b'synthetic app')
            (app / 'Contents/Helpers/modelplan').write_bytes(b'synthetic cli')
            forged = b'wrong credential helper'
            (app / 'Contents/Helpers/modelplan-credential-agent').write_bytes(forged)
            trusted = hashlib.sha256(b'approved helper').hexdigest()
            env = dict(os.environ, MODELPLAN_CREDENTIAL_AGENT_SHA256=hashlib.sha256(forged).hexdigest())
            result = subprocess.run([sys.executable, str(guard), '--app', str(app), '--main',
                                     str(app / 'Contents/MacOS/ModelPlanCommunity'),
                                     '--approved-helper-sha256', trusted], env=env, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('credential helper pin mismatch', result.stderr)
