# Pulse shell integration (U5)

Pinned upstream: qunqin24/Pulse v1.12.4, commit `7668384cbcf357bba7dee4af85b4052a59c6e35d`. The first four files were copied from `Sources/Pulse/Panel`; original Apache-2.0 copyright headers remain. Adapted files carry modification notices, with original/adapted hashes and upstream paths in `pulse/manifest.json`.

`pulse/LICENSE` retains the full license. The pinned tree has no literal NOTICE file. Its third-party notices are retained as `pulse/UPSTREAM_THIRD_PARTY_NOTICES.md` for provenance, without claiming unrelated components were ported; trailing whitespace alone is normalized, with both hashes recorded. The distribution catalog has a separate `pulse-native-shell` entry at this pin, covering all eight Swift files and the original license/third-party attribution bytes. The older Kiro reader port retains its separate pin.

## Modules and ownership

- PanelScreen provides display identity and pure notch geometry.
- ActiveDisplayFollower supplies pointer-defined active-display observations without application/window scanning.
- PanelPointerWatcher samples flipped local coordinates, deduplicates small movements and supports explicit reprobe/stop. PointerProbe is linked by the production composition for immediate entry-time queries and reprobing.
- PointerEntryReporter installs one activeAlways/inVisibleRect tracking area; entry is paired with sampling instead of trusting exits.
- PanelPlacement retains the rail-based geometry, edge/axis model, ratios and default-right behavior. It uses an injected saved-placement callback instead of UserDefaults, takes a caller-owned card gap and omits unused visual state.
- PulseDockPanel adapts the pinned FloatingPanelController's non-key window and window-level down/drag/up transaction. It falls through for controls/control-click and cancels capture when hidden. The optional input-arrival observer contains only event type/timestamp and has no production subscriber.

- PulseDockPresence adapts the weak, shared owner of Settings/cockpit Dock-icon presence, with injected application effects and no AppSettings dependency. DockQuit interception is omitted.
- PulseLoginItem retains only the modern app-bundle SMAppService route behind an injected service; no first-run default registration, LaunchAgent fallback, adoption or path repair is imported.

No private appearance selector, provider, visual tether, BotMark or update stack is imported. AppSettings is not a dependency of these ported files. Package dependencies are unchanged by the wiring slices.

## One controller on the normal entry

The normal companion factory retains StaticDockPreviewHost. Its Dock-only panel uses PulseDockPanel; card and outline panels remain separate. Input delegates to the existing painted-region/lifecycle gates. One DockEdgeController owns hover/reveal/collapse deadlines, press/drag/release state and the sole placement commit.

The host supplies PulseDockPositioning for initial placement, nearest-edge preview and release. ModelPlan retains validation, exposed-edge selection, adjoining-display exclusion, system-Dock avoidance and registered-anchor clamping. The selected display/edge/anchor then goes through the borrowed PanelPlacement for the window frame; sliver and wake registration translate with it. The edge-only facade preserves the existing Settings centre-fraction meaning when converting to Pulse's top-to-bottom available-travel ratio. Cards have their own window, so rail and panel use the Dock size without an upstream card envelope. Automatic recovery changes actual placement only, never saved UUID/edge intent.

The live follower starts only while permitted, shown and configured to follow. It samples the host's existing display/pointer environment and supplies an observed display without writing Settings. A held background press, including the interval before movement, refuses switching and retries afterward. Fixed mode, suspension and retirement stop the follower; topology changes forget the last observation and reprobe.

## Sampler and entry composition

The host mounts one transparent PulsePanelPointerSurface behind the active expanded or sliver content. It composes the borrowed sampler and entry reporter. Its hitTest always returns nil, it adds no accessibility element or click-catching region, and its observers resize with content bounds. Entry uses the linked PointerProbe.current to sample fresh coordinates between timer ticks, with PointerProbe.reportAgain resetting deduplication even after an already absent value. Reparenting also reprobes through that same object. Ordinary timer samples remain deduplicated.

Callbacks invalidate observation through the same controller. They do not reveal/collapse directly or presume nil means outside: the controller reads fresh global pointer, wake and separate-card facts and retains dwell/grace deadlines. Suppression, suspension and retirement stop sampling and ignore late entry/sample work. Reparenting between sliver and expanded content resets sample memory. No global input monitor, new window, persistence or second visibility state machine is added.

## Validation and completion boundary

Twenty-seven pure Pulse cases pass: placement/persistence/defaults, negative-origin and missing-display intent, notch cases, input capture/release/cancel, follower refusal/retry/stop, sampler/reprobe/teardown composed entry/click-through behavior, weak multi-window presence/closing and focus policy, and explicit login requests with observed approval/failure/unsupported states. Fifteen actual no-window Host/controller regressions pass: positioning/anchors/topology, preview/release/stop, live follow/held-press refusal, entry-driven dwell/reveal and sampler-driven grace/collapse, plus lifecycle shutdown without Settings changes.

