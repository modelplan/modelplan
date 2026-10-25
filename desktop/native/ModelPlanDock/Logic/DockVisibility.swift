// SPDX-License-Identifier: MIT
import Foundation
import CoreGraphics

/// Durations are elapsed seconds; the adapter supplies a sleep-aware monotonic clock.
public struct DockVisibilityPolicy: Equatable, Sendable {
    public var revealDwell: TimeInterval = 0.150
    public var leaveGrace: TimeInterval = 0.500
    public var staleLockRecovery: TimeInterval = 2.000
    public var arrivalGuard: TimeInterval = 0.300
    public var sampleInterval: TimeInterval = 0.150
    public var insideSlack: CGFloat = 12
    public var wakeDepth: CGFloat = 16
    public init() {}
    fileprivate var valid: Bool {
        [revealDwell, leaveGrace, staleLockRecovery, arrivalGuard, sampleInterval].allSatisfy { $0.isFinite && $0 >= 0 }
            && staleLockRecovery >= leaveGrace && insideSlack.isFinite && insideSlack >= 0 && wakeDepth.isFinite && wakeDepth >= 0
    }
}
public struct DockRecordedLocks: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let drag = Self(rawValue: 1), menu = Self(rawValue: 2), keyboard = Self(rawValue: 4)
}
public enum DockPointerRegion: Equatable, Sendable { case unknown, outside, inside, wake }
public struct DockPresence: Sendable {
    public var enabled = true, autoHide = true, cockpitClosed = true, allowedOverFullscreen = true, outerEdge = true
    public var pointer: DockPointerRegion = .unknown
    public var recordedLocks: DockRecordedLocks = []
    public var mouseButtonDown = false, menuActuallyOpen = false, ignitionHeld = false, cardPinned = false
    public init() {}
    fileprivate var protected: Bool { mouseButtonDown || menuActuallyOpen || ignitionHeld || cardPinned }
}
public enum DockSurfaceState: Equatable, Sendable {
    public enum Suppression: Equatable, Sendable { case userHidden, cockpit, fullscreen, sharedEdge }
    case suppressed(Suppression), sliver, expanded
}
public enum DockVisibilityIntent: Equatable, Sendable { case sample, reveal, lifecycleCancel }
public struct DockVisibilityChange: Sendable {
    public let state: DockSurfaceState
    public let didReveal: Bool, didCollapse: Bool, forcedHide: Bool
    public let clearRecordedLocks: DockRecordedLocks
    public let nextDeadline: TimeInterval?
    public let generation: UInt
}

