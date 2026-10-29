# Mac App foundation v2

Status: approved for build by the owner on 2026-10-29. This document is the design. It was settled in a three-way review: Claude (coordinator), Codex (GPT-6.1-Sol, xhigh) and GLM-5.3, over three rounds.
Related: the protocol reference in [`schema/app-cli/app-server.md`](../../schema/app-cli/app-server.md), the row model in [`schema/app-cli/rows-design.md`](../../schema/app-cli/rows-design.md), and ADRs [0001](../adr/0001-app-server-engine-boundary.md) to [0006](../adr/0006-proof-levels-and-review-tiers.md).

## Problem

The owner tested five beta07 candidates (respin1 to respin5). Each one failed on the real Mac or in integrated review. Low-level bugs kept appearing, and bugs the owner had reported and seen "fixed" came back. Every failure traced to one of these structural causes:

- **The app rebuilt the engine's state in Swift.** `desktop --json` returns overlapping views (`accounts`, `sources`, `connections`, `subscriptions`), and consent comes from a separate command. The app merged them in four surfaces with four input sets. Rows went missing, ages were lost, new reason codes were unmapped and titles were missing.
- **The app ran a short-lived CLI subprocess per request.** Each call had its own timeout, `busy` state, environment, size cap and decoder, so one boundary became six.
- **Hand-written Swift types drifted from the Go types.** Respin5 showed zero rows on the owner's Mac because Go omits `paceHistory.groups[*].cycles[*].spent[*].model` for an unknown model (`omitempty`), while Swift `PaceSpent.model` was required. The decoder threw `keyNotFound` and discarded the whole snapshot. CI never saw it, because fresh synthetic homes contain no such entry.
- **Keychain reads went through `/usr/bin/security` with a 2-second background timeout.** The first macOS prompt timed out unanswered, the timeout was persisted as `keychain-confirmation-needed`, and every later background read returned that latch. #298 added a foreground read at grant time, but that read bypasses the 5-minute reader budget.
- **The native shell was written from scratch.** We had decided to reuse Pulse's edge, hide and hover logic, but none of it was reused. Placement, sliver, drag and default-edge bugs recurred.
- **The cockpit was redrawn in AppKit from a web prototype**, with a complex native↔web bridge for the 3D porthole. It is 2–4 days late, and the art drifted.
- **Official visuals were assembled privately**, so public CI and cross-vendor review never saw the shipped artwork. The red-key ring regressed while its "fix" covered only the neutral key.
- **"Fixed" meant "PR merged".** Proofs ran on fresh homes, never on an owner-shaped environment (retained preferences, legacy files, Keychain-only Claude login, real data volume, official visuals).

## Solution

Keep Go as the only data engine, and remove the seams between it and the app:

1. **The app talks to one long-lived engine process.** `modelplan app-server` speaks JSON-RPC 2.0 over stdio, pushes the per-tool rows and takes requests (consent, refresh, history pages, diagnostics). Swift types are generated from the Go types. See [ADR 0001](../adr/0001-app-server-engine-boundary.md).
2. **The engine owns every row.** The app renders rows and never merges engine views. See [ADR 0002](../adr/0002-engine-owned-rows.md) and `rows-design.md`.
3. **Credentials are read under the app's own stable identity.** The app reads the Keychain with Security.framework, signed by a local self-signed code-signing identity. It hands a short-lived access token to Go in memory over the app-server pipe. See [ADR 0003](../adr/0003-keychain-identity-and-token-handoff.md).
4. **The native shell borrows proven code.** The Dock, menu bar and Settings stay native. Placement geometry and AppKit window patterns are ported from Pulse file by file, without a fork. See [ADR 0004](../adr/0004-native-shell-borrows-pulse.md).
5. **The cockpit is the prototype.** A native window hosts one WKWebView that runs the cockpit web code. The v1 porthole uses prerendered stills and videos only. See [ADR 0005](../adr/0005-web-cockpit-prerendered-porthole.md).
6. **Proof follows the owner's environment.** There are three proof levels (CI, owner-shaped synthetic, real Mac), a 5-minute real-Mac smoke before integrated review, and risk-tiered review. See [ADR 0006](../adr/0006-proof-levels-and-review-tiers.md).

