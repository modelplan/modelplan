// SPDX-License-Identifier: MIT
import ModelPlanSettings

/// Strings owned by the normal-entry status menu and its fallback reading window.
enum EngineRowsText {
    static let refresh = SettingsText("Refresh", "刷新")
    static let settings = SettingsText("Settings…", "设置…")
    static let cockpitMenu = SettingsText("Cockpit…", "驾驶舱…")
    static let cockpitAction = SettingsText("Cockpit", "驾驶舱")
    static let openCockpit = SettingsText("Open cockpit", "打开驾驶舱")
    static let readingsTitle = SettingsText("Dock readings", "挂件读数")
    static let quit = SettingsText("Quit", "退出")
    static let waiting = SettingsText("Waiting for readings", "等待读数")
}
