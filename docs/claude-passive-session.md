# Passive Claude session reader (beta)

The reader uses the shared [local-history projection interface](local-history-projection.md)
from PR232. `ClaudeSessionReducer` is a `localusage.ProjectionReducer`; it performs
no file, credential, Keychain, process or network I/O. There is no independent
walker, cursor, offset cache or scheduling engine.

`RefreshClaudeSessions(ctx, root, cache, access, now)` explicitly ingests the
consent-scoped Claude profile root through `RefreshProjection`. The shared engine
admits only main `projects/<project>/<session>.jsonl` files, delivers bounded
complete lines, handles appends/restarts/replacement/truncation and commits the
sanitized frontier, snapshot and cursors atomically. Its five-second local floor
and failure backoff are independent of account-quota/network schedules.

`ReadClaudeSessions(cache, access, caller, now)` uses `ReadProjectionCache` only.
It never discovers or reads a transcript, even on an empty cache. The persisted
snapshot is independent of the caller: selection is repeated using the caller's
profile-scoped HMAC, so a caller change requires no ingestion or write.
`ForgetClaudeSessions(cache, access)` uses `ForgetProjectionProfile` after the
caller cancels and joins in-flight work. It removes derived state/cursors even
after consent revocation, preserving the shared engine's local reservation.

CLIJIT supplies authorized roots, `localusage.HistoryAccess`, caller selection and
explicit refresh scheduling, including suspension while hidden/asleep. Quota
`Paths.ClaudeSessionAccess` admits cache-only projection into `Read`: session state
can produce an account with no quota windows when no plugin/status-line/account
snapshot exists. When an account exists, native session fields replace optional
hook metadata as a whole, including clearing unknown values. The session reader
does not collect quota or require a status line/plugin. Missing access grants
nothing; consent, denial, Automatic/Passive-only and `MODELPLAN_READERS` gates
apply before ingestion and cache presentation.

## Fields and selection

The owner confirmed top-level `effort`, `message.model`, and
`message.usage.speed` on 2026-10-27. The minimal fixture has exactly those shapes;
other usage keys are ignored. Missing/null/unknown fields independently remain
unknown, including malformed optional values. Speed `standard` maps to false;
`fast` maps to true. No service-tier/latency/preference inference is used and no
setting is changed. A minimal field fixture cannot establish activity by itself.

Selection validates filename/header agreement and source timestamps, reconstructs
the timestamp-selected main-chain leaf using keyed node references, and chooses
its newest complete assistant record. The whole selected ancestry must be
available. Complete same-message streaming fragments are deduplicated; conflicting
model/effort/Fast values become unknown independently. Exact repeated records do
not freshen the snapshot. Later incomplete blocks do not splice or freshen the
previous turn. A resumed branch can select an earlier assistant across refreshes.

Sidechains, agent/team workers, metadata/compaction and synthetic/error responses
are excluded. SDK/daemon sessions and unclassified origins cannot displace a
confirmed CLI/IDE/desktop recent session. An explicit matching caller is labelled
`current-thread`; a fallback is `recent-thread` and an unmatched caller is reported.
No file mtime or foreground-process inspection establishes activity.

Only conclusive discovery prunes missing file frontiers. Incomplete discovery,
byte recovery, missing ancestry, malformed records or an omitted bootstrap prefix
cannot publish a new snapshot: the engine retains the original-age last good
snapshot while committing sanitized progress with its cursor. Complete empty
files/discovery clear selection. Reset discards that file's old decoder state.
The semantic frontier is capped at 4096 sanitized graph records and 1800 KiB across
256 files, below the engine's 2 MiB decoder cap. Hitting a semantic bound remains
incomplete until reset or conclusive removal; it never guesses from dropped
ancestry. A presentation exceeding 64 KiB also remains incomplete.

## Privacy and verification

Session, node and message references are domain-separated HMAC-SHA256 values
scoped to the installation key and profile. The frontier contains only keyed
references, sequence tie breakers, timestamps, approved model/effort/Fast fields,
closed origin/type enums and completeness/exclusion flags. The snapshot contains
only approved fields and keyed observation/selection metadata. No message
contents, raw IDs/ancestry, paths, project names, titles, credentials or arbitrary
provider text are stored. No project label is collected.

Protocol evidence is read-only: Anthropic SDK Python sessions.py at
717cea09021fac3654879f0a362ed254a73ec35d and published TypeScript SDK 0.3.301.
Their implementations are not copied or vendored. All test records are handwritten
synthetic fixtures. Tests cover field unknowns, selection/exclusions, persisted
resumes, streaming duplicates/conflicts, unchanged-file zero-content reads,
append/torn-line recovery and backoff, reducer-error atomic rollback/replay,
replacement/truncation/empty discovery, bounded uncertainty, profile isolation,
cache-only caller changes, consent/privacy, Forget and optional-hook precedence.
No real transcript, credential or vendor request is needed or accessed.
