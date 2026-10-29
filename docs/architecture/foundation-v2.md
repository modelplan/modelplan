# Mac App foundation v2

Status: revision 2 for review. Revision 1 was reviewed by Codex (xhigh); this revision answers its ten P1 and ten P2 findings and adds the agreed supplements.
The owner approved the direction and four decisions on 2026-10-29, after a three-way review by Claude (coordinator), Codex (GPT-6.1-Sol, xhigh) and GLM-5.3. Each statement below is marked:

- **[owner]**: an owner decision.
- **[agreed]**: the three-way consensus.
- **[impl]**: an implementation choice in this document, open to review.
- **[pending]**: needs an owner decision. The safe default applies until then.

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
6. **[owner] Proof levels.** L1 CI, L2 the owner-shaped home and dedicated test Mac, L3 the owner's Mac. Review is risk-tiered. ADR 0006.
7. **[owner] Official runtime visuals ship from the public repo** once they are final, shipped and rights-clear. Sources stay private (ADR 0049).

## Seams under test

Each seam is tested at the highest point that reaches the owner-visible result:

| Seam | What is driven | What is observed |
|---|---|---|
| Engine boundary | The real `modelplan app-server` binary, in both a fresh and an owner-shaped home | The notifications and responses, validated against the schema and the row invariants. Real Go encodings go through the production Swift decoder |
| App boundary | Recorded app-server transcripts | The rendered Dock and menu-bar model, compared to the expected row set by stable id |
| Consent and Forget | The app-server plus an independent CLI process | No restored value after a revoke or Forget, whatever the interleaving |
| Credential operation | A fake Security.framework adapter plus the real app-server; L3 on the real Mac | Credential outcomes, late-result rejection, prompt policy, token canaries |
| Native shell | AppKit windows with synthetic real input | Saved edge vs actual edge, sliver, reveal, drag, displays |
| Cockpit | The cockpit bundle in headless Chrome (fast screen) and in WKWebView on macOS (final) | Screenshots against owner-confirmed baselines; bridge rejection cases |
| Product identity | The final package | App SHA, bundled engine hash, official-asset manifest and publication revision all match the reviewed candidate |
| Whole journey | The e2e job: real app, real app-server, fake providers, owner-shaped home | The owner journey checklist (Appendix A) |

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
32. As a lane, a reversible question resolves by default after 30 minutes. An irreversible one escalates to the owner after 4 hours.

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
- **[impl] Flow control.**
  - One writer per direction. Frames are at most 8 MiB, with a bounded outbound queue.
  - Full row snapshots coalesce: only the latest is kept. Consent receipts and credential outcomes are never coalesced or dropped.
  - Each request has a deadline and can be cancelled.
  - A slow history or Keychain call never blocks a revoke or a health message.
  - Swift has one engine-state store that consumes the stream and fans out to the Dock, the menu bar and Settings.
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
- **[agreed, fixes P1-05] Empty states are explicit.**
  - With a valid consent, the Dock row set equals the engine's expected set by stable id, with exactly one row per tool and no duplicates.
  - Legitimate empty states each have their own summary and UI: `readers_off`, `pending` (consent changing), `no_consent`, and "all hidden by you".
  - When identity or consent is uncertain, clearing sensitive values wins over showing a row.

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
- **[agreed] Deletion, in the same wave as the replacement and with evidence in the PR:**
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
- **[pending, P1-10] GET-only.** Gemini (Code Assist) and Cursor (plan and period usage) read quota with POST today, which does not meet the GET-only condition. Until the owner decides, their remote account-usage scopes stay disabled. Their local-history scopes keep working. Options:
  - **(a)** strict GET-only;
  - **(b)** per-vendor, owner-approved read-only POST, with method, host, path and body schema pinned in code. Recommended.

### Native shell

- **[owner] Ported from Pulse** (pinned commit, file by file, Apache-2.0 headers and NOTICE kept). Each file is reviewed before porting, because `DockPresence` depends on `AppSettings`, `LoginItem` has LaunchAgent and default-on behaviour, and there is a private appearance selector.
  - **Ported:** `PanelScreen`, `ActiveDisplayFollower`, `PanelPointerWatcher`, `PointerEntryReporter`, the `PanelPlacement` model and the `FloatingPanel` event and ordering techniques.
  - **Ported after review:** `LoginItem` without default-on, and `DockPresence` without `AppSettings`.
  - **Not ported:** the private selector, providers, `BotMark`, `DropletTether` and the update stack.
