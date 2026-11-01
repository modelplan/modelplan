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
/// The opt-in is NOT GUI authorization: use the coordinator's #699 grant,
/// announce a start/end window of at most20 minutes on #570, and first adopt
/// the matching #399 production bundle. No real account/Keychain scope exists.
@MainActor final class RealCockpitEntryJourneyTests: XCTestCase {
    func testNormalEntryUsesTheActualPinnedPageAndV2ShellProtocol() async throws {
        #if MODELPLAN_TEST_ONLY_SPI
        guard ProcessInfo.processInfo.environment["MODELPLAN_S6_REAL_PAGE"] == "1",
              let bundlePath = ProcessInfo.processInfo.environment["MODELPLAN_S6_PINNED_BUNDLE"] else {
            throw XCTSkip("Requires an announced synthetic WK window and the matching #399 bundle")
        }
        guard CommunityCockpitApplicationFactory.webSource != "f25e1e821411bdd58cb09d9a388b9064505e856c" else {
            throw XCTSkip("The #399 source and reviewed bundle hashes are not available/adopted yet")
        }
        let edition = ProcessInfo.processInfo.environment["MODELPLAN_S6_EDITION"] ?? "community"
        guard ["community","official"].contains(edition) else { XCTFail("Unknown test edition"); return }
        let input = URL(fileURLWithPath: bundlePath)
        _ = try VerifiedCockpitBundle(root: input, manifestSHA256: try XCTUnwrap(CommunityCockpitApplicationFactory.manifestPins[edition]), allowOfficial:edition == "official")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("s6-real-page-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let bundle = try makeSyntheticApp(at: directory, cockpit: input, edition:edition)
        let data = try JSONDecoder().decode(WireCockpitData.self, from: Data(contentsOf: nativeRoot.appendingPathComponent("ModelPlanCockpitWeb/Tests/ModelPlanCockpitWebTests/Fixtures/cockpit.json")))
        var pages: [CockpitWindowController] = [], clients = 0
        var nextRendered: XCTestExpectation?
        let previous = CommunityCockpitApplicationFactory.verificationPage
        defer { CommunityCockpitApplicationFactory.verificationPage = previous; pages.forEach { $0.discard() } }
        CommunityCockpitApplicationFactory.verificationPage = { page in
            page.verificationPlacement = (CGRect(x: 0, y: 0, width: 1400, height: 1000), CGRect(x: 700, y: 1000, width: 20, height: 22))
            page.verificationDidOpen = { [weak page] web, _ in
                XCTAssertTrue(web.isHidden, "First paint waits for the initial frozen shell load")
                XCTAssertFalse(page?.bridge.ready ?? true)
            }
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
        for entry in ["menu", "dock", "held-ignition", "tray"] {
            _ = try await app.settingsHost.application.editor.commit(SettingsB21Edit.language(.english))
            let rendered = expectation(description: entry + " real pinned page render"); nextRendered = rendered
            if entry == "menu" {
                let menu = try XCTUnwrap(app.liveStatusMenu)
                menu.performActionForItem(at: try XCTUnwrap(menu.items.firstIndex { $0.title == "Open Cockpit / 打开驾驶舱" }))
            } else if entry == "dock" {
                let menu = app.composition.dock.menu()
                menu.performActionForItem(at: try XCTUnwrap(menu.items.firstIndex { $0.title == "Open Cockpit / 打开驾驶舱" }))
            } else if entry == "tray" {
                app.toggleCockpit()
            } else {
                app.composition.dock.consoleButton.mouseDown(with: try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, eventNumber: 1, clickCount: 1, pressure: 1)))
            }
            await fulfillment(of: [rendered], timeout: 10)
            let page = try XCTUnwrap(pages.last)
            XCTAssertEqual(page.bridge.appearanceVersion, 2)
            XCTAssertFalse(try XCTUnwrap(page.verificationWebView).isHidden)
            XCTAssertEqual(page.bridge.readyCapabilities, ["appearanceUpdates", "shellState", "shellActions"])
            XCTAssertFalse(app.composition.dock.isPresentationAllowed)
            let dom = try await snapshot(page)
            XCTAssertEqual(dom["locale"] as? String, "en")
            XCTAssertEqual(dom["theme"] as? String, "night")
            _ = try await waitForDOM(page, label: "initial tall open page") { $0["active"] as? String == "true" && $0["shell"] as? String == "open" && $0["layout"] as? String == "890" }
            let ticket = page.queryTicket, home = try XCTUnwrap(page.window).frame
            try await click(".ck-head button[aria-label='Detach']", page: page)
            _ = try await waitForDOM(page, label: "detach reaches native and returns Put back") { self.hasControl($0, label:"Put back") }
            XCTAssertFalse(try XCTUnwrap(page.verificationShellState).attached)
            XCTAssertEqual(page.window?.frame, home, "Detach changes layer in place")
            try await click(".ck-head button[aria-label='Put back']", page: page)
            _ = try await waitForDOM(page, label: "put back returns native attachment") { self.hasControl($0, label:"Detach") }
            XCTAssertTrue(try XCTUnwrap(page.verificationShellState).attached)
            try await waitForCondition("put back completes at home") { page.window?.frame == home }

            try await click(".ck-head button[aria-label='Collapse']", page: page)
            let closed = try await waitForDOM(page, label:"real closed cap") { $0["shell"] as? String == "closed" && $0["bodyHeight"] as? Double == 691 }
            XCTAssertEqual(closed["capVisible"] as? Bool, true)
            XCTAssertEqual(closed["runningAnimations"] as? Int, 0)
            XCTAssertTrue(hasControl(closed,label:"Open"), "The closed page keeps its open control usable")
            XCTAssertEqual(page.verificationRootHeight, 691)
            try await click(".ck-head button[aria-label='Open']", page: page)
            _ = try await waitForDOM(page,label:"shutter reopens") { $0["shell"] as? String == "open" }

            page.verificationPlacement = (CGRect(x:0,y:0,width:1400,height:705),CGRect(x:700,y:705,width:20,height:22))
            let forced = try await waitForDOM(page,label:"705pt forces actual compact closed page") { $0["shell"] as? String == "closed" && $0["layout"] as? String == "640" && $0["bodyHeight"] as? Double == 609 }
            XCTAssertEqual(page.verificationRootHeight, 609)
            let state = try XCTUnwrap(page.verificationShellState)
            XCTAssertTrue(state.forcedClosed); XCTAssertEqual(state.tier,.compact)
            XCTAssertEqual(forced["capVisible"] as? Bool,true)
            XCTAssertEqual(forced["runningAnimations"] as? Int,0)
            XCTAssertTrue(hasControl(forced,label:"Open",enabled:false))
            XCTAssertFalse((forced["reason"] as? String ?? "").isEmpty)
            try await click(".ck-head button[aria-label='Open']",page:page,requiresEnabled:false)
            let stillForced = try await snapshot(page)
            XCTAssertEqual(stillForced["shell"] as? String,"closed")
            XCTAssertTrue(try XCTUnwrap(page.verificationShellState).forcedClosed)
            page.verificationPlacement = (CGRect(x:0,y:0,width:1400,height:1000),CGRect(x:700,y:1000,width:20,height:22))
            _ = try await waitForDOM(page,label:"resize restores saved open intent") { $0["shell"] as? String == "open" && $0["layout"] as? String == "890" }
            XCTAssertFalse(try XCTUnwrap(page.verificationShellState).forcedClosed)

            var environment = SettingsEnvironment(); environment.reduceMotion=false; environment.reduceTransparency=false
            app.settingsHost.application.update(environment:environment)
            _ = try await app.settingsHost.application.commit(.motion(.system))
            _ = try await app.settingsHost.application.commit(.transparency(.system))
            _ = try await waitForDOM(page,label:"live motion/transparency false") { $0["reduceMotion"] as? String == "false" && $0["reduceTransparency"] as? String == "false" }
            _ = try await app.settingsHost.application.commit(.motion(.on))
            _ = try await app.settingsHost.application.commit(.transparency(.on))
            _ = try await app.settingsHost.application.commit(.theme(.day))
            _ = try await app.settingsHost.application.editor.commit(SettingsB21Edit.language(.chinese))
            let chinese = try await waitForDOM(page,label:"live Chinese/Night/reduced appearance") { $0["locale"] as? String == "zh-CN" && $0["theme"] as? String == "night" && $0["reduceMotion"] as? String == "true" && $0["reduceTransparency"] as? String == "true" }
            XCTAssertTrue(hasControl(chinese,label:"关闭"))
            XCTAssertEqual(page.queryTicket,ticket,"Appearance and layout do not retag private data or reload")
            try await click(".ck-head button[aria-label='关闭']",page:page)
            try await waitForCondition("page Close disposes the real window") { page.bridge.disposed }
            XCTAssertNil(page.verificationWebView); XCTAssertNil(page.window)
            XCTAssertTrue(app.composition.dock.isPresentationAllowed)

        }
        XCTAssertEqual(pages.count,4, "All four normal actions create fresh production pages")
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
    private func makeSyntheticApp(at root: URL, cockpit: URL, edition:String) throws -> URL {
        let bundle = root.appendingPathComponent("Synthetic.app"), resources = bundle.appendingPathComponent("Contents/Resources"), helpers = bundle.appendingPathComponent("Contents/Helpers")
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: helpers, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: cockpit, to: resources.appendingPathComponent("Cockpit"))
        try JSONSerialization.data(withJSONObject:["edition":edition]).write(to:resources.appendingPathComponent("build-edition.json"))
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
        let value = try await evaluate(web: web, code: "const r=document.getElementById('cockpit'),c=document.querySelector('.s6-closed-cap');return {locale:document.documentElement.lang,theme:document.documentElement.dataset.theme,reduceMotion:document.documentElement.dataset.reduceMotion,reduceTransparency:document.documentElement.dataset.reduceTransparency,state:window.modelPlanCockpit?.state(),active:r?.dataset.active,shell:r?.dataset.shell,layout:r?.dataset.layout,bodyHeight:r?.getBoundingClientRect().height,capVisible:!!c&&!c.hidden&&getComputedStyle(c).display!=='none',reason:document.getElementById('s6-closed-reason')?.textContent,runningAnimations:document.getAnimations().filter(a=>a.playState==='running').length,buttons:[...document.querySelectorAll('button')].map(b=>({label:b.getAttribute('aria-label')||b.textContent,disabled:b.disabled,hidden:b.hidden,visible:!!(b.offsetWidth||b.offsetHeight)}))};", arguments: [:])
        return try XCTUnwrap(value as? [String: Any])
    }
    private func hasControl(_ dom:[String:Any],label:String,enabled:Bool=true) -> Bool {
        (dom["buttons"] as? [[String:Any]] ?? []).contains { $0["label"] as? String == label && $0["disabled"] as? Bool == !enabled && $0["hidden"] as? Bool == false && $0["visible"] as? Bool == true }
    }
    private func waitForDOM(_ page:CockpitWindowController,label:String,predicate:([String:Any])->Bool) async throws -> [String:Any] {
        let deadline = ContinuousClock.now.advanced(by:.seconds(3))
        repeat {
            let dom = try await snapshot(page)
            if predicate(dom) { return dom }
            try await Task.sleep(for:.milliseconds(20))
        } while ContinuousClock.now < deadline
        XCTFail(label); throw ScriptFailure.deadline
    }
    private func waitForCondition(_ label:String,predicate:()->Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by:.seconds(3))
        repeat { if predicate() { return }; try await Task.sleep(for:.milliseconds(20)) } while ContinuousClock.now < deadline
        XCTFail(label); throw ScriptFailure.deadline
    }
    /// Dispatch only to this test's owned WK window. No global input, private
    /// WebKit API or forged page-to-native action envelope is used.
    private func click(_ selector: String, page: CockpitWindowController, requiresEnabled:Bool=true) async throws {
        let web = try XCTUnwrap(page.verificationWebView), window = try XCTUnwrap(web.window)
        let value = try await evaluate(web: web, code: "const b=document.querySelector(selector);if(!b||(requiresEnabled&&b.disabled))throw Error('control-unavailable');const r=b.getBoundingClientRect();return {x:r.x+r.width/2,y:r.y+r.height/2};", arguments: ["selector":selector,"requiresEnabled":requiresEnabled])
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
