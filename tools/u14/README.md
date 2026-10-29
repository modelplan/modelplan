# U14 synthetic home and candidate evidence

The baseline/evidence tools and the real-binary engine runner share one scenario
registry. The runner drives `modelplan app-server` through anonymous pipes on
synthetic homes, with constructor overlays for recording providers and fault
injection. The backend and persistence scenarios use production U2; provider
data and publication-churn faults are synthetic. U6, U8
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
profile locally, choose a new destination under the git-ignored worktree `.tmp/` directory (create that parent first):

```sh
python3 tools/u14/verify.py --output .tmp/u14-evidence-unique-run
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
is migrated by the production U2 constructor; the original shape and that mutation are recorded separately.

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
python3 tools/u14/run.py --output .tmp/u14-engine-unique-run
python3 tools/u14/run.py --output /tmp/u14-pressure-unique-run \
  --scenarios U3-backpressure U14-zero-rows-omitted
```

The default engine IDs are `U14-protocol-smoke`, `U3-backpressure`,
`U14-zero-rows-{omitted,null,reported,corrupt}`, `U14-empty-states` and
`U2a-admission`. `--scenarios` selects registry IDs; unselected available engine
scenarios remain `not-run`, and UI/device capabilities remain `unsupported`.
The ordinary fail-closed binary is always exercised as a separate check.

The runner builds three exact CLI binaries: ordinary, provider-only, and history/fault. The ordinary build has no fixture
imports or overlay. Admission uses the provider-only binary: the command and
app-server constructor bytes are identical to the ordinary source, and only the
native HTTP-client constructor is replaced with a recording transport via a
virtual quota file. Production `accountReadClient` and `readers.NewReadTransport`
remain in that call chain; their source hashes are recorded. There is no
history-source or detection override in this binary.

The history/fault binary replaces the command's constructor call with the typed
provider constructor used by the model/cursor/backpressure scenarios. It retains
the production shared backend. Only the pending empty-state case enables its
real repeated-revoke fault; readers-off/no-consent/empty use the ordinary binary.
Recording transports never open a socket. Ordinary builds expose no fixture
flag, environment switch or endpoint override. Every role records its exact
binary, adapter, constructor-call and overlay hashes; each scenario binds the
roles it actually used. Builders reject changes to the expected constructor seams.

All three binaries use `SharedBackend`, the same U2 store, durable grant receipts,
original capture provenance, budgets, `RowsInput`, `ChangedRowsInput` and
`AppendManagedRows`. No test implementation of consent persistence or `Backend`
remains. The recording history source implements only U3c's `HistorySource`; its
admission and every output are fenced by the real backend. Unknown provider model
fields are omitted/null/present/corrupt synthetic variants. A corrupt history
reply fails that query while preserving the same stable rows.

`U3-null-selectors` sends `ref:null`, `cursor:null` and both null through the
registered handler. A positive query establishes observable admission/provider
counts; all invalid calls return `invalid_params` before either count increases.
A regression-only fault overlay that removes the producer guard must fail this
probe. The driver also remembers retired epochs: an old-7 → new-1 → old-7 private
result is rejected, and a late old receipt cannot restore the prior context.
Generation floors remain monotonic within each active epoch.

The ordinary smoke checks production capability registration, exact row membership
from detection plus persisted consent, duplicate ids, diagnostics, wrong-method
and unmatched-operation token rejection, and shutdown. Baseline input hashes are
checked before launch; after launch only the known production consent file may
change among those inputs. Credentials, tool configs and app preference inputs
remain hash checked. System executables found by compiled detection may add rows;
no real home or inherited credential environment is passed to a child.

`U3-shared-state` uses one synthetic home for the app-server and independent CLI.
It checks external revoke notifications and the floor, authoritative stale-error
context, reset epochs, cursor invalidation across scope/epoch/session, failed query
isolation, two-query caps and terminal cancellation, and Deny/Forget for a retired
scope with readers off. Production history queries use sanitized local caches
only; kinds and providers without an existing typed source return
`history_unavailable`. No query scans source logs or refreshes a provider.

