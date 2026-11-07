// SPDX-License-Identifier: MIT
import Foundation

/// MENU-12: an actually open menu protects the dock; a stale menu-open flag must not block recovery.
/// Delegate callbacks (`menuWillOpen`/`menuDidClose`) latch the menu-open signal, and AppKit's
/// balanced tracking notifications are the authority that a session is actually live. Protection
/// therefore requires both: a latch whose tracking session ended — the scrub path cancels tracking
/// without a guaranteed `menuDidClose` — or a latch that never saw a session stops protecting at
/// once, so the visibility state machine regains its collapse deadline and the dock recovers.
public struct DockMenuTrackingState: Sendable, Equatable {
    public private(set) var latched = false
    public private(set) var liveSessions = 0
    public init() {}
    /// An actually open menu only: a stale latch without a live session never protects.
    public var protectsDock: Bool { latched && liveSessions > 0 }
    public mutating func menuWillOpen() { latched = true }
    public mutating func menuDidClose() { latched = false }
    public mutating func trackingBegan() { liveSessions += 1; latched = true }
    public mutating func trackingEnded() {
        liveSessions = max(0, liveSessions - 1)
        if liveSessions == 0 { latched = false }
    }
}
