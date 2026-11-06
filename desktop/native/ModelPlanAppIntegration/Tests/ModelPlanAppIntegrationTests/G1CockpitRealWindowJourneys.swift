// SPDX-License-Identifier: MIT
#if DEBUG
import AppKit
import CryptoKit
import XCTest
import WebKit
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
    private func withLivePage(language: SettingsLanguage = .english, syntheticAccountCount: Int = 1, _ exercise: @MainActor (EngineDockMenuApplication, EngineCockpitCoordinator, CockpitWindowController) async throws -> Void) async throws {
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
        let capture = try Data(contentsOf: repo.appendingPathComponent("schema/app-cli/captures/WireCockpitData.json"))
        guard syntheticAccountCount == 1 || syntheticAccountCount == 2 else { throw CockpitBridgeError.unavailable }
        var fixture = try XCTUnwrap(JSONSerialization.jsonObject(with: capture) as? [String: Any])
        if syntheticAccountCount == 2 {
            var projection = try XCTUnwrap(fixture["projection"] as? [String: Any])
            var rows = try XCTUnwrap(projection["rows"] as? [[String: Any]])
            var accounts = try XCTUnwrap(rows.first?["accounts"] as? [[String: Any]])
            var second = try XCTUnwrap(accounts.first)
            second["subscriptionRef"] = NSNull()
            second["accountLocator"] = NSNull()
            accounts.append(second)
            rows[0]["accounts"] = accounts
            projection["rows"] = rows
            fixture["projection"] = projection
        }
        let data = try JSONDecoder().decode(WireCockpitData.self, from: JSONSerialization.data(withJSONObject: fixture))
        let settings = try SettingsStore(url: root.appendingPathComponent("settings.json"))
        _ = try await settings.update { $0.language = language }
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
        XCTAssertNil(coordinator.g1LivePageForChecks, "No cockpit page is prewarmed before the normal opening action")
        app.showConsole()
        let limit = ContinuousClock.now.advanced(by: .seconds(10))
        while coordinator.g1LivePageForChecks?.g1PageStateForChecks.ready != true && ContinuousClock.now < limit {
            try await Task.sleep(for: .milliseconds(20))
        }
        let page = try XCTUnwrap(coordinator.g1LivePageForChecks)
        try await exercise(app, coordinator, page)
        await page.g1CloseAndWaitForTeardown()
    }
    private func geometry(_ page: CockpitWindowController) async throws -> [String: Any] {
        let observation = try await page.g1PageGeometryForChecks()
        let raw = try XCTUnwrap(observation)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
    }
    private func dimension(_ facts: [String: Any], _ element: String, _ axis: String) throws -> Double {
        let rect = try XCTUnwrap(facts[element] as? [String: Any], "Missing actual element: " + element)
        return try XCTUnwrap((rect[axis] as? NSNumber)?.doubleValue)
    }
    #if MODELPLAN_TEST_ONLY_SPI
    func testC17NormalEntryHelpReadbackIsBoundedAndRetires() async throws {
        for language: SettingsLanguage in [.english, .chinese] {
            try await withLivePage(language: language) { _, _, page in
                let web = try XCTUnwrap(page.verificationWebView)
                let initial = try await page.g1HelpCaptionFactsForChecks()
                let before = try XCTUnwrap(initial)
                let hidden = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(before.utf8)) as? [String: Any])
                XCTAssertEqual(hidden["open"] as? Bool, false)
                for attached in [true, false] {
                    if !attached {
                        _ = try await web.evaluateJavaScript("document.querySelector('[data-detach]')?.click()")
                        for _ in 0..<100 where page.verificationShellState?.attached != false {
                            try await Task.sleep(for: .milliseconds(20))
                        }
                    }
                    XCTAssertEqual(page.verificationShellState?.attached, attached)
                    _ = try await web.evaluateJavaScript("window.dispatchEvent(new KeyboardEvent('keydown',{key:'Alt'}))")
                    var facts: [String: Any] = [:]
                    for _ in 0..<100 {
                        if let raw = try await page.g1HelpCaptionFactsForChecks(),
                           let value = try JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any],
                           value["open"] as? Bool == true { facts = value; break }
                        try await Task.sleep(for: .milliseconds(20))
                    }
                    XCTAssertEqual(facts["open"] as? Bool, true)
                    let key = language == .english ? "matchesEnglish" : "matchesChinese"
                    for target in ["window", "alert", "record"] {
                        let caption = try XCTUnwrap(facts[target] as? [String: Any])
                        XCTAssertEqual(caption["count"] as? Int, 1, target)
                        XCTAssertEqual(caption[key] as? Bool, true, target)
                        XCTAssertEqual(caption["visible"] as? Bool, true, target)
                        let clipped = try XCTUnwrap(caption["clippedRect"] as? [String: Any])
                        for axis in ["x", "y", "width", "height"] {
                            let value = try XCTUnwrap((clipped[axis] as? NSNumber)?.doubleValue)
                            XCTAssertTrue(value.isFinite && value >= 0, target + "." + axis)
                        }
                    }
                    XCTExpectFailure("C-17 product-missing: narrow Help captions overlap or exceed the viewport") {
                        XCTAssertEqual(facts["allInsideAndSeparate"] as? Bool, true)
                    }
                    _ = try await web.evaluateJavaScript("window.dispatchEvent(new KeyboardEvent('keyup',{key:'Alt'}))")
                    let closedRaw = try await page.g1HelpCaptionFactsForChecks()
                    let closed = try XCTUnwrap(closedRaw)
                    let closedFacts = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(closed.utf8)) as? [String: Any])
                    XCTAssertEqual(closedFacts["open"] as? Bool, false)
                }
                await page.g1CloseAndWaitForTeardown()
                let retired = try await page.g1HelpCaptionFactsForChecks()
                XCTAssertNil(retired, "A retired page must not return observations")
            }
        }
    }
    #endif

    #if MODELPLAN_TEST_ONLY_SPI
    func testG1_CKP_ENG_02_oneAndTwoMembersKeepThreeSlots() async throws {
        for count in [1, 2] {
            try await withLivePage(syntheticAccountCount: count) { _, _, page in
                let web = try XCTUnwrap(page.verificationWebView)
                let script = """
                (() => {
                  const keys = document.querySelector('.eng-keys');
                  if (!keys) return null;
                  return JSON.stringify({slots: keys.dataset.slots,
                    members: keys.querySelectorAll('.ek[data-sub]').length,
                    empty: keys.querySelectorAll('.ek.ek-bay').length,
                    columns: document.querySelectorAll('.eng-cols > .ec').length});
                })()
                """
                let deadline = ContinuousClock.now.advanced(by: .seconds(10))
                var facts: [String: Any]?
                while ContinuousClock.now < deadline {
                    if let raw = try await web.evaluateJavaScript(script) as? String,
                       let object = try JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any],
                       (object["members"] as? NSNumber)?.intValue == count {
                        facts = object
                        break
                    }
                    try await Task.sleep(for: .milliseconds(20))
                }
                let observed = try XCTUnwrap(facts, "The normal entry did not render the synthetic members")
                XCTAssertEqual(observed["slots"] as? String, "3")
                XCTAssertEqual((observed["members"] as? NSNumber)?.intValue, count)
                XCTAssertEqual((observed["empty"] as? NSNumber)?.intValue, 3 - count)
                XCTAssertEqual((observed["columns"] as? NSNumber)?.intValue, 3)
            }
        }
    }
    #endif

    func testG1_CKP_ENT_01_actualFadeAndOutline() async throws {
        try await withLivePage { _, _, page in
            let facts = try await self.geometry(page)
            let duration = try XCTUnwrap(page.g1OpenAnimationDurationForChecks)
            let reduce = facts["reduceMotion"] as? Bool == true
            XCTAssertEqual(duration, reduce ? 0 : 0.18, accuracy: 0.001)
            XCTAssertEqual(facts["rootOutline"] as? String, "none")
        }
    }
    func testG1_CKP_ENT_02_actualRootHasNoClipPath() async throws {
        try await withLivePage { _, _, page in
            let facts = try await self.geometry(page)
            XCTAssertEqual(facts["rootClipPath"] as? String, "none")
            XCTAssertEqual(facts["rootOpacity"] as? String, "1")
        }
    }
    func testG1_CKP_SHELL_18() async throws {
        try await withLivePage { _, _, page in
            XCTAssertTrue(page.g1PageStateForChecks.hasWindow)
            XCTAssertTrue(page.g1PageStateForChecks.hasPage)
            XCTAssertTrue(page.g1PageStateForChecks.ready)
            let facts = try await self.geometry(page)
            XCTAssertNotNil(facts["root"], "The real verified page must expose its cockpit root")
        }
    }
    func testG1_CKP_SHELL_12_baseReserve() async throws {
        try await withLivePage { _, _, page in
            let facts = try await self.geometry(page)
            let rootHeight = try self.dimension(facts, "root", "height")
            let contentHeight = try XCTUnwrap(page.window?.contentView?.bounds.height)
            XCTAssertEqual(Double(contentHeight) - rootHeight, 34, accuracy: 1)
        }
    }
    func testG1_CKP_ENTRY_01_menuAndDockRoutes() async throws {
        try await withLivePage { app, coordinator, initial in
            @MainActor func waitRetired(_ page: CockpitWindowController) async throws {
                let deadline = ContinuousClock.now.advanced(by: .seconds(3))
                while !page.g1PageStateForChecks.disposed && ContinuousClock.now < deadline {
                    try await Task.sleep(for: .milliseconds(20))
                }
                let disposed = page.g1PageStateForChecks.disposed
                XCTAssertTrue(disposed)
            }
            @MainActor func waitNewPage(_ previous: CockpitWindowController) async throws -> CockpitWindowController {
                let deadline = ContinuousClock.now.advanced(by: .seconds(10))
                while ContinuousClock.now < deadline {
                    if let current = coordinator.g1LivePageForChecks, current !== previous, current.g1PageStateForChecks.ready { return current }
                    try await Task.sleep(for: .milliseconds(20))
                }
                throw CockpitBridgeError.unavailable
            }
            initial.requestClose(); try await waitRetired(initial)
            app.composition.dock.setPresentationAllowed(true)
            app.renderMenu()
            let status = try XCTUnwrap(app.liveStatusMenu)
            let statusIndex = try XCTUnwrap(status.items.firstIndex { $0.title == "Open Cockpit" })
            status.performActionForItem(at: statusIndex)
            let fromMenu = try await waitNewPage(initial)
            XCTAssertTrue(fromMenu.g1PageStateForChecks.hasWindow)
            fromMenu.requestClose(); try await waitRetired(fromMenu)
            let dock = app.composition.dock.menu()
            let dockIndex = try XCTUnwrap(dock.items.firstIndex { $0.title == "Open Cockpit" })
            dock.performActionForItem(at: dockIndex)
            let fromDock = try await waitNewPage(fromMenu)
            XCTAssertTrue(fromDock.g1PageStateForChecks.hasWindow)
            XCTAssertTrue(initial.g1PageStateForChecks.disposed)
        }
    }
    func testG1_CKP_SHELL_24_closeControlUsesNonblockingFade() async throws {
        try await withLivePage { _, _, page in
            let facts = try await self.geometry(page)
            let close = try XCTUnwrap(facts["close"] as? [String: Any])
            let x = try XCTUnwrap((close["x"] as? NSNumber)?.doubleValue)
            let y = try XCTUnwrap((close["y"] as? NSNumber)?.doubleValue)
            let width = try XCTUnwrap((close["width"] as? NSNumber)?.doubleValue)
            let height = try XCTUnwrap((close["height"] as? NSNumber)?.doubleValue)
            let window = try XCTUnwrap(page.window)
            let web = try XCTUnwrap(window.contentView?.subviews.first { $0 is WKWebView } as? WKWebView)
            let local = web.convert(CGPoint(x: x + width / 2, y: web.isFlipped ? y + height / 2 : web.bounds.height - y - height / 2), to: nil)
            for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                let event = try XCTUnwrap(NSEvent.mouseEvent(with: type, location: local, modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1))
                window.sendEvent(event)
            }
            let deadline = ContinuousClock.now.advanced(by: .seconds(3))
            while page.g1CloseAnimationDurationForChecks == nil && ContinuousClock.now < deadline {
                try await Task.sleep(for: .milliseconds(20))
            }
            let duration = try XCTUnwrap(page.g1CloseAnimationDurationForChecks)
            let reduce = facts["reduceMotion"] as? Bool == true
            XCTAssertEqual(duration, reduce ? 0 : 0.12, accuracy: 0.001)
            while !page.g1PageStateForChecks.disposed && ContinuousClock.now < deadline {
                try await Task.sleep(for: .milliseconds(20))
            }
            XCTAssertTrue(page.g1PageStateForChecks.disposed)
        }
    }
    func testG1_CKP_SHELL_20_closeRetiresActualPage() async throws {
        try await withLivePage { app, coordinator, page in
            page.requestClose()
            let closeLimit = ContinuousClock.now.advanced(by: .seconds(3))
            while !page.g1PageStateForChecks.disposed && ContinuousClock.now < closeLimit {
                try await Task.sleep(for: .milliseconds(20))
            }
            XCTAssertTrue(page.g1PageStateForChecks.disposed)
            XCTAssertFalse(page.g1PageStateForChecks.hasPage)
            XCTAssertFalse(page.g1PageStateForChecks.hasWindow)
            XCTAssertNil(coordinator.g1LivePageForChecks)
            app.showConsole()
            let reopenLimit = ContinuousClock.now.advanced(by: .seconds(10))
            while coordinator.g1LivePageForChecks?.g1PageStateForChecks.ready != true && ContinuousClock.now < reopenLimit {
                try await Task.sleep(for: .milliseconds(20))
            }
            let reopened = try XCTUnwrap(coordinator.g1LivePageForChecks)
            XCTAssertFalse(reopened === page, "Reopen must construct a new actual page after disposal")
            XCTAssertTrue(reopened.g1PageStateForChecks.ready)
            XCTAssertTrue(reopened.g1PageStateForChecks.hasWindow)
            XCTAssertTrue(page.g1PageStateForChecks.disposed, "The retired page must not revive")
        }
    }
}
#endif
