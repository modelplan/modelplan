// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanCore
import ModelPlanAppIntegration

final class CommunityReaderReasonTests: XCTestCase {
    func testAbsentEvidenceStaysUnknownAndRawReasonsNeverBecomeCopy() throws {
        let result = CommunityReaderReason.project(snapshot: nil, diagnostics: StoreDiagnostics(),
            now: Date(timeIntervalSince1970: 1_800_000_000),
            facts: [.init(providerID: "codex", reasonCode: "/synthetic/private/alice@example.invalid/auth.json")])
        let reader = try XCTUnwrap(result.readers.first)
        XCTAssertEqual(reader.category, .unknown)
        XCTAssertEqual(reader.detection, .unknown)
        XCTAssertEqual(reader.consent, .unknown)
        XCTAssertEqual(reader.freshness, .unknown)
        XCTAssertNil(reader.beta)
        XCTAssertEqual(reader.english, "Reader status is unknown.")
        XCTAssertEqual(reader.chinese, "读取器状态未知。")
    }
    func testExplicitDetectionConsentAndBetaDoNotBecomeInferredGrants() throws {
        let result = CommunityReaderReason.project(snapshot: nil, diagnostics: StoreDiagnostics(),
            now: Date(timeIntervalSince1970: 1_800_000_000), facts: [
                .init(providerID: "codex", detection: .detected, beta: true),
                .init(providerID: "cursor", detection: .noSafeSignal, consent: .denied, beta: false),
            ])
        XCTAssertEqual(result.readers.map(\.detection), [.detected, .noSafeSignal])
        XCTAssertEqual(result.readers.map(\.consent), [.unknown, .denied])
        XCTAssertEqual(result.readers.map(\.beta), [true, false])
        XCTAssertEqual(result.readers.map(\.providerID), ["codex", "cursor"])
    }

    func testDetectionCopySeparatesAbsenceUnsafeSignalAndUpdateRequirement() throws {
        let cases: [(CommunityReaderDetection, String, String)] = [
            (.notDetected, "Tool not detected.", "未检测到工具。"),
            (.noSafeSignal, "No safe detection signal is available.", "没有可安全使用的检测信号。"),
            (.updateRequired, "Update required for this reader.", "此读取器需要更新。"),
            (.detected, "Reader status is unknown.", "读取器状态未知。"),
        ]
        for (status, english, chinese) in cases {
            let reader = try diagnostic(.init(providerID: "codex", detection: status))
            XCTAssertEqual(reader.english, english)
            XCTAssertEqual(reader.chinese, chinese)
            XCTAssertEqual(reader.consent, .unknown, "presence never proves a grant")
        }
    }
    func testExplicitDenialAndCombinedPolicyBlockHaveDifferentCopy() throws {
        let denied = try diagnostic(.init(providerID: "codex", consent: .denied))
        let blocked = try diagnostic(.init(providerID: "codex", blockedCode: "reader-consent-or-privacy"))
        XCTAssertEqual(denied.english, "Usage access was not granted.")
        XCTAssertEqual(denied.chinese, "未授权读取用量。")
        XCTAssertEqual(blocked.english, "Usage access is blocked by consent or privacy settings.")
        XCTAssertEqual(blocked.chinese, "授权或隐私设置阻止了用量读取。")
        XCTAssertEqual(blocked.consent, .unknown, "combined evidence is not an explicit denial")
    }
    func testOffChangedAndNotEnabledRemainDistinct() throws {
        for (code, english) in [
            ("reader-privacy", "Reader access is off."),
            ("consent-changed", "Reader permissions changed; a new reading is needed."),
            ("not-enabled", "Reader is not enabled."),
            ("update-required", "Update required for this reader."),
        ] {
            let reader = try diagnostic(.init(providerID: "codex", reasonCode: code))
            XCTAssertEqual(reader.english, english)
            XCTAssertEqual(reader.consent, .unknown)
        }
    }
    private func diagnostic(_ facts: CommunityReaderFacts) throws -> CommunityReaderDiagnostic {
        try XCTUnwrap(CommunityReaderReason.project(snapshot: nil, diagnostics: StoreDiagnostics(),
            now: Date(timeIntervalSince1970: 1_800_000_000), facts: [facts]).readers.first)
    }

    func testExplicitIntegrationGapDoesNotInventDenialOrMissingTool() throws {
        let reader = try diagnostic(.init(providerID: "claude", blockedCode: "not-connected-yet"))
        XCTAssertEqual(reader.english, "Reader connection is not complete yet.")
        XCTAssertEqual(reader.chinese, "读取器连接尚未完成。")
        XCTAssertEqual(reader.consent, .unknown)
        XCTAssertEqual(reader.detection, .unknown)
        XCTAssertEqual(reader.freshness, .unknown)
        XCTAssertEqual(try diagnostic(.init(providerID: "claude")).english, "Reader status is unknown.")
    }

    func testUnknownProviderAndUnrecognizedCodesAreNotExposedByDiagnostics() throws {
        let raw = "/synthetic/private/alice@example.invalid/auth.json"
        let reader = try diagnostic(.init(providerID: raw, blockedCode: raw, reasonCode: raw))
        XCTAssertNil(reader.providerID)
        XCTAssertEqual(reader.category, .unknown)
        XCTAssertFalse(String(reflecting: reader).contains(raw))
        XCTAssertFalse((reader.english + reader.chinese).contains("alice"))
    }
    func testConflictingFactsDoNotInventAChronologyOrVerifiedGrant() throws {
        let result = CommunityReaderReason.project(snapshot: nil, diagnostics: StoreDiagnostics(),
            now: Date(timeIntervalSince1970: 1_800_000_000), facts: [
                .init(providerID: "claude-code", detection: .detected, consent: .allowed, beta: true),
                .init(providerID: "native:claude", detection: .notDetected, consent: .denied, beta: false),
            ])
        XCTAssertEqual(result.readers.count, 1)
        let reader = try XCTUnwrap(result.readers.first)
        XCTAssertEqual(reader.providerID, "claude")
        XCTAssertEqual(reader.detection, .unknown)
        XCTAssertEqual(reader.consent, .unknown)
        XCTAssertEqual(reader.category, .unknown)
        XCTAssertNil(reader.beta)
    }

    func testDifferentUnknownToolsCannotBorrowEachOthersConsent() throws {
        let result = CommunityReaderReason.project(snapshot: nil, diagnostics: StoreDiagnostics(),
            now: Date(timeIntervalSince1970: 1_800_000_000), facts: [
                .init(providerID: "future-tool-one", consent: .denied),
                .init(providerID: "future-tool-two", consent: .allowed),
            ])
        XCTAssertEqual(result.readers.count, 2)
        XCTAssertEqual(result.readers.map(\.consent), [.denied, .allowed])
        XCTAssertTrue(result.readers.allSatisfy { $0.providerID == nil })
        XCTAssertFalse(result.readers.map { $0.english + $0.chinese }.joined().contains("future-tool"))
    }

}
