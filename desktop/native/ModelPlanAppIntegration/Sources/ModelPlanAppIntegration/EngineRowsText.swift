// SPDX-License-Identifier: MIT
import ModelPlanSettings

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
    /// G3-52 (owner 11-08): the hidden icon cannot be dragged, so the notice says how to make room
    /// and where the Cockpit and Settings are meanwhile. The widget menu keeps one short line; the
    /// steps are in Settings.
    static let statusItemHiddenMenu = SettingsText("The menu bar is full and the ModelPlan icon is hidden. Settings shows how to fix it.",
                                                   "菜单栏已满，ModelPlan 图标被挡住了。设置里有解决办法。")
    /// The steps, worded for this Mac: macOS 26 and later list every menu bar icon in
    /// System Settings > Menu Bar; macOS 15 can only hide its own items, in Control Center.
    static func statusItemHidden(macOSMajor: Int, cockpit: Bool, shortcut: String?) -> SettingsText {
        let room: SettingsText = macOSMajor >= 26
            ? SettingsText("To make room, turn some icons off in System Settings > Menu Bar, or hold ⌘ and drag system icons off the menu bar.",
                           "腾出位置：在「系统设置 › 菜单栏」里关掉一些图标，或按住 ⌘ 把系统图标拖出菜单栏。")
            : SettingsText("To make room, hold ⌘ and drag system icons off the menu bar, set some items to Don't Show in Menu Bar in System Settings > Control Center, or quit apps whose icons you don't need.",
                           "腾出位置：按住 ⌘ 把系统图标拖出菜单栏，在「系统设置 › 控制中心」里把一些项目设为「不在菜单栏显示」，或退出不需要图标的应用。")
        // MENU-07b: the Cockpit opens from the widget's Ignition, from opening the app again, or a set shortcut.
        let reach: SettingsText
        if cockpit, let shortcut {
            reach = SettingsText("Until then, open the Cockpit with the Ignition on the Quota Widget, by opening ModelPlan again from Spotlight, or with \(shortcut), and right-click the Quota Widget for Settings.",
                                 "在此之前，点额度挂件上的点火钮、用聚焦搜索再次打开 ModelPlan 或按 \(shortcut)，都能打开驾驶舱；右键点额度挂件可打开设置。")
        } else if cockpit {
            reach = SettingsText("Until then, open the Cockpit with the Ignition on the Quota Widget or by opening ModelPlan again from Spotlight, and right-click the Quota Widget for Settings.",
                                 "在此之前，点额度挂件上的点火钮或用聚焦搜索再次打开 ModelPlan，都能打开驾驶舱；右键点额度挂件可打开设置。")
        } else {
            reach = SettingsText("Until then, right-click the Quota Widget for Settings.", "在此之前，右键点额度挂件可打开设置。")
        }
        return SettingsText("The menu bar is full, so macOS hides the ModelPlan icon. " + room.english + " " + reach.english,
                            "菜单栏已满，macOS 把 ModelPlan 图标藏起来了。" + room.chinese + reach.chinese)
    }
    /// A chord as Settings shows it (⌃⌥⇧⌘ then the key).
    static func chordLabel(_ chord: ShortcutChord) -> String? {
        guard !chord.isUnassigned, chord.isValid else { return nil }
        let symbols: [(ShortcutChord.Modifier, String)] = [(.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘")]
        return symbols.filter { chord.modifiers.contains($0.0) }.map(\.1).joined() + chord.key
    }
    static let waiting = SettingsText("Waiting for readings", "等待读数")
    static let paused = SettingsText("Readings paused", "读数已暂停")
    static let readingServiceUnavailable = SettingsText(
        "Readings unavailable. Check the reading service connection in Settings.",
        "读数不可用，请在设置中检查读取服务连接。")
    static let waitingForFresh = SettingsText("Waiting for current readings. Refresh to retry.", "等待读数更新，可刷新重试。")
}
