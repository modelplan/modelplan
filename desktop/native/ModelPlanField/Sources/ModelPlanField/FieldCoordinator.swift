// SPDX-License-Identifier: MIT
import Foundation

@MainActor public protocol FieldTransport: AnyObject {
    func start(generation: UUID, receive: @escaping (Data) -> Void, failed: @escaping (FieldReleaseReason) -> Void)
    func send(_ command: FieldCommand)
    func snapshot(completion: @escaping (Data?) -> Void)
    func invalidate()
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
    private var captureTask: Task<Void, Never>?
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
                    captureTask?.cancel(); captureTask = nil
                    transport?.value.invalidate(); transport = nil
                }
            case .snapshot(let key):
                guard transport?.generation == key.generation else { continue }
                transport?.value.snapshot { [weak self] data in
                    guard let self else { return }
                    self.validateDeadlines()
                    guard self.state.pendingCapture == key, self.state.generation == key.generation else { return }
                    guard let data else { self.close(.webError); return }
                    self.captureTask = Task { [weak self] in
                        let prepared = await Task.detached(priority: .utility) { try? FieldPNG.prepare(data) }.value
                        guard !Task.isCancelled, let self else { return }
                        self.validateDeadlines()
                        guard let prepared else { if self.state.pendingCapture == key { self.close(.webError) }; return }
                        guard self.state.acceptCapture(key, now: self.now()) else { return }
                        do { try await self.cache.store(prepared, key: key) } catch { if !Task.isCancelled { self.onCacheFailure?() } }
                        guard !Task.isCancelled else { return }
                        self.captureTask = nil; self.scheduleDeadline()
                    }
                }
            }
        }
        scheduleDeadline(); onChange?(state.phase)
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
    deinit { timer?.invalidate(); captureTask?.cancel() }
}
