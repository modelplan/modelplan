// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanEngineClient
import ModelPlanWire
import ModelPlanEngineStoreCore

final class EngineStoreCoreTests: XCTestCase {
    private let features: [EngineFeature] = [.rows, .consent, .history, .publication, .pluginInstall, .diagnostics]

    private func capture<T: Decodable>(_ type: T.Type, _ file: String) throws -> T {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../../schema/app-cli/captures").standardizedFileURL
        return try WireDecoder.decode(type, from: Data(contentsOf: root.appendingPathComponent(file)))
    }

    private func bytes<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }

    private func context(_ generation: UInt64 = 7, epoch: String = "synthetic-store-epoch") -> EngineDeliveryContext {
        .init(sessionID: "synthetic-store-session", floor: .init(storeEpoch: epoch, generation: generation), revision: generation)
    }

    private func reply<T: Codable & Sendable>(_ value: T, _ generation: UInt64 = 7) throws -> EngineReply<T> {
        let current = context(generation)
        return .init(envelope: try .init(sessionId: current.sessionID, storeEpoch: current.floor.storeEpoch,
                                        consentGeneration: generation, data: value), delivery: current)
    }

    private func seed() throws -> [EngineClientEvent] {
        let current = context()
        let grant = EngineGrantResult(receipt: try capture(WireConsentReceipt.self, "WireConsentReceipt.json"),
                                      committedAt: current.floor, delivery: current, supersededByLaterConsent: false)
        return [
            .connection(.ready(current)), .context(current),
            .rowsChanged(try reply(capture(WireRowsSnapshot.self, "WireRowsSnapshot.json")), invalidRowCount: 2),
            .consentChanged(try reply(capture(WireConsentFacts.self, "WireConsentFacts.json"))),
            .response(requestID: .string("history"), .history(try reply(capture(WireHistoryPage.self, "WireHistoryPage.json")))),
            .response(requestID: .string("publication"), .publication(try reply(WireJSONValue.object(["synthetic": .bool(true)])))),
            .response(requestID: .string("plugin"), .pluginInstall(try reply(WireJSONValue.object(["synthetic": .bool(true)])))),
            .response(requestID: .string("diagnostics"), .diagnostics(try reply(capture(WireDiagnostics.self, "WireDiagnostics.json")))),
            .response(requestID: .string("refresh"), .refresh(try reply([capture(WireRefreshScheduled.self, "WireRefreshScheduled.json")]))),
            .response(requestID: .string("grant"), .grant(grant)),
            .health(try reply(capture(WireHealth.self, "WireHealth.json")))
        ]
    }

    private func assertEmptyPrivate(_ snapshot: EngineStoreSnapshot, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertNil(snapshot.delivery, file: file, line: line)
        XCTAssertNil(snapshot.lastResponseRequestID, file: file, line: line)
        XCTAssertNil(snapshot.rows, file: file, line: line)
        XCTAssertEqual(snapshot.invalidRowCount, 0, file: file, line: line)
        XCTAssertNil(snapshot.consent, file: file, line: line)
        XCTAssertNil(snapshot.history, file: file, line: line)
        XCTAssertNil(snapshot.publication, file: file, line: line)
        XCTAssertNil(snapshot.pluginInstall, file: file, line: line)
        XCTAssertNil(snapshot.diagnostics, file: file, line: line)
        XCTAssertNil(snapshot.refresh, file: file, line: line)
        XCTAssertNil(snapshot.lastGrant, file: file, line: line)
        XCTAssertNil(snapshot.health, file: file, line: line)
        XCTAssertTrue(snapshot.failures.isEmpty, file: file, line: line)
    }

    func testInitialStateAndConnectionEventsTable() {
        var core = EngineStoreCore()
        XCTAssertEqual(core.snapshot.connection, .idle)
        assertEmptyPrivate(core.snapshot)
        let states: [EngineConnectionState] = [.starting, .ready(context()), .restarting(attempt: 1, delay: .seconds(1)), .stopped(.requested), .idle]
        for state in states {
            guard case .none = core.apply(.connection(state)) else { return XCTFail("connection must not request a clear") }
            XCTAssertEqual(core.snapshot.connection, state)
            assertEmptyPrivate(core.snapshot)
        }
    }

    func testCapturedValueEventSequencePreservesEveryDonorField() throws {
        var core = EngineStoreCore()
        for event in try seed() {
            guard case .none = core.apply(event) else { return XCTFail("ordinary values must not request a clear") }
        }
        let snapshot = core.snapshot
        XCTAssertEqual(snapshot.connection, .ready(context()))
        XCTAssertEqual(snapshot.delivery, context())
        XCTAssertEqual(snapshot.lastResponseRequestID, .string("grant"))
        XCTAssertEqual(try bytes(snapshot.rows), try bytes(capture(WireRowsSnapshot.self, "WireRowsSnapshot.json")))
        XCTAssertEqual(snapshot.invalidRowCount, 2)
        XCTAssertEqual(try bytes(snapshot.consent), try bytes(capture(WireConsentFacts.self, "WireConsentFacts.json")))
        XCTAssertEqual(try bytes(snapshot.history), try bytes(capture(WireHistoryPage.self, "WireHistoryPage.json")))
        XCTAssertEqual(snapshot.publication, .object(["synthetic": .bool(true)]))
        XCTAssertEqual(snapshot.pluginInstall, .object(["synthetic": .bool(true)]))
        XCTAssertEqual(try bytes(snapshot.diagnostics), try bytes(capture(WireDiagnostics.self, "WireDiagnostics.json")))
        XCTAssertEqual(try bytes(snapshot.refresh), try bytes([capture(WireRefreshScheduled.self, "WireRefreshScheduled.json")]))
        XCTAssertEqual(try bytes(snapshot.lastGrant?.receipt), try bytes(capture(WireConsentReceipt.self, "WireConsentReceipt.json")))
        XCTAssertEqual(snapshot.lastGrant?.committedAt, context().floor)
        XCTAssertEqual(try bytes(snapshot.health), try bytes(capture(WireHealth.self, "WireHealth.json")))
    }

    func testClearTableResetsEveryPrivateFieldBeforeReturningEffect() throws {
        let reasons: [EngineInvalidationReason] = [.generationAdvanced, .epochChanged, .connectionLost, .stopped, .protocolFault]
        for reason in reasons {
            var core = EngineStoreCore()
            for event in try seed() { _ = core.apply(event) }
            for feature in features { _ = core.apply(.featureFailure(feature, .featureDecode(feature))) }
            XCTAssertNotNil(core.snapshot.rows)
            XCTAssertEqual(core.snapshot.failures.count, features.count)
            let invalidation = EngineInvalidation(revision: 8, reason: reason, previous: context(), nextFloor: context(8).floor)
            let effect = core.apply(.clearPrivateViews(invalidation))
            // Immediate state, before a native wrapper handles the returned effect.
            assertEmptyPrivate(core.snapshot)
            XCTAssertEqual(core.snapshot.connection, .ready(context()))
            guard case .clearPrivateViews(let returned) = effect else { XCTFail("missing clear effect: \(reason)"); continue }
            XCTAssertEqual(returned.revision, invalidation.revision)
            XCTAssertEqual(returned.reason, reason)
            XCTAssertEqual(returned.previous, invalidation.previous)
            XCTAssertEqual(returned.nextFloor, invalidation.nextFloor)
        }
    }

    func testFailureAndRecoverySequenceTableKeepsIndependentRows() throws {
        let rows = try capture(WireRowsSnapshot.self, "WireRowsSnapshot.json")
        let consent = try capture(WireConsentFacts.self, "WireConsentFacts.json")
        let history = try capture(WireHistoryPage.self, "WireHistoryPage.json")
        let diagnostics = try capture(WireDiagnostics.self, "WireDiagnostics.json")
        let recoveries: [(EngineFeature, EngineClientEvent)] = [
            (.rows, .rowsChanged(try reply(rows), invalidRowCount: 3)),
            (.rows, .response(requestID: .string("rows"), .rows(try reply(rows), invalidRowCount: 3))),
            (.consent, .consentChanged(try reply(consent))),
            (.consent, .response(requestID: .string("consent"), .consent(try reply(consent)))),
            (.history, .response(requestID: .string("history"), .history(try reply(history)))),
            (.publication, .response(requestID: .string("publication"), .publication(try reply(WireJSONValue.null)))),
            (.pluginInstall, .response(requestID: .string("plugin"), .pluginInstall(try reply(WireJSONValue.null)))),
            (.diagnostics, .response(requestID: .string("diagnostics"), .diagnostics(try reply(diagnostics))))
        ]
        for (recovered, recovery) in recoveries {
            var core = EngineStoreCore()
            for event in try seed() { _ = core.apply(event) }
            for feature in features {
                _ = core.apply(.featureFailure(feature, .featureDecode(feature)))
                _ = core.apply(.featureFailure(feature, .unsupportedCapability))
                XCTAssertEqual(try bytes(core.snapshot.rows), try bytes(rows), "independent rows changed: \(feature)")
                XCTAssertEqual(try bytes(core.snapshot.history), try bytes(history))
            }
            XCTAssertEqual(core.snapshot.failures.map(\.feature), features)
            for failure in core.snapshot.failures {
                guard case .unsupportedCapability = failure.error else { return XCTFail("latest failure was lost") }
            }
            _ = core.apply(recovery)
            XCTAssertEqual(core.snapshot.failures.map(\.feature), features.filter { $0 != recovered })
            XCTAssertEqual(try bytes(core.snapshot.rows), try bytes(rows))
        }
    }

    func testHistoricalReceiptSequenceTableNeverReplacesCurrentFactsOrContext() throws {
        let current = context(9)
        let facts = try capture(WireConsentFacts.self, "WireConsentFacts.json")
        let receipt = try capture(WireConsentReceipt.self, "WireConsentReceipt.json")
        let requests: [(WireRequestID, EngineConsentFloor?)] = [
            (.string("historical"), context(7).floor),
            (.signed(9_007_199_254_740_993), context(8).floor),
            (.unsigned(UInt64.max), nil)
        ]
        var core = EngineStoreCore()
        for event in try seed() { _ = core.apply(event) }
        _ = core.apply(.context(current))
        _ = core.apply(.consentChanged(try reply(facts, 9)))
        let originalRows = try bytes(core.snapshot.rows)
        for (id, committedAt) in requests {
            let result = EngineGrantResult(receipt: receipt, committedAt: committedAt, delivery: current,
                                           supersededByLaterConsent: true)
            _ = core.apply(.response(requestID: id, .grant(result)))
            XCTAssertEqual(core.snapshot.delivery, current)
            XCTAssertEqual(try bytes(core.snapshot.consent), try bytes(facts))
            XCTAssertEqual(try bytes(core.snapshot.rows), originalRows)
            XCTAssertEqual(core.snapshot.lastResponseRequestID, id)
            XCTAssertEqual(core.snapshot.lastGrant?.committedAt, committedAt)
            XCTAssertEqual(core.snapshot.lastGrant?.delivery, current)
            XCTAssertEqual(core.snapshot.lastGrant?.supersededByLaterConsent, true)
        }
    }

    func testClearThenFreshValuesSequenceDoesNotRestoreOtherPrivateFeatures() throws {
        var core = EngineStoreCore()
        for event in try seed() { _ = core.apply(event) }
        _ = core.apply(.clearPrivateViews(.init(revision: 8, reason: .epochChanged,
                                              previous: context(), nextFloor: context(1, epoch: "new-epoch").floor)))
        assertEmptyPrivate(core.snapshot)
        let fresh = context(1, epoch: "new-epoch")
        _ = core.apply(.context(fresh))
        let rows = try capture(WireRowsSnapshot.self, "WireRowsSnapshot.json")
        let response = EngineReply(envelope: try WireEnvelope(sessionId: fresh.sessionID,
                                    storeEpoch: fresh.floor.storeEpoch, consentGeneration: 1, data: rows), delivery: fresh)
        _ = core.apply(.response(requestID: .signed(42), .rows(response, invalidRowCount: 0)))
        XCTAssertEqual(core.snapshot.delivery, fresh)
        XCTAssertEqual(try bytes(core.snapshot.rows), try bytes(rows))
        XCTAssertNil(core.snapshot.history)
        XCTAssertNil(core.snapshot.consent)
        XCTAssertNil(core.snapshot.publication)
        XCTAssertNil(core.snapshot.pluginInstall)
        XCTAssertNil(core.snapshot.lastGrant)
        XCTAssertNil(core.snapshot.diagnostics)
        XCTAssertNil(core.snapshot.refresh)
        XCTAssertNil(core.snapshot.health)
        XCTAssertTrue(core.snapshot.failures.isEmpty)
    }

    func testRepeatedEmptyClearStillRequestsNativeViewClearing() {
        var core = EngineStoreCore()
        for revision in [UInt64(1), UInt64(2)] {
            let invalidation = EngineInvalidation(revision: revision, reason: .connectionLost, previous: nil, nextFloor: nil)
            let effect = core.apply(.clearPrivateViews(invalidation))
            assertEmptyPrivate(core.snapshot)
            XCTAssertEqual(core.snapshot.connection, .idle)
            guard case .clearPrivateViews(let returned) = effect else { XCTFail("empty clear lost its effect"); continue }
            XCTAssertEqual(returned.revision, revision)
            XCTAssertNil(returned.previous)
            XCTAssertNil(returned.nextFloor)
        }
    }

    func testReceiptAloneCannotCreateCurrentConsentOrContext() throws {
        var core = EngineStoreCore()
        let result = EngineGrantResult(receipt: try capture(WireConsentReceipt.self, "WireConsentReceipt.json"),
                                      committedAt: context(7).floor, delivery: context(9), supersededByLaterConsent: true)
        _ = core.apply(.response(requestID: .string("metadata-only"), .grant(result)))
        XCTAssertNil(core.snapshot.delivery)
        XCTAssertNil(core.snapshot.consent)
        XCTAssertNil(core.snapshot.rows)
        XCTAssertEqual(core.snapshot.lastGrant?.committedAt, context(7).floor)
        XCTAssertEqual(core.snapshot.lastResponseRequestID, .string("metadata-only"))
    }
}
