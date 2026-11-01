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
            reasons[member.id] = .init(input: input, reason: text(message.0.text),
                                    nextStep: message.1.map { text($0.text) } ?? (english ? "Check reading permissions in Settings" : "在设置检查读取权限"))
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
