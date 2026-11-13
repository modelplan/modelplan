<!-- SPDX-License-Identifier: MIT -->
# C15: OpenCode V2 local sessions and usage

C15 is an additional Go reader seam, **default off and not registered in the v1
production reader inventory**. It does not change the existing performance reader
or OpenCode Go account reader. The new `opencode.local_history` consent scope has
no default grant and inherits neither legacy whole-tool grants nor OpenCode Go
or browser-session grants. This PR adds no CLI command, App wire schema,
installation hook, scheduled watcher, catalogue row or account-reading route.

## Authorised input and projection

`OpenCodeV2DB(home)` resolves the documented
`<XDG_DATA_HOME or home/.local/share>/opencode/opencode.db`; an absolute
`OPENCODE_DB` selects an explicitly configured store, including a release-channel
database. Relative overrides fail closed. Resolution performs no I/O. The caller
supplies the selected path and the existing `HistoryAccess` consent, installation
key, keyed profile reference and live cancellation/publication fences to
`RefreshOpenCodeV2`. Automatic and Passive-only are eligible after explicit
consent. Readers/history Off, denied access, invalid privacy, absent consent or
unavailable installation key prevent new source reads. Future App integration
must supply the hidden/asleep and revocation fences through this same contract.

Only real `session_v2` and `session_message` tables with the evidenced columns
qualify; V1 `session`, `message` and JSON stores are unsupported. Views cannot
stand in for the native tables. The database is opened with SQLite `mode=ro`,
`query_only` and `trusted_schema=off`, with a short busy timeout and a two-second
context deadline. Every database/sidecar path component must be free of symlinks.
No OpenCode process, CLI, service discovery, socket, network call, config/auth
file, environment credential, browser store or Keychain is used.

The SQL projection selects bounded transient message/session IDs, the native
update watermark, model ID, created/completed milliseconds and the native
input/output/reasoning/cache-read/cache-write counts. It never selects the whole
message JSON, message content, `session_part`, V1 message tables, titles,
directories, tool payloads, native provider data, credentials or account IDs.
Wrong numeric JSON types become a fixed invalid sentinel inside SQL; arbitrary
nested objects/text never enter the Go projection. The independently written
fixtures include sensitive-field canaries and malformed nested metadata.

C15 reports completed assistant steps in **root sessions only**. Child sessions,
forks and orphan messages are excluded conservatively to avoid copied history
and delegated usage being counted twice. This is scoped local coverage, not a
complete lifetime bill. Session observations contain a keyed reference, validated
model ID and original completion time; they make no foreground/current-session
claim. Equal completion times use native row order. A model variant does not
establish reasoning effort or Fast. Missing/invalid model IDs stay unknown;
missing token categories stay null and recorded zero stays zero. No total, cost,
price, request count, account binding or remaining quota is inferred.

## Incremental state, errors and cleanup

A read transaction gives each batch a consistent snapshot. The numeric
`(time_updated, rowid)` watermark revisits the final timestamp after a complete
batch, so tied updates replace HMAC-keyed entries rather than being summed.
Native completion/corrections must update `time_updated`, as in the pinned
OpenCode writer. Unchanged keyed database/WAL generations perform zero SQL or
source-content reads. A changed source resumes the watermark; source/profile
changes, inode replacement, a missing anchor or update-watermark regression
start bounded recovery of that source only. Arbitrary historical edits that
preserve native update timestamps are outside the emitter contract.

`recordsRead` counts projected rows; `bytesRead` counts only the bounded values
returned by SQLite (including numeric watermark fields), not physical database
page reads or transcript size. Unchanged sources report zero for both.

Each attempt projects at most 1000 rows, retains at most 10000 entries per active
or staged generation, and limits the state file to 8 MiB. Entries expire after
35 days. Recovery checkpoints persist across process restarts. Replacement and
partial batches stage their data; only a complete batch promotes it to the
visible reading. The last good reading and its original age survive errors or
incomplete recovery. The source may still change between batches; `partial`
never claims complete current coverage. The two-second deadline also bounds
query work when the source lacks an update-order index.

The cache holds only validated counters/model/timestamps, consent capture
metadata, numeric watermarks and domain-separated HMAC-SHA256 references for
source, profile, session, message and file generations. No raw IDs, source paths
or transcript bytes are persisted. Schema version 1 here versions the C15 cache;
it does **not** mean OpenCode V1 support. New key/profile references cannot reuse
another installation's readings.

All profiles share the local-history five-minute attempt reservation and
10/20/40/60-minute failure backoff. Clock rollback cannot shorten the reservation.
`ReadOpenCodeV2Cache` opens only the sanitised ModelPlan cache and never advances
its watermark or gate. `ForgetHistoryProfile` and the shared production Forget
cleanup remove C15 derived readings/checkpoints while preserving the shared gate
and installation key. Production discovery/refresh remains unregistered.

Returned and retained `reason` fields use only fixed codes: `file_missing`,
`file_unreadable`, `schema_changed`, `parse_error`, `timeout`. Driver errors and
publication-callback prose never escape into JSON, cache or logs. Availability,
freshness, confidence and beta remain separate. C15 stays beta: fake-home tests
are format/conformance evidence, not real-account qualification.

## Evidence and verification

First-party [V2 troubleshooting documentation](https://opencode.ai/v2/docs/troubleshooting/#service-files)
defines the database location and `OPENCODE_DB`. The [V2 migration guide](https://opencode.ai/v2/docs/migrate-v1/)
distinguishes V2 from V1. Schema evidence is pinned to OpenCode commit
`8b4d98c33a75bc2404154486eadaffa8891493aa`:

- [V2 SQLite tables](https://github.com/anomalyco/opencode/blob/8b4d98c33a75bc2404154486eadaffa8891493aa/packages/core/src/session/sql.ts).
- [Assistant model, timestamps and usage](https://github.com/anomalyco/opencode/blob/8b4d98c33a75bc2404154486eadaffa8891493aa/packages/schema/src/session-message.ts).
- [Native token categories](https://github.com/anomalyco/opencode/blob/8b4d98c33a75bc2404154486eadaffa8891493aa/packages/schema/src/token-usage.ts).
- [Native update timestamps](https://github.com/anomalyco/opencode/blob/8b4d98c33a75bc2404154486eadaffa8891493aa/packages/core/src/database/schema.sql.ts).
- [Completion and usage updates](https://github.com/anomalyco/opencode/blob/8b4d98c33a75bc2404154486eadaffa8891493aa/packages/core/src/session/message-updater.ts).

Implementation and fixtures are original; no upstream source, database, captured
transcript or new dependency is included. `TestReaderReasonOpenCodeV2Conformance`
validates actual returned/retained JSON, all cache JSON, and captured process
stdout/stderr under synthetic failures. The external
`quota.TestReaderReasonOpenCodeV2LocalStore` fixture runs through the same reader
seam in the existing uncached hosted reader-conformance step; no workflow or
runner changes are needed. All tests use `testenv.IsolateHome` and handwritten
SQLite databases; no real home/account/credential or provider call is used.

From `cli/`: `go test -count=1 ./internal/localusage -run 'Test(OpenCodeV2|ReaderReasonOpenCode)'`.
