# Codex and Claude Code response accounting

Reference: ccusage@58866ba681343634ab6e5add61f18f3b70aa98f7,
`rust/adapters/codex/src/{parser,aggregate,types}.rs`,
`rust/adapters/claude/src/lib.rs`, `rust/crates/ccusage-core/src/types` (MIT).
This is a MATCH implementation in Go, sharing `tokenacct.Buckets/Windows` with
family 2 (#1017). The shared buckets source is identical to #1017@7007ed05.
The ccusage licence and the single notice identity cover the accounting paths.

Usage and speed have separate inputs. The response accountant reads usage even
when no turn has finished. Existing eligible-output / generation-time samples
remain the basis of t/s. Today and the recent 7/30 local calendar days expose
`totalTokens`; `observedOutputTokens` / `outputTokens` retain their output meaning.
Codex's reported output includes reasoning. Shared disjoint buckets therefore
subtract reasoning from ordinary output and put it in `reasoningTokens`; total
counts each token once. Legacy output fields include reasoning for compatibility.
Cache writes are also subtracted from inclusive Codex prompt input.

Deduplication covers cumulative notices, response/notice pairs, remote compaction
response identities, copied logs, fork prefixes/rewritten bursts, Claude streaming
updates and sidechain copies. An occurrence ordinal preserves distinct identical
Codex records in one file. Live snapshots replace a changed file's prior live contribution. Imports replace
only their requested per-file intervals, preserving earlier valid intervals and
independently owned live records. Records seen by both paths are counted once.
Accounting replaces the timing ledger's usage only inside proven coverage: live
usage from the first local day on which no older timing row of that source and
consent epoch existed when accounting began (`liveFrom`), imported usage on the
days an accounting import recorded. Earlier days keep their timing usage, so an
upgrade never erases sessions that were not re-read. Imports account Codex
background threads as the live observer does; their turns stay out of timing.
Fork prefixes are matched on ordinary usage only: compaction responses neither
consume nor end the prefix and are deduplicated by response identity (ccusage
`CodexReplayFilter`). Session totals subtract Codex cache writes from inclusive
input, bounded by the uncached input (ccusage `normalize_codex_raw_usage`).

The private compressed cache contains token counts, timestamps, model names,
consent epochs and hashed identities. It contains no transcript text or raw IDs or
paths. It retains 35 local days. A live observer fills its first local day; older
days use the existing history import under its consent fence. Imported accounting
remains removable, including import-only records on the live ledger's first day.
Ownership comes from the observing path, not a calendar-day guess; import metadata
does not suppress a later live scan. Unproven pre-release cache ownership fails
closed on import removal. A version marker makes existing admitted imports eligible for
one re-read, preserving their earlier coverage. Clear/revoke boundaries apply to
both paths. No provider request or new dependency is needed.

The personal CLI snapshot exposes the shared `tokenAccounting` windows per source;
account rows and cockpit details expose optional `observedTotalTokens`. The native
and web today number prefer it, with older-engine output fallback. No layout or
copy changes are needed: the today label is generic, and explicitly labelled
output rows remain output-only. Historical session/project rankings and speed
configuration samples remain explicitly output-based.

## Validation

Pinned `npx ccusage@20.0.51` was run on both synthetic fixtures, not hand-computed
alone. `TestAccountingUnfinishedResponsesNotSpeedSamples` fails against the old
observer (no usage for the unfinished turn), then passes with response accounting.

Read-only real-log comparison: **2026-11-15**, **America/Los_Angeles**, a completed
local day. Only aggregates were exported; no logs were added to the repository.

| Tool / bucket | ModelPlan | ccusage | Difference |
| --- | ---: | ---: | ---: |
| Codex uncached input | 20,063,348 | 20,063,348 | 0.00% |
| Codex cache read | 440,342,656 | 440,342,656 | 0.00% |
| Codex cache write | 0 | 0 | 0 tokens |
| Codex output including reasoning | 974,820 | 974,820 | 0.00% |
| Codex reasoning (output subset) | 239,872 | 239,872 | 0.00% |
| Codex total | 461,380,824 | 461,380,824 | 0.00% |
| Claude uncached input | 3,585 | 3,585 | 0.00% |
| Claude cache read | 565,980,236 | 565,980,236 | 0.00% |
| Claude cache write | 17,335,129 | 17,335,129 | 0.00% |
| Claude output | 924,041 | 924,041 | 0.00% |
| Claude total | 584,242,991 | 584,242,991 | 0.00% |

Reproduce with the opt-in read-only Go test:

```sh
cd cli
MODELPLAN_ACCOUNTING_VALIDATE_ROOT="$HOME/.codex/sessions" \
MODELPLAN_ACCOUNTING_VALIDATE_DAY=2026-11-15 \
MODELPLAN_ACCOUNTING_VALIDATE_ZONE=America/Los_Angeles \
go test ./internal/speed -run '^TestAccountingReferenceLocalLogs$' -v -count=1
```

For Claude set root to `$HOME/.claude/projects` and source to
`MODELPLAN_ACCOUNTING_VALIDATE_SOURCE=claude-code`. Compare against
`npx --yes ccusage@20.0.51 codex daily --json --offline --since 2026-11-15
--until 2026-11-15 --timezone America/Los_Angeles` (replace `codex` with `claude`).
Pricing is not added by this token-count change; no D127 cost-parity claim is made.
Other tool families and the GLM account 30-day view follow the coordinator's
separate family plan; quota/reset readers are unchanged.
