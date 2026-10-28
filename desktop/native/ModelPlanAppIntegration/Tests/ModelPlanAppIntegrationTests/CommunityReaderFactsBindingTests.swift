// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanCore
@testable import ModelPlanAppIntegration

final class CommunityReaderFactsBindingTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_793_145_600)
    func testNoObservationCannotInventPresenceConsentOrConnectionGap() {
        let facts = CommunityReaderFactsBinding.make(snapshot: nil, diagnostics: StoreDiagnostics())
        XCTAssertTrue(facts.isEmpty)
        let model = CommunityDockSnapshot(snapshot: nil, diagnostics: StoreDiagnostics(), now: now, readerFacts: facts)
        XCTAssertTrue(model.inputs.isEmpty)
        XCTAssertEqual(model.emptyDiagnostic?.category, .notLoaded)
    }
    func testCurrentDetectionPreservesUnknownAndConflictingPresence() throws {
        var diagnostics = StoreDiagnostics(); diagnostics.detection = nil; diagnostics.detectionReadAt = now
        diagnostics.detectionReport = try FeedDecoder.detection(Data(#"{"schemaVersion":1,"tools":[{"providerId":"codex","status":"unknown","detected":false},{"providerId":"claude","status":"not-detected","detected":false,"beta":true},{"providerId":"cursor","status":"not-detected","detected":true}]}"#.utf8))
        let facts = CommunityReaderFactsBinding.make(snapshot: nil, diagnostics: diagnostics)
        XCTAssertEqual(facts[0].detection, .unknown)
        XCTAssertEqual(facts[1].detection, .notDetected)
        XCTAssertEqual(facts[1].beta, true)
        XCTAssertEqual(facts[2].detection, .unknown)
        XCTAssertTrue(facts.allSatisfy { $0.consent == .unknown })
    }
    func testRetiredDetectionDoesNotLeakCachedPresence() throws {
        var diagnostics = StoreDiagnostics()
        diagnostics.detectionReport = try FeedDecoder.detection(Data(#"{"schemaVersion":1,"tools":[{"providerId":"codex","status":"detected","detected":true}]}"#.utf8))
        XCTAssertTrue(CommunityReaderFactsBinding.make(snapshot: nil, diagnostics: diagnostics).isEmpty)
    }
    func testDecodedPolicyBlockAndBetaDoNotBecomeConsentGrantOrSubscription() throws {
        let personal = try FeedDecoder.personal(Data(#"{"schemaVersion":1,"kind":"modelplan.personal-snapshot","generatedAt":"2026-10-28T00:00:00Z","validUntil":"2030-01-01T00:00:00Z","accounts":[{"source":"codex","beta":true}],"connections":[{"id":"codex","authorization":{"status":"yes"},"quotaAccess":{"blocked":"reader-consent-or-privacy"}}]}"#.utf8))
        var ledger = ExpiryLedger()
        let snapshot = JoinedSnapshot.make(personal: personal, presentation: PersonalProjection.evaluate(personal, now: now, ledger: &ledger), publication: nil)
        var diagnostics = StoreDiagnostics(); diagnostics.personal = nil
        let facts = CommunityReaderFactsBinding.make(snapshot: snapshot, diagnostics: diagnostics)
        let model = CommunityDockSnapshot(snapshot: snapshot, diagnostics: diagnostics, now: now, readerFacts: facts)
        XCTAssertTrue(model.inputs.isEmpty)
        XCTAssertEqual(model.readerDiagnostics.first?.category, .consentOrPrivacy)
        XCTAssertEqual(model.readerDiagnostics.first?.consent, .unknown)
        XCTAssertEqual(model.readerDiagnostics.first?.beta, true)
    }
    func testOnlyExplicitCapabilitySuppliesSafeEmptyAndMenuCopy() {
        let facts = CommunityReaderFactsBinding.make(snapshot: nil, diagnostics: StoreDiagnostics(), capabilities: .init(unconnectedProviders: ["claude"]))
        let model = CommunityDockSnapshot(snapshot: nil, diagnostics: StoreDiagnostics(), now: now, readerFacts: facts)
        XCTAssertTrue(model.inputs.isEmpty)
        XCTAssertEqual(model.emptyDiagnostic?.category, .notConnectedYet)
        XCTAssertEqual(CommunityReaderStatusPresentation.emptyText(model, english: false), "读取器连接尚未完成。")
        XCTAssertEqual(CommunityReaderStatusPresentation.menuLines(model, english: true), ["Claude: Reader connection is not complete yet."])
        let raw = "/synthetic/private/alice@example.invalid/auth.json"
        let unknown = CommunityDockSnapshot(snapshot: nil, diagnostics: StoreDiagnostics(), now: now, readerFacts: [.init(providerID: raw, reasonCode: raw)])
        XCTAssertFalse(CommunityReaderStatusPresentation.menuLines(unknown, english: true).joined().contains(raw))
        XCTAssertFalse(CommunityReaderStatusPresentation.emptyText(unknown, english: false).contains(raw))
    }
}
