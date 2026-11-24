// SPDX-License-Identifier: MIT
import AppKit
import OSLog
import ModelPlanCore
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanShell
import ModelPlanWire

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
    /// The resume's own start and subscriptions are in flight; the session they bring up is adopted there.
    private var starting = false
    /// The latest session the client reported ready, while starting too: reconciled once the start attempt finishes.
    private var lastReady: EngineDeliveryContext?
    /// G3-116 / recovery step 6: the engine stopped on its own (crash limit cooldown, cleanup failure, stall). The
    /// supervisor brings it back by itself (step 5); Refresh and the next resume reconcile with it sooner.
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
        if desired { DiagnosticsLog.shared.info("lifecycle", "engine suspend") }
        if !desired, stopTask != nil { onPause(); return }
        generation &+= 1; desired = false; subscriptionReady = false; delivered = false; starting = false
        expected = nil; fresh = nil; startTask?.cancel(); onPause()
        let prior = stopTask, client = composition.client
        stopTask = Task { await prior?.value; await client.stop() }
    }
    func resume() {
        guard !desired else { return }
        DiagnosticsLog.shared.info("lifecycle", "engine resume retry=\(manualRetry)")
        desired = true; generation &+= 1; let token = generation
        let useRetry = manualRetry; manualRetry = false
        subscriptionReady = false; delivered = false; expected = nil; fresh = nil; starting = true
        let prior = stopTask
        startTask = Task { @MainActor [weak self] in
            await prior?.value
            guard let self, self.desired, self.generation == token, !Task.isCancelled else { return }
            do {
                let context: EngineDeliveryContext
                do { context = try await (useRetry ? self.composition.client.retry() : self.composition.client.start()) }
                catch EngineClientError.notReady where !useRetry {
                    // Recovery step 6 (replaces #959's one-shot workaround): the supervisor is cooling down after its
                    // crash limit, or waiting for a stalled consumer. A resume (wake, unlock, display wake) is the moment
                    // to reconcile: retry() skips the cooldown. If it still refuses, the supervisor's own half-open
                    // attempt is adopted when it becomes ready (acceptedEvent).
                    guard self.desired, self.generation == token, !Task.isCancelled else { return }
                    DiagnosticsLog.shared.info("lifecycle", "engine reconcile retry after notReady")
                    context = try await self.composition.client.retry()
                }
                guard self.desired, self.generation == token, !Task.isCancelled else { return }
                self.expected = context
                do { _ = try await self.composition.client.subscribeRows(timeout: nil) }
                catch EngineClientError.rpc(let code, _) where code == WireErrorCode.busy {
                    // The client's bootstrap recovery will deliver the first rows. Keep this
                    // session and let publishIfFresh wait for its accepted rows and consent.
                }
                guard self.desired, self.generation == token, !Task.isCancelled else { return }
                do { _ = try await self.composition.client.consent(timeout: nil) }
                catch EngineClientError.unsupportedCapability { /* Older engines may not expose consent. */ }
                guard self.desired, self.generation == token, !Task.isCancelled else { return }
                self.subscriptionReady = true; self.publishIfFresh()
                self.finishStart(token)
            } catch {
                guard self.desired, self.generation == token, !Task.isCancelled else { return }
                Self.log.error("Engine restart or consent failed error=\(Self.errorName(error), privacy: .public)")
                self.subscriptionReady = false; self.delivered = false; self.onPause(); self.onStartFailed?()
                self.finishStart(token)
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
    /// Recovery step 6: a session the supervisor brought up by itself (after a crash, a cooldown, a stall, or after the
    /// resume's own start failed) is the lifecycle's session from now on. The client subscribes rows and consent on
    /// every fresh session itself, so its rows publish the readings again; nothing is restarted for it.
    /// macrev2-999-1: the start attempt is over (it succeeded or failed). A session the supervisor reported ready while it
    /// was in flight (the attempt's own session failed and a replacement came up) is reconciled now: the latest ready
    /// session that is still the client's current delivery becomes the lifecycle's session.
    private func finishStart(_ token: UInt64) {
        guard generation == token else { return }
        starting = false
        if let ready = lastReady, composition.client.isCurrent(ready) { adoptSupervisedSession(ready) }
    }
    private func adoptSupervisedSession(_ context: EngineDeliveryContext) {
        guard desired, !starting, expected?.sessionID != context.sessionID else { return }
        DiagnosticsLog.shared.info("lifecycle", "engine session adopted from the supervisor")
        expected = context; subscriptionReady = true; delivered = false
        publishIfFresh()
    }
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
            // The supervisor brings it back by itself (step 5); Refresh (retryPending) and the next resume do so sooner.
            engineStopped = true; delivered = false
        case .connection(.ready(let context)):
            engineStopped = false; lastReady = context
            adoptSupervisedSession(context)
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
         displaysAsleep: @escaping @MainActor (Set<UInt32>) -> Bool, screenLocked: (@MainActor () -> Bool?)? = nil,
         onPause: @escaping @MainActor () -> Void, onReady: @escaping @MainActor () -> Void,
         onGateOpen: @escaping @MainActor () -> Void, onStartFailed: (@MainActor () -> Void)? = nil) {
        let worker = EngineLifecycleWorker(composition: composition, onPause: onPause, onReady: onReady, onStartFailed: onStartFailed)
        let gate = LifecycleCoordinator(store: worker)
        self.worker = worker; self.gate = gate
        self.events = SystemEvents(gate: gate, workspace: workspace, local: local, distributed: lockEvents, displayIDs: displayIDs,
                                   onConsole: onConsole, displaysAsleep: displaysAsleep, screenLocked: screenLocked)
        gate.onPresentationChange = { allowed in
            DiagnosticsLog.shared.info("lifecycle", "presentation allowed=\(allowed)")
            if allowed { onGateOpen() } else { onPause() }
        }
    }
    func start() { events.start() }
    /// Spec item 2: the single wake/unlock/clock/display source for every other consumer (the cockpit).
    func subscribe(_ handler: @escaping @MainActor (SystemSignal) -> Void) -> () -> Void { events.subscribe(handler) }
    var canRetry: Bool { gate.canPresent }
    /// G3-116: the engine stopped on its own; Refresh retries it as it does a paused one.
    var engineStopped: Bool { worker.engineStopped }
    func retryPending() { guard gate.canPresent else { return }; worker.retryPending() }
    func setActivityPaused(_ paused: Bool) { gate.set(.activity, blocked: paused) }
    func stop() async { events.stop(); await gate.stop() }
}
