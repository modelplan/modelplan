// SPDX-License-Identifier: MIT
import Foundation

/// The last ten minutes of samples, in memory only (D324): nothing here is ever written to disk.
public struct ResourceHistory: Equatable, Sendable {
    public static let window: TimeInterval = 600
    /// Ten minutes at the fastest cadence (2 s) plus slack.
    public static let capacity = 330
    public private(set) var samples: [ResourceSample] = []
    public init() {}
    public mutating func append(_ s: ResourceSample) {
        guard s.uptime.isFinite, samples.last.map({ s.uptime > $0.uptime }) ?? true else { return }
        samples.append(s)
        let floor = s.uptime - Self.window
        if let keep = samples.firstIndex(where: { $0.uptime > floor }), keep > 0 { samples.removeFirst(keep) }
        if samples.count > Self.capacity { samples.removeFirst(samples.count - Self.capacity) }
    }
    public mutating func removeAll() { samples.removeAll() }
    /// The ten-minute CPU peak (the card's "最高").
    public var peakCPU: Double { samples.reduce(0) { max($0, $1.cpu) } }
}

/// What to push to the page as `pluginData` (D324): the whole window when the column starts running (the page keeps
/// no history of its own across openings), then only newer samples.
public struct ResourcePageFeed: Equatable, Sendable {
    /// desktop/cockpit/src/resource-plugin.ts MAX_PER_READING.
    public static let maximumPerReading = 360
    private var delivered: TimeInterval?
    public init() {}
    public mutating func next(_ history: ResourceHistory, running: Bool) -> [ResourceSample]? {
        guard running else { delivered = nil; return nil }
        let fresh = history.samples.filter { s in delivered.map { s.uptime > $0 } ?? true }.suffix(Self.maximumPerReading)
        guard let last = fresh.last else { return nil }
        delivered = last.uptime
        return Array(fresh)
    }
}
