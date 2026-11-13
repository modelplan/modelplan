// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanEngineStore
import ModelPlanEngineClient
import ModelPlanWire
@testable import ModelPlanAppIntegration

/// D238: a supported tool installed while ModelPlan runs reaches the app through the normal
/// engine rows path as detected-not-enabled: a status-menu line that opens Settings, no values
/// and no Quota Widget ring (G3-38, owner D76) until the user grants the tool's scope.
@MainActor final class D238LaterInstalledToolTests: XCTestCase {
    // The engine's own output for Kiro installed after the first run (rows.Build, D238). Kiro is
    // read through its runtime, so it stays opt-in; local-log-only tools are allowed without an
    // offer (D240).
    private static let kiroOffered = #"{"id":"kiro","kind":"tool","order":10,"name":{"en":"Kiro","zh":"Kiro"},"vendorKey":null,"surfaces":["menu","settings"],"consent":"unset","state":"needs_consent","reason":{"code":"consent_required","text":{"en":"Reader consent is needed","zh":"需要读取授权"}},"nextStep":{"action":"open_settings_consent","text":{"en":"Review reader consent in Settings","zh":"在设置中检查读取授权"}},"accounts":[],"expiresAt":null,"stateAfterExpiry":null}"#
    // The same tool when it was already there at first run and left undecided: Settings only.
    private static let kiroBaseline = kiroOffered.replacingOccurrences(of: #"["menu","settings"]"#, with: #"["settings"]"#)
    private static let summary = #"{"state":"no_consent","reason":{"code":"no_consent","text":{"en":"Choose tools to allow in Settings","zh":"在设置中选择允许读取的工具"}},"text":{"en":"Choose tools to allow in Settings","zh":"在设置中选择允许读取的工具"},"nextStep":{"action":"open_settings_consent","text":{"en":"Review reader consent in Settings","zh":"在设置中检查读取授权"}}}"#

    private func snapshot(_ sequence: Int, rows: [String]) throws -> WireRowsSnapshot {
        let json = #"{"sequence":"# + String(sequence) + #","projection":{"rowsVersion":1,"rows":["# + rows.joined(separator: ",") + #"],"rowsSummary":"# + Self.summary + "}}"
        return try WireDecoder.decode(WireRowsSnapshot.self, from: Data(json.utf8))
    }
    private func deliver(_ value: WireRowsSnapshot, to store: EngineStore) async throws {
        let context = EngineDeliveryContext(sessionID: "synthetic-d238", floor: .init(storeEpoch: "synthetic-d238", generation: 7), revision: 1)
        let reply = EngineReply(envelope: try WireEnvelope(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch, consentGeneration: 7, data: value), delivery: context)
        await store.consume(.rowsChanged(reply, invalidRowCount: 0))
    }

    func testToolInstalledAfterLaunchAppearsAsDetectedNotEnabled() async throws {
        let store = EngineStore()
        let provider = EngineDockMenuProvider(store: store)
        try await deliver(snapshot(1, rows: []), to: store)
        XCTAssertTrue(DetectedToolOffer.offers(provider.dockContent.menuRows, english: true).isEmpty)

        // The engine's next view after the install (its 30 s observation tick, Settings or wake).
        try await deliver(snapshot(2, rows: [Self.kiroOffered]), to: store)
        XCTAssertEqual(provider.dockContent.menuRows.map(\.id), ["kiro"])
        XCTAssertTrue(provider.dockContent.dockRows.isEmpty, "an undecided tool has no Quota Widget ring")
        XCTAssertTrue(EngineAccountMemberCatalogue(rows: provider.dockContent.menuRows).members.isEmpty, "no values before consent")
        XCTAssertEqual(DetectedToolOffer.offers(provider.dockContent.menuRows, english: true),
                       [.init(rowID: "kiro", title: "Kiro: Detected · Enable…")])
        XCTAssertEqual(DetectedToolOffer.offers(provider.dockContent.menuRows, english: false).map(\.title), ["Kiro：已检测到 · 启用…"])

        // Uninstalled: the engine drops the row and the line goes with it.
        try await deliver(snapshot(3, rows: []), to: store)
        XCTAssertTrue(DetectedToolOffer.offers(provider.dockContent.menuRows, english: true).isEmpty)
    }

    func testFirstRunToolLeftUndecidedIsNotOfferedAgain() throws {
        let rows = try snapshot(1, rows: [Self.kiroBaseline]).projection.rows
        XCTAssertTrue(DetectedToolOffer.offers(rows.filter { $0.surfaces.contains(.menu) }, english: true).isEmpty)
        XCTAssertTrue(DetectedToolOffer.offers(rows, english: true).isEmpty)
    }
}