A compiled negative control for the earlier positioning slice made the Pulse facade return no frame and caused the actual Host wake test to fail; restored source passed. Current sampler/entry checks use synthetic local/global points and direct local event objects, without posting input. Source policy, borrowed manifest, catalog license digests, vendored coverage and generated-notice consistency pass.

**Not-run:** native coordinate conversion and OS event delivery, real-input/restart/migration/package L2, and owner L3. Source wiring and local event objects do not prove those outcomes.

The presence/login adapters described below are a staged source slice. The atomic field-group backend now lives in the existing SettingsStore actor; remaining U5 source integration includes selecting that store and its Core port together on the normal entry, and consuming the staged service adapters. LoginItem's upstream automatic registration, LaunchAgent migration and path repair are not adopted; ModelPlan's preference default remains ON without executing an OS effect during migration. Migration must preserve old files and unmatched row intent, report corrupt-source/target recovery and never promote app-side readerConsent to engine consent. Existing paths remain until replacement call-chain, synthetic packaged L2 and historical regressions pass. No owner issue is declared fixed by these source slices.


## Reviewed presence/login service adapters

PulseDockPresence keeps one weak registry of visible or minimized full windows. Closing one excludes it before its isVisible flag changes, so another tracked window keeps Dock/Command-Tab presence. The icon preference and application effects are injected; tracking/construction do not change activation policy. Restored/programmatic presentation does not activate by default. Only an explicit user-presentation owner may request reactivation. No quit/logout interception or process-sender inspection is ported.

PulseLoginItem never registers during construction, observation or restoration. Bare executables and notFound services are unsupported; there is no fallback file writer. An explicit user choice or accepted first-run completion may request the modern service. Approval-required is not converted to enabled or retried automatically; errors return the newly observed state. ModelPlan's existing openAtLogin default remains true in its Settings store, separate from service observation and effects.

CommunityLoginServiceAdapter consumes a canonical SettingsHostRequest only when its revision and saved choice still match. Its effect authorization defaults false. Authorized requests are consumed at most once per revision; stale/replayed and unrelated requests cannot execute a login effect. It maps service facts back to LoginServiceState without editing the preference file or replacing the editor's one onHostRequest receiver. Three tests use actual editor/first-run commit requests and fake service effects; they prove default-on/no-registration, host authorization, revision/replay checks, observed requiresApproval and no rewrite after the native effect.

**Normal-entry integration remains pending.** The entry owner should retain one presence owner, track only Settings/cockpit full windows, and apply it at show/minimize/close/suspend transitions. It should forward accepted login requests from its existing system-effect receiver to the adapter with the current snapshot and explicit host authorization, then refresh observed capabilities separately. Unhandled requests still belong to their existing consumers. No entry ownership is taken by this slice, and no real activation/login-item operation, native GUI or L2 is executed by its tests.


## Production caller condition

The unconditional normal caller chain is `ProductionDockFactory.community` → `StaticDockPreviewHost.present` → `bindPointerInput` → `PulsePanelPointerSurface`. The native-panel branch mounts the same surface behind its real expanded/sliver content; the no-window test branch exercises that same binder separately. The surface owns `PanelPointerWatcher.WatcherView`, `PointerEntryReporter.TrackingView` and the linked `PointerProbe`; entry uses both probe current/reprobe methods and changed samples refresh the existing controller.

Unused SwiftUI NSViewRepresentable wrappers were removed from the two adapted files. Their remaining AppKit implementation has production consumers rather than being retained solely for tests. A focused entry test changes the synthetic point between timer ticks and requires the fresh linked-probe result. A compiled negative control temporarily disconnecting that production probe link fails the freshness assertion; exact source restoration returns all 27 pure cases to pass. These source consumers do not establish actual OS input delivery; the declared real-input L2 is still required.


## Atomic preference backend

The unchanged pure FoundationSettingsMigration planner is now consumed by the existing SettingsStore's explicit foundation initializer. A schema-v1 settings/core document is published from a bounded, fully written private stage using no-replace linkat. Existing valid targets skip legacy reads; invalid targets recover to read-only right-edge defaults without replacement. Settings and Core updates use one actor, a local transaction lock, a prior-byte/directory identity check and complete-file replacement. Old profile files and unmatched row intent remain untouched, and app-side readerConsent cannot be persisted as an engine grant.

Fourteen new file/store/editor cases and 48 affected legacy cases pass (62 total), including coexistence, corrupt-source/target recovery, no-replace publication races, failed staging, busy locks, symlinks, stale writers and settings/Core preservation. Eighteen affected no-window Host/login integration cases also pass. The detailed API and normal-entry handoff are in `desktop/native/ModelPlanSettings/FOUNDATION-STORE.md`. This is a source/backend milestone: Settings and Core must switch together in the entry owner's integration before packaged migration/restart L2, and the old path is retained until acceptance.
