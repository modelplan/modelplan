# App integration boundary

This package composes the existing Settings package and native products from above. The native root must not depend back on the standalone Settings package, which already depends on its Dock product. No dependency is added to either existing package and no private checkout is needed.

`SettingsApplicationCoordinator` owns one editor over the app-injected `SettingsStore`. A retained native Settings window may use that same editor. Its `onChange` callback remains available for window refresh; the coordinator owns `onCommit` and `onEnvironmentChange`. Do not replace those two callbacks or create another store for the same file.

One main-actor application closure receives immutable revision-tagged transactions. Successful persistence comes before commit delivery. Receipts older than the editor's known snapshot or the latest forwarded revision are discarded. Environment changes may apply at the same revision without writing preferences. Context changes carry current subscriptions even when no preference changes. Reentrant environment observations are serialized and coalesced after the current application callback.

Every other app writer must return through `reload()` after its successful commit; this adapter is not an automatic store observer. A restore/environment/context transaction is not consent or a login/reader/notification/updater-service intent. The host's application closure is responsible for actual consumer updates and error reporting; forwarding a transaction is not proof its drawing succeeded. `dockReading` exercises the existing quota projection with the committed pin/display mode and remaining-based critical threshold; it does not implement another ranking or projection engine.

## Settings window host

Retain one `SettingsWindowHost` over that application coordinator. Its native adapter lazily retains one existing `SettingsWindowController` using the same editor. `action` supplies a weak action for a gear/button; `menuItem(title:)` routes a localized menu item and reserved Command-comma to the same host. `present(paneID:)` supports a direct user action with an optional pane. Newer requests supersede older asynchronous preparation, and the host rechecks lifecycle eligibility before constructing/ordering a window. Preparation may reload the editor, so the host forwards the latest committed snapshot again before showing it.

Supply the native lifecycle's `canPresent` and call `suspend()` on presentation loss. Suspension retires even a queued menu/button action and orders an existing window out; resumption alone never reopens it. The host does not activate the app or invent a fullscreen/Space/permission rule. An injected environment closure is authoritative for the whole environment. Without one, default read-only OS UI observations merge into the editor’s current environment and preserve app-owned fullscreen and entrance-acceptance fields. Locale/subscription context stays on the shared editor. Restoring or opening Settings is not service consent.

`SettingsWindowSurface` is the small asynchronous preparation/synchronous-ordering seam. The shipped adapter uses M4's unchanged native controller; tests use a fake surface and never instantiate/order a real window. Both cross the same lifecycle and revision checks.

The running Community entry point, packaging and services remain unchanged: an app entry point still has to retain this host and attach its actions. Actual Dock/Cockpit redraw/density, the Instruments hint arbiter/scheduler/overlay/persistence bridge and displayed/physical acceptance remain open. No official resource is added and no native window is opened by the tests. Whole-batch and next-batch gates remain unchanged.

Verification: `swift test --package-path desktop/native/ModelPlanAppIntegration --scratch-path <owned-path> --jobs 2` and `node scripts/check-source-policy.mjs`.
