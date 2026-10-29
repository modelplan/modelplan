// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanDock

/// Pure preference migration planning. The caller owns bounded reads and the only store/writer.
public enum FoundationSettingsMigration {
    public enum ProductIdentity: Sendable { case official, community }
    public enum Failure: Error, Equatable, Sendable {
        case unreadable, tooLarge, unsupportedSchema, invalidJSON, invalidPreferences, invalidEdge, ambiguousRowMapping
    }
    public enum Input: Sendable { case absent, data(Data), failed(Failure) }
    /// The one new-store owner checks existence, type, bounds and its schema before calling.
    /// No legacy source is needed when that target exists; invalid targets are never repaired here.
    public enum TargetState: Sendable { case absent, present, invalid(Failure) }
    public enum Source: String, Equatable, Sendable { case officialSettings, communitySettings, communityCore, defaults, newSettings }
    public struct Issue: Equatable, Sendable {
        public let source: Source
        public let failure: Failure
        public init(source: Source, failure: Failure) { self.source = source; self.failure = failure }
    }
    public struct LegacyInputs: Sendable {
        public let officialSettings: Input, communitySettings: Input, core: Input
        public init(officialSettings: Input = .absent, communitySettings: Input = .absent, core: Input = .absent) {
            self.officialSettings = officialSettings; self.communitySettings = communitySettings; self.core = core
        }
    }
    public struct Selection: Equatable, Sendable {
        public let settings: Source, core: Source
    }
    public struct Candidate: Sendable {
        /// Versioned settings/core document; never contains readerConsent.
        public let document: Data
        public let selection: Selection
        public let issues: [Issue]
    }
    /// Advisory decisions only. The caller may persist only create, under its own atomic no-replace lock.
    /// A blocked fallback is for in-memory recovery and must never overwrite the existing target.
    public enum Decision: Sendable {
        case keepExisting
        case blocked(fallback: Candidate)
        case create(Candidate)
    }
    public static func prepare(product: ProductIdentity, target: TargetState,
                               legacy: () -> LegacyInputs, rowIDMap: [String: String] = [:]) throws -> Decision {
        switch target {
        case .present: return .keepExisting
        case .invalid(let failure):
            return .blocked(fallback: try candidate(settings: SettingsPreferences(), core: ["favouriteModelIDs": [String]()],
                selection: .init(settings: .defaults, core: .defaults), issues: [.init(source: .newSettings, failure: failure)]))
        case .absent: break
        }
        let inputs = legacy()
        var settings = SettingsPreferences(), settingsSource = Source.defaults, issues: [Issue] = []
        let sources: [(Source, Input)] = product == .official
            ? [(.officialSettings, inputs.officialSettings), (.communitySettings, inputs.communitySettings)]
            : [(.communitySettings, inputs.communitySettings), (.officialSettings, inputs.officialSettings)]
        for (source, input) in sources {
            do {
                if let loaded = try loadSettings(input) {
                    settings = loaded.preferences; settingsSource = source
                    if loaded.edgeDefaulted { issues.append(.init(source: source, failure: .invalidEdge)) }
                    break
                }
            } catch { issues.append(.init(source: source, failure: (error as? Failure) ?? .invalidPreferences)) }
        }
        var core: [String: Any] = ["favouriteModelIDs": [String]()], coreSource = Source.defaults
        do { if let loaded = try loadCore(inputs.core) { core = loaded; coreSource = .communityCore } }
        catch { issues.append(.init(source: .communityCore, failure: (error as? Failure) ?? .invalidPreferences)) }
        if remapRows(in: &settings, using: rowIDMap) {
            issues.append(.init(source: settingsSource, failure: .ambiguousRowMapping))
        }
        return .create(try candidate(settings: settings, core: core,
            selection: .init(settings: settingsSource, core: coreSource), issues: issues))
    }
    /// Only explicit, injective mappings may replace a persisted id. Occupied targets stay untouched.
    private static func remapRows(in settings: inout SettingsPreferences, using map: [String: String]) -> Bool {
        let ids = Set(settings.subscriptions.order).union(settings.subscriptions.hiddenIDs).union(settings.subscriptionSettings.keys)
        var accepted: [String: String] = [:], rejected = false
        for id in ids {
            guard let target = map[id], target != id else { continue }
            guard !target.isEmpty, target.utf8.count <= 256,
                  !target.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) else { rejected = true; continue }
            accepted[id] = target
        }
        for group in Dictionary(grouping: accepted, by: { $0.value }).values where group.count > 1 {
            for entry in group { accepted.removeValue(forKey: entry.key) }; rejected = true
        }
        // A rejected predecessor is now an occupied id too; resolve until no mapping can clobber it.
        while true {
            let occupied = ids.subtracting(accepted.keys)
            let conflicts = accepted.filter { occupied.contains($0.value) }.map(\.key)
            if conflicts.isEmpty { break }
            for id in conflicts { accepted.removeValue(forKey: id) }; rejected = true
        }
        settings.subscriptions = .init(order: settings.subscriptions.order.map { accepted[$0] ?? $0 },
            hiddenIDs: Set(settings.subscriptions.hiddenIDs.map { accepted[$0] ?? $0 }))
        var overrides: [String: SubscriptionSetting] = [:]
        for (id, value) in settings.subscriptionSettings { overrides[accepted[id] ?? id] = value }
        settings.subscriptionSettings = overrides
        return rejected
    }
    private struct SchemaHeader: Decodable { let schemaVersion: Int }
    private struct CoreEnvelope: Codable {
        let schemaVersion: Int
        let localeIdentifier: String?
        let favouriteModelIDs: [String]
        let fieldPickerValue: Data?
    }
    private static func bytes(_ input: Input, limit: Int) throws -> Data? {
        switch input {
        case .absent: return nil
        case .failed(let failure): throw failure
        case .data(let data):
            guard data.count <= limit else { throw Failure.tooLarge }
            return data
        }
    }
    private static func legacyObject(_ data: Data) throws -> [String: Any] {
        let object: Any
        do { object = try JSONSerialization.jsonObject(with: data) }
        catch { throw Failure.invalidJSON }
        guard let envelope = object as? [String: Any] else { throw Failure.invalidPreferences }
        let header = try JSONDecoder().decode(SchemaHeader.self, from: data)
        guard header.schemaVersion == 1 else { throw Failure.unsupportedSchema }
        return envelope
    }
    private static func loadSettings(_ input: Input) throws -> (preferences: SettingsPreferences, edgeDefaulted: Bool)? {
        guard let data = try bytes(input, limit: SettingsStore.maximumBytes) else { return nil }
        let envelope = try legacyObject(data)
        guard var values = envelope["preferences"] as? [String: Any] else { throw Failure.invalidPreferences }
        let edgeDefaulted: Bool
        if let value = values["dockEdge"] {
            edgeDefaulted = (value as? String).flatMap(SettingsDockEdge.init(rawValue:)) == nil
            if edgeDefaulted { values["dockEdge"] = "right" }
        } else { edgeDefaulted = false }
        let preferences = try JSONDecoder().decode(SettingsPreferences.self, from: JSONSerialization.data(withJSONObject: values))
        return (preferences, edgeDefaulted)
    }
    private static func loadCore(_ input: Input) throws -> [String: Any]? {
        guard let data = try bytes(input, limit: 32768) else { return nil }
        _ = try legacyObject(data)
        let value = try JSONDecoder().decode(CoreEnvelope.self, from: data)
        guard var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any]
        else { throw Failure.invalidPreferences }
        object.removeValue(forKey: "schemaVersion")
        return object
    }
    // Freeze the app-owned migration contract; future Settings fields do not silently gain migration.
    private static let migratedSettingsFields: Set<String> = [
        "theme", "size", "motion", "transparency", "percentageMode", "showPercentages", "redBelow", "sliverAlert",
        "showDock", "autoHide", "revealMilliseconds", "magnification", "showOverFullscreen", "followActiveDisplay",
        "dockEdge", "dockDisplayID", "dockAlongFraction", "openAtLogin", "automaticUpdates", "menuDisplay",
        "openShortcut", "dockShortcut", "language", "opening", "beatMilliseconds", "showProjectNames",
        "notifications", "subscriptions", "subscriptionSettings", "onboarding", "helpHints"
    ]
    private static func candidate(settings: SettingsPreferences, core: [String: Any],
                                  selection: Selection, issues: [Issue]) throws -> Candidate {
        guard var values = try JSONSerialization.jsonObject(with: JSONEncoder().encode(settings)) as? [String: Any]
        else { throw Failure.invalidPreferences }
        values = values.filter { migratedSettingsFields.contains($0.key) }
        let data = try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "settings": values, "core": core], options: [.sortedKeys])
        return .init(document: data, selection: selection, issues: issues)
    }
}
