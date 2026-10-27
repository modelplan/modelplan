# Passive Claude session adapter (beta, draft)

This PR is stacked on `cli/readers-local-history` / PR228 at the coordinator's
request. It contains no independent file walker, cursor, offset cache or log
collector. `ProjectClaudeSessions` reuses `localusage.HistoryAccess` and projects
bounded transient record batches into model/effort/Fast plus keyed session and
observation metadata. It performs no file/credential/Keychain/process/network I/O.

## Exact READERS API gap

PR228 currently exports `RefreshHistory`, `ReadHistoryCache`,
`ForgetHistoryProfile`, and the count-oriented `HistoryAccess/HistoryRow/HistoryResult`
types. `historyDepth("claude")` is unsupported; `historyAllowed`, `decodeHistory`,
`historyCursor` and its atomic commit logic are private and fixed to seven history
providers. `HistoryRow` carries day/model/token counts, not effort, nullable Fast,
source session selection or a sanitized custom snapshot.

The adapter needs READERS to export a bounded append/decoder seam that:

- admits approved main Claude transcript paths and supplies the filename session
  selector/profile scope without persisting raw paths;
- feeds new complete rows and explicitly marks bounded discovery/recovery uncertainty;
- allows a sanitized session-state snapshot (and only minimal keyed technical
  decoder/frontier state) to commit atomically with its cursor;
- preserves old capture age on incomplete/unreadable input and supports a bounded
  local-state cadence independent of network quota gates;
- retains existing byte-count, restart, truncation/replacement, privacy and
  revocation guarantees.

Until that API exists, this PR stays draft and has no collector/cache integration.
It does not patch READERS-owned files or invent a second cursor. Retarget to main
once PR228 merges; wire the adapter only after the exported contract is agreed.
The original standalone cursor has been removed.

## Projection contract

The owner confirmed top-level `effort`, `message.model`, and
`message.usage.speed` on 2026-10-27. The committed minimal fixture has exactly those
shapes; other usage keys are ignored. Missing/null/unknown fields independently
remain unknown, including malformed optional values. Speed standard maps false;
fast maps true. No service-tier/latency/preference inference is used. A minimal
field fixture cannot establish a current/interactive session by itself.

Selection validates filename/header session agreement and source timestamps,
reconstructs the selected main-chain leaf through transient UUID/parent UUIDs,
and chooses its newest complete assistant record. Complete same-message streaming
fragments are deduplicated; conflicting model/effort/Fast values become unknown
independently. Later incomplete blocks do not freshen or splice the previous turn.
Sidechains, agent/team workers, metadata/compaction, synthetic/error responses,
SDK entrypoints and daemon sessions cannot displace an interactive recent thread.
Unclassified origins cannot displace confirmed CLI/IDE/desktop origins. Explicit
matching callers get current-thread; an unmatched caller is reported as such.
A bounded/incomplete discovery cannot claim recent-thread. No file mtime or
foreground-process inspection establishes activity.

The session key is HMAC-SHA256 over the installation key, a versioned domain,
opaque profile ref and session ID. Profiles cannot share a key accidentally.
Raw IDs, ancestry, entrypoint/session-kind fields, content, cwd, titles, project
names and other usage fields remain transient or are never decoded. No label is
collected even if the optional project-label preference would permit it. The
selected projection replaces optional plugin/status-line harness metadata as a
whole, including clearing absent fields; optional snapshots cannot override it.
Automatic and Passive-only are admitted; missing consent/denial/off fail closed.

Protocol evidence is read-only: Anthropic SDK Python sessions.py at
717cea09021fac3654879f0a362ed254a73ec35d and published TypeScript SDK 0.3.301.
Their implementations are not copied or vendored. All records in tests are
handwritten; no real transcript or credential was read. Tests cover the owner
shape/older optional fields, branches/resumes, streaming duplicates/conflicts,
SDK/daemon/worker exclusions, current versus recent/missing caller, timestamp
and bounded uncertainty, HMAC isolation/privacy canaries and optional snapshots.
Incremental I/O/atomic-commit acceptance remains blocked on the READERS seam above.
