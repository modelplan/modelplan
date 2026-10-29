<!-- SPDX-License-Identifier: MIT -->
# Transport fuzz qualification

The Go targets call the production app-server scanner, request decoder,
initialize/session rejection and envelope/floor helpers, and history cursor
codec. Seeds are read from the producer-owned Go encodings in
`schema/app-cli/captures/`, including the production rows capture. No second wire
fixture schema, live credentials, provider reads or native app is involved.

Run the short CI profile from the repository root:

```sh
bash scripts/test-transport-fuzz.sh 30s
```

Each of the four native Go fuzz targets gets its own thirty-second campaign,
with two workers. A longer local profile uses `3m` per target. Scratch, Go build
and fuzz caches, source/OS/compiler metadata and bounded logs live under `.tmp/`.
The workflow uses a standard free Linux runner and runs Linux Swift explicitly;
an unavailable Swift compiler fails the job rather than silently skipping it.

| Target | Properties |
| --- | --- |
| `FuzzReadFrame` | Fragmented reads, varied buffers, multiple lines, malformed UTF-8, partial EOF, LF-inclusive 8 MiB boundaries and bounded frame backing storage. Compact seeds expand at the cap instead of storing multi-MiB corpus files. A separate LF/UTF-8 reference checks accepted bytes. |
| `FuzzDecodeRequest` | Malformed/duplicate/trailing JSON, exact integral/string IDs, round trips and the actual strict initialize/grant/history/credential/cancel parameter decoders. Scanner UTF-8 validation remains a separate layer. |
| `FuzzEnvelopeSession` | A preinitialized in-process server rejects invalid/repeated/foreign handshakes without changing the active session/floor. Error IDs/context stay correlated. Envelope serialization preserves UInt64 generations and the exact context; the production current-stamp fence refuses foreign stamps. No backend or UI acceptance is claimed. |
| `FuzzHistoryCursor` | Malformed token parsing, bounded positions/AAD, byte-exact seal/open, fresh-key rejection, tamper rejection and session/epoch/generation/scope/account/tool/kind fences. Binding generation uses the real captures; caller scope ordering must remain unchanged. |

`MutationFuzzTests` runs reproducible seeded mutation tests through the actual
Swift `LineFramer`, `IncomingFrame` and generated `WireDecoder`. It varies chunk
boundaries (including nonzero Data slice indices), corrupts/truncates/splices
bytes, changes structured headers and injects nested JSON. Accepted streams must
match an independent LF/UTF-8 oracle; rejected streams may deliver only unchanged
valid prefixes. Accepted decoder values must retain exact IDs, context and
payload after encoding/decoding. Required-header and token-placement mutations
have explicit negative assertions. This is a deterministic mutation campaign,
not a claim of coverage-guided Swift instrumentation or session/UI qualification.

```sh
MODELPLAN_SWIFT_FUZZ_SECONDS=180 swift test \
  --package-path clients/swift/ModelPlanEngineClient \
  --scratch-path .tmp/swift-build --jobs 2 --filter MutationFuzzTests
```

The default Swift test runs at least 512 mutations. CI runs for thirty seconds;
local campaigns can run longer. `MODELPLAN_SWIFT_FUZZ_SEED` selects a decimal
UInt64 seed; the default is fixed. Checkpoints record the seed/case/RNG state,
and invariant failures save the synthetic input in
`.tmp/transport-fuzz/swift-crasher.bin`. Fatal crashes can be replayed using the
same source/captures and seed; checkpoints bound the last batch. No user
information or environment values enter the corpus or logs.

The campaign found two seven-byte malformed dictionary keys that trap Linux
Swift 6.0.3 Foundation inside JSONDecoder: invalid UTF-8 and a literal tab. The
committed binary seeds replay both through WireDecoder and IncomingFrame. The
production fix validates UTF-8 and JSON syntax in the Go-owned Swift runtime
template before Foundation's dictionary path and returns the existing invalidFrame
error. The syntax-validation tree is discarded; typed decoding still consumes
the original bytes, preserving exact identifiers. Generated.swift is regenerated,
never hand-edited. The framer already rejected invalid UTF-8, but the literal-tab
seed reaches the decoder as a valid UTF-8 line. Valid messages retain their
existing decoding and token/identity checks.

Go automatically minimizes failures into `testdata/fuzz/<target>/`. Reproduce a
failure with `go test <package> -run '<target>/<hash>'`, retain its native corpus
file in the PR, and verify it fails before any production fix and passes after.
For a Swift failure, minimize and commit the synthetic input as a regression
seed exercised by the test suite. A campaign finding no failure produces no
invented crasher. Ordinary `go test` replays committed Go seeds without starting
a timed campaign. CI artifacts preserve logs, manifests and any failure input.

Keep native process supervision, real-binary integration, OS credential behavior,
UI/signing and final-package acceptance as separate evidence. A finite fuzz
campaign proves only the stated source, corpus, oracles and duration, not the
absence of all bugs. Remove this run's completed `.tmp/` output after retaining
its evidence; never delete other lanes' caches or an active compiler.
