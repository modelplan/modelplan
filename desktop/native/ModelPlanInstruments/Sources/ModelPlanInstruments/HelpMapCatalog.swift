// SPDX-License-Identifier: MIT
import Foundation

public enum HelpMapSurface: Sendable { case cockpit, dock }
public enum HelpMapRegion: String, CaseIterable, Sendable {
    case window = "mapWindow", shutter = "mapShutter", alert = "mapAlert", settings = "mapSettings"
    case pin = "mapPin", close = "mapClose", fiveHours = "map5h", weekly = "mapWeek", other = "mapOther"
    case faders = "mapFaders", screen = "mapScreen", record = "mapRecord", base = "mapBase"
    case nozzle = "mapNozzle", dockMove = "mapMove", overflow = "mapOverflow", rings = "mapRings"
    case number = "mapNumber", eventDot = "mapDot", ignition = "mapIgnition", sliver = "mapSliver"
}
public struct HelpMapEntry: Equatable, Sendable {
    public let region: HelpMapRegion
    public let sentence: String
    public var id: String { region.rawValue }
}

/// Content only. The same entries serve held Option and menu-latched help.
/// The renderer filters absent anchors and owns frozen tall/compact placement and safe leader routing.
public struct HelpMapCatalog: Sendable {
    public let language: InstrumentLanguage
    public init(_ language: InstrumentLanguage) { self.language = language }
    private func copy(_ chinese: String, _ english: String) -> String { language == .chinese ? chinese : english }
    public var menuTitle: String { copy("说明…", "Help…") }
    public var title: String { copy("驾驶舱说明", "Cockpit help") }
    public var metaphor: String {
        copy("发动机 = 订阅 · 推杆 = 模型 · 火焰 = 正在用", "Engine = subscription · Fader = model · Flame = working now")
    }
    public var dismissal: String { copy("按 Esc 或点一下退出说明", "Press Esc or click to dismiss help") }

    public func entries(for surface: HelpMapSurface) -> [HelpMapEntry] {
        let regions: [HelpMapRegion] = surface == .cockpit
            ? [.window, .shutter, .alert, .settings, .pin, .close, .fiveHours, .weekly, .other, .faders, .screen, .record, .base]
            : [.nozzle, .dockMove, .overflow, .rings, .number, .eventDot, .ignition, .sliver]
        return regions.map { HelpMapEntry(region: $0, sentence: sentence($0)) }
    }
    public func sentence(_ region: HelpMapRegion) -> String {
        switch region {
        case .window: return copy("悬窗：查看模型概况，按放大键看完整画面。", "Window: view the model overview or enlarge the full scene.")
        case .shutter: return copy("悬窗开关：拖动或按一下，收起或展开。", "Window shutter: drag or press to fold or expand the Window.")
        case .alert: return copy("注意灯：按一下查看全部提醒并停止闪烁。", "Alert lamp: press for all alerts and to stop flashing.")
        case .settings: return copy("设置：在独立窗口调整偏好或重新显示提示。", "Settings: adjust preferences or show hints again in its window.")
        case .pin: return copy("钉住：点别处也保持驾驶舱打开。", "Pin: keep the Cockpit open when clicking elsewhere.")
        case .close: return copy("关闭：结束本地试档并收起驾驶舱。", "Close: end the local Try and close the Cockpit.")
        case .fiveHours: return copy("5小时：这一行只放 5 小时额度，空白表示没有此额度。", "5h: only five-hour quota appears here; a blank means none exists.")
        case .weekly: return copy("每周：这一行只放每周额度，空白表示没有此额度。", "Weekly: only weekly quota appears here; a blank means none exists.")
        case .other: return copy("其他：其他周期和专项额度，+N 表示还有更多。", "Other: remaining periods and scoped quotas; +N means more.")
        case .faders: return copy("推杆：每个代表一个模型，拖动或点档位作本地比较，不会改会话。", "Faders: each is a model; drag or press an effort for a local comparison that leaves the session unchanged.")
        case .screen: return copy("公共屏：页键切页，底键选项或返回原页。", "Main screen: page keys change pages; bottom keys select or return.")
        case .record: return copy("会话记录：运行中的在前，按一行查看详情。", "Session record: running sessions come first; press a row for details.")
        case .base: return copy("火焰：表示这个订阅正在用，不表示额度告警。", "Flame: this subscription is working now; it does not mean an alert.")
        case .nozzle: return copy("喷口：每个是一个订阅，悬停看卡片、点按钉住，拖动可排序，⌥ 加方向键移动一位。", "Nozzle: each is a subscription; rest for its card, press to pin, drag to reorder or use Option arrows to move one place.")
        case .dockMove: return copy("背景与握柄：拖动可移动整个挂件，松手贴合预览的左、右或下边缘。", "Background and grips: drag to move the whole Dock; release at the preview on the left, right or bottom edge.")
        case .overflow: return copy("更多订阅：暂不支持拖动排序，可用 ⌥ 加方向键移动一位。", "Overflow: pointer dragging is unavailable; use Option arrows to reorder one place.")
        case .rings: return copy("额度圈：外圈较短、内圈较长，两个都表示剩余。", "Quota rings: outer is shorter and inner longer; both show quota left.")
        case .number: return copy("数字：显示这个喷口当前选中周期的剩余额度。", "Number: quota left in the window selected for this nozzle.")
        case .eventDot: return copy("事件点：橙色风险、蓝色公开重置、白色正在用点数。", "Event dot: amber risk, blue public reset, white credits in use.")
        case .ignition: return copy("点火钮：点按打开，长按点火。", "Ignition: tap to open or hold to ignite.")
        case .sliver: return copy("隐藏条：靠近稍停显示挂件，右键打开菜单。", "Sliver: rest near it to reveal the Dock or right-click for its menu.")
        }
    }
}
