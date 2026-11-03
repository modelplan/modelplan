// SPDX-License-Identifier: MIT
import Foundation
import AppKit
import ModelPlanEngineStore
import ModelPlanDock
import ModelPlanWire
import ModelPlanSettings

/// Scheduling facts only; this type does not determine retained-value policy.
public enum EngineRecomputeDeadline: Equatable, Sendable {
    case scheduled(Date, hasUnknownDeadline: Bool)
    case unknown
    case none
}

/// Reads only already-admitted rows. The consumer must recompute after each
/// replacement or invalidation and use its own snapshot token to cancel timers.
public enum EngineDeadlineFacts {
    public static func evaluate(rows: [RowsRow], events: [EngineResetEvent] = [], eventRows: [RowsRow]? = nil, now: Date) -> EngineRecomputeDeadline {
        var next: Date?
        var unknown = false
        func includeDate(_ date: Date) {
            guard date > now else { return }
            if next.map({ date < $0 }) ?? true { next = date }
        }
        func include(_ stamp: WireTimestamp?) {
            guard let stamp else { unknown = true; return }
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            guard let date = fractional.date(from: stamp.rawValue) ?? ISO8601DateFormatter().date(from: stamp.rawValue) else {
                unknown = true; return
            }
            includeDate(date)
        }
        for row in rows where row.consent == .allowed || row.consent == .implicit || row.consent == .notRequired {
            let accounts = row.accounts.filter { $0.valueState == .current || $0.valueState == .retained }
            guard !accounts.isEmpty else { continue }
            include(row.expiresAt)
            for account in accounts {
                include(account.freshUntil)
                for window in account.windows where window.current { include(window.validUntil) }
            }
        }
        let eligibleEventRows = eventRows ?? rows
        for event in events where event.publishedAt < event.expiresAt {
            let matches = eligibleEventRows.contains { row in
                (row.consent == .allowed || row.consent == .implicit || row.consent == .notRequired) && row.id == event.rowID &&
                row.accounts.contains { account in event.planIDs.map { $0.contains(account.plan.id) } ?? true }
            }
            guard matches else { continue }
            includeDate(event.publishedAt)
            includeDate(event.expiresAt)
        }
        if let next { return .scheduled(next, hasUnknownDeadline: unknown) }
        return unknown ? .unknown : .none
    }
}

