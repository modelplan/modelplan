// SPDX-License-Identifier: MIT
import Foundation
import AppKit
import ModelPlanEngineStore
import ModelPlanDock
import ModelPlanWire
import ModelPlanSettings

/// Shared host seam backed only by admitted app-server rows. Legacy context data is unused.
@MainActor public final class EngineDockContentProvider: DockContentProvider {
    public struct ResetEventPresentation:Equatable,Sendable {
        public let eventID:String
        public let unacknowledged:Bool
    }
    public var resetEventState:() -> EngineRowsEventState = { .absentFromSchema }
    public var acknowledgedResetEventIDs:Set<String> = []
    public private(set) var resetEventsByMember:[String:[ResetEventPresentation]] = [:]
    /// Consumers must discard session placement and scope for these members on every refresh.
    public private(set) var memberInstability:[String:Bool] = [:]
    public var language="en"
    private var english:Bool { language == "en" }
    private func text(_ value:RowsText) -> String { english ? value.en : value.zh }
    private func text(_ value:RowsName) -> String { english ? value.en : value.zh }
    private let liveMenus = LivePrivateMenus()
    func bindDockMenuTracking(_ host: StaticDockPreviewHost) { liveMenus.watch(host) }
    func scrubInvalidatedMenus() { if source.dockContent.status == .cleared { liveMenus.scrubAll() } }
    public let source: EngineDockMenuProvider
    public init(source: EngineDockMenuProvider) { self.source = source }
    public func makeContent(_ context: DockContentContext) -> DockContent {
        let value = source.dockContent
        var inputs: [DockInstrumentInput] = []
        var reasons: [String: DockContentRow] = [:]
        let members=EngineAccountMemberCatalogue(rows:value.dockRows).members
        memberInstability=Dictionary(uniqueKeysWithValues:members.map { ($0.id,!$0.isStable) })
        let events:[EngineResetEvent]
        if case .available(let admitted)=resetEventState() { events=admitted } else { events=[] }
        resetEventsByMember = [:]
        for member in members {
            let row=member.row
            let input = makeInput(member, now: context.now)
            inputs.append(input)
            let message = message(row, now: context.now)
            let account=member.account
            var resets:[String:Date]=[:]
            var descriptions:[String:String]=[:]
            for window in account.windows {
                if let reset=date(window.resetsAt) { resets[window.id]=reset }
                switch window.role {
                case .daily: descriptions[window.id]=english ? "Daily":"每日"
                case .monthly: descriptions[window.id]=english ? "Monthly":"每月"
                case .other,.unknown: descriptions[window.id]=text(window.label)
                case .session,.weekly:break
                }
            }
            var reserve:[DockCardRow]=[]
            let memberEvents=events.filter { event in
                event.rowID == member.rowID && event.publishedAt <= context.now && context.now < event.expiresAt &&
                (event.planIDs.map { $0.contains(member.account.plan.id) } ?? true)
            }
            resetEventsByMember[member.id]=memberEvents.map { .init(eventID:$0.id,unacknowledged:!acknowledgedResetEventIDs.contains($0.id)) }
            for event in memberEvents {
                reserve.append(.init(id:"reset-event:"+event.id,kind:.notice,label:english ? "Public reset announced":"已公告公开重置",value:"",detail:english ? "Announcement; personal quota is not confirmed reset":"公告不代表个人额度已重置"))
            }
            if account.valueState == .current || account.valueState == .retained,
               let credits=account.credits,let balance=credits.balance,balance.isFinite,balance >= 0 {
                switch credits.unit {
                case "credits": reserve.append(.init(id:"credits",kind:.reserve,label:english ? "Credits":"点数",value:String(balance)+(english ? " credits":" 点")))
                case "money": reserve.append(.init(id:"credits",kind:.reserve,label:english ? "Balance":"余额",value:String(balance),detail:english ? "Currency not reported":"未报告币种"))
                default: reserve.append(.init(id:"credits",kind:.reserve,label:english ? "Reserve":"储备",value:String(balance),detail:english ? "Unit not reported":"未报告单位"))
                }
            }
            reasons[member.id] = .init(input: input, reason: text(message.0.text),
                nextStep: message.1.map { text($0.text) } ?? (english ? "Check reading permissions in Settings" : "在设置检查读取权限"),
                originalObservedAt:date(account.observedAt),plan:account.plan.name.map{text($0)} ?? "",
                sourceName:sourceName(account.route),resetTimes:resets,windowDescriptions:descriptions,additionalRows:reserve)
        }
        let status: String
        switch value.status {
        case .loading: status = english ? "Loading readings…" : "正在读取…"
        case .empty: status = english ? "No readings are available. Check Settings." : "暂无读数，请检查设置。"
        case .failed: status = english ? "Readings unavailable. Check the engine connection." : "读数不可用，请检查引擎连接。"
        case .cleared: status = english ? "Readings cleared. Waiting for current data." : "读数已清除，正在等待当前数据。"
        case .ready: status = value.summary.map { text($0.text) } ?? (english ? "Readings" : "读数")
        }
        let lines = EngineAccountMemberCatalogue(rows:value.menuRows).members.map { member -> String in
            let row=member.row
            let reading = try? DockInstrumentProjection.evaluate(makeInput(member, now: context.now), now: context.now)
            let number = reading?.remainingPercent.map { " · \(Int($0.rounded()))%" } ?? ""
            return member.name(english:english) + number + " · " + text(message(row, now: context.now).0.text)
        }
        let subscriptions=members.map { member in SettingsSubscription(id:member.id,
            name:.init(member.name(english:true),member.name(english:false)),
            plan:member.account.plan.name.map{text($0)} ?? "",vendor:member.row.vendorKey ?? "") }
        return .init(snapshot: .init(inputs: inputs, subscriptions:subscriptions,presentationRows: reasons),
                     menuStatusLines: lines.isEmpty ? [status] : lines, emptyText: status)
    }
    private func date(_ stamp: WireTimestamp?) -> Date? {
        guard let stamp else { return nil }
        let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: stamp.rawValue) ?? ISO8601DateFormatter().date(from: stamp.rawValue)
    }
    private func sourceName(_ route:RowsRoute) -> String {
        switch route {
        case .savedLoginApi:return english ? "Saved sign-in":"已有登录"
        case .runtimeRpc:return english ? "Tool runtime":"工具运行时"
        case .localLog,.localSqlite:return english ? "Local history":"本地历史"
        case .apiKeyApi:return english ? "Configured key":"已配置密钥"
        case .browserSession:return english ? "Browser session":"浏览器会话"
        case .statusLine:return english ? "Tool status line":"工具状态栏"
        case .manual:return english ? "Manual reading":"手动读数"
        case .knownUnknown,.unknown:return english ? "Unknown source":"未知来源"
        }
    }
    private func message(_ row: RowsRow, now: Date) -> (RowsReason, RowsNextStep?) {
        if let expiry = date(row.expiresAt), now >= expiry, let after = row.stateAfterExpiry {
            return (after.reason, after.nextStep)
        }
        return (row.reason, row.nextStep)
    }
    private func quotaLabel(_ role:RowsRole) -> String {
        switch role {
        case .session:return english ? "5h":"5小时"
        case .weekly:return english ? "Weekly":"每周"
        case .daily,.monthly,.other,.unknown:return english ? "Other":"其他"
        }
    }
    private func makeInput(_ member:EngineAccountMember, now: Date) -> DockInstrumentInput {
        let row=member.row
        var input = DockInstrumentInput(id: member.id, name: member.name(english:english), windows: [])
        input.vendorResourceKey = row.vendorKey
        input.duplicateAccountTag=member.duplicateTag
        let rowCurrent = row.state == .fresh && (date(row.expiresAt).map { now < $0 } ?? true)
        let account=member.account
            let accountCurrent = rowCurrent && account.valueState == .current && (date(account.freshUntil).map { now < $0 } ?? true)
            for window in account.windows {
                let current = accountCurrent && window.current && (date(window.validUntil).map { now < $0 } ?? true)
                let period:DockQuotaPeriod
                switch window.role {
                case .session: period = .fiveHour
                case .daily: period = .day
                case .weekly: period = .week
                case .monthly: period = .month
                case .other,.unknown: period = .other
                }
                var projected=DockQuotaWindowInput(id: window.id, period: period, label: quotaLabel(window.role),
                    remainingPercent: current ? window.remainingPercent : nil,
                    resetsAt: current ? date(window.resetsAt) : nil,
                    durationSeconds: window.durationSeconds.map { Double($0) })
                // Only known plan-wide session and weekly limits participate.
                // Named, unknown and model-scoped pools remain card-only.
                let generalLimit = (period == .fiveHour && ["main", "five_hour"].contains(window.limitKey)) ||
                    (period == .week && ["main", "weekly"].contains(window.limitKey))
                projected.isGeneral = window.modelScope == nil && window.poolKey == "main" && generalLimit
                input.windows.append(projected)
            }
        func rank(_ period:DockQuotaPeriod) -> Int {
            switch period { case .fiveHour:return 0;case .week:return 1;case .month:return 2;case .day:return 3;case .other:return 4 }
        }
        // Canonicalize each role's tightest first for rings and the shared pin consumer.
        input.windows.sort { left,right in
            if rank(left.period) != rank(right.period) { return rank(left.period) < rank(right.period) }
            let a=left.remainingPercent ?? .infinity,b=right.remainingPercent ?? .infinity
            return a == b ? left.id < right.id:a < b
        }
        input.dataState = input.windows.contains { $0.remainingPercent != nil } ? .fresh : .unavailable
        return input
    }

}
