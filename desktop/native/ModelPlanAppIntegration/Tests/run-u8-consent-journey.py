#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Run the XCTest-shared synthetic consent journey without XCTest or windows."""
import argparse
import pathlib
import subprocess
import sys
import tempfile
p = argparse.ArgumentParser()
p.add_argument("--build", type=pathlib.Path, required=True)
a = p.parse_args()
here = pathlib.Path(__file__).resolve().parent
root = here.parents[3]
build = a.build.resolve()
objects = [str(f) for f in build.glob("*.build/*.o") if f.parent.name != "ModelPlanCommunityApp.build" and "Tests" not in f.parent.name]
if not objects or not (build / "Modules/ModelPlanAppIntegration.swiftmodule").exists():
    p.error("normal AppIntegration product build required")
with tempfile.TemporaryDirectory(prefix="u8-consent-journey-") as scratch:
    binary = pathlib.Path(scratch) / "journey"
    subprocess.run(["swiftc", "-parse-as-library", "-I", str(build / "Modules"), str(here / "ModelPlanAppIntegrationTests/U8ConsentJourney.swift"), str(here / "U8ConsentJourneyMain.swift"), *objects, "-o", str(binary)], check=True)
    sys.exit(subprocess.run([str(binary), str(root / "schema/app-cli/captures/WireConsentFacts.json")]).returncode)
