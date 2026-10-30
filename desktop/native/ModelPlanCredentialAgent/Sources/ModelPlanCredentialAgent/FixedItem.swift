// SPDX-License-Identifier: MIT
import Foundation
import Security
import LocalAuthentication
import ModelPlanWire

/// Requests cannot supply a service, account, executable or path.
public struct FixedItemQuery: Sendable {
    public let interactive: Bool
    public let service = "Claude Code-credentials"
    public init(interactive: Bool) { self.interactive = interactive }
    public var attributes: [String: Any] {
        let context = LAContext()
        context.interactionNotAllowed = !interactive
        return [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                kSecReturnAttributes as String: true, kSecReturnPersistentRef as String: true,
                kSecMatchLimit as String: kSecMatchLimitAll,
                kSecUseAuthenticationContext as String: context]
    }
    public func dataAttributes(persistentRef: Data) -> [String: Any] {
        let context = LAContext()
        context.interactionNotAllowed = !interactive
        return [kSecValuePersistentRef as String: persistentRef,
                kSecMatchLimit as String: kSecMatchLimitOne, kSecReturnData as String: true,
                kSecUseAuthenticationContext as String: context]
    }
}
public struct ItemRead: Sendable {
    public let status: Int32
    public let data: Data?
    public init(status: Int32, data: Data? = nil) { self.status = status; self.data = data }
}
public protocol FixedItemReading: Sendable {
    /// Runs on the bounded worker, never MainActor.
    func read(_ query: FixedItemQuery) -> ItemRead
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
    public func read(_ query: FixedItemQuery) -> ItemRead {
        // Password data is not a legal all-matches return. Enumerate only attributes/ref.
        let enumeration = matcher.copyMatching(query.attributes)
        guard enumeration.status == errSecSuccess else { return .init(status: enumeration.status) }
        guard let items = enumeration.value as? [[String: Any]] else { return .init(status: errSecDecode) }
        guard !items.isEmpty else { return .init(status: errSecItemNotFound) }
        guard items.count == 1 else { return .init(status: errSecDuplicateItem) }
        guard let item = items.first, item[kSecAttrService as String] as? String == query.service,
              let ref = item[kSecValuePersistentRef as String] as? Data,
              !ref.isEmpty, ref.count <= 4096 else { return .init(status: errSecDecode) }
        // Read exactly that reference; never select the first of multiple matches.
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
