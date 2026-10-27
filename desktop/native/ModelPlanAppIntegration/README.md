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

## Serialized first-use hint execution

`HintExecutionHost` owns one existing `FirstUseHints` arbiter, its `InstrumentHintSourceRouter`, one injected deadline scheduler and one token-addressed overlay. `HintCommonModeScheduler` reuses the existing finite common-mode timer implementation. Source rests and five-second expiry share that deadline; no view timer or historical hint queue is installed.

Restore through the same app-scoped `SettingsStore` (its `HintPreferenceWriting` conformance changes only `helpHints` using the captured revision). The writer serializes and coalesces actual open/reveal/confirmed-show ledger changes. I/O or stale-revision failures preserve the real in-memory seen/budget state and report an error; they do not reload and blindly retry onto a newer snapshot. Explicit retry keeps the same CAS revision. An unrelated Settings commit is only an observation floor, not permission to rebase old hint state.

Route the successful editor's revision-tagged `resetHelpHints` request to `applyCommittedReset`. It verifies the current snapshot from that same writer, fences old writes/late receipts with a separate epoch, and preserves flags on stale/uncommitted reset requests. This does not replace the Settings window's `onChange` observer. The composition owner must forward normal committed snapshots as revision floors and classify reset receipts explicitly.

The injected overlay must verify actual current anchor, placement and surface visibility in `showAndVerify` and `updateAndVerify`; geometry-only `onPresentation` is insufficient. Reentrant surface changes, disposal and stale timer/render callbacks cannot confirm an old offer or hide a new token. Reduced Motion updates keep the original expiry. None of these injected receipts establishes actual displayed UI or physical proof by itself.

This module is execution code, not completed live app composition. CommunityApp still needs one app-scoped host wired to current Dock/Cockpit inputs, the Help UI adapter and Settings receipt routing. Context/clock/source geometry, real overlay eligibility, scoped error reporting and subsequent stale-revision reconciliation remain explicit host responsibilities. No system service, capture, private drawing/copy package, CLI mutation or actual window launch is added. PR183 is the source-router dependency; merge it before this change.


## Concrete Help composition and typed Settings receipts

`InstrumentHelpComposition.restored(application:)` uses the existing coordinator/editor/store,
P10 arbiter/source router/common-mode deadline and one M4 `HelpUILayerView`. The CommunityApp
session retains one composition after restore; concurrent restore calls share its creation task.
The commit observer is installed before asynchronous restore and acknowledges any one in-flight
startup receipt before exposing the composition, so an intervening save cannot be missed.
It does not open a window or embed a cockpit. The actual cockpit host must embed `layer`, call
`update` with current session identity, overlay-local anchors, occupied live readings, map/RM
facts and injected released copy, and suspend/dispose it at the corresponding lifetime boundary.
Dock-only hints require the actual Dock surface binding and are not admitted by this cockpit layer.
Trial content also requires the matching P09 source snapshot paired with the converted overlay
anchor; unbound or replaced sources cannot point a trial offer at an arbitrary other fader.

The adapter checks token, current geometry, session and live AppKit window/view visibility after
M4 renders and after visibility callouts. A geometry receipt alone never confirms a hint. No-window,
replaced, hidden or unplaceable offers spend no flag/budget. This runtime check is not physical,
pixel or occlusion-proof acceptance. Tests inject visibility only for deterministic module regressions.
Layer actions/cancellations carry the current composition generation; source-view trial callbacks
still use their P09 leases. Map/context semantic actions remain callbacks to the owning surface.
No private hint wording, official visual recipe or persisted preferences field is added here.

`SettingsEditor.observeCommittedEdits` is an additive async receipt observer; neither the window's
`onChange` nor the coordinator's `onCommit` is replaced. Its receipt records the originating store,
exact before/after revisions and an explicit reset kind, including an already-empty reset. The save
boundary stays busy until observers acknowledge or a bounded delivery failure retires the consumer,
so another editor save cannot overtake an active reset consumer.
Only successful commits emit receipts. Hint writes refresh the same editor through the existing
coordinator, with coalescing reads rather than a second preference owner or timer.

A contiguous ordinary receipt can reconcile a stale hint CAS only if it belongs to the same store,
preserves the saved hint ledger and matches that actor's current exact revision/ledger. It fences
an older pending writer and preserves the in-memory shown ledger; a foreign receipt, skipped
revision, reset receipt or newer reset cannot authorize rebasing. Actual reset receipts continue
through P10's current-revision/empty-ledger/epoch checks. I/O failures are not cleared by ordinary
reconciliation. Full live Dock/Cockpit data, size/density rendering, official recipe/copy injection and
physical/appearance/performance acceptance remain separate work; no launch/signing/system effect
is performed by this composition increment.


## Bounded post-commit acknowledgment

All async Settings observers for one committed edit share a maximum two-second acknowledgment
limit; a shorter limit can be injected, without changing hint dwell/display timing. Completion of
all healthy observers, their explicit removal or the shared deadline releases `isSaving`. Observers
run concurrently so an unrelated stalled consumer cannot prevent the real reset consumer receiving
its receipt. This is an event-driven I/O acknowledgment deadline, not another hint admission timer.
Synchronous callbacks still must not block the main actor.