- **[agreed]** Hover, reveal, collapse and drag state live in one AppKit controller that we own. It is tested with synthetic real input.
- **[agreed, fixes P2-05] Preferences and migration.**
  - The new file is `~/Library/Application Support/ModelPlan/settings.json`, carrying a `schemaVersion`.
  - On first run it migrates from, in priority order:
    1. the production Beta07 `ModelPlan/Beta07/settings-v1.json`;
    2. the Community `ModelPlan/Native/settings-v1.json`;
    3. the surface file `ModelPlan/Native/community-v1.json`.
  - Fields migrated: Dock placement (saved edge, ratio, display UUID), hidden rows, order and per-account window choice. Old row preference ids are mapped to the new row and account ids.
  - The migration writes the new file atomically and leaves the old files untouched.
  - Defaults: with no file, the right edge when available. A system-Dock or adjacent-display fallback is tested separately. A saved left edge is kept. A corrupt file opens on the right, reports the error and is not overwritten. An unplugged display falls back to the main display and keeps the stored UUID.
  - The saved edge and the actual edge are stored separately, and the actual edge is never written back as the default.
  - The H40 shape export is updated to include each of the files above. The owner-shaped home reproduces them synthetically and never reads owner files.
  - `doctor` prints the path in use.
- **[impl] Borrowed libraries:** LaunchAtLogin-Modern and KeyboardShortcuts (MIT), recorded in `docs/borrowed/`. Sparkle integration is not part of this foundation; the existing update path stays.

### Cockpit and porthole

- **[owner] Cockpit bundle.** A native window hosts one WKWebView running the cockpit bundle built from the prototype code, loaded from the app bundle with no remote content.
- **[agreed, fixes P1-08 and P2-08] `CockpitBridge`.** A narrow, typed host bridge, not a pass-through.
  - **Allowed:**
    - display DTOs pushed by the host: rows, `cockpit/query` and `history/query` results, publication summary;
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

  The owner receives exactly the file that passed L3.
- **[agreed] Release coupling.**
  - The app bundles one exact engine version and hash. Plugin and Skill pins stay independent.
  - All CLI copies on a machine share the data directory under the storage rules in `clients-and-readers.md` section 2. Each store has a schema version, minimum reader and writer versions, and unknown-version handling. A copy that cannot write a store safely refuses to write.
  - A protocol minor version adds methods, fields or enum values through capability negotiation, and the generator and its consumers update together.
  - The version number of the first app-server release is a release choice. 0.6.0 is proposed.
- **[agreed] Rollback** means installing the previous test build, under three rules:
  - A rolled-back build must never re-enable a revoked scope: the consent store's minimum writer version blocks older writers from rewriting consent they do not understand.
  - New stores are additive where possible, and an older writer that would drop unknown fields refuses to write.
  - Rollback is tested for consent, readings and preferences.
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
- Every fix lands with a test that fails before it.
- **Fixtures.**
  - Real-binary captures for every row state.
  - The respin5 cases:
    - `spent.model` omitted, null and present;
    - a Keychain-only Claude;
    - a legacy `connections.json`;
    - each preference file listed above, including a retained left edge;
    - a corrupt preference file.
  - Per-scope consent, including a local-only grant on a tool that has an O scope.
- **Owner-shaped home.** Rebuilt from the updated shape export before each beta, in the e2e job for every PR touching `cli/`, `desktop/native/`, the cockpit bundle or the official assets.
- **Race tests.**
  - An independent CLI revokes or Forgets while a read is in flight.
  - The revoke is committed but cleanup fails.
  - A lost receipt is retried.
  - The app and the CLI modify consent at the same time.
  - A late credential result arrives after a revoke.
  - A message from an old session arrives after a restart.
