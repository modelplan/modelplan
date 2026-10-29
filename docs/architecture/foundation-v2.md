# Mac App foundation v2

Status: revision 3 for review. Codex (xhigh) reviewed revisions 1 and 2. This revision closes the revision 2 re-review. It fixes:
- the delivery graph;
- the consent store boundary for old writers;
- the fence on history and cockpit queries;
- the admission gates;
- the proof rules.
The owner approved the direction and its decisions on 2026-10-29, after a three-way review by Claude (coordinator), Codex (GPT-6.1-Sol, xhigh) and GLM-5.3. Markers:

- **[owner]**: an owner decision, dated when it came after the direction.
- **[agreed]**: the three-way consensus on a design rule.
- **[impl]**: an implementation detail of this revision. It can change in review without owner approval. Numbers such as queue sizes and caps are [impl].

Unmarked text (the delivery plan, the test lists, the checklist) is the current plan. An accepted direction does not mean each protocol detail was approved line by line. Nothing here is implemented yet.

Related:
- the protocol in [`schema/app-cli/app-server.md`](../../schema/app-cli/app-server.md);
- rows in [`schema/app-cli/rows-design.md`](../../schema/app-cli/rows-design.md);
- the reader standard in [`docs/readers/integration-standard.md`](../readers/integration-standard.md);
- ADRs [0001](../adr/0001-app-server-engine-boundary.md)–[0006](../adr/0006-proof-levels-and-review-tiers.md); private ADR 0049.

## Terms

Five terms are used precisely in this document:

| Term | Meaning |
|---|---|
| **consent generation** | A monotonic counter in the consent store. Every committed grant, revoke or Forget increments it. It is shared by every CLI copy on the machine. |
| **session** | One handshake between the app and one app-server process. The app assigns a new random `sessionId` when it starts each child. |
| **sequence** | A counter that orders `rows/changed` notifications within one session. It is compared only within the same session. |
| **row set** | The rows the engine emits for one projection. Membership follows `rows-design.md`. |
| **owner-shaped home** | A synthetic HOME rebuilt from the owner's sanitized shape export. |

## Problem

The owner tested five beta07 candidates (respin1 to respin5). Each one failed on the real Mac or in integrated review, and bugs the owner had reported and seen "fixed" came back. The causes were structural:

- **The app rebuilt the engine's state in Swift.**
  - `desktop --json` returns overlapping views: `accounts`, `sources`, `connections` and `subscriptions`. Consent comes from a separate command.
  - Four app surfaces merged these with four different input sets.
  - The results were missing rows, lost ages, unmapped reason codes and missing titles.
- **One short-lived CLI subprocess per request.** Each call had its own timeout, `busy` state, environment, size cap and decoder.
- **Hand-written Swift types drifted from Go.**
  - Go omits `paceHistory.groups[*].cycles[*].spent[*].model` for an unknown model, but Swift `PaceSpent.model` was required.
  - On the owner's Mac the decoder threw `keyNotFound` and discarded the whole snapshot.
  - CI never saw it, because fresh synthetic homes contain no such entry.
- **Keychain reads ran through `/usr/bin/security` with a 2-second background timeout.**
  - An unanswered prompt was saved as a permanent latch.
  - #298's grant-time foreground read bypasses the 5-minute reader budget.
- **The native shell was written from scratch.** The decision to reuse Pulse was never carried out, and placement, sliver, drag and default-edge bugs recurred.
- **The cockpit was redrawn in AppKit from a web prototype,** with a separate native↔web bridge. It slipped 2–4 days, and the art drifted.
- **Official visuals were assembled privately,** so the red-key ring regressed while its fix only covered the neutral key.
- **"Fixed" meant "PR merged".**

## Solution

1. **[owner] One engine process.** The app talks to `modelplan app-server`, which speaks JSON-RPC 2.0 over stdio. Swift types are generated from the Go types. ADR 0001.
2. **[owner] The engine owns every row.** The app renders rows and never merges engine views. ADR 0002.
3. **[owner] Keychain under the app's own identity.** The app reads the Keychain with Security.framework under a stable self-signed signing identity, and hands an access token to Go in memory only. ADR 0003.
4. **[owner] Native shell, Pulse-derived.** The Dock, menu bar and Settings stay native. Placement geometry and AppKit patterns are ported from Pulse file by file. ADR 0004.
5. **[owner] The cockpit runs the prototype web code.** A WKWebView sits in a native window, behind a narrow typed bridge. The v1 porthole is prerendered. ADR 0005.
6. **[owner] Proof levels.**
   - L1: checks.
   - L2: declared scenarios on the owner-shaped home and the dedicated test Mac.
   - L3: the owner's Mac.

   A level is earned by checks on a stated subject, never by a merge. Review is risk-tiered. ADR 0006.
7. **[owner] Official runtime visuals ship from the public repo** once they are final, shipped and rights-clear. Sources stay private (ADR 0049).

## Seams under test

Each seam has tests that reach the owner-visible result. A fix keeps its regression test at the seam where the failure belongs:

| Seam | What is driven | What is observed |
|---|---|---|
| Engine boundary | The real `modelplan app-server` binary, in both a fresh and an owner-shaped home | The notifications and responses, validated against the schema and the row invariants. Real Go encodings go through the production Swift decoder |
| App boundary | Recorded app-server transcripts | The rendered Dock and menu-bar model, compared to the expected row set by stable id |
| Consent and Forget | The app-server plus an independent CLI process, including an old released CLI | No restored value after a revoke or Forget, whatever the interleaving |
| Sensitive queries | `history/query` and `cockpit/query` results that straddle a revoke or re-grant | No private value shown after the revoke; an old cursor or late result returns nothing |
| Credential operation | A fake Security.framework adapter plus the real app-server; L3 on the real Mac | Credential outcomes, late-result rejection, prompt policy, token canaries |
| Native shell | AppKit windows with synthetic real input | Saved edge vs actual edge, sliver, reveal, drag, displays |
| Cockpit | The cockpit bundle in headless Chrome (fast screen) and in WKWebView on macOS (final) | Screenshots against owner-confirmed baselines; bridge rejection cases |
| Product identity | The final package | App SHA, bundled engine hash, official-asset manifest and publication revision all match the reviewed candidate |
| Whole journey | The e2e job: real app, real app-server, fake providers, owner-shaped home | The Appendix A scenarios that run at L2 |

