// SPDX-License-Identifier: MIT
import Foundation

/// G3-122: what the admitted projection says about the menu-bar title at one moment.
/// `.value` is a number to show; `.none` means the item is icon-only by decision (icon display mode, no reading
/// at all, privacy clear); `.unavailable` means the projection is between two admitted states (an engine delivery
/// is being replaced, a reconnect, a reading still loading) and says nothing about the number.
enum StatusTitleReading: Equatable {
    case value(String)
    case none
    case unavailable
}

/// G3-122 (owner build 14f): the menu-bar percentage blinked on and off, faster than once a second. Every engine
/// rows delivery replaces the admitted projection in two synchronous steps (clear, then install), and each step
/// re-rendered the status item: "13%", then "" with the square icon-only length, then "13%" again. Renders between
/// an invalidation and the next install (an occlusion re-verify, a Settings change, a tooltip refresh) read the empty
/// fallback too.
///
/// Behaviour copied from CodexBar (own code): its status item reads `UsageStore.snapshot(for:)`, which keeps the last
/// successful snapshot while a refresh is in flight or failed and drops it only on a definitive event (account
/// change, provider disabled); the single writer `setButtonContent` writes only changed values. Here: one owner of the
/// title decides what is shown; a gap keeps the last number shown, with no stale marking (owner, G3-122); only a
/// definitive `.none` or a gap longer than `holdLimit` takes the number away.
struct StatusTitleKeeper {
    /// A gap this long is no longer a transient replacement (the engine is gone or the reading has truly lapsed).
    static let holdLimit: TimeInterval = 600
    private(set) var shown = ""
    private var lastValue: String?
    private var unavailableSince: Date?

    /// While a gap holds the last number: when the hold ends (macrev2-976-2). The owner arms a wake-up for it, so the
    /// number goes at the limit even when nothing else renders (a paused engine, a suspended projection).
    var holdDeadline: Date? {
        guard lastValue != nil, let since = unavailableSince else { return nil }
        return since.addingTimeInterval(Self.holdLimit)
    }

    /// The title to show now. Pure in its inputs and the injected time; never returns a different title for a
    /// `.unavailable` reading inside the hold.
    mutating func resolve(_ reading: StatusTitleReading, now: Date) -> String {
        switch reading {
        case .value(let title) where !title.isEmpty:
            lastValue = title; unavailableSince = nil; shown = title
        case .value, .none:
            lastValue = nil; unavailableSince = nil; shown = ""
        case .unavailable:
            guard let lastValue else { shown = ""; return shown }
            let since = unavailableSince ?? now
            unavailableSince = since
            // A clock that went backwards restarts the hold instead of ending it.
            if now < since { unavailableSince = now }
            if now.timeIntervalSince(unavailableSince ?? now) >= Self.holdLimit {
                self.lastValue = nil; self.unavailableSince = nil; shown = ""
            } else { shown = lastValue }
        }
        return shown
    }
}
