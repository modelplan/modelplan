// SPDX-License-Identifier: MIT
import Foundation

/// Stable semantic IDs, not DOM selectors. Specific controls/data use their own topic before .control.
public enum HelpTopic: String, CaseIterable, Sendable {
    case tutorial, ignition, sliver, dockMove, pinned, caution, shutter, pin, close, settings
    case cardToday, subscription, publicReset, point, reserve, quota, time, todaySpeed, today, credits
    case sessionSpeed, liveSpeed, periodSpeed, event, ring, dockQuota, nozzle, page, engine, recommended
    case effort, effortLCD, working, otherSessions, identity, base, session, bank, option, screen
    case heat, chart, comparison, usage, source, window, control, link, nativeSetting, record
}
public enum HelpStatisticsPeriod: Sendable {
    case days7, days30
    public var days: Int { self == .days7 ? 7 : 30 }
}
public enum HelpNozzleLocation: Sendable { case dock, overflow }

public struct HelpContext: Sendable {
    /// App-owned localized facts, never raw vendor posts or calendar date strings.
    public let fact: String?
    public let value: String?
    public let statisticsPeriod: HelpStatisticsPeriod?
    public let nozzleLocation: HelpNozzleLocation
    public init(fact: String? = nil, value: String? = nil, statisticsPeriod: HelpStatisticsPeriod? = nil,
                nozzleLocation: HelpNozzleLocation = .dock) {
        self.fact = fact; self.value = value; self.statisticsPeriod = statisticsPeriod; self.nozzleLocation = nozzleLocation
    }
    public static func quota(remaining: Double?, resetsAt: Date?, now: Date, language: InstrumentLanguage) -> Self {
        let format = InstrumentFormat(language)
        let remainingText = language == .chinese ? "剩余 " : "Quota left "
        return Self(fact: remainingText + format.percent(remaining) + " · " + format.reset(resetsAt, now: now))
    }
}

public struct HelpExplanation: Equatable, Sendable {
    public let title: String
    public let body: String
    /// Views and accessibility consumers use this exact same two-line description.
    public var accessibleDescription: String { title + "\n" + body }
}

public struct HelpCatalog: Sendable {
    public let language: InstrumentLanguage
    public init(_ language: InstrumentLanguage) { self.language = language }
    private func copy(_ chinese: String, _ english: String) -> String { language == .chinese ? chinese : english }

