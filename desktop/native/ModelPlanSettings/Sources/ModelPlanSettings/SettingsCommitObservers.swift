// SPDX-License-Identifier: MIT
import Foundation

/// Delivery failed after preferences were successfully committed. This is not a disk-save error.
public struct SettingsCommitDeliveryFailure: Equatable, Sendable {
    public let observerID: UUID, revision: UInt64
    public func message(_ language: SettingsLanguage) -> String {
        language == .chinese
            ? "设置已保存，但部分应用视图未能更新。请重新打开应用后重试。"
            : "Settings saved, but some app views could not update. Reopen the app to retry."
    }
}

/// One bounded acknowledgment deadline per committed edit, unrelated to hint dwell/admission.
/// An uncooperative consumer is disabled, retaining at most its one outstanding task rather than
/// invoking it again for every save. Cancellation is requested, never awaited as a structured loser.
@MainActor final class SettingsCommitObservers {
    typealias Observer = @MainActor (SettingsCommittedEdit) async -> Void
    private final class Entry {
        let id: UUID, observer: Observer, onFailure: (SettingsCommitDeliveryFailure) -> Void
        var worker: Task<Void, Never>?, token: UUID?
        var failed = false
        init(id: UUID, observer: @escaping Observer, onFailure: @escaping (SettingsCommitDeliveryFailure) -> Void) {
            self.id = id; self.observer = observer; self.onFailure = onFailure
        }
    }
    private final class Delivery {
        let id = UUID(), revision: UInt64
        var pending: [UUID: UUID]
        var continuation: CheckedContinuation<Void, Never>?
        var deadline: Task<Void, Never>?
        init(revision: UInt64, pending: [UUID: UUID], continuation: CheckedContinuation<Void, Never>) {
            self.revision = revision; self.pending = pending; self.continuation = continuation
        }
    }
    private var entries: [UUID: Entry] = [:]
    private var delivery: Delivery?
    private let limit: Duration
    private let onFailure: (SettingsCommitDeliveryFailure) -> Void
    init(limit: Duration, onFailure: @escaping (SettingsCommitDeliveryFailure) -> Void) {
        self.limit = limit; self.onFailure = onFailure
    }
    func observe(onFailure: @escaping (SettingsCommitDeliveryFailure) -> Void,
                 _ observer: @escaping Observer) -> UUID {
        let id = UUID(); entries[id] = Entry(id: id, observer: observer, onFailure: onFailure); return id
    }
    func remove(_ id: UUID) {
        guard let entry = entries.removeValue(forKey: id) else { return }
        entry.worker?.cancel()
        if let delivery, delivery.pending.removeValue(forKey: id) != nil, delivery.pending.isEmpty { complete(delivery) }
    }
    func deliver(_ edit: SettingsCommittedEdit) async {
        let available = entries.values.filter { !$0.failed && $0.worker == nil }
        guard !available.isEmpty else { return }
        // SettingsEditor keeps isSaving until this boundary settles, so saves cannot overlap.
        precondition(delivery == nil)
        await withCheckedContinuation { continuation in
            let pending = Dictionary(uniqueKeysWithValues: available.map { ($0.id, UUID()) })
            let current = Delivery(revision: edit.after.revision, pending: pending, continuation: continuation)
            delivery = current
            current.deadline = Task { [weak self, limit] in
                do { try await Task.sleep(for: limit) } catch { return }
                self?.timedOut(current.id)
            }
            for entry in available {
                let token = pending[entry.id]!, id = entry.id, observer = entry.observer
                entry.token = token
                entry.worker = Task { [weak self] in
                    if !Task.isCancelled { await observer(edit) }
                    self?.finished(id: id, token: token)
                }
            }
        }
    }
    private func finished(id: UUID, token: UUID) {
        if let entry = entries[id], entry.token == token { entry.worker = nil; entry.token = nil }
        guard let current = delivery, current.pending[id] == token else { return }
        current.pending.removeValue(forKey: id)
        if current.pending.isEmpty { complete(current) }
    }
    private func timedOut(_ id: UUID) {
        guard let current = delivery, current.id == id else { return }
        var failures: [(Entry, SettingsCommitDeliveryFailure)] = []
        for (id, token) in current.pending {
            guard let entry = entries[id], entry.token == token else { continue }
            entry.failed = true; entry.worker?.cancel()
            failures.append((entry, .init(observerID: id, revision: current.revision)))
        }
        // Retire/settle the deadline before callbacks can remove observers or change the app.
        complete(current)
        for (entry, failure) in failures {
            onFailure(failure)
            entry.onFailure(failure)
        }
    }
    private func complete(_ current: Delivery) {
        guard delivery === current else { return }
        delivery = nil; current.deadline?.cancel(); current.deadline = nil
        let continuation = current.continuation; current.continuation = nil; continuation?.resume()
    }
}
