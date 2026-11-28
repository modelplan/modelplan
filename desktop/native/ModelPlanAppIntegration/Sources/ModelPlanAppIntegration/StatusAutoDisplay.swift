// SPDX-License-Identifier: MIT
import AppKit
import Foundation

/// D377 option C (owner 2026-11-21), amended by D476 (owner 2026-11-27): the automatic menu-bar display. The item is the
/// icon alone by default; a compact number appears while the tracked quota is red (below the alert line) or amber (its
/// estimate runs out before the reset); a used-up quota shows the icon with a red dot; a crowded menu bar where the item
/// risks being hidden (squeezed: its window off screen or covered, the D378 detection) shows no number at all, red
/// included, so the icon stays as narrow as it can.
///
/// Reference: Pulse and CodexBar status items (icon-only by default, a number only by choice; CodexBar's compact
/// spacing). Behaviour is our own code; macOS has no "hidden behind the notch" query, so "squeezed" is the existing
/// status-item window check (`EngineDockMenuApplication.checkStatusItemVisibility`): the window is not visible, is
/// occluded, or is off every screen. When nothing can be detected the item stays icon-only by default (it never
/// widens without a quota below the line).
enum StatusAutoMode: Equatable {
    case iconOnly
    /// A compact number (for example "15%"); `StatusAutoDisplay.compactLength` wide.
    case number(String)
    /// The quota is used up: the icon with a red dot, no text.
    case usedUp
}

/// What the admitted projection says about the tracked (tightest) quota. `remaining` is always the remaining truth
/// (0...100); `shown` is the text for the user's percentage mode ("15%", or "85%" when percentages show used).
struct StatusAutoReading: Equatable {
    var name: String
    var remaining: Double
    var shown: String
    var alertLine: Double
    /// D476 (supersedes D377 on amber): the tracked quota is amber, its estimate runs out before the reset (the same
    /// run-out the ring uses, `DockQuotaWindowInput.runOutAt`). A reserve item never sets it (master spec §4.1).
    var amber = false
}

enum StatusAutoInput: Equatable {
    case reading(StatusAutoReading)
    /// No tracked quota (no rows, a privacy clear): icon only.
    case none
    /// A gap between two admitted states: the last reading is kept (up to `StatusTitleKeeper.holdLimit`).
    case unavailable
}

struct StatusAutoDisplay {
    /// The compact item width in points (icon, a 3 pt gap and up to three characters in monospaced digits).
    static let compactLength: CGFloat = 42
    /// A number goes away only when the remaining quota is this far above the alert line (no flicker at the line).
    static let hysteresis: Double = 5
    /// A squeeze must last this long before the item falls back to the icon.
    static let squeezeDebounce: TimeInterval = 0.75
    /// After a fall-back the wide form is tried again only on a display change or after this long.
    static let retryWide: TimeInterval = 600
    /// At most one squeeze-driven switch in this time.
    static let minimumSwitchInterval: TimeInterval = 60

    private var numberShown = false
    /// The red latch alone (amber never sets it).
    private var redShown = false
    private var held: StatusAutoReading?
    private var unavailableSince: Date?
    private var squeezedSince: Date?
    private var fellBack = false
    private var fellBackAt = Date.distantPast
    private var fellBackEpoch = 0
    private var lastSqueezeSwitch: Date?
    /// The last reading decided on (for the accessibility label and tests).
    private(set) var reading: StatusAutoReading?
    /// The earliest reading expiry or squeeze transition that needs another evaluation.
    private(set) var pendingDeadline: Date?

    /// The mode to show now. Pure in its inputs and the injected time.
    mutating func resolve(_ input: StatusAutoInput, squeezed: Bool, displayEpoch: Int, now: Date) -> StatusAutoMode {
        pendingDeadline = nil
        let current: StatusAutoReading?
        switch input {
        case .reading(let value): held = value; unavailableSince = nil; current = value
        case .none: held = nil; unavailableSince = nil; current = nil
        case .unavailable:
            if held != nil {
                let since = min(unavailableSince ?? now, now)
                unavailableSince = since
                let expiry = since.addingTimeInterval(StatusTitleKeeper.holdLimit)
                if now >= expiry { held = nil; unavailableSince = nil }
                else { recheck(at: expiry) }
            }
            current = held
        }
        reading = current
        guard let current else { numberShown = false; redShown = false; squeezedSince = nil; return .iconOnly }
        if current.remaining <= 0 { numberShown = false; redShown = false; squeezedSince = nil; return .usedUp }
        // D377 red keeps its recovery hysteresis: shown at or under the alert line, gone five points above it.
        // D476 amber is not latched (macrev2-1289-9): it shows only while the estimate runs out before the reset, so an
        // amber reading that turns normal drops the number at once.
        if current.remaining <= current.alertLine { redShown = true }
        else if current.remaining > current.alertLine + Self.hysteresis { redShown = false }
        numberShown = redShown || current.amber
        guard numberShown else { squeezedSince = nil; fellBack = false; return .iconOnly }
        let wide = StatusAutoMode.number(current.shown)
        if fellBack {
            let retryDelay = displayEpoch != fellBackEpoch ? Self.minimumSwitchInterval : Self.retryWide
            let retry = fellBackAt.addingTimeInterval(retryDelay)
            if now < retry {
                recheck(at: retry)
                return .iconOnly
            }
            fellBack = false
            lastSqueezeSwitch = now
        }
        guard squeezed else { squeezedSince = nil; return wide }
        let since = squeezedSince ?? now
        squeezedSince = since
        let ready = since.addingTimeInterval(Self.squeezeDebounce)
        let nextSwitch = lastSqueezeSwitch.map { $0.addingTimeInterval(Self.minimumSwitchInterval) } ?? .distantPast
        let due = max(ready, nextSwitch)
        if now >= due {
            fellBack = true; fellBackAt = now; fellBackEpoch = displayEpoch; lastSqueezeSwitch = now; squeezedSince = nil
            recheck(at: now.addingTimeInterval(Self.retryWide))
            return .iconOnly
        }
        recheck(at: due)
        return wide
    }

    private mutating func recheck(at deadline: Date) {
        pendingDeadline = min(pendingDeadline ?? deadline, deadline)
    }

    /// The accessibility label: complete in every state, "ModelPlan · Codex 0%". Without a reading it is "ModelPlan".
    static func accessibilityLabel(_ reading: StatusAutoReading?) -> String {
        guard let reading else { return "ModelPlan" }
        return "ModelPlan \u{00B7} \(reading.name) \(reading.shown)"
    }
}

/// The red dot of a used-up quota, at the icon's bottom-right corner (G3-166: at the top-right it sat on the rocket's
/// nose). It lies inside the button's bounds and has no width of its own.
@MainActor final class StatusUsedUpDotView: NSView {
    static let side: CGFloat = 7
    override var isFlipped: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    /// Where the dot sits in a button's bounds: the bottom-right corner, whichever way the button's y axis runs.
    static func frame(in bounds: NSRect, flipped: Bool) -> NSRect {
        let y = flipped ? max(bounds.minY, bounds.maxY - side) : bounds.minY
        return NSRect(x: max(bounds.minX, bounds.maxX - side), y: y, width: side, height: side)
    }
    func attach(to button: NSButton) {
        frame = Self.frame(in: button.bounds, flipped: button.isFlipped)
        autoresizingMask = [.minXMargin, button.isFlipped ? .minYMargin : .maxYMargin]
        if superview !== button { button.addSubview(self) }
    }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.systemRed.setFill()
        NSBezierPath(ovalIn: bounds.insetBy(dx: 0.5, dy: 0.5)).fill()
    }
}