    public func explanation(_ topic: HelpTopic, context: HelpContext = .init()) -> HelpExplanation {
        let title: String
        let basis: String
        switch topic {
        case .tutorial:
            title = copy("练习", "Practice")
            basis = copy("这里只练习本地操作，不会改变真实会话。", "This is a local practice preview that leaves real sessions unchanged.")
        case .ignition:
            title = copy("点火钮", "Ignition")
            basis = copy("点按打开驾驶舱，长按点火；快速打开设置会跳过点火。", "Tap to open the Cockpit or hold to ignite; Always quick skips ignition.")
        case .sliver:
            title = copy("隐藏条", "Sliver")
            basis = copy("靠近这里稍停可显示挂件，右键可打开菜单。", "Rest near this edge to reveal the Dock or right-click for its menu.")
        case .dockMove:
            title = copy("移动挂件", "Move the Dock")
            basis = copy("拖动背景或端部握柄可移动整个挂件，松手贴合预览边缘；只能停在左、右或下边缘。", "Drag the background or end grips to move the whole Dock, then release at the preview on the left, right or bottom edge.")
        case .pinned:
            title = copy("已钉住", "Pinned")
            basis = copy("按 Esc 或点别处取消，卡片不会随指针移动而关闭。", "Press Esc or click elsewhere to release the card.")
        case .caution:
            title = copy("注意灯", "Alert lamp")
            basis = copy("按一下查看全部提醒并停止闪烁。", "Press to see all alerts and stop the flashing.")
        case .shutter:
            title = copy("悬窗开关", "Window shutter")
            basis = copy("拖到另一端或按一下，收起或展开悬窗。", "Drag to the other end or press to fold or expand the Window.")
        case .pin:
            title = copy("驾驶舱钉住", "Pin the Cockpit")
            basis = copy("钉住后，点别处也会保持驾驶舱打开。", "When pinned, the Cockpit stays open when you click elsewhere.")
        case .close:
            title = copy("关闭驾驶舱", "Close the Cockpit")
            basis = copy("关闭驾驶舱，并结束当前的本地试档。", "Closes the Cockpit and ends its local Try.")
        case .settings:
            title = copy("设置", "Settings")
            basis = copy("选项会保存在这台设备上。", "Choices are saved on this device.")
        case .cardToday:
            title = copy("今日与速度", "Today and Speed")
            basis = copy("今日是今天的输出，速度是来源当前报告的生成速度，未提供统计时段。", "Today is today's output; Speed is the latest reported generation rate and its averaging window is unavailable.")
        case .subscription:
            title = copy("订阅", "Subscription")
            basis = copy("这个标识区分订阅，卡片显示它最近读取的额度与储备。", "This identifies the subscription whose latest quota and Reserve appear in the card.")
        case .publicReset:
            title = copy("公开重置", "Public reset")
            basis = copy("公开公告不代表你的账户已经重置，请等待账户读数确认。", "A public announcement does not prove an account reset; wait for your account reading.")
        case .point:
            title = copy("模型与档位", "Model and effort")
            basis = copy("数值是这个模型和档位的能力与参考成本。", "These values describe ability and reference cost for this model and effort.")
        case .reserve:
            title = copy("储备", "Reserve")
            basis = copy("包含可用重置次数、最近到期时间和点数。", "This includes reset counts, their nearest expiry and credits.")
        case .quota:
            title = copy("额度 · 剩余", "Quota · left")
            basis = copy("条形表示剩余额度，圆点表示距离重置的时间。", "The bar shows quota left and dots show time until reset.")
        case .time:
            title = copy("距离重置的时间", "Time until reset")
            basis = copy("亮点越多，距离本次重置越久。", "More lit dots mean more time remains until this reset.")
        case .todaySpeed, .sessionSpeed, .liveSpeed, .periodSpeed:
            title = copy("速度 · ", "Speed · ") + (helpLine(context.value) ?? "--")
            switch topic {
            case .liveSpeed:
                basis = InstrumentHelpDefinitions.liveSpeed(language)
            case .sessionSpeed:
                basis = copy("这次会话的输出 token 数除以生成用时。", "Output tokens divided by generation time for this whole session.")
            case .todaySpeed:
                basis = InstrumentHelpDefinitions.todayAverage(language)
            default:
                if let days = context.statisticsPeriod?.days {
                    basis = copy("最近 \(days) 天的输出 token 数除以生成用时。", "Output tokens divided by generation time over the last \(days) days.")
                } else {
                    basis = copy("所选期间的输出 token 数除以生成用时；统计时段未提供。", "Output tokens divided by generation time for the selected period; its averaging window is unavailable.")
                }
            }
        case .today:
            title = copy("今日", "Today")
            basis = InstrumentHelpDefinitions.todayAverage(language)
        case .credits:
            title = copy("点数", "Credits")
            basis = copy("这是当前点数及所选期间的点数用量。", "This is the credit balance or credit use in the selected period.")
        case .event:
            title = copy("事件点", "Event dot")
            basis = copy("橙色表示风险，蓝色表示公开重置，白色表示正在用点数。", "Amber means risk, blue means a public reset and white means credits are in use.")
        case .ring:
            title = copy("额度圈", "Quota ring")
            basis = copy("每个圈表示对应周期的剩余额度，外圈周期较短。", "Each ring shows quota left for its window and the outer window is shorter.")
        case .dockQuota:
            title = copy("额度 · 剩余", "Quota · left")
            basis = copy("数字是这个喷口选定周期的剩余额度，圈也表示剩余。", "This number is quota left in the nozzle's selected window, and the rings also show quota left.")
        case .nozzle:
            title = copy("挂件喷口 · 订阅", "Dock nozzle · subscription")
            basis = context.nozzleLocation == .overflow
                ? copy("悬停查看额度卡片，按一下钉住；更多订阅暂不支持拖动排序，可用 ⌥ 加方向键移动一位。", "Rest for the quota card or press to pin; overflow items cannot be dragged in v1; use Option arrows to move one place.")
                : copy("悬停查看额度卡片，按一下钉住，沿挂件拖动喷口可调整订阅顺序；也可用 ⌥ 加方向键移动一位。", "Rest for the quota card, press to pin, or drag along the Dock to reorder; Option arrows move one place.")
        case .page:
            title = copy("订阅页", "Subscription page")
            basis = copy("翻页不会改变已选订阅。", "Changing pages keeps your subscription selection.")
        case .engine:
            title = copy("发动机 · 订阅", "Engine · subscription")
            basis = copy("按一下只看这个订阅，再按一次回到全部。", "Press to select this subscription, then press again to return to All.")
        case .recommended:
            title = copy("★推荐", "★ Recommended")
            basis = copy("金色 ★ 标出这个模型的推荐档位。", "The gold ★ marks the recommended effort for this model.")
        case .effort:
            title = copy("档位 · 当前或试", "Effort · Current or Try")
            basis = copy("拖动或点选档位作本地比较，白色是当前，蓝色是试，不会改会话。", "Drag or press an effort for a local Try; white is Current and blue is Try, with the session unchanged.")
        case .effortLCD:
            title = copy("档位 · 当前或试", "Effort · Current or Try")
            basis = copy("点按在公共屏比较，长按钉在这一组，只在本机试，不会改会话。", "Press to compare on the Main screen or hold to pin in this bank; the Try is local and leaves the session unchanged.")
        case .working:
            title = copy("模型状态灯", "Model status lamp")
            basis = copy("蓝色是试，白色是已选或快速，暗色是未选。", "Blue is Try, white is selected or Fast, and dim means unselected.")
        case .otherSessions:
            title = copy("其他会话", "Other sessions")
            basis = copy("这个点标出其他会话正在使用的档位，数字是会话数。", "This mark shows an effort used by other sessions and its number is the session count.")
        case .identity:
            title = copy("订阅标识", "Subscription identity")
            basis = copy("颜色标识订阅，不表示正在用或额度告警。", "This colour identifies the subscription; it does not indicate work or quota alerts.")
        case .base:
            title = copy("火焰与喷口", "Flame and mouth")
            basis = copy("细线标识订阅，有火焰才表示正在生成。", "The line identifies the subscription and a flame means it is working now.")
        case .session:
            title = copy("会话", "Session")
            basis = copy("按一下在公共屏查看这次会话。", "Press to view this session on the Main screen.")
        case .bank:
            title = copy("推杆翻组", "Fader bank")
            basis = copy("每组三个模型；按左右键或 [ ] 翻组。", "Each bank holds three models; use the arrow keys or [ ] to change banks.")
        case .option:
            title = copy("公共屏选项", "Main-screen option")
            basis = copy("直接点选文字，或用键盘按一下切换。", "Press the printed choice directly or activate the key to cycle.")
        case .screen:
            title = copy("公共屏", "Main screen")
            basis = copy("按页键查看总览、订阅、档位或去向。", "Use the page keys for Overview, Subscriptions, Effort or Destinations.")
        case .heat:
            title = copy("每日用量", "Daily use")
            basis = copy("颜色越亮用量越多，空白表示没有记录。", "Brighter cells mean more use and a gap means no record is available.")
        case .chart:
            title = copy("用量图", "Usage chart")
            basis = copy("每条表示对应时段的用量，空白表示没有记录。", "Each bar shows use in its period and a gap means no record is available.")
        case .comparison:
            title = copy("档位比较", "Effort comparison")
            basis = copy("比较以当前为基准，试档不会改变会话。", "Comparisons use Current as the reference and Try leaves the session unchanged.")
        case .usage:
            title = copy("用量", "Usage")
            basis = copy("这是所选期间记录的用量，-- 表示不可用。", "This is recorded use for the selected period and -- means unavailable.")
        case .source:
            title = copy("读取来源与时间", "Where and when this was read")
            basis = copy("来源只说明这次读数从哪里取得。", "This identifies where this reading was obtained.")
        case .window:
            title = copy("悬窗", "Window")
            basis = copy("显示模型概况；按放大键查看完整画面。", "Shows the model overview; press Enlarge for the full view.")
        case .control:
            title = helpLine(context.fact) ?? copy("选项", "Option")
            basis = copy("按一下使用这个选项，不会改变真实会话。", "Press to use this option; it leaves real sessions unchanged.")
        case .link:
            title = helpLine(context.fact) ?? copy("来源链接", "Source link")
            basis = copy("打开这个链接查看来源，不会改变你的会话。", "Opens this link to view the source; your session is unchanged.")
        case .nativeSetting:
            title = copy("原生应用设置", "Native-app setting")
            basis = copy("此项的可用性以应用报告的状态为准。", "Availability follows the status reported by the app.")
        case .record:
            title = copy("会话记录", "Session record")
            basis = copy("运行中的会话在前，按一行查看这次会话。", "Running sessions come first; press a row to view that session.")
        }
        let facts = helpLine(context.fact).map { HelpDurationText.expand($0, language: language) }
        let prefix = topic == .control || topic == .link ? nil : facts
        let body = prefix.map { $0 + copy("；", "; ") + basis } ?? basis
        return HelpExplanation(title: title, body: body)
    }

