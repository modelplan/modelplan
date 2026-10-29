# App rows: the CLI owns each tool's row, the app renders it

Status: design, owner-approved direction (2026-10-29). Build after beta07 ships, or at once if beta07 respin5 fails again on an app↔CLI seam.
Owners: CLI part, CLIJIT. App part, M0 (Dock, menu bar), with M4 for Settings.

## Problem

`modelplan desktop --json` hands the app several overlapping views: `accounts`, `sources`, `connections`, `subscriptions`. Consent arrives separately through `consent --json`. From these the app rebuilds "one row per AI tool", in four surfaces with four different input sets. The same fact is computed in several places:

| Fact | CLI | App |
|---|---|---|
| Canonical tool id | catalogue ids | 4 canonicalisers that disagree (openai, zcode, opencode) |
| Display name | detect `displayName` | 5 more title tables |
| Quota state | `quotaLevel`, `nativeClaudeConnection`, `doctor readers` | Projection stale rule, UnboundDockRows guidance, CommunityReaderReason, DockSnapshot `dataState` |
| Reason → next step | `nextStep` fields (never decoded by the app) | 3 string tables |
| Row membership | accounts, managed sources (only after a first attempt), the fixed Diagnose list | refs, unbound accounts, consent ∩ connections, a Claude special case; the menu bar uses another set |
| Observation age | account/window `observedAt`, connection `at` (only when `yes`) | falls back to `connections.quota.at`; sources carry no time |

Every beta07 respin failed on this merge: tools with no row after their first read failed, lost ages, unmapped reason codes, missing names. The app's stale rule matches `out-of-use`, which the CLI never emits. The app's guidance switch matches `reader_error`, `not_detected` and `error`, which the CLI never emits as these values.

The CLI-as-engine boundary stays. One Go reader set serves the CLI, both plugins, the Skill and the app; it runs headless in e2e CI; a future Windows or Linux UI reuses it unchanged. What changes is who decides each tool's row: the CLI, in one place.

## The contract: `rows` in the desktop snapshot

`desktop --json` gains `rowsVersion: 1`, `rows[]` and `rowsSummary`. Everything comes from the same generation as the rest of the snapshot, so no second call is needed and nothing can race.

```text
Row
  id            canonical tool id from the catalogue (claude, codex, cursor, copilot, gemini, grok, kimi, zai, qwen, opencodego, kiro, amp, droid, antigravity, minimax, …). The only id the app sees.
  order         integer; the CLI sorts
  name          {en, zh}; the single title table
  vendorKey     art key ("openai", "claude", …) or null
  surfaces      subset of [dock, menu, settings]; which surfaces show this row
  consent       allowed | denied | unset | not_offered
  state         fresh | stale | pending | needs_consent | needs_keychain | needs_action | failed | unsupported | off
  reason        {code, text {en, zh}}; code from the closed set below; text is CLI-authored, never copied from a tool's files
  nextStep      {action, text {en, zh}} or null
                action: open_settings_consent | open_settings_keychain | open_tool | install_runtime | refresh | update_cli | none
  observedAt    RFC 3339 or null (null when unknown, missing or in the future)
  freshUntil    RFC 3339 or null; after this the app shows the row as stale without re-deriving anything
  accounts[]    accountRef (opaque, stable), plan, subscriptionRef or null, observedAt, freshUntil,
                windows[] {kind, label {en, zh}, remainingPercent 0–100 or null, resetsAt or null}
  lastFailure   {code, at} or null; kept when a later read fails but an older reading is still shown

rowsSummary
  state         ok | readers_off | no_consent | empty
  text          {en, zh}
  nextStep      as above
```

Closed reason codes: `ok`, `not_read_yet`, `stale_reading`, `login_expired`, `runtime_missing`, `key_missing`, `region_changed`, `keychain_unset`, `keychain_denied`, `consent_required`, `consent_denied`, `privacy_blocked`, `not_admitted`, `no_reader`, `catalogue_off`, `update_required`, `no_usage_windows`, `reader_busy`, plus the reader error codes already in `reader_errors.go`: `file_missing`, `file_unreadable`, `parse_error`, `schema_changed`, `http_401`, `http_403`, `http_429`, `http_5xx`, `network`, `timeout`, `unsupported_login`, `other`.

### Membership: which tools get a row (one Go function)

1. Readers off globally: no rows; `rowsSummary.state = readers_off` with its next step.
2. Every tool in the catalogue that is detected or has an account gets a row. `surfaces` decides where it shows.
3. Dock and menu bar show a row when its consent is `allowed`, or when it has an account or a verified subscription binding. A consented tool always has a Dock row, whatever its reader did. This is the invariant that respin1–4 kept breaking.
4. Settings shows every detected tool, consented or not.
5. Nothing consented: `rowsSummary.state = no_consent`, next step `open_settings_consent`.

### State: one precedence table (one Go function, table-tested)

| Precedence | Condition | state | reason.code |
|---|---|---|---|
| 1 | consent not allowed (Dock rows only reach here through an account) | needs_consent | consent_required / consent_denied |
| 2 | Claude Keychain choice unset or denied (darwin only) | needs_keychain | keychain_unset / keychain_denied |
| 3 | admission blocked: privacy, catalogue, update, no key | off or needs_action | privacy_blocked / catalogue_off / update_required / key_missing |
| 4 | a reading inside its freshness window | fresh | ok |
| 5 | a reading past freshness, or the reader failed after a success | stale | stale_reading; `lastFailure` keeps the error code |
| 6 | the reader failed and there is no reading | failed, or needs_action when a step fixes it (login_expired, runtime_missing, http_401) | the error code |
| 7 | consented, no attempt yet or the reader is busy | pending | not_read_yet / reader_busy |
| 8 | no reader exists for this tool | unsupported | no_reader |

