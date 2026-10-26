# App integration boundary

This package composes the existing Settings package and native products from above. The native root must not depend back on the standalone Settings package, which already depends on its Dock product. No dependency is added to either existing package and no private checkout is needed.

`SettingsApplicationCoordinator` owns one editor over the app-injected `SettingsStore`. A retained native Settings window may use that same editor. Its `onChange` callback remains available for window refresh; the coordinator owns `onCommit` and `onEnvironmentChange`. Do not replace those two callbacks or create another store for the same file.

One main-actor application closure receives immutable revision-tagged transactions. Successful persistence comes before commit delivery. Receipts older than the editor's known snapshot or the latest forwarded revision are discarded. Environment changes may apply at the same revision without writing preferences. Context changes carry current subscriptions even when no preference changes. Reentrant environment observations are serialized and coalesced after the current application callback.

Every other app writer must return through `reload()` after its successful commit; this adapter is not an automatic store observer. A restore/environment/context transaction is not consent or a login/reader/notification/updater-service intent. The host's application closure is responsible for actual consumer updates and error reporting; forwarding a transaction is not proof its drawing succeeded. `dockReading` exercises the existing quota projection with the committed pin/display mode and remaining-based critical threshold; it does not implement another ranking or projection engine.

## Settings window host

Retain one `SettingsWindowHost` over that application coordinator. Its native adapter lazily retains one existing `SettingsWindowController` using the same editor. `action` supplies a weak action for a gear/button; `menuItem(title:)` routes a localized menu item and reserved Command-comma to the same host. `present(paneID:)` supports a direct user action with an optional pane. Newer requests supersede older asynchronous preparation, and the host rechecks lifecycle eligibility before constructing/ordering a window. Preparation may reload the editor, so the host forwards the latest committed snapshot again before showing it.

Supply the native lifecycle's `canPresent` and call `suspend()` on presentation loss. Suspension retires even a queued menu/button action and orders an existing window out; resumption alone never reopens it. The host activates only for a user-initiated open and does not invent a fullscreen/Space/permission rule. An injected environment closure is authoritative for the whole environment. Without one, default read-only OS UI observations merge into the editor’s current environment and preserve app-owned fullscreen and entrance-acceptance fields. Locale/subscription context stays on the shared editor. Restoring or opening Settings is not service consent.

`SettingsWindowSurface` is the small asynchronous preparation/synchronous-ordering seam. The shipped adapter uses M4's unchanged native controller; tests use a fake surface and never instantiate/order a real window. Both cross the same lifecycle and revision checks.

The integrated Community entry below retains this host and attaches its actual Settings menu action; services remain unchanged. Actual Dock/Cockpit redraw/density, the Instruments hint arbiter/scheduler/overlay/persistence bridge and displayed/physical acceptance remain open. No official resource is added and no native window is opened by the tests. Whole-batch and next-batch gates remain unchanged.

Verification: `swift test --package-path desktop/native/ModelPlanAppIntegration --scratch-path <owned-path> --jobs 2` and `node scripts/check-source-policy.mjs`.


## Integrated Community entry

`ModelPlanCommunityApp` is the upper executable used by `package-neutral.sh`; its shared root `ModelPlanCommunityHost` owns the existing delegate/runtime/probe implementation once. The legacy root executable remains available with the same explicit probes and no injected Settings. Normal integrated launch creates one app-owned SettingsStore at Application Support/ModelPlan/Native/settings-v1.json and one application/window host, restores preferences without opening a window, and inserts the actual retained Settings status action and a main-application-menu copy for Command-comma. Both target the same host; the status item is not reparented. Probe modes skip Settings initialization. Malformed/unavailable preferences disable Settings instead of overwriting them or showing raw paths. Shared lifecycle presentation loss suspends pending Settings opens; resume never opens that window automatically.

Explicit gear/tray/Command-comma entry uses `.userInitiated`, activates immediately before show after eligibility checks, and validates again after activation reentrancy. `.restoration` and default `.programmatic` presentation do not activate. Tests inject a no-op/recording activation and fake window surface; they never activate an app or order a real window. The integrated entry applies committed app theme only, including clearing an override for System; it performs no service, reader, updater or consent action.

The packaging script now selects this executable, keeping the final bundle executable name and existing pinned-helper checksum and ad-hoc packaging procedure. No packaging/signing command is run by these tests. CI builds and archives the new executable alongside the legacy one, with macOS14 deployment metadata; it does not launch the integrated app. Actual Dock/Cockpit quota/size/density consumers and H11 single-arbiter/scheduler/overlay/persistence wiring remain separate engineering work. Physical/visual proof remains on the B25 list.

## Instrument hint source lifetime (P09 work in progress)

`InstrumentHintSourceRouter` binds each live Instruments callback to an ephemeral generation and re-resolves view-local travel/pointer state before trial admission and again at the app deadline. Replaced/removed sources cannot cancel a replacement rest; real keyboard/down/focus-loss input from a live surface can cancel pending rest. Repeated stationary candidates keep the existing arbiter deadline.

The injected receiver is the app's **existing single** `FirstUseHints` owner. This adapter owns no hint policy, timer, overlay, preferences file or seen flags. It validates source lifetime and geometry only; after a real successful `confirmShown`, call `didConfirmShown` to retire pending source bookkeeping. The app host must call `cancelPendingRest` alongside arbiter context/lifecycle/reset transactions, even when it retains live view bindings. The full serialized scheduler/overlay/persistence host and actual app/view binding are still pending and are not claimed delivered by this source adapter. No native window, permission or system operation is performed.
