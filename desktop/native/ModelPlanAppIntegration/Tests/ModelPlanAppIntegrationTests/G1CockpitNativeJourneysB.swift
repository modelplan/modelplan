// SPDX-License-Identifier: MIT
#if DEBUG
import AppKit
import CryptoKit
import XCTest
import ModelPlanCockpitWeb
import ModelPlanEngineClient
import ModelPlanSettings
import ModelPlanWire
@testable import ModelPlanAppIntegration

/// Synthetic engine only; the normal Factory, verified bundle and WK page remain real.
private actor G1BCockpitEngine: EngineClient {
    let consumer: any EngineClientEventConsumer
    let data: WireCockpitData
    let context = EngineDeliveryContext(sessionID: "s-00000000-0000-4000-8000-000000000001", floor: .init(storeEpoch: "g1-synthetic", generation: 1), revision: 1)
    init(consumer: any EngineClientEventConsumer, data: WireCockpitData) { self.consumer = consumer; self.data = data }
    nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool { context.storeEpochForG1B == "g1-synthetic" }
    func start() async throws -> EngineDeliveryContext { await consumer.consume(.connection(.ready(context))); return context }
    func retry() async throws -> EngineDeliveryContext { try await start() }
    func stop() async {}
    func subscribeRows(timeout: Duration?) async throws -> EngineRequestCompletion { .init(requestID: .string("g1-rows")) }
    func cockpit(timeout: Duration?) async throws -> EngineRequestCompletion {
        let id = WireRequestID.string(UUID().uuidString)
        let envelope = try WireEnvelope(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch, consentGeneration: context.floor.generation, data: data)
        await consumer.consume(.response(requestID: id, .cockpit(.init(envelope: envelope, delivery: context))))
        return .init(requestID: id)
    }
    func consent(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func grant(_ request: WireConsentGrantParams, userAction: EngineUserAction?, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func refresh(_ request: WireRefreshRequestParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func history(_ query: WireHistoryQueryParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func publication(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func pluginInstall(_ request: WirePluginInstallParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func diagnostics(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
}
private extension EngineDeliveryContext {
    var storeEpochForG1B: String { floor.storeEpoch }
}

@MainActor final class G1CockpitNativeJourneysB: XCTestCase {
    private func opened() async throws -> (EngineDockMenuApplication, CockpitWindowController) {
        guard let path = ProcessInfo.processInfo.environment["MODELPLAN_COCKPIT_BUNDLE_DIR"], !path.isEmpty else {
            throw XCTSkip("NOT RUN: MODELPLAN_COCKPIT_BUNDLE_DIR is not supplied by the GUI CI job")
        }
        let source = URL(fileURLWithPath: path, isDirectory: true)
        let pin = try XCTUnwrap(CommunityCockpitApplicationFactory.manifestPins["community"])
        _ = try VerifiedCockpitBundle(root: source, manifestSHA256: pin, allowOfficial: false)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("g1-cockpit-" + UUID().uuidString)
        let bundle = root.appendingPathComponent("Synthetic.app"), resources = bundle.appendingPathComponent("Contents/Resources"), helpers = bundle.appendingPathComponent("Contents/Helpers")
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: helpers, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: source, to: resources.appendingPathComponent("Cockpit"))
        let helper = Data("g1-synthetic-not-executable".utf8)
        let digest = SHA256.hash(data: helper).map { String(format: "%02x", $0) }.joined()
        try helper.write(to: helpers.appendingPathComponent("modelplan"))
        try Data(digest.utf8).write(to: resources.appendingPathComponent("modelplan.sha256"))
        let info: [String: Any] = ["ModelPlanPublicSource": String(repeating: "a", count: 40), "ModelPlanHelperVersion": CommunityConsentBundleIdentity.version,
            "ModelPlanBundledHelperSHA256": digest, "ModelPlanSourceHelperSHA256ByArchitecture": CommunityConsentBundleIdentity.sourceSHA256ByArchitecture]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: bundle.appendingPathComponent("Contents/Info.plist"))
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../../..").standardizedFileURL
        let data = try JSONDecoder().decode(WireCockpitData.self, from: Data(contentsOf: repo.appendingPathComponent("schema/app-cli/captures/WireCockpitData.json")))
        let settings = try SettingsStore(url: root.appendingPathComponent("settings.json"))
        let configuration = EngineClientConfiguration(executableURL: helpers.appendingPathComponent("modelplan"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true)
        var fanout: CockpitStoreFanout?
        let app = CommunityCockpitApplicationFactory.makeForChecks(configuration: configuration, settingsStore: settings, bundleURL: bundle, createsNativePanels: false, cockpitEntryEnabled: true) { _, consumer in
            fanout = consumer as? CockpitStoreFanout
            return G1BCockpitEngine(consumer: consumer, data: data)
        }
        addTeardownBlock { @MainActor in
            fanout?.cockpit.close()
            await app.composition.stop()
            try? FileManager.default.removeItem(at: root)
        }
        _ = NSApplication.shared
        await app.prepare()
        await app.composition.start()
        let coordinator = try XCTUnwrap(fanout?.cockpit)
        app.showConsole()
        let limit = ContinuousClock.now.advanced(by: .seconds(10))
        while coordinator.g1LivePageForChecks?.g1PageStateForChecks.ready != true && ContinuousClock.now < limit {
            try await Task.sleep(for: .milliseconds(20))
        }
        let page = try XCTUnwrap(coordinator.g1LivePageForChecks)
        return (app, page)
    }
    private func geometry(_ page: CockpitWindowController) async throws -> [String: Any] {
        let observed = try await page.g1PageGeometryForChecks()
        let json = try XCTUnwrap(observed)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
    }
    private func rect(_ name: String, _ values: [String: Any]) throws -> CGRect {
        let item = try XCTUnwrap(values[name] as? [String: Double], "Missing actual page geometry: \(name)")
        return try CGRect(x: XCTUnwrap(item["x"]), y: XCTUnwrap(item["y"]), width: XCTUnwrap(item["width"]), height: XCTUnwrap(item["height"]))
    }
    func testCKP_SHELL_01() async throws {
        let (app, page) = try await opened()
        let anchor = try XCTUnwrap(app.cockpitAnchor, "Actual status-item anchor unavailable")
        let window = try XCTUnwrap(page.window)
        XCTAssertTrue(window.isVisible)
        XCTAssertLessThanOrEqual(window.frame.maxY, anchor.maxY + 1)
        // Outside-press dismissal requires a separate admitted input journey.
    }
    func testCKP_SHELL_02() async throws { try requireInteraction("CKP-SHELL-02", "detach and put-back actions and actual position") }
    func testCKP_SHELL_04() async throws { try requireInteraction("CKP-SHELL-04", "title drag, snap and cancellation input") }
    func testCKP_SHELL_05() async throws { try requireInteraction("CKP-SHELL-05", "status-item toggle and detached-position restart") }
    func testCKP_SHELL_06() async throws { try requireInteraction("CKP-SHELL-06", "display arrangement changes and retained positions") }
    func testCKP_SHELL_07() async throws {
        let (_, page) = try await opened()
        let geometry = try await geometry(page)
        let deck = try rect("deck", geometry), tape = try rect("tape", geometry)
        XCTAssertTrue([217.0, 257.0].contains { abs(deck.height - $0) < 1 }, "Actual deck height: \(deck.height)")
        XCTAssertTrue([58.0, 94.0].contains { abs(tape.height - $0) < 1 }, "Actual tape height: \(tape.height)")
        // The other height profiles need a controllable real display geometry.
    }
    func testCKP_SHELL_08() async throws {
        let (_, page) = try await opened()
        let window = try XCTUnwrap(page.window)
        XCTAssertGreaterThan(window.contentView?.bounds.width ?? 0, 0)
        XCTAssertEqual(window.contentView?.bounds.width ?? 0, 636, accuracy: 1)
        // Closed geometry and cap shape remain unobserved.
    }
    func testCKP_SHELL_09() async throws {
        let (_, page) = try await opened()
        let geometry = try await geometry(page)
        let deck = try rect("deck", geometry)
        XCTAssertEqual(deck.width, 588, accuracy: 1)
        // Individual gutter and padding values require a page readback.
    }
    func testCKP_SHELL_10() async throws {
        let (_, page) = try await opened()
        let geometry = try await geometry(page)
        let deck = try rect("deck", geometry), tape = try rect("tape", geometry)
        if abs(deck.height - 257) < 1 { XCTAssertEqual(tape.height, 94, accuracy: 1) }
        else { XCTAssertEqual(deck.height, 217, accuracy: 1); XCTAssertEqual(tape.height, 58, accuracy: 1) }
        // The other profile and remaining modules require additional readback.
    }
    func testCKP_SHELL_11() async throws { try requireInteraction("CKP-SHELL-11", "short display geometry and scaled pointer routing") }
    private func requireInteraction(_ id: String, _ missing: String) throws {
        guard let path = ProcessInfo.processInfo.environment["MODELPLAN_COCKPIT_BUNDLE_DIR"], !path.isEmpty else {
            throw XCTSkip("NOT RUN: MODELPLAN_COCKPIT_BUNDLE_DIR is not supplied by the GUI CI job")
        }
        throw XCTSkip("NOT RUN \(id): requires real \(missing)")
    }
}
#endif
