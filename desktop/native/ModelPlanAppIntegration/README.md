# App integration boundary

This package composes the existing Settings package and native products from above. The native root must not depend back on the standalone Settings package, which already depends on its Dock product. No dependency is added to either existing package and no private checkout is needed.

`SettingsApplicationCoordinator` owns one editor over the app-injected `SettingsStore`. A retained native Settings window may use that same editor. Its `onChange` callback remains available for window refresh; the coordinator owns `onCommit` and `onEnvironmentChange`. Do not replace those two callbacks or create another store for the same file.

One main-actor application closure receives immutable revision-tagged transactions. Successful persistence comes before commit delivery. Receipts older than the editor's known snapshot or the latest forwarded revision are discarded. Environment changes may apply at the same revision without writing preferences. Context changes carry current subscriptions even when no preference changes. Reentrant environment observations are serialized and coalesced after the current application callback.

Every other app writer must return through `reload()` after its successful commit; this adapter is not an automatic store observer. A restore/environment/context transaction is not consent or a login/reader/notification/updater-service intent. The host's application closure is responsible for actual consumer updates and error reporting; forwarding a transaction is not proof its drawing succeeded. `dockReading` exercises the existing quota projection with the committed pin/display mode and remaining-based critical threshold; it does not implement another ranking or projection engine.

This first integration increment does not change the running Community app entry point, menus, packaging, services or official resources. It does not yet attach actual Dock/Cockpit views, route gear/menu/Command-comma, instantiate the Settings singleton, or connect the Instruments hint inputs to the one arbiter/timer/overlay. Those app-host integrations and displayed/physical acceptance remain open. No native window is opened by this package or its tests. Whole-batch and next-batch gates remain unchanged.

Verification: `swift test --package-path desktop/native/ModelPlanAppIntegration --scratch-path <owned-path> --jobs 2` and `node scripts/check-source-policy.mjs`.