/// Shared host seam backed only by admitted app-server rows. Legacy context data is unused.
@MainActor public final class EngineDockContentProvider: DockContentProvider {
    public var resetEventState:() -> EngineRowsEventState = { .absentFromSchema }
    public private(set) var signals:[DockSubscriptionSignal] = []
    /// Facts from the latest makeContent pass, not a timer or a freshness claim.
    /// A consumer must discard its prior schedule on replacement/clear and
    /// invoke makeContent again before reading this value.
    public private(set) var recomputeDeadline: EngineRecomputeDeadline = .unknown
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
        recomputeDeadline = EngineDeadlineFacts.evaluate(rows: value.dockRows + value.menuRows, events: events, eventRows: value.dockRows, now: context.now)
        signals = []
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
            reserve.append(.init(id:"source",kind:.statistic,label:english ? "Source":"来源",value:sourceName(account.route)))
            let memberEvents=events.filter { event in
                event.rowID == member.rowID && event.publishedAt <= context.now && context.now < event.expiresAt &&
                (event.planIDs.map { $0.contains(member.account.plan.id) } ?? true)
            }
            let confirmedIDs=Set(memberEvents.filter{$0.status == "confirmed"}.compactMap(\.confirms))
            let preferred=memberEvents.filter { $0.status != "announced" || !confirmedIDs.contains($0.id) }
                .max { $0.publishedAt < $1.publishedAt }
            var signal=DockSubscriptionSignal(id:member.id);signal.dataState=input.dataState
            if let event=preferred {
                if event.status == "confirmed" {
                    var reset=DockResetSignal(id:event.id,status:.confirmed,confirmedAt:event.publishedAt,expiresAt:event.expiresAt)
                    reset.restartedReading=member.account.valueState == .current && member.account.windows.contains { window in
                        guard window.current else { return false }
                        guard let observed=date(window.observedAt),let resets=date(window.resetsAt) else { return false }
                        return observed > event.publishedAt && resets > event.publishedAt
                    }
                    signal.reset=reset
                } else { signal.reset=DockResetSignal(id:event.id,status:.announced,announcedAt:event.publishedAt,scheduledThrough:event.expiresAt,expiresAt:event.expiresAt) }
            }
            signals.append(signal)
            for event in preferred.map({[$0]}) ?? [] {
                let label=event.status == "confirmed" ? (english ? "Public reset confirmed":"公开重置已确认") : (english ? "Public reset announced":"已公告公开重置")
                reserve.append(.init(id:"reset-event:"+event.id+":"+event.status,kind:.notice,label:label,value:"",detail:english ? "Public status does not confirm a personal quota reset":"公开状态不代表个人额度已重置"))
            }
            if (row.consent == .allowed || row.consent == .implicit || row.consent == .notRequired),
               (date(row.expiresAt).map { context.now < $0 } ?? true),
               (date(account.freshUntil).map { context.now < $0 } ?? true),
               account.valueState == .current || account.valueState == .retained,
               let credits=account.credits,let balance=credits.balance,balance.isFinite,balance >= 0 {
                switch credits.unit {
                case "credits":
                    let number:String?
                    switch M5CreditsDisplayFormat.text(balance,unit:.credits) {
                    case .formatted(let text): number=text
                    case .fallback(let value, _): number=String(value)
                    case .missing,.invalid: number=nil
                    }
                    if let number { reserve.append(.init(id:"credits",kind:.reserve,label:english ? "Credits":"点数",value:number+(english ? " credits":" 点"))) }
                case "money": reserve.append(.init(id:"credits",kind:.reserve,label:english ? "Balance":"余额",value:String(balance),detail:english ? "Currency not reported":"未报告币种"))
                case "": reserve.append(.init(id:"credits",kind:.reserve,label:english ? "Reserve":"储备",value:String(balance),detail:english ? "Unit not reported":"未报告单位"))
                case "other":
                    let unit=M5CreditsDisplayFormat.Unit(identifier:credits.unit)
                    switch M5CreditsDisplayFormat.unknownUnitText(balance,unit:unit,knowledge:.unknown) {
                    case .rendered(_,_,let text,_):
                        reserve.append(.init(id:"credits",kind:.reserve,label:english ? "Reserve":"储备",value:text,detail:english ? "Unit unavailable":"单位不可用"))
                    case .fallback(let value,_),.notApplicable(let value?,_):
                        reserve.append(.init(id:"credits",kind:.reserve,label:english ? "Reserve":"储备",value:String(value),detail:english ? "Unit unavailable; exact value shown":"单位不可用；显示原始数值"))
                    case .missing,.invalid,.notApplicable(nil,_): break
                    }
                default: reserve.append(.init(id:"credits",kind:.reserve,label:english ? "Reserve":"储备",value:String(balance),detail:english ? "Unit not recognized":"单位未识别"))
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
            plan:member.account.plan.name.map{text($0)} ?? "",vendor:member.row.vendorKey ?? "",
            source:sourceState(member,now:context.now),isUnstable:!member.isStable) }
        return .init(snapshot: .init(inputs: inputs, subscriptions:subscriptions,presentationRows: reasons),
                     menuStatusLines: lines.isEmpty ? [status] : lines, emptyText: status, signals:signals)
    }
    private func sourceState(_ member:EngineAccountMember,now:Date) -> SubscriptionSourceState {
        let row=member.row, account=member.account
        if row.consent == .denied { return .denied }
        if row.state == .off { return .readerDisabled }
        if row.state == .stale || account.valueState == .retained { return .stale }
        if row.state == .fresh && account.valueState == .current {
            if (date(row.expiresAt).map { now >= $0 } ?? false) ||
                (date(account.freshUntil).map { now >= $0 } ?? false) { return .stale }
            return .fresh
        }
        return .unavailable
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
        // A non-fresh row remains non-fresh. The Dock model currently cannot
        // display a current weekly window while its overall input is non-fresh.
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