## User stories

**First run**
1. As a new user, I see each detected tool and each of its read paths, so that I know what the app can read.
2. As a new user, I see each path's default. Local and owning-runtime reads are pre-selected. Login-borrowing reads are unselected, and a "select all" control is shown. That way nothing sends my credentials unless I choose it. [owner]
3. As a new user, I see, for each login-borrowing path, that granting sends my existing login to that vendor's official usage endpoint.
4. As a new user, I grant once, and the app does not ask again for the same path.

**Readings**

5. As a user with a valid consent, every allowed path's tool appears exactly once in the Dock row set, unless I hid it.
6. As a user, a tool whose first read failed shows a human reason and a next step.
7. As a user, every value shows its observation age in minutes or hours. A missing or future time shows as "time unknown".
8. As a user, a value from a failed refresh shows as stale, with its age.
9. As a user with two accounts on one tool, each account shows its own state, and the menu bar uses only current values.
10. As a user, a tool waiting for its first read says so, and a key-based tool whose key is missing says that.
11. As a user, one malformed history entry never changes my Dock.
12. As a user, when readers are off or consent is changing, the Dock shows that state, not an empty strip.

**Claude and the Keychain**

13. As a user, the macOS prompt appears only after I choose to allow the Keychain in Settings, and while I am there.
14. As a user, after "Always Allow", a new test build of the same signing identity does not prompt again. This is verified across two builds.
15. As a user, if I deny or cancel, the Claude row shows the Keychain step. It never loops or prompts in the background.
16. As a user, allowing the Keychain causes no remote request beyond the normal budget.

**Shell**

17. As a user, on first launch the Dock sits on the right edge of the main display, when that edge is available.
18. As a user, a Dock I moved left stays left after relaunch and after updates.
19. As a user, a corrupt preference file opens the Dock on the right, reports the error, and is not overwritten.
20. As a user, if the remembered display is unplugged, the Dock moves to the main display and comes back when the display returns.
21. As a user, the collapsed Dock shows a sliver, reveals on hover, collapses on leave and can be dragged to another edge.
22. As a user, the menu bar uses the same hidden-row and used/remaining preferences as the Dock.
23. As a VoiceOver user, each Dock card announces the tool name, its state and the remaining value.

**Settings**

24. As a user, I can revoke any path in Settings, including the paths of tools that are no longer installed or no longer in the catalogue.
25. As a user, a revoke or Forget removes that path's values at once, and they never reappear. That holds when the revoke comes from the CLI, and when a read finishes late.
26. As a user, "Copy diagnostics" gives a sanitized report.

**Cockpit**

27. As a user, the cockpit matches the confirmed design at every supported size and language.
28. As a user, the porthole shows a confirmed still for my setup, or "No view for this setup yet" with "Choose another setup".
29. As a user, the cockpit uses no live 3D in v1. Once it is closed, its memory stays within the measured limit.

**Owner and lanes**

30. As the owner, a problem I reported counts as fixed only at L3 on the real candidate, compared against my report.
31. As a lane, I see which tickets I can start from their blocking edges.
32. As a lane, my question is handled by its approved default rule when one matches:
    - Authorised routine work goes ahead at once.
    - A pending question whose type has an approved waiting policy takes its default after 30 minutes.
    - An irreversible change, a new permission or a public disclosure waits for an answer, and escalates to the owner after 4 hours.

## Implementation decisions

### Consent by read path, not by tool

- **[agreed, fixes P1-01]** Consent is recorded per **read scope**, not per tool. Scopes are stable ids, for example:
  - `claude.local_history`
  - `claude.account_usage.saved_login`
  - `codex.runtime_usage`
  - `gemini.local_history`
  - `gemini.account_usage.saved_login`
  - `zai.account_usage.api_key`
- The Keychain is a separate permission on the scopes that need it. It does not stand in for scope consent: a Claude or Gemini login read from a file needs no Keychain.
- Go owns scope definition, persistence, readback and admission. The existing class and `DeniedSources` machinery is reused, with complete mutation, readback, migration and admission semantics.
- An old tool-level grant carries over only to the scopes it provably covered. New scopes never inherit it.
- Promoting a scope to pre-selected changes only the initial choice for users who have not decided. It never overrides a denial, a revoke, or Passive mode.
- **[agreed, fixes P1-R03] Store boundary for old writers.** Per-scope consent changes what a grant means, so it cannot be an additive field: a shipped schema-1 writer would ignore the new field and write tool-level grants back.
  - **Schema bump.** The consent store moves to `schemaVersion: 2` in place (`~/.config/modelplan/consent.json`).
  - **Shipped CLIs already honour this boundary** (`cli/internal/consent/consent.go`, main `f830589`):
    - `consent.Load` rejects any `schemaVersion` other than 1;
    - `Current()` then reports readers `off`;
    - the mutation path returns the load error instead of writing.

    An old copy therefore reads nothing and writes nothing.
  - **[impl] Migration.**
    1. The first v2-capable engine takes the store lock and reads schema 1.
    2. It maps each tool grant to the scopes that grant provably covered, and keeps denials and pending Forget entries.
    3. It writes schema 2 atomically.
    4. It keeps the schema-1 file as `consent.v1.bak`, never reads it again for decisions, and deletes it after the official release.
  - **[impl] Recovery.** A schema-2 file that fails to load is never overwritten. Readers stay off, and `doctor` and Settings show "consent store unreadable" with a reset action. After confirmation, the reset writes an empty schema-2 store.
  - **Consequence.**
    - Every CLI copy on the machine that reads quota must be v2-capable. The app's bundled engine, the plugin pins and the Skill's install pin move in the same release.
    - Until a plugin updates, its old copy shows readers off. It never reads under stale grants.
  - **Regression (U2).** Run the current plugin-pinned release and the latest released CLI against a schema-2 home. After a revoke in the new engine, the old copy's grant, refresh and Forget commands must not change the store, restore a value or make a remote call. Only the versions this scenario runs are claimed.