The commit has already succeeded before this boundary. A timeout therefore returns the actual saved
snapshot, records `lastCommitDeliveryFailure`, and shows “Settings saved, but some app views could
not update”; it does not throw a fake disk-save error or retry the saved edit. The failed registration
is disabled even if its old task eventually returns. Cancellation is requested but an uncooperative
observer is never awaited as the losing child of a structured race. At most its one outstanding task
is retained for that registration, rather than starting another stuck task on each later save.

A consumer with live effects must synchronously retire them in its registration's `onFailure` before
the next save can proceed; read-only observers may use the default no-op callback. The concrete Help
connection latches failures across startup, fences pending persistence epochs, disposes the old host/
layer and ignores late receipts before releasing that boundary. Historical in-memory seen/budget
truth is retained; an old writer cannot drain another pending write across a newer reset. A newly
restored replacement is independent of the failed connection. No automatic consumer re-enable,
preferences schema change, second store, repeat hint timer or system effect is introduced.


## Live community model/effort surface

The integrated Community entry now retains `CommunityInstrumentSurfaceProvider` instead of the
neutral summary panel provider. The shared root host forwards its existing `ModelSelectionRuntime`
result and actual publication timestamp to the optional `CommunityInstrumentSurface` seam. The
legacy root entry/probes keep their existing provider. No Settings/AppIntegration reverse dependency
is introduced into Shell or Instruments, and no second store, selector or score calculation is added.

The upper surface uses the existing native `MainScreenView` with a native model picker over the
complete ordered public catalogue. Selecting a model refreshes current feeds before using the action;
a removed target cannot be activated. Available exact comparisons reuse the existing controller;
without an exact revision/join, the public catalogue and published effort labels remain available.
Unknown usage, subscription and destination content is explicitly unavailable rather than fabricated.
Publication age metadata uses only the actual optional publication timestamp and rejects future dates;
connecting this metadata and website actions to the Option source corner remains separate work.

Committed language/theme changes reevaluate current source facts, and older Settings revisions cannot
restore stale drawing state. System theme continues to inherit the OS appearance. Settings Size is
Dock size, so it does not change this independent MainScreen profile. Recipe minimum dimensions are
prepared before publishing, and a render failure hides the prior bitmap and disables its picker.
Hidden/closed/lifecycle-suspended surfaces stop rendering and resume from current facts. A synchronous
size callback can reenter Settings/source delivery; queued rendering coalesces to the latest packet.

This is a real read-only model/effort view in the existing Community status action, not the complete
four-region cockpit or Dock. Full live overview/fader/engine/record/3D data, Dock size-density binding,
source-coordinate callbacks, Help layer embedding, official recipe/copy injection and physical,
appearance/performance acceptance remain open. The nine no-window module regressions exercise actual
native view/raster construction and compile/link the Community executable; they do not launch it or
prove physical input, pixel appearance, window visibility or minimum-system acceptance.

## Actual community contextual Help embedding

The Community session's existing `makeHelp` startup receipt fence supplies the same retained
`InstrumentHelpComposition` to the upper surface provider. That provider embeds its existing M4
layer above the real MainScreen. The binding keeps the composition weakly: the session owns its
lifetime, avoiding a composition/application/application-closure/provider cycle.

MainScreen's existing resolved `onHelpChange` supplies both explanation and source-local rectangle;
there is no second contextual dwell timer or legacy popover. The binding checks that explanation
and rectangle still belong to the current recipe, converts them with NSView into overlay-local
coordinates, and forwards real text/image/control/chart occupancy plus the sibling picker area.
The existing compact Help layout uses the actual container viewport; it does not assert the generic
community window is a 640-point cockpit or change the cockpit's frozen profile. Missing/unplaceable
space remains fail-closed. No frozen Option map placement is guessed from this generic view.

Suspend/close/source replacement removes contextual state. Held old source or dismissal callbacks
cannot alter the replacement composition, and a reentrant close during layer presentation cannot
restore old Help. Environment changes refresh the same layer. The generic catalogue supplies no
cockpit-open/Dock-reveal session, first-use copy, trial lease or offer, so contextual Help cannot
spend the first-use ledger/budget. Geometry-only presentation remains insufficient for physical or
visibility acceptance. Source-corner age/website actions, full Option map, Dock/fader and full cockpit
source binding, released private copy/recipe and physical/performance proof remain open.

Six new no-window regressions cover actual layer/coordinate binding, current-recipe validation,
lifecycle cleanup, stale callbacks, reentrant close and application/provider release. Together with
the eleven surface regressions they pass seventeen selected tests and compile/link CommunityApp.
This change depends on PR193; preserve merge order and exact-head external gates.

The Community entry also binds local Option modifier events to the same Help layer. Its neutral,
MainScreen-only map uses the current recipe's actual anchors and reading/control/plot exclusions;
when a free source-corner block cannot fit, no source controls are published and instruments do not move.
The primary control shows actual publication age or an explicit unknown plus About, while the optional
second control opens the published data-source link. Missing/future/non-finite publication dates stay unknown.
No extra clock, dwell policy, first-use offer or seen/budget write is introduced. Escape, Option release,
hide/close and replacement publication retire old actions; only current presented controls may call the
injected public website opener. CommunityApp supplies the HTTPS modelplan.ai opener after user actions;
headless tests inject a recorder and never open a browser. Existing comparison website intents use the same
current-link fence. This partial community map is not the complete Cockpit/Dock map or physical/appearance
acceptance, and it does not change the MainScreen profile or chart heights.
