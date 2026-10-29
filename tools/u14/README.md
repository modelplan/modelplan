# U14 synthetic home and candidate evidence

The baseline/evidence tools and the real-binary engine runner share one scenario
registry. The runner drives `modelplan app-server` through anonymous pipes on
synthetic homes, with a constructor-only overlay for recording providers and
fault injection. Results are scoped to transport/engine fixture proof. U6, U8
and U10 consume the later native integration; feature failures stay with their
feature owner.

For the standalone baseline/evidence tools, Python 3.12+, Git and the standard
library are sufficient. No private checkout,
network access, product login, Keychain access or dependency install is required.

```sh
python3 -m unittest discover -s tools/u14/tests -v
```

The dedicated hosted workflow runs `verify.py` on standard Ubuntu runners. It
runs this suite, the source-policy gate, and both CLIs across all ten preference
cases, then uploads the synthetic evidence (also on failure). To run the same
profile locally, choose a new temporary destination outside the source checkout:

```sh
python3 tools/u14/verify.py --output /tmp/u14-evidence-unique-run
```

The bundle records these L1 checks separately from real product scenarios. Native UI, real input, OS permissions and official
visual confirmation remain separate checks.

## Shape baseline

```sh
u14_run_dir=$(mktemp -d)
python3 tools/u14/shape_home.py \
  --shape tools/u14/examples/synthetic-shape.json \
  --case coexistence --output "$u14_run_dir/home"
```

The destination must be a new directory beneath an existing parent with no
symlink components. Existing files are never reused or overwritten. Only this
new home is written; there is no discovery of real home files. Set `HOME` only
on the future test child, never globally. Delete the temporary run directory
when finished.

`schemas/shape.schema.json` is the input contract. Files have a home-relative
path and an `empty`, `corrupt`, or `json` state. A JSON shape contains only
object field names, array structure and scalar **types**. The builder generates
fixed synthetic scalar values. Do not add owner values, tokens, account names,
absolute paths, project names or arbitrary contents. Sanitize dynamic object
keys and file names before supplying a shape. Tool names produce executable
presence stubs that exit 69: they never impersonate working vendor runtimes.
Vendor-specific history/config parsing needs separate synthetic reader fixtures.

The committed example is hand-built and explicitly lists its fidelity gaps.
An approved export uses `fidelity: approved-shape-export`, an `approvalRef`, and
a new `baselineVersion`. This reference records external approval; the tool
cannot grant approval. Real sanitized owner exports stay outside the public
repository and are never committed or automatically uploaded. Update an approved
baseline only during an approved diagnostics/L3 run when a structure changes or
a gap is found. A newer timestamp is not stronger evidence.

Every build writes `.u14-baseline.json` with its version, normalized input hash,
covered structures, known gaps, file hashes, capabilities and migration oracle.
All content is deterministic for a shape and preference case. Files use mode
0600, presence stubs 0700, and newly created directories 0700.

### Preference inputs and expected migration

All three source paths are relative to `Library/Application Support/`:

| Group | Source | Synthetic discriminator |
|---|---|---|
| Official Settings | `ModelPlan/Beta07/settings-v1.json` | Night theme, left edge, fraction 0.25 |
| Community Settings | `ModelPlan/Native/settings-v1.json` | Day theme, right edge, fraction 0.75 |
| Independent Core | `ModelPlan/Native/community-v1.json` | `en_US`, synthetic favourite and field picker |

Settings inputs include appearance, placement, order/hidden/unmatched row ids,
per-subscription settings, shortcuts, notifications, onboarding and help hints.
Both Settings inputs carry old `readerConsent` UI choices; they never grant
engine consent. Consent is generated independently at
`.config/modelplan/consent.json` with synthetic schema-1 allow/deny/unset records
and unset Keychain permission, or as a missing/corrupt store. Schema-2 consent
remains a known gap until U2 supplies its persisted store contract.

`--case` selects an input and expected source-group oracle:

| Case | Official Settings | Community Settings | Core |
|---|---|---|---|
| `coexistence` | Beta07 | Native | Core |
| `corrupt-beta07`, `missing-beta07` | Native | Native | Core |
| `corrupt-native` | Beta07 | Beta07 | Core |
| `corrupt-core` | Beta07 | Native | Defaults |
| `all-corrupt`, `fresh` | Defaults | Defaults | Defaults |
| `new-exists` | New file | New file | New file |
| `corrupt-new` | Defaults, report error | Defaults, report error | Defaults, report error |
| `invalid-progress` | Beta07, recover invalid onboarding | Native | Core |

