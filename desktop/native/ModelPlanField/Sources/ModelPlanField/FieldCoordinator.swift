// SPDX-License-Identifier: MIT
import Foundation

@MainActor public protocol FieldTransport: AnyObject {
    func start(generation: UUID, receive: @escaping (Data) -> Void, failed: @escaping (FieldReleaseReason) -> Void)
    func send(_ command: FieldCommand)
    func snapshot(completion: @escaping (Data?) -> Void)
    func invalidate()
}

// Internal optional cancellation seam; the public transport contract is unchanged.
@MainActor protocol FieldSnapshotCancellation: AnyObject { func cancelSnapshot() }

@MainActor private final class FieldCaptureWork {
    let key: FieldCaptureKey
    let transport: any FieldTransport
    var cancelled = false, snapshotCompleted = false
    var preparation: Task<PreparedFieldStill?, Never>?
    var task: Task<Void, Never>?
    init(key: FieldCaptureKey, transport: any FieldTransport) { self.key = key; self.transport = transport }
    func cancel() {
        guard !cancelled else { return }
        cancelled = true
        (transport as? any FieldSnapshotCancellation)?.cancelSnapshot()
        preparation?.cancel(); task?.cancel()
    }
}

/// Nonvisual orchestration. Product enlargement is opt-in after the integrated resource/runtime gate.
/// Window visibility and workspace reasons are supplied by the native owner, not NSApp.isActive.
@MainActor public final class FieldCoordinator {
    public private(set) var state: FieldLifecycle
    public var onChange: ((FieldPhase) -> Void)?
    public var onCacheFailure: (() -> Void)?
    private let enabled: Bool
    private let makeTransport: () -> any FieldTransport
    private let cache: FieldStillCache
    private let now: () -> ContinuousClock.Instant
    private var transport: (generation: UUID, value: any FieldTransport)?
    private var timer: Timer?
    private var captureWork: FieldCaptureWork?
    // Internal test seam models slow/non-preemptible ImageIO without allocating a real field.
    var prepareImage: (Data) -> Task<PreparedFieldStill?, Never> = { data in
        Task.detached(priority: .utility) {
            guard !Task.isCancelled else { return nil }
            let image = try? FieldPNG.prepare(data)
            return Task.isCancelled ? nil : image
        }
    }
    public init(configuration: FieldConfiguration, cache: FieldStillCache, enlargementEnabled: Bool = false,
                now: @escaping () -> ContinuousClock.Instant = { .now },
                makeTransport: @escaping () -> any FieldTransport) {
        state = FieldLifecycle(configuration: configuration); self.cache = cache; enabled = enlargementEnabled
        self.now = now; self.makeTransport = makeTransport
    }
    public func enlarge() { guard enabled else { return }; perform(state.enlarge(now: now())) }
    public func update(_ configuration: FieldConfiguration) { perform(state.update(configuration, now: now())) }
    public func setVisibility(_ visibility: FieldVisibility) { perform(state.setVisibility(visibility, now: now())) }
    public func setBlocked(_ reason: FieldPauseReason, blocked: Bool) { perform(state.setBlocked(reason, blocked: blocked, now: now())) }
    public func clearCache() async throws { close(.cacheClear); try await cache.clear() }
    public func close(_ reason: FieldReleaseReason = .close) {
        perform(state.close(reason, now: now()))
        if reason == .memoryPressure { cache.clearDecoded() }
    }
    public func validateDeadlines() { perform(state.advance(now: now())) }
    private func receive(_ data: Data, generation: UUID) {
        guard let message = try? FieldWebMessage.decode(data), message.generation == generation else { return }
        perform(state.receive(message, now: now()))
    }
    private func perform(_ effects: [FieldEffect]) {
        if let work = captureWork, state.pendingCapture != work.key || state.generation != work.key.generation {
            work.cancel() // Cancel, but retain ownership and handles until the chain returns.
        }
        for effect in effects {
            switch effect {
            case .mount(let generation):
                let value = makeTransport(); transport = (generation, value)
                value.start(generation: generation, receive: { [weak self] data in self?.receive(data, generation: generation) },
                    failed: { [weak self] reason in
                        guard let self, self.state.generation == generation else { return }
                        self.close(reason)
                    })
            case .send(let command):
                if transport?.generation == command.generation { transport?.value.send(command) }
            case .release(let generation):
                if transport?.generation == generation {
                    captureWork?.cancel()
                    transport?.value.invalidate(); transport = nil
                }
            case .snapshot(let key):
                guard captureWork == nil, let transport, transport.generation == key.generation else { continue }
                let work = FieldCaptureWork(key: key, transport: transport.value)
                captureWork = work
                transport.value.snapshot { [weak self] data in self?.receivedSnapshot(data, work: work) }
            }
        }
        scheduleDeadline(); onChange?(state.phase)
    }
    private func receivedSnapshot(_ data: Data?, work: FieldCaptureWork) {
        guard captureWork === work, !work.snapshotCompleted else { return }
        work.snapshotCompleted = true
        validateDeadlines()
        guard !work.cancelled, state.pendingCapture == work.key, let data else {
            if !work.cancelled, state.pendingCapture == work.key { close(.webError) }
            retire(work); return
        }
        let preparation = prepareImage(data); work.preparation = preparation
        work.task = Task { [weak self, work] in
            let prepared = await preparation.value
            defer { work.preparation = nil; work.task = nil }
            guard let self else { return }
            defer { self.retire(work) }
            guard !work.cancelled, !Task.isCancelled else { return }
            self.validateDeadlines()
            guard !work.cancelled else { return }
            guard let prepared else { if self.state.pendingCapture == work.key { self.close(.webError) }; return }
            guard self.state.acceptCapture(work.key, now: self.now()) else { return }
            do { try await self.cache.store(prepared, key: work.key) }
            catch { if !work.cancelled, !Task.isCancelled { self.onCacheFailure?() } }
        }
    }
    private func retire(_ work: FieldCaptureWork) {
        guard captureWork === work else { return }
        work.preparation = nil; work.task = nil; captureWork = nil
        perform(state.capturePipelineRetired(work.key, now: now()))
    }
    private func scheduleDeadline() {
        timer?.invalidate(); timer = nil
        guard let deadline = state.nextDeadline else { return }
        let duration = now().duration(to: deadline).components
        let seconds = max(0, Double(duration.seconds) + Double(duration.attoseconds) / 1e18)
        let timer = Timer(timeInterval: seconds, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.validateDeadlines() }
        }
        RunLoop.main.add(timer, forMode: .common); self.timer = timer
    }
    deinit {
        timer?.invalidate()
        let work = captureWork, retiredTransport = transport?.value
        Task { @MainActor in work?.cancel(); retiredTransport?.invalidate() }
    }
}
