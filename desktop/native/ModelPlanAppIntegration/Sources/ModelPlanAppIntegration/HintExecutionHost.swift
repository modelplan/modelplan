// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanDock
import ModelPlanSettings

/// Implement with the same app-scoped SettingsStore, not another store for its URL.
public protocol HintPreferenceWriting: Sendable {
    func snapshot() async -> SettingsSnapshot
    func acceptsOrigin(of edit: SettingsCommittedEdit) async -> Bool
    func saveHints(_ preferences: FirstUseHintPreferences, expectedRevision: UInt64) async throws -> SettingsSnapshot
}
public extension HintPreferenceWriting {
    func acceptsOrigin(of edit: SettingsCommittedEdit) async -> Bool { false }
}
extension SettingsStore: HintPreferenceWriting {
    public func acceptsOrigin(of edit: SettingsCommittedEdit) -> Bool { edit.belongs(to: self) }
    public func saveHints(_ preferences: FirstUseHintPreferences, expectedRevision: UInt64) throws -> SettingsSnapshot {
        try update(expectedRevision: expectedRevision) { $0.helpHints = preferences }
    }
}
@MainActor public protocol HintDeadlineScheduling: AnyObject {
    func arm(at deadline: TimeInterval, _ action: @escaping @MainActor () -> Void)
    func cancel()
}
/// Reuses the existing one-shot/common-mode implementation; no repeating or view-owned timer.
@MainActor public final class HintCommonModeScheduler: HintDeadlineScheduling {
    private let scheduler: DockCommonModeScheduler
    public init(uptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        scheduler = DockCommonModeScheduler(clock: uptime)
    }
    public func arm(at deadline: TimeInterval, _ action: @escaping @MainActor () -> Void) { scheduler.arm(at: deadline, action) }
    public func cancel() { scheduler.cancel() }
}
@MainActor public protocol HintOverlayPresenting: AnyObject {
    func placeableKinds(context: HintContext, trial: InstrumentHintSourceSnapshot?) -> Set<FirstUseHintKind>
    /// True only after the host verifies actual placement AND current surface visibility.
    /// A layout-only receipt (including HelpUI onPresentation) is insufficient.
    func showAndVerify(_ offer: HintOffer, trial: InstrumentHintSourceSnapshot?) -> Bool
    /// Recheck the current anchor/placement/visibility when updating an already shown token.
    func updateAndVerify(_ presentation: HintPresentation) -> Bool
    /// Must address this token only; a late hide must never remove a replacement offer.
    func hide(offerID: UUID)
}

/// One app-scoped arbiter, source router, deadline and injected overlay. It does not create windows.
@MainActor public final class HintExecutionHost: InstrumentTrialHintReceiving {
    public private(set) var hints: FirstUseHints
    public private(set) var persistenceError: Error?
    public var onPersistenceFailure: ((Error) -> Void)?
    public var onPersisted: ((SettingsSnapshot) -> Void)?
    public private(set) var isRunning = true
    public lazy var sources = InstrumentHintSourceRouter(receiver: self, uptime: uptime)
    private let persistence: any HintPreferenceWriting
    private let scheduler: any HintDeadlineScheduling
    private let overlay: any HintOverlayPresenting
    private let uptime: () -> TimeInterval
    private var generation: UInt64 = 0, writeEpoch: UInt64 = 0
    private var disposed = false
    private var deadlineID: UUID?, resetCheck: UUID?
    private var deferredContext: HintContext?
    private var revision: UInt64, revisionFloor: UInt64
    private var saved: FirstUseHintPreferences, pending: FirstUseHintPreferences?
    private struct Write {
        let id: UUID, epoch: UInt64, revision: UInt64, preferences: FirstUseHintPreferences
    }
    private var writing: Write?
    private var writeTask: Task<Void, Never>?

