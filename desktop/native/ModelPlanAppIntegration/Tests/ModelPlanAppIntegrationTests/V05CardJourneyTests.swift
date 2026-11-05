// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanDock
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanSettings
import ModelPlanWire
@testable import ModelPlanAppIntegration

private actor V05SyntheticClient: EngineClient {
    nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool { true }
    let store: EngineStore, rows: WireRowsSnapshot
    let context = EngineDeliveryContext(sessionID: "reserve-synthetic", floor: .init(storeEpoch: "reserve-synthetic", generation: 1), revision: 1)
    init(store: EngineStore, rows: WireRowsSnapshot) { self.store = store; self.rows = rows }
    func start() async throws -> EngineDeliveryContext {
        await store.consume(.connection(.ready(context))); await store.consume(.context(context))
        await store.consume(.rowsChanged(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch,
            consentGeneration: 1, data: rows), delivery: context), invalidRowCount: rows.projection.invalidRowCount))
        return context
    }
    func stop() async {}
    func retry() async throws -> EngineDeliveryContext { try await start() }
    func subscribeRows(timeout: Duration?) async throws -> EngineRequestCompletion { .init(requestID: .string("synthetic-rows")) }
    func refresh(_ request: WireRefreshRequestParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func consent(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func grant(_ request: WireConsentGrantParams, userAction: EngineUserAction?, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func history(_ request: WireHistoryQueryParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func cockpit(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func publication(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func pluginInstall(_ request: WirePluginInstallParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func diagnostics(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
}

@MainActor private final class V05Timer: DockEdgeScheduling {
    func arm(at deadline: TimeInterval, _ action: @escaping @MainActor () -> Void) {}
    func cancel() {}
}

@MainActor final class V05CardJourneyTests: XCTestCase {
    func testV05NormalEntryRendersReserveWithoutDiagnosticLinesInBothLanguages() async throws {
        try await checkReserve(retained: false)
    }

    func testV05NormalEntryShowsRetainedReserveOnceInBothLanguages() async throws {
        try await checkReserve(retained: true)
    }

    private func checkReserve(retained: Bool) async throws {
        _ = NSApplication.shared
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("v05-card-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: capture)) as? [String: Any])
        var projection = try XCTUnwrap(root["projection"] as? [String: Any])
        var rows = try XCTUnwrap(projection["rows"] as? [[String: Any]])
        var row = rows[0], accounts = try XCTUnwrap(row["accounts"] as? [[String: Any]])
        var account = accounts[0], windows = try XCTUnwrap(account["windows"] as? [[String: Any]])
        row["id"] = "codex"; row["state"] = "fresh"; row["consent"] = "allowed"; row["surfaces"] = ["dock"]
        row["expiresAt"] = "2028-12-01T00:00:00Z"
        row["reason"] = ["code": "ok", "text": ["en": "Reading available", "zh": "读数可用"]]
        row["nextStep"] = ["action": "open_settings_consent", "text": ["en": "Check read access in Settings", "zh": "在设置检查读取权限"], "availableAt": NSNull(), "disabledReason": NSNull()]
        account["subscriptionRef"] = "aaaaaaaaaaaaaaaa"; account["valueState"] = "current"
        account["observedAt"] = "2026-12-01T00:00:00Z"; account["freshUntil"] = "2028-12-01T00:00:00Z"
        account["lastFailure"] = NSNull(); account["credits"] = ["balance": 123.45, "unit": "unknown"]
        windows[0].removeValue(forKey: "modelScope"); windows[0]["current"] = true
        windows[0]["observedAt"] = "2026-12-01T00:00:00Z"; windows[0]["validUntil"] = "2028-12-01T00:00:00Z"
        windows[0]["resetsAt"] = "2028-12-01T00:00:00Z"; windows[0]["remainingPercent"] = 42.0
        if retained {
            row["state"] = "stale"; row["expiresAt"] = NSNull(); row["stateAfterExpiry"] = NSNull()
            row["reason"] = ["code": "stale_reading", "text": ["en": "A retained reading is shown", "zh": "正在显示保留的旧读数"]]
            row["nextStep"] = ["action": "refresh", "text": ["en": "Refresh when permitted", "zh": "在允许时刷新"], "availableAt": NSNull(), "disabledReason": NSNull()]
            account["valueState"] = "retained"; windows[0]["current"] = false
        }
        account["windows"] = [windows[0]]; row["accounts"] = [account]; rows[0] = row
        projection["rows"] = rows; projection.removeValue(forKey: "resetEvents"); root["projection"] = projection
        let snapshot = try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: root))
        XCTAssertEqual(snapshot.projection.invalidRowCount, 0)
        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en"])
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2027-01-01T00:00:00Z"))
        let display = DockDisplayArea(id: "synthetic", frame: .init(x: 0, y: 0, width: 1440, height: 900), visibleFrame: .init(x: 0, y: 80, width: 1440, height: 820))
        var pointer = CGPoint(x: 700, y: 450), elapsed = 0.0
        let timer = V05Timer()
        let app = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/not-launched"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true),
            settingsStore: settings, createsNativePanels: false,
            dockEnvironment: { .init(displays: [display], layouts: [], primaryDisplayID: "synthetic", pointer: pointer) },
            deadlineNow: { now }, deadlineElapsed: { elapsed }, deadlineScheduling: timer,
            makeClient: { _, store in V05SyntheticClient(store: store, rows: snapshot) }, activateSettings: {})
        defer { app.composition.dock.close() }
        await app.prepare(); app.allowDockPresentation(); await app.composition.start()
        let dock = app.composition.dock, id = "aaaaaaaaaaaaaaaa"
        // This is the directory uploaded by the pinned GUI workflow, including on test failure.
        let environment = ProcessInfo.processInfo.environment
        let evidence: URL?
        if environment["GITHUB_ACTIONS"] == "true" {
            let runnerTemp = try XCTUnwrap(environment["RUNNER_TEMP"], "The GUI runner must supply its artifact directory")
            evidence = URL(fileURLWithPath: runnerTemp, isDirectory: true)
                .appendingPathComponent("dock-instrument-checks/dock-visual", isDirectory: true)
        } else {
            evidence = nil
        }
        if let evidence {
            try FileManager.default.createDirectory(at: evidence, withIntermediateDirectories: true)
            let result = dock.lastAppearanceError.map { "Production appearance failed: \($0)\n" } ?? "Production appearance loaded.\n"
            try result.write(to: evidence.appendingPathComponent("v05-appearance-\(retained ? "retained" : "fresh").txt"), atomically: true, encoding: .utf8)
        }
        XCTAssertNil(dock.lastAppearanceError, "The production Dock appearance must load")
        XCTAssertTrue(dock.interactionBindingInstalled, "Normal-entry interaction must be installed")
        XCTAssertTrue(dock.interactionEnvironment().active, "Normal-entry interaction must be active")
        XCTAssertTrue(dock.dockView.interactionProjectionAvailable, "The production Dock view must be available")
        let placement = try XCTUnwrap(dock.edgePresentation?.placement), anchor = try XCTUnwrap(dock.dockView.interactionAnchor(id))
        pointer = CGPoint(x: placement.frame.minX + anchor.midX - dock.dockView.bounds.minX, y: placement.frame.maxY - anchor.midY + dock.dockView.bounds.minY)
        try XCTUnwrap(dock.dockView.nozzleEventDelegate).hoverNozzle(id)
        elapsed += 0.251; dock.interactionControllerForChecks?.refresh()
        XCTAssertFalse(dock.card.isHidden)
        func textFields(_ view: NSView) -> [NSTextField] { ((view as? NSTextField).map { [$0] } ?? []) + view.subviews.flatMap(textFields) }
        for (language, label, forbidden) in [(SettingsLanguage.english, "Reserve", ["unit not reported", "reading available", "check read access in settings", "a retained reading is shown", "refresh when permitted"]), (.chinese, "储备", ["未报告单位", "读数可用", "在设置检查读取权限", "正在显示保留的旧读数", "在允许时刷新"])] {
            _ = try await app.settingsHost.application.editor.commit(SettingsB21Edit.language(language))
            dock.card.layoutSubtreeIfNeeded()
            let fields = textFields(dock.card).filter { !$0.isHiddenOrHasHiddenAncestor }
            let texts = fields.map(\.stringValue)
            XCTAssertTrue(texts.contains(label), "The real card must retain the reserve row")
            let reserveLabel = try XCTUnwrap(fields.first { $0.stringValue == label })
            let visibleBounds = reserveLabel.convert(reserveLabel.bounds, to: dock.card).intersection(dock.card.bounds)
            XCTAssertGreaterThan(visibleBounds.width, 0, "The reserve label must have visible width inside the card")
            XCTAssertGreaterThan(visibleBounds.height, 0, "The reserve label must have visible height inside the card")
            XCTAssertGreaterThanOrEqual(visibleBounds.width + 1, reserveLabel.intrinsicContentSize.width,
                                        "The reserve label must not be clipped horizontally")
            XCTAssertEqual(texts.filter { $0 == "123" }.count, 1, "The synthetic rounded reserve must be shown exactly once")
            let reserveValue = try XCTUnwrap(fields.first { $0.stringValue == "123" })
            let valueBounds = reserveValue.convert(reserveValue.bounds, to: dock.card).intersection(dock.card.bounds)
            XCTAssertGreaterThan(valueBounds.height, 0, "The reserve value must have visible height inside the card")
            XCTAssertGreaterThanOrEqual(valueBounds.width + 1, reserveValue.intrinsicContentSize.width,
                                        "The reserve value must not be clipped horizontally")
            XCTAssertTrue(visibleBounds.intersection(valueBounds).isEmpty,
                          "The reserve label and value must not overlap")
            XCTAssertFalse(texts.contains { $0.contains("≈") }, "The integer policy does not use an approximation marker")
            for phrase in forbidden { XCTAssertFalse(texts.contains { $0.localizedCaseInsensitiveContains(phrase) }, "Diagnostic copy must not appear on the card") }
            if let evidence {
                let suffix = (retained ? "retained-" : "fresh-") + (language == .english ? "en" : "zh")
                guard let bitmap = dock.card.bitmapImageRepForCachingDisplay(in: dock.card.bounds),
                      !dock.card.bounds.isEmpty else {
                    try "Card bitmap unavailable.\n".write(to: evidence.appendingPathComponent("v05-card-\(suffix).txt"), atomically: true, encoding: .utf8)
                    XCTFail("The synthetic card cannot be rendered to an offscreen bitmap")
                    continue
                }
                dock.card.cacheDisplay(in: dock.card.bounds, to: bitmap)
                guard let png = bitmap.representation(using: .png, properties: [:]) else {
                    try "Card PNG encoding failed.\n".write(to: evidence.appendingPathComponent("v05-card-\(suffix).txt"), atomically: true, encoding: .utf8)
                    XCTFail("The synthetic card bitmap cannot be encoded")
                    continue
                }
                try png.write(to: evidence.appendingPathComponent("v05-card-\(suffix).png"), options: .atomic)
            }
        }
        await app.composition.stop()
    }
}
