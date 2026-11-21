# SPDX-License-Identifier: MIT
"""Guard (macrevb-1096-9, D324): the resource plugin is opt-in at the normal entry so test and fixture apps never sample
this Mac; the installed community app is the one caller that opts in. Without this, dropping the argument would silently
ship an app with no resource plugin while every test still passes."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
INTEGRATION = ROOT / "desktop" / "native" / "ModelPlanAppIntegration" / "Sources"


class ResourcePluginOptInTests(unittest.TestCase):
    def test_the_installed_app_opts_in(self):
        app = (INTEGRATION / "ModelPlanCommunityApp" / "CommunityApp.swift").read_text(encoding="utf-8")
        call = re.search(r"EngineRowsEntry\.make\((.*?)\)\s*\n\s*NSApplication\.shared\.delegate", app, re.S)
        self.assertIsNotNone(call, "CommunityApp makes the app through EngineRowsEntry.make")
        self.assertRegex(call.group(1), r"installsResourcePlugin:\s*true")

    def test_the_default_leaves_it_out(self):
        for name in ("EngineRowsEntry.swift", "CommunityCockpitApplicationFactory.swift"):
            text = (INTEGRATION / "ModelPlanAppIntegration" / name).read_text(encoding="utf-8")
            self.assertIn("installsResourcePlugin: Bool = false", text, name)


if __name__ == "__main__":
    unittest.main()