    private init(snapshot: SettingsSnapshot, persistence: any HintPreferenceWriting,
                 scheduler: any HintDeadlineScheduling, overlay: any HintOverlayPresenting,
                 uptime: @escaping () -> TimeInterval) {
        hints = FirstUseHints(preferences: snapshot.preferences.helpHints)
        saved = snapshot.preferences.helpHints; revision = snapshot.revision; revisionFloor = snapshot.revision
        self.persistence = persistence; self.scheduler = scheduler; self.overlay = overlay; self.uptime = uptime
    }
    public static func restored(persistence: any HintPreferenceWriting,
                                scheduler: any HintDeadlineScheduling, overlay: any HintOverlayPresenting,
                                uptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) async -> HintExecutionHost {
        let snapshot = await persistence.snapshot()
        return HintExecutionHost(snapshot: snapshot, persistence: persistence, scheduler: scheduler, overlay: overlay, uptime: uptime)
    }
    public func updateContext(_ context: HintContext) throws {
        guard !disposed, isRunning else { return }
        let operation = beginOperation()
        if resetCheck != nil { deferredContext = context; return }
        guard let now = try time(for: operation) else { return }
        let previous = hints.visible
        try hints.updateContext(context, at: now)
        if hints.trialRest == nil { sources.cancelPendingRest(reason: .targetRemoval) }
        guard current(operation) else { return }
        if let previous, previous.offer.id != hints.visible?.offer.id {
            overlay.hide(offerID: previous.offer.id)
            guard current(operation) else { return }
        }
        queuePersistence()
        try drive(at: now, operation: operation)
    }
    public func request(_ kind: FirstUseHintKind) throws {
        guard isRunning, !disposed, resetCheck == nil else { return }
        let operation = beginOperation()
        guard let now = try time(for: operation) else { return }
        hints.request(kind); try drive(at: now, operation: operation)
    }
    public func beginDwell(_ kind: FirstUseHintKind) throws {
        guard isRunning, !disposed, resetCheck == nil else { return }
        let operation = beginOperation()
        guard let now = try time(for: operation) else { return }
        try hints.beginDwell(kind, at: now); armDeadline()
    }
    public func beginDockRevealDwell() throws {
        guard let kind = hints.reservedDockHint else { return }; try beginDwell(kind)
    }
    public func cancelDwell(_ kind: FirstUseHintKind) {
        guard !disposed else { return }; _ = beginOperation(); hints.cancelDwell(kind); armDeadline()
    }
    @discardableResult public func beginTrialRest(on target: TrialHintTarget, at eventTime: TimeInterval) -> Bool {
        guard isRunning, !disposed, resetCheck == nil else { return false }
        let operation = beginOperation()
        do {
            guard let now = try time(for: operation), eventTime.isFinite, eventTime >= 0, eventTime <= now else { return false }
            let rest = try hints.beginTrialRest(on: target, at: now); armDeadline()
            return current(operation) && hints.trialRest == rest && rest != nil
        } catch { return false }
    }
    public func cancelTrialRest(on target: TrialHintTarget, reason: TrialHintCancellation) {
        guard let rest = hints.trialRest, rest.target == target else { return }
        _ = beginOperation(); hints.cancelTrialRest(rest, reason: reason); armDeadline()
    }
    public func dismiss() {
        guard !disposed else { return }
        let operation = beginOperation(), previous = hints.visible
        hints.dismiss(); sources.cancelPendingRest(reason: .keyInput)
        guard generation == operation else { return }
        deadlineID = nil; scheduler.cancel()
        guard generation == operation else { return }
        if let previous { overlay.hide(offerID: previous.offer.id) }
    }
    public func suspend() {
        guard !disposed else { return }; isRunning = false; dismiss()
    }
    public func resume(context: HintContext) throws {
        guard !disposed else { return }; isRunning = true; try updateContext(context)
    }
    public func dispose() {
        guard !disposed else { return }
        disposed = true; isRunning = false; generation &+= 1
        let previous = hints.visible; hints.dismiss()
        sources.cancelPendingRest(reason: .targetRemoval)
        deadlineID = nil; scheduler.cancel()
        if let previous { overlay.hide(offerID: previous.offer.id) }
    }
    /// App composition retires a timed-out Settings consumer before releasing the editor save.
    /// Keep real in-memory seen/budget truth, but fence late writes and never start another pending write.
    func abandonPendingPersistenceForRetirement() {
        writeEpoch &+= 1; pending = nil; resetCheck = nil; deferredContext = nil; onPersisted = nil
    }
    /// A newer unrelated snapshot is a revision floor, NEVER permission to rebase a stale hint write.
    /// Reset requests are delivered separately, tagged with the successful editor commit revision.
    public func observeCommitted(_ snapshot: SettingsSnapshot) { revisionFloor = max(revisionFloor, snapshot.revision) }