Freshness thresholds stay where they are now (per reader, in Go). The CLI writes them out as `freshUntil`, so the app only compares against the clock.

### Privacy

A row never carries hosts, file paths, emails, account names, key names or free text read from a tool's files. `accountRef` is an opaque hash, stable per account on this machine. `plan` comes from the catalogue's plan names only. A test fails when any row string is not from the CLI's message table.

## App side

- New generated Swift types for `Row`, `RowsSummary` and every enum, emitted by a Go generator in `cli/internal/appcontract` from the same Go structs that produce the JSON. Enums decode an unknown value as `.unknown(String)`, so an older app never crashes on a newer CLI.
- Dock: one card per row where `surfaces` contains `dock`. Name, state, reason, next step and values are taken from the row as they are. The age text is formatted from `observedAt` and now (minutes, hours, days). Fresh flips to stale by the clock against `freshUntil`.
- Menu bar: the same rows, with the same Dock preferences applied (hidden rows, used versus remaining). The lowest remaining value across the visible fresh rows' windows.
- Settings: the subscriptions and connections lists come from the rows. Consent editing keeps the consent API, but it now decodes `displayName`, `notice` and `nextStep` from it.
- Next-step actions map to fixed app destinations (Settings sections, opening a tool, the CLI update flow).
- Deleted: `CommunityUnboundDockRows`, the row and category logic in `CommunityReaderReason`, the Dock use of the `Projection` stale rule, the four canonicalisers, the five title tables, the guidance string tables, and the `onCanonicalInvalidated` clearing of Dock consent (the rows already carry consent).

## Generated captures and tests

- Extend the `appcontract` seed catalogue to all 13 fallback tools, plus antigravity and minimax, and the generator to these states:
  - fresh
  - pending before the first read
  - first read failed (grok `parse_error`)
  - login expired
  - runtime missing
  - Keychain unset, Keychain denied
  - stale with a last failure
  - consent off
  - nothing consented
  - two Codex accounts
  - a future `observedAt`
  - a tool with no reader (amp)
- Go tests:
  - every internal status/reason/errorCode the readers emit maps to a closed code; any capture that contains `other` fails
  - the membership invariant: every allowed tool has a Dock row in every state
  - privacy: row strings come only from the message table
- Swift tests render the Dock, the menu bar and Settings from each capture and assert:
  - the card count equals the Dock rows
  - no bare "?"
  - every non-fresh card shows a reason and a next step
  - every card with a reading shows its age
- The e2e journey (#281) asserts the same invariants with the real binaries.

## Rollout

1. CLI vX (CLIJIT): add `rows` next to the existing fields; captures, schema and the Swift type generator; release; pin.
2. App (M0, M4): switch Dock, menu bar and Settings to rows; delete the merge code; one PR per surface, each running against the generated captures.
3. Next CLI: drop `connections` from `desktop --json` (only the app's merge reads it there). `accounts` stays for the cockpit and history views. `quota --json`, which the plugins and the Skill read, is untouched.

There is no compatibility with released app builds before the official release (owner rule). Plugins, the Skill and the status line are unaffected: they read `quota --json` or render inside the CLI.

Estimate: CLI about 1 day, app 1–2 days, then capture and e2e updates.

## Grill-me: questions asked and answers

1. **Does every consented tool get a row in every state?** Yes. Membership rule 3, a Go invariant test over every generated state, and the Swift card-count test.
2. **What about a tool with no reader (amp, droid)?** It gets a row with `unsupported` / `no_reader` and next step `none`. It is never hidden, and never `pending` forever.
3. **Several profiles or accounts for one tool?** One row, several `accounts[]`. Row state is the best account's state (fresh beats stale beats failed). The menu bar takes the lowest window across the fresh accounts.
4. **Old reading plus a new failure?** `stale` with `lastFailure`. The old value shows with its age, and the failure shows as the reason.
5. **The snapshot ages while the app holds it?** `freshUntil` per row and account; the app flips by clock. The snapshot's `validUntil` still triggers a refresh.
6. **A future or missing `observedAt`?** The CLI nulls it. The app shows "observation time unknown" and never treats the reading as fresh.
7. **Keychain on other platforms?** `needs_keychain` is emitted only on darwin. The other states and actions are platform-neutral, so a Windows or Linux UI renders the same rows.
8. **Language?** Both languages ship in each text. The app picks by its own setting, so no CLI flag is needed.
9. **Consent changes while a read is running?** The next snapshot reflects it, because consent is read inside the same generation. The Dock no longer clears consent first, so nothing flickers.
10. **Subscription binding?** `subscriptionRef` per account; Settings groups by it. Binding verification stays in Go (`quota.Binding`).
11. **An unknown new state from a newer CLI?** `.unknown(String)` renders as a neutral card with the reason text and the next step. No crash, no hidden row.
12. **Speed, sessions and history panels?** Unchanged; they keep reading their own snapshot fields.
13. **Could the CLI leak something new?** Rows only use message-table strings and catalogue plan names; the test enforces it. `accountRef` is a local hash, not an identifier from the vendor.
14. **Where can it still go wrong?** In the precedence table and the status→code map. Both are single Go functions with table tests and generated captures, and the e2e job runs them with the real binaries. A bug there is one fix in one place.
15. **Does this delay beta07?** Not unless respin5 fails on the seam again (owner's trigger). In that case beta07 ships on rows, about 2–3 days later.
