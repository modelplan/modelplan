// SPDX-License-Identifier: MIT
import Foundation
import Security
import LocalAuthentication
import CryptoKit
import ModelPlanWire

/// Requests cannot supply a service, account, executable or path. Two fixed items exist: Claude Code's
/// saved login, and (D380) ZCode 3.19+'s credential-store key, whose account ZCode derives itself from
/// its own credentials file under this user's home (zai-org/ZCode credential-security,
/// systemCredentialCipher.ts). The query only ever reads; this module has no write, update or delete call.
public struct FixedItemQuery: Sendable {
    public enum Item: Sendable, Equatable { case claude, zcode }
    public static let zcodeService = "ZCode Credential Encryption"
    public let interactive: Bool
    public let item: Item
    public let service: String
    /// nil for Claude (the service alone names it); ZCode's hex(sha256(credentials.json path)).
    public let account: String?
    public init(interactive: Bool) {
        self.interactive = interactive; item = .claude; service = "Claude Code-credentials"; account = nil
    }
    /// D380: ZCode's key item for `home`/.zcode/v2/credentials.json, the path ZCode itself resolves.
    public init(interactive: Bool, zcodeHome home: String) {
        self.interactive = interactive; item = .zcode; service = Self.zcodeService
        account = Self.zcodeAccount(home: home)
    }
    public static func zcodeAccount(home: String) -> String {
        let path = (home as NSString).appendingPathComponent(".zcode/v2/credentials.json")
        return SHA256.hash(data: Data(path.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    public var attributes: [String: Any] {
        let context = LAContext()
        context.interactionNotAllowed = !interactive
        var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                kSecReturnAttributes as String: true, kSecReturnPersistentRef as String: true,
                kSecMatchLimit as String: kSecMatchLimitAll,
                kSecUseAuthenticationContext as String: context]
        if let account { query[kSecAttrAccount as String] = account }
        return query
    }
    public func dataAttributes(persistentRef: Data) -> [String: Any] {
        let context = LAContext()
        context.interactionNotAllowed = !interactive
        return [kSecValuePersistentRef as String: persistentRef,
                kSecMatchLimit as String: kSecMatchLimitOne, kSecReturnData as String: true,
                kSecUseAuthenticationContext as String: context]
    }
}
public enum ItemReadTermination: Sendable {
    case canceled, timeout
    public var outcome: WireCredentialOutcome { self == .timeout ? .timeout : .canceled }
}
public struct ItemRead: Sendable {
    /// nil when the operation was stopped before another OS call was admitted.
    public let status: Int32?
    public let data: Data?
    public let termination: ItemReadTermination?
    public init(status: Int32, data: Data? = nil) { self.status = status; self.data = data; termination = nil }
    public init(termination: ItemReadTermination) { status = nil; data = nil; self.termination = termination }
}
public protocol FixedItemReading: Sendable {
    /// Runs on the bounded worker, never MainActor.
    func read(_ query: FixedItemQuery, authorize: @Sendable () -> ItemReadTermination?) -> ItemRead
}
/// Low-level seam for validating actual query dictionaries without a Keychain.
public struct ItemMatch {
    public let status: Int32
    public let value: Any?
    public init(status: Int32, value: Any? = nil) { self.status = status; self.value = value }
}
public protocol ItemMatching: Sendable {
    func copyMatching(_ attributes: [String: Any]) -> ItemMatch
}
public struct SystemItemMatcher: ItemMatching {
    public init() {}
    public func copyMatching(_ attributes: [String: Any]) -> ItemMatch {
        var value: CFTypeRef?
        let status = SecItemCopyMatching(attributes as CFDictionary, &value)
        return .init(status: status, value: value)
    }
}
/// Explicit backend. Construction never queries. Tests inject matching at this seam.
public struct SecurityItemReader: FixedItemReading {
    private let matcher: any ItemMatching
    public init(matcher: any ItemMatching = SystemItemMatcher()) { self.matcher = matcher }
    public func read(_ query: FixedItemQuery, authorize: @Sendable () -> ItemReadTermination?) -> ItemRead {
        // Password data is not a legal all-matches return. Enumerate only attributes/ref.
        if let stopped = authorize() { return .init(termination: stopped) }
        let enumeration = matcher.copyMatching(query.attributes)
        guard enumeration.status == errSecSuccess else { return .init(status: enumeration.status) }
        guard let items = enumeration.value as? [[String: Any]] else { return .init(status: errSecDecode) }
        guard !items.isEmpty else { return .init(status: errSecItemNotFound) }
        guard items.count == 1 else { return .init(status: errSecDuplicateItem) }
        guard let item = items.first, item[kSecAttrService as String] as? String == query.service,
              query.account == nil || item[kSecAttrAccount as String] as? String == query.account,
              let ref = item[kSecValuePersistentRef as String] as? Data,
              !ref.isEmpty, ref.count <= 4096 else { return .init(status: errSecDecode) }
        // Read exactly that reference; never select the first of multiple matches.
        if let stopped = authorize() { return .init(termination: stopped) }
        let result = matcher.copyMatching(query.dataAttributes(persistentRef: ref))
        guard result.status == errSecSuccess else { return .init(status: result.status) }
        guard let data = result.value as? Data, data.count <= 64 * 1024 else { return .init(status: errSecDecode) }
        return .init(status: errSecSuccess, data: data)
    }
}
public enum SecurityOutcome {
    public static func map(_ status: Int32) -> WireCredentialOutcome {
        switch status {
        case errSecSuccess: return .ok
        case errSecUserCanceled: return .canceled
        case errSecAuthFailed: return .denied
        case errSecItemNotFound: return .notFound
        case errSecInteractionNotAllowed: return .interactionRequired
        default: return .error
        }
    }
}
