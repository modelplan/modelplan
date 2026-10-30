// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanSettings
import ModelPlanWire

/// Synchronous fanout from the already-admitted application store into Settings.
@MainActor final class EngineScopeConsentBinding: EngineStoreEventSink {
    let entry: ScopeConsentEntry
    private let store: EngineStore
    init(composition: EngineDockMenuComposition) {
        let store = composition.store
        self.store = store
        let factory = EngineConsentGrantFactory { [weak store] in
            guard let snapshot = store?.snapshot else { return (nil, nil) }
            return (snapshot.delivery, snapshot.acceptedConsent)
        }
        entry = ScopeConsentEntry(client: composition.client, ready: { [weak store] in
            guard let snapshot = store?.snapshot, case .ready = snapshot.connection else { return false }
            return true
        }, makeGrant: { intent in try factory.make(intent) })
        store.attach(self)
    }
    func clearPrivateViews(_ invalidation: EngineInvalidation) {
        entry.clearPrivateViews()
    }
    func acceptedEvent(_ event: EngineClientEvent) {
        switch event {
        case .consentChanged(let reply): entry.acceptedFacts(reply.envelope.data)
        case .rowsChanged(let reply, _): entry.acceptedRows(reply.envelope.data)
        case .response(let requestID, let response):
            switch response {
            case .consent(let reply): entry.acceptedFacts(reply.envelope.data)
            case .rows(let reply, _): entry.acceptedRows(reply.envelope.data)
            case .grant(let grant): entry.controller.receiveAcceptedGrant(grant)
            case .diagnostics(let reply): entry.controller.receiveAcceptedDiagnostics(reply.envelope.data)
            case .pluginInstall(let reply): entry.acceptedPluginResult(requestID: requestID, result: reply.envelope.data)
            default: break
            }
        default: break
        }
    }
    func apply(_ snapshot: EngineStoreSnapshot) {
        // An unrelated snapshot fanout is not a new consent readback.
        entry.controller.refreshAvailability()
    }
}
