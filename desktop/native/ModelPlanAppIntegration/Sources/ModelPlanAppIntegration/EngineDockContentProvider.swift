// SPDX-License-Identifier: MIT
import Foundation
import AppKit
import ModelPlanEngineStore
import ModelPlanDock
import ModelPlanWire
import ModelPlanSettings

/// Shared host seam backed only by admitted app-server rows. Legacy context data is unused.
@MainActor public final class EngineDockContentProvider: DockContentProvider {
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
        for member in members {
            let row=member.row
            let input = makeInput(member, now: context.now)
            inputs.append(input)
            let message = message(row, now: context.now)
            let account=member.account
            var details:[String:String]=[:]
            for window in account.windows { details[window.id]=resetDetail(date(window.resetsAt),now:context.now) }
            var reserve:[DockCardRow]=[]
            if let credits=account.credits,let balance=credits.balance,balance.isFinite,balance >= 0 {
                reserve.append(.init(id:"credits",kind:.reserve,label:english ? "Credits":"点数",
                    value:String(balance)+" "+(credits.unit == "credits" && !english ? "点":credits.unit)))
            }
            reasons[member.id] = .init(input: input, reason: text(message.0.text),
                nextStep: message.1.map { text($0.text) } ?? (english ? "Check reading permissions in Settings" : "在设置检查读取权限"),
                originalObservedAt:date(account.observedAt),plan:account.plan.name.map{text($0)} ?? "",
                sourceName:sourceName(account.route),windowDetails:details,additionalRows:reserve)
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
    private func resetDetail(_ reset:Date?,now:Date) -> String {
        guard let reset else { return "--" }
        let seconds=reset.timeIntervalSince(now)
        guard seconds.isFinite,seconds < Double(Int.max/60) else { return "--" }
        guard seconds > 0 else { return english ? "Reset time passed":"已过重置时间" }
        let minutes=Int(ceil(seconds/60)),days=minutes/1440,hours=(minutes%1440)/60,rest=minutes%60
        let value:String
        if days > 0 { value=english ? "\(days)d \(hours)h":"\(days)天\(hours)小时" }
        else if hours > 0 { value=english ? "\(hours)h \(rest)m":"\(hours)小时\(rest)分" }
        else { value=english ? "\(rest)m":"\(rest)分" }
        return english ? "Resets in "+value:value+"后重置"
    }
    private func message(_ row: RowsRow, now: Date) -> (RowsReason, RowsNextStep?) {
        if let expiry = date(row.expiresAt), now >= expiry, let after = row.stateAfterExpiry {
            return (after.reason, after.nextStep)
        }
        return (row.reason, row.nextStep)
    }
    private func makeInput(_ member:EngineAccountMember, now: Date) -> DockInstrumentInput {
        let row=member.row
        var input = DockInstrumentInput(id: member.id, name: member.name(english:english), windows: [])
        input.vendorResourceKey = row.vendorKey
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
                var projected=DockQuotaWindowInput(id: window.id, period: period, label: text(window.label),
                    remainingPercent: current ? window.remainingPercent : nil,
                    resetsAt: current ? date(window.resetsAt) : nil,
                    durationSeconds: window.durationSeconds.map { Double($0) })
                projected.isGeneral = period == .fiveHour || period == .week || period == .month
                input.windows.append(projected)
            }
        input.dataState = input.windows.contains { $0.remainingPercent != nil } ? .fresh : .unavailable
        return input
    }

}
