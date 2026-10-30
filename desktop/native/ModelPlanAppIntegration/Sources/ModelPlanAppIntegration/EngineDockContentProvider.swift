// SPDX-License-Identifier: MIT
import Foundation
import AppKit
import ModelPlanEngineStore
import ModelPlanDock
import ModelPlanWire

/// Shared host seam backed only by admitted app-server rows. Legacy context data is unused.
@MainActor public final class EngineDockContentProvider: DockContentProvider {
    private let liveMenus = LivePrivateMenus()
    func bindDockMenuTracking(_ host: StaticDockPreviewHost) { liveMenus.watch(host) }
    func scrubInvalidatedMenus() { if source.dockContent.status == .cleared { liveMenus.scrubAll() } }
    public let source: EngineDockMenuProvider
    public init(source: EngineDockMenuProvider) { self.source = source }
    public func makeContent(_ context: DockContentContext) -> DockContent {
        let value = source.dockContent
        var inputs: [DockInstrumentInput] = []
        var reasons: [String: DockContentRow] = [:]
        for row in value.dockRows {
            let input = makeInput(row, now: context.now)
            inputs.append(input)
            let message = message(row, now: context.now)
            reasons[row.id] = .init(input: input, reason: message.0.text.en,
                                    nextStep: message.1?.text.en ?? "Check reading permissions in Settings / 在设置检查读取权限")
        }
        let status: String
        switch value.status {
        case .loading: status = "Loading readings… / 正在读取…"
        case .empty: status = "No readings are available. Check Settings. / 暂无读数，请检查设置。"
        case .failed: status = "Readings unavailable. Check the engine connection. / 读数不可用，请检查引擎连接。"
        case .cleared: status = "Readings cleared. Waiting for current data. / 读数已清除，正在等待当前数据。"
        case .ready: status = value.summary?.text.en ?? "Readings / 读数"
        }
        let lines = value.menuRows.map { row -> String in
            let reading = try? DockInstrumentProjection.evaluate(makeInput(row, now: context.now), now: context.now)
            let number = reading?.remainingPercent.map { " · \(Int($0.rounded()))%" } ?? ""
            return row.name.en + number + " · " + message(row, now: context.now).0.text.en
        }
        return .init(snapshot: .init(inputs: inputs, presentationRows: reasons),
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
    private func makeInput(_ row: RowsRow, now: Date) -> DockInstrumentInput {
        var input = DockInstrumentInput(id: row.id, name: row.name.en, windows: [])
        input.vendorResourceKey = row.vendorKey
        let rowCurrent = row.state == .fresh && (date(row.expiresAt).map { now < $0 } ?? true)
        for (accountIndex, account) in row.accounts.enumerated() {
            let accountCurrent = rowCurrent && account.valueState == .current && (date(account.freshUntil).map { now < $0 } ?? true)
            for window in account.windows {
                let current = accountCurrent && window.current && (date(window.validUntil).map { now < $0 } ?? true)
                input.windows.append(.init(id: "\(accountIndex):\(window.id)", period: .other, label: window.label.en,
                    remainingPercent: current ? window.remainingPercent : nil,
                    resetsAt: current ? date(window.resetsAt) : nil,
                    durationSeconds: window.durationSeconds.map { Double($0) }))
            }
        }
        input.dataState = input.windows.contains { $0.remainingPercent != nil } ? .fresh : .unavailable
        return input
    }

}
