// SPDX-License-Identifier: MIT
import Foundation

public struct SettingsText: Equatable, Sendable {
    public let english: String, chinese: String
    public init(_ english: String, _ chinese: String) { self.english = english; self.chinese = chinese }
    public func value(_ language: SettingsLanguage) -> String { language == .english ? english : chinese }
}
public enum SettingKey: String, CaseIterable, Sendable {
    case theme, size, motion, transparency, percentageMode, showPercentages, percentagePin, redBelow, sliverAlert
    case showDock, autoHide, reveal, magnification, fullscreen, captureHiding, activeDisplay, order
    case login, automaticUpdates, menuDisplay, openShortcut, dockShortcut, language, opening, countdown, resetHints
    case notificationConsent, forecast, reset, official, expiring, stale
    case visible, alias, source, projectNames, retention, clearCLI, clearAppCache, privacyStatement
    case appVersion, cliStatus, architecture, diagnostics, feedback, licenses
    case dockEdge, detectedReaders, optionalReaders
}
public enum SettingAvailability: Equatable, Sendable {
    case available, readOnly, unsupportedCaptureHiding, cliOwned, serviceUnavailable, cacheUnavailable
}
public enum SubscriptionSourceState: String, Sendable { case fresh, stale, unavailable, denied, readerDisabled }
public struct SettingsSubscription: Sendable {
    public let id: String, name: SettingsText, plan: String, vendor: String
    public let modelNames: [String], toolNames: [String]
    public let source: SubscriptionSourceState
    public init(id: String, name: SettingsText, plan: String = "", vendor: String = "",
                modelNames: [String] = [], toolNames: [String] = [], source: SubscriptionSourceState = .unavailable) {
        self.id = id; self.name = name; self.plan = plan; self.vendor = vendor
        self.modelNames = modelNames; self.toolNames = toolNames; self.source = source
    }
}
public enum CLIReadState: String, Sendable { case ready, unavailable, denied, stale }
public enum SettingsArchitecture: String, Sendable { case appleSilicon, intelUntested }
public enum SettingsDiagnosticCode: String, Sendable { case permissionDenied, unsupported, stale, cliUnavailable, readerUnavailable }
public struct SettingsAbout: Sendable {
    public var appVersion: String, cliVersion: String
    public var macOSVersion = "unknown"
    public var enabledReaders = Set<SettingsReaderID>()
    public var recentErrorCodes: [SettingsDiagnosticCode] = []
    public var cliState: CLIReadState
    public var architecture: SettingsArchitecture
    public init(appVersion: String = "unknown", cliVersion: String = "unknown", cliState: CLIReadState = .unavailable,
                architecture: SettingsArchitecture = .appleSilicon) {
        self.appVersion = appVersion; self.cliVersion = cliVersion; self.cliState = cliState; self.architecture = architecture
    }
    private func safeVersion(_ value: String) -> String {
        guard value.utf8.count <= 64,
              value.range(of: #"^v?[0-9]+(?:\.[0-9]+){1,3}(?:[+-][A-Za-z0-9.-]+)?$"#, options: .regularExpression) != nil else { return "unknown" }
        return value
    }
    public var version: String { safeVersion(appVersion) }
    /// Deliberate allowlist. No paths, aliases, projects, account IDs, raw CLI output/errors or machine identity.
    public var diagnosticText: String {
        "app=\(version)\ncli=\(safeVersion(cliVersion))\nmacOS=\(safeVersion(macOSVersion))\nreaders=\(SettingsReaderID.allCases.filter { enabledReaders.contains($0) }.map(\.rawValue).joined(separator: ","))\nerrors=\(recentErrorCodes.prefix(8).map(\.rawValue).joined(separator: ","))"
    }
    public static let feedbackURL = URL(string: "https://github.com/modelplan/modelplan/issues/new/choose")!
    public static let privacy = SettingsText("No local data is uploaded. Only public data is downloaded.", "不上传任何本机数据，只下载公开数据。")
    public static let intelNote = SettingsText("Intel untested; 3D may stutter.", "Intel 未测试，3D 效果可能卡顿。")
}
public struct SettingsLicenseNotice: Equatable, Sendable {
    public let component: String, license: String, text: String
    public init(component: String, license: String, text: String) {
        self.component = component; self.license = license; self.text = text
    }
}
public struct SettingsPageContext: Sendable {
    public var subscriptions: [SettingsSubscription] = []
    public var capabilities = SettingsCapabilities()
    public var shortcutObservations: [SettingsShortcutObservation] = []
    public var about = SettingsAbout()
    /// Supplied by the app from its audited bundled notices, not a download or private source.
    public var readerObservations: [SettingsReaderID: ReaderObservation] = [:]
    public var licenseNotices: [SettingsLicenseNotice] = []
    public init() {}
}
public struct SubscriptionRowValue: Equatable, Sendable {
    public let id: String, name: String, plan: String, value: String
    public let options: [String]
}
public enum SettingsRowValue: Equatable, Sendable {
    case choice(String, options: [String]), toggle(Bool), text(String), subscriptions([SubscriptionRowValue])
    case action(SettingsActionRequest?), link(URL), notices([SettingsLicenseNotice]), login(LoginSetting), readers([ReaderSetting])
}
public struct SettingsRow: Equatable, Sendable {
    public let key: SettingKey
    public let paneID: String
    public let groupID: String
    public let paneTitle: SettingsText
    public let groupTitle: SettingsText?
    /// Compatibility only. Custom pane identifiers are intentionally not constrained to draft IDs.
    public var pane: SettingsPane? { SettingsPane(rawValue: paneID) }
    public let title: SettingsText
    public let subtitle: SettingsText
    public let availability: SettingAvailability
    public let value: SettingsRowValue
}

/// Semantic page data only: no view, geometry, drawing, artwork or platform service invocation.
public enum SettingsCatalogue {
    private struct Definition {
        let key: SettingKey, title: SettingsText, subtitle: SettingsText
        init(_ key: SettingKey, _ en: String, _ zh: String, _ hint: String, _ hintZH: String) {
            self.key = key; title = .init(en, zh); subtitle = .init(hint, hintZH)
        }
    }
    private static let definitions: [Definition] = [
        .init(.theme,"Theme","主题","Follow the system or choose day/night.","跟随系统或选择日间、夜间。"),
        .init(.size,"Dock size","挂件大小","Choose small, medium or large.","选择小、中、大。"),
        .init(.motion,"Reduce motion","减少动态效果","Follow accessibility settings or always reduce motion.","跟随辅助功能设置或始终减少动态。"),
        .init(.transparency,"Reduce transparency","减少透明度","Follow accessibility settings or use solid surfaces.","跟随辅助功能设置或使用不透明表面。"),
        .init(.percentageMode,"Percentage basis","百分比含义","Show remaining or used quota.","显示剩余或已用额度。"),
        .init(.showPercentages,"Show percentages","显示百分比","Keep notification indicators when numbers are hidden.","隐藏数字后仍保留提示点。"),
        .init(.percentagePin,"Percentage window","百分比窗口","Select the tightest, five-hour or weekly window per subscription.","为每个订阅选择最紧张、5小时或周窗口。"),
        .init(.redBelow,"Critical threshold","变红阈值","Threshold uses remaining quota even when displaying used quota.","即使显示已用额度，阈值仍按剩余额度判断。"),
        .init(.sliverAlert,"Sliver alert color","隐藏条提示色","Allow the collapsed strip to indicate attention.","允许收起的细条提示需关注状态。"),
        .init(.showDock,"Show dock","显示挂件","Show or hide the desktop dock.","显示或隐藏桌面挂件。"),
        .init(.autoHide,"Auto-collapse","自动收起","Collapse to the edge strip when leaving.","移开后收起成贴边细条。"),
        .init(.reveal,"Reveal dwell","展开停留时间","Wait before revealing the edge dock.","在边缘停留后展开。"),
        .init(.magnification,"Hover magnification","悬停放大","Choose none, subtle or strong.","选择不放大、轻微或明显。"),
        .init(.fullscreen,"Show over full-screen apps","全屏应用上显示","Off by default.","默认关闭。"),
        .init(.captureHiding,"Hide from capture","录屏时隐藏","Unavailable: hiding from arbitrary recorders is not supported.","不可用：不支持对任意录屏程序隐藏。"),
        .init(.dockEdge,"Dock edge","挂件边缘","Choose right, bottom or left.","选择右侧、底部或左侧。"),
        .init(.detectedReaders,"Detected readers","已检测读取器","Read-only local reader observations.","本地读取器的只读观测。"),
        .init(.optionalReaders,"Optional readers","可选读取器","Off by default; saves consent only.","默认关闭；只保存同意选择。"),
        .init(.activeDisplay,"Follow active display","跟随当前显示器","Use the display selected by the display coordinator.","使用显示器协调器选定的显示器。"),
        .init(.order,"Subscription order","订阅顺序","One shared order for the dock and cockpit; hidden entries remain editable.","挂件与驾驶舱共用顺序；隐藏项仍可编辑。"),
        .init(.login,LoginSetting.title.english,LoginSetting.title.chinese,"Start ModelPlan after signing in to your Mac.","登录 Mac 后自动启动 ModelPlan。"),
        .init(.automaticUpdates,"Check for updates automatically","自动检查更新","Show available versions quietly in Overview and the menu.","有可用版本时，在总览和菜单中轻声提醒。"),
        .init(.menuDisplay,"Menu-bar display","菜单栏显示","Icon, tightest percentage or two windows.","图标、最紧张百分比或并列两个窗口。"),
        .init(.openShortcut,"Open cockpit shortcut","开舱快捷键","Global registration can fail; local matching remains available.","全局注册可能失败；应用内匹配仍可用。"),
        .init(.dockShortcut,"Toggle dock shortcut","显示隐藏挂件快捷键","Text editing and composition do not trigger shortcuts.","文本编辑与输入法组合期间不触发。"),
        .init(.language,"Language","语言","Choose Chinese or English.","选择中文或英文。"),
        .init(.opening,"Opening behavior","开舱方式","Open quickly when ignition is unavailable.","点火不可用时使用快速打开。"),
        .init(.countdown,"Countdown beat","倒数节奏","Three beats follow the 200 ms hold boundary.","按住200毫秒后开始三拍倒数。"),
        .init(.resetHints,"Show hints again","重新显示提示","Reset the nine first-use hints and their open/reveal budgets.","重置九种首次提示及开舱、挂件展开的提示预算。"),
        .init(.notificationConsent,"Enable notifications","开启通知","Ask for permission only after explicit opt-in.","仅在主动开启后请求通知权限。"),
        .init(.forecast,"May not last to reset","可能撑不到重置","Notify for a new forecast episode.","新出现的耗尽风险可通知。"),
        .init(.reset,"Quota reset","额度重置","Notify when a reset is observed.","观测到重置时通知。"),
        .init(.official,"Official extra reset","官方额外重置","Notify once per official event.","每个官方事件仅通知一次。"),
        .init(.expiring,"Reset card expiring","重置卡即将到期","Expired cards are never revived after wake.","唤醒后不重新显示已过期的卡片通知。"),
        .init(.stale,"Data stopped arriving","数据停止更新","Notify once per stale-data episode.","每次数据停滞仅通知一次。"),
        .init(.visible,"Subscription visibility","订阅可见性","Apply to both dock and cockpit.","同时用于挂件与驾驶舱。"),
        .init(.alias,"Subscription alias","订阅别名","Commit only completed text, never an active IME composition.","仅提交已完成的文本，不提交输入法组合内容。"),
        .init(.source,"Data source status","数据来源状态","Read-only status; this app does not enable collectors.","只读状态；本应用不开启采集器。"),
        .init(.projectNames,"Project names","项目名称","Shown by default; hiding also applies to notifications.","默认显示；隐藏时通知也不显示名称。"),
        .init(.retention,"Local retention","本地保留时间","CLI-owned: sessions 35 days; daily totals 371 days.","CLI管理：会话35天，日汇总371天。"),
        .init(.clearCLI,"Clear CLI data","清除CLI数据","Unavailable here; no mutating CLI command is issued.","此处不可用；不会执行写入型CLI命令。"),
        .init(.clearAppCache,"Clear app cache","清除应用缓存","Only app-owned derived caches; preferences and CLI data are kept.","仅清除应用衍生缓存，保留偏好和CLI数据。"),
        .init(.privacyStatement,"Privacy statement","隐私说明","No local uploads; only public downloads.","不上传本机数据，仅下载公开数据。"),
        .init(.appVersion,"App version","应用版本","Application build version.","应用构建版本。"),
        .init(.cliStatus,"CLI status","CLI状态","Read-only CLI availability.","CLI可用性的只读状态。"),
        .init(.architecture,"Architecture","架构","Intel is untested; 3D may stutter.","Intel未测试，3D效果可能卡顿。"),
        .init(.diagnostics,"Copy diagnostics","复制诊断","Versions, macOS, reader IDs and error codes only.","仅含版本、macOS、读取器ID和错误代码。"),
        .init(.feedback,"Feedback","反馈","Open the public issue template; nothing is submitted automatically.","打开公开问题模板，不自动提交内容。"),
        .init(.licenses,"Third-party notices","第三方声明","The app adapter supplies bundled license notices.","由应用适配器提供随包许可证声明。"),
    ]
    public static func rows(preferences p: SettingsPreferences, context c: SettingsPageContext,
                            pane: SettingsPane? = nil, query: String = "",
                            structure: SettingsStructure = .task65) throws -> [SettingsRow] {
        try rows(preferences: p, context: c, paneID: pane?.rawValue, query: query, structure: structure)
    }
    public static func rows(preferences p: SettingsPreferences, context c: SettingsPageContext,
                            paneID: String?, query: String = "",
                            structure: SettingsStructure = .task65) throws -> [SettingsRow] {
        try p.validate()
        let catalogue = c.subscriptions.map(\.id)
        guard !catalogue.contains(""), Set(catalogue).count == catalogue.count,
              Set(definitions.map(\.key)) == Set(SettingKey.allCases) else { throw SettingsError.invalidCatalogue }
        let byID = Dictionary(uniqueKeysWithValues: c.subscriptions.map { ($0.id, $0) })
        let byKey = Dictionary(uniqueKeysWithValues: definitions.map { ($0.key, $0) })
        let ordered = try p.presentedSubscriptionIDs(catalogue, includingHidden: true).compactMap { byID[$0] }
        let query = normalized(query.trimmingCharacters(in: .whitespacesAndNewlines))
        return structure.panes.filter { paneID == nil || $0.id == paneID }.flatMap { pane in
            pane.groups.flatMap { group in
                group.keys.compactMap { key -> SettingsRow? in
                    guard let d = byKey[key] else { return nil }
                    let baseMatches = query.isEmpty || [d.key.rawValue, d.title.english, d.title.chinese,
                        d.subtitle.english, d.subtitle.chinese, pane.title.english, pane.title.chinese,
                        group.title?.english ?? "", group.title?.chinese ?? ""].contains { normalized($0).contains(query) }
                    let perSubscription = [.percentagePin, .order, .visible, .alias, .source].contains(d.key)
                    let subs = baseMatches ? ordered : ordered.filter { sub in
                        [sub.id, sub.name.english, sub.name.chinese, sub.plan, sub.vendor, p.subscriptionSettings[sub.id]?.alias ?? ""]
                            .appending(contentsOf: sub.modelNames + sub.toolNames).contains { normalized($0).contains(query) }
                    }
                    guard baseMatches || (perSubscription && !subs.isEmpty) else { return nil }
                    return .init(key: key, paneID: pane.id, groupID: group.id, paneTitle: pane.title,
                                 groupTitle: group.title, title: d.title, subtitle: d.subtitle,
                                 availability: availability(key, c), value: value(key, p, c, subs))
                }
            }
        }
    }
    private static func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }
    private static func availability(_ k: SettingKey, _ c: SettingsPageContext) -> SettingAvailability {
        switch k {
        case .captureHiding: return .unsupportedCaptureHiding
        case .retention, .clearCLI: return .cliOwned
        case .source, .detectedReaders, .privacyStatement, .appVersion, .cliStatus, .architecture, .diagnostics, .licenses: return .readOnly
        case .login: return .available // The local choice stays editable even when service actions are unavailable.
        case .clearAppCache: return c.capabilities.appCacheClearAvailable ? .available : .cacheUnavailable
        default: return .available
        }
    }
    private static func value(_ k: SettingKey, _ p: SettingsPreferences, _ c: SettingsPageContext, _ subs: [SettingsSubscription]) -> SettingsRowValue {
        func choices<T: RawRepresentable & CaseIterable>(_ v: T) -> SettingsRowValue where T.RawValue == String {
            .choice(v.rawValue, options: T.allCases.map(\.rawValue))
        }
        func perSub(options: [String] = [], _ transform: (SettingsSubscription) -> String) -> SettingsRowValue {
            .subscriptions(subs.map { .init(id: $0.id, name: $0.name.value(p.language), plan: $0.plan, value: transform($0), options: options) })
        }
        switch k {
        case .dockEdge: return choices(p.dockEdge)
        case .detectedReaders: return .readers(ReaderSetting.project(consent: p.readerConsent, observations: c.readerObservations).filter { $0.consent == nil })
        case .optionalReaders: return .readers(ReaderSetting.project(consent: p.readerConsent, observations: c.readerObservations).filter { $0.consent != nil })
        case .theme: return choices(p.theme)
        case .size: return choices(p.size)
        case .motion: return choices(p.motion)
        case .transparency: return choices(p.transparency)
        case .percentageMode: return choices(p.percentageMode)
        case .showPercentages: return .toggle(p.showPercentages)
        case .percentagePin: return perSub(options: PercentagePin.allCases.map(\.rawValue)) { (p.subscriptionSettings[$0.id]?.percentagePin ?? .auto).rawValue }
        case .redBelow: return .choice(String(p.redBelow), options: [10,16,20,25].map(String.init))
        case .sliverAlert: return .toggle(p.sliverAlert)
        case .showDock: return .toggle(p.showDock)
        case .autoHide: return .toggle(p.autoHide)
        case .reveal: return .choice(String(p.revealMilliseconds), options: [100,150,300].map(String.init))
        case .magnification: return choices(p.magnification)
        case .fullscreen: return .toggle(p.showOverFullscreen)
        case .captureHiding: return .text("unsupported")
        case .activeDisplay: return .toggle(p.followActiveDisplay)
        case .order: return perSub { $0.id }
        case .login: return .login(LoginSetting(preferences: p, capabilities: c.capabilities))
        case .automaticUpdates: return .toggle(p.automaticUpdates)
        case .menuDisplay: return choices(p.menuDisplay)
        case .openShortcut: return .text(shortcut(p.openShortcut))
        case .dockShortcut: return .text(shortcut(p.dockShortcut))
        case .language: return choices(p.language)
        case .opening: return choices(p.opening)
        case .countdown: return .choice(String(p.beatMilliseconds), options: [150,200,250].map(String.init))
        case .resetHints: return .action(.resetHelpHints)
        case .notificationConsent: return .toggle(p.notifications.optedIn)
        case .forecast, .reset, .official, .expiring, .stale: return .toggle(p.notifications.kinds.contains(NotificationKind(rawValue: k.rawValue)!))
        case .visible: return perSub(options: ["true", "false"]) { String(!p.subscriptions.hiddenIDs.contains($0.id)) }
        case .alias: return perSub { p.subscriptionSettings[$0.id]?.alias ?? "" }
        case .source: return perSub { $0.source.rawValue }
        case .projectNames: return .toggle(p.showProjectNames)
        case .retention: return .text("sessions=35d; dailyTotals=371d; owner=CLI")
        case .clearCLI: return .action(nil)
        case .clearAppCache: return .action(c.capabilities.clearRequest)
        case .privacyStatement: return .text(SettingsAbout.privacy.value(p.language))
        case .appVersion: return .text(c.about.version)
        case .cliStatus: return .text(c.about.cliState.rawValue)
        case .architecture: return .text(c.about.architecture == .intelUntested ? SettingsAbout.intelNote.value(p.language) : c.about.architecture.rawValue)
        case .diagnostics: return .text(c.about.diagnosticText)
        case .feedback: return .link(SettingsAbout.feedbackURL)
        case .licenses: return .notices(c.licenseNotices)
        }
    }
    private static func shortcut(_ chord: ShortcutChord) -> String {
        [ShortcutChord.Modifier.command, .control, .option, .shift].filter { chord.modifiers.contains($0) }.map(\.rawValue).joined(separator: "+") + "+" + chord.key
    }
}
private extension Array { func appending(contentsOf values: [Element]) -> Self { self + values } }
