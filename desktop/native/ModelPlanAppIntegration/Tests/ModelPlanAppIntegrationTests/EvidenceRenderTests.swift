// SPDX-License-Identifier: MIT
import AppKit
import ImageIO
import XCTest
@_spi(DockResourceChecks) import ModelPlanDock
import ModelPlanSettings
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanWire
@testable import ModelPlanAppIntegration

private actor EvidenceEngine: EngineClient {
    nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool { true }
    let store: EngineStore, rows: WireRowsSnapshot
    let context = EngineDeliveryContext(sessionID: "evidence", floor: .init(storeEpoch: "evidence", generation: 1), revision: 1)
    init(store: EngineStore, rows: WireRowsSnapshot) { self.store = store; self.rows = rows }
    func start() async throws -> EngineDeliveryContext {
        await store.consume(.connection(.ready(context))); await store.consume(.context(context)); return context
    }
    func retry() async throws -> EngineDeliveryContext { try await start() }
    func stop() async {}
    func subscribeRows(timeout: Duration?) async throws -> EngineRequestCompletion {
        await store.consume(.rowsChanged(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch, consentGeneration: 1, data: rows), delivery: context), invalidRowCount: 0))
        return .init(requestID: .string("rows"))
    }
    func consent(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func grant(_ request: WireConsentGrantParams, userAction: EngineUserAction?, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func refresh(_ request: WireRefreshRequestParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func history(_ request: WireHistoryQueryParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func cockpit(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func publication(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func pluginInstall(_ request: WirePluginInstallParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func diagnostics(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
}

/// Temporary: writes synthetic renders for #650's before/after evidence. Never merged.
@MainActor final class EvidenceRenderTests: XCTestCase {
    private var output: URL {
        URL(fileURLWithPath: ProcessInfo.processInfo.environment["EVIDENCE_OUT"] ?? NSTemporaryDirectory(), isDirectory: true)
    }
    private func write(_ image: CGImage?, _ name: String) {
        guard let image, let writer = CGImageDestinationCreateWithURL(output.appendingPathComponent(name + ".png") as CFURL, "public.png" as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(writer, image, nil); CGImageDestinationFinalize(writer)
    }
    private func snapshot(_ view: NSView, _ name: String) {
        guard view.bounds.width > 0, let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep); write(rep.cgImage, name)
    }
    func testWriteRenders() async throws {
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: capture)) as? [String: Any])
        var projection = try XCTUnwrap(json["projection"] as? [String: Any])
        var row = try XCTUnwrap((projection["rows"] as? [[String: Any]])?.first)
        var account = try XCTUnwrap((row["accounts"] as? [[String: Any]])?.first)
        var window = try XCTUnwrap((account["windows"] as? [[String: Any]])?.first)
        let observed = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-60))
        let reset = ISO8601DateFormatter().string(from: Date().addingTimeInterval(4 * 86400))
        window["id"] = "week"; window["role"] = "weekly"; window["durationSeconds"] = 604800; window["limitKey"] = "weekly"; window["poolKey"] = "main"
        window["remainingPercent"] = 76; window["current"] = true; window["observedAt"] = observed; window["resetsAt"] = reset; window["validUntil"] = reset
        window.removeValue(forKey: "modelScope")
        account["windows"] = [window]; account["route"] = "runtime_rpc"; account["observedAt"] = observed; account["valueState"] = "current"
        account["freshUntil"] = "2099-01-01T00:00:00Z"; account["subscriptionRef"] = "aaaaaaaaaaaaaaaa"
        account["plan"] = ["id": "pro", "name": ["en": "Synthetic", "zh": "Synthetic"]]
        row["id"] = "codex"; row["vendorKey"] = "openai"; row["name"] = ["en": "Codex", "zh": "Codex"]; row["state"] = "fresh"; row["consent"] = "allowed"
        row["surfaces"] = ["dock", "menu", "settings"]; row["expiresAt"] = "2099-01-01T00:00:00Z"; row["accounts"] = [account]
        projection["rows"] = [row]; json["projection"] = projection
        let rows = try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: json))
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("evidence-" + UUID().uuidString)
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en"])
        _ = try await store.update { p in p.showDock = true; p.autoHide = false; p.dockEdge = .right; p.size = .large; p.showPercentages = true; for _ in 0..<16 { p.onboarding.next() } }
        let screen = DockDisplayArea(id: "primary", frame: CGRect(x: 0, y: 0, width: 1440, height: 900), visibleFrame: CGRect(x: 0, y: 80, width: 1440, height: 795), backingScale: 2)
        let app = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: store, createsNativePanels: false,
            dockEnvironment: { .init(displays: [screen], layouts: [], primaryDisplayID: "primary", pointer: CGPoint(x: 600, y: 450)) },
            makeClient: { _, target in EvidenceEngine(store: target, rows: rows) }, activateSettings: {})
        await app.prepare(); app.allowDockPresentation(); await app.composition.start()
        let dock = app.composition.dock, view = dock.dockView
        for _ in 0..<600 where view.presentedReadingsForChecks.isEmpty { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertFalse(view.presentedReadingsForChecks.isEmpty)
        write(view.presentedImageForChecks, "resting")
        if let container = view.superview { snapshot(container, "resting-with-ignition") }
        let id = try XCTUnwrap(view.presentedReadingsForChecks.keys.first)
        try XCTUnwrap(view.nozzleEventDelegate).hoverNozzle(id)
        try await Task.sleep(for: .milliseconds(600))
        write(view.presentedImageForChecks, "hover")
        for _ in 0..<300 where dock.card.isHidden { try await Task.sleep(for: .milliseconds(10)) }
        snapshot(dock.card, "card")
        await app.composition.stop(); dock.close()
    }
}
