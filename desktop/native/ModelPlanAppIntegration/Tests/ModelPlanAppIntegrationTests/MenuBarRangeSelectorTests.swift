// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanCockpitWeb
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanSettings
import ModelPlanWire
@testable import ModelPlanAppIntegration

/// MENU-50 / MENU-52 / CKP-SHELL-50 (WP-09), GUI leg: on the real status item, the right-click menu starts with the
/// range selector and the range's grey total line; choosing a segment changes the app's one range (the state the
/// cockpit reads), the total follows it, and a relaunch on the same profile restores it before the first menu.
/// Reference: CodexBar `StatusItemController` (custom-view rows at the top of the status menu).
@MainActor final class MenuBarRangeSelectorTests: XCTestCase {
    private func launch(_ root: URL) throws -> EngineDockMenuApplication {
        let rows = try HostPairedProjectionTests.rows(weekly: 40, sequence: 1)
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["zh-CN"])
        return EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"),
            applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: store, createsNativePanels: false,
            dockEnvironment: normalEntryTestEnvironment,
            makeClient: { _, store in EntrySyntheticClient(store: store, rows: rows) }, activateSettings: {})
    }
    /// The schema's cockpit capture with today 33.9M, 7d 212M and 30d 788M output tokens.
    private func cockpit() throws -> WireCockpitData {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../../schema/app-cli/captures/WireCockpitData.json").standardizedFileURL
        var value = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        var details = try XCTUnwrap(value["details"] as? [String: Any])
        details["subscriptions"] = try XCTUnwrap(details["subscriptions"] as? [[String: Any]]).map { sub in
            var sub = sub
            sub["today"] = (sub["today"] as? [[String: Any]] ?? []).map { var t = $0; t["observedOutputTokens"] = 33_900_000; return t }
            return sub
        }
        value["details"] = details
        var history = try XCTUnwrap(value["history"] as? [String: Any])
        history["subscriptions"] = try XCTUnwrap(history["subscriptions"] as? [[String: Any]]).map { sub in
            var sub = sub
            sub["sources"] = (sub["sources"] as? [[String: Any]] ?? []).map { source in
                var source = source
                for (key, total) in [("recent7d", 212_000_000), ("recent30d", 788_000_000)] {
                    var sums = source[key] as? [String: Any] ?? [:]; sums["outputTokens"] = total; source[key] = sums
                }
                return source
            }
            return sub
        }
        value["history"] = history
        return try WireDecoder.decode(WireCockpitData.self, from: JSONSerialization.data(withJSONObject: value))
    }
    private func deliver(_ data: WireCockpitData, to app: EngineDockMenuApplication) async throws {
        let context = EngineDeliveryContext(sessionID: "synthetic", floor: .init(storeEpoch: "synthetic", generation: 1), revision: 1)
        let reply = try EngineReply(envelope: .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch,
            consentGeneration: 1, data: data), delivery: context)
        await app.composition.store.consume(.response(requestID: .string("wp-09-range"), .cockpit(reply)))
    }
    private func selector(_ menu: NSMenu) throws -> NSSegmentedControl {
        let row = try XCTUnwrap(menu.items.first, "the selector is the first row")
        return try XCTUnwrap(row.view?.subviews.compactMap { $0 as? NSSegmentedControl }.first)
    }
    private func total(_ menu: NSMenu) -> String? {
        menu.items.first { $0.accessibilityIdentifier() == "status.rangeTotal" }?.title
    }

    func testRightClickMenuSwitchesTheAppRangeAndARelaunchRestoresIt() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("wp-09-range-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let app = try launch(root)
        await app.prepare(); app.allowDockPresentation(); await app.composition.start()
        app.installStatusItem()
        try await deliver(cockpit(), to: app)
        app.renderMenu()
        let menu = try XCTUnwrap(app.statusMenuForTesting)
        XCTAssertTrue(menu === app.liveStatusMenu, "the status item carries the live menu")

        // MENU-50: selector · grey total · (no problem line in this healthy fixture) · the fixed items.
        let control = try selector(menu)
        XCTAssertEqual((0..<control.segmentCount).map { control.label(forSegment: $0) }, ["今天", "7天", "30天"])
        XCTAssertEqual(control.selectedSegment, 1, "a fresh profile starts at 7d")
        XCTAssertEqual(control.accessibilityIdentifier(), "status.range")
        XCTAssertEqual(total(menu), "全部订阅 · 212M")
        XCTAssertFalse(try XCTUnwrap(menu.items.first { $0.accessibilityIdentifier() == "status.rangeTotal" }).isEnabled, "a grey, read-only line")

        // Choose 30天 in the menu: the app's range changes; the menu follows.
        control.selectedSegment = 2
        XCTAssertTrue(control.sendAction(control.action, to: control.target))
        XCTAssertEqual(app.cockpitRange.value, .thirtyDays, "MENU-52: the same state as the title bar and big-screen keys")
        let after = try XCTUnwrap(app.liveStatusMenu)
        XCTAssertEqual(try selector(after).selectedSegment, 2)
        XCTAssertEqual(total(after), "全部订阅 · 788M")

        // A change from the cockpit (big-screen key or T) shows in the next menu too.
        app.cockpitRange.select(.today)
        XCTAssertEqual(try selector(XCTUnwrap(app.liveStatusMenu)).selectedSegment, 0)
        XCTAssertEqual(total(try XCTUnwrap(app.liveStatusMenu)), "全部订阅 · 33.9M")

        // The menu-bar title stays the tightest quota, whatever the range (MENU-51).
        let title = try XCTUnwrap(app.statusButtonForTesting).title
        app.cockpitRange.select(.sevenDays)
        XCTAssertEqual(try XCTUnwrap(app.statusButtonForTesting).title, title)
        app.cockpitRange.select(.thirtyDays)

        // Quit and relaunch on the same profile: restored before the first menu.
        app.removeStatusItem(); await app.composition.stop(); app.composition.dock.close()
        let again = try launch(root)
        addTeardownBlock { @MainActor in again.removeStatusItem(); await again.composition.stop(); again.composition.dock.close() }
        XCTAssertEqual(again.cockpitRange.value, .thirtyDays, "CKP-SHELL-50: the range outlives a restart")
        await again.prepare(); again.installStatusItem(); again.renderMenu()
        XCTAssertEqual(try selector(XCTUnwrap(again.statusMenuForTesting)).selectedSegment, 2)
    }
}
