// SPDX-License-Identifier: MIT
import Foundation
import Darwin
import ModelPlanDock

public enum SettingsError: Error, Equatable {
    case unsupportedSchema, invalidPreference, tooLarge, invalidCatalogue, staleRevision, invalidTime
}
public enum SettingsTheme: String, Codable, CaseIterable, Sendable { case system, day, night }
public enum SettingsSize: String, Codable, CaseIterable, Sendable { case small = "S", medium = "M", large = "L" }
public enum AccessibilityPreference: String, Codable, CaseIterable, Sendable { case system, on }
public enum PercentageMode: String, Codable, CaseIterable, Sendable { case remaining, used }
public enum PercentagePin: String, Codable, CaseIterable, Sendable { case auto, fiveHour = "5h", week }
public enum HoverMagnification: String, Codable, CaseIterable, Sendable { case none, subtle, strong }
public enum MenuDisplay: String, Codable, CaseIterable, Sendable { case icon, tightest, twoWindows }
public enum OpeningPreference: String, Codable, CaseIterable, Sendable { case hold, quick }
public enum SettingsLanguage: String, Codable, CaseIterable, Sendable { case chinese = "zh-CN", english = "en" }
public enum NotificationKind: String, Codable, CaseIterable, Sendable { case forecast, reset, official, expiring, stale }
public struct NotificationPreferences: Codable, Equatable, Sendable {
    /// Per-kind choices do not grant consent. The separate opt-in defaults off.
    public var optedIn = false
    public var kinds = Set(NotificationKind.allCases)
    public init() {}
    private enum CodingKeys: CodingKey { case optedIn, kinds }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(optedIn, forKey: .optedIn)
        try c.encode(kinds.sorted { $0.rawValue < $1.rawValue }, forKey: .kinds)
    }
}
public struct SubscriptionSetting: Codable, Equatable, Sendable {
    public var alias = ""
    public var percentagePin: PercentagePin = .auto
    public init(alias: String = "", percentagePin: PercentagePin = .auto) {
        self.alias = alias; self.percentagePin = percentagePin
    }
}
public struct ShortcutChord: Codable, Equatable, Sendable {
    public enum Modifier: String, Codable, Hashable, Sendable { case command, control, option, shift }
    public var modifiers: Set<Modifier>
    public var key: String
    public init(_ key: String, modifiers: Set<Modifier>) { self.key = key; self.modifiers = modifiers }
    private enum CodingKeys: CodingKey { case modifiers, key }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(key, forKey: .key)
        try c.encode(modifiers.sorted { $0.rawValue < $1.rawValue }, forKey: .modifiers)
    }
    public var isValid: Bool {
        key.count == 1 && key.utf8.count <= 8 && key == key.uppercased() && key != "+"
            && !key.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
            && !(key == "," && modifiers == [.command]) // Command-comma belongs to Settings.
            && !modifiers.intersection([.command, .control, .option]).isEmpty
    }
}

/// App-owned choices only: no CLI snapshots, credentials, raw errors or inferred login/authorization state.
/// The file is separate from Core's CommunityPreferences (locale/favourites); neither store overwrites the other.
public struct SettingsPreferences: Codable, Sendable {
    public var theme: SettingsTheme = .system
    public var size: SettingsSize = .medium
    public var motion: AccessibilityPreference = .system
    public var transparency: AccessibilityPreference = .system
    public var percentageMode: PercentageMode = .remaining
    public var showPercentages = true
    public var redBelow = 16
    public var sliverAlert = true
    public var showDock = true
    public var autoHide = true
    public var revealMilliseconds = 150
    public var magnification: HoverMagnification = .subtle
    public var showOverFullscreen = false
    public var followActiveDisplay = true
    public var dockEdge: SettingsDockEdge = .right
    public var readerConsent = ReaderConsent()
    public var helpHints = FirstUseHintPreferences()
    /// App-owned choice, never the observed SMAppService state. Missing v1 fields default on.
    public var openAtLogin = true
    /// Saved preference only; observing/performing update checks belongs to the application service.
    public var automaticUpdates = true
    public var menuDisplay: MenuDisplay = .icon
    public var openShortcut = ShortcutChord("O", modifiers: [.command, .shift])
    public var dockShortcut = ShortcutChord("D", modifiers: [.command, .shift])
    public var language: SettingsLanguage = .chinese
    public var opening: OpeningPreference = .hold
    public var beatMilliseconds = 250
    public var showProjectNames = true
    public var notifications = NotificationPreferences()
    /// Reuse the dock's single ordering/visibility contract, including missing-ID reconnect behavior.
    public var subscriptions = DockSubscriptionPreferences()
    public var subscriptionSettings: [String: SubscriptionSetting] = [:]
    public var onboarding = OnboardingState()
    public init() {}

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case theme, size, motion, transparency, percentageMode, showPercentages, redBelow, sliverAlert
        case showDock, autoHide, revealMilliseconds, magnification, showOverFullscreen, followActiveDisplay
        case openAtLogin, automaticUpdates, menuDisplay, openShortcut, dockShortcut, language, opening, beatMilliseconds, showProjectNames
        case notifications, subscriptions, subscriptionSettings, onboarding, dockEdge, readerConsent, helpHints
    }
    /// Missing v1 choices adopt defaults; malformed preferences fail closed. Progress recovery is flow-owned.
    public init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) throws -> T {
            c.contains(key) ? try c.decode(T.self, forKey: key) : fallback
        }
        theme = try value(.theme, theme); size = try value(.size, size)
        motion = try value(.motion, motion); transparency = try value(.transparency, transparency)
        percentageMode = try value(.percentageMode, percentageMode); showPercentages = try value(.showPercentages, showPercentages)
        redBelow = try value(.redBelow, redBelow); sliverAlert = try value(.sliverAlert, sliverAlert)
        showDock = try value(.showDock, showDock); autoHide = try value(.autoHide, autoHide)
        revealMilliseconds = try value(.revealMilliseconds, revealMilliseconds); magnification = try value(.magnification, magnification)
        showOverFullscreen = try value(.showOverFullscreen, showOverFullscreen); followActiveDisplay = try value(.followActiveDisplay, followActiveDisplay)
        openAtLogin = try value(.openAtLogin, openAtLogin)
        automaticUpdates = try value(.automaticUpdates, automaticUpdates)
        menuDisplay = try value(.menuDisplay, menuDisplay); openShortcut = try value(.openShortcut, openShortcut)
        dockShortcut = try value(.dockShortcut, dockShortcut); language = try value(.language, language)
        opening = try value(.opening, opening); beatMilliseconds = try value(.beatMilliseconds, beatMilliseconds)
        showProjectNames = try value(.showProjectNames, showProjectNames); notifications = try value(.notifications, notifications)
        subscriptions = try value(.subscriptions, subscriptions); subscriptionSettings = try value(.subscriptionSettings, subscriptionSettings)
        onboarding = try value(.onboarding, onboarding)
        dockEdge = try value(.dockEdge, dockEdge); readerConsent = try value(.readerConsent, readerConsent)
        helpHints = try value(.helpHints, helpHints)
        try validate()
    }
    public func validate() throws {
        func validID(_ id: String) -> Bool { !id.isEmpty && id.utf8.count <= 256 && !id.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) }
        guard [10, 16, 20, 25].contains(redBelow), [100, 150, 300].contains(revealMilliseconds),
              [150, 200, 250].contains(beatMilliseconds), openShortcut.isValid, dockShortcut.isValid,
              openShortcut != dockShortcut, subscriptionSettings.count <= 1000, subscriptions.order.count <= 1000,
              subscriptions.hiddenIDs.count <= 1000, subscriptions.order.allSatisfy(validID),
              subscriptions.hiddenIDs.allSatisfy(validID), subscriptionSettings.allSatisfy({ id, value in
                  validID(id) && value.alias.count <= 128 && value.alias.utf8.count <= 1024 && !value.alias.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
              }) else { throw SettingsError.invalidPreference }
    }
}

