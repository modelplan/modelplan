<!-- SPDX-License-Identifier: MIT -->
# U2/U3 engine Drive

One Python 3.12 standard-library command runs the ordinary `modelplan` executable
through its production CLI and `app-server` entry points. No Go overlay, test
constructor, credential, account, Keychain or native UI is involved. The fixed
Copilot stdio runtime is synthetic; it is a positive/blocked reader control, not
live vendor proof. This is a non-GUI Drive scenario for the native verification
skill, independent of its GUI guardian/observer implementation.

**Profile status: pending coordinator review.** `profile.json` describes tool
presence, directory layout, consent v1 and file kinds, with no real values. The
omitted/null/reported optional-model structures derive from the sanitized
zero-row contract examples. The type-only records are retained shape inputs,
not a claim to execute the Swift decoder or history query. U14's existing shape
builder materializes fixed values. Each scenario adds only the declared fake
runtime, parseable empty connections v1, and the synthetic mutations below.
An approval requires a reviewed new profile version, `approved-shape-export`,
an approval reference, and updated known gaps. The supplied pending profile
cannot qualify for L2. No owner HOME is read or copied.

## Prepare released subjects

The coordinator names the next release containing the engine implementation.
Do not substitute the current source build for that release. Download each
ordinary archive and its published `checksums.txt` once:

```sh
mkdir -p .tmp/engine-drive
python3 tools/u14/engine_drive/release.py \
  --tag vX.Y.Z --commit <full-release-tag-commit> \
  --output .tmp/engine-drive/subject
python3 tools/u14/engine_drive/release.py \
  --tag v0.5.46 --commit 3602d410b17f9376278413633abeec6e3572ee56 \
  --output .tmp/engine-drive/old46
python3 tools/u14/engine_drive/release.py \
  --tag v0.5.47 --commit f830589cc613daf16267c692b735c3a240ec4d2e \
  --output .tmp/engine-drive/old47
```

The helper chooses the host Linux/macOS architecture, uses only the public
release URLs, resolves the public tag to verify the commit, checks archive SHA-256 against
published checksums and extracts
one regular executable in memory. It retains the archive/checksums and records
release tag, commit, archive hash and executable hash. The runner independently
rechecks them and requires `--binary` to match those exact released bytes.
Keep prepared artifacts immutable until execution is complete. The release
commit is the full commit resolved from its public tag, not the harness head.
No network download occurs during a Drive run.

## Single entry command for M2 / M0

Supply a reviewed profile and a run context JSON such as
`{"dedicatedTestMac":true,"approvalRef":"<coordinator run approval>"}`.
The context is operator attestation, not automatic device discovery. It contains
no host identity. Only the coordinator can attest the dedicated test Mac.

```sh
python3 tools/u14/engine_drive/run.py \
  --binary .tmp/engine-drive/subject/modelplan \
  --release .tmp/engine-drive/subject/release.json \
  --old-release .tmp/engine-drive/old46/release.json \
  --old-release .tmp/engine-drive/old47/release.json \
  --shape <reviewed-profile.json> --context <approved-run-context.json> \
  --level L2 --run-id <skill-run> --attempt <attempt> --epoch <epoch> \
  --stop-file <caller-guardian-stop-marker> --deadline <fixed-unix-expiry> \
  --output <new-evidence-directory>
```

The caller supplies the same run/attempt/epoch, fixed expiry and stop marker
used by its existing guardian. The engine package does not issue/revoke GUI
leases or create another guardian. It launches no window and delivers no input.
It checks stop/deadline before scenarios and while waiting, caps total work at
1,200 seconds (default 900), and reserves 15 seconds for cleanup. A scenario has
a 60-second default bound. A stop leaves dependent/unstarted cases `not-run`;
a timed-out scenario is `timeout`. Parent and worker use owned process groups;
cleanup terminates only that run's descendants and removes only `.work` under
the exclusively created output directory. Evidence is retained separately.
Use a run directory outside disposable skill scratch if evidence must survive
outer Cleanup. The caller still owns its overall lease and final Cleanup step.