    /// Validate a committed reset against this same writer before clearing in-memory flags/budgets.
    /// Pause new offers/writes during verification; failed/stale requests do not clear seen truth.
    @discardableResult public func applyCommittedReset(_ request: SettingsHostRequest) async -> Bool {
        guard !disposed, request.intent == .action(.resetHelpHints), request.revision > 0 else { return false }
        generation &+= 1; let token = UUID(); resetCheck = token
        deadlineID = nil; scheduler.cancel()
        guard resetCheck == token, !disposed else { return false }
        hints.cancelTrialRest(reason: .targetRemoval); sources.cancelPendingRest(reason: .targetRemoval)
        let snapshot = await persistence.snapshot()
        guard resetCheck == token, !disposed else { return false }
        let operation = beginOperation()
        resetCheck = nil; let deferred = deferredContext; deferredContext = nil
        let accepted = snapshot.revision == request.revision && snapshot.revision >= revisionFloor
            && snapshot.preferences.helpHints == FirstUseHintPreferences()
        revisionFloor = max(revisionFloor, snapshot.revision)
        if accepted {
            writeEpoch &+= 1; pending = nil; revision = snapshot.revision; saved = snapshot.preferences.helpHints
            persistenceError = nil; let previous = hints.visible; hints.reset()
            if let previous { overlay.hide(offerID: previous.offer.id) }
        }
        guard generation == operation, !disposed else { return accepted }
        if let deferred, isRunning { try? updateContext(deferred) } else { armDeadline() }
        startWriteIfNeeded()
        return accepted
    }
    /// Only a typed, contiguous editor transaction which preserved the saved hint ledger can
    /// advance a stale CAS base. A fresh snapshot alone is never sufficient evidence.
    /// The app serializes these receipts with reset receipts through the same binding.
    @discardableResult public func reconcileUnchangedHints(_ edit: SettingsCommittedEdit) async -> Bool {
        guard !disposed, resetCheck == nil, case .preferences = edit.kind,
              edit.before.revision == revision, edit.after.revision > edit.before.revision,
              edit.before.preferences.helpHints == saved, edit.after.preferences.helpHints == saved else { return false }
        let originalRevision = revision, originalSaved = saved, epoch = writeEpoch
        _ = beginOperation(); let token = UUID(); resetCheck = token
        deadlineID = nil; scheduler.cancel()
        guard resetCheck == token, !disposed else { return false }
        let originMatches = await persistence.acceptsOrigin(of: edit)
        guard resetCheck == token, !disposed else { return false }
        let snapshot = await persistence.snapshot()
        guard resetCheck == token, !disposed else { return false }
        let operation = beginOperation(); resetCheck = nil
        let deferred = deferredContext; deferredContext = nil
        let accepted = originMatches && revision == originalRevision && saved == originalSaved && writeEpoch == epoch
            && snapshot.revision == edit.after.revision && snapshot.revision >= revisionFloor
            // Origin plus the exact monotonically increasing actor revision identifies the receipt.
            && snapshot.preferences.helpHints == edit.after.preferences.helpHints
        revisionFloor = max(revisionFloor, snapshot.revision)
        if accepted {
            // A write suspended before this edit can only fail its old CAS; fence its completion.
            writeEpoch &+= 1; revision = snapshot.revision; saved = snapshot.preferences.helpHints
            pending = hints.preferences == saved ? nil : hints.preferences
            if (persistenceError as? SettingsError) == .staleRevision { persistenceError = nil }
        }
        guard generation == operation, !disposed else { return accepted }
        if let deferred, isRunning { try? updateContext(deferred) } else { armDeadline() }
        startWriteIfNeeded()
        return accepted
    }
    /// Explicit retry keeps the captured CAS revision. It never snapshots/rebases over a possible reset.
    public func retryPersistence() {
        persistenceError = nil
        queuePersistence()
        // The same ledger may already be retained in pending; explicit retry still drains it.
        startWriteIfNeeded()
    }
    public func flushPersistence() async { while let task = writeTask { await task.value } }

