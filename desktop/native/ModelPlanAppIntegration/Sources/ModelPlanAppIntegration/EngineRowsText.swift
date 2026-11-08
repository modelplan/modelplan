// SPDX-License-Identifier: MIT
import ModelPlanSettings
import ModelPlanDock

/// Strings owned by the normal-entry status menu and its fallback reading window.
enum EngineRowsText {
    static let showQuotaWidget = SettingsText("Show Quota Widget", "显示额度挂件")
    /// The widget menu's checkable item; the same stored setting as Settings' auto-collapse switch.
    static let autoCollapse = SettingsText("Auto-Collapse", "自动收起")
    /// One-time hint after the widget is turned off from the status menu or Settings.
    static let widgetTurnedOffHint = SettingsText(
        "Quota Widget is off. Right-click the menu bar icon and choose Show Quota Widget.",
        "额度挂件已关闭，可右键点菜单栏图标，勾选「显示额度挂件」重新打开")
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
    /// G3-22: macOS hides status items behind the notch when the menu bar is full.
    static let statusItemHidden = SettingsText("The menu bar is full and the ModelPlan icon is hidden. Hold ⌘ and drag it to the right.",
                                               "菜单栏已满，ModelPlan 图标被挡住了。按住 ⌘ 把它拖到右边。")
    /// D65 (owner 11-08): the card's plain line for a window at 0 %, with the time until it resets when known.
    /// "5-hour quota used up · resets in 3h 18m" / "5 小时额度已用完 · 3 小时 18 分后重置".
    static func quotaUsedUp(period: DockQuotaPeriod, label: String, resetMinutes: Int?) -> SettingsText {
        let name: SettingsText
        switch period {
        case .fiveHour: name = SettingsText("5-hour", "5 小时")
        case .day: name = SettingsText("Daily", "每日")
        case .week: name = SettingsText("Weekly", "每周")
        case .month: name = SettingsText("Monthly", "每月")
        case .other: name = SettingsText(label, label)
        }
        let english = name.english + " quota used up", chinese = name.chinese + "额度已用完"
        guard let minutes = resetMinutes, minutes >= 0 else { return SettingsText(english, chinese) }
        let days = minutes / 1440, hours = (minutes % 1440) / 60, rest = minutes % 60
        let en: String, zh: String
        if days > 0 { en = "\(days)d \(hours)h"; zh = "\(days) 天 \(hours) 小时" }
        else if hours > 0 { en = "\(hours)h \(rest)m"; zh = "\(hours) 小时 \(rest) 分" }
        else { en = "\(max(1, rest))m"; zh = "\(max(1, rest)) 分" }
        return SettingsText(english + " · resets in " + en, chinese + " · " + zh + "后重置")
    }
    static let waiting = SettingsText("Waiting for readings", "等待读数")
    static let paused = SettingsText("Readings paused", "读数已暂停")
    static let readingServiceUnavailable = SettingsText(
        "Readings unavailable. Check the reading service connection in Settings.",
        "读数不可用，请在设置中检查读取服务连接。")
    static let waitingForFresh = SettingsText("Waiting for current readings. Refresh to retry.", "等待读数更新，可刷新重试。")
}

/// Right-click menus (cockpit, widget, status item). Terms follow the shared glossary and Settings.
extension EngineRowsText {
    static let resetPosition = SettingsText("Reset Position", "重置位置")
    static let widgetSize = SettingsText("Quota Widget Size", "额度挂件大小")
    static let sizeSmall = SettingsText("Small", "小")
    static let sizeMedium = SettingsText("Medium", "中")
    static let sizeLarge = SettingsText("Large", "大")
    static let help = SettingsText("Help", "说明")
    static let closeWindow = SettingsText("Close Window", "关闭窗口")
}
