// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanEngineClient
import ModelPlanWire
@testable import ModelPlanEngineStore

@MainActor private final class Sink: EngineStoreSink {
    var received: [EngineStoreSnapshot] = []
    var privateCachePresent = false
    var clearCount = 0
    var onClear: (() -> Void)?
    func clearPrivateViews(_ invalidation: EngineInvalidation) {
        privateCachePresent = false
        clearCount += 1
        onClear?()
    }
    func apply(_ snapshot: EngineStoreSnapshot) {
        received.append(snapshot)
        privateCachePresent = snapshot.rows != nil || snapshot.history != nil || snapshot.cockpit != nil
    }
}

@MainActor final class EngineStoreTests: XCTestCase {
    private func capture<T: Decodable>(_ type: T.Type, _ file: String) throws -> T {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../../schema/app-cli/captures").standardizedFileURL
        return try WireDecoder.decode(type, from: Data(contentsOf: root.appendingPathComponent(file)))
    }
    private func context(_ generation: UInt64 = 7) -> EngineDeliveryContext {
        .init(sessionID: "synthetic-store-session",
              floor: .init(storeEpoch: "synthetic-store-epoch", generation: generation),
              revision: generation)
    }
    private func reply<T: Codable & Sendable>(_ value: T, _ generation: UInt64 = 7) throws -> EngineReply<T> {
        let ctx = context(generation)
        return .init(envelope: try .init(sessionId: ctx.sessionID, storeEpoch: ctx.floor.storeEpoch,
                                        consentGeneration: generation, data: value), delivery: ctx)
    }
    func testRowsFanOutAndDetachWithoutMembershipReinterpretation() async throws {
        let store = EngineStore(), sink = Sink()
        let token = store.attach(sink)
        let rows = try capture(WireRowsSnapshot.self, "WireRowsSnapshot.json")
        await store.consume(.rowsChanged(try reply(rows), invalidRowCount: 2))
        XCTAssertEqual(store.snapshot.rows?.projection.rows.map(\.id), rows.projection.rows.map(\.id))
        XCTAssertEqual(sink.received.last?.rows?.projection.rows.map(\.id), rows.projection.rows.map(\.id))
        XCTAssertEqual(store.snapshot.invalidRowCount, 2)
        store.detach(token)
        let count = sink.received.count
        await store.consume(.featureFailure(.history, .featureDecode(.history)))
        XCTAssertEqual(sink.received.count, count)
    }
    func testClearRemovesEveryRetainedPrivateValueAndSinkCacheBeforeAck() async throws {
        let store = EngineStore(), sink = Sink()
        store.attach(sink)
        await store.consume(.context(context()))
        await store.consume(.rowsChanged(try reply(capture(WireRowsSnapshot.self, "WireRowsSnapshot.json")), invalidRowCount: 1))
        await store.consume(.consentChanged(try reply(capture(WireConsentFacts.self, "WireConsentFacts.json"))))
        await store.consume(.response(requestID: .string("history"), .history(try reply(capture(WireHistoryPage.self, "WireHistoryPage.json")))))
        await store.consume(.response(requestID: .string("publication"), .publication(try reply(capture(WirePublicationResult.self, "WirePublicationResult.json")))))
        await store.consume(.response(requestID: .string("plugin"), .pluginInstall(try reply(capture(WirePluginInstallResult.self, "WirePluginInstallResult.json")))))
        await store.consume(.response(requestID: .string("diagnostics"), .diagnostics(try reply(capture(WireDiagnostics.self, "WireDiagnostics.json")))))
        await store.consume(.response(requestID: .string("refresh"), .refresh(try reply([WireRefreshScheduled]()))))
        await store.consume(.response(requestID: .string("cockpit"), .cockpit(try reply(capture(WireCockpitData.self, "WireCockpitData.json")))))
        sink.onClear = {
            XCTAssertNil(store.snapshot.rows)
            XCTAssertNil(store.snapshot.consent)
            XCTAssertNil(store.snapshot.history)
            XCTAssertNil(store.snapshot.cockpit)
            XCTAssertNil(store.snapshot.publication)
            XCTAssertNil(store.snapshot.pluginInstall)
            XCTAssertNil(store.snapshot.diagnostics)
            XCTAssertNil(store.snapshot.refresh)
            XCTAssertNil(store.snapshot.lastGrant)
            XCTAssertNil(store.snapshot.delivery)
            XCTAssertNil(store.snapshot.lastResponseRequestID)
            XCTAssertEqual(store.snapshot.invalidRowCount, 0)
        }
        await store.consume(.clearPrivateViews(.init(revision: 8, reason: .generationAdvanced,
                                                    previous: context(), nextFloor: context(8).floor)))
        XCTAssertEqual(sink.clearCount, 1)
        XCTAssertFalse(sink.privateCachePresent)
        XCTAssertNil(sink.received.last?.rows)
    }
    func testHistoryFailureDoesNotReplaceIndependentRows() async throws {
        let store = EngineStore()
        let rows = try capture(WireRowsSnapshot.self, "WireRowsSnapshot.json")
        await store.consume(.rowsChanged(try reply(rows), invalidRowCount: 0))
        await store.consume(.featureFailure(.history, .featureDecode(.history)))
        XCTAssertEqual(store.snapshot.rows?.projection.rows.map(\.id), rows.projection.rows.map(\.id))
        XCTAssertEqual(store.snapshot.failures.first?.feature, .history)
    }
    func testHistoricalReceiptDoesNotReplaceConsentOrDeliveryContext() async throws {
        let store = EngineStore()
        let current = context(9)
        await store.consume(.context(current))
        let facts = try capture(WireConsentFacts.self, "WireConsentFacts.json")
        await store.consume(.consentChanged(try reply(facts, 9)))
        let receipt = try capture(WireConsentReceipt.self, "WireConsentReceipt.json")
        let result = EngineGrantResult(receipt: receipt, committedAt: context(7).floor,
                                       delivery: current, supersededByLaterConsent: true)
        await store.consume(.response(requestID: .string("grant"), .grant(result)))
        XCTAssertEqual(store.snapshot.delivery, current)
        XCTAssertEqual(store.snapshot.lastResponseRequestID, .string("grant"))
        XCTAssertEqual(store.snapshot.consent?.scopes.map(\.scope), facts.scopes.map(\.scope))
        XCTAssertTrue(store.snapshot.lastGrant?.supersededByLaterConsent == true)
        XCTAssertEqual(store.snapshot.lastGrant?.committedAt?.generation, 7)
    }
    func testProductionFactoryBindsRealMergedClientWithoutStartingIt() {
        let config = EngineClientConfiguration(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"),
                                                applicationVersion: "synthetic-test", allowedEnvironment: [:],
                                                offline: true, readOnly: true)
        let pair = EngineStoreConnection(configuration: config)
        XCTAssertTrue(pair.client is any EngineClient)
        XCTAssertNil(pair.store.snapshot.rows)
        XCTAssertEqual(pair.store.snapshot.connection, .idle)
    }
    func testTypedResultsAndCockpitFailureRecoveryUsePortableCore() async throws {
        let store = EngineStore()
        await store.consume(.featureFailure(.cockpit, .featureDecode(.cockpit)))
        XCTAssertEqual(store.snapshot.failures.first?.feature, .cockpit)
        let cockpit = try capture(WireCockpitData.self, "WireCockpitData.json")
        let publication = try capture(WirePublicationResult.self, "WirePublicationResult.json")
        let plugin = try capture(WirePluginInstallResult.self, "WirePluginInstallResult.json")
        await store.consume(.response(requestID: .string("cockpit"), .cockpit(try reply(cockpit))))
        await store.consume(.response(requestID: .string("publication"), .publication(try reply(publication))))
        await store.consume(.response(requestID: .string("plugin"), .pluginInstall(try reply(plugin))))
        XCTAssertFalse(store.snapshot.failures.contains { $0.feature == .cockpit })
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        XCTAssertEqual(try encoder.encode(XCTUnwrap(store.snapshot.cockpit)), try encoder.encode(cockpit))
        XCTAssertEqual(try encoder.encode(XCTUnwrap(store.snapshot.publication)), try encoder.encode(publication))
        XCTAssertEqual(try encoder.encode(XCTUnwrap(store.snapshot.pluginInstall)), try encoder.encode(plugin))
    }

}
