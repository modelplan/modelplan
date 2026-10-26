// SPDX-License-Identifier: MIT
import Foundation

public enum FirstUseHintKind: String, Codable, CaseIterable, Sendable {
    // Declaration order is the fixed request priority, including the contextual tie order.
    case ignition, detach, optionHelp, shutter, field, drag, page, pinned, trial
}
public struct FirstUseHintPreferences: Codable, Equatable, Sendable {
    public private(set) var seen: Set<FirstUseHintKind>
    public private(set) var opens: Int
    public private(set) var reveals: Int
    public init(seen: Set<FirstUseHintKind> = [], opens: Int = 0, reveals: Int = 0) {
        self.seen = seen; self.opens = max(0,min(2,opens)); self.reveals = max(0,min(2,reveals))
    }
    private enum CodingKeys: CodingKey { case seen, opens, reveals, cockpitOpens }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(seen: c.contains(.seen) ? try c.decode(Set<FirstUseHintKind>.self, forKey: .seen) : [],
                  opens: c.contains(.opens) ? try c.decode(Int.self, forKey: .opens)
                    : c.contains(.cockpitOpens) ? try c.decode(Int.self, forKey: .cockpitOpens) : 0,
                  reveals: c.contains(.reveals) ? try c.decode(Int.self, forKey: .reveals) : 0)
        // The obsolete first-pin field is intentionally not decoded or re-encoded.
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(FirstUseHintKind.allCases.filter { seen.contains($0) }, forKey: .seen)
        try c.encode(opens, forKey: .opens); try c.encode(reveals, forKey: .reveals)
    }
    fileprivate mutating func opened() { opens = min(2,opens + 1) }
    fileprivate mutating func revealed() { reveals = min(2,reveals + 1) }
    fileprivate mutating func mark(_ kind: FirstUseHintKind) { seen.insert(kind) }
}
/// Opaque view identity of the travel, shared by its cap and track; never persisted.
public struct TrialHintTarget: Equatable, Hashable, Sendable {
    public let id: String
    public init(id: String) { self.id = id }
}
public struct TrialHintRest: Equatable, Sendable {
    public let id: UUID, target: TrialHintTarget, deadline: TimeInterval
}
public enum TrialHintCancellation: CaseIterable, Sendable {
    case pointerMovement, pointerLeave, pointerDown, keyInput, focusLoss, targetRemoval
}
public struct HintContext: Equatable, Sendable {
    public var cockpitOpen: UUID?, dockReveal: UUID?
    public var cardPinned = false, captureReady = false, helpMapVisible = false, reducedMotion = false
    public init(cockpitOpen: UUID? = nil, dockReveal: UUID? = nil) { self.cockpitOpen = cockpitOpen; self.dockReveal = dockReveal }
}
public struct HintOffer: Equatable, Sendable {
    public let id: UUID, kind: FirstUseHintKind
    public let trialTarget: TrialHintTarget?
    fileprivate let generation: UInt64
}
public struct HintPresentation: Equatable, Sendable {
    public let offer: HintOffer, expiresAt: TimeInterval
    public var reducedMotion: Bool
    public var fadeSeconds: Double { reducedMotion ? 0 : 0.18 }
}
/// Pure, timer-free arbitration. One app-wide instance/overlay; no cockpit/card mutation API exists.
public struct FirstUseHints: Sendable {
    public static let dwellSeconds = 0.5, visibleSeconds = 5.0
    public private(set) var preferences: FirstUseHintPreferences
    public private(set) var context = HintContext()
    public private(set) var visible: HintPresentation?
    public private(set) var offered: HintOffer?
    public private(set) var cockpitBudgetUsed = false, dockBudgetUsed = false
    private var generation: UInt64 = 0
    private var pending = Set<FirstUseHintKind>()
    private var dwell: [FirstUseHintKind: TimeInterval] = [:]
    private var dwellReady = Set<FirstUseHintKind>()
    private var lastTime: TimeInterval?
    public private(set) var trialRest: TrialHintRest?
    private var trialReady = false
    public var nextDeadline: TimeInterval? {
        (Array(dwell.values) + (trialReady ? [] : trialRest.map { [$0.deadline] } ?? []) + (visible.map { [$0.expiresAt] } ?? [])).min()
    }
    public init(preferences: FirstUseHintPreferences = .init()) { self.preferences = preferences }
    public mutating func updateContext(_ next: HintContext, at now: TimeInterval) throws {
        try tick(now)
        if next.cockpitOpen != context.cockpitOpen || next.dockReveal != context.dockReveal {
            visible = nil; offered = nil; pending = []; dwell = [:]; dwellReady = []; trialRest = nil; trialReady = false; generation &+= 1
        }
        if next.cockpitOpen != context.cockpitOpen {
            cockpitBudgetUsed = false
            if next.cockpitOpen != nil { preferences.opened() }
        }
        if next.dockReveal != context.dockReveal {
            dockBudgetUsed = false
            if next.dockReveal != nil { preferences.revealed() }
        }
        context = next
        if !contextSupports(.trial) { cancelTrialRest(reason: .targetRemoval) }
        // Identity can stay stable while a card/anchor or guarded capture condition disappears.
        // An unshown offer spends nothing; a shown hint retains its real ledger/budget spend.
        if let offer = offered, !allowed(offer.kind) { offered = nil }
        if let presentation = visible, !contextSupports(presentation.offer.kind) { visible = nil }
        if context.helpMapVisible { dismiss() }
        if visible != nil { visible!.reducedMotion = context.reducedMotion }
        offerContextualTriggers()
    }
    public mutating func request(_ kind: FirstUseHintKind) {
        guard kind != .trial, visible == nil, !preferences.seen.contains(kind),
              ![.ignition,.field,.drag].contains(kind) || dwellReady.contains(kind) else { return }
        pending.insert(kind)
    }
    public mutating func beginDwell(_ kind: FirstUseHintKind, at now: TimeInterval) throws {
        try tick(now)
        guard [.ignition,.field,.drag].contains(kind), !preferences.seen.contains(kind),
              kind == .field ? context.cockpitOpen != nil : context.dockReveal != nil,
              kind != .drag || reservedDockHint == .drag else { return }
        if dwell[kind] == nil { dwell[kind] = now + Self.dwellSeconds }
    }
    public mutating func cancelDwell(_ kind: FirstUseHintKind) {
        dwell.removeValue(forKey: kind); dwellReady.remove(kind); pending.remove(kind)
        if offered?.kind == kind { offered = nil }
    }
    /// One app-wide rest token. Repeated entry on the same stationary travel does not restart it.
    public mutating func beginTrialRest(on target: TrialHintTarget, at now: TimeInterval) throws -> TrialHintRest? {
        guard !target.id.isEmpty, target.id.utf8.count <= 256 else { throw SettingsError.invalidPreference }
        try tick(now)
        guard contextSupports(.trial), !preferences.seen.contains(.trial), !cockpitBudgetUsed, visible == nil else { return nil }
        if let trialRest, trialRest.target == target { return trialRest }
        cancelTrialRest(reason: .pointerMovement)
        let deadline = now + Self.dwellSeconds
        guard deadline.isFinite, deadline > now else { throw SettingsError.invalidTime }
        let rest = TrialHintRest(id: UUID(), target: target, deadline: deadline)
        trialRest = rest; return rest
    }
    /// The optional token prevents a removed/replaced view's late callback from cancelling a new rest.
    @discardableResult public mutating func cancelTrialRest(_ rest: TrialHintRest? = nil, reason: TrialHintCancellation) -> Bool {
        if let rest, rest != trialRest { return false }
        let hadRest = trialRest != nil
        trialRest = nil; trialReady = false; pending.remove(.trial)
        if offered?.kind == .trial { offered = nil }
        return hadRest
    }
    /// Timer callbacks return through the same priority/placement arbiter, never a per-fader queue.
    public mutating func offerTrialRest(_ rest: TrialHintRest, placeable: Set<FirstUseHintKind>, at now: TimeInterval) throws -> HintOffer? {
        guard trialRest == rest else { return nil }
        try tick(now)
        guard trialRest == rest, trialReady else { return nil }
        return try nextOffer(placeable: placeable, at: now)
    }
    /// Same reveal dwell for the reserved ignition/drag hint; the host owns scheduling.
    public mutating func beginDockRevealDwell(at now: TimeInterval) throws {
        try tick(now)
        if let kind = reservedDockHint { try beginDwell(kind, at: now) }
    }
    public var reservedDockHint: FirstUseHintKind? {
        guard context.dockReveal != nil else { return nil }
        if !preferences.seen.contains(.ignition) { return .ignition }
        return preferences.reveals >= 2 && !preferences.seen.contains(.drag) ? .drag : nil
    }
    public mutating func advance(at now: TimeInterval) throws { try tick(now) }
    /// Placement is supplied by the native adapter; an offer itself spends no flag or budget.
    public mutating func nextOffer(placeable: Set<FirstUseHintKind>, at now: TimeInterval) throws -> HintOffer? {
        try tick(now); offerContextualTriggers()
        guard visible == nil, offered == nil else { return nil }
        guard let kind = FirstUseHintKind.allCases.first(where: { pending.contains($0) && placeable.contains($0) && allowed($0) }) else { return nil }
        let offer = HintOffer(id: UUID(), kind: kind, trialTarget: kind == .trial ? trialRest?.target : nil, generation: generation); offered = offer; return offer
    }
    public mutating func reject(_ offer: HintOffer) { if offered == offer { offered = nil } }
    public mutating func confirmShown(_ offer: HintOffer, at now: TimeInterval) throws {
        try tick(now)
        guard offered == offer, offer.generation == generation, allowed(offer.kind), visible == nil else { throw SettingsError.staleRevision }
        preferences.mark(offer.kind)
        if usesDock(offer.kind) { dockBudgetUsed = true }
        if context.cockpitOpen != nil { cockpitBudgetUsed = true }
        offered = nil; pending = []; trialRest = nil; trialReady = false
        visible = .init(offer: offer, expiresAt: now + Self.visibleSeconds, reducedMotion: context.reducedMotion)
    }
    /// Also used by Don't show again/Esc/click. Only this overlay is dismissed.
    public mutating func dismiss() { visible = nil; offered = nil; pending = []; dwell = [:]; dwellReady = []; trialRest = nil; trialReady = false }
    public mutating func reset() {
        dismiss(); preferences = .init(); cockpitBudgetUsed = false; dockBudgetUsed = false; generation &+= 1
        // Keep the current host context; reset does not close/reopen a window or manufacture an open.
    }
    private func usesDock(_ kind: FirstUseHintKind) -> Bool {
        kind == .ignition || kind == .drag || (kind == .pinned && context.cockpitOpen == nil)
    }
    private func contextSupports(_ kind: FirstUseHintKind) -> Bool {
        guard !context.helpMapVisible else { return false }
        if usesDock(kind) { guard context.dockReveal != nil else { return false } }
        else { guard context.cockpitOpen != nil else { return false } }
        // Exact frozen guarded list: pinned/drag deliberately do not gain a capture barrier.
        if [.detach,.optionHelp,.shutter,.field,.page,.trial].contains(kind), !context.captureReady { return false }
        if kind == .shutter && preferences.opens < 2 { return false }
        if kind == .drag && (preferences.reveals < 2 || !preferences.seen.contains(.ignition)) { return false }
        if kind == .pinned && (!context.cardPinned || (usesDock(kind) && reservedDockHint != nil)) { return false }
        return true
    }
    private func allowed(_ kind: FirstUseHintKind) -> Bool {
        guard contextSupports(kind), !preferences.seen.contains(kind),
              context.cockpitOpen == nil || !cockpitBudgetUsed else { return false }
        if usesDock(kind) && dockBudgetUsed { return false }
        if [.ignition,.field,.drag].contains(kind) && !dwellReady.contains(kind) { return false }
        if kind == .trial && (!trialReady || trialRest == nil) { return false }
        return true
    }
    private mutating func offerContextualTriggers() {
        if context.cockpitOpen != nil {
            request(.detach); request(.optionHelp)
            if preferences.opens >= 2 { request(.shutter) }
        }
        if context.cardPinned { request(.pinned) }
    }
    private mutating func tick(_ now: TimeInterval) throws {
        guard now.isFinite, now >= 0, lastTime.map({ now >= $0 }) ?? true else { throw SettingsError.invalidTime }
        lastTime = now
        if let visible, now >= visible.expiresAt { dismiss() }
        let ready = dwell.filter { now >= $0.value }.map(\.key)
        for kind in ready { dwell.removeValue(forKey: kind); dwellReady.insert(kind); request(kind) }
        if let trialRest, now >= trialRest.deadline, contextSupports(.trial), !preferences.seen.contains(.trial), visible == nil {
            trialReady = true; pending.insert(.trial)
        }
    }
}