- **[agreed, fixes P2-R11] Revoke and Forget.** Both go through `consent/grant`; there is no separate method.
  - **Revoke.** `deny` revokes a scope: the scope becomes denied and its cached readings are erased. The denial is recorded, so promotion or re-detection never re-enables the scope.
  - **Forget.** `forget` does what `deny` does, and also erases the scope's derived history and identity records.
  - **Unfinished cleanup.** Erasure that cannot finish is recorded as `cleanup_pending` and retried. The denial itself is already committed.
  - **Budget.** Budget state is kept across a revoke, so a re-grant cannot buy an extra remote read.
  - **Tightening is always accepted.** Deny and Forget work when readers are off, when the tool is no longer detected or is retired, and when no reader exists. Only `allow` is subject to admission gates.
  - **Idempotency.** The same `requestId` with a different payload is rejected (`request_mismatch`), using the stored request hash. Receipts persist in the store, so a retry after a restart replays the original receipt.

### Engine process (`modelplan app-server`)

- **[owner] Lifecycle.**
  - The app starts the bundled app-server as a child with anonymous pipes for stdin, stdout and stderr. No named endpoint, socket or daemon.
  - Unrelated file descriptors are not inherited, and pipes are closed and reaped on exit or cancel.
  - The environment is an allow-list: `HOME`, `PATH`, `TMPDIR`, locale, and the explicit vendor-key variables listed in the reader catalogue (`Z_AI_API_KEY`, `OPENCODE_API_KEY`, `MINIMAX_CODING_API_KEY`, the Kimi explicit-key variable). Everything else is dropped.
- **[impl] Supervision.**
  - Restart with backoff (1 s, 2 s, 4 s, capped at 30 s).
  - After 5 crashes in 10 minutes, stop and show "engine stopped" with a Retry action.
  - A protocol mismatch never restarts.
  - stdout and stderr are drained concurrently. stderr carries allow-listed log lines only: state codes, stage, counts, durations.
- **[agreed, fixes P1-04] Sessions.**
  - Each child gets a fresh `sessionId` from the app. `sequence` is compared only within that session.
  - Messages carrying an old `sessionId` are dropped.
  - A new session resets sequence but never lowers the committed consent-generation floor.
  - `rows/subscribe` returns the snapshot together with its sequence. Notifications with a lower or equal sequence in the same session are dropped, so the subscribe boundary is atomic.
- **[impl, fixes P2-R10] Flow control.** The exact rules are in `app-server.md`, section "Flow control". In short:
  - **Two outbound classes, one writer per direction.**
    - Control messages are sent before query results and are never coalesced. They are consent receipts, `consent/changed`, credential requests, health and errors.
    - Row snapshots coalesce to the latest.
  - **Caps.** In-flight requests, queries and credential operations each have a limit. A request over a limit gets a `busy` error at once, so nothing waits without bound.
  - **Frames.** A frame is limited while it is scanned. An unterminated line is rejected at 8 MiB without buffering more.
  - **Deadlines.** Each request has a deadline and can be cancelled. A slow history or Keychain call never blocks a revoke or a health message.
  - **Lost receipts.** A receipt can still be lost when the connection drops. The app recovers it by retrying the same `requestId`, or by reading consent back in the next session.
  - **One store.** Swift has one engine-state store that consumes the stream and fans out to the Dock, the menu bar and Settings.
- **[agreed, fixes P1-02] Cross-process safety is kept, not deleted.**
  - The app-server removes duplicate scheduling and detached refresh workers from the app path. It keeps using the shared mechanisms every CLI copy relies on:
    - provider locks and budgets;
    - `consent.ReaderLock` / `ReaderLockContext` admission;
    - the atomic `consent.Publish`, which serializes the generation check with the cache commit;
    - Forget synchronization.
  - A read result is committed only through `Publish` under the generation it was admitted with. A result that loses that race is discarded and never cached.
  - The app-server watches the consent store. When an independent CLI process changes consent, the app-server re-reads and notifies the app with the new generation.
- **[agreed] Consent transactions.**
  - `consent/grant` returns a receipt that says whether the change committed, and at which generation. That holds even on `cleanup_pending`: the revoke has committed but cleanup is incomplete.
  - The app raises its floor from any committed generation, including one carried in an error.
  - Requests are idempotent by `requestId`.
  - `consent/get` returns its generation, and the app never joins consent facts and rows of different generations.
- **[owner] Data ownership.** The engine owns consent, readings, caches and history. The app owns presentation preferences only.
- **[agreed] Standalone CLI.** `desktop --json` and the other commands keep their wire contracts. `quota --json` stays byte-identical, which is a gate.
  - A standalone CLI run has no app identity. It cannot read a Keychain-only Claude login, and says so with a recovery step: open the app, or use a credentials file.
  - It never falls back to `/usr/bin/security`.

### Rows

- **[owner]** The row model, membership, total classifier, reason codes and privacy rules follow `rows-design.md`. This document supersedes two parts of it:
  - classifier rows 3 and 4 swap, so a missing or retired tool comes before `no_reader`;
  - the scope extends from "display projection only" to the whole app, through the app-server.
