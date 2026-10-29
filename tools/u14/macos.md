<!-- SPDX-License-Identifier: MIT -->
# U14 part E: hosted macOS harness

`macos_runner.py` consumes the existing part-A synthetic-home builder and part-B
candidate generator. The separate `u14-macos.yml` workflow runs on standard
`macos-latest` hosts, by dispatch or on ready pull requests that touch `tools/u14`
or `desktop/native`. Draft PRs skip the job. No private files, signing credentials,
release trust changes or dedicated runners are required.

The runner requires a clean checkout. All generated files belong under its
ignored `.tmp/` directory. On Linux or an unadmitted local Mac, it emits an
unsupported part-B bundle without building or launching an app:

```sh
mkdir -p .tmp
python3 tools/u14/macos_runner.py --output "$PWD/.tmp/u14-macos" \
  --case coexistence --scenarios all
```

A hosted run builds both Darwin CLI architectures from the recorded source SHA,
then invokes the unchanged production `package-neutral.sh --unverified` to build
the ordinary release Community app. The bundled helper hash must match the
package's pin. Its actual `app-server --offline` process must complete the 1.0
handshake and report the build version. This is a real bundled engine, with no
fixture backend or replacement app. The package has an ad hoc CI identity;
release identity and consent grants remain unsupported.

The current native entry still uses the legacy desktop client. Until U6/U8 land,
the app and the separately exercised bundled app-server are independent children.
`macos-native-engine-binding` explicitly records unsupported. Neither the
handshake nor an image claims native protocol integration.

## Runtime and evidence

Every run creates the fixed hand-built synthetic shape home from part A, verifies
its initial file hashes, and launches with `HOME` and `CFFIXED_USER_HOME` redirected
to it. No host credential environment is inherited. Readers, native account reads
and history are disabled; a runtime sandbox denies network access. Compiler logs
are bounded; app stdout/stderr and host logs are not exported.

The Swift probe verifies the launched app's PID and bundle path before querying
its windows through the Accessibility API. It waits at most 30 seconds, then
walks only AX elements belonging to that PID, with node/depth/message deadlines.
It records truncation rather than claiming a complete tree when a bound is hit.
The offscreen PNG uses a ScreenCaptureKit desktop-independent window filter for
that same PID, including occluded windows. There is no whole-display fallback.
Missing Accessibility or screen-capture permission produces unsupported without
permission prompts or TCC changes. The probe uses Apple's
[AX trust check](https://developer.apple.com/documentation/applicationservices/1459186-axisprocesstrustedwithoptions),
[AX attribute API](https://developer.apple.com/documentation/applicationservices/1462085-axuielementcopyattributevalue),
[window filter](https://developer.apple.com/documentation/screencapturekit/sccontentfilter/init%28desktopindependentwindow%3A%29)
and [screenshot API](https://developer.apple.com/documentation/screencapturekit/scscreenshotmanager/captureimage%28contentfilter%3Aconfiguration%3Acompletionhandler%3A%29).

Owned process groups are stopped on failure or timeout. The GUI phase has a
20-minute watchdog; the hosted job has a 45-minute limit. Only the part-B bundle
is uploaded, for 14 days; the job deletes its generated scratch. The manifest
binds the exact source SHA, app tree hash, bundled helper hash/version, part-A
baseline, observed display (when available), scenario catalog and evidence blobs.
Infrastructure outcomes and feature outcomes are separate checks.

## Adding feature scenarios

`SCENARIO_DRIVERS` is deliberately empty. All A01–A19 are explicitly unsupported;
selecting an ID cannot turn infrastructure evidence into a feature pass. The
shared registry, schemas, engine runners and native source are unchanged.

After a feature's production consumer lands, its DRI registers a callable under
its existing A01–A19 ID. Only selected registered callbacks execute. A callback
receives `NativeContext` with the owned app process, bundled helper, synthetic
home, run directory and shared deadline. `context.capture()` returns a fresh
PID-checked AX/image receipt and evidence checks using the same probe. Return
`{"outcome": "pass|fail|not-run|unsupported|timeout", "evidence": [absolute_path]}`;
executed outcomes require evidence files inside this run. Unregistered or
unselected IDs remain unsupported. Callback evidence is hashed by part B.

`context.capabilities` starts with the proven bundled `app-server` capability;
AX success adds `native-ui`/`accessibility`, and a captured image adds
`offscreen-capture`. Feature callbacks may add other capabilities only after
proving their real production/input path. Part B still applies each scenario's
required capabilities and baseline structures. No CLI option accepts claimed
feature outcomes or arbitrary capability lists.

Hosted evidence is not dedicated-device L2 acceptance, an official package,
owner-approved visuals, migration proof, or owner-Mac acceptance. U6/U8/U10 own
their scenario assertions and failures; RELPIPE owns shared U14 integration.