Official runtime visuals that are final, shipped and rights-clear move to the public repo. Editable sources stay private. That decision lives in the private repo (ADR 0049).

## Seams under test

Each seam is tested at the highest point that still reaches the owner-visible result. These are the only places new tests attach:

| Seam | What is driven | What is observed |
|---|---|---|
| Engine boundary | Real `modelplan app-server` binary, synthetic HOME (fresh and owner-shaped) | The `rows/changed` notifications, validated against the schema and the row invariants |
| App boundary | Recorded app-server transcripts, fed into the Swift client | The rendered Dock and menu-bar model: the card count, the reason and next step on every non-fresh card, and an age on every value |
| Native shell | AppKit window plus synthetic real input (pointer, drag, displays) | The saved preference, the actual edge, the sliver visibility and the reveal |
| Cockpit | Cockpit web bundle in headless Chrome, fed the same row transcripts | Screenshots compared against owner-confirmed baselines |
| Credential | Security.framework adapter with an injected fake keychain, plus L3 on the real Mac | The token reaches Go only through the pipe; prompt timing; latch behaviour |
| Whole journey | e2e job: the real app and the real app-server, fake providers, owner-shaped home | The ten-step owner journey invariants |

## User stories

**Install and first run**
1. As a new user, I open the app and see each AI tool detected on my Mac, so that I know what it can read.
2. As a new user, I see local readings (Codex app-server, local logs) pre-selected and login-borrowing readings listed unselected, with a "select all" control, so that nothing sends my credentials without my choice.
3. As a new user, I see, per vendor, that granting sends my existing login to that vendor's official usage endpoint, so that I understand the effect.
4. As a new user, I grant consent once, and the app does not ask again for the same scope.

**Readings**

5. As a user, every tool I allowed has exactly one Dock row in every state, so that a tool never vanishes.
6. As a user, a tool whose first read failed shows a human reason and a next step, so that I can fix it.
7. As a user, every reading shows its observation age in minutes or hours, and "time unknown" when the time is missing or in the future.
8. As a user, a value from a failed refresh shows as stale, with its age, and is not shown as fresh.
9. As a user with two accounts on one tool, each account shows its own state, and the menu bar uses only current values.
10. As a user, a tool waiting for its first read says "waiting for first reading", not "no current reading".
11. As a user, a tool whose key is not in the app's environment says so, instead of waiting forever.
12. As a user, one malformed history entry never empties my Dock.

**Claude and the Keychain**

13. As a user, when I allow Claude's Keychain in Settings, the macOS prompt appears while I am there.
14. As a user, after I click "Always Allow", later updates of the test build do not prompt again unless the signing identity changed.
15. As a user, if I deny or cancel the prompt, the Claude row shows the Keychain step and does not loop.
16. As a user, granting the Keychain does not cause extra requests to Claude beyond the normal budget.

**Shell**

17. As a user, on first launch the Dock sits on the right edge of the main display.
18. As a user, if I moved the Dock to the left, it stays on the left after relaunch and after updates.
19. As a user, if the preference file is corrupt, the Dock opens on the right, the app reports the error, and the file is not overwritten.
20. As a user, if the remembered display is unplugged, the Dock moves to the main display. When the display comes back, the Dock returns to it.
21. As a user, the collapsed Dock shows a thin sliver, reveals on hover, collapses on leave and can be dragged to another edge.
22. As a user, the menu bar shows the lowest current remaining percentage, using the same hidden-row and used/remaining preferences as the Dock.

**Settings and maintenance**

23. As a user, I can revoke a tool in Settings, even one that is no longer installed or no longer in the catalogue.
24. As a user, revoking removes that tool's readings immediately, and they never reappear from a late response.
25. As a user, "Copy diagnostics" gives a sanitized report: protocol version, each tool's state code, the last error class and the engine health.

**Cockpit**

26. As a user, the cockpit looks exactly like the confirmed design at every supported size and language.
27. As a user, the porthole shows a confirmed still for my current setup, or "No view for this setup yet" with "Choose another setup".
28. As a user, the cockpit uses no live 3D in v1 and adds no memory once it is closed.

**Owner and lanes**