- **[agreed]** Rows carry a safe `route` code for each account (for example `saved_login_api`, `runtime_rpc`, `local_log`, `api_key_api`), so "source shown on every value" has a field to show. Time can be null; the app shows "time unknown" and never invents a time.
- **[agreed, fixes P1-05 and P2-R08] Empty states are explicit, and each has one owner.**
  - **Engine.** The engine emits the full row set before any presentation filter, with one row per tool and no duplicates. Its summary states are engine states: `readers_off`, `pending` (consent changing), `no_consent`, and an empty set.
  - **App.** The app applies its presentation preferences (hidden rows, order) to that set. When every row is hidden, the app shows its own "all hidden by you" state. It never writes that state back into the engine snapshot, and Go never reads app preferences.
  - **The check.** After the surface's filter, the stable ids shown equal the expected ids, declared plans included, each exactly once. When the expected set is empty, the matching empty state is shown.
  - **Uncertainty.** When identity or consent is uncertain, clearing sensitive values wins over showing a row.

### Sensitive query results

- **[agreed, fixes P1-R04]** `history/query` and `cockpit/query` return private values, so they follow the same fence as rows.
  - **Engine.** The engine admits the query under the current consent of every scope it touches, reads, and checks the generation again before it answers. If the generation moved, it answers `consent_changed` with no items.
  - **Context.** Every result carries its context in the response envelope: the `sessionId`, the scopes covered and the `consentGeneration` it was admitted under. Items do not repeat these fields.
  - **Cursors.** A cursor is opaque. It is bound to the session, the scopes, the account reference and the generation. After a revoke or re-grant it returns `cursor_stale`, so an old cursor never recovers data.
  - **App.** When the app sees a higher generation in any message, it:
    - clears every history and cockpit view and derived cache for the affected scopes;
    - drops any result admitted under a lower generation;
    - sends `CockpitBridge` a `clear` with the new generation, and the page discards anything older.
  - **Acceptance.**
    - Rows stay correct while a history or cockpit result arrives late across a revoke.
    - An open page removes private values at once.
    - After a re-grant, an old cursor or a late response cannot bring data back.

### Swift client

- **[agreed, fixes P2-02] One wire source of truth.**
  - Dedicated wire DTO structs in Go define field names, presence, nullability, enum sets, required ids and size limits. Their JSON tags are the source: `omitempty` means "may be absent", a pointer means "may be null".
  - The generator emits Swift from these DTOs. Conformance tests push real Go encodings through the production Swift decoder.
  - Internal storage types are never exported. `history.Entry` does not exist; history uses a new `HistoryItem` DTO.
- **Decode policy.** Mutation tests check three classes:
  1. legal omission or null is accepted;
  2. an unknown display value degrades locally;
  3. a broken identity, type or version fails explicitly and leaves the app in a safe state.
- **[owner] No merge logic.** The Dock, the menu bar and Settings read rows and consent facts directly.
- **[agreed] Deletion.** Each item goes in the wave that completes its replacement, never with the interface PR alone. Before it goes, the replacement's new call chain, its consent fence, the real package and its regressions must all pass. Historical regression scenarios stay; they are not a compatibility layer. The items:
  - `CommunityUnboundDockRows`;
  - the row and category logic in `CommunityReaderReason`;
  - the Dock's use of the `Projection` stale rule;
  - the four canonicalisers and the title and guidance tables;
  - the engine paths of `CLITransport`;
  - the hand-written `PersonalSnapshot` engine types;
  - `onCanonicalInvalidated`, removed only after the session and generation fence is proven by its test.

  The prototype's JS `live-adapter.js:82–89` accounts→subscriptions interpretation is also removed; the cockpit gets display data from Go.

### Credentials

- **[owner] Identity.**
  - Test builds are signed with a local self-signed code-signing identity, with a fixed identifier and designated requirement. Certificate Assistant, type Code Signing.
  - The private key stays in the build Mac's login keychain, with a `.p12` backup kept by the owner. It never goes into a repository, and the certificate is not set as system-trusted.
  - The claim is narrow: ModelPlan requests access under its own identity, and L3 verifies "Always Allow" across two builds.
  - The app does not change existing access-list entries. An old trust entry for `/usr/bin/security` stays until the owner removes it by hand. The diagnostics page explains how.
- **[agreed, fixes P1-03] Credential operation.** One request-and-outcome exchange:
  - **Request.** The server sends `credentials/request { operationId, provider, scope, consentGeneration, interactive }`. `interactive` is true only for an operation that follows an explicit user action in Settings.
  - **Read.** The app runs `SecItemCopyMatching` off the main thread. A logical deadline only stops the app from waiting; the OS call itself is not cancelled, and a late callback is dropped by `operationId`.
  - **Result.** The app replies with `credentials/result { operationId, outcome, accessToken?, expiresAt? }`. `outcome` is one of `ok`, `canceled`, `denied`, `not_found`, `interaction_required`, `timeout` or `error`.
  - **Rejection.** Go rejects any result whose operation id, session or consent generation does not match an open operation.
  - **Background.** The app never shows a prompt in the background: background operations run with UI disabled and return `interaction_required`.
  - **Where the token may appear.** Only in `credentials/result.accessToken`. Never in broadcasts, diagnostics, errors, logs or the web page.
- **[agreed] Budget.**
  - A Keychain grant starts one interactive credential operation.
  - The remote quota request obeys the shared budget.
  - The #298 foreground bypass (`readerstate.go:202`, `:206`) is removed.
