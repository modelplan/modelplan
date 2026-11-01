<!-- SPDX-License-Identifier: MIT -->
# Local session activity (phase 1)

The existing app-server owns one 2-second, non-overlapping observer. The UI does
not acquire a second log reader. Discovery reuses `ActiveLogs`' bounded regular
file walk (no symlinks, at most 64 recent files); each read is at most 256 KiB.
An unchanged URL/mtime/size caches only reduced verdicts. Every scan evaluates
deadlines again, including on cache hits. Model waits expire at 90 seconds and
tool waits at 300 seconds from the decisive record timestamp. A tail with no
recognized event uses a separately marked 30-second write-time fallback.

Claude and Codex use their existing history roots. ZCode uses `cli/log` JSONL
lifecycle events (`turn.started`, `turn.completed`, `turn.failed`) and turn IDs,
so completing one overlapping turn cannot finish another. The bounded config
reader extracts only base-URL values and checks the exact Z.ai/BigModel domain
or a subdomain; it does not deserialize keys or other configuration values.
All raw buffers are transient, never logged or placed in the verdict cache.
The sole content inspection is a fixed Claude interruption-prefix comparison.

Format provenance: the vendor's public feedback reports document JSONL lifecycle
events and the config baseURL field:
[lifecycle](https://github.com/zai-org/feedback/issues/568),
[failure](https://github.com/zai-org/feedback/issues/1234),
[configuration](https://github.com/zai-org/feedback/issues/744).
The parser and fixtures here are independently written; no upstream code or
transcript content is copied.

Activity binds only through existing per-session ledger associations to a
verified opaque account reference. `refs[source]` is not session provenance:
the legacy fallback now disappears when multiple different accounts share a
source, and the new observer excludes that fallback entirely. Missing or
conflicting session bindings remain unbound. In particular the existing ZCode
DB observer currently records no subscription reference; a base-URL host alone
does not resolve that identity gap. No provider-wide animation is substituted.

Rows carry optional per-account activity with session/account references,
binding verification, phase, original record time and expiry. Publication uses
the existing consent epoch/generation fence. Recording-off, missing permission,
login changes and expired evidence cannot create working state. Rates and token
counts are independent and unchanged.

Tests use temporary synthetic trees only. Go execution and artifact generation
run in CI. Phase 2 (member-key projection, explicit in-flight animation gate,
one-second rotation, consent copy and latency proof) follows the S4 member-key
merge and does not ship in this phase.
