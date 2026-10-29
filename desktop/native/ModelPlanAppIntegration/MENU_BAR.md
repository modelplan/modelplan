# Native menu bar

The real `CommunityApplicationFactory.makeDelegate` supplies `CommunityMenuBarProjector` and the existing MIT tray template to the root host. `CommunityDelegate.render` updates the retained status item from the same store completion as the Dock and overview; it creates no new store, reader or timer.

Selection uses `CommunityDockSnapshot` and `DockInstrumentProjection`, then takes the minimum original remaining percentage before formatting the title as a rounded integer percentage. The menu keeps the full Dock readout for that same row. Unknown, expired, future-observed and failed readings are excluded by those existing Dock rules. No current reading means icon only. The disabled first menu item names the selected row and percentage, or offers Settings when there is no reading. The image stays template mode and text has no custom level colour.

`Resources/tray.png` is an unchanged bundle copy of `desktop/src-tauri/icons/tray.png`, retaining its historical MIT grant. `ModelPlanAppIntegration_ModelPlanAppIntegration.bundle` must be next to CLI-built executables or inside `Contents/Resources` in a packaged app. The public neutral packager and hosted native-runtime artifact copy it explicitly. App lookup uses packaged resources first and does not depend on a build-checkout fallback. External app assemblers must include the same resource bundle.

Checks construct the actual factory with synthetic transports and in-memory buttons only. They do not create a system status item, open a window, or start the app/helper/provider.

The presenter reads the same applied Settings snapshot held by the retained Dock host. It excludes hidden IDs and applies aliases, window pin and used/remaining basis before the shared evaluator. Selection still follows the tightest original remaining value; display follows the selected percentage basis. Until the authoritative Settings receipt exists it shows icon only. A Settings apply receipt reprojects the existing retained store view immediately; it does not enqueue another CLI command or wait for a poll.

菜单栏读取同一个 Dock Host 已应用的设置快照：先排除隐藏行，再应用别名、窗口 pin 和已用/剩余显示方式，然后走共用投影。选择仍按原始剩余额度最紧的一行，显示遵循设置的百分比含义；权威设置尚未到达时仅显示图标。设置 apply 回执会立即重投影现有 store 视图，不增加 CLI 命令或等待下一次轮询。
