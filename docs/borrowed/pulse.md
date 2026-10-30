# Pulse shell intake (U5, interface only)

Pinned upstream: qunqin24/Pulse v1.12.4, commit `7668384cbcf357bba7dee4af85b4052a59c6e35d`. The four files in `Sources/ModelPlanShell/Pulse` are copied byte-for-byte from `Sources/Pulse/Panel`, retaining their Apache-2.0 copyright headers. `pulse/LICENSE` retains the full license. The pinned tree has no file named NOTICE; its third-party notices are retained as `pulse/UPSTREAM_THIRD_PARTY_NOTICES.md` for provenance, without claiming those unrelated components were ported. Its trailing whitespace is normalized; the original and adapted digests are both recorded. `pulse/manifest.json` binds the copied files.

## Reviewed first slice

- PanelScreen: display UUID lookup and pure notch geometry; no provider/settings dependency.
- ActiveDisplayFollower: one cancellable pointer-sampling timer, PanelScreen lookup, no accessibility window scanning.
- PanelPointerWatcher and PointerProbe: local view/window-coordinate sampling with teardown and one explicit reprobe; no provider/settings dependency.
- PointerEntryReporter: activeAlways local tracking-area entry, paired with the sampler for exit decisions.

These are not yet wired to the production controller. Copying them does not prove real-event delivery or L2. The integrated controller must own hover/reveal/collapse/drag and produce event-arrival evidence through the versioned runner.

## Placement adaptation

PanelPlacement is now adapted from the same pinned source, with a prominent modification notice. It retains the rail-based geometry, edge/axis model, ratios and default-right behavior. Persistence is an injected value callback to the one ModelPlan store; it no longer reads/writes UserDefaults. Card gap is caller-owned and unused liquid visual state is removed. Seven pure tests cover default right, explicit left, a negative-origin display, preview versus commit persistence, preserved missing-display UUID, ratio round-trip and injected card gap. These tests use the production source bytes but are not window/input or integrated-store proof.

## Remaining reviewed intake

FloatingPanelController still contains AppSettings, PanelIntent, fixed layout and DropletTether coupling. Port only placement/state and event/ordering mechanisms behind ModelPlan-owned sizes/preferences; do not import the visual tether or providers. DockPresence needs its AppSettings dependency removed. LoginItem's upstream automatic registration, LaunchAgent migration and path-repair routines are not adopted; the ModelPlan preference default remains ON under product policy, without executing an OS effect in migration. The private appearance selector, provider code, BotMark, DropletTether and update stack are excluded.

## Completion boundary

M4 supplies the separately owned, product-identity-keyed migration candidate; M0 integrates one atomic no-replace destination store. Existing paths remain until the replacement call chain, packaged synthetic-profile L2 and historical regression scenarios pass. The first-run/right, explicit-left, retained/corrupt preferences, actual/saved edge and real-input checks belong to U5; physical/display limitations remain explicit. No owner L3 or real-account input is used here.

## Wired panel event slice

The normal companion factory retains StaticDockPreviewHost; its Dock-only makePanel route now constructs PulseDockPanel. Card and outline panels are unchanged. The borrowed window-level down/drag/up transaction delegates to the existing painted-region/lifecycle gates, falls through for controls/control-click, and cancels capture when hidden. The panel cannot become key/main, and its optional numeric-only arrival callback does not log input contents. No upstream private appearance selector is present.

Eleven pure source tests cover placement, input capture/release/cancel, control exclusion and asymmetric-notch/null cases. These are not actual native event delivery. The final unified shell/controller, follower/sampler/entry L1 behavior coverage, migration-store integration and real-input/package L2 remain pending. This slice does not close U5 or an owner report.
