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
                kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitAll,
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
/// Explicit backend. Construction never performs a query. Tests inject a fake instead.
public struct SecurityItemReader: FixedItemReading {
    public init() {}
    public func read(_ query: FixedItemQuery) -> ItemRead {
        var value: CFTypeRef?
        let status = SecItemCopyMatching(query.attributes as CFDictionary, &value)
        guard status == errSecSuccess else { return .init(status: status) }
        // An ambiguous fixed service must not silently select another profile's item.
        guard let items = value as? [Data], items.count == 1, let data = items.first,
              data.count <= 64 * 1024 else { return .init(status: errSecDecode) }
        return .init(status: status, data: data)
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
