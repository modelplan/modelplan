// SPDX-License-Identifier: MIT
import Foundation

/// D413: one minute of samples, folded (mean and peak of every reading in it). The 1-hour view of the Resources screen
/// draws these; the peak keeps the highest raw (2–10 s) reading, so a short spike is not averaged away.
public struct ResourceMinute: Equatable, Sendable {
    /// Start of the minute on the page's time axis (Unix ms, a multiple of 60 000).
    public var unixMs: Int64
    public var count = 0
    public var cpuSum = 0.0, cpuPeak = 0.0, memorySum = 0.0, memoryPeak = 0.0, diskSum = 0.0, diskPeak = 0.0
    public var netCount = 0
    public var netInSum = 0.0, netOutSum = 0.0, netInPeak: UInt64 = 0, netOutPeak: UInt64 = 0
    public init(unixMs: Int64) { self.unixMs = unixMs }
    mutating func fold(_ s: ResourceSample) {
        count += 1
        cpuSum += s.cpu; cpuPeak = max(cpuPeak, s.cpu)
        memorySum += s.memoryPercent; memoryPeak = max(memoryPeak, s.memoryPercent)
        diskSum += s.diskPercent; diskPeak = max(diskPeak, s.diskPercent)
        if let i = s.netIn, let o = s.netOut {
            netCount += 1; netInSum += Double(i); netOutSum += Double(o)
            netInPeak = max(netInPeak, i); netOutPeak = max(netOutPeak, o)
        }
    }
    public var cpu: Double { count == 0 ? 0 : cpuSum / Double(count) }
    public var memory: Double { count == 0 ? 0 : memorySum / Double(count) }
    public var disk: Double { count == 0 ? 0 : diskSum / Double(count) }
    public var netIn: UInt64? { netCount == 0 ? nil : UInt64(netInSum / Double(netCount)) }
    public var netOut: UInt64? { netCount == 0 ? nil : UInt64(netOutSum / Double(netCount)) }
}

/// The last ten minutes of samples and (D413) the last hour as one-minute folds, in memory only (D324): nothing here is
/// ever written to disk.
public struct ResourceHistory: Equatable, Sendable {
    public static let window: TimeInterval = 600
    /// Ten minutes at the fastest cadence (2 s) plus slack.
    public static let capacity = 330
    /// D413: closed minutes kept for the 1-hour view.
    public static let minuteCapacity = 60
    public private(set) var samples: [ResourceSample] = []
    /// Closed minutes, oldest first (at most an hour); the minute still being filled is not in here.
    public private(set) var minutes: [ResourceMinute] = []
    private var current: ResourceMinute?
    public init() {}
    public mutating func append(_ s: ResourceSample) {
        guard s.uptime.isFinite, samples.last.map({ s.uptime > $0.uptime }) ?? true else { return }
        samples.append(s)
        let floor = s.uptime - Self.window
        if let keep = samples.firstIndex(where: { $0.uptime > floor }), keep > 0 { samples.removeFirst(keep) }
        if samples.count > Self.capacity { samples.removeFirst(samples.count - Self.capacity) }
        let minute = s.unixMs - ((s.unixMs % 60_000) + 60_000) % 60_000
        if let open = current, open.unixMs != minute {
            if minute > open.unixMs { minutes.append(open) }
            current = nil
        }
        if current == nil { current = ResourceMinute(unixMs: minute) }
        current?.fold(s)
        // An hour back from the newest minute; also bounded by count.
        minutes.removeAll { $0.unixMs <= minute - Int64(Self.minuteCapacity) * 60_000 }
        if minutes.count > Self.minuteCapacity { minutes.removeFirst(minutes.count - Self.minuteCapacity) }
    }
    public mutating func removeAll() { samples.removeAll(); minutes.removeAll(); current = nil }
    /// The ten-minute CPU peak (the card's "最高").
    public var peakCPU: Double { samples.reduce(0) { max($0, $1.cpu) } }
}

/// What to push to the page as `pluginData` (D324): the whole window when the column starts running (the page keeps
/// no history of its own across openings), then only newer samples.
public struct ResourcePageFeed: Equatable, Sendable {
    /// desktop/cockpit/src/resource-plugin.ts MAX_PER_READING.
    public static let maximumPerReading = 360
    private var delivered: TimeInterval?
    private var deliveredMinute: Int64?
    public init() {}
    /// D413: every closed minute when the column starts running or a new minute closed since the last delivery; nil
    /// otherwise (the page keeps the last list it got).
    public mutating func minutes(_ history: ResourceHistory, running: Bool) -> [ResourceMinute]? {
        guard running else { deliveredMinute = nil; return nil }
        guard let last = history.minutes.last, last.unixMs != deliveredMinute else { return nil }
        deliveredMinute = last.unixMs
        return history.minutes
    }
    public mutating func next(_ history: ResourceHistory, running: Bool) -> [ResourceSample]? {
        guard running else { delivered = nil; return nil }
        let fresh = history.samples.filter { s in delivered.map { s.uptime > $0 } ?? true }.suffix(Self.maximumPerReading)
        guard let last = fresh.last else { return nil }
        delivered = last.uptime
        return Array(fresh)
    }
}
