# App rows: the CLI owns each tool's row, the app renders it (v4)

Status: design approved for build (MACREV R4 SOUND; GLM R4 issue folded in). Owner-approved direction (2026-10-29). v4 folds in four rounds of GLM and MACREV design review on #289.
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
                opencodego, kiro, amp, droid, antigravity, minimax, …) or "declared:<planId>" (percent-encoded) for a plan the user
                declared in local.json. planId is the user's own stable key, so inserting or reordering plans never moves
                preferences, and no locator has to be allocated. The only tool id the app sees.
  kind          tool | declared
  order         integer (the CLI's default order; app preferences may reorder)
  name          {en, zh}: the single title table (declared rows: the user's planId text as both, userAuthored = true)
  vendorKey     art key or null
  surfaces      subset of [dock, menu, settings]
  consent       allowed | implicit | denied | unset | not_required | retired
                implicit = no consent record, but the privacy mode (Automatic by default, consent.go:76) already permits
                this local read (Claude status line, Codex logs; connect.go:245, :306); treated exactly like allowed
  state         see "State"
  reason        {code, text {en, zh}}; code from the mapping table; text from the CLI message table
  nextStep      {action, text {en, zh}, availableAt?, disabledReason?} or null
                action: open_settings_consent | open_settings_keychain | open_tool | install_runtime | refresh | update_cli | none
                disabledReason: cooldown | read_only | offline (the app shows it and never bypasses it)
  accounts[]    see below
  expiresAt         RFC 3339 or null: the earliest validUntil of any current account or window in this row
  stateAfterExpiry  {state, reason, nextStep}: a conservative latch the CLI precomputes as if every value in the row
                    were retained (normally stale / stale_reading), or null

Account (one per subscription/profile shown under the row)
  subscriptionRef   the verified random local reference (identity.go), or null when unbound; never a hash
  accountLocator    an existing identity reference for the profile (identity.go), or null; read-only commands never
                    allocate one (allocation happens only in an authorised collection, exactly like subscription refs);
                    never positional, never a hash. Per-account preferences use subscriptionRef, else accountLocator,
                    else fall back to the row's preferences until a reference exists
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
    id              unique within the account: role + durationSeconds + limitKey + poolKey; if two windows still
                    collide, the CLI appends an ordinal ordered by resetsAt; provider text never appears
    role            session | daily | weekly | monthly | other   (maps to the Dock period)
    durationSeconds integer or null
    label           {en, zh} from the message table; an unknown Codex limit becomes the generic "Other limit"
    limitKey        allow-listed key, or "other" for any unknown limit (never provider text; nothing is persisted)
    poolKey         allow-listed key, or "other" (never provider text); resetMode as today
    remainingPercent 0–100 or null
    resetsAt, observedAt
    current         bool at generation time
    validUntil      RFC 3339 or null: min(account freshUntil, this window's resetsAt). The snapshot's validUntil is
                    not part of it: that only schedules the next refresh. After validUntil this window is not current;
                    a five-hour reset does not touch a weekly window whose validUntil is later

Not in rows v1: reset `cards` (local.json reset reminders). They stay on `accounts[]`, which this release keeps; no Dock surface renders them today. They move into rows only when a surface needs them.

rowsSummary
  state         ok | readers_off | no_consent | empty | pending
                pending = the publication check failed closed; declared rows still show
  reason        {code, text {en, zh}} (codes: ok, readers_off, no_consent, no_dock_rows, consent_changed)
                empty = something is allowed or declared, but no row has a Dock surface with a value or a next step (for example every allowed tool is unsupported); text says so and nextStep opens Settings
  text          {en, zh}
  nextStep      as above
```

## Clock: one effective-current rule

The app applies exactly two rules and never re-runs the classifier:

1. **Window values.** A window is current while `current` is true and now < `validUntil`. The menu minimum uses only such windows, so one window's reset never hides another window.
2. **Row latch.** When now ≥ `row.expiresAt`, the row shows `stateAfterExpiry` and stays latched until a new snapshot replaces it. That state is never fresh. There is one transition only, so a held snapshot that crosses several deadlines cannot pass through intermediate states, and delayed or failed refreshes leave it latched and honest.

Refresh scheduling stays on the snapshot's `validUntil`. Tests walk a held snapshot through multiple deadlines while replacement refreshes are delayed or unavailable.

## Inputs: one immutable consent and admission view

The row builder, `ReadPermitted` and `connections.Diagnose` all receive the same consent/admission value, captured once per command. Today `Diagnose` reads consent a second time; that path is removed. The snapshot carries `consentGeneration`.

**Publication check:** after the whole snapshot (rows included) is built, the CLI re-reads `CurrentGeneration`. This extends today's `ReadPermitted` check (`connect.go:321`) to the full build.
- If the generation changed, the result is discarded and the build retried once with the new consent.
- If it changes again, the CLI fails closed. It emits no tool accounts and no tool rows, and keeps the declared rows, which read nothing. `rowsSummary.state` is `pending`, with code `consent_changed` and the new generation.
- A discarded result is never printed.

The app keeps a **committed floor**. After a grant, revoke or Forget is committed, the app rejects any snapshot whose `consentGeneration` is older than that generation. The current `onCanonicalInvalidated` clearing stays until this fence is in place and tested; only then is it removed.

## Membership

Candidates are the union of four sets:

1. every catalogue entry;
2. every persisted consent record (allowed or denied), including tools no longer detected and catalogue entries that have since been retired;
3. every account under an allowed, implicit or not-required consent;
4. every planId that appears anywhere in local.json (`plans[]`, `windows[]` or `resetCards[]`), as today's `acct()` does.

Then the rules apply in order:

1. **Readers off globally:** no tool rows. `rowsSummary.state = readers_off`, with its next step. Declared rows still show: they are the user's own data and read nothing.
2. **Consent allowed or implicit:** the tool always gets a dock/menu/settings row, whether or not it is still detected or in the catalogue. When it is not detected, `state = needs_action`, code `tool_not_found`. When it is retired, `consent = retired`, code `catalogue_retired`. **This is the invariant the respins kept breaking.**
3. **Denied, or Forget cleanup pending:** a settings row only. Its accounts are never exported (`accounts = []`) and never shown, so a revoked tool's readings cannot reappear. `cleanup_pending` is the code.
4. **Detected but unset:** a settings row only.
5. **Declared plans:** dock/menu/settings rows with `consent = not_required`. They skip the tool predicates (detection, reader, consent, Keychain): only rows 1 (privacy veto), 8–10 below apply. A declared plan without a manual reading is `pending`, code `no_manual_reading`, action `none`.
6. **Nothing allowed and nothing declared:** `rowsSummary.state = no_consent`, next step `open_settings_consent`.

## State: a total classifier

**Account `valueState`** (per profile):
- `current`: the latest attempt for this profile succeeded, `observedAt` is known and not in the future, and the value is within freshness.
- `retained`: a value is shown, but it is past freshness, or a newer attempt failed (`lastFailure` is set), or its `observedAt` is null or in the future. In the last case the code is `observation_time_unknown`.
- `none`: there is no value. Either the profile was never read, the reading was empty, or the value was discarded after a login or generation change.

**Row state**: the first row of this table that matches. Let C, R and N be the row's current, retained and none accounts.

| # | Condition | state | codes (normative list below) |
|---|---|---|---|
| 1 | admission veto | off / needs_action | privacy_blocked, catalogue_off, update_required, key_missing, codexbar_not_audited, codexbar_not_read, codexbar_access_unknown, browser_session_consent_required, not_admitted |
| 2 | consent: unset (and not implicit), denied, outdated, or changed mid-read | needs_consent / pending | consent_required, consent_denied, consent_outdated, consent_changed |
| 3 | tool missing from the machine, or retired | needs_action | tool_not_found, catalogue_retired |
| 4 | no reader exists for the tool | unsupported | no_reader |
| 5 | the credential read is **actually blocked** by the credential store (Keychain unset/denied/canceled/not found/unavailable/confirmation needed, and no readable credentials file), and C is empty | needs_keychain | keychain_unset, keychain_denied, keychain_canceled, keychain_not_found, keychain_unavailable, keychain_confirmation_needed |
| 6 | C and R both empty, and the latest attempt failed | failed / needs_action | reader error codes; login_expired, runtime_missing and http_401 give needs_action |
| 7 | C and R both empty, and the latest attempt succeeded with no windows | empty | no_usage_windows |
| 8 | C and R both empty, and there was no attempt yet, or the reader is busy or cooling down | pending | not_read_yet, reader_busy, no_manual_reading |
| 9 | R is not empty | stale | stale_reading or observation_time_unknown (the original error stays only in that account's `lastFailure`) |
| 10 | C is not empty and R is empty | fresh | ok, estimated |
| 11 | none of the above (unreachable by construction; asserted by a test) | failed | other |

Notes:

- **Credential-store versus reader permission.** Row 2 is driven only by the consent record from the consent API (allowed/denied/unset/outdated), never by a reader's status string. When Claude's credential path reports `consent_required` because the Keychain choice is unset and no `.credentials.json` exists (`claudeaccount.go:118`), the mapping turns it into `keychain_unset`, which is row 5. Likewise the Keychain vocabulary's `consent-required` (`security.go:66`) maps to `keychain_unset`, and its `busy` maps to `reader_busy` (row 8).
- Row 2 is about the tool's reader consent. Row 5 is only about the credential store blocking an actual read. They are separate predicates, and row 5 comes before the generic failure in row 6. A recorded Keychain choice that blocks nothing is a Settings fact on the consent API, so a fresh Claude reading from `.credentials.json` stays `fresh`.
- **Case "A current, B none".** Row 10 applies and the row is `fresh`. Account B is listed with `valueState = none` and its own `lastFailure`.
- **Ordering guarantees.** Rows 1–5 come before any value-based state, so a stale value never hides a veto. Missing or retired tools (row 3) come before no reader (row 4), preserving the actionable membership rule. Row 4 comes before row 8, so an unsupported tool never stays pending.
- **Login or generation change.** The old account becomes `valueState = none`. Its numbers are dropped, not shown as stale for the new login.
- **Required captures.** Every overlap named here has its own capture: a Keychain first-failure, A current with B none, a value whose time is null or in the future, and an empty reading.

## Reason-code mapping (normative)

The closed set of codes, with the state and next-step action each one gives:

| code | state | action |
|---|---|---|
| ok, estimated | fresh | none |
| stale_reading, observation_time_unknown | stale | refresh |
| not_read_yet, reader_busy, consent_changed | pending | none (a refresh action carries `disabledReason` while cooling down) |
| no_manual_reading | pending | none |
| no_usage_windows | empty | none |
| consent_required, consent_denied, consent_outdated | needs_consent | open_settings_consent |
| keychain_unset, keychain_denied, keychain_canceled, keychain_not_found, keychain_unavailable, keychain_confirmation_needed | needs_keychain | open_settings_keychain |
| login_expired | needs_action | open_tool |
| runtime_missing | needs_action | install_runtime |
| update_required | needs_action | update_cli |
| key_missing, tool_not_found, catalogue_retired, http_401, unsupported_login | needs_action | open_settings_consent |
| privacy_blocked, catalogue_off, not_admitted, codexbar_not_audited, codexbar_not_read, codexbar_access_unknown, browser_session_consent_required | off | open_settings_consent |
| no_reader | unsupported | none |
| cleanup_pending | off (Settings surface only) | open_settings_consent |
| file_missing, file_unreadable, parse_error, schema_changed, http_403, http_429, http_5xx, network, timeout | failed (row 6, when there is no value; with a retained value the row is stale and the code lives in `lastFailure`) | refresh |
| other | failed | refresh |

A single Go table maps every status, reason, errorCode and blocked value to `(state, code, action)`. The emitting sites are `sources.go`, `readerstate.go`, `quota_native.go`, `claudeaccount.go`, `keychain/security.go`, `connect.go` (the Blocked values), `codexbar.go`, `detect` (`unknown` and `no-safe-signal`), `consent_api.go`, `reader_errors.go`, and the per-reader admission files (`copilot_state.go`, `antigravity_state.go`, `zaiconfig_state.go`, and any other `*_state.go` that sets a blocked or availability value). Three tests guard the table:

- **Exhaustive.** Every known emitted value maps to its listed code.
- **Intentional generic outcome.** The canceled and untyped results of `reader_errors.go`, which already emit `other` on purpose, are listed as the only sources allowed to produce `other`.
- **Unknown fallback.** An unmapped value maps to `other`. Any capture whose `other` comes from a site outside that list fails.

## Privacy

- No row field carries hosts, file paths, emails, account or login names, key names, credential, profile or account hashes, or free text read from a tool's files.
- Every exported id is one of four kinds: an allow-listed key, the literal `other`, the user's own declared `planId`, or an existing identity reference. That covers row ids, `accountLocator`, window ids, `limitKey` and `poolKey`. A charset check alone is not a privacy rule, so unknown provider limit or pool text never appears, not even in ids. Read-only commands write nothing.
- `subscriptionRef` is the existing random local reference. `MODELPLAN_IDENTITY=off` gives `null`.
- Plan names come from an allow-list. Declared plans are the user's own text from their own local.json, flagged `userAuthored`.
- Tests use a field-specific validator per field (ids, timestamps, refs, `limitKey`/`poolKey` allow-list, message-table texts), plus canaries: raw emails, paths, hashes, provider error text and secret-like limit or pool ids (for example `account_token_123`) are seeded into the fixtures and must never appear in any row field, ids included.

## App side

- Generated Swift types for Row, Account, Window and RowsSummary, and for every enum. A Go generator in `cli/internal/appcontract` emits them from the same structs. Unknown enum values decode as `.unknown(String)` and render as a neutral card with the reason text.
- **Dock:** one card per row whose `surfaces` contains dock, in app order. Accounts with windows become the card's instruments. Age is formatted from `observedAt` (minutes, hours, days). The card states and next-step actions come from the row, and so do the `disabledReason` labels.
- **Menu bar:** the same rows and the same preferences as the Dock.
- **Settings subscriptions list:** the rows, joined by tool id to the consent API facts for the controls.
- **Preferences (one policy, shared by the Dock and the menu bar):**
  - *Row level, keyed by row id:* hidden and order.
  - *Account level, keyed by `subscriptionRef`, else `accountLocator`:* the selected window.
  - *Global, unchanged:* used versus remaining stays one app-wide setting, as today (`ConsumerPolicy.swift:59`).
  - *One-time migration:* a row is hidden only if all its old subscriptions were hidden. Its order is the smallest old order. Per-subscription window choices carry over to the matching account.
  - *Precedence:* after migration, only the new keys are read.
  - *Cross-navigation:* cockpit and history keep joining on `subscriptionRef`.
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
    - two consecutive generation changes (fail-closed output still validates against the schema and decodes)
  - read-only:
    - a first `--read-only` run over a pre-rows cache, with no identity references yet (accountLocator null, nothing written)
    - identity off
    - declared plans before any collection
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
  - the exactly-once publication check (revoke between ReadPermitted and output)
  - the membership invariant: every allowed tool has exactly one Dock row in every state
  - the privacy validators and canaries
  - `quota --json` stays byte-identical across the change (plugin and Skill gate)
- **Swift tests** render the Dock, the menu bar and Settings from every capture:
  - the card count equals the number of Dock rows
  - every non-fresh card has a reason and a next step
  - every card with a value shows its age
  - the menu minimum uses only current windows
- **e2e (#281):** extended with membership, revoke and mixed-account journeys.
- **CI path filters:** `.github/workflows/desktop.yml` also triggers on `cli/internal/quota`, `cli/internal/connections`, `cli/internal/consent`, `cli/internal/detect`, `cli/internal/keychain`, `cli/internal/appcontract` and `cli/cmd/modelplan`, so a change to the projection always runs the Swift, capture and app-smoke checks.

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
3. **Consent API (CLIJIT, with step 1):** `consent --json` also lists tools that have a persisted grant but are no longer detected or have been retired, with `detected = false`. Settings can then show and revoke them, and the rule-2 rows always join to consent facts. Both layers change: the CLI request validation (`consent_api.go:253`) accepts a deny for a persisted undetected/retired grant, and Settings `mayDeny` (`CommunityConsentContract.swift:40`) stops requiring detection. A gate test covers it: such a grant can be revoked through both layers, while an unknown or undetected tool still cannot be newly granted.
4. **Then:**
   - delete the merge code
   - remove the invalidation clearing
5. **Later, in its own contract version (desktop-v2):** remove or shrink `connections` in `desktop --json`.

No compatibility is kept with released app builds before the official release (owner rule). The schema and conformance obligations above still apply.

**Estimate:**
- CLI: about 1.5 days (the per-profile failure time and the single consent input add to v1).
- App: 1–2 days.
- Then captures and e2e.

## Grill-me: questions and answers

1. **Can an allowed tool lose its row?** No. Persisted grants are candidates even when undetected or retired (membership rule 2). An invariant test covers every state.
2. **Can a revoked tool's readings reappear?** No. A denied tool or one with pending cleanup exports no accounts. The app also rejects snapshots older than the committed floor.
3. **Success, then a failed refresh 5 minutes later?** The account becomes `retained` with `lastFailure`, so the row is `stale` (#9). It is not shown as fresh.
4. **Two accounts, one current and one retained?** The row is `stale`. Each account carries its own `valueState`, and the menu minimum skips the retained account's windows.
5. **Keychain unset but a credentials file works?** The row stays `fresh`. `needs_keychain` appears only when the read is actually blocked (#5).
6. **Unsupported tool?** Missing or retired tools take priority (#3). Otherwise `unsupported` (#4) comes before the pending check (#8), so it is never pending forever.
7. **Empty reading, or a null or future time?** An empty reading is `empty` (#7). A value whose time is null or in the future is `retained` with `observation_time_unknown`, so the row is `stale` (#9) and the age shows as unknown.
8. **Unknown Codex limit or plan?** It gets a generic label, plan `unknown`, and `limitKey` / `poolKey` = `other`. The raw text is never exported, not even inside ids.
9. **Settings needs Keychain, Forget and generation facts?** Those stay on the consent API, joined by id. Rows never encode permissions.
10. **Preferences keyed by subscription?** They stay keyed by `subscriptionRef`. Only row-level choices move to the row id, with a migration.
11. **Does a newer CLI break an older app?** No. Unknown enum values render neutrally, and the fields are additive under desktop-v1.
12. **A refresh action during cooldown or offline?** The action carries `disabledReason` and `availableAt`. The app shows them and never bypasses them.
13. **Does a projection change escape CI?** No. The workflow paths are widened.
14. **What can still be wrong?** The classifier order and the mapping table. Each is one Go function with table tests, captures and e2e, so any fix happens in one place.
15. **A held snapshot crosses a reset or freshness time?** `expiresAt` and `stateAfterExpiry` let the app switch state by the clock. The window rule removes reset windows from the minimum. The app never re-runs the classifier.
16. **Revoke during the build?** The publication check discards the result and retries once, then fails closed. The app floor covers revokes that the app itself committed.
17. **Two Codex subscriptions with different hidden or order choices?** The migration policy decides it: the row is hidden only if all were hidden, and it takes the smallest order. Window choices stay per account.
18. **Does this delay beta07?** Only through the owner's trigger: if respin5 fails on the seam again, beta07 moves to rows, about 2–3 days later.
