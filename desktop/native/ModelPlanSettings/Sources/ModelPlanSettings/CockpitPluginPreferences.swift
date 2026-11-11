// SPDX-License-Identifier: MIT
import Foundation

/// v1.1 cockpit plugin columns (owner D121, D124, D126, D127): which plugins are on, their order, which are pinned
/// to the engine table's first page (at most two), and per-plugin settings such as a sampling interval (3–30 s).
/// The cockpit page applies the same rules (desktop/cockpit/src/plugin-state.ts); the JSON shape below is the
/// bridge's `plugins` message body and the page's `pluginsEdit` action body (desktop/cockpit/README.md, "Plugin
/// columns"). The page also reports `pluginsRunning` ids; the app samples only those, at the plugin's interval. The catalogue mirrors the page registry
/// (desktop/cockpit/src/plugin-registry.ts); tests/cockpit/unit/plugins.test.mjs checks the two agree.
public struct CockpitPluginSettingSpec: Equatable, Sendable {
    public let key: String
    public let minimum: Int
    public let maximum: Int
    public let defaultValue: Int
    public let title: SettingsText
    public init(key: String, minimum: Int, maximum: Int, defaultValue: Int, title: SettingsText) {
        self.key = key; self.minimum = minimum; self.maximum = maximum; self.defaultValue = defaultValue; self.title = title
    }
}
public struct CockpitPluginDefinition: Equatable, Sendable {
    public let id: String
    public let title: SettingsText
    public let defaultEnabled: Bool
    public let settings: [CockpitPluginSettingSpec]
    public init(id: String, title: SettingsText, defaultEnabled: Bool, settings: [CockpitPluginSettingSpec]) {
        self.id = id; self.title = title; self.defaultEnabled = defaultEnabled; self.settings = settings
    }
}
public enum CockpitPluginCatalogue {
    public static let maximumPinned = 2
    public static let maximumEntries = 32
    /// The framework placeholder (off by default) until the resource (D124) and cost (D126/D127) plugins land, then the calendar.
    public static let builtIn: [CockpitPluginDefinition] = [
        CockpitPluginDefinition(id: "placeholder", title: .init("Placeholder", "占位插件"), defaultEnabled: false, settings: [
            CockpitPluginSettingSpec(key: "intervalSeconds", minimum: 3, maximum: 30, defaultValue: 10, title: .init("Update interval", "更新间隔")),
        ]),
        /// v1.1 calendar (D137/D138/D140/D141/D145, CKP-PLG-06/07): default on; no settings. The page shapes its data from
        /// the display data the app already sends, so the app samples nothing for it.
        CockpitPluginDefinition(id: "calendar", title: .init("Calendar", "日历"), defaultEnabled: true, settings: []),
    ]
    private static let lower: ClosedRange<Unicode.Scalar> = "a"..."z"
    private static let upper: ClosedRange<Unicode.Scalar> = "A"..."Z"
    private static let digit: ClosedRange<Unicode.Scalar> = "0"..."9"
    static func validID(_ id: String) -> Bool {
        let scalars = Array(id.unicodeScalars)
        guard let first = scalars.first, scalars.count <= 32, lower.contains(first) else { return false }
        return scalars.allSatisfy { scalar in lower.contains(scalar) || digit.contains(scalar) || scalar == "-" }
    }
    static func validSettingKey(_ key: String) -> Bool {
        let scalars = Array(key.unicodeScalars)
        guard let first = scalars.first, scalars.count <= 32, lower.contains(first) || upper.contains(first) else { return false }
        return scalars.allSatisfy { scalar in lower.contains(scalar) || upper.contains(scalar) || digit.contains(scalar) }
    }
}

public struct CockpitPluginEntry: Codable, Equatable, Sendable {
    public var id: String
    public var enabled: Bool
    public var pinned: Bool
    public init(id: String, enabled: Bool, pinned: Bool) { self.id = id; self.enabled = enabled; self.pinned = pinned }
}

public enum CockpitPluginEdit: Equatable, Sendable {
    case setEnabled(String, Bool)
    case setPinned(String, Bool)
    /// -1 earlier, +1 later in the order.
    case move(String, Int)
    case setSetting(String, String, Int)
}

