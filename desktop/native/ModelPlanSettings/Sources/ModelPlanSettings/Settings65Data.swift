// SPDX-License-Identifier: MIT
import Foundation

public enum SettingsDockEdge: String, Codable, CaseIterable, Sendable { case right, bottom, left }
public enum SettingsReaderID: String, Codable, CaseIterable, Sendable { case codex, claude, gemini, cursor }
public enum OptionalReaderID: String, Codable, CaseIterable, Sendable { case gemini, cursor }
/// Consent is an app choice, not proof a reader is enabled or a command to enable one.
public struct ReaderConsent: Codable, Equatable, Sendable {
    public var gemini = false
    public var cursor = false
    public init() {}
    private enum CodingKeys: CodingKey { case gemini, cursor }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        gemini = c.contains(.gemini) ? try c.decode(Bool.self, forKey: .gemini) : false
        cursor = c.contains(.cursor) ? try c.decode(Bool.self, forKey: .cursor) : false
    }
    public subscript(_ id: OptionalReaderID) -> Bool {
        get { id == .gemini ? gemini : cursor }
        set { if id == .gemini { gemini = newValue } else { cursor = newValue } }
    }
}
public enum ReaderObservation: String, Sendable { case unknown, detected, unavailable, denied }
public struct ReaderSetting: Equatable, Sendable {
    public let id: SettingsReaderID, title: String
    public let description: SettingsText
    public let observation: ReaderObservation
    public let consent: Bool?
    public static func project(consent: ReaderConsent, observations: [SettingsReaderID: ReaderObservation]) -> [Self] {
        SettingsReaderID.allCases.map { id in
            let optional = OptionalReaderID(rawValue: id.rawValue)
            let title: String
            switch id { case .codex: title = "Codex CLI"; case .claude: title = "Claude Code"; case .gemini: title = "Gemini CLI"; case .cursor: title = "Cursor" }
            let description: SettingsText = id == .gemini ? .init("Read local session usage.", "读取本地会话用量。") : id == .cursor ? .init("Read local editor usage.", "读取本地编辑器用量。") : .init("Read local usage records.", "读取本地用量记录。")
            return .init(id: id, title: title, description: description, observation: observations[id] ?? .unknown,
                         consent: optional.map { consent[$0] })
        }
    }
}
/// Confirmed task65 homes shared by the current data table; not a visual/layout implementation.
public enum Settings65Homes {
    public static let general = SettingsGroupDefinition(id: "general", keys: [.login,.automaticUpdates,.language,.menuDisplay,.openShortcut,.dockShortcut,.resetHints])
    public static let dock: [SettingsGroupDefinition] = [
        .init(id: "display", title: .init("Display", "显示"), keys: [.showDock,.autoHide,.reveal,.magnification,.size]),
        .init(id: "numbers", title: .init("Numbers", "数字"), keys: [.showPercentages,.percentageMode,.percentagePin,.redBelow,.sliverAlert]),
        .init(id: "location", title: .init("Position", "位置"), keys: [.dockDisplay,.dockEdge,.dockPosition,.fullscreen,.captureHiding,.activeDisplay]),
        .init(id: "sequence", title: .init("Order", "顺序"), keys: [.order]),
    ]
    public static let cockpit = SettingsGroupDefinition(id: "cockpit", keys: [.opening,.countdown])
    public static let appearance = SettingsGroupDefinition(id: "appearance", keys: [.theme,.motion,.transparency])
    public static let subscriptions = SettingsGroupDefinition(id: "subscriptions", keys: [.visible,.alias,.source,.detectedReaders,.optionalReaders])
    public static let paneCountPending = false
}
public enum SettingsDiagramKind: String, CaseIterable, Sendable { case edge, percentages, autoCollapse, size, quotaWindow }
public enum SettingsDiagramInput: Equatable, Sendable {
    case edge(SettingsDockEdge), percentages(shown: Bool, eventDot: Bool), autoCollapse(Bool), size(SettingsSize)
    case quotaWindow(subscriptionID: String?, pin: PercentagePin)
}
public struct SettingsDiagramPolicy: Equatable, Sendable {
    public let duration: TimeInterval
    public let selectedEndState: Bool
    public let loops = false
    public let changesControlGeometry = false
    public init(reduceMotion: Bool) { duration = reduceMotion ? 0 : 0.4; selectedEndState = reduceMotion }
    public static let width: Double = 96, height: Double = 40, stroke: Double = 1
    public static var sizeRatio: [Int] { SettingsSize.allCases.map { Int($0.nozzleDiameter) } }
    public static let quotaArcFraction = 0.7
    public static let clockwiseFromTwelve = true
}
public enum SettingsDiagrams {
    public static func inputs(_ p: SettingsPreferences, orderedIDs: [String], lastChangedSubscriptionID: String? = nil) -> [SettingsDiagramInput] {
        let selected = lastChangedSubscriptionID.flatMap { orderedIDs.contains($0) ? $0 : nil } ?? orderedIDs.first
        return [.edge(p.dockEdge), .percentages(shown: p.showPercentages, eventDot: true), .autoCollapse(p.autoHide), .size(p.size),
                .quotaWindow(subscriptionID: selected, pin: selected.flatMap { p.subscriptionSettings[$0]?.percentagePin } ?? .auto)]
    }
}

/// No timer or view; the host samples only during this one finite transition.
public struct SettingsDiagramPlayback: Sendable {
    public private(set) var startedAt: TimeInterval?
    public private(set) var endsAt: TimeInterval?
    public init() {}
    public mutating func trigger(at now: TimeInterval, reduceMotion: Bool) throws {
        guard now.isFinite, now >= 0 else { throw SettingsError.invalidTime }
        startedAt = reduceMotion ? nil : now; endsAt = reduceMotion ? nil : now + 0.4
    }
    public mutating func reduceMotionNow() { startedAt = nil; endsAt = nil }
    public func progress(at now: TimeInterval) throws -> Double {
        guard now.isFinite, now >= 0 else { throw SettingsError.invalidTime }
        guard let startedAt, let endsAt else { return 1 }
        return max(0,min(1,(now-startedAt)/(endsAt-startedAt)))
    }
}
