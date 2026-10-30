// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanEngineClient
import ModelPlanWire

public struct EngineStoreFeatureFailure: Sendable {
    public let feature: EngineFeature
    public let error: EngineClientError
}

/// Request identity and result from the same accepted response event.
public struct EngineAcceptedPluginInstall: Sendable {
    public let requestID: WireRequestID
    public let result: WirePluginInstallResult
}

/// UI-owned accepted values only. No credential payload or protocol reducer.
public struct EngineStoreSnapshot: Sendable {
    public internal(set) var connection: EngineConnectionState = .idle
    public internal(set) var delivery: EngineDeliveryContext?
    public internal(set) var lastResponseRequestID: WireRequestID?
    public internal(set) var rows: WireRowsSnapshot?
    public internal(set) var invalidRowCount = 0
    public internal(set) var acceptedConsent: EngineReply<WireConsentFacts>?
    public var consent: WireConsentFacts? { acceptedConsent?.envelope.data }
    public internal(set) var history: WireHistoryPage?
    public internal(set) var cockpit: WireCockpitData?
    public internal(set) var publication: WirePublicationResult?
    public internal(set) var lastPluginInstall: EngineAcceptedPluginInstall?
    public var pluginInstall: WirePluginInstallResult? { lastPluginInstall?.result }
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
        switch event {
        case .connection(let connection):
            snapshot.connection = connection
        case .clearPrivateViews(let invalidation):
            let connection = snapshot.connection
            snapshot = EngineStoreSnapshot()
            snapshot.connection = connection
            return .clearPrivateViews(invalidation)
        case .context(let context):
            snapshot.delivery = context
        case .response(let requestID, let response):
            snapshot.lastResponseRequestID = requestID
            apply(response, requestID: requestID)
        case .rowsChanged(let reply, let count):
            snapshot.rows = reply.envelope.data
            snapshot.invalidRowCount = count
            succeeded(.rows)
        case .consentChanged(let reply):
            snapshot.acceptedConsent = reply
            succeeded(.consent)
        case .health(let reply):
            snapshot.health = reply.envelope.data
        case .featureFailure(let feature, let error):
            snapshot.failures.removeAll { $0.feature == feature }
            snapshot.failures.append(.init(feature: feature, error: error))
        }
        return .none
    }

    private mutating func apply(_ response: EngineResponse, requestID: WireRequestID) {
        switch response {
        case .rows(let reply, let count):
            snapshot.rows = reply.envelope.data
            snapshot.invalidRowCount = count
            succeeded(.rows)
        case .consent(let reply):
            snapshot.acceptedConsent = reply
            succeeded(.consent)
        case .grant(let result):
            // Historical receipts are transaction metadata, never current facts
            // or a replacement delivery context/authorization.
            snapshot.lastGrant = result
        case .refresh(let reply):
            snapshot.refresh = reply.envelope.data
        case .history(let reply):
            snapshot.history = reply.envelope.data
            succeeded(.history)
        case .cockpit(let reply):
            snapshot.cockpit = reply.envelope.data
            succeeded(.cockpit)
        case .pluginInstall(let reply):
            snapshot.lastPluginInstall = .init(requestID: requestID, result: reply.envelope.data)
            succeeded(.pluginInstall)
        case .publication(let reply):
            snapshot.publication = reply.envelope.data
            succeeded(.publication)
        case .diagnostics(let reply):
            snapshot.diagnostics = reply.envelope.data
            succeeded(.diagnostics)
        }
    }

    private mutating func succeeded(_ feature: EngineFeature) {
        snapshot.failures.removeAll { $0.feature == feature }
    }

}
