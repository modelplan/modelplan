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
private actor G1CockpitEngine: EngineClient {
    let consumer: any EngineClientEventConsumer
    let data: WireCockpitData
    let context = EngineDeliveryContext(sessionID: "s-00000000-0000-4000-8000-000000000001", floor: .init(storeEpoch: "g1-synthetic", generation: 1), revision: 1)
    init(consumer: any EngineClientEventConsumer, data: WireCockpitData) { self.consumer = consumer; self.data = data }
    nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool { context.storeEpochForG1 == "g1-synthetic" }
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
    var storeEpochForG1: String { floor.storeEpoch }
}

@MainActor final class G1CockpitRealWindowJourneys: XCTestCase {
    func testG1_CKP_SHELL_18() async throws {
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
            return G1CockpitEngine(consumer: consumer, data: data)
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
        XCTAssertTrue(page.g1PageStateForChecks.hasWindow)
        XCTAssertTrue(page.g1PageStateForChecks.hasPage)
        XCTAssertTrue(page.g1PageStateForChecks.ready)
        let geometry = try await page.g1PageGeometryForChecks()
        XCTAssertNotNil(geometry, "The live verified page must answer its read-only DOM observation")
        await page.g1CloseAndWaitForTeardown()
        XCTAssertTrue(page.g1PageStateForChecks.disposed)
        XCTAssertFalse(page.g1PageStateForChecks.hasPage)
        XCTAssertFalse(page.g1PageStateForChecks.hasWindow)
    }
}
#endif
