// SPDX-License-Identifier: MIT
import AppKit
import CryptoKit
import WebKit
import XCTest
import ModelPlanSettings
import ModelPlanCockpitWeb
import ModelPlanEngineClient
import ModelPlanWire
@testable import ModelPlanAppIntegration

/// This is an opt-in synthetic WK journey, not an ordinary unit-test fallback.
/// The opt-in is NOT GUI authorization: the coordinator must independently book
/// the test window and the #399 bundle must first be repinned in production.
@MainActor final class RealCockpitEntryJourneyTests: XCTestCase {
    func testNormalEntryUsesTheActualPinnedPageAndV2ShellProtocol() async throws {
        #if MODELPLAN_TEST_ONLY_SPI
        guard ProcessInfo.processInfo.environment["MODELPLAN_S6_REAL_PAGE"] == "1",
              let bundlePath = ProcessInfo.processInfo.environment["MODELPLAN_S6_PINNED_BUNDLE"] else {
            throw XCTSkip("Requires the coordinator-scheduled synthetic WK window and actual #399 bundle")
        }
        guard CommunityCockpitApplicationFactory.webSource != "f25e1e821411bdd58cb09d9a388b9064505e856c" else {
            throw XCTSkip("The #399 source and reviewed bundle hashes are not available/adopted yet")
        }
        let input = URL(fileURLWithPath: bundlePath)
        _ = try VerifiedCockpitBundle(root: input, manifestSHA256: try XCTUnwrap(CommunityCockpitApplicationFactory.manifestPins["community"]))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("s6-real-page-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let bundle = try makeSyntheticApp(at: directory, cockpit: input)
        let data = try JSONDecoder().decode(WireCockpitData.self, from: Data(contentsOf: nativeRoot.appendingPathComponent("ModelPlanCockpitWeb/Tests/ModelPlanCockpitWebTests/Fixtures/cockpit.json")))
        var pages: [CockpitWindowController] = [], clients = 0
        var nextRendered: XCTestExpectation?
        let previous = CommunityCockpitApplicationFactory.verificationPage
        defer { CommunityCockpitApplicationFactory.verificationPage = previous; pages.forEach { $0.discard() } }
        CommunityCockpitApplicationFactory.verificationPage = { page in
            page.verificationPlacement = (CGRect(x: 0, y: 0, width: 1400, height: 1000), CGRect(x: 700, y: 1000, width: 20, height: 22))
            page.onRendered = { nextRendered?.fulfill() }
            pages.append(page)
        }
        let settings = try SettingsStore(url: directory.appendingPathComponent("settings.json"))
        _ = try await settings.update { $0.language = .english }
        let app = EngineRowsEntry.make(configuration: .init(executableURL: bundle.appendingPathComponent("Contents/Helpers/modelplan"), applicationVersion: "synthetic", allowedEnvironment: [:], offline: true, readOnly: true),
            settingsStore: settings, createsNativePanels: false, bundleURL: bundle,
            cockpitRuntime: .init(client: { _, consumer in clients += 1; return PinnedPageJourneyEngine(consumer, data: data) }, onUnavailable: { XCTFail("Actual pinned-page journey became unavailable") }))
        await app.prepare()
        _ = try await app.settingsHost.application.commit(.motion(.on))
        await app.composition.start()
        XCTAssertTrue(pages.isEmpty, "No prewarm or page injection")
        app.composition.dock.setPresentationAllowed(true)
        for entry in ["menu", "dock", "held-ignition"] {
            let rendered = expectation(description: entry + " real pinned page render"); nextRendered = rendered
            if entry == "menu" {
                let menu = try XCTUnwrap(app.liveStatusMenu)
                menu.performActionForItem(at: try XCTUnwrap(menu.items.firstIndex { $0.title == "Open Cockpit / 打开驾驶舱" }))
            } else if entry == "dock" {
                let menu = app.composition.dock.menu()
                menu.performActionForItem(at: try XCTUnwrap(menu.items.firstIndex { $0.title == "Open Cockpit / 打开驾驶舱" }))
            } else {
                app.composition.dock.consoleButton.mouseDown(with: try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, eventNumber: 1, clickCount: 1, pressure: 1)))
            }
            await fulfillment(of: [rendered], timeout: 10)
            let page = try XCTUnwrap(pages.last)
            XCTAssertEqual(page.bridge.appearanceVersion, 2)
            XCTAssertEqual(page.bridge.readyCapabilities, ["appearanceUpdates", "shellState", "shellActions"])
            XCTAssertFalse(app.composition.dock.isPresentationAllowed)
            let dom = try await snapshot(page)
            XCTAssertEqual(dom["locale"] as? String, "en")
            XCTAssertEqual(dom["theme"] as? String, "night")
            // Producer-dependent portion deliberately remains a failing gate,
            // never a fake page or a permissive read-only substitute. Finalize
            // actual button selectors/DOM geometry against #399's released page:
            // detach -> putBack; shutterToggle -> closed -> open; usable=705
            // must show closed 609 root + disabled open control with a reason;
            // live zh-CN/Reduce Motion/Reduce Transparency; page Close -> dispose.
            XCTFail("#399 control/DOM assertions are pending the actual reviewed bundle; real-page journey is NOT qualified")
            page.discard()
        }
        XCTAssertEqual(clients, 1)
        app.composition.dock.setPresentationAllowed(false); await app.composition.stop()
        #else
        throw XCTSkip("Compile only the scheduled WK journey with MODELPLAN_TEST_ONLY_SPI; no GUI in ordinary unit checks")
        #endif
    }
    #if MODELPLAN_TEST_ONLY_SPI
    private var nativeRoot: URL {
        var root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<3 { root.deleteLastPathComponent() }
        return root
    }
    private func makeSyntheticApp(at root: URL, cockpit: URL) throws -> URL {
        let bundle = root.appendingPathComponent("Synthetic.app"), resources = bundle.appendingPathComponent("Contents/Resources"), helpers = bundle.appendingPathComponent("Contents/Helpers")
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: helpers, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: cockpit, to: resources.appendingPathComponent("Cockpit"))
        let bytes = Data("synthetic-not-executable".utf8)
        let hash = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        try bytes.write(to: helpers.appendingPathComponent("modelplan"))
        try Data(hash.utf8).write(to: resources.appendingPathComponent("modelplan.sha256"))
        let pin = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: nativeRoot.appendingPathComponent("consent-cli-pin.json"))) as? [String: Any])
        let info: [String: Any] = ["CFBundleShortVersionString":"synthetic", "ModelPlanPublicSource":String(repeating:"a",count:40), "ModelPlanHelperVersion":CommunityConsentBundleIdentity.version, "ModelPlanBundledHelperSHA256":hash, "ModelPlanSourceHelperSHA256ByArchitecture":try XCTUnwrap(pin["sourceSHA256ByArchitecture"])]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: bundle.appendingPathComponent("Contents/Info.plist"))
        XCTAssertTrue(CommunityConsentBundleIdentity.matches(bundle: bundle))
        return bundle
    }
    private enum ScriptFailure: Error { case deadline }
    @MainActor private final class ScriptReceipt {
        var continuation: CheckedContinuation<Any, Error>?
        var deadline: Task<Void, Never>?
        init(_ continuation: CheckedContinuation<Any, Error>) { self.continuation = continuation }
        func finish(_ result: Result<Any, Error>) {
            guard let continuation else { return }; self.continuation = nil
            deadline?.cancel(); deadline = nil; continuation.resume(with: result)
        }
    }
    private func evaluate(web: WKWebView, code: String, arguments: [String: Any]) async throws -> Any {
        try await withCheckedThrowingContinuation { continuation in
            let receipt = ScriptReceipt(continuation)
            receipt.deadline = Task { @MainActor in
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
                receipt.finish(.failure(ScriptFailure.deadline))
            }
            web.callAsyncJavaScript(code, arguments: arguments, in: nil, in: .page) { result in
                Task { @MainActor in receipt.finish(result) }
            }
        }
    }
    private func snapshot(_ page: CockpitWindowController) async throws -> [String: Any] {
        let web = try XCTUnwrap(page.verificationWebView)
        let value = try await evaluate(web: web, code: "return {locale:document.documentElement.lang,theme:document.documentElement.dataset.theme,state:window.modelPlanCockpit?.state(),root:document.getElementById('cockpit')?.getBoundingClientRect().toJSON(),buttons:[...document.querySelectorAll('button')].map(b=>({label:b.getAttribute('aria-label')||b.textContent,disabled:b.disabled,rect:b.getBoundingClientRect().toJSON()}))};", arguments: [:])
        return try XCTUnwrap(value as? [String: Any])
    }
    /// Dispatch only to this test's owned WK window. No global input, private
    /// WebKit API or forged page-to-native action envelope is used.
    private func click(_ selector: String, page: CockpitWindowController) async throws {
        let web = try XCTUnwrap(page.verificationWebView), window = try XCTUnwrap(web.window)
        let value = try await evaluate(web: web, code: "const b=document.querySelector(selector);if(!b||b.disabled)throw Error('control-unavailable');const r=b.getBoundingClientRect();return {x:r.x+r.width/2,y:r.y+r.height/2};", arguments: ["selector":selector])
        let point = try XCTUnwrap(value as? [String:Double]), x = try XCTUnwrap(point["x"]), y = try XCTUnwrap(point["y"])
        let location = web.convert(CGPoint(x:x, y:web.isFlipped ? y : web.bounds.height-y), to:nil)
        for kind in [NSEvent.EventType.leftMouseDown,.leftMouseUp] {
            window.sendEvent(try XCTUnwrap(NSEvent.mouseEvent(with:kind,location:location,modifierFlags:[],timestamp:0,windowNumber:window.windowNumber,context:nil,eventNumber:1,clickCount:1,pressure:1)))
        }
    }
    #endif
}

