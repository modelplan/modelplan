<!-- SPDX-License-Identifier: MIT -->
# U14 part E: hosted macOS harness

This draft adds the native harness entry point in `tools/u14` and a standard
hosted macOS workflow. It consumes the existing part-A synthetic-home builder
and part-B evidence generator. The shared engine runner, scenario registry,
schemas and native application sources remain owned by their existing lanes.

The planned run builds the ordinary Community app bundle and a same-source real
app-server helper, launches only with a synthetic home and runtime network
denial, waits for the owned app's windows through Accessibility, captures an AX
tree and a window-only offscreen image, and hashes the evidence into a part-B
bundle. Missing hosted permissions are recorded as unsupported, never bypassed.

A01–A19 remain explicitly unsupported until their U6/U8/U10 scenario drivers are
implemented. A successful harness check is neither a feature scenario pass nor
dedicated-device, official-package, signing-identity or owner-Mac acceptance.
No native source is edited by this contribution.
