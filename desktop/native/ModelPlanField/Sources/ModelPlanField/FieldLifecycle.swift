// SPDX-License-Identifier: MIT
import Foundation

public enum FieldPhase: Equatable, Sendable { case still, loading, live, failed }
public enum FieldPauseReason: Hashable, Sendable { case locked, sleep, sessionInactive, noDisplay, termination }
public enum FieldVisibility: Sendable { case visible, occluded, orderedOut, collapsed, offSpace }
public enum FieldReleaseReason: String, Sendable {
    case close, orderedOut, collapsed, offSpace, locked, sleep, sessionInactive, screenRemoved, memoryPressure, termination
    case readyTimeout, settledTimeout, captureTimeout, idle, occluded, navigation, webProcessTerminated, webError, cacheClear
}
public enum FieldEffect: Equatable, Sendable {
    case mount(UUID), send(FieldCommand), snapshot(FieldCaptureKey), release(UUID)
}

/// Single-instance reducer. All elapsed deadlines are revalidated on input, never trusted to callbacks.
/// Only explicit enlarge/retry mounts; appearance, publication, focus and uncover never remount.
public struct FieldLifecycle: Sendable {
    private struct ConfigurationRequest: Sendable {
        let id: UUID, configuration: FieldConfiguration, paused: Bool
        let deadline: ContinuousClock.Instant
    }
    private struct CaptureRequest: Sendable {
        let key: FieldCaptureKey, deadline: ContinuousClock.Instant
        var snapshotStarted = false
    }
    public private(set) var phase: FieldPhase = .still
    public private(set) var generation: UUID?
    public private(set) var configuration: FieldConfiguration
    public private(set) var lastRelease: FieldReleaseReason?
    public private(set) var visibility: FieldVisibility = .visible
    public private(set) var disposalAcknowledged = false
    private var readyDeadline: ContinuousClock.Instant?
    private var watchdog: ContinuousClock.Instant?
    private var occlusionDeadline: ContinuousClock.Instant?
    private var request: ConfigurationRequest?
    private var capture: CaptureRequest?
    private var applied: ConfigurationRequest?
    private var retired: (generation: UUID, requestId: UUID, deadline: ContinuousClock.Instant)?
    private var ready = false
    private var blockers: Set<FieldPauseReason> = []

    public init(configuration: FieldConfiguration) { self.configuration = configuration }
    public var nextDeadline: ContinuousClock.Instant? {
        [readyDeadline, watchdog, occlusionDeadline, request?.deadline, capture?.deadline, retired?.deadline].compactMap { $0 }.min()
    }
    public var pendingCapture: FieldCaptureKey? { capture?.key }

