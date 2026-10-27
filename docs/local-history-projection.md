# Local-history projection interface (beta)

`cli/internal/localusage` exports `RefreshProjection`, `ReadProjectionCache` and
`ForgetProjectionProfile` for passive local session projections. FEEDFIX owns the
Claude reducer and CLIJIT owns consent, authorized roots and caller selection.
This interface does not collect quota or decode Claude fields.

The supported kind is `claude`. The supplied root is a Claude profile root;
only `projects/<encoded-project>/<session>.jsonl` main transcripts are eligible.
Discovery does not descend other root directories, hidden directories or subagent
trees. Symlinks and nonregular source files are refused. Default and custom roots
use the same rule. Detection alone grants no access: `HistoryAccess`, Passive,
`MODELPLAN_READERS=off`, denial, key availability and revocation checks apply.

The interface uses the existing history discovery, source opener, keyed metadata
and content checkpoints, complete-line cursor loop, lock and atomic state writer.
It adds no second walker or cursor. Count-history API signatures and scheduling
stay unchanged. Projection has a separate five-second local-state reservation,
shared across profiles, with failure backoff up to one minute. Callers suspend
scheduled work while hidden/asleep and cancel/join work before Forget. Forget
removes this profile's derived state and cursors, retaining its kind's reservation.
No quota/network gate is touched; no vendor or subprocess call occurs.

## Reducer contract

`ProjectionReducer(ctx, prior, batch)` returns `ProjectionState` or an error. The
prior state contains a sanitized presentation `Snapshot`, minimal sanitized
`Decoder` frontier, source `ObservedAt`, engine-owned `CapturedAt` and a semantic
`Incomplete` flag. The reducer is trusted application code: it must whitelist its
output, use keyed identities, avoid I/O, and never retain message contents, raw
IDs/ancestry, paths, project names, titles, credentials or arbitrary provider text.
The engine validates JSON and size bounds; it cannot determine whether arbitrary
JSON contains a sensitive field. Snapshot is capped at 64 KiB and Decoder at
2 MiB. Neither raw batch nor reducer error is serialized.

Each data batch contains up to 256 complete newline-terminated lines (at most
1 MiB total), the first line's original byte offset, a profile-scoped HMAC file reference, and the transient
filename session ID. Filename/header agreement is the provider reducer's job.
`Reset` identifies initial discovery, replacement, truncation or rewrite; discard
that file's old frontier before consuming its new lines. `EndFile` follows each
processed file, including unchanged files with `Unchanged=true`. Unchanged files
require no source content reads. Source-open failures omit that file's batches
and make final recovery incomplete.

Large new/reset files bootstrap from the last 4 MiB, discarding the first partial
line. `PrefixOmitted` remains true in that file's future batches and in `Final`
while any recovered file has an omitted prefix. This is bounded evidence, never
proof of complete ancestry or classification. The reducer must mark `Incomplete`
when missing ancestry/headers prevent safe selection. Appends then resume from
the last committed complete line without rereading the tail.

One `Final` batch supplies the bounded live keyed-file manifest and transaction
`DiscoveryComplete` / byte `RecoveryComplete` flags. Other batches already report
discovery completeness; EndFile reports that file's byte recovery. Only conclusive
discovery permits pruning missing file frontiers. Limits are 4096 discovery
entries, 256 files, 4096 delivered records, 8 MiB per file and 32 MiB per refresh.
Hitting a limit yields incomplete recovery; committed decoder/cursor progress
resumes on the next eligible refresh. Context cancellation stops reads and
prevents publication. A file changing during recovery also reports incomplete
and is rechecked on the next attempt.

On incomplete byte recovery or reducer `Incomplete`, sanitized decoder progress
and cursors commit together, while the previous good Snapshot, ObservedAt and
CapturedAt remain unchanged. On a complete final reduction the snapshot can be
replaced or cleared; unchanged snapshots retain their original capture time.
Reducer errors, invalid output or cancellation abort the state/cursor transaction.
The reservation remains. This lets the next attempt replay uncommitted lines.

`ProjectionResult` includes the sanitized snapshot, original observation/capture
times, availability, completeness, freshness, next eligible attempt, beta label
and parsed/validation byte diagnostics. It exposes no decoder frontier. Cached
completeness describes the last committed read; freshness ages independently.
`ReadProjectionCache` reads only ModelPlan's cache and reservation: no source
discovery, stat, open or read. Synthetic regression tests cover this contract;
no real account, transcript or credential is needed or accessed.
