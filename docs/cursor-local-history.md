<!-- SPDX-License-Identifier: MIT -->
# Cursor local numeric history (beta)

`cursor.local_history` is independent of Cursor's saved-login account quota.
The account POST route remains `policy_pending`. An old saved-login grant does
not grant this new local producer. Grant local history explicitly, then request
`refresh/request` for `cursor.local_history`. `history/query` with tool `cursor`
and kind `tokens` reads only the resulting sanitized ModelPlan cache.

The supported source is an **existing optional numeric export**, not a built-in
Cursor token-history guarantee: `~/.cursor/token-usage/usage.jsonl`, written by
[Cursor Token Usage's MIT emitter at 9379e191](https://github.com/SebberSky/cursor-token-usage/blob/9379e191c3d1caa80315cf7814146127833a492e/hooks/token-usage-logger.py).
Its [license](https://github.com/SebberSky/cursor-token-usage/blob/9379e191c3d1caa80315cf7814146127833a492e/LICENSE)
is MIT. The Go parser is independently written from its emitted record contract;
no exporter code is copied or executed. ModelPlan does not install the exporter,
edit Cursor hooks, access its transcript, read its chat/prompt snapshots, or use
its estimated prices. Without the export, count history is unavailable.

Only complete JSONL `stop` records with `tokens_present: true`, a timestamp, bounded
conversation/generation identifiers, and at least one nonnegative integer count
are accepted. Input, output, cache-read, cache-write and total are preserved as
reported by the exporter; absent fields stay unknown. ModelPlan never derives a
total by adding buckets, estimates tokens from text/context gauges, or interprets
these records as remaining quota, spend or a provider bill. The exporter itself
may normalize or calculate fields, so its reported numbers do not establish
native vendor accuracy. Synthetic compatibility is tested; live vendor accuracy
is not certified.

Records replace the same keyed conversation/generation rather than summing retry
copies. Existing history limits, complete-line checkpoints, HMAC references,
35-day cache retention, shared five-minute read gate, consent capture stamps,
revocation checks and Forget cleanup apply. Only sanitized day/model/count rows
survive; prompt previews, workspace roots, raw session/turn identifiers, arbitrary
extra fields and credential canaries are excluded from caches and responses.
Negative, fractional, oversized and wrong-type counts are rejected. No unknown
counter becomes zero. Source files are never modified or copied.

The real `modelplan app-server` registers this producer through the ordinary
shared history source. Typed responses carry the local-history scope and their
admitted epoch/generation. Continuation cursors retain the existing session,
account, scope and consent binding. Querying does not scan or refresh the export.
Late results after a revoke or epoch reset are discarded by the handler and
shared enqueue/write fences.

## Acceptance fixture

Use only a disposable synthetic home. Write two complete records to the compiled
path, with different `generation_id` and `model` values so the existing day/model
aggregation produces two typed items. Include `event: "stop"`, RFC3339 `ts`,
`conversation_id`, `tokens_present: true`, and numeric `total_tokens` (other native
buckets are optional). Grant `cursor.local_history`, request its refresh, and wait
for two `history/query` token items before testing the account POST veto. Capture
both counts before and after the veto; never declare a pass from an empty source
or a hard-coded item count. The existing U14 runner must seed and refresh this
producer before replacing its prior `unsupported` result.