- **[owner] OAuth-borrowing scopes** are in the standard tier and are not pre-selected. They are promoted only after two clean beta cycles, a re-review and an owner decision.
- **[owner, 2026-10-29, P1-10] POST gate.** Reads are GET-only, except a read-only POST that the owner approves per vendor. Its method, host, path and request-body schema are pinned in code and covered by the recording-transport test; the integration card presents the exact request for approval. Gemini (Code Assist) and Cursor (plan and period usage) read quota with POST today, so their remote account-usage scopes stay disabled until their cards are approved. Their local-history scopes keep working.
- **[owner, 2026-10-29] API keys.** A key the user configured for ModelPlan (`modelplan connect` or Settings) keeps working. A key found only in the environment is offered unchecked and is used only after consent.

### Native shell

- **[owner] Ported from Pulse** (pinned commit, file by file, Apache-2.0 headers and NOTICE kept). Each file is reviewed before porting, because `DockPresence` depends on `AppSettings`, `LoginItem` has LaunchAgent and default-on behaviour, and there is a private appearance selector.
  - **Ported:** `PanelScreen`, `ActiveDisplayFollower`, `PanelPointerWatcher`, `PointerEntryReporter`, the `PanelPlacement` model and the `FloatingPanel` event and ordering techniques.
  - **Ported after review:** `LoginItem` without default-on, and `DockPresence` without `AppSettings`.
  - **Not ported:** the private selector, providers, `BotMark`, `DropletTether` and the update stack.
- **[agreed]** Hover, reveal, collapse and drag state live in one AppKit controller that we own. It is tested with synthetic real input.
- **[agreed, fixes P2-05 and P2-R12] Preferences and migration.**
  - **The new file** is `~/Library/Application Support/ModelPlan/settings.json`, carrying a `schemaVersion`. It has two sections. Today's two stores hold different data and are used together, and neither overwrites the other (`ModelPlanSettings/Preferences.swift`, main `f830589`).
  - **Migration by field group.** It runs on first run only; when the new file exists, nothing is migrated.

    | Group | Today's source | Fields | New section |
    |---|---|---|---|
    | Settings | The build's own file: `ModelPlan/Beta07/settings-v1.json` for the official build, `ModelPlan/Native/settings-v1.json` for the Community build. If it is missing or corrupt, the other one. The two are never merged field by field | Appearance: theme, size, motion, transparency, percentage mode and display, red threshold. Dock: edge, display UUID, along-fraction, auto-hide and reveal, magnification. Rows: order and visibility (`subscriptions`), per-subscription settings. Other: menu display, shortcuts, language, opening, notifications, help hints, onboarding progress, open at login, automatic updates | `settings` |
    | Core | `ModelPlan/Native/community-v1.json`, independent of the Settings group | Locale, favourite model ids, field picker value | `core` |
    | Not migrated | `readerConsent` in the Settings file | Old app-side consent UI state | — |

  - **Consent stays in the engine.** `readerConsent` is never promoted to engine consent. Consent migrates in the engine (see "Store boundary for old writers").
  - **Row ids.** Old row-preference ids are mapped to the new row and account ids. An id with no match is kept in the file, unused, so the existing reconnect behaviour still finds it.
  - **Recovery.** The migration writes the new file atomically and leaves the old files untouched. A corrupt source falls back to the other source of the same group. If none loads, defaults apply and the error is reported.
  - **Defaults.**
    - With no file, the Dock goes on the right edge when that edge is available. A system-Dock or adjacent-display fallback is tested separately.
    - A saved left edge is kept.
    - A corrupt new file opens on the right, reports the error and is not overwritten.
    - An unplugged display falls back to the main display, and the stored UUID is kept.
  - **Saved and actual edge.** They are stored separately, and the actual edge is never written back as the default.
  - **Coexistence cases.** A synthetic home with all three old files, and one with a corrupt Beta07 file, each migrate to the expected sections.
  - **Shape export.** The H40 shape export covers each of the files above. The owner-shaped home reproduces them synthetically and never reads owner files.
  - `doctor` prints the path in use.
- **[impl] Borrowed libraries:** LaunchAtLogin-Modern and KeyboardShortcuts (MIT), recorded in `docs/borrowed/`. Sparkle integration is not part of this foundation; the existing update path stays.

### Cockpit and porthole

- **[owner] Cockpit bundle.** A native window hosts one WKWebView running the cockpit bundle built from the prototype code, loaded from the app bundle with no remote content.
- **[agreed, fixes P1-08 and P2-08] `CockpitBridge`.** A narrow, typed host bridge, not a pass-through.
  - **Allowed:**
    - display DTOs pushed by the host: rows, `cockpit/query` and `history/query` results, publication summary;
    - a `clear` message carrying a new consent generation, after which the page discards older data;
    - a fixed set of user actions: choose setup, open Settings, open history page.
  - **Refused:** credentials, consent mutation, plugin install, arbitrary commands, files or URLs, and any message from a non-main frame or another origin.
  - **Message rules:** messages carry `generation` and `requestId` and a size limit. Navigation is restricted, and there is a CSP.
  - These rules reuse the Field bridge's discipline for main frame, local origin, generation and teardown. The snapshot state machine is not reused.
  - Go supplies the cockpit's display data, so the page does no account→subscription interpretation.
- **[agreed, fixes P2-04] Lifecycle.**
  - The page pauses when hidden or occluded, and is released when the window closes.
  - There is no hidden prewarmed page by default. Cold and repeat open times, and memory after close, are measured first. A prewarm experiment with a retention limit is optional, after that measurement.
  - The target is measurable: memory falls back after close and does not grow over repeated open/close. It is not "zero".
- **[owner, fixes P1-07] Porthole v1: no runtime 3D.**
  - Stills and ignition/entrance videos come from the **private** offline render pipeline: three.js scene sources stay private (ADR 0049). The pipeline publishes a public runtime asset pack with a manifest of input ids, versions and result hashes.
  - Public CI verifies the manifest, completeness, licence and the official build without a private checkout.
  - The default setup always has a confirmed still.
