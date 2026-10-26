// SPDX-License-Identifier: MIT
import Foundation

public enum FirstUseHintKind: String, Codable, CaseIterable, Sendable {
    // Declaration order is the fixed request priority, including the contextual tie order.
    case ignition, optionHelp, shutter, field, drag, page, pinned, trial
}
public struct FirstUseHintPreferences: Codable, Equatable, Sendable {
    public private(set) var seen: Set<FirstUseHintKind>
    public private(set) var cockpitOpens: Int
    public private(set) var hasPinned: Bool
    public init(seen: Set<FirstUseHintKind> = [], cockpitOpens: Int = 0, hasPinned: Bool = false) {
        self.seen = seen; self.cockpitOpens = max(0,min(2,cockpitOpens)); self.hasPinned = hasPinned
    }
    private enum CodingKeys: CodingKey { case seen, cockpitOpens, hasPinned }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(seen: c.contains(.seen) ? try c.decode(Set<FirstUseHintKind>.self, forKey: .seen) : [],
                  cockpitOpens: c.contains(.cockpitOpens) ? try c.decode(Int.self, forKey: .cockpitOpens) : 0,
                  hasPinned: c.contains(.hasPinned) ? try c.decode(Bool.self, forKey: .hasPinned) : false)
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(FirstUseHintKind.allCases.filter { seen.contains($0) }, forKey: .seen)
        try c.encode(cockpitOpens, forKey: .cockpitOpens); try c.encode(hasPinned, forKey: .hasPinned)
    }
    fileprivate mutating func opened() { cockpitOpens = min(2,cockpitOpens + 1) }
    fileprivate mutating func pinned() { hasPinned = true }
    fileprivate mutating func mark(_ kind: FirstUseHintKind) { seen.insert(kind) }
}
public struct HintContext: Equatable, Sendable {
    public var cockpitOpen: UUID?, dockReveal: UUID?
    public var cardPinned = false, captureReady = false, helpMapVisible = false, reducedMotion = false
    public init(cockpitOpen: UUID? = nil, dockReveal: UUID? = nil) { self.cockpitOpen = cockpitOpen; self.dockReveal = dockReveal }
}
public struct HintOffer: Equatable, Sendable {
    public let id: UUID, kind: FirstUseHintKind
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
    public init(preferences: FirstUseHintPreferences = .init()) { self.preferences = preferences }
    public mutating func updateContext(_ next: HintContext, at now: TimeInterval) throws {
        try tick(now)
        if next.cockpitOpen != context.cockpitOpen || next.dockReveal != context.dockReveal {
            visible = nil; offered = nil; pending = []; dwell = [:]; dwellReady = []; generation &+= 1
        }
        if next.cockpitOpen != context.cockpitOpen {
            cockpitBudgetUsed = false
            if next.cockpitOpen != nil { preferences.opened() }
        }
        if next.dockReveal != context.dockReveal { dockBudgetUsed = false }
        if next.cardPinned && !context.cardPinned { preferences.pinned() }
        context = next
        // Identity can stay stable while a card/anchor or guarded capture condition disappears.
        // An unshown offer spends nothing; a shown hint retains its real ledger/budget spend.
        if let offer = offered, !allowed(offer.kind) { offered = nil }
        if let presentation = visible, !contextSupports(presentation.offer.kind) { visible = nil }
        if context.helpMapVisible { dismiss() }
        if visible != nil { visible!.reducedMotion = context.reducedMotion }
        offerContextualTriggers()
    }
    public mutating func request(_ kind: FirstUseHintKind) {
        guard visible == nil, !preferences.seen.contains(kind),
              ![.ignition,.field].contains(kind) || dwellReady.contains(kind) else { return }
        pending.insert(kind)
    }
    public mutating func beginDwell(_ kind: FirstUseHintKind, at now: TimeInterval) throws {
        try tick(now)
        guard [.ignition,.field].contains(kind), !preferences.seen.contains(kind),
              kind == .field ? context.cockpitOpen != nil : context.dockReveal != nil else { return }
        if dwell[kind] == nil { dwell[kind] = now + Self.dwellSeconds }
    }
    public mutating func cancelDwell(_ kind: FirstUseHintKind) {
        dwell.removeValue(forKey: kind); dwellReady.remove(kind); pending.remove(kind)
        if offered?.kind == kind { offered = nil }
    }
    public mutating func advance(at now: TimeInterval) throws { try tick(now) }
    /// Placement is supplied by the native adapter; an offer itself spends no flag or budget.
    public mutating func nextOffer(placeable: Set<FirstUseHintKind>, at now: TimeInterval) throws -> HintOffer? {
        try tick(now); offerContextualTriggers()
        guard visible == nil, offered == nil else { return nil }
        guard let kind = FirstUseHintKind.allCases.first(where: { pending.contains($0) && placeable.contains($0) && allowed($0) }) else { return nil }
        let offer = HintOffer(id: UUID(), kind: kind, generation: generation); offered = offer; return offer
    }
    public mutating func reject(_ offer: HintOffer) { if offered == offer { offered = nil } }
    public mutating func confirmShown(_ offer: HintOffer, at now: TimeInterval) throws {
        try tick(now)
        guard offered == offer, offer.generation == generation, allowed(offer.kind), visible == nil else { throw SettingsError.staleRevision }
        preferences.mark(offer.kind)
        if usesDock(offer.kind) { dockBudgetUsed = true }
        if context.cockpitOpen != nil { cockpitBudgetUsed = true }
        offered = nil; pending = []
        visible = .init(offer: offer, expiresAt: now + Self.visibleSeconds, reducedMotion: context.reducedMotion)
    }
    /// Also used by Don't show again/Esc/click. Only this overlay is dismissed.
    public mutating func dismiss() { visible = nil; offered = nil; pending = []; dwell = [:]; dwellReady = [] }
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
        if [.optionHelp,.shutter,.field,.page,.trial].contains(kind), !context.captureReady { return false }
        if kind == .shutter && preferences.cockpitOpens < 2 { return false }
        if kind == .drag && !preferences.hasPinned { return false }
        if kind == .pinned && !context.cardPinned { return false }
        return true
    }
    private func allowed(_ kind: FirstUseHintKind) -> Bool {
        guard contextSupports(kind), !preferences.seen.contains(kind),
              context.cockpitOpen == nil || !cockpitBudgetUsed else { return false }
        if usesDock(kind) && dockBudgetUsed { return false }
        if [.ignition,.field].contains(kind) && !dwellReady.contains(kind) { return false }
        return true
    }
    private mutating func offerContextualTriggers() {
        if context.cockpitOpen != nil {
            request(.optionHelp)
            if preferences.cockpitOpens >= 2 { request(.shutter) }
        }
        if context.cardPinned { request(.drag); request(.pinned) }
    }
    private mutating func tick(_ now: TimeInterval) throws {
        guard now.isFinite, now >= 0, lastTime.map({ now >= $0 }) ?? true else { throw SettingsError.invalidTime }
        lastTime = now
        if let visible, now >= visible.expiresAt { dismiss() }
        let ready = dwell.filter { now >= $0.value }.map(\.key)
        for kind in ready { dwell.removeValue(forKey: kind); dwellReady.insert(kind); request(kind) }
    }
}