The retained Settings inputs use current completed progress (`setup65`, signature
`7:setup65:0`). `invalid-progress` deliberately replaces only the Beta07 progress
with an unknown step, leaving group-source selection intact. The U5 production
consumer must assert completed-progress retention and invalid-progress recovery
when that migration seam is wired.

Migration is by **whole group**, never a field-by-field merge of the two Settings
files. Core is independent. Sources remain unchanged; unmatched row ids remain
stored. An existing new file suppresses migration. A corrupt new file stays
untouched and reports its error; a saved missing display UUID stays stored even
when actual placement falls back. The builder emits inputs and an oracle only.
The real U5 migration and native placement tests must assert those behaviors.
The new-file envelope is provisional and declared as a fidelity gap until U5 pins
it. Do not count it as production decoder evidence.

## Candidate manifest and evidence bundle

Copy `examples/candidate-input.json` into the temporary run directory and supply
explicit artifact/evidence paths. Source paths identify **all involved repos**;
Git fills their exact SHAs. Dirty worktrees, duplicate repos and unknown scenario
ids are rejected. Use a clean committed subject for evidence generation.

```sh
python3 tools/u14/candidate.py \
  --input "$u14_run_dir/candidate-input.json" \
  --baseline "$u14_run_dir/home/.u14-baseline.json" \
  --output "$u14_run_dir/evidence"
```

The input is validated against `schemas/candidate-input.schema.json`; the output
against `schemas/candidate-manifest.schema.json`. `contracts.py` implements only
the JSON Schema subset used here and rejects unsupported keywords. The schemas
also work with an independent draft-2020-12 validator.

The new evidence directory contains:

- `manifest.json` and `manifest.sha256`: source SHAs, build type/configuration,
  App and helper hashes/version, official manifest and visual-baseline hashes,
  publication revision, OS/display, baseline identity/gaps, profile, intended
  proof level and every scenario outcome.
- `blobs/<sha256>`: explicit, sanitized evidence files copied by content hash.
- `scenarios.json` and the output schema, with their hashes bound in the manifest.

App inputs may be a single file (for example the exact candidate archive) or an
App directory. Directory hash v1 is SHA-256 of canonical, sorted, indented JSON
records plus a final newline, as produced by `contracts.encoded`. Each record
binds a POSIX relative path, kind, file SHA-256 and permission mode (or a relative
internal symlink target). Directory modes are included; mtimes and ownership are
excluded. External/broken symlinks and special files are refused. Use the same
algorithm to verify the tree; `tree` is not the SHA of an archive. The generator
reads artifacts without running them or rebuilding the package. The helper
path must identify the actual reviewed bundled helper. Helper version is supplied
by the build step, not inferred by executing an untrusted binary.

Display conditions are explicit: `unsupported`, or width/height/scale/theme/locale.
OS facts are read from the current host, without hostname or user identity. The
publication revision is supplied by the build, not looked up on the network.
The caller provides a complete list of repositories and truthful measured
capabilities; this tool cannot discover omitted repos or prove a reported pass.
`intendedLevel` is a requested level, not an earned aggregate verdict.

Outcomes are `pass`, `fail`, `not-run`, `unsupported`, or `timeout`. A missing
capability or required baseline structure always produces `unsupported`, even
if an input claims `pass`. Omitted executable scenarios become `not-run`. A
reported pass/fail/timeout requires an evidence file. Optional `checks` bind
named L1 checks and their evidence separately from product scenarios. Artifact capabilities come
from actual hashed inputs; callers cannot claim a package or visual baseline
with no artifact. This stage never marks the real app-server/UI scenarios passed
on the strength of builder unit tests. Evidence paths do not appear in the
manifest; only bundle-relative hashes do. No logs, screenshots or diagnostics
are collected implicitly. Supply only reviewed synthetic evidence for public CI.

Output directories cannot be reused. Treat completed bundles as immutable and
record `manifest.sha256` in review. The same candidate bytes proceed through L2,
smoke, review and L3; do not rebuild an allegedly equivalent package. Baseline
metadata states gaps but cannot prove that the app consumed the home. The future
runner must verify the baseline file hashes before driving the real binary.

## Scenario ownership and migration

`scenarios.json` maps the intents of draft PR #300 onto Appendix A A01–A19.
It retains the old actual-panel, card guidance, first-read, age and normal-cadence
refresh assertions. Its old respin gate is superseded. `U2a-admission` adds zero
unapproved POST calls, terminal MiniMax 401/403 and retained local history.
`U3-backpressure` adds stopped-output flow control and revoke-receipt replay.
The registry records feature units, required capabilities and baseline structures.

