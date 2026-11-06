// SPDX-License-Identifier: MIT
import ModelPlanSettings

/// Strings owned by the normal-entry status menu and its fallback reading window.
enum EngineRowsText {
    static let showQuotaWidget = SettingsText("Show Quota Widget", "显示额度挂件")
    /// The widget menu's checkable item; the same stored setting as Settings' auto-collapse switch.
    static let autoCollapse = SettingsText("Auto-Collapse", "自动收起")
    /// One-time hint after the widget is turned off from the status menu or Settings.
    static let widgetTurnedOffHint = SettingsText(
        "Quota Widget is off. To turn it back on, choose Show Quota Widget from the menu bar icon.",
        "额度挂件已关闭，可在菜单栏图标里勾选「显示额度挂件」重新打开")
    static let refresh = SettingsText("Refresh", "刷新")
    static let settings = SettingsText("Settings…", "设置…")
    static let contextSettings = SettingsText("Settings", "设置")
    static let contextClose = SettingsText("Close", "关闭")
    static let cockpitMenu = SettingsText("Cockpit…", "驾驶舱…")
    static let cockpitAction = SettingsText("Cockpit", "驾驶舱")
    static let openCockpit = SettingsText("Open cockpit", "打开驾驶舱")
    static let readingsTitle = SettingsText("Quota Widget readings", "额度挂件读数")
    static let comingSoon = SettingsText("Coming soon", "即将推出")
    static let quit = SettingsText("Quit ModelPlan", "退出 ModelPlan")
    static let about = SettingsText("About ModelPlan", "关于 ModelPlan")
    static let waiting = SettingsText("Waiting for readings", "等待读数")
    static let paused = SettingsText("Readings paused", "读数已暂停")
    static let readingServiceUnavailable = SettingsText(
        "Readings unavailable. Check the reading service connection in Settings.",
        "读数不可用，请在设置中检查读取服务连接。")
    static let waitingForFresh = SettingsText("Waiting for current readings. Refresh to retry.", "等待读数更新，可刷新重试。")
}
