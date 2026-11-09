// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanEngineClient
import ModelPlanWire

/// The engine's local usage-history import (metadata only), as Settings needs it. The engine owns
/// consent, dedupe and writes; this layer only asks and shows.
@MainActor public protocol HistoryImportCommands: AnyObject {
    var ready: Bool { get }
    func start(days: Int, firstRun: Bool) async throws
    func status() async throws
    func cancel() async throws
    func remove() async throws
}

/// HIST-IMP-02/03 presentation state: the day count (7 / 30 / 90, default 30), progress, cancel and
/// "remove imported". The accepted engine status is the only input; nothing is guessed locally.
@MainActor public final class HistoryImportModel {
    public static let dayChoices = [7, 30, 90]
    public static let defaultDays = 30
    public private(set) var status: WireHistoryImportStatus?
    public var days = HistoryImportModel.defaultDays
    public private(set) var failed = false
    private let commands: any HistoryImportCommands
    private var observers: [UUID: @MainActor () -> Void] = [:]
    private var asked = false
    private var poll: Task<Void, Never>?
    private let pollInterval: Duration

    public init(commands: any HistoryImportCommands, pollInterval: Duration = .milliseconds(700)) {
        self.commands = commands; self.pollInterval = pollInterval
    }
    @discardableResult public func observe(_ body: @escaping @MainActor () -> Void) -> UUID {
        let id = UUID(); observers[id] = body; return id
    }
    public func removeObserver(_ id: UUID) { observers.removeValue(forKey: id) }
    private func changed() { for body in Array(observers.values) { body() } }

    public var isRunning: Bool { status?.phase == .running }
    public var hasImported: Bool { (status?.importedRows ?? 0) > 0 }
    public var canStart: Bool { commands.ready && !isRunning }
    public var canRemove: Bool { commands.ready && !isRunning && hasImported }
    /// 0...1 while running; nil until the engine has counted the files.
    public var fraction: Double? {
        guard let status, status.phase == .running, status.filesTotal > 0 else { return nil }
        return min(1, Double(status.filesDone) / Double(status.filesTotal))
    }

    /// Only call from the owner's accepted-event fanout, on the main actor.
    public func receive(_ value: WireHistoryImportStatus) {
        status = value; failed = false
        if value.phase == .running { schedulePoll() } else { poll?.cancel(); poll = nil }
        changed()
    }
    public func refresh() async {
        guard commands.ready else { return }
        do { try await commands.status() } catch { failed = true; changed() }
    }
    /// The first look at the page asks once; later changes arrive as accepted events.
    public func refreshIfNeeded() async {
        guard status == nil, !asked else { return }
        asked = true; await refresh()
    }
    public func start() async {
        guard canStart else { return }
        do { try await commands.start(days: days, firstRun: false) } catch { failed = true; changed() }
    }
    public func cancel() async {
        guard isRunning else { return }
        do { try await commands.cancel() } catch { failed = true; changed() }
    }
    public func remove() async {
        guard canRemove else { return }
        do { try await commands.remove() } catch { failed = true; changed() }
    }
    /// HIST-IMP-03: after the first-run consent is committed, the import runs once without another
    /// dialog. The engine answers a repeat with nothing to do, so asking again is harmless.
    public func runAfterFirstRunConsent() async {
        guard commands.ready, !isRunning else { return }
        do { try await commands.start(days: Self.defaultDays, firstRun: true) } catch { failed = true; changed() }
    }
    private func schedulePoll() {
        guard poll == nil else { return }
        let interval = pollInterval
        poll = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                guard !Task.isCancelled, let self else { return }
                await self.refresh()
                if !self.isRunning { return }
            }
        }
    }
    public func stop() { poll?.cancel(); poll = nil }
}

/// All copy of the feature in one place (English, Chinese).
public enum HistoryImportText {
    public static let title = SettingsText("Import usage history", "导入使用历史")
    public static let subtitle = SettingsText("Reads older Claude Code and Codex sessions on this Mac: times, models, effort and token counts only, never prompts or replies. It stays on this Mac.",
                                              "读取本机较早的 Claude Code 和 Codex 会话：只取时间、模型、档位和令牌数，不读提示词或回复，数据只留在本机。")
    public static let importButton = SettingsText("Import now", "立即导入")
    public static let cancelButton = SettingsText("Cancel", "取消")
    public static let removeButton = SettingsText("Remove imported history", "删除已导入的历史")
    public static let daysLabel = SettingsText("Days back", "回溯天数")
    public static func dayChoice(_ days: Int) -> SettingsText { .init("\(days) days", "\(days) 天") }
    /// HIST-IMP-03: the one plain line under the first-run consent.
    public static let firstRunLine = SettingsText("After you continue, ModelPlan imports up to 30 days of past usage from these tools in the background (counts, models and times only). Cancel or remove it in Settings › Data & Privacy.",
                                                  "继续后，ModelPlan 会在后台从这些工具导入最多 30 天的过往用量（只含次数、模型和时间）。可在 设置 › 数据与隐私 中取消或删除。")
    public static func running(days: Int) -> SettingsText { .init("Importing \(days) days of local history…", "正在导入 \(days) 天的本地历史…") }
    public static let unavailable = SettingsText("Not available until the engine is ready.", "引擎就绪前不可用。")
    public static let failed = SettingsText("The import could not run. Nothing was changed.", "导入未能运行，未做任何改动。")
    public static func line(_ model: HistoryImportModel) -> SettingsText {
        if model.failed { return failed }
        guard let s = model.status else { return model.canStart ? .init("", "") : unavailable }
        switch s.phase {
        case .running: return running(days: s.days)
        case .cancelled: return .init("Import cancelled; nothing was changed.", "导入已取消，未做任何改动。")
        case .failed: return failed
        case .unknown: return .init("", "")
        case .idle, .done:
            if s.coverage.isEmpty {
                let skipped = s.sources.contains { $0.status == .skippedNoConsent }
                return skipped ? .init("Skipped tools without history access. Allow them in Settings › Subscriptions.", "未授权读取历史的工具已跳过。可在 设置 › 订阅 中允许。")
                    : .init("Nothing imported yet.", "尚未导入。")
            }
            let rows = s.importedRows
            let span = s.coverage.map(\.from).min()! + " – " + s.coverage.map(\.through).max()!
            return .init("Imported \(rows) daily rows, \(span).", "已导入 \(rows) 条每日记录，\(span)。")
        }
    }
}
