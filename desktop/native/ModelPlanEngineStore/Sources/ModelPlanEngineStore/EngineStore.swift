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

/// A view/cache owner clears synchronously, before consume acknowledges the barrier.
/// Implementations must not retain a Task that later republishes a prior snapshot.
@MainActor public protocol EngineStoreSink: AnyObject {
    func clearPrivateViews(_ invalidation: EngineInvalidation)
    func apply(_ snapshot: EngineStoreSnapshot)
}

@MainActor private final class WeakSink {
    weak var value: (any EngineStoreSink)?
    init(_ value: any EngineStoreSink) { self.value = value }
}

/// The client already admitted these events. Session/epoch/generation/sequence
/// decisions and process supervision belong solely to ModelPlanEngineClient.
@MainActor public final class EngineStore: EngineClientEventConsumer {
    public private(set) var snapshot = EngineStoreSnapshot()
    private var sinks: [UUID: WeakSink] = [:]

    public init() {}

    @discardableResult
    public func attach(_ sink: any EngineStoreSink) -> UUID {
        let id = UUID()
        sinks[id] = WeakSink(sink)
        sink.apply(snapshot)
        return id
    }

    public func detach(_ id: UUID) { sinks.removeValue(forKey: id) }

    public func consume(_ event: EngineClientEvent) async {
        // There is intentionally no suspension or RPC in this delivery turn.
        switch event {
        case .connection(let connection):
            snapshot.connection = connection
        case .clearPrivateViews(let invalidation):
            let connection = snapshot.connection
            snapshot = EngineStoreSnapshot()
            snapshot.connection = connection
            for sink in liveSinks() { sink.clearPrivateViews(invalidation) }
        case .context(let context):
            snapshot.delivery = context
        case .response(let requestID, let response):
            snapshot.lastResponseRequestID = requestID
            apply(response)
        case .rowsChanged(let reply, let count):
            snapshot.rows = reply.envelope.data
            snapshot.invalidRowCount = count
            succeeded(.rows)
        case .consentChanged(let reply):
            snapshot.consent = reply.envelope.data
            succeeded(.consent)
        case .health(let reply):
            snapshot.health = reply.envelope.data
        case .featureFailure(let feature, let error):
            snapshot.failures.removeAll { $0.feature == feature }
            snapshot.failures.append(.init(feature: feature, error: error))
        }
        for sink in liveSinks() { sink.apply(snapshot) }
    }

    private func apply(_ response: EngineResponse) {
        switch response {
        case .rows(let reply, let count):
            snapshot.rows = reply.envelope.data
            snapshot.invalidRowCount = count
            succeeded(.rows)
        case .consent(let reply):
            snapshot.consent = reply.envelope.data
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
        case .pluginInstall(let reply):
            snapshot.pluginInstall = reply.envelope.data
            succeeded(.pluginInstall)
        case .publication(let reply):
            snapshot.publication = reply.envelope.data
            succeeded(.publication)
        case .diagnostics(let reply):
            snapshot.diagnostics = reply.envelope.data
            succeeded(.diagnostics)
        }
    }

    private func succeeded(_ feature: EngineFeature) {
        snapshot.failures.removeAll { $0.feature == feature }
    }

    private func liveSinks() -> [any EngineStoreSink] {
        sinks = sinks.filter { $0.value.value != nil }
        return sinks.values.compactMap(\.value)
    }
}