- **Red-line tests.** These use a recording transport, a fake filesystem, a fake keychain, a fake process and a fake network. They assert forbidden events: method, host, path and parameters; retries after 401 or 403; writes outside allowed stores; token canaries outside `credentials/result`. See `integration-standard.md` section 2.
- **Visual tests.** Offscreen native at 1x and 2x and both themes; the cockpit in headless Chrome, then in WKWebView; owner-confirmed baselines.
- **Shell tests with real input.**
- **Prior art:** the e2e journey (#281, #290), appcontract captures (#275, #285), the rows oracle table test (on #299), and the H37 invariants.

## Delivery

Each unit has one final owner (DRI), a consumer, an acceptance command and environment, and a condition for deleting the old path. A unit's **start** may need less than its **completion**.

| Unit | Delivers | Start needs | Completion needs | DRI | Consumer and acceptance |
|---|---|---|---|---|---|
| U1 Rows core | Classifier, mapping, membership, rows 3↔4 swap, oracle tests (#299) | — | — | CLIJIT | Oracle and table tests, L1 |
| U2 Consent and reader state | Per-scope consent (P1-01), the fence and Publish rules (P1-02), #295, #294, removing the #298 bypass, multi-writer tests | — | U1 | FEEDFIX | Race tests, L2 |
| U3 app-server core | Handshake, sessions, supervision contract, `rows/*`, `consent/*`, `diagnostics/get`, `credentials/request/result` | U1 types | U1, U2 | CLIJIT | Protocol tests against the real binary, L2 |
| U3b app-server data handlers | `refresh/request`, `history/query` (`HistoryItem`), `cockpit/query`, `publication/get`, `plugin/install` | U3 | U3 | READERS | Real-binary handler tests |
| U4 Generated Swift client | Wire DTOs, generator, engine-state store, decode policy, mutation tests | U3 schema | U3 | CLIJIT, with M0 as consumer | Real Go encodings through the production decoder |
| U5 Shell from Pulse | Ported modules, controller, settings file and migration, real-input tests | — | — | M0 | Real-input and migration tests, L2 on the test Mac |
| U6 Dock and menu on rows | Render rows, delete the merge code and `onCanonicalInvalidated` (after the fence test) | U4, U5 | U2, U4, U5 | M0 | Owner-shaped e2e, L2 |
| U7 Keychain identity | Signing identity in packaging, Security.framework adapter, credential operation | U3 | U2, U3 | M0, with CLIJIT for the Go side | Credential race tests, L3 two-build check |
| U8 Settings on app-server | Per-scope consent UI (O unselected), revoke for undetected tools, diagnostics | U4 | U2, U4 | M4 | e2e, L2 |
| U9 Official visuals public | Asset pack and manifest, public official build, baselines | Owner-confirmed item list | — | M2/M3 | Manifest and visual checks |
| U10 First candidate | Package with product identity, L1/L2, 5-min smoke, integrated review, L3 | — | U2, U6, U7, U8, U9 (release gate) | M0, with M1 for L3 | Appendix A |
| U11 Cockpit web | Bundle, `CockpitBridge`, lifecycle, visual tests | U3b | U3b, U9 | Cockpit lane | Bridge-rejection tests, WKWebView baselines |
| U12 Prerendered porthole | Private pipeline, public asset pack and manifest, default-still check | U9 | U9 | M3 | Manifest and default-still CI |
| U13 v1 candidate | U10 plus U11 and U12; upgrade, wake and rollback checks; L3 | — | U10, U11, U12 | M0, with M1 for L3 | Appendix A |

The first real chain is U1, then U2 and U3, then U4, then U6 (rows, consent, Swift, Dock). Work widens only after that chain passes L2. These units become tickets after this revision passes review.

**Migration of in-flight work:**

| PR | Goes into |
|---|---|
| #299 (with the oracle test) | U1 |
| #295, #294 | U2 |
| #297 (plugin install UI) | U8, behind `plugin/install` |
| #300 (e2e native-panel cases) | The e2e harness, re-pointed to the app-server |
| #298 (Keychain grant read) | U2 removes its budget bypass; U7 replaces its Keychain path |

**Estimate from design freeze:** the first candidate in 5–8 working days, v1 in 10–15. That assumes no new tools, approved visuals, available lanes and test Mac, and reused readers. The estimate is redone after the first chain (U6).

## Process

See [`docs/agents/development-process.md`](https://github.com/guanbear/modelplans.ai/blob/main/docs/agents/development-process.md) in the private repo, which is in review.

## Supersedes and status

| Document | What changes |
|---|---|
| `clients-and-readers.md` §3–§6 | First-run "pre-check all standard" becomes per-scope defaults; `/usr/bin/security` stable-identity rule is replaced by ADR 0003; the browser cookie cache rule is unchanged (advanced class) |
| `rows-design.md` v4 | Classifier rows 3↔4 swap; scope extends from display projection to the whole app; `route` added per account; empty-state rules as above |
| `integration-standard.md` | Applies from the next reader change; existing readers keep running until their card is written |

Every row in this document is marked [owner], [agreed], [impl] or [pending]. [impl] rows may change in review without owner approval. [pending] rows wait for the owner.

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
- The owner-shaped home is only as good as the latest shape export.

## Appendix A: L3 checklist (owner journey and reported issues)

Each candidate is checked against these items. Every check uses a local screenshot or the diagnostics export, compared against the original report where one exists.

1. Fresh first run lists the detected tools and scopes, with the defaults of user story 2.
2. Consent per scope, and Claude Keychain consent with the prompt only after the user's action.
3. **The Dock row set matches the consented set by id**: no zero rows when consent is valid, no duplicates. This was the respin1–5 failure.
4. **A tool whose first read failed** shows one row with a reason and a next step.
5. **Every value shows its age.** Stale values are labelled.
6. **Refresh** stays within budget, and a value refreshes after its due time.
7. The menu bar shows the lowest current value and follows the Dock's preferences.
8. **Dock default edge** is right on first run, and a saved left edge is kept. Owner report (beta06, respin5).
9. **Official red key** ring and material match the confirmed baseline. Owner report (beta06, respin5).
10. The sliver is visible, and reveal and collapse work.
11. Drag to each edge, and display unplug and replug.
12. The Settings edge shows the actual placement. Owner report (beta06).
13. The read-only and no-consent paths show their summary states. Owner report (beta06).
14. Claude Keychain: Always Allow survives the next build.
15. Revoke removes values at once, and a CLI-side revoke is reflected.
16. VoiceOver labels on Dock cards.
17. Copy diagnostics is sanitized.
18. The product identity of the candidate matches the reviewed one.
