// SPDX-License-Identifier: MIT
import Foundation
import AppKit
import XCTest
import ModelPlanCore
import ModelPlanSettings
@testable import ModelPlanAppIntegration

@MainActor final class H33DockPresenterTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private func snapshot(accounts: [[String: Any]] = [], connections: [[String: Any]] = [], sources: [[String: Any]] = []) throws -> JoinedSnapshot {
        let iso = ISO8601DateFormatter()
        let object: [String: Any] = ["schemaVersion": 1, "kind": "modelplan.personal-snapshot",
            "generatedAt": iso.string(from: now.addingTimeInterval(-10)), "validUntil": iso.string(from: now.addingTimeInterval(300)),
            "accounts": accounts, "connections": connections, "sources": sources]
        let personal = try FeedDecoder.personal(JSONSerialization.data(withJSONObject: object))
        var ledger = ExpiryLedger()
        return .make(personal: personal, presentation: PersonalProjection.evaluate(personal, now: now, ledger: &ledger), publication: nil)
    }
    private func consent(_ ids: [String], mode: String = "automatic") throws -> ConsentPreview {
        let tools = ids.map { ["id": $0, "displayName": $0, "backend": "native", "readerId": "native:" + $0,
            "accessClass": "standard", "detected": true, "allowed": true, "keychain": "unset", "hosts": []] as [String: Any] }
        return try FeedDecoder.consentPreview(JSONSerialization.data(withJSONObject: ["generation": 1, "consentTextVersion": 2,
            "mode": mode, "consentText": ["en": "Synthetic", "zh": "合成"], "tools": tools]))
    }
    private func model(_ snapshot: JoinedSnapshot, consent: ConsentPreview? = nil) -> CommunityDockSnapshot {
        var diagnostics = StoreDiagnostics(); diagnostics.personal = nil
        return .init(snapshot: snapshot, diagnostics: diagnostics, now: now, canonicalConsent: consent)
    }
    func testAlwaysYesCodexConnectionRequiresCanonicalConsentAndWaitsForFirstRead() throws {
        let value = try snapshot(connections: [["id": "codex", "authorization": ["status": "yes"], "quota": ["status": "no", "reason": "missing"]]])
        XCTAssertTrue(model(value).inputs.isEmpty)
        XCTAssertTrue(model(value, consent: try consent(["codex"], mode: "off")).inputs.isEmpty)
        let admitted = model(value, consent: try consent(["codex"]))
        let row = try XCTUnwrap(admitted.presentationRows.values.first)
        XCTAssertTrue(row.reason.contains("Waiting for first reading"))
        XCTAssertTrue(row.input.alias?.contains("Codex") == true)
        XCTAssertFalse(row.reason.contains("not detected"))
        XCTAssertTrue(admitted.subscriptions.isEmpty)
    }
    func test545ClaudeStatusLineConnectionStillShowsNativeKeychainGuidance() throws {
        let value = try snapshot(connections: [["id": "claude-code", "authorization": ["status": "not-applicable", "via": "status-line"]]],
            sources: [["source": "native:claude", "status": "consent_required"]])
        let row = try XCTUnwrap(model(value).presentationRows.values.first)
        XCTAssertTrue(row.nextStep.contains("Allow Keychain"))
        XCTAssertTrue(row.input.alias?.contains("Claude Code") == true)
        XCTAssertTrue(row.input.alias?.contains("Keychain") == true)
        XCTAssertTrue(row.input.windows.isEmpty)
    }
    func testAnyAccountSuppressesDuplicateButRetainsNativeSourceReasonAndMembership() throws {
        for bound in [false, true] {
            var account: [String: Any] = ["source": "claude-code", "stale": true, "windows": []]
            if bound { account["subscription"] = ["subscriptionRef": "actual-ref", "status": "verified"] }
            let value = try snapshot(accounts: [account], connections: [["id": "native:claude", "authorization": ["status": "yes"]]],
                sources: [["source": "native:claude", "status": "consent_required"]])
            let result = model(value, consent: try consent(["claude"]))
            XCTAssertEqual(result.inputs.count, 1)
            XCTAssertEqual(result.subscriptions.count, bound ? 1 : 0)
            XCTAssertTrue(result.inputs[0].alias?.contains("Claude Code") == true)
            let row = try XCTUnwrap(result.presentationRows[result.inputs[0].id])
            XCTAssertTrue(row.nextStep.contains("Keychain"))
        }
    }
    func testEveryEmptyReasonHasSettingsNextStep() throws {
        XCTAssertTrue(model(try snapshot()).emptyDiagnostic != nil)
        let text = CommunityReaderStatusPresentation.emptyText(model(try snapshot()), english: true)
        XCTAssertTrue(text.contains("Settings"))
    }
    func testActualHostWithdrawsPhantomConnectionWhenCanonicalConsentInvalidates() async throws {
        _ = NSApplication.shared
        let host = StaticDockPreviewHost(currentDate: { self.now }, createsNativePanels: false)
        defer { host.close() }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("h33-host-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = SettingsApplicationCoordinator(store: try SettingsStore(url: root.appendingPathComponent("settings.json"))) { host.apply($0) }
        await app.reload()
        var diagnostics = StoreDiagnostics(); diagnostics.personal = nil
        let value = try snapshot(connections: [["id": "codex", "authorization": ["status": "yes"], "quota": ["status": "no", "reason": "missing"]]])
        host.render(snapshot: value, diagnostics: diagnostics)
        host.updateDockConsent(try consent(["codex"]))
        XCTAssertTrue(host.menu().items.contains { $0.title.contains("Waiting for first reading") })
        func rowCount() -> Int {
            (host.dockView.accessibilityChildren() ?? []).compactMap { $0 as? NSAccessibilityElement }
                .filter { $0.accessibilityIdentifier()?.hasPrefix("dock.subscription.") == true }.count
        }
        XCTAssertEqual(rowCount(), 1)
        host.updateDockConsent(nil)
        XCTAssertEqual(rowCount(), 0, "reader diagnostic menu copy is not a quota/presentation row")
        XCTAssertNil(host.nativePanel)
    }
}