public struct CockpitPluginPreferences: Codable, Equatable, Sendable {
    public var version = 1
    /// User order. Ids this build does not know (from a newer build) are kept so a round trip never drops them.
    public var entries: [CockpitPluginEntry] = []
    public var settings: [String: [String: Int]] = [:]
    public init() {}
    private enum CodingKeys: String, CodingKey { case version, entries, settings }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decode(Int.self, forKey: .version)
        entries = try c.decode([CockpitPluginEntry].self, forKey: .entries)
        settings = try c.decode([String: [String: Int]].self, forKey: .settings)
        try validate()
    }

    public func validate() throws {
        var ids = Set<String>()
        guard version == 1, entries.count <= CockpitPluginCatalogue.maximumEntries,
              entries.filter(\.pinned).count <= CockpitPluginCatalogue.maximumPinned,
              settings.count <= CockpitPluginCatalogue.maximumEntries else { throw SettingsError.invalidPreference }
        for entry in entries {
            guard CockpitPluginCatalogue.validID(entry.id), ids.insert(entry.id).inserted, !entry.pinned || entry.enabled else {
                throw SettingsError.invalidPreference
            }
        }
        for (id, values) in settings {
            guard CockpitPluginCatalogue.validID(id), values.count <= 8,
                  values.allSatisfy({ CockpitPluginCatalogue.validSettingKey($0.key) && (0...86_400).contains($0.value) }) else {
                throw SettingsError.invalidPreference
            }
        }
    }

    /// Every catalogued plugin has an entry: missing ones are appended in catalogue order with their default.
    public func materialized(_ catalogue: [CockpitPluginDefinition] = CockpitPluginCatalogue.builtIn) -> CockpitPluginPreferences {
        var copy = self
        let known = Set(entries.map(\.id))
        for plugin in catalogue where !known.contains(plugin.id) {
            copy.entries.append(.init(id: plugin.id, enabled: plugin.defaultEnabled, pinned: false))
        }
        return copy
    }
    /// The catalogued plugins that are on, in user order.
    public func enabledIDs(_ catalogue: [CockpitPluginDefinition] = CockpitPluginCatalogue.builtIn) -> [String] {
        let known = Set(catalogue.map(\.id))
        return materialized(catalogue).entries.filter { $0.enabled && known.contains($0.id) }.map(\.id)
    }
    /// A saved value inside the spec's range, else the default.
    public func value(_ id: String, _ key: String, _ catalogue: [CockpitPluginDefinition] = CockpitPluginCatalogue.builtIn) -> Int? {
        guard let spec = catalogue.first(where: { $0.id == id })?.settings.first(where: { $0.key == key }) else { return nil }
        if let saved = settings[id]?[key], (spec.minimum...spec.maximum).contains(saved) { return saved }
        return spec.defaultValue
    }
    /// Whether a pin can be added for `id` right now (on, and fewer than two others pinned).
    public func canPin(_ id: String, _ catalogue: [CockpitPluginDefinition] = CockpitPluginCatalogue.builtIn) -> Bool {
        let full = materialized(catalogue)
        guard let entry = full.entries.first(where: { $0.id == id }), entry.enabled else { return false }
        return full.entries.filter { $0.pinned && $0.id != id }.count < CockpitPluginCatalogue.maximumPinned
    }

    /// Applies one edit by the page's rules. Returns false (and leaves self unchanged) when the edit is refused.
    @discardableResult
    public mutating func apply(_ edit: CockpitPluginEdit, _ catalogue: [CockpitPluginDefinition] = CockpitPluginCatalogue.builtIn) -> Bool {
        var next = materialized(catalogue)
        switch edit {
        case let .setEnabled(id, on):
            guard catalogue.contains(where: { $0.id == id }) || !on,
                  let i = next.entries.firstIndex(where: { $0.id == id }) else { return false }
            next.entries[i].enabled = on
            if !on { next.entries[i].pinned = false }
        case let .setPinned(id, pinned):
            guard let i = next.entries.firstIndex(where: { $0.id == id }), !pinned || next.canPin(id, catalogue) else { return false }
            next.entries[i].pinned = pinned
        case let .move(id, step):
            guard step == -1 || step == 1, let i = next.entries.firstIndex(where: { $0.id == id }),
                  next.entries.indices.contains(i + step) else { return false }
            next.entries.swapAt(i, i + step)
        case let .setSetting(id, key, value):
            guard let spec = catalogue.first(where: { $0.id == id })?.settings.first(where: { $0.key == key }),
                  (spec.minimum...spec.maximum).contains(value) else { return false }
            next.settings[id, default: [:]][key] = value
        }
        guard (try? next.validate()) != nil else { return false }
        self = next
        return true
    }

    /// The bridge body (sorted keys), sent to the page as `{"type":"plugins","plugins":<this>}`.
    public func bridgeJSON() throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }
    /// A page `pluginsEdit` body, already parsed by JSONSerialization. Fails closed on any unexpected shape.
    public static func fromPage(_ object: Any) throws -> CockpitPluginPreferences {
        guard let dictionary = object as? [String: Any], Set(dictionary.keys) == ["version", "entries", "settings"],
              let entries = dictionary["entries"] as? [Any],
              entries.allSatisfy({ item in
                  guard let entry = item as? [String: Any] else { return false }
                  return Set(entry.keys) == ["id", "enabled", "pinned"]
              }),
              JSONSerialization.isValidJSONObject(dictionary) else { throw SettingsError.invalidPreference }
        let data = try JSONSerialization.data(withJSONObject: dictionary)
        return try JSONDecoder().decode(CockpitPluginPreferences.self, from: data)
    }
}

