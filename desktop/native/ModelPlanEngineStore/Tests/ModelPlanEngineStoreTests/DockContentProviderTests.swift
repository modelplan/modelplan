// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanWire
import ModelPlanEngineClient
@testable import ModelPlanEngineStore

@MainActor final class DockContentProviderTests: XCTestCase {
    private func rows() throws -> WireRowsSnapshot {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../../../schema/app-cli/captures").standardizedFileURL
        return try WireDecoder.decode(WireRowsSnapshot.self, from: Data(contentsOf: root.appendingPathComponent("WireRowsSnapshot.json")))
    }
    private func context() -> EngineDeliveryContext {
        .init(sessionID: "synthetic-u6", floor: .init(storeEpoch: "synthetic-u6", generation: 7), revision: 1)
    }
    func testAcceptedRowsReachTheirDeclaredSurfacesAndClearSynchronously() async throws {
        let store = EngineStore()
        let actual = EngineDockMenuProvider(store: store)
        XCTAssertEqual(actual.dockContent.status, .loading)
        let fixture = try rows(), context = context()
        let reply = EngineReply(envelope: try WireEnvelope(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch, consentGeneration: 7, data: fixture), delivery: context)
        await store.consume(.rowsChanged(reply, invalidRowCount: 0))
        XCTAssertEqual(actual.dockContent.status, .ready)
        XCTAssertEqual(actual.dockContent.dockRows.map(\.id), ["codex"])
        XCTAssertEqual(actual.dockContent.menuRows.map(\.id), [])
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        XCTAssertEqual(try encoder.encode(actual.dockContent.dockRows), try encoder.encode(fixture.projection.rows.filter { $0.surfaces.contains(.dock) }))
        var clearedInsideCallback = false
        actual.dockContentDidChange = {
            if actual.dockContent.status == .cleared {
                clearedInsideCallback = true
                XCTAssertTrue(actual.dockContent.dockRows.isEmpty)
                XCTAssertTrue(actual.dockContent.menuRows.isEmpty)
                XCTAssertNil(actual.dockContent.summary)
            }
        }
        await store.consume(.clearPrivateViews(.init(revision: 2, reason: .generationAdvanced, previous: context, nextFloor: context.floor)))
        XCTAssertTrue(clearedInsideCallback)
        XCTAssertEqual(actual.dockContent.status, .cleared)
    }
    func testLoadingFailureEmptyAndRestartAreDistinctWithoutReclassifyingRows() async throws {
        let store = EngineStore(), context = context()
        let provider = EngineDockMenuProvider(store: store)
        XCTAssertEqual(provider.dockContent.status, .loading)
        await store.consume(.featureFailure(.rows, .featureDecode(.rows)))
        XCTAssertEqual(provider.dockContent.status, .failed)
        XCTAssertTrue(provider.dockContent.dockRows.isEmpty)
        let captured = try rows()
        let empty = try WireRowsSnapshot(sequence: 8, projection: .init(rowsVersion: 1, rows: [], rowsSummary: captured.projection.rowsSummary))
        await store.consume(.rowsChanged(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch, consentGeneration: 7, data: empty), delivery: context), invalidRowCount: 0))
        XCTAssertEqual(provider.dockContent.status, .empty)
        XCTAssertNotNil(provider.dockContent.summary)
        await store.consume(.featureFailure(.history, .featureDecode(.history)))
        XCTAssertEqual(provider.dockContent.status, .empty)
        await store.consume(.clearPrivateViews(.init(revision: 2, reason: .connectionLost, previous: context, nextFloor: nil)))
        XCTAssertEqual(provider.dockContent.status, .cleared)
        await store.consume(.connection(.starting))
        XCTAssertEqual(provider.dockContent.status, .loading)
    }

}