- **[agreed] Live 3D after v1** only behind a measured budget on the lowest supported Mac, with automatic fallback to stills.
- **[agreed] Visual checks.**
  - Headless-Chrome screenshots are the fast screen. The final check is WKWebView on macOS against owner-confirmed baselines.
  - Baselines change only with owner confirmation, never by automatic re-baselining.
- Rive is not introduced. RealityKit comes after v1, and SceneKit is not used.

### Product identity and release coupling

- **[agreed, fixes P2-06]** Every candidate records, and L3 checks:
  - the app SHA-256;
  - the bundled `modelplan` binary hash and version;
  - the official-asset manifest hash;
  - the publication revision.

  The owner receives the same bundle that passed L2 and the integrated review, and runs L3 on it. Acceptance and release use that same bundle; it is never rebuilt.
- **[agreed] Release coupling.**
  - The app bundles one exact engine version and hash. Plugin and Skill pins stay independent.
  - All CLI copies on a machine share the data directory. Each store has a schema version and an unknown-version rule.
    - A store whose meaning does not change stays additive, as `clients-and-readers.md` section 2 says.
    - A store whose meaning changes (consent, in this foundation) bumps its schema to a version that shipped copies reject, as described above. It never relies on old copies honouring a new field.
  - A protocol minor version adds methods, fields or enum values through capability negotiation, and the generator and its consumers update together.
  - The version number of the first app-server release is a release choice. 0.6.0 is proposed.
- **[agreed, fixes P1-R03] Rollback** means installing the previous test build, under three rules:
  - A rolled-back build never re-enables a revoked scope. A build from before the consent schema bump cannot load the schema-2 store, so it shows readers off and writes nothing. To read again, the user moves forward to a v2-capable build.
  - Other stores stay additive, and their old readers ignore unknown fields.
  - Rollback is tested for consent, readings and preferences, together with the old-writer regression above.
- **[agreed] CI path filters** also cover official assets, the cockpit bundle, schemas, the generator and packaging entry points.

### Security model

- **[agreed]** The token's exposure is kept short and narrow. It is held in memory only as long as a request needs it, then released. Swift `Data` zeroing is an extra measure, not a guarantee, because copies may exist in String, JSON and IPC buffers and in Go.
- **[agreed]** stderr and diagnostics use allow-listed fields only, written that way from the start. Raw responses are never logged and then scrubbed.
- **[agreed]** There is no listening endpoint, so there are no connection checks. The pipes and file descriptors are scoped as in "Lifecycle".

### Text and accessibility

- **[agreed] Text ownership.** Engine-owned user text (row reasons, next steps, consent text) comes from the Go message table in English and Chinese. App-owned UI text comes from the app's own tables.
  - Completeness tests check that every key has both languages, interpolation arguments match, unknown reasons fall back, and long strings render.
  - Internal log codes are not translated.
- **[agreed] Accessibility minimum.** Dock cards, the menu-bar menu and Settings controls carry VoiceOver labels: tool name, state and remaining value. The cockpit's actionable controls are keyboard-reachable. M1 checks this at L3.

### Reader integration

See [`integration-standard.md`](../readers/integration-standard.md). The read path, not the tool, is classified. Each red line is defined by an observable forbidden event and a test seam. Each reader starts from an integration card.

### Performance

- **[agreed]** Measure the baseline first, then set the limits:
  - app and app-server idle CPU and memory;
  - Dock reveal latency;
  - cockpit cold and repeat open times;
  - memory after close;
  - growth over repeated cycles;
  - energy.
- The limits become checks in CI or on the test Mac. The 0.3-second open target is reviewed against the measured baseline before it is made a limit.

## Testing decisions

- A good test drives a seam from the table above and asserts what the owner would see.
- A fix that changes behaviour lands with a test that fails before it, at the seam where the failure belongs. A docs fix, or a refactor with no behaviour change, needs no new test. Extend an existing test rather than copying it.
- **Fixtures.**
  - Real-binary captures for every row state.
  - The respin5 cases:
    - `spent.model` omitted, null and present;
    - a Keychain-only Claude;
    - a legacy `connections.json`;
    - each preference file listed above, including a retained left edge;
    - a corrupt preference file.
  - Per-scope consent, including a local-only grant on a tool that has an O scope.
- **Owner-shaped home.**
  - The e2e job rebuilds it from an approved, versioned shape baseline for every PR that touches `cli/`, `desktop/native/`, the cockpit bundle or the official assets.
  - The baseline states the structures it covers and its known gaps.
  - The baseline is updated only when the structure changes or L3 exposes a gap, within an approved run. It is never re-exported as a routine step before each beta.
- **Race tests.**
  - An independent CLI revokes or Forgets while a read is in flight.
  - The revoke is committed but cleanup fails.
  - A lost receipt is retried.
  - The app and the CLI modify consent at the same time.
  - A late credential result arrives after a revoke.
  - A message from an old session arrives after a restart.
  - A history or cockpit result arrives after a revoke, and an old cursor is used after a re-grant.
  - An old released CLI runs grant, refresh and Forget against a schema-2 store.
