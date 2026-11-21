// SPDX-License-Identifier: MIT
import Foundation

/// The widget hover card's rows (D327): CPU · 内存 · 磁盘, each label · continuous bar · % · one side value.
/// Variant A: the row that matches the ring readout is at full ink (label and number), the others at secondary ink.
/// The emphasis never uses a background; a tint marks problem rows only (memory pressure high, CPU ≥ 70 %, disk ≥ 90 %).
/// An amber or red number keeps its tone on every row. Maps onto ModelPlanDock DockCardRow (label, value, fill, tone).
public struct ResourceCard: Equatable, Sendable {
    public enum RowID: String, Equatable, Sendable { case cpu, memory, disk }
    public enum Ink: Equatable, Sendable { case full, secondary }
    public enum ValueInk: Equatable, Sendable { case full, secondary, tone(ResourceTone) }
    public struct Row: Equatable, Sendable {
        public var id: RowID, label: String, percent: Int, side: String
        /// Bar fill (0–1); memory also has its faint cached segment after the used one.
        public var fill: Double, cachedFill: Double?
        /// The warning notch on the bar (CPU 70 %, disk 90 %).
        public var notch: Double?
        public var tone: ResourceTone
        /// Label ink (variant A).
        public var ink: Ink
        public var valueInk: ValueInk
        public var tinted: Bool
    }
    public var rows: [Row]
    /// "内存压力 正常 · 每 10 秒"; the card's right side links to the cockpit screen.
    public var footer: String
    public var screenLink: String

    public init(sample s: ResourceSample, shown: ResourceShown, cpuPeak: Double, interval: TimeInterval, language: ResourceLanguage) {
        let zh = language == .chinese
        let matched: RowID = shown.key == .cpu ? .cpu : .memory
        func row(_ id: RowID, _ label: String, _ value: Double, _ side: String, cached: Double? = nil, notch: Double?, tone: ResourceTone, problem: Bool) -> Row {
            let ink: Ink = id == matched ? .full : .secondary
            let valueInk: ValueInk = tone != .normal ? .tone(tone) : ink == .full ? .full : .secondary
            return Row(id: id, label: label, percent: Int(value.rounded()), side: side, fill: min(1, max(0, value / 100)),
                       cachedFill: cached, notch: notch, tone: tone, ink: ink, valueInk: valueInk, tinted: problem)
        }
        let peak = Int(max(cpuPeak, s.cpu).rounded())
        rows = [
            row(.cpu, "CPU", s.cpu, zh ? "最高 \(peak)%" : "peak \(peak)%", notch: ResourceRules.cpuUp / 100,
                tone: ResourceRules.cpuTone(s.cpu), problem: s.cpu >= ResourceRules.cpuUp),
            row(.memory, zh ? "内存" : "Memory", s.memoryPercent, "\(ResourceFormat.gb(s.memoryUsed)) / \(ResourceFormat.gb(s.memTotal)) GB",
                cached: min(1 - s.memoryPercent / 100, s.cachedPercent / 100), notch: nil,
                tone: ResourceRules.memoryTone(s.pressure), problem: s.pressure != .normal),
            row(.disk, zh ? "磁盘" : "Disk", s.diskPercent, zh ? "剩 \(ResourceFormat.gb(s.diskFree)) GB" : "\(ResourceFormat.gb(s.diskFree)) GB free",
                notch: ResourceRules.diskWarning / 100, tone: ResourceRules.diskTone(s.diskPercent), problem: s.diskPercent >= ResourceRules.diskWarning),
        ]
        let pressure: String
        switch s.pressure {
        case .normal: pressure = zh ? "正常" : "Normal"
        case .warn: pressure = zh ? "偏高" : "Elevated"
        case .critical: pressure = zh ? "严重" : "Critical"
        }
        var parts = [(zh ? "内存压力 " : "Memory pressure ") + pressure]
        if s.swapUsed >= UInt64(1 << 30) / 10 { parts.append((zh ? "交换 " : "swap ") + ResourceFormat.gb(s.swapUsed) + " GB") }
        let seconds = Int(interval.rounded())
        parts.append(zh ? "每 \(seconds) 秒" : "every \(seconds) s")
        footer = parts.joined(separator: " · ")
        screenLink = zh ? "驾驶舱大屏 ›" : "Cockpit screen ›"
    }
}
