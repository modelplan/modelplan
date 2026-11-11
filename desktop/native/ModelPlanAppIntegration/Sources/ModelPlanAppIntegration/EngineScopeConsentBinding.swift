// SPDX-License-Identifier: MIT
import AppKit
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
        entry.markImage = { ScopeConsentMarks.image(for: $0) }
        // HIST-IMP-02/03: the local-history import, over the same engine client.
        let importer = HistoryImportModel(commands: EngineHistoryImportCommands(client: composition.client, ready: { [weak store] in
            guard let snapshot = store?.snapshot, case .ready = snapshot.connection else { return false }
            return true
        }))
        entry.historyImport = importer
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
            case .grant(let grant):
                entry.controller.receiveAcceptedGrant(grant)
                // The first-run import follows the committed consent with no further dialog; the engine
                // runs it once and skips every tool that was not allowed.
                if grant.committedAt != nil, !grant.supersededByLaterConsent, grant.receipt.code == .ok, let model = entry.historyImport {
                    Task { @MainActor in await model.runAfterFirstRunConsent() }
                }
            case .historyImport(let reply): entry.acceptedHistoryImport(reply.envelope.data)
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

/// Adapts the engine client to the Settings import model. Replies come back as accepted
/// `.historyImport` events, never as a return value.
@MainActor final class EngineHistoryImportCommands: HistoryImportCommands {
    private let client: any EngineClient
    private let isReady: @MainActor () -> Bool
    init(client: any EngineClient, ready: @escaping @MainActor () -> Bool) { self.client = client; isReady = ready }
    var ready: Bool { isReady() }
    func start(days: Int, firstRun: Bool) async throws {
        _ = try await client.historyImportStart(try WireHistoryImportStartParams(days: days, firstRun: firstRun), timeout: nil)
    }
    func status() async throws { _ = try await client.historyImportStatus(timeout: nil) }
    func cancel() async throws { _ = try await client.historyImportCancel(timeout: nil) }
    func remove() async throws { _ = try await client.historyImportRemove(timeout: nil) }
}