29. As the owner, a problem I reported counts as fixed only after the real-Mac run on the real candidate shows it gone, compared against my report.
30. As a lane, I can see which tickets I can start, from their blocking edges, without asking the coordinator.
31. As a lane, a reversible question resolves by the default table after 30 minutes. An irreversible one escalates to the owner after 4 hours.

## Implementation decisions

### Engine process (`modelplan app-server`)

- **Lifecycle.**
  - The app starts the bundled `modelplan app-server` once per app instance, as a child process with private stdin/stdout. There is no listening socket and no system daemon.
  - stderr carries sanitized logs only.
  - The app stops the child on quit.
  - On a crash the app restarts the child with backoff (1 s, 2 s, 4 s, capped at 30 s), and the Dock shows an "engine restarting" summary state.
- **Handshake.** The first request is `initialize`, carrying `protocolVersion`, `appVersion` and `capabilities`.
  - A major-version mismatch fails closed, with a visible app error. It never falls back to silently decoding nothing.
- **One scheduler.**
  - The app-server owns reader scheduling, budgets, cooldowns and backoff for everything the app shows.
  - The CLI, plugins and Skill keep using the existing shared budget files and provider locks. The app-server honours those files, so all copies share one per-vendor budget.
  - Detached refresh workers and cross-process admission are not used on the app path.
- **One consent and admission value per generation.**
  - The app-server captures consent once per build and checks the generation again before it publishes a snapshot. This builds on FEEDFIX #295, which is in review.
  - Grants and revokes go through the app-server. A committed revoke bumps the generation, and older results are dropped.
- **Data ownership.**
  - The engine owns consent, readings, caches and history.
  - The app owns presentation preferences only.
  - Nothing the engine owns is written by the app, and nothing the app owns is written by the engine.
- **Standalone CLI unchanged.** `modelplan desktop --json` and the other commands keep working for plugins, the Skill and terminal use. `quota --json` stays byte-identical, which is a gate.

### Rows

- The row model, membership rules, total classifier, closed reason codes and privacy rules are exactly as in `rows-design.md` v4. Classifier rows 3 and 4 swap: a missing or retired tool comes before `no_reader`.
- The app-server pushes `rows/changed` with the full `Projection` on every change. History, cockpit and publication data are separate request methods, so a history decode failure never affects rows.
- `accountLocator`, `subscriptionRef` and all ids follow the rows privacy rules. No credential, path or provider text crosses the boundary.

### Swift client

- **Generated types.**
  - A Go generator in `cli/internal/appcontract` emits every protocol type and enum into one Swift file.
  - Unknown enum values decode as `.unknown(String)`.
  - Hand-written decoders for engine data are deleted.
- **Decode isolation by feature.**
  - Each notification and response decodes on its own.
  - In a row, an unknown display value degrades to a neutral card that keeps its reason text.
  - A failed history page affects only the history view.
  - Identity and version errors are rejected explicitly.
  - "Zero rows" is only ever rendered from `rowsSummary.state = no_consent`.
- **No merge logic.** The Dock, the menu bar and the Settings subscriptions list read rows directly. Settings permission controls join rows by tool id to the consent facts returned by the app-server.
- **Deleted in the same wave the replacement lands:**
  - Dock rows and snapshot: `CommunityUnboundDockRows`, the row and category logic in `CommunityReaderReason`, and the Dock use of the `Projection` stale rule.
  - Tables and identities: the four tool-id canonicalisers, the five title tables and the guidance tables.
  - Transport and helpers: the per-command `CLITransport` paths for engine data, `onCanonicalInvalidated`, and the hand-written `PersonalSnapshot` engine types.

  There are no compatibility layers.
- **Diagnostics.** "Copy diagnostics" calls `diagnostics/get` and adds the app's own state (protocol version, last decode error class, engine restart count). The output is sanitized by the same rules as rows.

### Credentials

- **Identity.**
  - Test builds are signed with a local self-signed code-signing certificate. Create it with Keychain Access, Certificate Assistant, type "Code Signing". Keep it in the build Mac's login keychain with its private key.
  - The private key never enters a repository; the owner keeps a `.p12` backup.
  - The certificate is not set as system-trusted.
  - Replacing the certificate changes the identity, and users then re-approve once. Gatekeeper still treats the build as unidentified until Developer ID notarization.
  - L3 verifies that "Always Allow" survives two consecutive builds.