public struct SettingsSnapshot: Sendable {
    public let revision: UInt64
    public let preferences: SettingsPreferences
}
private struct PreferenceEnvelope: Codable { let schemaVersion: Int; let preferences: SettingsPreferences }

/// Single-writer actor. A failed validation/read/write never changes the last committed in-memory value.
/// Give this one app-scoped instance an app-owned URL; do not open concurrent stores for the same file.
public actor SettingsStore {
    public static let maximumBytes = 256 * 1024
    private let url: URL
    let onboardingDefinition: OnboardingDefinition
    private var current: SettingsPreferences
    private var revision: UInt64 = 0
    public init(url: URL, onboardingDefinition: OnboardingDefinition = .task65) throws {
        self.url = url; self.onboardingDefinition = onboardingDefinition
        if FileManager.default.fileExists(atPath: url.path) {
            // Bound allocation before reading. A second bound detects growth during the read.
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            guard ((attributes[.size] as? NSNumber)?.intValue ?? Int.max) <= Self.maximumBytes else { throw SettingsError.tooLarge }
            guard attributes[.type] as? FileAttributeType == .typeRegular else { throw SettingsError.invalidPreference }
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            let data = try handle.read(upToCount: Self.maximumBytes + 1) ?? Data()
            guard data.count <= Self.maximumBytes else { throw SettingsError.tooLarge }
            let header = try JSONDecoder().decode(SchemaHeader.self, from: data)
            guard header.schemaVersion == 1 else { throw SettingsError.unsupportedSchema }
            current = try JSONDecoder().decode(PreferenceEnvelope.self, from: data).preferences
            try current.validate()
        } else { current = SettingsPreferences() }
        current.onboarding.reconcile(in: onboardingDefinition)
    }
    private struct SchemaHeader: Decodable { let schemaVersion: Int }
    public func snapshot() -> SettingsSnapshot { .init(revision: revision, preferences: current) }
    @discardableResult public func update(expectedRevision: UInt64? = nil,
        _ edit: @Sendable (inout SettingsPreferences) throws -> Void) throws -> SettingsSnapshot {
        if let expectedRevision, expectedRevision != revision { throw SettingsError.staleRevision }
        var candidate = current
        try edit(&candidate); candidate.onboarding.reconcile(in: onboardingDefinition); try candidate.validate()
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(PreferenceEnvelope(schemaVersion: 1, preferences: candidate))
        guard data.count <= Self.maximumBytes else { throw SettingsError.tooLarge }
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let stage = directory.appendingPathComponent(".settings-" + UUID().uuidString + ".tmp")
        defer { try? FileManager.default.removeItem(at: stage) }
        let descriptor = Darwin.open(stage.path, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, 0o600)
        guard descriptor >= 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        let writer = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        do { try writer.write(contentsOf: data); try writer.close() }
        catch { try? writer.close(); throw error }
        // All fallible preparation happens before atomic replacement; no post-commit chmod failure.
        guard Darwin.rename(stage.path, url.path) == 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        current = candidate; revision &+= 1
        return snapshot()
    }
}
