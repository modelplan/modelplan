# Passive Claude Code session state (beta)

The native session collector reads Claude Code's own `projects/**/*.jsonl` under
the locally admitted `~/.claude` or `CLAUDE_CONFIG_DIR` root. It needs neither a
plugin nor a status line. It never opens credentials, contacts a provider, launches
Claude, changes its settings or uses inference.

The owner confirmed these fields with a sanitised probe on 2026-10-27:

| Session field | ModelPlan field |
| --- | --- |
| `message.model` | `harness.model` |
| Top-level `effort` | `harness.effort` |
| `message.usage.speed` (`standard` / `fast`) | `harness.fastMode` (`false` / `true`) |

All three are optional for older records. Missing or unknown values stay unknown;
the reader does not inherit an older turn's values or infer speed from
`service_tier`. It ignores `inference_geo`, `iterations`, message content, cwd and
project labels. The committed owner-confirmed fixture contains exactly the
confirmed fields; other fixtures add invented transcript envelopes for testing.
No real transcripts were accessed for development or tests.

Each source keeps its newest assistant record. Sidechain, metadata and compact
summary records, `subagents` directories and `agent-*.jsonl` are excluded. Selection
uses record timestamps, falling back to file modification time for older records
without a timestamp. The most recent main session is marked **recent-thread**;
an explicitly named cached session is **current-thread**. These labels describe
the transcript source; they do not assert which OAuth account owns the session.
With multiple quota accounts the session remains a separate unbound local entry.

The ModelPlan cache stores only model/effort/fast, capture time, keyed session and
source identities, and the minimal file-identity/offset checkpoint needed to read
appends. It contains no raw session IDs, content, paths or project names. Project
labels are not collected even when the optional label preference permits them.
The installation's existing identity key supplies domain-separated HMACs; raw
device/inode identifiers are also hashed before persistence.

Reads after the first use the committed byte offset, including after a process
restart. Truncation or replacement resets the cursor and uses a bounded tail.
An incomplete final row waits for its newline. Initial/recovery reads inspect at
most 256 KiB per file, 128 files and 4,096 directory entries; larger or partial
views are reported as **partial**. Directory discovery inspects names/metadata,
never performs a full transcript-content rescan, and never follows symlinks.
The collector currently requires Unix device/inode metadata (macOS/Linux).

CLIJIT calls `RefreshClaudeSessions` with a trusted `ClaudeSessionAccess` after
shared consent. A missing grant or `MODELPLAN_READERS=off` blocks collection;
Passive-only permits it. A consent-generation callback discards in-flight results
after revocation. Ordinary `quota.Read`, including JSON rendering, reads only
ModelPlan's sanitized session cache and never starts collection. A passive cached
session replaces optional status-line harness fields, including with unknown
values; the plugin/status line cannot override it. CLIJIT owns collector scheduling
and consent wiring. No files in `cli/internal/speed` are changed.

Tests cover the confirmed/older shapes, optional unknowns, newest/main/current
selection, append-only offsets across collector calls, poisoned old spans that
must not be rescanned, inode replacement, truncation, incomplete rows, bounded
tail recovery, cached reads after transcript removal and absence of private data.
