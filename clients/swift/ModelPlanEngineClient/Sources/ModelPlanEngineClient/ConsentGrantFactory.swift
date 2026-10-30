// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanWire

/// Projection of an explicit UI intent. No defaults, reader policy or authority.
/// Settings' ScopeConsentIntent can conform without moving UI types into the client.
public protocol EngineConsentGrantIntent: Sendable {
    var requestID: String { get }
    var allowIDs: [String] { get }
    var denyIDs: [String] { get }
    var forgetIDs: [String] { get }
    var keychainIDs: [String] { get }
}

public enum EngineConsentGrantError: Error, Sendable, Equatable {
    case missingContext, missingConsentFacts, staleConsentFacts
    case invalidConsentTextVersion, invalidIntent
}

/// Caller-owned synchronous factory. The provider is read for every invocation,
/// never captured as an old floor when the Settings command port is constructed.
/// Values must come from the client's accepted event path, normally StoreCore.
@MainActor public final class EngineConsentGrantFactory {
    private let accepted: @MainActor () -> (context: EngineDeliveryContext?, consent: EngineReply<WireConsentFacts>?)

    public init(accepted: @escaping @MainActor () -> (context: EngineDeliveryContext?, consent: EngineReply<WireConsentFacts>?)) {
        self.accepted = accepted
    }

    public func make<Intent: EngineConsentGrantIntent>(_ intent: Intent) throws -> WireConsentGrantParams {
        let current = accepted()
        guard let context = current.context, !context.sessionID.isEmpty,
              !context.floor.storeEpoch.isEmpty,
              !["unavailable", "legacy"].contains(context.floor.storeEpoch) else {
            throw EngineConsentGrantError.missingContext
        }
        guard let consent = current.consent else { throw EngineConsentGrantError.missingConsentFacts }
        // Consistency of already-accepted values, not a second protocol reducer.
        // Epochs are equality-only; same-floor old sessions/revisions are stale too.
        guard consent.delivery == context,
              consent.envelope.sessionId == context.sessionID,
              consent.envelope.storeEpoch == context.floor.storeEpoch,
              consent.envelope.consentGeneration == context.floor.generation else {
            throw EngineConsentGrantError.staleConsentFacts
        }
        guard consent.envelope.data.consentTextVersion > 0 else {
            throw EngineConsentGrantError.invalidConsentTextVersion
        }
        let allow = intent.allowIDs, deny = intent.denyIDs, forget = intent.forgetIDs, keychain = intent.keychainIDs
        let scopes = allow + deny + forget
        guard Set(scopes).count == scopes.count,
              Set(keychain).count == keychain.count,
              Set(keychain).isSubset(of: Set(allow)) else { throw EngineConsentGrantError.invalidIntent }
        do {
            return try WireConsentGrantParams(requestId: intent.requestID,
                expectStoreEpoch: context.floor.storeEpoch, expectGeneration: context.floor.generation,
                consentTextVersion: consent.envelope.data.consentTextVersion,
                allow: allow, deny: deny, forget: forget,
                keychain: Dictionary(uniqueKeysWithValues: keychain.map { ($0, .allow) }))
        } catch { throw EngineConsentGrantError.invalidIntent }
    }
}
