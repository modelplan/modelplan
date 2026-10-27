# Claude Code account reader (beta)

The native reader uses Claude Code's saved OAuth login for read-only account quota.
It needs no ModelPlan status line or plugin. It never refreshes, rewrites, moves or
copies Claude credentials, runs Claude, reads browser data or calls inference.
Expired or rejected credentials give one next step: **Open Claude Code to refresh**.

CLIJIT supplies `quota.Paths.ReaderAccess` from its shared consent record; a missing
grant permits no tool-file, Keychain or network access. Legacy connection settings
alone do not grant access. The consent line is: “Read Claude Code's saved login to
show usage. The credential is sent to Anthropic to authenticate. macOS may ask
you to allow Keychain access.” `MODELPLAN_READERS=passive|off` suspends collection.
The App's configured system proxy belongs on the injected HTTP client; the reader
preserves that transport and refuses redirects. CLIJIT owns command/consent wiring.

## Local sources and identity

An admitted profile uses `~/.claude/.credentials.json`, or
`$CLAUDE_CONFIG_DIR/.credentials.json`. Only the `claudeAiOauth` access token,
expiry, scopes and plan type are consumed; no refresh operation exists. API keys,
auth helpers, cloud logins and alternate API hosts are unavailable without a
request. A malformed/expired file never falls back to another account's Keychain
item. Multiple locally admitted profiles are visited in rotation, sharing one
provider-wide budget. Custom-directory Keychain derivation is unsupported.

If the default profile has no credential file, a separate Keychain grant permits
`/usr/bin/security find-generic-password -s Claude Code-credentials -w`. The item
name is fixed. Background reads require a prior grant and run with a **two-second
deadline**. A timeout kills and reaps the process, records
`keychain-confirmation-needed`, and suspends background Keychain calls. Deny records
`denied` and also suspends them. Both states persist across processes and retain
the last good reading and capture age. Their sole next step is **Allow in Settings**.
Only an explicit Settings/App refresh or CLI action can request an interactive
read with a longer deadline; success clears the blocked state. A timer, resume or
JSON read can never make an interactive request. Deny is never retried automatically.
Only safe state strings are persisted; stdout and stderr are never logged.

Profile account/org IDs and credential generations are stored only as
domain-separated keyed hashes using ModelPlan's existing installation identity key.
Public readings carry an opaque subscription reference. The raw account/org IDs
are not stored. Stable identity metadata lives for at most 24 hours and is bound
to the credential. A changed credential invalidates that binding before use.

## Requests and quota shapes

The compiled host is `https://api.anthropic.com`. Bearer requests use the beta
header `oauth-2025-04-20`; the undocumented OAuth contract is sourced from
[CodexBar 0.81.0](https://github.com/steipete/CodexBar/tree/0.81.0/Sources/CodexBarCore/Providers/Claude)
(MIT; ee890b5f392e70d6e20162d3e95cf9f1be265b60). This is an independent implementation.

One provider read has **at most two requests**. A cold read uses
`/api/oauth/profile` plus `/api/oauth/usage`. With valid cached profile metadata,
usage uses one slot. V1 makes no prepaid or organisation-enumeration request.
Usage windows always come from one usage response.

`five_hour` maps to `five_hour`; `seven_day` and model-specific Opus/Sonnet windows
map to `weekly`, with labels for model-specific limits. OAuth apps and Cowork have
separate weekly labels. Extra usage maps to a spend window with USD amounts in
major units (the source amounts are cents); there is no guessed reset timestamp.
No MCP/request quota is invented when the response provides none. Plans explicitly
returning null windows remain valid readings without invented allowances.

**TODO (later, not v1):** prepaid credits are omitted by the owner's decision on
2026-10-27. No sanitised response exists for
`/api/oauth/organizations/{org}/prepaid/credits`, and development must not call it
with real credentials. Add a mapping only after a sanitised fixture establishes
the OAuth response fields and units. CodexBar's web shape is insufficient. V1
exposes only evidenced usage windows and extra-usage spend/limit, with no guessed
wallet or zero balance.

## Cache, cadence and verification

A cross-process provider reservation enforces a five-minute floor across all
profiles and callers. Unchanged readings adapt to 10/15/30 minutes; failures back
off to 10/20/40/60 minutes and honor a longer Retry-After. Native readers share the
existing serialization lock. Failures preserve the last good account and its
capture time, except that a changed credential cannot inherit an unverified old
identity. Cache projections drop windows whose reset has passed. Duplicate
profiles with a verified common subscription reference show the newest reading.
The cache projection performs no tool-file reads, HTTP, subprocess or refresh.

Tests use synthetic credential files and an `httptest` server only. Keychain tests
inject fast success, a child process killed on deadline and Deny exit codes;
none accesses the real Keychain. Session-state extraction is a separate PR in
`cli/internal/quota/claudesession*`; this reader does not edit `cli/internal/speed`.