private actor PinnedPageJourneyEngine: EngineClient {
    nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool { false }
    let consumer: any EngineClientEventConsumer
    let data: WireCockpitData
    let context = EngineDeliveryContext(sessionID: "s-00000000-0000-0000-0000-000000000001", floor: .init(storeEpoch: "synthetic-s6", generation: 1), revision: 1)
    init(_ consumer: any EngineClientEventConsumer, data: WireCockpitData) { self.consumer = consumer; self.data = data }
    func start() async throws -> EngineDeliveryContext { await consumer.consume(.connection(.ready(context))); return context }
    func retry() async throws -> EngineDeliveryContext { try await start() }
    func stop() async {}
    func subscribeRows(timeout: Duration?) async throws -> EngineRequestCompletion { .init(requestID: .string("synthetic")) }
    func cockpit(timeout: Duration?) async throws -> EngineRequestCompletion {
        let id = WireRequestID.string(UUID().uuidString)
        let envelope = try WireEnvelope(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch, consentGeneration: context.floor.generation, data: data)
        await consumer.consume(.response(requestID: id, .cockpit(.init(envelope: envelope, delivery: context))))
        return .init(requestID: id)
    }
    func consent(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func grant(_ request: WireConsentGrantParams, userAction: EngineUserAction?, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func refresh(_ request: WireRefreshRequestParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func history(_ request: WireHistoryQueryParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func publication(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func pluginInstall(_ request: WirePluginInstallParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func diagnostics(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
}
