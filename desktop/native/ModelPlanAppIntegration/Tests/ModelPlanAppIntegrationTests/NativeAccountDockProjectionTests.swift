// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanCore
import ModelPlanSettings
@testable import ModelPlanAppIntegration

@MainActor final class NativeAccountDockProjectionTests: XCTestCase {
    func testActualCommunityFactoryRetainsNativeClaudeValueWithoutAStatusLineOrWindow() async throws {
        let now = Date(), format = ISO8601DateFormatter()
        let object: [String: Any] = ["schemaVersion": 1, "kind": "modelplan.personal-snapshot",
            "generatedAt": format.string(from: now), "validUntil": format.string(from: now.addingTimeInterval(600)),
            "accounts": [["source": "claude-code", "via": "native", "observedAt": format.string(from: now.addingTimeInterval(-30)),
                "windows": [["kind": "weekly", "remainingPercent": 75.0, "resetsAt": format.string(from: now.addingTimeInterval(3600))]]]],
            "sources": [["source": "claude-code", "status": "missing"], ["source": "native:claude", "status": "ok"]]]
        let personal = try FeedDecoder.personal(JSONSerialization.data(withJSONObject: object))
        var ledger = ExpiryLedger()
        let joined = JoinedSnapshot.make(personal: personal, presentation: .evaluate(personal, now: now, ledger: &ledger), publication: nil)
        let host = ProductionDockFactory.community(createsNativePanels: false)
        defer { host.close() }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("native-claude-dock-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let application = SettingsApplicationCoordinator(store: try SettingsStore(url: root.appendingPathComponent("settings.json"))) { host.apply($0) }
        await application.reload()
        var diagnostics = StoreDiagnostics(); diagnostics.personal = nil
        host.render(snapshot: joined, diagnostics: diagnostics)
        let nodes = (host.dockView.accessibilityChildren() ?? []).compactMap { $0 as? NSAccessibilityElement }
        XCTAssertEqual(host.purpose, .production)
        XCTAssertEqual(nodes.count, 1)
        XCTAssertEqual(nodes.first?.accessibilityValue() as? String, "75%")
        XCTAssertNil(host.nativePanel); XCTAssertNil(host.dockView.window)
        XCTAssertTrue(CommunityDockSnapshot(snapshot: joined, diagnostics: diagnostics, now: now).subscriptions.isEmpty)
    }
}
