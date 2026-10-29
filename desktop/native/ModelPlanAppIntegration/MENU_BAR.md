# Native menu bar

The real `CommunityApplicationFactory.makeDelegate` supplies `CommunityMenuBarProjector` and the existing MIT tray template to the root host. `CommunityDelegate.render` updates the retained status item from the same store completion as the Dock and overview; it creates no new store, reader or timer.

Selection uses `CommunityDockSnapshot` and `DockInstrumentProjection`, then takes the minimum original remaining percentage before formatting the title as a rounded integer percentage. The menu keeps the full Dock readout for that same row. Unknown, expired, future-observed and failed readings are excluded by those existing Dock rules. No current reading means icon only. The disabled first menu item names the selected row and percentage, or offers Settings when there is no reading. The image stays template mode and text has no custom level colour.

`Resources/tray.png` is an unchanged bundle copy of `desktop/src-tauri/icons/tray.png`, retaining its historical MIT grant. `ModelPlanAppIntegration_ModelPlanAppIntegration.bundle` must be next to CLI-built executables or inside `Contents/Resources` in a packaged app. The public neutral packager and hosted native-runtime artifact copy it explicitly. App lookup uses packaged resources first and does not depend on a build-checkout fallback. External app assemblers must include the same resource bundle.

Checks construct the actual factory with synthetic transports and in-memory buttons only. They do not create a system status item, open a window, or start the app/helper/provider.
