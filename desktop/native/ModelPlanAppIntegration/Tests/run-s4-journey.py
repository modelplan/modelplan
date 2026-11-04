#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Run the XCTest-shared normal-entry journey on CLT without XCTest.

Requires a normal product build from the selected source head. Never launches
that product: links library objects into the non-windowed synthetic journey.
"""
import argparse
import pathlib
import subprocess
import tempfile
import sys

p = argparse.ArgumentParser()
p.add_argument("--build", type=pathlib.Path, required=True)
a = p.parse_args()
here = pathlib.Path(__file__).resolve().parent
root = here.parents[3]
build = a.build.resolve()
objects = [str(f) for f in build.glob("*.build/*.o")
           if f.parent.name not in {"ModelPlanCommunityApp.build"}
           and "Tests" not in f.parent.name]
if not objects or not (build / "Modules/ModelPlanAppIntegration.swiftmodule").exists():
    p.error("a normal AppIntegration product build is required")
with tempfile.TemporaryDirectory(prefix="m4-s4-journey-") as scratch:
    binary = pathlib.Path(scratch) / "journey"
    subprocess.run(["swiftc", "-parse-as-library", "-I", str(build / "Modules"),
                    str(here / "ModelPlanAppIntegrationTests/S4QuotaJourney.swift"),
                    str(here / "S4JourneyMain.swift"), *objects, "-o", str(binary)], check=True)
    sys.exit(subprocess.run([str(binary), str(root / "schema/app-cli/captures/WireRowsSnapshot.json")]).returncode)
