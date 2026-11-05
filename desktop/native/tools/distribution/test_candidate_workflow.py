# SPDX-License-Identifier: MIT
"""Pin the isolation boundary between candidate code and receipt issuance."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[4]


class CandidateWorkflowTests(unittest.TestCase):
    def test_untrusted_builder_cannot_supply_verifiers_or_pin(self):
        text = (ROOT / '.github/workflows/v1-test-build.yml').read_text()
        build = text.split('\n  build:\n', 1)[1].split('\n  validate:\n', 1)[0]
        validation = text.split('\n  validate:\n', 1)[1].split('\n  draft-prerelease:\n', 1)[0]
        self.assertIn('runs-on: macos-latest', build)
        self.assertIn('runs-on: macos-latest', validation)
        self.assertIn('needs: build', validation)
        self.assertNotIn('subject/', validation)
        self.assertNotIn('MODELPLAN_CREDENTIAL_AGENT_SHA256', validation)
        self.assertIn('control/desktop/native/credential-agent-artifact-pin.json', validation)
        self.assertIn('control/desktop/native/tools/distribution/check_app_architectures.py', validation)
        self.assertIn('control/desktop/native/ModelPlanCockpitWeb/check-bundle-pins.py --repo control', validation)
        self.assertIn('cd control/cli && go run ./internal/releaseguard/cmd', validation)
        self.assertIn("github.ref == 'refs/heads/main'", validation)
        self.assertLess(validation.index('candidate_archive.py'), validation.index('ditto -x -k'))
        self.assertLess(validation.index('check_app_architectures.py'), validation.index('candidate_manifest.py create'))
        self.assertIn('candidate_source.py "$SOURCE_SHA"', validation)
