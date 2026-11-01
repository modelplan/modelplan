// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanCore
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanShell

/// Adapts the existing multi-reason lifecycle gate to the app-server client.
@MainActor private final class EngineLifecycleWorker: LifecycleStore, EngineStoreEventSink {
    private let composition: EngineDockMenuComposition
    private let onPause: @MainActor () -> Void
    private let onReady: @MainActor () -> Void
    private var attachment: UUID?
    private var desired = false, subscriptionReady = false, delivered = false, manualRetry = false
    private var generation: UInt64 = 0
    private var expected: EngineDeliveryContext?, fresh: EngineDeliveryContext?
    private var startTask: Task<Void, Never>?, stopTask: Task<Void, Never>?

    init(composition: EngineDockMenuComposition, onPause: @escaping @MainActor () -> Void,
         onReady: @escaping @MainActor () -> Void) {
        self.composition = composition; self.onPause = onPause; self.onReady = onReady
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
                let context = try await (useRetry ? self.composition.client.retry() : self.composition.client.start())
                guard self.desired, self.generation == token, !Task.isCancelled else { return }
                self.expected = context
                _ = try await self.composition.client.subscribeRows(timeout: nil)
                guard self.desired, self.generation == token, !Task.isCancelled else { return }
                self.subscriptionReady = true; self.publishIfFresh()
                _ = try? await self.composition.client.consent(timeout: nil)
            } catch { /* Keep the presentation withdrawn until a current subscription succeeds. */ }
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
         onGateOpen: @escaping @MainActor () -> Void) {
        let worker = EngineLifecycleWorker(composition: composition, onPause: onPause, onReady: onReady)
        let gate = LifecycleCoordinator(store: worker)
        self.worker = worker; self.gate = gate
        self.events = SystemEvents(gate: gate, workspace: workspace, local: local, distributed: lockEvents, displayIDs: displayIDs,
                                   onConsole: onConsole, displaysAsleep: displaysAsleep)
        gate.onPresentationChange = { allowed in if allowed { onGateOpen() } else { onPause() } }
    }
    func start() { events.start() }
    var canRetry: Bool { gate.canPresent }
    func retryPending() { guard gate.canPresent else { return }; worker.retryPending() }
    func setActivityPaused(_ paused: Bool) { gate.set(.activity, blocked: paused) }
    func stop() async { events.stop(); await gate.stop() }
}
