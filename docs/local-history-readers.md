<!-- SPDX-License-Identifier: MIT -->
# Incremental local agent usage

`localusage.RefreshHistory` reads an explicitly authorised local store for Amp,
Droid, Kimi Code, Qwen Code, Copilot CLI, Gemini CLI or Grok Build. It reports
**local usage**, tokens by recorded model and UTC day, with separate unknown or
unallocated measurements. It never reports remaining quota, calls a provider,
launches a tool, imports credentials or requires an export command.

## Sources and limits

The caller supplies the selected store root; these are relative record paths,
not additional detection signals or arbitrary search locations.

| Tool | Authorised store / records | Mapping and coverage |
|---|---|---|
| Amp | Historical `amp/threads`, flat `T-*.json` | Assistant `usage` model, timestamp and native token fields. Missing usage timestamps stay undated. Current cloud-only/stub threads have no local usage to recover. |
| Droid | `.factory/sessions`, `*/<session>.settings.json` | Own-session `tokenUsage` only. Inclusive parent/child totals are excluded. The snapshot cannot prove historical model/day, so its counts remain **unallocated**, with no current-model or mtime attribution. |
| Kimi | `.kimi/sessions`, `*/*/wire.jsonl` | Timestamped Wire `StatusUpdate.token_usage` step deltas. Missing model stays unknown. Message IDs deduplicate repeated updates; no context-window count is treated as usage. Unknown Wire protocol versions are unsupported. |
| Qwen | `.qwen`, known `projects/*/chats`, `tmp/*/chats` and legacy `*/chats` records | Existing Qwen assistant/usageMetadata projection; source record IDs and timestamps only. This is the transcript-history source, separate from the aggregate-only reader in PR 224. Select one source; never add both. |
| Copilot CLI | `.copilot/session-state`, `*/events.jsonl` | Pinned SDK durable `session.shutdown.modelMetrics`. Ephemeral `assistant.usage` and context usage are excluded. Only a session whose recorded start/shutdown are on the same UTC day can enter a daily row; otherwise totals remain unallocated. Later cumulative shutdowns replace prior ones. |
| Gemini CLI | `.gemini`, known `tmp/*/chats/session-*.json` and legacy `*/chats` snapshots | Existing Gemini recorded-message/token projection, deduplicated by native IDs. Changed snapshots replace their own entries; no session total is added to message usage. |
| Grok Build | `.grok/sessions`, `*/usage.json` or `*/*/usage.json`, with sibling `summary.json` | Recorded per-turn `modelUsage` and `endedAt`, never the cumulative session total. Known root-session summary metadata is required. Forks, hidden sessions and subagent siblings are excluded because parent ledgers can already include their usage. Incomplete provider records stay outside complete daily totals. |

Input/cache/reasoning categories retain their emitter's native meanings and can
overlap. No total, price, cost, subscription, reset or missing value is inferred.
Zero remains a known value. Missing model/day is displayed explicitly; it is not
filled from a preference, current model, neighbouring record or file timestamp.
These are observed local records, with incomplete coverage where the tool stores
no local usage. They are not a complete bill.

## Incremental and privacy contract

Each tool has one shared cross-process lock and persisted attempt reservation,
with a five-minute minimum across profiles and 10/20/40/60-minute error backoff.
The Qwen history and aggregate seams use the same Qwen gate/lock names. All calls,
including explicit refresh and failure, respect the gate; clock rollback never
shortens it. CLIJIT must route each provider/source once under the common reader
policy, including any account-reader scheduling.

Unchanged file generations perform zero source-content reads. JSONL resumes at
its last complete line; an unchanged incomplete suffix waits for the emitter to
change it. Appends validate bounded checkpoints; same-size rewrites trigger a
bounded replay using keyed ctime/mtime/size and file identity. Changed JSON
snapshots replace their own keyed rows. Cursor and validation-read bytes are
separate diagnostics. Signed Darwin device IDs and unsigned Unix layouts work;
unknown metadata layouts fail visibly. Recovery can be partial under the budget.