    public func hint(_ request: HelpHintRequest) -> String? {
        guard request.valid else { return nil }
        switch request.hint {
        case .trial: return copy("这只是本地比较，不会改你的会话", "Just a local comparison; your session is unchanged")
        case .ignition: return copy("点按打开，长按点火", "Tap to open · hold to ignite")
        case .pinned: return copy("已钉住，按 Esc 或点别处取消", "Pinned · Esc or click elsewhere to release")
        case .page: return copy("还有订阅在第 \(request.pageNumber!) 页", "More subscriptions on page \(request.pageNumber!)")
        case .cockpit: return copy("按住 ⌥ 查看说明", "Hold ⌥ for help")
        }
    }
    public var resetHints: String { copy("重新显示提示", "Show hints again") }
    public var hintsReset: String { copy("提示已重置", "Hints reset") }
}

private func helpLine(_ value: String?) -> String? {
    guard let value else { return nil }
    let line = value.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    return line.isEmpty ? nil : line
}

/// Expands only the compact d/h/m syntax used in app-owned relative facts, never calendar dates.
public enum HelpDurationText {
    public static func expand(_ text: String, language: InstrumentLanguage) -> String {
        let replacements: [(String, String)] = language == .english
            ? [(#"(?<![A-Za-z0-9])(\d+)h(\d{2})(?!\d|[a-z])"#, "$1h$2m")]
            : [(#"(?<![A-Za-z0-9])(\d+)d(\d+)h(?![A-Za-z0-9])"#, "$1 天 $2 小时"),
               (#"(?<![A-Za-z0-9])(\d+)h(\d{2})(?:m)?(?![A-Za-z0-9])"#, "$1 小时 $2 分"),
               (#"(?<![A-Za-z0-9])(\d+)h(?![A-Za-z0-9])"#, "$1 小时"),
               (#"(?<![A-Za-z0-9])(\d+)m(?![A-Za-z0-9])"#, "$1 分"),
               (#"(?<![A-Za-z0-9])(\d+)d(?![A-Za-z0-9])"#, "$1 天")]
        return replacements.reduce(text) { result, replacement in
            let regex = try! NSRegularExpression(pattern: replacement.0)
            return regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: replacement.1)
        }
    }
}
