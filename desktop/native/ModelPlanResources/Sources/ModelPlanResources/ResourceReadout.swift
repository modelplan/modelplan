// SPDX-License-Identifier: MIT
import Foundation

public enum ResourceReadoutKey: String, Equatable, Sendable { case memory, cpu }
/// D371 B4c (owner 11-21, the 11-13 round-4 status colour): a resource's tone is normal, amber (`.warning`) or red
/// (`.critical`), the same family as the quota rings. It colours the ring arc, the card bar and the number alike.
public enum ResourceTone: String, Equatable, Sendable { case normal, warning, critical }

/// What the widget's readout shows under the ring.
public struct ResourceShown: Equatable, Sendable {
    public var key: ResourceReadoutKey
    public var percent: Int
    public var tone: ResourceTone
    public init(key: ResourceReadoutKey, percent: Int, tone: ResourceTone) { self.key = key; self.percent = percent; self.tone = tone }
    public func label(_ language: ResourceLanguage) -> String { key == .cpu ? "CPU" : language == .chinese ? "内存" : "Memory" }
    /// "内存 47%", "CPU 96%".
    public func text(_ language: ResourceLanguage) -> String { "\(label(language)) \(percent)%" }
}

public enum ResourceRules {
    /// CPU takes the readout at or above this for `cpuUpFor` seconds.
    public static let cpuUp: Double = 70
    public static let cpuUpFor: TimeInterval = 20
    /// The readout returns to memory after CPU has stayed below this for `cpuDownFor` seconds.
    public static let cpuDown: Double = 60
    public static let cpuDownFor: TimeInterval = 30
    /// D371 B4c: one status rule for CPU, memory and disk (the 11-13 board gives no numbers, so the brief's): amber from
    /// 80 %, red from 90 %, and a tone is left only once the value is `hysteresis` points below its threshold.
    public static let amber: Double = 80
    public static let red: Double = 90
    public static let hysteresis: Double = 3
    public static func tone(_ percent: Double, previous: ResourceTone? = nil) -> ResourceTone {
        let redAt = previous == .critical ? red - hysteresis : red
        let amberAt = previous == .warning || previous == .critical ? amber - hysteresis : amber
        return percent >= redAt ? .critical : percent >= amberAt ? .warning : .normal
    }
    public static func cpuTone(_ cpu: Double, previous: ResourceTone? = nil) -> ResourceTone { tone(cpu, previous: previous) }
    /// Memory is toned by its percentage and also by macOS memory pressure (warn is at least amber, critical red).
    public static func memoryTone(_ pressure: ResourcePressure) -> ResourceTone {
        switch pressure { case .normal: return .normal; case .warn: return .warning; case .critical: return .critical }
    }
    public static func memoryTone(percent: Double, pressure: ResourcePressure, previous: ResourceTone? = nil) -> ResourceTone {
        worse(tone(percent, previous: previous), memoryTone(pressure))
    }
    public static func diskTone(_ disk: Double, previous: ResourceTone? = nil) -> ResourceTone { tone(disk, previous: previous) }
    static func worse(_ a: ResourceTone, _ b: ResourceTone) -> ResourceTone {
        a == .critical || b == .critical ? .critical : a == .warning || b == .warning ? .warning : .normal
    }
}

/// The three tones after one sample; the previous ones give the 3-point hysteresis a memory.
public struct ResourceLevels: Equatable, Sendable {
    public var cpu: ResourceTone, memory: ResourceTone, disk: ResourceTone
    public init(cpu: ResourceTone, memory: ResourceTone, disk: ResourceTone) { self.cpu = cpu; self.memory = memory; self.disk = disk }
    public init(sample s: ResourceSample, previous: ResourceLevels? = nil) {
        cpu = ResourceRules.cpuTone(s.cpu, previous: previous?.cpu)
        memory = ResourceRules.memoryTone(percent: s.memoryPercent, pressure: s.pressure, previous: previous?.memory)
        disk = ResourceRules.diskTone(s.diskPercent, previous: previous?.disk)
    }
}