Four real backend empty states are exercised: readers off, no consent, admitted
without readings, and pending. Pending uses a test detection callback that commits
two real revokes during each stable-build retry and leaves the fallback fence
stable. This is a labeled fault scenario, with no production switch.

Backpressure stops draining the actual stdout pipe after two recording history
queries complete and a large data write starts. A real reader lock forces pending
cleanup; a revoke must commit while stdout remains blocked. A short-pause probe
then observes `engine/health` through the transport control queue, in the new
consent context. A second process stops reading until the production 10-second
write timeout, then restarts and replays the real U2 receipt. The receipt is never
stored by fixture code, and revoked values stay absent after restart.

`U2a-admission` runs the provider-only binary with the unchanged production
constructor and one shared synthetic home per case. Gemini OAuth and Cursor
SQLite login inputs are valid synthetic data; missing credentials cannot explain
zero POST calls. Real schema-1 migration supplies retained grants. A new account
grant is refused with `policy_pending`, explicit remote refresh is deferred, and
an independent CLI refresh still reaches no unapproved provider.

A separate MiniMax compatibility control first returns 404 then a successful
legacy 200 and verifies a positive reading. The 401 and 403 cases must stop after
one authenticated GET, despite that available legacy reply. Another app request
and an independent CLI cannot reset the persisted budget. The raw recorder keeps
only compiled route labels, method/status and a credential-match boolean; header
values, credentials and bodies are never logged. Gemini and Cursor history are
checked before and after account reads using positive typed values and hashes,
not only row counts. Cursor uses two complete synthetic numeric records at the
compiled `.cursor/token-usage/usage.jsonl` path, with explicit local-history
consent and a real refresh before querying. This tests the optional export's
numeric contract described in [Cursor local history](../../docs/cursor-local-history.md);
it does not certify native Cursor counts or execute/install an exporter. Original
tool-owned login inputs and the numeric export must remain byte-identical.

Selecting any admission ID runs the shared group and records these outcomes
individually:

| Scenario | Required outcome |
|---|---|
| `U2a-post-veto` | pass: both unapproved scopes make zero underlying calls |
| `U2a-minimax-auth-stop` | pass: 401/403 stop before the legacy route |
| `U2a-minimax-legacy-control` | pass: the available legacy reply produces a reading |
| `U2a-local-history-gemini` | pass: typed values remain identical |
| `U2a-local-history-cursor` | pass: two positive typed export rows remain identical |
| `U3b-refresh-shared-budget` | pass: CLI preserves budget bytes, app cooldown deadline and raw request count |

The aggregate `U2a-admission` passes only when every executed subcheck passes.
The components remain independently visible in the manifest. Intact Cursor seed
bytes or an empty successful query never count as history readability; disabling
only the real Cursor decoder in a negative-control build must fail this scenario.
The U3b component exposes the budget checks already exercised inside admission,
and additionally verifies the app-server's `cooldown` response and exact deadline
before and after the standalone CLI call. The successful 404→200 compatibility
control is one logical read with two HTTP calls; both failure cases have one call.
No further HTTP call is permitted. No budget file is reset or timestamp rewritten.
Linux engine results are L1; dedicated test-Mac/package L2 is recorded as not-run.

```sh
mkdir -p .tmp
TMPDIR="$PWD/.tmp" python3 tools/u14/run.py --output .tmp/admission-run --scenarios U2a-admission
```

In-checkout output is accepted only under the git-ignored `.tmp/` directory;
other tracked paths and symlink parents remain rejected. Remove completed local
runs after retaining their bundle where needed. Hosted CI uploads only bundles
and summaries, then removes its scratch directory.

The proof scope is production U2 state/admission and U3 transport with recording
providers and a publication-churn fault. It does not earn native UI, final-package,
owner-device or L3 acceptance. UI scenarios remain unsupported on this Linux lane.
One standard hosted Linux job runs Go/driver regressions, the baseline profile,
and executable scenarios; it uploads only the evidence bundles and summaries.
