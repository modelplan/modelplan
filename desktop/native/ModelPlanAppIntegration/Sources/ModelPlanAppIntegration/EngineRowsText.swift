// SPDX-License-Identifier: MIT
import ModelPlanSettings

/// Strings owned by the normal-entry status menu and its fallback reading window.
enum EngineRowsText {
    static let refresh = SettingsText("Refresh", "刷新")
    static let settings = SettingsText("Settings…", "设置…")
    static let readingsMenu = SettingsText("Dock readings…", "挂件读数…")
    static let readingsTitle = SettingsText("Dock readings", "挂件读数")
    static let quit = SettingsText("Quit", "退出")
    static let waiting = SettingsText("Waiting for readings", "等待读数")
}
