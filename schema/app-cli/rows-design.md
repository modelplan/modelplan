# App rows: the CLI owns each tool's row, the app renders it (v2)

Status: design, owner-approved direction (2026-10-29). v2 folds in the GLM and MACREV design reviews on #289.
Schedule: build after beta07 ships, or at once if beta07 respin5 fails again on an app↔CLI seam.
Owners: CLI part, CLIJIT. App part, M0 (Dock, menu bar), with M4 for Settings.

## Problem

`modelplan desktop --json` hands the app several overlapping views: `accounts`, `sources`, `connections` and `subscriptions`, with consent coming separately from `consent --json`. The app rebuilds "one row per AI tool" from them, in four surfaces that each use a different set of inputs. The same facts are therefore computed several times:

- tool id canonicalisers: 4 in the app, which disagree with each other;
- title tables: 5 in the app, plus the CLI's;
- quota-state rules: 4 in the app, plus 3 in the CLI;
- reason→guidance tables: 3 in the app (the CLI's `nextStep` is never decoded);
- membership rules: 3, and the menu bar uses a different input set from the Dock.

Every beta07 respin so far failed on this merge. The CLI-as-engine boundary stays: one Go reader set serves the CLI, both plugins, the Skill and the app, it runs headless in e2e CI, and a future Windows or Linux UI reuses it. What moves is the decision about each tool's displayed row. It becomes one Go projection.

## Scope of the first release

This release adds a **display projection only**. Three things are explicitly unchanged:

- **Consent editing and Settings permission facts stay on the consent API.** That covers detection, access class, backend, Keychain choice, consent generation and text version, and pending Forget cleanup. The consent API remains authoritative for them.
- **Local presentation preferences stay in the app**: hidden rows, order, used versus remaining, and the selected window.
- **`accounts`, `connections`, history, the cockpit, plugins, the Skill and the status line keep reading what they read today.**

Rows replace only how the Dock, the menu bar and the Settings subscription list decide what to show and in which state. Settings joins rows to consent facts by tool id; it never reconstructs a permission from a row's state or reason.

## The contract

`desktop --json` stays desktop-v1 and adds optional fields: `rowsVersion: 1`, `consentGeneration`, `rows[]` and `rowsSummary`. The frozen schema, the Go conformance tests, the Swift decoder, the goldens and the journey consumers are all updated in the same PR. `connections` stays in this release.

```text
Row
  id            canonical id: a catalogue tool id (claude, codex, cursor, copilot, gemini, grok, kimi, zai, qwen,
                opencodego, kiro, amp, droid, antigravity, minimax, …) or "declared:<n>" for a plan the user declared
                in local.json. The only tool id the app sees.
  kind          tool | declared
  order         integer (the CLI's default order; app preferences may reorder)
  name          {en, zh}: the single title table (declared rows: the user's own plan name, userAuthored = true)
  vendorKey     art key or null
  surfaces      subset of [dock, menu, settings]
  consent       allowed | denied | unset | not_required | retired
  state         see "State"
  reason        {code, text {en, zh}}; code from the mapping table; text from the CLI message table
  nextStep      {action, text {en, zh}, availableAt?, disabledReason?} or null
                action: open_settings_consent | open_settings_keychain | open_tool | install_runtime | refresh | update_cli | none
                disabledReason: cooldown | read_only | offline (the app shows it and never bypasses it)
  accounts[]    see below

Account (one per subscription/profile shown under the row)
  subscriptionRef   the verified random local reference (identity.go), or null when unbound; never a hash
  plan              {id, name {en, zh}}: from the plan allow-list; an unknown harness plan becomes {id: "unknown"};
                    declared plans keep the user's text with userAuthored = true
  beta              bool
  credits           {balance, unit} or null
  valueState        current | retained | none
                    current  = the latest attempt for this profile succeeded and is within freshness
                    retained = an older value is still shown: past freshness, or a newer attempt failed
                    none     = no value (never read, empty reading, or discarded after a login/generation change)
  observedAt        RFC 3339 or null (null when unknown or in the future, so the value is never current)
  freshUntil        RFC 3339 or null; the app flips current to retained by the clock
  lastFailure       {code, at} or null (per profile; needs a per-profile attempt time in readerstate)
  windows[]
    id              stable within the account (kind + limit + pool)
    role            session | daily | weekly | monthly | other   (maps to the Dock period)
    durationSeconds integer or null
    label           {en, zh} from the message table; an unknown Codex limit becomes the generic "Other limit"
    limitId         null, or a machine id matching ^[a-z0-9_-]{1,32}$ (never shown as text)
    pool, resetMode as today
    remainingPercent 0–100 or null
    resetsAt, observedAt
    current         bool: this window's value is current (a five-hour reset does not invalidate a still-current weekly window)

rowsSummary
  state         ok | readers_off | no_consent | empty
  text          {en, zh}
  nextStep      as above
```

## Inputs: one immutable consent and admission view

The row builder, `ReadPermitted` and `connections.Diagnose` all receive the same consent/admission value, captured once per command. Today `Diagnose` reads consent a second time; that path is removed. The snapshot carries `consentGeneration`.

The app keeps a **committed floor**. After a grant, revoke or Forget is committed, the app rejects any snapshot whose `consentGeneration` is older than that generation. The current `onCanonicalInvalidated` clearing stays until this fence is in place and tested; only then is it removed.

## Membership

Candidates are the union of four sets:

1. every catalogue entry;
2. every persisted consent record (allowed or denied), including tools no longer detected and catalogue entries that have since been retired;
3. every account under an allowed or not-required consent;
4. every plan declared in local.json.

Then the rules apply in order:

1. **Readers off globally:** no rows. `rowsSummary.state = readers_off`, with its next step.
2. **Consent allowed:** the tool always gets a dock/menu/settings row, whether or not it is still detected or in the catalogue. When it is not detected, `state = needs_action`, code `tool_not_found`. When it is retired, `consent = retired`, code `catalogue_retired`. **This is the invariant the respins kept breaking.**
3. **Denied, or Forget cleanup pending:** a settings row only. Its accounts are never exported (`accounts = []`) and never shown, so a revoked tool's readings cannot reappear. `cleanup_pending` is the code.
4. **Detected but unset:** a settings row only.
5. **Declared plans:** dock/menu/settings rows with `consent = not_required`.
6. **Nothing allowed and nothing declared:** `rowsSummary.state = no_consent`, next step `open_settings_consent`.

## State: a total classifier

First each account gets a `valueState`. Then the row gets the **first** matching state:

| # | Condition | state | example codes |
|---|---|---|---|
| 1 | admission veto: privacy, catalogue off, update required, key missing, helper not admitted | off / needs_action | privacy_blocked, catalogue_off, update_required, key_missing, codexbar_not_audited, codexbar_not_read, codexbar_access_unknown, browser_session_consent_required, not_admitted |
| 2 | consent needed: unset, denied, outdated text version, consent changed mid-read | needs_consent / pending | consent_required, consent_denied, consent_outdated, consent_changed |
| 3 | no reader exists for the tool | unsupported | no_reader |
| 4 | tool missing from the machine or retired | needs_action | tool_not_found, catalogue_retired |
| 5 | the latest attempt failed and **no** account has a value | failed / needs_action | reader error codes; login_expired, runtime_missing and http_401 → needs_action |
| 6 | Claude's credential read is **actually blocked** by an unset/denied Keychain choice (no readable credentials file) and there is no current value | needs_keychain | keychain_unset, keychain_denied, keychain_canceled, keychain_not_found, keychain_unavailable, keychain_confirmation_needed |
| 7 | any shown account is `retained` | stale | stale_reading, or the account's `lastFailure.code` |
| 8 | every shown account is `current` | fresh | ok, estimated (CodexBar estimate, shown with a marker) |
| 9 | successful read with no usage windows | empty | no_usage_windows |
| 10 | allowed, no attempt yet, or the reader is busy or cooling down | pending | not_read_yet, reader_busy |
| 11 | anything else | failed | other (a safe fallback; tested separately) |

Notes:

- A recorded Keychain choice that does not block a read is not a row state. It stays a Settings fact on the consent API. A fresh Claude reading from `.credentials.json` stays `fresh`.
- Rows 1–6 come before any value-based state, so a stale value never hides a veto. Row 3 comes before row 10, so an unsupported tool never stays pending.
- A login or account-generation change sets the old account to `valueState = none`. The old numbers are dropped, not shown as stale for the new login.
- The menu bar's minimum uses only windows with `current = true` on visible rows. App preferences choose used or remaining and the hidden rows.

## Reason-code mapping

A single Go table maps every status, reason, errorCode and blocked value that the readers, the consent code and the detector emit to `(state, code, action)`. Two tests guard it:

- **Exhaustive known mappings.** The emitting sites are enumerated from the code: `sources.go`, `readerstate.go`, `quota_native.go`, `claudeaccount.go`, `keychain/security.go`, `connect.go` (Blocked), `codexbar.go`, `detect` (`unknown`, `no-safe-signal`), `consent_api.go` and `reader_errors.go`. Each must map to a code that is not `other`.
- **Safe unknown fallback.** An unmapped value maps to `other` / `failed`, with a generic text and `open_settings_consent` as the next step. `other` stays legal in production; it is the intended result for canceled or untyped reader errors.

## Privacy

- No row field carries hosts, file paths, emails, account or login names, key names, credential, profile or account hashes, or free text read from a tool's files.
- `subscriptionRef` is the existing random local reference. `MODELPLAN_IDENTITY=off` gives `null`.
- Plan names come from an allow-list. Declared plans are the user's own text from their own local.json, flagged `userAuthored`.
- Tests use a field-specific validator per field (ids, timestamps, refs, `limitId` charset, message-table texts), plus canaries: raw emails, paths, hashes and provider error text are seeded into the fixtures and must never appear in a row.

## App side

- Generated Swift types for Row, Account, Window and RowsSummary, and for every enum. A Go generator in `cli/internal/appcontract` emits them from the same structs. Unknown enum values decode as `.unknown(String)` and render as a neutral card with the reason text.
- **Dock:** one card per row whose `surfaces` contains dock, in app order. Accounts with windows become the card's instruments. Age is formatted from `observedAt` (minutes, hours, days). The card states and next-step actions come from the row, and so do the `disabledReason` labels.
- **Menu bar:** the same rows and the same preferences as the Dock.
- **Settings subscriptions list:** the rows, joined by tool id to the consent API facts for the controls.
- **Preferences:** per-subscription choices (hidden, order, window) stay keyed by `subscriptionRef`. Row-level choices are keyed by row id. A one-time migration maps the old keys. Cockpit and history cross-navigation keeps joining on `subscriptionRef`.
- **Deleted only after the regression gates below pass:** `CommunityUnboundDockRows`, the row and category logic in `CommunityReaderReason`, the Dock's use of the `Projection` stale rule, the app canonicalisers and the title and guidance tables. `onCanonicalInvalidated` clearing goes once the generation fence is tested.

## Captures and tests

- **Seed catalogue:** all 13 fallback tools, plus antigravity and minimax.
- **Generated states:**
  - fresh
  - pending
  - first read failed: a grok `parse_error` with no account and no connection
  - success followed by a failed refresh: the account is retained and `lastFailure` is set
  - login expired
  - runtime missing
  - Keychain:
    - unset, blocking the read
    - unset with a readable credentials file (stays fresh)
    - denied
    - confirmation needed
  - consent:
    - consent off
    - nothing consented
    - consent outdated
    - consent changed during collection
    - revoke during collection
    - a delayed pre-revoke snapshot rejected by the floor
    - cleanup pending
  - allowed tool:
    - no longer detected
    - retired from the catalogue
  - accounts:
    - two Codex accounts, one current and one retained
    - a login change that discards the old account
  - windows and readings:
    - mixed window lifetimes: the 5-hour window reset while the weekly window is still current
    - duplicate kinds/pools
    - a future `observedAt`
    - an empty reading
  - other:
    - a tool with no reader (amp)
    - a declared local.json plan
    - CodexBar estimated
    - cooldown/offline refresh
- **Go tests:**
  - the classifier's table tests, including the overlapping conditions
  - the mapping tests: exhaustive known values, plus the separate unknown fallback
  - the membership invariant: every allowed tool has exactly one Dock row in every state
  - the privacy validators and canaries
  - `quota --json` stays byte-identical across the change (plugin and Skill gate)
- **Swift tests** render the Dock, the menu bar and Settings from every capture:
  - the card count equals the number of Dock rows
  - every non-fresh card has a reason and a next step
  - every card with a value shows its age
  - the menu minimum uses only current windows
- **e2e (#281):** extended with membership, revoke and mixed-account journeys.
- **CI path filters:** `.github/workflows/desktop.yml` also triggers on `cli/internal/quota`, `cli/internal/connections`, `cli/internal/consent`, `cli/internal/detect` and `cli/cmd/modelplan`, so a change to the projection always runs the Swift, capture and app-smoke checks.

## Rollout

1. **CLI vX (CLIJIT):**
   - add the per-profile attempt and failure time to readerstate
   - build the single consent/admission input and give it to Diagnose
   - add the rows projection, the mapping table, the captures, the schema update and the Swift generator
   - widen the CI paths
   - release and pin
2. **App (M0 for the Dock and menu bar, M4 for Settings), one PR per surface:**
   - switch the surface to rows behind the regression gates
   - add the generation fence
   - migrate the preferences
3. **Then:**
   - delete the merge code
   - remove the invalidation clearing
4. **Later, in its own contract version (desktop-v2):** remove or shrink `connections` in `desktop --json`.

No compatibility is kept with released app builds before the official release (owner rule). The schema and conformance obligations above still apply.

**Estimate:**
- CLI: about 1.5 days (the per-profile failure time and the single consent input add to v1).
- App: 1–2 days.
- Then captures and e2e.

## Grill-me: questions and answers

1. **Can an allowed tool lose its row?** No. Persisted grants are candidates even when undetected or retired (membership rule 2). An invariant test covers every state.
2. **Can a revoked tool's readings reappear?** No. A denied tool or one with pending cleanup exports no accounts. The app also rejects snapshots older than the committed floor.
3. **Success, then a failed refresh 5 minutes later?** The account becomes `retained` with `lastFailure`, so the row is `stale` (#7). It is not shown as fresh.
4. **Two accounts, one current and one retained?** The row is `stale`. Each account carries its own `valueState`, and the menu minimum skips the retained account's windows.
5. **Keychain unset but a credentials file works?** The row stays `fresh`. `needs_keychain` appears only when the read is actually blocked (#6).
6. **Unsupported tool?** `unsupported` (#3), before the pending check, so it is never pending forever.
7. **Empty reading, or a null or future time?** `empty` (#9). A null time is never current, and the age shows as unknown.
8. **Unknown Codex limit or plan?** A generic label and plan `unknown`. The raw text is never exported; `limitId` exists only when it is charset-safe.
9. **Settings needs Keychain, Forget and generation facts?** Those stay on the consent API, joined by id. Rows never encode permissions.
10. **Preferences keyed by subscription?** They stay keyed by `subscriptionRef`. Only row-level choices move to the row id, with a migration.
11. **Does a newer CLI break an older app?** No. Unknown enum values render neutrally, and the fields are additive under desktop-v1.
12. **A refresh action during cooldown or offline?** The action carries `disabledReason` and `availableAt`. The app shows them and never bypasses them.
13. **Does a projection change escape CI?** No. The workflow paths are widened.
14. **What can still be wrong?** The classifier order and the mapping table. Each is one Go function with table tests, captures and e2e, so any fix happens in one place.
15. **Does this delay beta07?** Only through the owner's trigger: if respin5 fails on the seam again, beta07 moves to rows, about 2–3 days later.
