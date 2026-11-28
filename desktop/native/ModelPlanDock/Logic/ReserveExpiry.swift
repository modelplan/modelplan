// SPDX-License-Identifier: MIT
import Foundation

/// Master spec §5.1 / C7 (D474): the one 48 h rule for a reserve item that expires soon. Within it the reserve line's
/// expiry clause turns amber (never a dot, never the ring, the lamp or the menu-bar %). The page helper
/// (`desktop/cockpit/study/rocket-r1/reserve-expiry.js`) and this one are tested against
/// `desktop/tests/shared/reserve-expiry.json`.
public enum ReserveExpiry {
    public static let soonHours: Double = 48
    /// True when the item expires after `now` and at most 48 h from it; a missing expiry is never soon.
    public static func soon(_ expiresAt: Date?, now: Date) -> Bool {
        guard let expiresAt, expiresAt.timeIntervalSinceReferenceDate.isFinite, now.timeIntervalSinceReferenceDate.isFinite else { return false }
        let left = expiresAt.timeIntervalSince(now)
        return left > 0 && left <= soonHours * 3600
    }
}