    public mutating func enlarge(now: ContinuousClock.Instant = .now) -> [FieldEffect] {
        var effects = advance(now: now)
        guard generation == nil, visibility == .visible, blockers.isEmpty else { return effects }
        let id = UUID(); generation = id; phase = .loading; ready = false; lastRelease = nil
        readyDeadline = now.advanced(by: .seconds(10)); watchdog = now.advanced(by: .seconds(180))
        effects.append(.mount(id)); return effects
    }
    public mutating func update(_ next: FieldConfiguration, now: ContinuousClock.Instant = .now) -> [FieldEffect] {
        var effects = advance(now: now)
        if next != configuration { configuration = next; capture = nil }
        effects += configureIfNeeded(now: now); return effects
    }
    public mutating func setVisibility(_ next: FieldVisibility, now: ContinuousClock.Instant = .now) -> [FieldEffect] {
        var effects = advance(now: now); visibility = next
        switch next {
        case .visible:
            occlusionDeadline = nil; effects += configureIfNeeded(now: now)
        case .occluded:
            capture = nil
            if generation != nil, occlusionDeadline == nil { occlusionDeadline = now.advanced(by: .seconds(5)) }
            effects += configureIfNeeded(now: now)
        case .orderedOut: effects += release(.orderedOut, now: now)
        case .collapsed: effects += release(.collapsed, now: now)
        case .offSpace: effects += release(.offSpace, now: now)
        }
        return effects
    }
    public mutating func setBlocked(_ reason: FieldPauseReason, blocked: Bool, now: ContinuousClock.Instant = .now) -> [FieldEffect] {
        if blocked {
            blockers.insert(reason)
            let releaseReason: FieldReleaseReason
            switch reason {
            case .locked: releaseReason = .locked
            case .sleep: releaseReason = .sleep
            case .sessionInactive: releaseReason = .sessionInactive
            case .noDisplay: releaseReason = .screenRemoved
            case .termination: releaseReason = .termination
            }
            return release(releaseReason, now: now)
        }
        blockers.remove(reason)
        return advance(now: now) // Removing a blocker never remounts or removes another blocker.
    }
    public mutating func close(_ reason: FieldReleaseReason = .close, now: ContinuousClock.Instant = .now) -> [FieldEffect] {
        release(reason, now: now)
    }
    public mutating func receive(_ message: FieldWebMessage, now: ContinuousClock.Instant = .now) -> [FieldEffect] {
        var effects = advance(now: now)
        if let retired, message.type == .disposed, message.generation == retired.generation,
           message.requestId == retired.requestId, now <= retired.deadline {
            disposalAcknowledged = true; self.retired = nil; return effects
        }
        guard let generation, message.generation == generation, message.version == 1 else { return effects }
        switch message.type {
        case .ready:
            guard !ready else { return effects }
            ready = true; readyDeadline = nil; effects += configureIfNeeded(now: now)
        case .settled:
            guard let request, request.id == message.requestId else { return effects }
            applied = request; self.request = nil; phase = .live
            effects += configureIfNeeded(now: now)
            if self.request == nil { effects += requestCapture(now: now) }
        case .interaction:
            guard visibility == .visible, message.interaction != nil else { return effects }
            watchdog = now.advanced(by: .seconds(180))
        case .captureResult:
            guard var capture, !capture.snapshotStarted, message.requestId == capture.key.requestId,
                  message.captureKey == capture.key, captureIsCurrent(capture.key) else { return effects }
            capture.snapshotStarted = true; self.capture = capture; effects.append(.snapshot(capture.key))
        case .error: effects += release(.webError, now: now)
        case .disposed: break
        }
        return effects
    }
    /// Accept only after bounded image preparation, before authorizing atomic cache persistence.
    public mutating func acceptCapture(_ key: FieldCaptureKey, now: ContinuousClock.Instant = .now) -> Bool {
        guard let capture, capture.snapshotStarted, now < capture.deadline, captureIsCurrent(key) else { return false }
        self.capture = nil; return true
    }
    public mutating func advance(now: ContinuousClock.Instant = .now) -> [FieldEffect] {
        if let retired, now >= retired.deadline { self.retired = nil }
        guard generation != nil else { return [] }
        let due: [(ContinuousClock.Instant?, FieldReleaseReason)] = [
            (occlusionDeadline, .occluded), (readyDeadline, .readyTimeout), (request?.deadline, .settledTimeout),
            (capture?.deadline, .captureTimeout), (watchdog, .idle)
        ]
        if let first = due.compactMap({ deadline, reason in deadline.map { ($0, reason) } })
            .filter({ now >= $0.0 }).min(by: { $0.0 < $1.0 }) { return release(first.1, now: now) }
        return []
    }
    private func captureIsCurrent(_ key: FieldCaptureKey) -> Bool {
        guard let capture, let applied else { return false }
        return capture.key == key && generation == key.generation && visibility == .visible &&
            request == nil && applied.configuration == configuration && !applied.paused &&
            key.configurationId == applied.id
    }
    private mutating func requestCapture(now: ContinuousClock.Instant) -> [FieldEffect] {
        guard capture == nil, let generation, let applied, request == nil,
              visibility == .visible, !applied.paused, applied.configuration == configuration else { return [] }
        let key = FieldCaptureKey(generation: generation, requestId: UUID(), configurationId: applied.id,
            appearance: configuration.appearance, viewport: configuration.viewport, projectionRevision: configuration.projection.revision)
        capture = CaptureRequest(key: key, deadline: now.advanced(by: .seconds(2)))
        return [.send(FieldCommand(generation: generation, requestId: key.requestId, type: .capture, captureKey: key))]
    }
    private mutating func configureIfNeeded(now: ContinuousClock.Instant) -> [FieldEffect] {
        guard let generation, ready, request == nil else { return [] }
        let paused = visibility == .occluded
        guard applied?.configuration != configuration || applied?.paused != paused else { return [] }
        let kind: FieldCommandKind
        if let applied {
            let projectionChanged = applied.configuration.projection != configuration.projection
            let appearanceChanged = applied.configuration.appearance != configuration.appearance ||
                applied.configuration.viewport != configuration.viewport || applied.paused != paused
            kind = projectionChanged && appearanceChanged ? .configure : projectionChanged ? .setPublicProjection : .setAppearance
        } else { kind = .configure }
        let id = UUID(); capture = nil
        request = ConfigurationRequest(id: id, configuration: configuration, paused: paused, deadline: now.advanced(by: .seconds(5)))
        return [.send(FieldCommand(generation: generation, requestId: id, type: kind, configuration: configuration, paused: paused))]
    }
    private mutating func release(_ reason: FieldReleaseReason, now: ContinuousClock.Instant) -> [FieldEffect] {
        guard let generation else { return [] }
        let command = FieldCommand(generation: generation, type: .dispose)
        retired = (generation, command.requestId, now.advanced(by: .milliseconds(250))); disposalAcknowledged = false
        self.generation = nil; ready = false; readyDeadline = nil; watchdog = nil
        occlusionDeadline = nil; request = nil; capture = nil; applied = nil; lastRelease = reason
        phase = [.readyTimeout, .settledTimeout, .captureTimeout, .navigation, .webProcessTerminated, .webError].contains(reason) ? .failed : .still
        return [.send(command), .release(generation)]
    }
}