- **Red-line tests.** These use a recording transport, a fake filesystem, a fake keychain, a fake process and a fake network. They assert forbidden events: method, host, path and parameters; retries after 401 or 403; writes outside allowed stores; token canaries outside `credentials/result`. See `integration-standard.md` section 2.
- **Visual tests.** Offscreen native at 1x and 2x and both themes; the cockpit in headless Chrome, then in WKWebView; owner-confirmed baselines.
- **Shell tests with real input.**
- **Prior art:** the e2e journey (#281, #290), appcontract captures (#275, #285), the rows oracle table test (on #299), and the H37 invariants.

## Delivery

- **One DRI.** Each unit has one final owner (DRI); any collaborators are named after it.
- **Start and completion.** A unit's **start** may need less than its **completion**. Completion edges are transitive: a candidate is complete only when everything its units depend on for completion is complete.
- **What each ticket names:**
  - its consumer;
  - its exact inputs (a SHA, schema version or artefact hash);
  - its scenarios and environment;
  - an acceptance command: an existing one, or "new in this ticket" with its inputs and pass rule;
  - the condition for deleting the old path.

| Unit | Delivers | Start needs | Completion needs | DRI | Consumer and acceptance |
|---|---|---|---|---|---|
| U1 Rows core | Classifier, mapping, membership, rows 3↔4 swap, oracle tests (#299) | — | — | CLIJIT | Oracle and table tests, L1 |
| U2 Consent and reader state | Per-scope consent, consent schema 2 and its migration, the fence and Publish rules, revoke and Forget semantics, #295, #294, removing the #298 bypass, multi-writer and old-writer regressions | — | U1 | FEEDFIX | Race and old-writer tests, L2 |
| U2a Reader admission, first batch | Admission gates on the first batch. Unapproved POST account-usage scopes (Gemini Code Assist, Cursor) make zero remote calls. MiniMax sends no request after a 401 or 403, or stays disabled until it doesn't. Local-history scopes are unaffected | U2 scope ids | U2 | READERS | Recording-transport tests, L1 |
| U3 app-server core | Handshake, sessions, envelope, flow control, supervision contract, `rows/*`, `consent/*`, `diagnostics/get`, `credentials/request/result`, `engine/health` | U1 types | U1, U2 | CLIJIT | Protocol tests against the real binary, L2 |
| U3b First-candidate handlers | `refresh/request` (shared budget), `plugin/install` (same contract as `plugin install --json`) | U3 | U3 | READERS | Real-binary handler tests |
| U3c Cockpit handlers | `history/query` (`HistoryItem`, cursors), `cockpit/query`, `publication/get`, with the sensitive-query fence | U3 | U2, U3 | READERS | Real-binary handler tests, including late results after a revoke |
| U4 Generated Swift client | Wire DTOs, generator, engine-state store, decode policy, mutation tests | U3 schema | U3 | CLIJIT, with M0 as consumer | Real Go encodings through the production decoder |
| U5 Shell from Pulse | Ported modules, controller, settings file and migration by field group, real-input tests | — | — | M0 | Real-input and migration tests, L2 on the test Mac |
| U6 Dock and menu on rows | Render rows, refresh through U3b, delete the merge code and `onCanonicalInvalidated` (after the fence test) | U4, U5 | U2, U3b, U4, U5, U14 | M0 | Owner-shaped e2e, L2 |
| U7 Keychain identity (implementation-ready) | Signing identity in packaging, Security.framework adapter, credential operation | U3 | U2, U3 | M0, with CLIJIT for the Go side | On the test Mac: two signed builds of one identity, a synthetic Keychain item, interactive, background and late-callback cases, budget. L2 |
| U8 Settings on app-server | Per-scope consent UI (O unselected), revoke and Forget for undetected tools, diagnostics, plugin install (#297) through U3b | U4 | U2, U3b, U4, U14 | M4 | e2e, L2 |
| U9 Official visuals public | Asset pack and manifest, public official build, baselines | Owner-confirmed item list | — | M0, with M2 and M3 for the assets | Manifest and visual checks |
| U14 e2e harness, shape baseline, candidate manifest | The e2e runner on the app-server (the scenario intents of #300), the versioned shape-baseline builder, the candidate manifest and evidence-bundle generator | U3 | U3 | RELPIPE | Consumed by U6, U8 and U10. Feature scenarios stay with each feature's DRI, and a failure goes back to that DRI |
| U10 First candidate | Package with product identity; L1, L2, 5-minute smoke, integrated review, then L3 | — | U2, U2a, U6, U7, U8, U9, U14 (release gate) | M0, with M1 for L3 | The Appendix A items marked U10. The real two-build Keychain check (A14) stays pending until the next reviewed candidate |
| U11 Cockpit web | Bundle, `CockpitBridge` (with `clear`), lifecycle, visual tests | U3c | U3c, U9 | Cockpit lane | Bridge-rejection and clear tests, WKWebView baselines |
| U12 Prerendered porthole | Private pipeline, public asset pack and manifest, default-still check | U9 | U9 | Cockpit lane, with M3 for the art | Manifest and default-still CI |
| U13 v1 candidate | U10 plus U11 and U12; upgrade, wake and rollback checks; L3 | — | U10, U11, U12 | M0, with M1 for L3 | The Appendix A items marked U13, with A14 completed |

**Methods the first candidate consumes:**
- `initialize`, `shutdown`;
- `rows/subscribe`, `rows/changed`;
- `consent/get`, `consent/grant`, `consent/changed`;
- `credentials/request`, `credentials/result`;
- `refresh/request`, `plugin/install`;
- `diagnostics/get`, `engine/health`.

The cockpit methods (U3c) are not on its path.

The first real chain is U1, then U2 and U3, then U4, then U6 (rows, consent, Swift, Dock). Work widens only after that chain passes L2. These units become tickets after this revision passes review.

**Existing work and contracts to migrate.** The capability and its regressions move; old PRs are not re-implemented as they were.

| Work | Goes into |
|---|---|
| #299 (with the oracle test) | U1 |
| #295, #294 | U2 |
| #297 (plugin install UI, merged) | U8, behind `plugin/install` (U3b) |
| #300 (e2e native-panel cases) | U14, the scenario intents only. Its old respin6 gate does not return |
| #298 (Keychain grant read, merged) | U2 removes its budget bypass; U7 replaces its Keychain path |

**Estimate from design freeze:** the first candidate in 5–8 working days, v1 in 10–15. That assumes no new tools, approved visuals, available lanes and test Mac, and reused readers. The estimate is redone after the first chain (U6).

## Process

The working process lives in the private repo's development-process document, which is in review. Each task contract pins the version it follows by SHA. This foundation depends on these rules from it:
- one final DRI per unit;
- start and completion edges;
- proof earned by checks on a stated subject (ADR 0006);
- deletion only after the replacement's evidence;
- an owner-reported issue closed only at L3.

## Supersedes and status

| Document | What changes |
|---|---|
| `clients-and-readers.md` §2 | The additive rule stays for stores whose meaning does not change. Consent moves to schema 2, which shipped copies reject (see "Store boundary for old writers") |
| `clients-and-readers.md` §3–§6 | Three changes; the one-read definition (a fixed set of at most two requests) is unchanged. First-run "pre-check all standard" becomes per-scope defaults. ADR 0003 replaces the `/usr/bin/security` stable-identity rule. The advanced browser-session class is unchanged: CodexBar keeps its session cookie in its own Keychain item, and Forget clears it |
| `rows-design.md` v4 | Classifier rows 3↔4 swap; scope extends from display projection to the whole app; `route` added per account; empty states split between engine and app as above |
| `integration-standard.md` | Cards are written reader by reader, but admission gates apply now and override the transition: the POST gate, known red-line violations (the MiniMax retry), readers off and every revoke. Only a reader that already meets the red lines keeps running until its card is written. U2a delivers the first-batch gates |
| ADR 0006 | Synced with the proof and review rules above |

## Out of scope

- Windows support.
- Live 3D and the RealityKit entrance in v1.
- New tools before v1, except repairs to the first batch.
- Moving scoring or production into the public CLI.
- Compatibility with released app builds before the official release.
- A new Sparkle integration in this foundation.

## Risks

- A long-lived engine process is new. Supervision and log hygiene must be right in U3.
- The self-signed identity may not prevent prompts on every update. If L3 shows prompts, accept one prompt per update until Developer ID.
- Pulse has one maintainer and frequent churn, so upstream fixes need manual review.
- A web cockpit adds a WebContent process while it is open, and its memory must stay within the measured limit.
- The owner-shaped home is only as good as its shape baseline. The baseline's known gaps are listed with it.

## Appendix A: L3 checklist (owner journey and reported issues)

Each item has a scenario id, the candidate it applies to, the L2 evidence it needs first, and the part only L3 can show.

- **What a run covers.** A candidate runs the items that apply to it, plus the item for every reported issue it claims to fix. All of this fits in one owner GUI run of at most 20 minutes.
- **Destructive preconditions** (a fresh first run, no consent) are proven at L2 on a synthetic profile. The owner's real state is only used as it is: never reset, revoked or forgotten.
- **Unfinished items.** An item that does not fit or cannot run is recorded `pending` or `not-run`, never passed.
- **Closing a reported issue.** It closes only when its item passes at L3, compared against the original report.

| Id | Check | Applies to | L2 first | L3 part |
|---|---|---|---|---|
| A01 | First run lists detected tools and scopes, with the defaults of user story 2 | U10 | Fresh synthetic profile | The owner's detected set, from the existing state |
| A02 | Consent per scope; the Claude Keychain prompt appears only after the user's action | U10 | Synthetic Keychain: interactive and background cases | The real prompt timing |
| A03 | **Row set matches by id.** After the surface's filter, the shown ids equal the expected ids, each once. An empty expected set shows its specific empty state. This was the respin1–5 failure | U10 | Owner-shaped e2e | The owner's real Dock |
| A04 | A tool whose first read failed shows one row with a reason and a next step | U10 | Owner-shaped e2e | The owner's real failing tool, if there is one |
| A05 | Every value shows its age, and stale values are labelled | U10 | Captures | Visual check |
| A06 | Refresh stays within budget, and a value refreshes after its due time | U10 | Budget tests on one home | One observed refresh, without forcing extra refreshes |
| A07 | The menu bar shows the lowest current value and follows the Dock's preferences | U10 | e2e | Visual check |
| A08 | The Dock is on the right edge on first run, and a saved left edge is kept. Owner report (beta06, respin5) | U10 | Migration and real-input tests on the test Mac | The owner's real saved edge |
| A09 | The official red key's ring and material match the confirmed baseline. Owner report (beta06, respin5) | U10 | Visual check on the final package | The owner's visual confirmation |
| A10 | The sliver is visible; reveal and collapse work | U10 | Real-input tests | Visual check |
| A11 | Drag to each edge; display unplug and replug | U10 | Real-input tests; unplug only where the test Mac can do it | The owner's real displays where available, otherwise `not-run` |
| A12 | The Settings edge shows the actual placement. Owner report (beta06) | U10 | Real-input tests | Visual check |
| A13 | Readers-off and no-consent paths show their summary states. Owner report (beta06) | U10 | Synthetic profile | Not recreated on the owner's Mac; L2 evidence only |
| A14 | Claude Keychain: Always Allow survives the next build | Started by U10, completed by the next reviewed candidate | U7 two-build test on the test Mac | The real Keychain, across two reviewed candidates |
| A15 | Revoke removes values at once, and a CLI-side revoke is reflected | U10 | Race tests | Not run on the owner's profile; L2 evidence only |
| A16 | VoiceOver labels on Dock cards | U10 | Accessibility tests | Spot check |
| A17 | Copy diagnostics is sanitized | U10 | Canary scan | The owner's export, checked locally and never uploaded |
| A18 | The candidate's identity matches the reviewed one | U10, U13 | Manifest | Hashes on the owner's Mac |
| A19 | The cockpit matches the confirmed design: porthole still or fallback, keyboard reach, memory after close | U13 | U11 and U12 evidence: WKWebView baselines, the default-still check, lifecycle measures | The owner's visual confirmation |