The registry is a plan, not execution evidence; run bundles record what actually
executed. The current engine runner consumes the pinned U3 runtime. Headless engine replay, Community
native UI, official package, real input and owner L3 have different capabilities;
record each profile's actual outcomes separately. U14 remains open until U6, U8
and U10 consume the runner. A14's real-account check spans two reviewed candidates;
A19 belongs to U13. Destructive first-run/revoke cases run only on synthetic
profiles, never by resetting owner state.

## Real-binary engine runner

The engine stage requires Go 1.24+, Python 3.12+ and Git. The standalone baseline
and candidate tools still require only Python and Git. A new run must start from
a clean committed checkout and write outside it:

```sh
python3 tools/u14/run.py --output /tmp/u14-engine-unique-run
python3 tools/u14/run.py --output /tmp/u14-pressure-unique-run \
  --scenarios U3-backpressure U14-zero-rows-omitted
```

The default engine IDs are `U14-protocol-smoke`, `U3-backpressure`,
`U14-zero-rows-{omitted,null,reported,corrupt}`, `U14-empty-states` and
`U2a-admission`. `--scenarios` selects registry IDs; unselected available engine
scenarios remain `not-run`, and UI/device capabilities remain `unsupported`.
The ordinary fail-closed binary is always exercised as a separate check.

The runner builds two exact CLI binaries. The ordinary build has no fixture
imports. A Go build overlay replaces exactly the `appserver.New` constructor
argument and supplies a virtual factory file. It links only synthetic backend,
recording-provider and fault-injection tooling. Production `main.run`,
`appServerCmd`, `Server.Serve`, framing, queues and timeout constants are unchanged.
No runtime environment switch, test flag or endpoint override is added to an
ordinary build. The builder rejects a changed constructor rather than silently
substituting a fixture for a new production backend.

The child environment has only synthetic HOME/PATH/TMPDIR and locale; no API keys,
real HOME, product login or Keychain is inherited. Stdout uses bounded frame and
request waits; stderr is drained concurrently and only its byte count/digest is
retained by the driver. Cleanup closes and reaps only the run's own child. Shape
file hashes are checked before and after scenarios.

The recording transport never resolves a host or opens a socket. It admits only
one fixed synthetic history GET and refuses all other methods, hosts, paths and
parameters. Provider history with an absent/null/reported model is decoded into
the actual Go wire DTO; a malformed model produces `history_unavailable`.
Each case observes the same real app-server row projection before and after.
These are newly constructed synthetic derivatives of the historical optional-model
failure; no handoff file, owner value, legacy compatibility decoder or private
path is included. Separate inputs exercise engine `readers_off`, `pending`,
`no_consent` and `empty`. The app's all-hidden state waits for UI integration.

Backpressure stops draining the actual stdout pipe after a large frame starts.
Two recording-provider queries complete; a revoke commits and the backend health
change is read while data remains blocked. The process exits at the production
10-second write timeout. A fresh process/session on the same synthetic home
replays the fixture's stored receipt, preserving its committed epoch/generation,
and exposes no restored values. The test receipt file is a fixture-only store,
not U2 persistence, locking, migration, budget or admission proof.

Every accepted run writes `bundle/manifest.json`, its digest, hash-addressed
scenario/check evidence and `summary.json`, including on scenario failure or
timeout. Invalid inputs/dirty sources are rejected before a run starts. The
manifest identifies the source, exact fixture helper hash/version and shape
baseline. The `runner-build` check binds both exact binary hashes, schema-checker
hash, original/fixture constructor hashes and overlay hashes. `overlaySha256`
binds a normalized relative-path plan; `goOverlaySha256` additionally identifies
the actual temporary Go overlay mapping without exporting local paths.
Temporary build files and homes are excluded from CI uploads. Every observed
complete wire frame is checked with the existing Go app-contract schema validator.

The proof scope is **transport/engine fixture proof**. It does not earn final
package, native UI, U2 persistence or admission acceptance. The pending admission
entrypoint probes the ordinary constructor and records `not-run` until the real
U2 backend and recording-provider binding exist. Its executable acceptance
assertions require zero unapproved Gemini/Cursor POSTs with `policy_pending`,
retained seeded local histories on a shared home, and exactly one MiniMax request
after each 401/403 even with a successful legacy response available. Negative
controls reject each forbidden event. No fixture receipt can satisfy this scenario.
When U2 is linked into U3, rebind it to the production constructor on the synthetic
home; keep the overlay only for provider/fault injection.

One standard hosted Linux job runs fixture checks, pipe regressions, the baseline
L1 profile and real engine scenarios. It uploads only the two evidence bundles
and engine summary, including on failure. MACREV reviews the runner; U6, U8 and
U10 remain its qualified consumers before U14 closes.