/// Returns deadlines/effects, owns no timer, pointer monitor, window or process.
public struct DockVisibilityState: Sendable {
    public private(set) var surface: DockSurfaceState = .sliver
    public private(set) var generation: UInt = 0
    private var outsideSince: TimeInterval?, dwellSince: TimeInterval?, revealedAt: TimeInterval?, lastTime: TimeInterval?
    public let policy: DockVisibilityPolicy
    public init(policy: DockVisibilityPolicy = .init()) { self.policy = policy }
    public func acceptsPress(at now: TimeInterval, keyboardOrAccessibility: Bool = false) -> Bool {
        guard surface == .expanded, now.isFinite, lastTime.map({now >= $0}) ?? true else { return false }
        return keyboardOrAccessibility || (revealedAt.map { now >= $0 + policy.arrivalGuard } ?? true)
    }
    public mutating func step(_ input: DockPresence, at now: TimeInterval, intent: DockVisibilityIntent = .sample, expectedGeneration: UInt? = nil) throws -> DockVisibilityChange {
        if let expectedGeneration, expectedGeneration != generation { throw DockLogicError.staleGeneration }
        guard policy.valid, now.isFinite, lastTime.map({now >= $0}) ?? true else { throw DockLogicError.invalidTime }
        lastTime = now
        let previous = surface
        var deadline: TimeInterval?, forced = false
        var clear: DockRecordedLocks = []
        func suppression() -> DockSurfaceState.Suppression? {
            if !input.enabled { return .userHidden }; if !input.cockpitClosed { return .cockpit }
            if !input.allowedOverFullscreen { return .fullscreen }; if !input.outerEdge { return .sharedEdge }; return nil
        }
        if intent == .lifecycleCancel {
            generation &+= 1
            if let reason = suppression() { surface = .suppressed(reason) }
            else { surface = input.autoHide ? .sliver : .expanded }
            outsideSince = nil; dwellSince = nil; revealedAt = nil; clear = input.recordedLocks
        } else if let reason = suppression() {
            surface = .suppressed(reason); outsideSince = nil; dwellSince = nil; revealedAt = nil
            if previous != surface { generation &+= 1 }; clear = input.recordedLocks
        } else if !input.autoHide || intent == .reveal {
            surface = .expanded; outsideSince = nil; dwellSince = nil
            if previous != .expanded { revealedAt = now }
        } else {
            if case .suppressed = surface { surface = .sliver }
            if surface == .sliver {
                outsideSince = nil
                if input.pointer == .wake {
                    if dwellSince == nil { dwellSince = now }
                    if now >= dwellSince! + policy.revealDwell { surface = .expanded; revealedAt = now; dwellSince = nil }
                    else { deadline = dwellSince! + policy.revealDwell }
                } else { dwellSince = nil }
            } else if input.pointer == .inside || input.pointer == .wake || input.pointer == .unknown {
                outsideSince = nil; dwellSince = nil
            } else {
                if outsideSince == nil { outsideSince = now }
                if !input.protected {
                    let duration = input.recordedLocks.isEmpty ? policy.leaveGrace : policy.staleLockRecovery
                    let due = outsideSince! + duration
                    if now >= due {
                        forced = !input.recordedLocks.isEmpty; clear = input.recordedLocks
                        surface = .sliver; outsideSince = nil; dwellSince = nil
                    } else { deadline = due }
                }
            }
        }
        return DockVisibilityChange(state: surface, didReveal: previous != .expanded && surface == .expanded,
                                    didCollapse: previous == .expanded && surface != .expanded, forcedHide: forced,
                                    clearRecordedLocks: clear, nextDeadline: deadline, generation: generation)
    }
}

public enum DockEdge: CaseIterable, Sendable { case left, right, top, bottom }
/// Hover-retention geometry only, supplied by the eventual view.
/// Slack/corridor rectangles MUST NOT be reused as native click-catching regions (B05b proves those separately).
public struct DockPresenceArea: Sendable {
    public var painted: [CGRect], wake: CGRect, card: CGRect?, display: CGRect, edge: DockEdge, outerEdge: Bool
    public init(painted: [CGRect], wake: CGRect, card: CGRect?, display: CGRect, edge: DockEdge, outerEdge: Bool = true) {
        self.painted = painted; self.wake = wake; self.card = card; self.display = display; self.edge = edge; self.outerEdge = outerEdge
    }
    private func contains(_ rect: CGRect, _ point: CGPoint) -> Bool {
        !rect.isNull && !rect.isEmpty && point.x >= rect.minX && point.x <= rect.maxX && point.y >= rect.minY && point.y <= rect.maxY
    }
    public func region(at point: CGPoint, policy: DockVisibilityPolicy = .init()) -> DockPointerRegion {
        guard policy.valid, point.x.isFinite, point.y.isFinite else { return .unknown }
        if outerEdge && contains(wake, point) { return .wake }
        let slack = policy.insideSlack
        if painted.contains(where: { contains($0.insetBy(dx: -slack, dy: -slack), point) }) { return .inside }
        if let card, !card.isNull, !card.isEmpty {
            var corridor = card.insetBy(dx: -slack, dy: -slack)
            switch edge {
            case .left: corridor = CGRect(x: display.minX-slack, y: corridor.minY, width: max(0,corridor.maxX-display.minX+slack), height: corridor.height)
            case .right: corridor = CGRect(x: corridor.minX, y: corridor.minY, width: max(0,display.maxX+slack-corridor.minX), height: corridor.height)
            case .bottom: corridor = CGRect(x: corridor.minX, y: display.minY-slack, width: corridor.width, height: max(0,corridor.maxY-display.minY+slack))
            case .top: corridor = CGRect(x: corridor.minX, y: corridor.minY, width: corridor.width, height: max(0,display.maxY+slack-corridor.minY))
            }
            if contains(corridor, point) { return .inside }
        }
        return .outside
    }
}