    private func beginOperation() -> UInt64 {
        generation &+= 1
        // An unconfirmed outer render cannot hold the arbiter hostage after reentrant input.
        if let offer = hints.offered { hints.reject(offer) }
        return generation
    }
    private func current(_ operation: UInt64) -> Bool { generation == operation && isRunning && !disposed && resetCheck == nil }
    private func time(for operation: UInt64) throws -> TimeInterval? {
        let now = uptime(); guard current(operation) else { return nil }
        guard now.isFinite, now >= 0, (now + FirstUseHints.visibleSeconds).isFinite,
              now + FirstUseHints.visibleSeconds > now else { throw SettingsError.invalidTime }
        return now
    }
    private func drive(at now: TimeInterval, operation: UInt64) throws {
        guard current(operation) else { return }
        let previous = hints.visible; try hints.advance(at: now)
        if let previous, hints.visible == nil {
            overlay.hide(offerID: previous.offer.id); guard current(operation) else { return }
        }
        if let visible = hints.visible {
            let remainsVisible = overlay.updateAndVerify(visible)
            guard current(operation) else { return }
            if !remainsVisible {
                hints.dismiss(); sources.cancelPendingRest(reason: .targetRemoval)
                guard current(operation) else { return }
                overlay.hide(offerID: visible.offer.id)
                guard current(operation) else { return }
            }
            armDeadline(); return
        }
        let trial = hints.trialRest == nil ? nil : sources.validatePendingRest()
        guard current(operation) else { return }
        // A trial candidate without a current source must not become a display offer.
        if hints.trialRest != nil, trial == nil { hints.cancelTrialRest(reason: .targetRemoval) }
        let kinds = overlay.placeableKinds(context: hints.context, trial: trial)
        guard current(operation) else { return }
        guard let offer = try hints.nextOffer(placeable: kinds, at: now) else { armDeadline(); return }
        let shown = overlay.showAndVerify(offer, trial: offer.kind == .trial ? trial : nil)
        guard current(operation), hints.offered == offer else { overlay.hide(offerID: offer.id); return }
        if offer.kind == .trial {
            let still = sources.validatePendingRest()
            guard current(operation), hints.offered == offer, still == trial, still != nil else {
                hints.reject(offer); overlay.hide(offerID: offer.id); return
            }
        }
        guard shown else { hints.reject(offer); overlay.hide(offerID: offer.id); armDeadline(); return }
        do {
            guard let confirmedAt = try time(for: operation), hints.offered == offer else { overlay.hide(offerID: offer.id); return }
            try hints.confirmShown(offer, at: confirmedAt)
        } catch { hints.reject(offer); overlay.hide(offerID: offer.id); throw error }
        if let target = offer.trialTarget { sources.didConfirmShown(target) }
        queuePersistence(); guard current(operation) else { return }; armDeadline()
    }
    private func armDeadline() {
        deadlineID = nil
        guard isRunning, !disposed, resetCheck == nil, let deadline = hints.nextDeadline else { scheduler.cancel(); return }
        let id = UUID(); deadlineID = id
        scheduler.arm(at: deadline) { [weak self] in
            guard let self, self.deadlineID == id, self.isRunning, !self.disposed, self.resetCheck == nil else { return }
            self.deadlineID = nil; let operation = self.beginOperation()
            do { if let now = try self.time(for: operation) { try self.drive(at: now, operation: operation) } }
            catch { self.dismiss() }
        }
    }
    private func queuePersistence() {
        let preferences = hints.preferences
        if pending == preferences || (writing?.epoch == writeEpoch && writing?.preferences == preferences) { return }
        if preferences == saved, writing == nil { pending = nil; return }
        pending = preferences; startWriteIfNeeded()
    }
    private func startWriteIfNeeded() {
        guard resetCheck == nil, writing == nil, persistenceError == nil, let preferences = pending else { return }
        pending = nil
        let write = Write(id: UUID(), epoch: writeEpoch, revision: revision, preferences: preferences)
        writing = write
        writeTask = Task { [weak self, persistence] in
            let result: Result<SettingsSnapshot, Error>
            do { result = .success(try await persistence.saveHints(preferences, expectedRevision: write.revision)) }
            catch { result = .failure(error) }
            self?.finished(write, result: result)
        }
    }
    private func finished(_ write: Write, result: Result<SettingsSnapshot, Error>) {
        guard writing?.id == write.id else { return }
        writing = nil; writeTask = nil
        guard write.epoch == writeEpoch else { startWriteIfNeeded(); return }
        switch result {
        case .success(let receipt):
            saved = receipt.preferences.helpHints; revision = receipt.revision
            if receipt.revision < revisionFloor { failPersistence(SettingsError.staleRevision); return }
            revisionFloor = receipt.revision
            if hints.preferences == saved { pending = nil } else { pending = hints.preferences }
            startWriteIfNeeded()
            onPersisted?(receipt)
        case .failure(let error): failPersistence(error)
        }
    }
    private func failPersistence(_ error: Error) {
        pending = hints.preferences; persistenceError = error; onPersistenceFailure?(error)
    }
}