`manifest.json` is the Drive result consumed by Evidence: schema version,
run/attempt/epoch, harness head, engine release commit/tag/hash, old subjects,
profile hash/approval, platform attribution, stable scenario IDs and per-case
`pass/fail/not-run/unsupported/timeout`, duration and hashed relative evidence
references. `cleanup.json` reports `cleaned/failed` separately. There is no GUI
arrival, AX, screenshot or native-surface claim. RPC evidence contains only
allowlisted method/id/error-code/session/epoch/generation/sequence/frame-hash records; raw diagnostics, paths,
environment and raw home contents are never exported. Every executed scenario
retains the U14 baseline hash/file-kind report. Evidence is written atomically
before scratch removal. Cleanup failures preserve the original outcomes and
make the command exit nonzero. Exit zero requires every case to pass and cleanup
to complete; neither process exit alone nor a merge earns proof.

Linux and GitHub-hosted macOS always remain L1. L2 requires Darwin outside
GitHub Actions, an explicit approved dedicated-Mac context, approved shape,
checksum-verified released subject and both old released writers. Missing L2
prerequisites produce `unsupported` outcomes without running a source subject.
The package never earns L3. This evidence covers these declared engine cases,
not whole-ticket closure, native rendering, live providers or final App signing.

## Scenario map

| ID | Driven / observed acceptance |
| --- | --- |
| U2-migration | Schema 1 to 2, byte-identical backup and repeat-load idempotence |
| U2-revoke-in-flight | Real blocked read, independent deny, cleanup_pending, released read cannot publish |
| U2-reset-old-allow | Reset reuses generation 1 with a new epoch, rejects historical allow and late publication |
| U2-two-writers | Concurrent independent CLI writers: one commit, one stale generation |
| U2-completed-regrant / U2-completed-reset | Positive actual capture, no resurrection after tighten/reset/regrant, shared budget retained |
| U2-retired-deny / U2-retired-forget | Retired reader's cache removed with readers off, no runtime started |
| U2-old-writer-v0.5.46 / U2-old-writer-v0.5.47 | Real old release's grant/connect/refresh/quota/disconnect cannot change schema-2 consent or readings, or call providers |
| U3-protocol | Real handshake/health/session/envelope, stable unique rows, diagnostics, misplaced token and unknown credential rejection, clean shutdown |
| U3-major-mismatch / U3-eof | Major mismatch terminal rejection; EOF ends owned engine |
| U3-shared-revoke-receipt | Positive runtime row, independent CLI revoke, changed notification/current rejection context, cleared rows, durable Forget receipt replay across restart |
| U3-backpressure-receipt | Stop stdout reads, flood ordinary diagnostics, bounded engine exit; independent revoke persists and receipt replays after restart |

The pressure case uses ordinary diagnostics instead of a test history provider.
It does not claim the separate fixture-only two-held-query/cursor tests or
Swift decoding. Those remain their existing L1 coverage, not new L2 claims.
There is no shared U14 registry/runner edit; these IDs belong to this standalone
Drive manifest. RELPIPE retains the shared harness and its part-B schema.

## L1 development and CI

```sh
(cd cli && go build -trimpath -o ../.tmp/engine-drive/modelplan ./cmd/modelplan)
python3 tools/u14/engine_drive/run.py \
  --binary .tmp/engine-drive/modelplan --source-sha "$(git rev-parse HEAD)" \
  --old-release .tmp/engine-drive/old46/release.json \
  --old-release .tmp/engine-drive/old47/release.json \
  --level L1 --output .tmp/engine-drive/evidence
python3 -m unittest discover -s tools/u14/engine_drive -p 'test_*.py' -v
```

Source builds must name their full commit and are explicitly `source-build` in
evidence. Missing old releases are `unsupported`, never pass. The hosted Linux
and macOS workflow fetches both old releases, builds the ordinary current CLI,
runs all cases as L1 and uploads evidence even on failure. No private runner,
credential, approved profile or dedicated Mac is required for these checks.
