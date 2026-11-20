// SPDX-License-Identifier: MIT
import Foundation

/// What decides the sampling cadence (owner D324).
public struct ResourceVisibility: Equatable, Sendable {
    /// The plugin is on (Settings › Subscriptions › Plugins). Off = no sampling at all.
    public var pluginEnabled: Bool
    /// The cockpit is open and the resource column is on its current page (the page's `pluginsRunning` lists it).
    public var columnShown: Bool
    /// The widget's resource ring is on screen.
    public var widgetShown: Bool
    /// The saved column interval (`intervalSeconds`, 2 / 5 / 10).
    public var columnSetting: Int
    public init(pluginEnabled: Bool, columnShown: Bool, widgetShown: Bool, columnSetting: Int) {
        self.pluginEnabled = pluginEnabled; self.columnShown = columnShown; self.widgetShown = widgetShown; self.columnSetting = columnSetting
    }
}

public enum ResourceCadence {
    public static let columnChoices: [Int] = [2, 5, 10]
    public static let widget: TimeInterval = 10
    public static let hidden: TimeInterval = 60
    /// A saved value snapped to the nearest choice; a tie takes the slower (cheaper) one.
    public static func columnInterval(_ setting: Int) -> TimeInterval {
        let best = columnChoices.min { a, b in
            let da = abs(a - setting), db = abs(b - setting)
            return da == db ? a > b : da < db
        } ?? 5
        return TimeInterval(best)
    }
    /// nil = do not sample.
    public static func interval(_ v: ResourceVisibility) -> TimeInterval? {
        guard v.pluginEnabled else { return nil }
        if v.columnShown { return columnInterval(v.columnSetting) }
        if v.widgetShown { return widget }
        return hidden
    }
    /// Timer coalescing: 10 % of the interval, at least 0.2 s. A coalesced timer may fire late, never early.
    public static func tolerance(_ interval: TimeInterval) -> TimeInterval { max(0.2, interval * 0.1) }
}

/// The cadence state machine. The sampler asks `admit` before every read, so no path (a stale timer, a repeated
/// visibility report) can sample while the plugin is off or sooner than the current interval allows.
public struct ResourceSchedule: Equatable, Sendable {
    public private(set) var interval: TimeInterval?
    public private(set) var lastSample: TimeInterval?
    public init() {}
    /// Applies a visibility change; returns the delay until the next sample (nil = stop).
    public mutating func update(_ visibility: ResourceVisibility, now: TimeInterval) -> TimeInterval? {
        interval = ResourceCadence.interval(visibility)
        guard let interval else { return nil }
        guard let lastSample else { return 0 }
        return max(0, lastSample + interval - now)
    }
    /// The delay to the next sample from `now`, given the current interval.
    public func delay(now: TimeInterval) -> TimeInterval? {
        guard let interval else { return nil }
        guard let lastSample else { return 0 }
        return max(0, lastSample + interval - now)
    }
    /// True (and records the sample time) only when sampling is on and the interval has passed.
    public mutating func admit(now: TimeInterval) -> Bool {
        guard let interval, now.isFinite else { return false }
        if let lastSample, now - lastSample < interval { return false }
        lastSample = now
        return true
    }
    /// Plugin off: forget the last sample time with the history.
    public mutating func reset() { lastSample = nil }
}