Discovery is bounded to 4096 directory entries, 256 record/metadata files, known
filenames/depth and no symlink components. A file contributes at most 8 MiB per
read; a transaction parses at most 32 MiB, and at most 20000 projected entries are
retained. Dated history expires after 35 days. Undated captures also expire after
35 days without inventing a usage day. Source timestamps retain their original
age; failed or unchanged reads never make old usage newly observed. Grok readings
retain their safe capture-time root classification independently of live cursor
discovery, so missing or unreadable sources retain aged last-good data with an
unavailable current status. Positive fork/subagent/hidden-session evidence
invalidates eligibility even if that source later disappears. New Grok captures
still require a currently verified root summary.

The cache contains only validated numeric counters, model/day metadata, safe
coverage codes and installation-keyed HMAC references/checkpoints. It contains
no raw session/message IDs, project paths, titles, account fields, prompts,
responses, thinking or tool payloads. No borrowed credential is read or stored.
Synthetic sensitive-field canaries are checked against results and stored bytes.

## Integration and qualification

CLIJIT supplies `HistoryAccess` (explicit consent, effective privacy/denial,
installation key and keyed profile reference) and the authorised root. The seam
fails closed without those inputs. Passive is supported; `MODELPLAN_READERS=off`
blocks all new history I/O. CLIJIT cancels work on revocation and uses
`ForgetHistoryProfile` to remove derived readings/checkpoints; cleanup preserves
the provider attempt floor. `ReadHistoryCache` is the cache-only --json/App path.
The legacy history entry points are unchanged; select the new incremental seam
when integrating, rather than running both. No other lane's detection, consent,
routing, provider files or publication schemas are changed here.

Availability, freshness, confidence and beta remain independent. Every result
stays beta until opted-in real-account qualification; synthetic tests cannot
clear beta. Missing/denied/unsupported/stale/partial have safe status codes and
one next step. No real sessions, accounts or credentials were used to build this.

## Schema evidence

All projections are independently written. No upstream implementation, private
fixture, collection machinery or new dependency is included.

- First-party [Kimi Wire file envelopes](https://github.com/MoonshotAI/kimi-cli/blob/9ab1286b8fe4e6bcd116949a27ce5e0ac3389c82/src/kimi_cli/wire/file.py) and [StatusUpdate](https://github.com/MoonshotAI/kimi-cli/blob/9ab1286b8fe4e6bcd116949a27ce5e0ac3389c82/src/kimi_cli/wire/types.py).
- First-party [Copilot SDK event types](https://github.com/github/copilot-sdk/blob/538675843887643ce471c874a3a9870ebda3f6f4/nodejs/src/generated/session-events.ts).
- First-party [Grok usage file](https://github.com/xai-org/grok-build/blob/2bdd1d6a6369de0e8c68132ea4539e9abd9e14a8/crates/codegen/xai-grok-shell/src/session/usage_file.rs), [summary classification](https://github.com/xai-org/grok-build/blob/2bdd1d6a6369de0e8c68132ea4539e9abd9e14a8/crates/codegen/xai-grok-shell/src/session/persistence.rs), and [sibling subagent layout](https://github.com/xai-org/grok-build/blob/2bdd1d6a6369de0e8c68132ea4539e9abd9e14a8/crates/codegen/xai-grok-shell/src/session/storage/jsonl/mod.rs).
- Existing `localusage` Qwen/Gemini projections and handwritten fixtures; first-party [Qwen aggregate/schema source](https://github.com/QwenLM/qwen-code/blob/32f6713ce6394b48dc384d301ee761fb9a1b5b80/packages/core/src/services/usageHistoryService.ts) and [Gemini recording service](https://github.com/google-gemini/gemini-cli/blob/363a13119a57354f469732577518b9d6b319d1d6/packages/core/src/services/chatRecordingService.ts).
- Third-party, explicitly reverse-engineered legacy [Amp format evidence](https://github.com/skillsynchq/txcript/blob/c60e686e7ed30e67019288eed80c4be478512d64/docs/formats/amp.md), and [Droid own/inclusive counter evidence](https://github.com/asymptote-labs/agent-beacon/blob/90b19ae0626fd6fd060c62ddbc70827a23242f4e/cli/beacon/internal/factorysession/types.go). These are compatibility evidence, not first-party supported disk-format contracts.