/// Small file beside the settings file (`SettingsStore.directory`), so plugin choices never rewrite the main
/// preferences document. A missing or unreadable file means defaults; it is replaced only on the next edit.
public actor CockpitPluginStore {
    public static let fileName = "cockpit-plugins.json"
    public static let maximumBytes = 64 * 1024
    private let url: URL
    private var current: CockpitPluginPreferences
    public init(directory: URL) {
        url = directory.appendingPathComponent(Self.fileName)
        current = Self.read(url) ?? CockpitPluginPreferences()
    }
    private static func read(_ url: URL) -> CockpitPluginPreferences? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              attributes[.type] as? FileAttributeType == .typeRegular,
              ((attributes[.size] as? NSNumber)?.intValue ?? Int.max) <= maximumBytes,
              let data = try? Data(contentsOf: url), data.count <= maximumBytes else { return nil }
        return try? JSONDecoder().decode(CockpitPluginPreferences.self, from: data)
    }
    public func snapshot() -> CockpitPluginPreferences { current }
    public func save(_ preferences: CockpitPluginPreferences) throws {
        try preferences.validate()
        let data = try preferences.bridgeJSON()
        guard data.count <= Self.maximumBytes else { throw SettingsError.tooLarge }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        try data.write(to: url, options: [.atomic])
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        current = preferences
    }
}

/// What the Settings section and the cockpit bridge share: one current value, saved through the store, with a
/// callback the app uses to send the new state to an open cockpit page.
@MainActor public final class CockpitPluginSettingsModel {
    public let catalogue: [CockpitPluginDefinition]
    public private(set) var preferences: CockpitPluginPreferences
    private let store: CockpitPluginStore?
    /// Called after every committed change (from Settings or from the page) with the new value.
    public var onChange: ((CockpitPluginPreferences) -> Void)?
    public init(preferences: CockpitPluginPreferences = .init(), store: CockpitPluginStore? = nil,
                catalogue: [CockpitPluginDefinition] = CockpitPluginCatalogue.builtIn) {
        self.preferences = preferences; self.store = store; self.catalogue = catalogue
    }
    public static func load(from store: CockpitPluginStore) async -> CockpitPluginSettingsModel {
        CockpitPluginSettingsModel(preferences: await store.snapshot(), store: store)
    }
    /// A Settings edit. Returns false when refused (e.g. a third pin) or when saving failed; nothing changes then.
    @discardableResult public func perform(_ edit: CockpitPluginEdit) async -> Bool {
        var next = preferences
        guard next.apply(edit, catalogue) else { return false }
        return await commit(next)
    }
    /// A page `pluginsEdit` body; the page already applied the same rules.
    @discardableResult public func acceptPageEdit(_ object: Any) async -> Bool {
        guard let next = try? CockpitPluginPreferences.fromPage(object) else { return false }
        return await commit(next)
    }
    private func commit(_ next: CockpitPluginPreferences) async -> Bool {
        do { try await store?.save(next) } catch { return false }
        preferences = next; onChange?(next); return true
    }
}
