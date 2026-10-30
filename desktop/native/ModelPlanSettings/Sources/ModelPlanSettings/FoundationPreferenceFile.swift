// SPDX-License-Identifier: MIT
import Foundation
import Darwin

/// The caller supplies its application-support root; no home discovery or account access.
public struct FoundationPreferenceLocation: Sendable {
    public let applicationSupport: URL
    public let product: FoundationSettingsMigration.ProductIdentity
    public var directory: URL { applicationSupport.appendingPathComponent("ModelPlan", isDirectory: true) }
    public var target: URL { directory.appendingPathComponent("settings.json") }
    public init(applicationSupport: URL, product: FoundationSettingsMigration.ProductIdentity) throws {
        guard applicationSupport.isFileURL, applicationSupport.path.hasPrefix("/") else {
            throw FoundationPreferenceError.invalidLocation
        }
        self.applicationSupport = applicationSupport.standardizedFileURL; self.product = product
    }
}
public enum FoundationPreferenceError: Error, Equatable {
    case invalidLocation, recoveryRequired, externalChange, busy, engineOwnedConsent, requiresFoundationStore, durabilityUncertain
}
public struct FoundationCorePreferences: Codable, Equatable, Sendable {
    public var localeIdentifier: String?
    public var favouriteModelIDs: [String]
    public var fieldPickerValue: Data?
    public init(localeIdentifier: String? = nil, favouriteModelIDs: [String] = [], fieldPickerValue: Data? = nil) {
        self.localeIdentifier = localeIdentifier; self.favouriteModelIDs = favouriteModelIDs; self.fieldPickerValue = fieldPickerValue
    }
}
public struct FoundationPreferenceStatus: Sendable {
    public let path: URL
    public let createdByMigration: Bool
    public let readOnlyRecovery: Bool
    public let selection: FoundationSettingsMigration.Selection?
    public let issues: [FoundationSettingsMigration.Issue]
}

