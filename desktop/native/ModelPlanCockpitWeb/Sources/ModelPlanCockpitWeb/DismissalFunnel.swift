// SPDX-License-Identifier: MIT
import Foundation

/// Native-shell spec item 1: why a transient surface (the attached cockpit, the Help map, a first-use hint) was asked to
/// close. Every input path of a surface (its monitors, observers and delegate callbacks) only calls `request`.
public enum DismissReason: String, Sendable { case escape, outsidePress, appResigned, keyResigned }

/// What currently keeps a surface open. Behaviour from Maccy `FloatingPanel.resignKey` (no close while an alert or a
/// drag is up) and Stats `PopupWindow` (`locked` while the popup is being moved), own code.
public struct DismissalSuppression: OptionSet, Hashable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    /// A title drag, a widget carry, the snap guide.
    public static let drag = DismissalSuppression(rawValue: 1 << 0)
    /// An alert, an open/save panel or a sheet of ours.
    public static let modal = DismissalSuppression(rawValue: 1 << 1)
    /// One of our menus is being tracked (the status menu, the cockpit's context menu).
    public static let menuTracking = DismissalSuppression(rawValue: 1 << 2)
    /// The activation policy just flipped (Dock icon on/off), which posts resign/become active by itself.
    public static let policyChange = DismissalSuppression(rawValue: 1 << 3)
    /// The open is still entering: the click that opened it must not close it.
    public static let opening = DismissalSuppression(rawValue: 1 << 4)
    /// A panel the surface owns (Help overlay, hint, the enlarged field) is the target.
    public static let ownedChild = DismissalSuppression(rawValue: 1 << 5)
}

/// One suppression held by its owner until `release()`. Releasing twice is harmless.
@MainActor public final class DismissalHold {
    private var onRelease: (@MainActor () -> Void)?
    init(onRelease: @escaping @MainActor () -> Void) { self.onRelease = onRelease }
    public func release() { let action = onRelease; onRelease = nil; action?() }
    public var isReleased: Bool { onRelease == nil }
}

/// The one decision point for closing a transient surface. AppKit-free; the clock is injected.
///
/// Rules, in order: a request while not armed is ignored (one close per show; the second monitor firing for the same
/// click is a no-op); a request while any suppression is live is dropped, not deferred (Escape is dropped only for
/// `.modal` and `.menuTracking`); otherwise `close(reason)` runs once and the funnel disarms. `rearm()` and `disarm()`
/// clear every hold, so a leaked hold cannot keep a surface open past its next show.
@MainActor public final class DismissalFunnel {
    public enum Outcome: Equatable { case closed, suppressed(DismissalSuppression), ignored }
    private struct Entry { let suppression: DismissalSuppression; let expiresAt: UInt64? }
    private let now: @MainActor () -> UInt64
    private let close: @MainActor (DismissReason) -> Void
    /// Suppressions the owner reads live at request time (a drag in progress, `NSApp.modalWindow`, the entrance).
    private let live: @MainActor () -> DismissalSuppression
    private var holds: [UInt64: Entry] = [:]
    private var nextHold: UInt64 = 0
    private var closing = false
    public private(set) var isArmed = false

    /// `now` is milliseconds on any monotonic clock.
    public init(now: @escaping @MainActor () -> UInt64 = DismissalFunnel.uptimeMilliseconds,
                live: @escaping @MainActor () -> DismissalSuppression = { [] },
                close: @escaping @MainActor (DismissReason) -> Void) {
        self.now = now; self.live = live; self.close = close
    }
    public nonisolated static func uptimeMilliseconds() -> UInt64 { UInt64(ProcessInfo.processInfo.systemUptime * 1_000) }

    /// On show: armed, with no holds left from an earlier show.
    public func rearm() { holds.removeAll(); isArmed = true }
    /// On detach, close and teardown: later requests are ignored.
    public func disarm() { holds.removeAll(); isArmed = false }

    /// Suppressions live now: held, not expired, plus the owner's live ones.
    public var activeSuppression: DismissalSuppression {
        let time = now()
        holds = holds.filter { $0.value.expiresAt.map { time < $0 } ?? true }
        return holds.values.reduce(live()) { $0.union($1.suppression) }
    }

    @discardableResult
    public func request(_ reason: DismissReason) -> Outcome {
        guard isArmed, !closing else { return .ignored }
        let active = activeSuppression
        let blocking: DismissalSuppression = reason == .escape ? active.intersection([.modal, .menuTracking]) : active
        guard blocking.isEmpty else { return .suppressed(blocking) }
        isArmed = false; holds.removeAll()
        closing = true; defer { closing = false }
        close(reason)
        return .closed
    }

    /// Held until released (or the next rearm/disarm).
    public func hold(_ suppression: DismissalSuppression) -> DismissalHold {
        let id = add(suppression, expiresAt: nil)
        return DismissalHold { [weak self] in self?.holds[id] = nil }
    }
    /// Held for a fixed time on the injected clock, e.g. the 250 ms after an activation-policy flip.
    @discardableResult
    public func hold(_ suppression: DismissalSuppression, forMilliseconds duration: UInt64) -> DismissalHold {
        let id = add(suppression, expiresAt: now() &+ duration)
        return DismissalHold { [weak self] in self?.holds[id] = nil }
    }
    private func add(_ suppression: DismissalSuppression, expiresAt: UInt64?) -> UInt64 {
        nextHold &+= 1
        holds[nextHold] = Entry(suppression: suppression, expiresAt: expiresAt)
        return nextHold
    }
}
