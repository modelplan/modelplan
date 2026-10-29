// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanEngineClient
import ModelPlanWire

public struct EngineStoreFeatureFailure: Sendable {
    public let feature: EngineFeature
    public let error: EngineClientError
}

/// UI-owned accepted values only. No credential payload or protocol reducer.
public struct EngineStoreSnapshot: Sendable {
    public internal(set) var connection: EngineConnectionState = .idle
    public internal(set) var delivery: EngineDeliveryContext?
    public internal(set) var lastResponseRequestID: WireRequestID?
    public internal(set) var rows: WireRowsSnapshot?
    public internal(set) var invalidRowCount = 0
    public internal(set) var consent: WireConsentFacts?
    public internal(set) var history: WireHistoryPage?
    public internal(set) var publication: WireJSONValue?
    public internal(set) var pluginInstall: WireJSONValue?
    public internal(set) var diagnostics: WireDiagnostics?
    public internal(set) var refresh: [WireRefreshScheduled]?
    public internal(set) var lastGrant: EngineGrantResult?
    public internal(set) var health: WireHealth?
    public internal(set) var failures: [EngineStoreFeatureFailure] = []
}

/// Applying values does not acknowledge the client's delivery barrier.
public enum EngineStoreEffect: Sendable {
    case none
    case clearPrivateViews(EngineInvalidation)
}

/// Pure storage of already-admitted events. The client owns protocol admission;
/// the native wrapper owns synchronous UI/cache clearing and acknowledgement.
public struct EngineStoreCore: Sendable {
    public private(set) var snapshot = EngineStoreSnapshot()

    public init() {}

    public mutating func apply(_ event: EngineClientEvent) -> EngineStoreEffect {
        // Interface baseline: event-sequence tests qualify the donor extraction.
        return .none
    }
}
