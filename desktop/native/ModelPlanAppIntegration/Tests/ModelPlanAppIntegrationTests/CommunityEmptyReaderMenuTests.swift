// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanCore
@testable import ModelPlanAppIntegration

final class CommunityEmptyReaderMenuTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_793_145_600)
    func testUnloadedFeedWithoutReaderFactsHasFixedBilingualMenuReason() {
        let model = CommunityDockSnapshot(snapshot:nil, diagnostics:StoreDiagnostics(), now:now, readerFacts:[])
        XCTAssertTrue(model.inputs.isEmpty); XCTAssertTrue(model.readerDiagnostics.isEmpty)
        XCTAssertEqual(model.emptyDiagnostic?.category, .notLoaded)
        XCTAssertEqual(CommunityReaderStatusPresentation.emptyMenuLine(model, english:true), model.emptyDiagnostic!.english + " Open Settings to check connected tools.")
        XCTAssertEqual(CommunityReaderStatusPresentation.emptyMenuLine(model, english:false), model.emptyDiagnostic!.chinese + " 打开设置检查已连接工具。")
    }
    func testExistingPerReaderReasonDoesNotGetADuplicateAggregateLine() {
        let model = CommunityDockSnapshot(snapshot:nil, diagnostics:StoreDiagnostics(), now:now,
            readerFacts:[.init(providerID:"claude",blockedCode:"not-connected-yet")])
        XCTAssertNil(CommunityReaderStatusPresentation.emptyMenuLine(model, english:true))
        XCTAssertEqual(CommunityReaderStatusPresentation.menuLines(model, english:true), ["Claude: Reader connection is not complete yet. Open Settings to check this tool."])
    }
    func testKnownZeroSubscriptionNeverGetsAnEmptyMenuReason() throws {
        let data = Data(#"{"schemaVersion":1,"kind":"modelplan.personal-snapshot","generatedAt":"2026-10-28T00:00:00Z","validUntil":"2030-01-01T00:00:00Z","accounts":[{"source":"codex","subscription":{"subscriptionRef":"synthetic","status":"verified"},"windows":[{"kind":"five_hour","remainingPercent":0,"observedAt":"2026-10-28T00:00:00Z"}]}],"subscriptions":[{"subscriptionRef":"synthetic","sources":["codex"]}]}"#.utf8)
        let personal = try FeedDecoder.personal(data); var ledger = ExpiryLedger()
        let joined = JoinedSnapshot.make(personal:personal, presentation:PersonalProjection.evaluate(personal,now:now,ledger:&ledger), publication:nil)
        var diagnostics = StoreDiagnostics(); diagnostics.personal = nil
        let model = CommunityDockSnapshot(snapshot:joined, diagnostics:diagnostics, now:now, readerFacts:[])
        XCTAssertEqual(model.inputs.map(\.id), ["synthetic"])
        XCTAssertEqual(model.inputs.first?.windows.first?.remainingPercent, 0)
        XCTAssertNil(CommunityReaderStatusPresentation.emptyMenuLine(model, english:true))
    }
    func testRawTransportReasonIsNotCopiedIntoTheEmptyMenu() {
        let raw = "/synthetic/private/alice@example.invalid/auth.json"
        var diagnostics = StoreDiagnostics(); diagnostics.personal = raw
        let model = CommunityDockSnapshot(snapshot:nil, diagnostics:diagnostics, now:now, readerFacts:[])
        let line = CommunityReaderStatusPresentation.emptyMenuLine(model, english:true)
        XCTAssertNotNil(line); XCTAssertFalse(line?.contains(raw) ?? true)
        XCTAssertFalse(line?.contains("alice") ?? true)
    }
}
