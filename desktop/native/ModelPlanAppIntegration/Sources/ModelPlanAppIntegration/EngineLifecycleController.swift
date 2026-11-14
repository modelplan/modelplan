// SPDX-License-Identifier: MIT
import AppKit
import OSLog
import ModelPlanCore
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanShell

/// Adapts the existing multi-reason lifecycle gate to the app-server client.
@MainActor private final class EngineLifecycleWorker: LifecycleStore, EngineStoreEventSink {
    private let composition: EngineDockMenuComposition
    private let onPause: @MainActor () -> Void
    private let onReady: @MainActor () -> Void
    /// First run v1: the reader did not start (spawn, handshake or first subscription failed), for the page to say so.
    private let onStartFailed: (@MainActor () -> Void)?
    private var attachment: UUID?
    private var desired = false, subscriptionReady = false, delivered = false, manualRetry = false
    private var generation: UInt64 = 0
    private var expected: EngineDeliveryContext?, fresh: EngineDeliveryContext?
    private var startTask: Task<Void, Never>?, stopTask: Task<Void, Never>?
    /// G3-116: the engine stopped on its own (crash limit, cleanup failure) and waits for an explicit retry.
    private(set) var engineStopped = false
    private static let log = Logger(subsystem: "org.modelplan.community", category: "lifecycle")
    /// The error's case name only, never associated values.
    private static func errorName(_ error: Error) -> String {
        String(String(describing: error).prefix { $0.isLetter || $0.isNumber || $0 == "." }.prefix(48))
    }

    init(composition: EngineDockMenuComposition, onPause: @escaping @MainActor () -> Void,
         onReady: @escaping @MainActor () -> Void, onStartFailed: (@MainActor () -> Void)? = nil) {
        self.composition = composition; self.onPause = onPause; self.onReady = onReady; self.onStartFailed = onStartFailed
        attachment = composition.store.attach(self)
    }
    func suspend() {
        if !desired, stopTask != nil { onPause(); return }
        generation &+= 1; desired = false; subscriptionReady = false; delivered = false
        expected = nil; fresh = nil; startTask?.cancel(); onPause()
        let prior = stopTask, client = composition.client
        stopTask = Task { await prior?.value; await client.stop() }
    }
    func resume() {
        guard !desired else { return }
        desired = true; generation &+= 1; let token = generation
        let useRetry = manualRetry; manualRetry = false
        subscriptionReady = false; delivered = false; expected = nil; fresh = nil
        let prior = stopTask
        startTask = Task { @MainActor [weak self] in
            await prior?.value
            guard let self, self.desired, self.generation == token, !Task.isCancelled else { return }
            do {
                let context: EngineDeliveryContext
                do { context = try await (useRetry ? self.composition.client.retry() : self.composition.client.start()) }
                catch EngineClientError.notReady where !useRetry {
                    // G3-116: after the engine crashed past its restart budget the client takes only an explicit
                    // retry, so every later wake or unlock failed here at once and the widget kept "?" until quit.
                    // A resume is that explicit moment: retry once.
                    guard self.desired, self.generation == token, !Task.isCancelled else { return }
                    Self.log.error("Engine start needs a retry; retrying")
                    context = try await self.composition.client.retry()
                }
                guard self.desired, self.generation == token, !Task.isCancelled else { return }
                self.expected = context
                _ = try await self.composition.client.subscribeRows(timeout: nil)
                guard self.desired, self.generation == token, !Task.isCancelled else { return }
                do { _ = try await self.composition.client.consent(timeout: nil) }
                catch EngineClientError.unsupportedCapability { /* Older engines may not expose consent. */ }
                guard self.desired, self.generation == token, !Task.isCancelled else { return }
                self.subscriptionReady = true; self.publishIfFresh()
            } catch {
                guard self.desired, self.generation == token, !Task.isCancelled else { return }
                Self.log.error("Engine restart or consent failed error=\(Self.errorName(error), privacy: .public)")
                self.subscriptionReady = false; self.delivered = false; self.onPause(); self.onStartFailed?()
            }
        }
    }
    func stopAndWait() async {
        suspend()
        let stopping = stopTask, starting = startTask
        await stopping?.value; await starting?.value
        if let attachment { composition.store.detach(attachment); self.attachment = nil }
    }
    func clockOrTimeZoneChanged() { if desired { suspend(); resume() } }
    func retryPending() { if desired && !delivered { suspend(); manualRetry = true; resume() } }
    func clearPrivateViews(_ invalidation: EngineInvalidation) { fresh = nil }
    func apply(_ snapshot: EngineStoreSnapshot) { publishIfFresh() }
    func acceptedEvent(_ event: EngineClientEvent) {
        switch event {
        case .rowsChanged(let reply, _): fresh = reply.delivery
        case .response(_, .rows(let reply, _)): fresh = reply.delivery
        // G3-116: the engine's own restarts and stops were not logged anywhere, so a lost delivery could not be told
        // apart from a cockpit fault. Reasons and counters only.
        case .connection(.restarting(let attempt, _)):
            Self.log.error("Engine connection lost; restart attempt=\(attempt, privacy: .public)")
        case .connection(.stopped(let reason)) where reason != .requested:
            Self.log.error("Engine stopped reason=\(String(describing: reason), privacy: .public)")
            // Nothing restarts it on its own now: let Refresh (retryPending) and the next resume retry it.
            engineStopped = true; delivered = false
        case .connection(.ready): engineStopped = false
        default: break
        }
    }
    private func publishIfFresh() {
        guard desired, subscriptionReady, !delivered, let expected, let fresh,
              fresh.sessionID == expected.sessionID, composition.store.snapshot.delivery == fresh,
              composition.store.snapshot.rows != nil, composition.client.isCurrent(fresh) else { return }
        delivered = true; onReady()
    }
}

/// SystemEvents and the app-server activity observer share one independent-reasons gate.
@MainActor final class EngineLifecycleController {
    private let worker: EngineLifecycleWorker
    private let gate: LifecycleCoordinator
    private let events: SystemEvents
    init(composition: EngineDockMenuComposition, workspace: NotificationCenter, local: NotificationCenter,
         lockEvents: NotificationCenter, displayIDs: @escaping @MainActor () -> Set<UInt32>, onConsole: @escaping @MainActor () -> Bool?,
         displaysAsleep: @escaping @MainActor (Set<UInt32>) -> Bool,
         onPause: @escaping @MainActor () -> Void, onReady: @escaping @MainActor () -> Void,
         onGateOpen: @escaping @MainActor () -> Void, onStartFailed: (@MainActor () -> Void)? = nil) {
        let worker = EngineLifecycleWorker(composition: composition, onPause: onPause, onReady: onReady, onStartFailed: onStartFailed)
        let gate = LifecycleCoordinator(store: worker)
        self.worker = worker; self.gate = gate
        self.events = SystemEvents(gate: gate, workspace: workspace, local: local, distributed: lockEvents, displayIDs: displayIDs,
                                   onConsole: onConsole, displaysAsleep: displaysAsleep)
        gate.onPresentationChange = { allowed in if allowed { onGateOpen() } else { onPause() } }
    }
    func start() { events.start() }
    var canRetry: Bool { gate.canPresent }
    /// G3-116: the engine stopped on its own; Refresh retries it as it does a paused one.
    var engineStopped: Bool { worker.engineStopped }
    func retryPending() { guard gate.canPresent else { return }; worker.retryPending() }
    func setActivityPaused(_ paused: Bool) { gate.set(.activity, blocked: paused) }
    func stop() async { events.stop(); await gate.stop() }
}
