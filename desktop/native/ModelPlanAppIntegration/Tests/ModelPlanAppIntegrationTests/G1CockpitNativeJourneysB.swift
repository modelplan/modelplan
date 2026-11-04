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
    private func opened(usable: CGRect? = nil) async throws -> (EngineDockMenuApplication, CockpitWindowController) {
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
        #if MODELPLAN_TEST_ONLY_SPI
        if let usable {
            CommunityCockpitApplicationFactory.verificationPage = { page in
                page.verificationPlacement = (usable: usable, anchor: CGRect(x: usable.midX, y: usable.maxY - 20, width: 20, height: 20))
            }
        }
        defer { CommunityCockpitApplicationFactory.verificationPage = nil }
        #else
        if usable != nil { throw XCTSkip("NOT RUN: controlled display placement requires MODELPLAN_TEST_ONLY_SPI") }
        #endif
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
        let press = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseDown, location: CGPoint(x: -20, y: -20), modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1))
        NSApplication.shared.sendEvent(press)
        let deadline = ContinuousClock.now + .seconds(3)
        while page.g1PageStateForChecks.hasWindow && ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertFalse(page.g1PageStateForChecks.hasWindow, "An outside press should close an attached cockpit")
    }
    func testCKP_SHELL_02() async throws { try requireInteraction("CKP-SHELL-02", "detach and put-back actions and actual position") }
    func testCKP_SHELL_04() async throws {
        #if MODELPLAN_TEST_ONLY_SPI
        let (_, page) = try await opened(usable: CGRect(x: 0, y: 0, width: 1440, height: 1000))
        let window = try XCTUnwrap(page.window)
        let root = try XCTUnwrap(window.contentView)
        let drag = try XCTUnwrap(root.subviews.first { String(describing: type(of: $0)).contains("CockpitTitleDrag") })
        let point = drag.convert(CGPoint(x: drag.bounds.midX, y: drag.bounds.midY), to: nil)
        func event(_ kind: NSEvent.EventType, _ x: CGFloat) throws -> NSEvent {
            try XCTUnwrap(NSEvent.mouseEvent(with: kind, location: CGPoint(x: point.x + x, y: point.y), modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1))
        }
        let home = window.frame
        drag.mouseDown(with: try event(.leftMouseDown, 0))
        drag.mouseDragged(with: try event(.leftMouseDragged, 80))
        XCTAssertFalse(try XCTUnwrap(page.verificationShellState).attached)
        XCTAssertNotEqual(window.frame.origin, home.origin)
        drag.cancelOperation(nil)
        XCTAssertTrue(try XCTUnwrap(page.verificationShellState).attached)
        XCTAssertEqual(window.frame.origin, home.origin)
        drag.mouseDown(with: try event(.leftMouseDown, 0))
        drag.mouseDragged(with: try event(.leftMouseDragged, 14))
        drag.mouseUp(with: try event(.leftMouseUp, 0))
        XCTAssertTrue(try XCTUnwrap(page.verificationShellState).attached)
        #else
        try requireInteraction("CKP-SHELL-04", "controlled display placement compiled with MODELPLAN_TEST_ONLY_SPI")
        #endif
    }
    func testCKP_SHELL_05() async throws { try requireInteraction("CKP-SHELL-05", "status-item toggle and detached-position restart") }
    func testCKP_SHELL_06() async throws {
        #if MODELPLAN_TEST_ONLY_SPI
        let (_, page) = try await opened(usable: CGRect(x: 0, y: 0, width: 1440, height: 1000))
        let window = try XCTUnwrap(page.window)
        for usable in [CGRect(x: 0, y: 0, width: 1440, height: 1000), CGRect(x: 200, y: 100, width: 700, height: 760), CGRect(x: 80, y: 60, width: 420, height: 520)] {
            page.verificationPlacement = (usable: usable, anchor: CGRect(x: usable.midX, y: usable.maxY - 20, width: 20, height: 20))
            XCTAssertTrue(usable.insetBy(dx: -1, dy: -1).contains(window.frame), "Actual window must fit the current display")
        }
        // Retention across up to eight actual display arrangements is not observable through this seam.
        #else
        try requireInteraction("CKP-SHELL-06", "controlled display placement compiled with MODELPLAN_TEST_ONLY_SPI")
        #endif
    }
    func testCKP_SHELL_07() async throws {
        #if MODELPLAN_TEST_ONLY_SPI
        for (height, expectedRoot, expectedTier, expectedClosed) in [(1000.0,877.0,"tall",false),(800.0,627.0,"compact",false),(650.0,609.0,"compact",true)] {
            let (_, page) = try await opened(usable: CGRect(x: 0, y: 0, width: 1440, height: height))
            let root = try XCTUnwrap(page.verificationRootHeight)
            XCTAssertEqual(root, expectedRoot, accuracy: 0.01)
            let shell = try XCTUnwrap(page.verificationShellState)
            XCTAssertEqual(shell.tier.rawValue, expectedTier)
            XCTAssertEqual(shell.forcedClosed, expectedClosed)
            await page.g1CloseAndWaitForTeardown()
        }
        #else
        try requireInteraction("CKP-SHELL-07", "controlled display placement compiled with MODELPLAN_TEST_ONLY_SPI")
        #endif
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
    func testCKP_SHELL_11() async throws {
        #if MODELPLAN_TEST_ONLY_SPI
        let (_, page) = try await opened(usable: CGRect(x: 0, y: 0, width: 420, height: 500))
        let window = try XCTUnwrap(page.window), content = try XCTUnwrap(window.contentView)
        XCTAssertLessThan(window.frame.width, 636)
        XCTAssertEqual(window.frame.width / content.bounds.width, window.frame.height / content.bounds.height, accuracy: 0.01)
        XCTAssertTrue(try XCTUnwrap(page.verificationShellState).forcedClosed)
        // Scaled hit testing and drag remain unverified.
        #else
        try requireInteraction("CKP-SHELL-11", "controlled display placement compiled with MODELPLAN_TEST_ONLY_SPI")
        #endif
    }
    private func requireInteraction(_ id: String, _ missing: String) throws {
        guard let path = ProcessInfo.processInfo.environment["MODELPLAN_COCKPIT_BUNDLE_DIR"], !path.isEmpty else {
            throw XCTSkip("NOT RUN: MODELPLAN_COCKPIT_BUNDLE_DIR is not supplied by the GUI CI job")
        }
        throw XCTSkip("NOT RUN \(id): requires real \(missing)")
    }
}
#endif
