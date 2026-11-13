// SPDX-License-Identifier: MIT
import Foundation

public struct CommunityPreferences: Codable, Equatable, Sendable {
    public var schemaVersion = 1
    public var localeIdentifier: String? = nil
    public var favouriteModelIDs: [String] = []
    /// Public model IDs and field-local preset only; optional for existing v1 files.
    public var fieldPickerValue: Data? = nil
    public init() {}
}
/// App-owned UI preferences only. Never stores credentials, raw CLI output or personal history.
public struct PreferenceFile {
    public let url: URL
    public init(url: URL) { self.url = url }
    public func load() throws -> CommunityPreferences {
        guard FileManager.default.fileExists(atPath: url.path) else { return CommunityPreferences() }
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        guard data.count <= 32768 else { throw FeedError.tooLarge }
        let value = try JSONDecoder().decode(CommunityPreferences.self, from: data)
        guard value.schemaVersion == 1 else { throw FeedError.unsupportedSchema }
        return value
    }
    public func save(_ value: CommunityPreferences) throws {
        let data = try JSONEncoder().encode(value)
        guard data.count <= 32768, value.schemaVersion == 1 else { throw FeedError.tooLarge }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}

public enum NativeWindowRole: CaseIterable, Sendable {
    case dock, sliver, hoverCard, cockpit, pinnedCard, overflow, field, settings, onboarding
    public var canBecomeMain: Bool { self == .settings || self == .onboarding }
    public var canBecomeKeyOnExplicitEntry: Bool { self != .dock && self != .sliver && self != .hoverCard }
    public var floats: Bool { !canBecomeMain }
}
