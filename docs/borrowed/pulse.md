# Pulse shell integration (U5)

Pinned upstream: qunqin24/Pulse v1.12.4, commit `7668384cbcf357bba7dee4af85b4052a59c6e35d`. The first four files were copied from `Sources/Pulse/Panel`; original Apache-2.0 copyright headers remain. Adapted files carry modification notices, with original/adapted hashes and upstream paths in `pulse/manifest.json`.

`pulse/LICENSE` retains the full license. The pinned tree has no literal NOTICE file. Its third-party notices are retained as `pulse/UPSTREAM_THIRD_PARTY_NOTICES.md` for provenance, without claiming unrelated components were ported; trailing whitespace alone is normalized, with both hashes recorded. The distribution catalog has a separate `pulse-native-shell` entry at this pin, covering all six Swift files and the original license/third-party attribution bytes. The older Kiro reader port retains its separate pin.

## Modules and ownership

- PanelScreen provides display identity and pure notch geometry.
- ActiveDisplayFollower supplies pointer-defined active-display observations without application/window scanning.
- PanelPointerWatcher samples flipped local coordinates, deduplicates small movements and supports explicit reprobe/stop. PointerProbe remains the borrowed immediate-query helper.
- PointerEntryReporter installs one activeAlways/inVisibleRect tracking area; entry is paired with sampling instead of trusting exits.
- PanelPlacement retains the rail-based geometry, edge/axis model, ratios and default-right behavior. It uses an injected saved-placement callback instead of UserDefaults, takes a caller-owned card gap and omits unused visual state.
- PulseDockPanel adapts the pinned FloatingPanelController's non-key window and window-level down/drag/up transaction. It falls through for controls/control-click and cancels capture when hidden. The optional input-arrival observer contains only event type/timestamp and has no production subscriber.

No private appearance selector, provider, visual tether, BotMark or update stack is imported. AppSettings is not a dependency of these ported files. Package dependencies are unchanged by the wiring slices.

## One controller on the normal entry

The normal companion factory retains StaticDockPreviewHost. Its Dock-only panel uses PulseDockPanel; card and outline panels remain separate. Input delegates to the existing painted-region/lifecycle gates. One DockEdgeController owns hover/reveal/collapse deadlines, press/drag/release state and the sole placement commit.

The host supplies PulseDockPositioning for initial placement, nearest-edge preview and release. ModelPlan retains validation, exposed-edge selection, adjoining-display exclusion, system-Dock avoidance and registered-anchor clamping. The selected display/edge/anchor then goes through the borrowed PanelPlacement for the window frame; sliver and wake registration translate with it. The edge-only facade preserves the existing Settings centre-fraction meaning when converting to Pulse's top-to-bottom available-travel ratio. Cards have their own window, so rail and panel use the Dock size without an upstream card envelope. Automatic recovery changes actual placement only, never saved UUID/edge intent.

The live follower starts only while permitted, shown and configured to follow. It samples the host's existing display/pointer environment and supplies an observed display without writing Settings. A held background press, including the interval before movement, refuses switching and retries afterward. Fixed mode, suspension and retirement stop the follower; topology changes forget the last observation and reprobe.

## Sampler and entry composition

The host mounts one transparent PulsePanelPointerSurface behind the active expanded or sliver content. It composes the borrowed sampler and entry reporter. Its hitTest always returns nil, it adds no accessibility element or click-catching region, and its observers resize with content bounds. Entry forces another sample even after an already absent value; ordinary samples remain deduplicated.

Callbacks invalidate observation through the same controller. They do not reveal/collapse directly or presume nil means outside: the controller reads fresh global pointer, wake and separate-card facts and retains dwell/grace deadlines. Suppression, suspension and retirement stop sampling and ignore late entry/sample work. Reparenting between sliver and expanded content resets sample memory. No global input monitor, new window, persistence or second visibility state machine is added.

## Validation and completion boundary

Nineteen pure Pulse cases pass: placement/persistence/defaults, negative-origin and missing-display intent, notch cases, input capture/release/cancel, follower refusal/retry/stop, sampler/reprobe/teardown and composed entry/click-through behavior. Fifteen actual no-window Host/controller regressions pass: positioning/anchors/topology, preview/release/stop, live follow/held-press refusal, entry-driven dwell/reveal and sampler-driven grace/collapse, plus lifecycle shutdown without Settings changes.

A compiled negative control for the earlier positioning slice made the Pulse facade return no frame and caused the actual Host wake test to fail; restored source passed. Current sampler/entry checks use synthetic local/global points and direct local event objects, without posting input. Source policy, borrowed manifest, catalog license digests, vendored coverage and generated-notice consistency pass.

**Not-run:** native coordinate conversion and OS event delivery, real-input/restart/migration/package L2, and owner L3. Source wiring and local event objects do not prove those outcomes.

Remaining U5 source work is reviewed presence/login adaptation and field-group migration with one atomic no-replace destination store. LoginItem's upstream automatic registration, LaunchAgent migration and path repair are not adopted; ModelPlan's preference default remains ON without executing an OS effect during migration. Migration must preserve old files and unmatched row intent, report corrupt-source/target recovery and never promote app-side readerConsent to engine consent. Existing paths remain until replacement call-chain, synthetic packaged L2 and historical regressions pass. No owner issue is declared fixed by these source slices.
