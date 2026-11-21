// SPDX-License-Identifier: MIT
import Foundation

public enum ResourceReadoutKey: String, Equatable, Sendable { case memory, cpu }
/// Only numbers carry a tone; the ring never changes colour (D236, D327).
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
    public static let cpuRed: Double = 90
    public static let diskWarning: Double = 90
    public static func cpuTone(_ cpu: Double) -> ResourceTone { cpu >= cpuRed ? .critical : cpu >= cpuUp ? .warning : .normal }
    /// Memory follows macOS memory pressure, never its percentage (macOS fills free memory with cache).
    public static func memoryTone(_ pressure: ResourcePressure) -> ResourceTone {
        switch pressure { case .normal: return .normal; case .warn: return .warning; case .critical: return .critical }
    }
    public static func diskTone(_ disk: Double) -> ResourceTone { disk >= diskWarning ? .warning : .normal }
}

/// The readout switch (D327): memory normally; CPU once it has stayed ≥ 70 % for 20 s; back to memory once CPU has
/// stayed below 60 % for 30 s. Time runs between samples: a run is counted from its first sample to the current one,
/// and any sample outside the band restarts it.
public struct ResourceReadout: Equatable, Sendable {
    public private(set) var key: ResourceReadoutKey = .memory
    private var highSince: TimeInterval?
    private var lowSince: TimeInterval?
    public init() {}
    public mutating func step(_ s: ResourceSample) -> ResourceShown {
        let cpu = s.cpu, now = s.uptime
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
            ? ResourceShown(key: .cpu, percent: Int(cpu.rounded()), tone: ResourceRules.cpuTone(cpu))
            : ResourceShown(key: .memory, percent: Int(s.memoryPercent.rounded()), tone: ResourceRules.memoryTone(s.pressure))
    }
    public mutating func reset() { self = ResourceReadout() }
}

/// The widget ring (D327): outer arc memory (solid used, faint cached), inner thin arc CPU; disk is not on the ring.
/// Fractions 0–1. Maps onto the subscription ring's two arcs (ModelPlanDock DockInstrumentReading outer / inner).
public struct ResourceFace: Equatable, Sendable {
    public var memoryUsed: Double, memoryCached: Double, cpu: Double
    public var shown: ResourceShown
    /// False under Reduce Motion: arcs and the readout change without animation.
    public var animates: Bool
    public init(sample s: ResourceSample, shown: ResourceShown, reduceMotion: Bool) {
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
        return drawn.shown != face.shown || drawn.animates != face.animates || abs(drawn.memoryUsed - face.memoryUsed) >= step ||
            abs(drawn.memoryCached - face.memoryCached) >= step || abs(drawn.cpu - face.cpu) >= step
    }
    public mutating func reset() { drawn = nil }
}