- **Read.**
  - The app reads only the fixed item `Claude Code-credentials`, with `SecItemCopyMatching`, off the main thread, with a bounded wait.
  - A canceled or denied result is a normal interactive state. It is never a permanent latch.
  - `/usr/bin/security` is no longer used.
- **Handoff.**
  - The app sends `credentials/provide { provider, accessToken, expiresAt }` over the app-server pipe.
  - The token never appears in argv, env, logs, crash reports, diagnostics or on disk, and the app never sends a refresh token.
  - The Go side keeps the token in memory, uses it for the fixed GET endpoints only, and drops it on expiry, revoke or process exit.
- **Grant flow.**
  - A Keychain grant in Settings triggers one foreground Keychain read only.
  - The remote quota request obeys the shared budget: it runs now if the vendor is due, otherwise at the next due time.
  - The foreground bypass in `readerstate.go` (#298) is removed.
- **OAuth-borrowing reads (O class).**
  - They are in the standard tier and are not pre-selected on first run.
  - Structural conditions:
    - GET only, to endpoints fixed in code;
    - no refresh function reachable from the reader interface;
    - stop on 401 or 403 and mark the row `needs_action` without retrying with other parameters;
    - the source is shown on every row;
    - each vendor can be switched off remotely and revoked.
  - They become pre-selected only after two beta cycles with no credential incident and a re-review, and only by owner decision.

### Native shell

- **Ported from Pulse** (pinned commit, file by file, Apache-2.0 headers and NOTICE kept):
  - `PanelScreen`, `ActiveDisplayFollower`, `PanelPointerWatcher`, `PointerEntryReporter`;
  - the logic of `PanelPlacement`: the edge and dock model, `dragDock`, ratios, offsets and ratio + display-UUID persistence;
  - the `FloatingPanel` event ownership and the place / order-front / place-again technique;
  - `LoginItem`, without the default-on first run.
- **Not taken from Pulse:**
  - the SwiftUI-held hover state;
  - providers, the private appearance selector, `BotMark`, `DropletTether` and `DockPresence`'s `AppSettings` coupling;
  - Pulse's update stack.
- **Hover, reveal, collapse and drag state** live in one AppKit controller that we own. It is driven by synthetic real input in tests, because Pulse only tests geometry.
- **Preferences.**
  - One app preference file, with a `schemaVersion` and a migration test per version.
  - The Dock placement keeps the saved edge separate from the actual edge.
  - Defaults: no file means the right edge of the main display. A corrupt file opens on the right, reports the error and is not overwritten. An unplugged remembered display falls back to the main display while the stored UUID is kept.
  - `doctor` and diagnostics print the preference file path the app actually uses.
- **Borrowed libraries:** Sparkle (already used), LaunchAtLogin-Modern and KeyboardShortcuts (MIT), each recorded in `docs/borrowed/`.

### Cockpit and porthole

- **Window and bundle.**
  - A native `NSWindow` hosts one `WKWebView` running the cockpit web bundle, built from the prototype code. Instruments, art, HUD and porthole live in that one page.
  - The bundle is loaded from the app bundle with no remote content. A non-persistent website data store is used for isolation.
- **Data bridge.** The native side forwards the same row and request payloads over one `WKScriptMessageHandler` channel. The page never talks to the engine directly.
- **Lifecycle.**
  - When the window is hidden or occluded, the page pauses animation.
  - Closing the window releases the `WKWebView`.
  - A hidden prewarmed page keeps open time at 0.3 s or less.
- **Porthole v1: no runtime 3D.**
  - Stills and ignition/entrance videos come from a reproducible offline pipeline in the repo: three.js scenes, a headless render script, and fixed inputs, versions and hashes.
  - The default setup always has a confirmed still, which a CI check enforces.
  - Unregistered setups show "No view for this setup yet".
- **Live 3D after v1** only behind a measured budget.
  - Measure on the lowest supported Mac: the 2D baseline, the 3D peak, 10 s and 60 s after unloading the scene (dispose plus `forceContextLoss`, keeping the page), after closing the window, and over 20 setup switches.
  - Count the app, Go, WebContent and attributable GPU increments without double-counting shared memory, plus CPU and energy.
  - The page falls back to stills automatically when the budget fails.
- **Animation** uses the prototype's existing stack. Rive is not introduced.
- **Native RealityKit entrance** comes after v1. SceneKit is not used.

### Official visuals

- Final, shipped, rights-clear runtime assets move to the public repo under the existing official-visuals licence, and public CI builds the official candidate. Editable sources stay private.
- The owner confirms the item list. Private ADR 0049 has the details.
- Baselines for visual comparison are owner-confirmed images with recorded hashes.

### Reader integration standard

The full standard is in [`docs/readers/integration-standard.md`](../readers/integration-standard.md). It covers the classification and tiers, the red lines and how each one is enforced, the reference index, the decision procedure, the card template, and the current paths for each tool. In summary:

- **Classify the read path, not the tool.**
  - Carrier: local JSON/log (L), SQLite (S), hook (J), owning-tool RPC (R), CLI output (D).
  - Authentication: borrowed OAuth (O), API key (K), browser session (C).
  - Plus whether the endpoint is official (A) or undocumented. Web scraping (W) is never used.
- **Red lines**, each enforced as a test or type, not as text:
  - no refresh or rewrite of another tool's tokens or config;
  - no persisted or copied credentials;
  - no inference calls;
  - at most one read per vendor per 5 minutes, with backoff, shared by CLI, plugins and app;
  - detection reads presence only and never scans browser data;
  - keyed hashes only;
  - source and time shown on every value;
  - fixed destinations, with no credential-carrying cross-domain redirect;
  - per-vendor circuit breaker;
  - never revoke the original tool's token.
- **Integration card.** Every new or repaired reader starts from `docs/readers/<tool>.md`:
  - the official source plus the two or three closest implementations, chosen among CodexBar, Pulse, Token Monitor, Tokei, ccusage, Tokscale, ClaudeBar and openusage;
  - for each: data meaning, auth ownership, candidate paths, side effects, known incidents, licence, failure recovery and test evidence.
  - Choose the most stable compliant path. If none complies, borrow ideas and pitfalls only, or mark the read path `not-read`.
  - Every pitfall becomes a synthetic fixture.
- **Licences.** MIT and Apache-2.0 code may be ported with attribution; Apache also needs NOTICE. Code with no licence file is not copied. Tokei, for example, states MIT only in its README.
- **First batch:** Claude, Gemini, Grok, Kimi, Kiro and Cursor. All of them failed on the owner's Mac.

### Borrowed code ledger

`docs/borrowed/<source>.md` records, for each borrowed module:
- the source repository and pinned commit;
- the files taken;
- the behaviour kept and the parts deliberately left out;
- the licence obligations;
- the target module;
- the upstream issues we know of.

A borrowing is done only when its real call chain is shown in the PR.

## Testing decisions

- **A good test drives a seam from the table above and asserts what the owner would see.** Tests do not assert internal call order or private state.
- **Every fix lands with a test that fails before the fix.**
- **Fixtures.**
  - `appcontract` generates real-binary captures for every state listed in `rows-design.md`.
  - It adds the respin5 cases: `spent.model` omitted, null and present; a Keychain-only Claude; a legacy `connections.json`; a retained left placement; a corrupt preference file.
- **Owner-shaped home.** A generator builds a synthetic HOME from the owner's sanitized shape export (H40). The export is refreshed before each beta. It runs in the e2e job for every PR touching `cli/` or `desktop/native/`.
- **Decode mutation tests.** For each fixture, drop, null and retype every optional field in turn. The Dock must never render zero rows unless the summary is `no_consent`.
- **Visual comparison.**
  - Native Dock cards, the sliver and the key are rendered offscreen at 1x and 2x, in both themes.
  - The cockpit is screenshotted in headless Chrome at every supported size and language.
  - Both compare against owner-confirmed baselines, with a per-surface tolerance.
- **Real-input shell tests** cover hover reveal and collapse, drag to each edge, display unplug and replug, and relaunch persistence. They run on macOS CI where possible, and in the M1 checklist otherwise.
- **Prior art:**
  - the e2e journey (#281, #290);
  - the appcontract captures (#275, #285);
  - the rows oracle table test (on #299);
  - the H37 invariants.

## Delivery

Units are vertical slices with blocking edges. They become tickets after this document's review (`to-tickets`).

| Unit | Delivers | Blocked by | Owner |
|---|---|---|---|
| U1 Rows core | Classifier, mapping, membership, oracle tests (#299) | — | CLIJIT |
| U2 Consent fence and reader state | #295, #294, plus the D5 budget fix | U1 types | FEEDFIX, READERS |
| U3 app-server skeleton | `initialize`, `rows/changed`, `consent/*`, `diagnostics/get`, restart and handshake tests | U1 | CLIJIT |
| U4 Generated Swift client | Generator, client, decode isolation, mutation tests | U3 schema | CLIJIT + M0 |
| U5 Shell from Pulse | Placement, controller, preferences v1 and migration, real-input tests | — | M0 |
| U6 Dock and menu on rows | Render rows, delete the merge code, owner-shaped e2e | U4, U5 | M0 |
| U7 Keychain identity | Self-signed signing in packaging, Security.framework adapter, `credentials/provide` | U3 | M0 + CLIJIT |
| U8 Settings on app-server | Consent UI (O not pre-selected), revoke including undetected tools, diagnostics | U4 | M4 |
| U9 Official visuals public | Asset move, public official build, visual baselines | owner list | M2/M3 |
| U10 First candidate | Package, L1/L2, 5-min smoke, integrated review, L3 | U6, U7, U8, U9 | M0, M1 |
| U11 Cockpit web | Bundle, bridge, lifecycle, headless visual tests | U3, U9 | Cockpit lane |
| U12 Prerendered porthole | Offline pipeline, default-still CI check | U9 | Cockpit lane |
| U13 v1 candidate | U10 plus U11 and U12, upgrade and wake checks, L3 | U10, U11, U12 | all |

Estimated from design freeze (about 10-30): the first candidate (U10) in 5–8 working days, about 11-07 to 11-13; v1 (U13) in 10–15 working days, about 11-14 to 11-25. This assumes:
- no new tools are added;
- the visuals are already approved;
- the lanes and the Mac GUI slot are available;
- existing readers are reused.

The estimate is redone after U3 and U6.

## Process

- **Lanes.**
  - Mac: three development lanes (shell and integration M0, Settings M4, cockpit web) plus M1 as the sole real-Mac verifier, who writes no feature code.
  - The engine, app-server and readers belong to the local CLI lanes.
  - At most two strongly coupled tasks are active at once.
  - The GUI slot is exclusive and capped at 300 s per run.
- **Interfaces first.**
  - A cross-lane change starts from a reviewed interface: a type sketch or schema.
  - No contract PR is accepted without its consumer.
  - PR titles state the stage, for example "interface only" or "wired".
  - Each brief names its acceptance tests and the environments they run in.
- **Proof levels and review tiers:** see [ADR 0006](../adr/0006-proof-levels-and-review-tiers.md).
- **Coordination.**
  - Requests are event-driven: lanes start with `question:` or `coordinator request:`.
  - A versioned default table, `docs/agents/defaults.md` in the private repo, holds rules. Each rule comes from a real past ruling.
  - A reversible item with no answer in 30 minutes takes its default and goes into the candidate's change report. An irreversible item escalates to the owner after 4 hours.
  - Work is dispatched with `herdr agent prompt`, never by simulated typing.
- **Briefs** follow `writing-for-agents`: every step has a checkable completion criterion.

## Out of scope

- Windows support.
- Live 3D and the RealityKit entrance in v1.
- New tools or readers before v1, except repairs in the first batch.
- Moving the scoring or production pipeline into the public CLI.
- Compatibility with released app builds before the official release.

## Risks

- **Engine.** The app-server is a new long-lived process. Crash handling, restart and log hygiene must be right from the first slice.
- **Credentials.** A self-signed identity does not guarantee that the prompt never returns. If L3 shows prompts on every update, the fallback is to accept one prompt per update until Developer ID.
- **Pulse.** Pulse has a single maintainer and its Panel code changes often. We port and own the code, so upstream fixes need manual review.
- **Cockpit.** A web cockpit adds a WebContent process when open. The prewarmed page must stay within the memory measured in U11.
- **Fixtures.** Owner-shaped fixtures are only as good as the latest shape export. Refresh it before every beta.