/// Bounded file transactions used only by the app's one SettingsStore actor.
/// Bootstrap publishes a complete file with linkat (no replacement). Updates
/// serialize on a local lock and compare the previous bytes before replacement.
enum FoundationPreferenceFile {
    typealias Migration = FoundationSettingsMigration
    static let maximumBytes = SettingsStore.maximumBytes + 32768 + 1024
    struct Document {
        var settings: SettingsPreferences
        var core: FoundationCorePreferences
        static func decode(_ bytes: Data) throws -> Document {
            guard bytes.count <= maximumBytes else { throw Migration.Failure.tooLarge }
            let object: [String: Any]
            do {
                guard let value = try JSONSerialization.jsonObject(with: bytes) as? [String: Any] else { throw Migration.Failure.invalidPreferences }
                object = value
            } catch let error as Migration.Failure { throw error }
            catch { throw Migration.Failure.invalidJSON }
            struct Header: Decodable { let schemaVersion: Int }
            let header: Header
            do { header = try JSONDecoder().decode(Header.self, from: bytes) }
            catch { throw Migration.Failure.invalidPreferences }
            guard header.schemaVersion == 1 else { throw Migration.Failure.unsupportedSchema }
            guard var settings = object["settings"] as? [String: Any], let core = object["core"] as? [String: Any] else { throw Migration.Failure.invalidPreferences }
            // App-side legacy consent is never restored as an engine grant.
            settings.removeValue(forKey: "readerConsent")
            do {
                let settingsBytes = try JSONSerialization.data(withJSONObject: settings)
                let coreBytes = try JSONSerialization.data(withJSONObject: core)
                guard settingsBytes.count <= SettingsStore.maximumBytes, coreBytes.count <= 32768 else { throw Migration.Failure.tooLarge }
                let preferences = try JSONDecoder().decode(SettingsPreferences.self, from: settingsBytes)
                try preferences.validate()
                return .init(settings: preferences, core: try JSONDecoder().decode(FoundationCorePreferences.self, from: coreBytes))
            } catch let error as Migration.Failure { throw error }
            catch { throw Migration.Failure.invalidPreferences }
        }
        func encoded() throws -> Data {
            try settings.validate()
            guard settings.readerConsent == ReaderConsent() else { throw FoundationPreferenceError.engineOwnedConsent }
            guard var values = try JSONSerialization.jsonObject(with: JSONEncoder().encode(settings)) as? [String: Any]
            else { throw Migration.Failure.invalidPreferences }
            values.removeValue(forKey: "readerConsent")
            let settingsBytes = try JSONSerialization.data(withJSONObject: values)
            let coreBytes = try JSONEncoder().encode(core)
            guard settingsBytes.count <= SettingsStore.maximumBytes, coreBytes.count <= 32768 else { throw Migration.Failure.tooLarge }
            let data = try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "settings": values,
                "core": JSONSerialization.jsonObject(with: coreBytes)], options: [.sortedKeys])
            guard data.count <= maximumBytes else { throw Migration.Failure.tooLarge }
            return data
        }
    }
    struct DirectoryIdentity: Equatable { let device: dev_t; let inode: ino_t }
    struct Opened {
        let location: FoundationPreferenceLocation
        var document: Document
        var bytes: Data
        let directoryIdentity: DirectoryIdentity?
        var writeBlocked: Bool
        let status: FoundationPreferenceStatus
    }
    struct Hooks {
        var onLegacyRead: ((Migration.Source) -> Void)?
        var beforePublish: (() throws -> Void)?
    }
    private enum Read { case absent, bytes(Data), invalid(Migration.Failure) }
    private static func posix() -> NSError { .init(domain: NSPOSIXErrorDomain, code: Int(errno)) }
    private static func identity(_ fd: Int32) throws -> DirectoryIdentity {
        var value = stat(); guard fstat(fd, &value) == 0 else { throw posix() }
        return .init(device: value.st_dev, inode: value.st_ino)
    }
    private static func directory(_ location: FoundationPreferenceLocation, create: Bool) throws -> Int32? {
        if create { try FileManager.default.createDirectory(at: location.directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700]) }
        let fd = Darwin.open(location.directory.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        if fd < 0 {
            if !create && errno == ENOENT { return nil }
            throw FoundationPreferenceError.invalidLocation
        }
        return fd
    }
    private static func read(_ parent: Int32, _ name: String, limit: Int) -> Read {
        let fd = openat(parent, name, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        if fd < 0 { return errno == ENOENT ? .absent : .invalid(.unreadable) }
        defer { Darwin.close(fd) }
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_mode & S_IFMT == S_IFREG else { return .invalid(.unreadable) }
        guard info.st_size >= 0, info.st_size <= Int64(limit) else { return .invalid(.tooLarge) }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: false)
        do {
            let bytes = try handle.read(upToCount: limit + 1) ?? Data()
            return bytes.count <= limit ? .bytes(bytes) : .invalid(.tooLarge)
        } catch { return .invalid(.unreadable) }
    }
    private static func existing(_ read: Read, location: FoundationPreferenceLocation, identity: DirectoryIdentity?) throws -> Opened? {
        switch read {
        case .absent: return nil
        case .bytes(let bytes):
            do {
                let doc = try Document.decode(bytes)
                return .init(location: location, document: doc, bytes: bytes, directoryIdentity: identity, writeBlocked: false,
                    status: .init(path: location.target, createdByMigration: false, readOnlyRecovery: false, selection: nil, issues: []))
            } catch { return try recovery(location, failure: (error as? Migration.Failure) ?? .invalidPreferences) }
        case .invalid(let failure): return try recovery(location, failure: failure)
        }
    }
    private static func recovery(_ location: FoundationPreferenceLocation, failure: Migration.Failure) throws -> Opened {
        let decision = try Migration.prepare(product: location.product, target: .invalid(failure), legacy: { preconditionFailure("existing targets never read legacy") })
        guard case .blocked(let candidate) = decision else { preconditionFailure("expected recovery candidate") }
        return .init(location: location, document: try Document.decode(candidate.document), bytes: candidate.document, directoryIdentity: nil, writeBlocked: true,
            status: .init(path: location.target, createdByMigration: false, readOnlyRecovery: true, selection: candidate.selection, issues: candidate.issues))
    }
    private static func legacy(_ parent: Int32, group: String, name: String, limit: Int) -> Migration.Input {
        let fd = openat(parent, group, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        if fd < 0 { return errno == ENOENT ? .absent : .failed(.unreadable) }
        defer { Darwin.close(fd) }
        switch read(fd, name, limit: limit) {
        case .absent: return .absent
        case .bytes(let bytes): return .data(bytes)
        case .invalid(let failure): return .failed(failure)
        }
    }
    private static func locked<T>(_ fd: Int32, _ body: () throws -> T) throws -> T {
        let lock = openat(fd, ".settings.lock", O_RDWR | O_CREAT | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard lock >= 0 else { throw posix() }; defer { Darwin.close(lock) }
        var info = stat()
        guard fstat(lock, &info) == 0, info.st_mode & S_IFMT == S_IFREG else { throw FoundationPreferenceError.invalidLocation }
        guard flock(lock, LOCK_EX | LOCK_NB) == 0 else { throw FoundationPreferenceError.busy }
        defer { _ = flock(lock, LOCK_UN) }
        return try body()
    }
    private static func stage(_ bytes: Data, in parent: Int32) throws -> String {
        let name = ".settings-" + UUID().uuidString + ".tmp"
        let fd = openat(parent, name, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw posix() }; defer { Darwin.close(fd) }
        do {
            try bytes.withUnsafeBytes { buffer in
                var offset = 0
                while offset < buffer.count {
                    let count = Darwin.write(fd, buffer.baseAddress!.advanced(by: offset), buffer.count - offset)
                    if count < 0 && errno == EINTR { continue }
                    guard count > 0 else { throw posix() }
                    offset += count
                }
            }
            guard fsync(fd) == 0 else { throw posix() }
            return name
        } catch { _ = unlinkat(parent, name, 0); throw error }
    }
    static func open(_ location: FoundationPreferenceLocation, rowIDMap: [String: String] = [:], hooks: Hooks = .init()) throws -> Opened {
        if let fd = try directory(location, create: false) {
            defer { Darwin.close(fd) }
            if let value = try existing(read(fd, "settings.json", limit: maximumBytes), location: location, identity: identity(fd)) { return value }
        }
        let fd = try directory(location, create: true)!; defer { Darwin.close(fd) }
        return try locked(fd) {
            let id = try identity(fd)
            if let value = try existing(read(fd, "settings.json", limit: maximumBytes), location: location, identity: id) { return value }
            let decision = try Migration.prepare(product: location.product, target: .absent, legacy: {
                hooks.onLegacyRead?(.officialSettings)
                let official = legacy(fd, group: "Beta07", name: "settings-v1.json", limit: SettingsStore.maximumBytes)
                hooks.onLegacyRead?(.communitySettings)
                let community = legacy(fd, group: "Native", name: "settings-v1.json", limit: SettingsStore.maximumBytes)
                hooks.onLegacyRead?(.communityCore)
                let core = legacy(fd, group: "Native", name: "community-v1.json", limit: 32768)
                return .init(officialSettings: official, communitySettings: community, core: core)
            }, rowIDMap: rowIDMap)
            guard case .create(let candidate) = decision else { preconditionFailure("absent target must create") }
            let document = try Document.decode(candidate.document)
            let temporary = try stage(candidate.document, in: fd); defer { _ = unlinkat(fd, temporary, 0) }
            try hooks.beforePublish?()
            guard linkat(fd, temporary, fd, "settings.json", 0) == 0 else {
                if errno == EEXIST, let winner = try existing(read(fd, "settings.json", limit: maximumBytes), location: location, identity: id) { return winner }
                throw posix()
            }
            guard fsync(fd) == 0 else { throw FoundationPreferenceError.durabilityUncertain }
            return .init(location: location, document: document, bytes: candidate.document, directoryIdentity: id, writeBlocked: false,
                status: .init(path: location.target, createdByMigration: true, readOnlyRecovery: false, selection: candidate.selection, issues: candidate.issues))
        }
    }
    static func replace(_ bytes: Data, expected: Opened) throws {
        guard !expected.writeBlocked else { throw FoundationPreferenceError.recoveryRequired }
        guard let fd = try directory(expected.location, create: false) else { throw FoundationPreferenceError.externalChange }
        defer { Darwin.close(fd) }
        guard try identity(fd) == expected.directoryIdentity else { throw FoundationPreferenceError.externalChange }
        try locked(fd) {
            guard case .bytes(let current) = read(fd, "settings.json", limit: maximumBytes), current == expected.bytes else { throw FoundationPreferenceError.externalChange }
            let temporary = try stage(bytes, in: fd); defer { _ = unlinkat(fd, temporary, 0) }
            guard renameat(fd, temporary, fd, "settings.json") == 0 else { throw posix() }
            guard fsync(fd) == 0 else { throw FoundationPreferenceError.durabilityUncertain }
        }
    }
}