/// The readout switch (D327): memory normally; CPU once it has stayed ≥ 70 % for 20 s; back to memory once CPU has
/// stayed below 60 % for 30 s. Time runs between samples: a run is counted from its first sample to the current one,
/// and any sample outside the band restarts it.
public struct ResourceReadout: Equatable, Sendable {
    public private(set) var key: ResourceReadoutKey = .memory
    /// The tones after the latest sample (D371 hysteresis state).
    public private(set) var levels: ResourceLevels?
    private var highSince: TimeInterval?
    private var lowSince: TimeInterval?
    public init() {}
    public mutating func step(_ s: ResourceSample) -> ResourceShown {
        let cpu = s.cpu, now = s.uptime
        let levels = ResourceLevels(sample: s, previous: self.levels)
        self.levels = levels
        switch key {
        case .memory:
            if cpu >= ResourceRules.cpuUp {
                let since = highSince ?? now
                highSince = since
                if now - since >= ResourceRules.cpuUpFor { key = .cpu; highSince = nil; lowSince = nil }
            } else { highSince = nil }
        case .cpu:
            if cpu < ResourceRules.cpuDown {
                let since = lowSince ?? now
                lowSince = since
                if now - since >= ResourceRules.cpuDownFor { key = .memory; lowSince = nil; highSince = nil }
            } else { lowSince = nil }
        }
        return key == .cpu
            ? ResourceShown(key: .cpu, percent: Int(cpu.rounded()), tone: levels.cpu)
            : ResourceShown(key: .memory, percent: Int(s.memoryPercent.rounded()), tone: levels.memory)
    }
    public mutating func reset() { self = ResourceReadout() }
}

/// The widget ring (D327, D371 status colours): outer arc memory (solid used, faint cached), inner thin arc CPU; disk is not on the ring.
/// Fractions 0–1. Maps onto the subscription ring's two arcs (ModelPlanDock DockInstrumentReading outer / inner).
public struct ResourceFace: Equatable, Sendable {
    public var memoryUsed: Double, memoryCached: Double, cpu: Double
    public var shown: ResourceShown
    /// D371: the status tone of each resource; the ring's outer arc is memory's, the inner arc CPU's.
    public var levels: ResourceLevels
    /// False under Reduce Motion: arcs and the readout change without animation.
    public var animates: Bool
    public init(sample s: ResourceSample, shown: ResourceShown, reduceMotion: Bool, levels: ResourceLevels? = nil) {
        self.levels = levels ?? ResourceLevels(sample: s)
        memoryUsed = s.memoryPercent / 100
        memoryCached = min(1 - memoryUsed, s.cachedPercent / 100)
        cpu = s.cpu / 100
        self.shown = shown
        animates = !reduceMotion
    }
}

/// Redraw only on a change of at least one percentage point in an arc, or any readout change (D324).
public struct ResourceRedrawGate: Equatable, Sendable {
    private var drawn: ResourceFace?
    public init() {}
    public mutating func admit(_ face: ResourceFace) -> Bool {
        defer { if changed(face) { drawn = face } }
        return changed(face)
    }
    private func changed(_ face: ResourceFace) -> Bool {
        guard let drawn else { return true }
        let step = 0.01 - 1e-9
        // The ring draws memory's and CPU's tone (disk is not on the ring), so only those redraw it.
        return drawn.shown != face.shown || drawn.levels.cpu != face.levels.cpu || drawn.levels.memory != face.levels.memory || drawn.animates != face.animates || abs(drawn.memoryUsed - face.memoryUsed) >= step ||
            abs(drawn.memoryCached - face.memoryCached) >= step || abs(drawn.cpu - face.cpu) >= step
    }
    public mutating func reset() { drawn = nil }
}
