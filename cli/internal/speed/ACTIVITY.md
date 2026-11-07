<!-- SPDX-License-Identifier: MIT -->
# Local session activity

The existing app-server owns one 2-second, non-overlapping observer. The UI does
not acquire a second log reader. Discovery reuses `ActiveLogs`' bounded regular
file walk (no symlinks, at most 64 recent files); each read is at most 256 KiB.
An unchanged URL/mtime/size caches only reduced verdicts. Every scan evaluates
deadlines again, including on cache hits. Model waits expire at 90 seconds and
tool waits at 300 seconds from the decisive record timestamp. A tail with no
recognized event uses a separately marked 30-second write-time fallback.

Claude and Codex use their existing history roots. ZCode uses `cli/log` JSONL
lifecycle events (`turn.started`, `turn.completed`, `turn.failed`) and turn IDs,
so completing one overlapping turn cannot finish another. No ZCode settings file is
opened here: ZCode is watched only when ModelPlan's cache holds a successful reading
of its configured Coding Plan key, and its activity binds to that key's account.
All raw buffers are transient, never logged or placed in the verdict cache.
The sole content inspection is a fixed Claude interruption-prefix comparison.

Format provenance: the vendor's public feedback reports document JSONL lifecycle
events:
[lifecycle](https://github.com/zai-org/feedback/issues/568),
[failure](https://github.com/zai-org/feedback/issues/1234).
The parser and fixtures here are independently written; no upstream code or
transcript content is copied.

Activity binds only through per-session ledger associations to a verified opaque
account reference: completed sessions, plus live records for a first turn in flight.
The app-server records both itself every 30 seconds, so no plugin hook is needed and
a brand-new session can take up to that long to light. `refs[source]` is not session provenance:
the legacy fallback now disappears when multiple different accounts share a
source, and the new observer excludes that fallback entirely. Missing or
conflicting session bindings remain unbound. The ZCode DB observer records no
subscription reference, so ZCode binds through its one configured key instead. No
provider-wide animation is substituted.

Rows carry optional per-account activity with session/account references,
binding verification, phase, original record time and expiry. Publication uses
the existing consent epoch/generation fence. Recording-off, missing permission,
login changes and expired evidence cannot create working state. Rates and token
counts are independent and unchanged.

Tests use temporary synthetic trees only. Go execution and artifact generation
run in CI. The normal App entry now maps admitted account activity to the existing
member key and supplies explicit in-flight evidence without inventing token output.
The existing batch-013 frame provider and one-second rotation stay in use; app and
OS Reduce Motion hold a static frame. A one-shot presentation deadline retires
stale effects even without another engine notification. Sleep/lock cancel that
deadline and withdraw effects through the existing lifecycle controller; resumption
still requires current rows. First-run consent discloses local activity reads.

`NormalEntryActivityTests` drives `EngineRowsEntry` with synthetic engine messages,
uses the production flame frames and observes the real CA installation through the
existing resource-check SPI. Detached, unhosted CA layers lose animation keys at a
run-loop flush, so the test samples installation and verifies the one-second period
there; expiry and lifecycle assertions require actual effect/lease withdrawal.
This is not physical display acceptance. Restoring the old output-only gate makes
the normal-entry regression fail. Missing or ambiguous bindings remain unbound,
including ZCode ledger entries without an explicit subscription association.
