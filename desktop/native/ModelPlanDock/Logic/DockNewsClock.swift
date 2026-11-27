// SPDX-License-Identifier: MIT
import Foundation

/// D466 / DOCK-3.7-05: the one news clock for a public reset announcement, shared by every native surface (the widget
/// dot, the sliver and menu-bar dot, the card block and the alert row). One entry per event id and status.
///
/// An item is live until the first of
///  1. 30 minutes after the user first looked at it (hover the card that shows it, the cockpit page drawing it on its
///     visible page or listing it in the opened alert list; revealing the widget or opening the cockpit is not a look),
///  2. 3 present hours (Mac awake, unlocked and not idle for more than 5 minutes), counted from refresh timestamps (no
///     timer, no wakeup; sleep, screen sleep and lock close the span at once),
///  3. 24 hours after its anchor (the confirmation time, or the publication time of an announcement).
/// An item that has never been drawn is live (its clock starts when it is first drawn).
///
/// The whole value is Codable so a store can persist it; `DockNewsClockStore` below does that as one small JSON file.
public struct DockNewsClock: Codable, Equatable, Sendable {
    public static let lookGrace: TimeInterval = 30 * 60
    public static let presentCap: TimeInterval = 3 * 3600
    public static let hardCap: TimeInterval = 24 * 3600
    /// A gap between two refreshes counts as presence only up to this long; a longer gap is sleep or a stalled app.
    public static let maxCountedGap: TimeInterval = 15 * 60
    /// An entry is dropped this long after it was first drawn (well past the 24 h cap).
    public static let retention: TimeInterval = 72 * 3600

    public struct Entry: Codable, Equatable, Sendable {
        public var firstShown: Date
        public var firstLooked: Date?
        public var presentSeconds: TimeInterval
    }
    public private(set) var entries: [String: Entry] = [:]
    private var lastTick: Date?
    private var lastPresent = false
    public init() {}

    public static func key(eventID: String, status: String) -> String { eventID + "#" + status }

    /// One normal refresh. `shown` are the items drawn now; `present` is whether the Mac is awake and unlocked.
    /// Returns true when the persisted state changed enough to be worth saving.
    @discardableResult
    public mutating func tick(shown keys: [String], present: Bool, at now: Date) -> Bool {
        guard now.timeIntervalSinceReferenceDate.isFinite else { return false }
        var changed = false
        var gap: TimeInterval = 0
        if let last = lastTick, lastPresent, present { gap = min(max(now.timeIntervalSince(last), 0), Self.maxCountedGap) }
        for key in keys {
            if var entry = entries[key] {
                if gap > 0 { entry.presentSeconds += gap; entries[key] = entry; changed = true }
            } else {
                entries[key] = Entry(firstShown: now, firstLooked: nil, presentSeconds: 0); changed = true
            }
        }
        let before = entries.count
        entries = entries.filter { now.timeIntervalSince($0.value.firstShown) < Self.retention }
        if entries.count != before { changed = true }
        lastTick = now; lastPresent = present
        return changed
    }

    /// Master spec §5.3: the Mac went to sleep, the screens slept or the screen locked. The present span ends here, so the
    /// gap up to the next refresh is never counted, however short it is (no timer: the next tick starts a new span).
    public mutating func endPresence() { lastPresent = false }

    /// Master spec §5.3: the user counts as present only with recent input. macOS has no idle notification, so the idle
    /// seconds are read at the existing refresh tick; past this many seconds the Mac is idle.
    public static let idleThreshold: TimeInterval = 5 * 60
    /// Whether the Mac counts as present: awake, unlocked, in the console session and not idle.
    public static func isPresent(locked: Bool, onConsole: Bool, idleSeconds: TimeInterval?) -> Bool {
        if locked || !onConsole { return false }
        if let idleSeconds, idleSeconds.isFinite, idleSeconds > idleThreshold { return false }
        return true
    }

    /// The user looked at these items now (the first look only is kept).
    public mutating func look(_ keys: [String], at now: Date) {
        guard now.timeIntervalSinceReferenceDate.isFinite else { return }
        for key in keys {
            guard var entry = entries[key] else { continue }
            if entry.firstLooked == nil { entry.firstLooked = now; entries[key] = entry }
        }
    }

    /// Whether the item still shows at `now`.
    public func isLive(_ key: String, anchor: Date, at now: Date) -> Bool {
        guard now < anchor.addingTimeInterval(Self.hardCap) else { return false }
        guard let entry = entries[key] else { return true }
        if let looked = entry.firstLooked, now >= looked.addingTimeInterval(Self.lookGrace) { return false }
        return entry.presentSeconds < Self.presentCap
    }

    /// The latest moment the item can still be news (24 h after its anchor, or 30 min after the first look); nil when it
    /// is not news now. The present-hours cap cannot be predicted, so a surface re-asks on every refresh.
    public func liveUntil(_ key: String, anchor: Date, at now: Date) -> Date? {
        guard isLive(key, anchor: anchor, at: now) else { return nil }
        var end = anchor.addingTimeInterval(Self.hardCap)
        if let looked = entries[key]?.firstLooked { end = min(end, looked.addingTimeInterval(Self.lookGrace)) }
        return end
    }

    /// Whether the user has looked at the item (the pointer surfaces, menu-bar and sliver, drop their dot at once).
    public func hasBeenLooked(_ key: String) -> Bool { entries[key]?.firstLooked != nil }
}

/// The shared holder: one instance per app, handed to the content provider (which ticks and reads it) and to the Dock
/// host (which records looks). Persistence is one JSON file; a missing or unreadable file starts a fresh clock.
public final class DockNewsClockStore: @unchecked Sendable {
    public private(set) var clock: DockNewsClock
    private let url: URL?
    private var lastSave: Date?
    public init(url: URL? = nil) {
        self.url = url
        if let url, let data = try? Data(contentsOf: url), let decoded = try? JSONDecoder().decode(DockNewsClock.self, from: data) {
            clock = decoded
        } else { clock = DockNewsClock() }
    }
    public func tick(shown keys: [String], present: Bool, at now: Date) {
        let changed = clock.tick(shown: keys, present: present, at: now)
        // At most one write a minute; a look always saves.
        if changed, lastSave.map({ now.timeIntervalSince($0) >= 60 }) ?? true { save(at: now) }
    }
    /// Sleep, screen sleep or lock: close the present span (nothing to save; the span state is not persisted).
    public func endPresence() { clock.endPresence() }
    public func look(_ keys: [String], at now: Date) {
        guard !keys.isEmpty else { return }
        let before = clock
        clock.look(keys, at: now)
        if clock != before { save(at: now) }
    }
    public func isLive(_ key: String, anchor: Date, at now: Date) -> Bool { clock.isLive(key, anchor: anchor, at: now) }
    public func liveUntil(_ key: String, anchor: Date, at now: Date) -> Date? { clock.liveUntil(key, anchor: anchor, at: now) }
    private func save(at now: Date) {
        lastSave = now
        guard let url, let data = try? JSONEncoder().encode(clock) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}
