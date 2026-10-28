// SPDX-License-Identifier: MIT
import Foundation

@MainActor public protocol RefreshTimeSource: AnyObject {
    var wall: Date { get }
    var elapsed: TimeInterval { get }
}
@MainActor public final class SystemRefreshTime: RefreshTimeSource {
    private let origin = ContinuousClock.now
    public init() {}
    public var wall: Date { Date() }
    public var elapsed: TimeInterval {
        let c = origin.duration(to: .now).components
        return Double(c.seconds) + Double(c.attoseconds) / 1e18
    }
}

public struct StoreDiagnostics: Sendable {
    public init() {}
    public var detection: String? = "not-requested"
    public var detectionReadAt: Date?
    public var detectionReport: DetectionReport?
    public var personal: String? = "not-loaded"
    public var publication: String? = "not-loaded"
    public var publicationWarning = false
    public var publicationReadAt: Date?
    public var publicationLastGoodReadAt: Date?
    public var childRunning = false
}

/// Immutable validated feeds live only in this store's memory, not in another personal-history database.
/// Every returned view rechecks deadlines; dataRevision is never a freshness shortcut.
@MainActor public final class SnapshotStore {
    private let transport: any CLITransport
    private let decoder = DecodeWorker()
    private let time: any RefreshTimeSource
    private let automaticTimers: Bool
    private var personal: PersonalSnapshot?, publication: PublicPublication?
    private var personalUsable = false, publicUsable = false
    private var ledger = ExpiryLedger()
    private var pending: [CLICommand] = []
    private var worker: Task<Void, Never>?
    private var activeCommand: CLICommand?
    private var activeCommandGeneration: Int?
    public var detectionReport: DetectionReport? { diagnostics.detectionReport }
    private var timer: Timer?
    private var generation = 0
    private var suspended = true
    private var surfacesVisible = false
    private var accountRefreshDue: TimeInterval = 0
    private static let accountRefreshInterval: TimeInterval = 300
    private var desktopDue: TimeInterval = .infinity, publicationDue: TimeInterval = .infinity
    private var knownDeadline: Date?
    private var expiryRefreshNeeded = false
    private var retriedJoin: String?
    public private(set) var diagnostics = StoreDiagnostics()
    public var onChange: (() -> Void)?
    public init(transport: any CLITransport, time: (any RefreshTimeSource)? = nil, automaticTimers: Bool = true) {
        self.transport = transport; self.time = time ?? SystemRefreshTime(); self.automaticTimers = automaticTimers
    }
    deinit { timer?.invalidate(); worker?.cancel() }
    public func start() { guard suspended else { return }; resume() }
    /// Hosts report actual Dock (including its sliver) or cockpit visibility, independently of OS pauses.
    /// A visibility change never clears sleep/lock suspension or resets the attempt spacing.
    public func setSurfacesVisible(dock: Bool, cockpit: Bool) {
        let visible = dock || cockpit
        guard visible != surfacesVisible else { return }
        surfacesVisible = visible
        if visible, !suspended { enqueue(.desktop); kick() }
        arm()
    }
    public func refresh() {
        guard !suspended else { return }
        enqueue(.desktop); enqueue(.publicationOffline); enqueue(.publication); kick()
    }
    /// Explicit caller request only; start/resume/refresh never scan for installed tools.
    /// Uses the existing serialized child queue, with no independent timer or reader.
    public func requestDetection() {
        guard !suspended, !pending.contains(.detect) else { return }
        // A cancelled older generation still owns the child slot, but not this awake request.
        guard activeCommand != .detect || activeCommandGeneration != generation else { return }
        enqueue(.detect); kick()
    }
    /// Sleep/lock/user switch/display removal use this transaction; ordinary app deactivation does not.
    public func suspend() {
        guard !suspended else { return }
        suspended = true; generation += 1; pending.removeAll(); timer?.invalidate(); timer = nil
        diagnostics.detectionReport = nil; diagnostics.detection = "not-requested"; diagnostics.detectionReadAt = nil
        worker?.cancel() // Retain the slot until the transport has reaped its child.
        onChange?()
    }
    public func resume() {
        guard suspended else { return }
        suspended = false; generation += 1
        _ = view() // Retire UTC deadlines before publishing the restored frame.
        desktopDue = time.elapsed; publicationDue = time.elapsed
        enqueue(.desktop); enqueue(.publicationOffline); enqueue(.publication)
        onChange?(); kick()
    }
    public func clockOrTimeZoneChanged() {
        // A forward jump while suspended must retire evidence before a later backward jump.
        _ = view()
        tick()
    }
    public func tick() {
        guard !suspended else { return }
        _ = view()
        if time.elapsed >= desktopDue || expiryRefreshNeeded || (surfacesVisible && time.elapsed >= accountRefreshDue) { enqueue(.desktop); expiryRefreshNeeded = false }
        if time.elapsed >= publicationDue { enqueue(.publication) }
        onChange?(); kick(); arm()
    }
    public func view() -> JoinedSnapshot? { view(at: time.wall) }
    private func view(at now: Date) -> JoinedSnapshot? {
        guard let personal else { return nil }
        if let deadline = knownDeadline, deadline <= now { expiryRefreshNeeded = true }
        var projection = PersonalProjection.evaluate(personal, now: now, ledger: &ledger)
        knownDeadline = projection.nextDeadline
        if suspended || !personalUsable { projection = projection.stale(reason: suspended ? "suspended" : "personal-read-unavailable") }
        return JoinedSnapshot.make(personal: personal, presentation: projection, publication: publication, publicUsable: publicUsable)
    }
    /// A dated public catalog is independent of account availability and of the scored join.
    public func modelSelectionFeeds() -> ModelSelectionFeeds { selectionFeeds(for: view()) }
    private func selectionFeeds(for current: JoinedSnapshot?) -> ModelSelectionFeeds {
        ModelSelectionFeeds(publication: publication, personal: personal,
            personalUsable: current?.presentation.actionable == true,
            publicIsLastGood: !publicUsable || diagnostics.publicationWarning)
    }
    /// Capture all host/selector facts before any rendering callout can change store state.
    public func observation() -> SnapshotObservation {
        let now = time.wall
        let current = view(at: now)
        return SnapshotObservation(observedAt: now, snapshot: current,
            selectionFeeds: selectionFeeds(for: current), diagnostics: diagnostics)
    }
    /// Test/termination hook: cancellation is complete only after this returns.
    public func stopAndWait() async { suspend(); await worker?.value }
    public var idle: Bool { worker == nil && pending.isEmpty }
    private func enqueue(_ command: CLICommand) { if !pending.contains(command) { pending.append(command) } }
    private func kick() {
        guard !suspended, worker == nil, !pending.isEmpty else { return }
        // Do not start a bounded publication child across the next personal-read deadline.
        if pending.first != .desktop && desktopDue - time.elapsed < 30 { pending.removeAll { $0 == .desktop }; pending.insert(.desktop, at: 0) }
        let command = pending.removeFirst(), token = generation
        activeCommand = command; activeCommandGeneration = token
        if command == .desktop { desktopDue = time.elapsed + 60 }
        if command == .publication { publicationDue = time.elapsed + 600 }
        diagnostics.childRunning = true
        worker = Task { [weak self, transport, decoder] in
            do {
                try Task.checkCancellation()
                // Check visibility at execution time: presentation can resume after kick() queued
                // this worker. Both commands keep the same slot, including cancellation/reaping.
                if command == .desktop, let self, self.surfacesVisible,
                   self.time.elapsed >= self.accountRefreshDue {
                    self.accountRefreshDue = self.time.elapsed + Self.accountRefreshInterval
                    do { _ = try await transport.execute(.refreshAccount) } catch { /* Best effort. */ }
                    try Task.checkCancellation()
                }
                if command == .desktop, let self { self.desktopDue = self.time.elapsed + 60 }
                let result = try await transport.execute(command)
                try Task.checkCancellation()
                switch command {
                case .detect:
                    guard result.exitCode == 0 else { throw FeedError.malformed("detect-exit") }
                    let value = try await decoder.detection(result.stdout)
                    guard let self, token == self.generation, !self.suspended else { break }
                    self.diagnostics.detectionReport = value
                    self.diagnostics.detection = nil; self.diagnostics.detectionReadAt = self.time.wall
                case .refreshAccount:
                    // Refresh output is never a feed; the desktop worker invokes it above.
                    break
                case .desktop:
                    guard result.exitCode == 0 else { throw FeedError.malformed("desktop-exit") }
                    let value = try await decoder.personal(result.stdout)
                    guard let self, token == self.generation, !self.suspended else { break }
                    self.personal = value; self.personalUsable = true; self.diagnostics.personal = nil
                case .publication, .publicationOffline:
                    guard result.exitCode == 0 else { throw FeedError.malformed(result.exitCode == 3 && result.stdout.isEmpty ? "publication-unavailable" : "publication-exit") }
                    let value = try await decoder.publication(result.stdout)
                    guard let self, token == self.generation, !self.suspended else { break }
                    self.publication = value; self.publicUsable = true
                    self.diagnostics.publication = value.supportedUnits ? nil : "unsupported-units"
                    self.diagnostics.publicationWarning = result.warning
                    self.diagnostics.publicationReadAt = self.time.wall
                    if !result.warning { self.diagnostics.publicationLastGoodReadAt = self.time.wall }
                }
            } catch {
                if let self, token == self.generation, !self.suspended {
                    if command == .detect {
                        self.diagnostics.detectionReport = nil; self.diagnostics.detection = "detection-read-unavailable"
                        self.diagnostics.detectionReadAt = nil
                    }
                    else if command == .desktop { self.personalUsable = false; self.diagnostics.personal = "personal-read-unavailable" }
                    else {
                        self.diagnostics.publication = "publication-read-unavailable"
                        self.diagnostics.publicationWarning = self.publication != nil
                        // A previously validated last-good public feed remains dated, never fabricated as fresh.
                        if self.publication == nil { self.publicUsable = false }
                    }
                }
            }
            guard let self else { return }
            self.worker = nil; self.activeCommand = nil; self.activeCommandGeneration = nil
            self.diagnostics.childRunning = false
            if token == self.generation && !self.suspended {
                self.reconcileIDs(); _ = self.view(); self.onChange?()
            }
            self.kick(); self.arm()
        }
        arm()
    }
    private func reconcileIDs() {
        guard let publicID = publication?.publicationId else { retriedJoin = nil; return }
        let personalID = personal?.publication?.publicationId
        guard publicID != personalID else { retriedJoin = nil; return }
        let pair = (personalID ?? "<unavailable>") + "|" + publicID
        if retriedJoin != pair { retriedJoin = pair; enqueue(.desktop) }
    }
    private func arm() {
        timer?.invalidate(); timer = nil
        guard automaticTimers, !suspended else { return }
        // Pending work owns past cadence deadlines; completion re-arms them. Never poll a slow child.
        var delays = [desktopDue - time.elapsed, publicationDue - time.elapsed].filter { $0 > 0 && $0.isFinite }
        if surfacesVisible, accountRefreshDue > time.elapsed { delays.append(accountRefreshDue - time.elapsed) }
        if let deadline = view()?.presentation.nextDeadline {
            let delay = deadline.timeIntervalSince(time.wall)
            if delay > 0 { delays.append(delay) }
        }
        guard let next = delays.min() else { return }
        let delay = max(0.01, next)
        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common); self.timer = timer
    }
}

extension PersonalProjection {
    func stale(reason: String) -> Self {
        Self(actionable: false, unavailableReason: reason, quotas: quotas.map { QuotaReading(source: $0.source, subscription: $0.subscription, kind: $0.kind,
             remaining: nil, historicalRemaining: $0.historicalRemaining, reason: reason, observedAt: $0.observedAt) },
             current: current.map { CurrentConfiguration(source: $0.source, harnessModel: $0.harnessModel, effort: nil) },
             live: live.map { LiveReading(ref: $0.ref, subscription: $0.subscription, working: false, rate: nil) }, events: [], nextDeadline: nextDeadline)
    }
}
