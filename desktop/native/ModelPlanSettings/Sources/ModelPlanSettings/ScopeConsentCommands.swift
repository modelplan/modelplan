// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanEngineClient
import ModelPlanWire

/// App-owned gestures, never a wire schema or an authorization record.
public enum ScopeConsentMutation: Sendable, Equatable {
    case allow(scopes: [String], keychain: [String])
    case revoke(scope: String)
    case forget(scope: String)
    /// G3-45: the first-run choices, sent once on Done through the same grant request:
    /// checked tools are allowed, unchecked ones refused.
    case choose(allow: [String], deny: [String], keychain: [String])
}
public struct ScopeConsentIntent: Sendable, Equatable {
    public let requestID: String
    public let mutation: ScopeConsentMutation
    public init(requestID: String = UUID().uuidString, mutation: ScopeConsentMutation) {
        self.requestID = requestID; self.mutation = mutation
    }
    public var allowIDs: [String] {
        switch mutation { case .allow(let ids, _), .choose(let ids, _, _): return ids.sorted(); default: return [] }
    }
    public var denyIDs: [String] {
        switch mutation { case .revoke(let id): return [id]; case .choose(_, let ids, _): return ids.sorted(); default: return [] }
    }
    public var forgetIDs: [String] { if case .forget(let id) = mutation { return [id] }; return [] }
    public var keychainIDs: [String] {
        switch mutation { case .allow(_, let ids), .choose(_, _, let ids): return ids.sorted(); default: return [] }
    }
}
// The client factory constructs wire parameters from its live accepted context.
extension ScopeConsentIntent: EngineConsentGrantIntent {}

public enum ScopeConsentCommandFailure: Error, Sendable { case notReady, missingMetadata, intentMismatch }
@MainActor public protocol ScopeConsentCommands: AnyObject {
    var isReady: Bool { get }
    var canMutate: Bool { get }
    func grant(_ intent: ScopeConsentIntent, userAction: EngineUserAction) async throws -> EngineRequestCompletion
    func inspectConsent() async throws -> EngineRequestCompletion
    func diagnostics() async throws -> EngineRequestCompletion
    func pluginInstall(_ request: WirePluginInstallParams) async throws -> EngineRequestCompletion
}

/// M0 supplies the authoritative parameter factory. Settings owns no session/epoch/floor reducer.
@MainActor public final class EngineClientScopeConsentCommands: ScopeConsentCommands {
    private let client: any EngineClient
    private let ready: @MainActor () -> Bool
    private let makeGrant: (@MainActor (ScopeConsentIntent) throws -> WireConsentGrantParams)?
    public init(client: any EngineClient, ready: @escaping @MainActor () -> Bool,
                makeGrant: (@MainActor (ScopeConsentIntent) throws -> WireConsentGrantParams)? = nil) {
        self.client = client; self.ready = ready; self.makeGrant = makeGrant
    }
    public var isReady: Bool { ready() }
    public var canMutate: Bool { ready() && makeGrant != nil }
    public func grant(_ intent: ScopeConsentIntent, userAction: EngineUserAction) async throws -> EngineRequestCompletion {
        guard ready() else { throw ScopeConsentCommandFailure.notReady }
        guard let makeGrant else { throw ScopeConsentCommandFailure.missingMetadata }
        let request = try makeGrant(intent)
        func same(_ actual: [String], _ expected: [String]) -> Bool {
            actual.count == expected.count && Set(actual) == Set(expected) && actual.count == Set(actual).count
        }
        let keychain = request.keychain ?? [:]
        guard request.requestId == intent.requestID,
              same(request.allow, intent.allowIDs), same(request.deny, intent.denyIDs),
              same(request.forget ?? [], intent.forgetIDs), same(Array(keychain.keys), intent.keychainIDs),
              keychain.values.allSatisfy({ $0 == .allow }) else { throw ScopeConsentCommandFailure.intentMismatch }
        return try await client.grant(request, userAction: userAction, timeout: nil)
    }
    public func inspectConsent() async throws -> EngineRequestCompletion { try await client.consent(timeout: nil) }
    public func diagnostics() async throws -> EngineRequestCompletion { try await client.diagnostics(timeout: nil) }
    public func pluginInstall(_ request: WirePluginInstallParams) async throws -> EngineRequestCompletion {
        try await client.pluginInstall(request, timeout: nil)
    }
}
