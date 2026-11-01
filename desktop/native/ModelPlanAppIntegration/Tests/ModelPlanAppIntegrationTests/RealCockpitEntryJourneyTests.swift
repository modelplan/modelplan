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
    func testNormalEntryUsesTheActualPinnedPageAndV2ShellProtocol() throws {
        #if MODELPLAN_TEST_ONLY_SPI
        try runOwnedCocoaLoop {
            try await self.exerciseActualPage()
            try await self.exerciseOwnedTray()
        }
        #else
        throw XCTSkip("Requires the announced WK journey build")
        #endif
    }
    #if MODELPLAN_TEST_ONLY_SPI
    // One NSApplication loop per XCTest process; both actual journeys run
    // inside it, as they do in one normal application lifetime.
    private func runOwnedCocoaLoop(_ journey:@escaping @MainActor () async throws -> Void) throws {
        guard ProcessInfo.processInfo.environment["MODELPLAN_S6_REAL_PAGE"] == "1" else {
            throw XCTSkip("Requires the announced synthetic WK journey window")
        }
        let application = NSApplication.shared; application.setActivationPolicy(.accessory)
        var completion:Result<Void,Error>?
        Task { @MainActor in
            do { try await journey(); completion = .success(()) } catch { completion = .failure(error) }
            application.stop(nil)
            if let wake=NSEvent.otherEvent(with:.applicationDefined,location:.zero,modifierFlags:[],timestamp:0,windowNumber:0,context:nil,subtype:0,data1:0,data2:0) { application.postEvent(wake,atStart:false) }
        }
        application.run(); try XCTUnwrap(completion).get()
    }
    #endif
    #if MODELPLAN_TEST_ONLY_SPI
    private func exerciseActualPage() async throws {
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
        let physical = try XCTUnwrap(NSScreen.main).visibleFrame
        func placement(_ height:CGFloat) -> (CGRect,CGRect) {
            (CGRect(x:physical.minX,y:physical.maxY-height,width:physical.width,height:height),
             CGRect(x:physical.midX-10,y:physical.maxY,width:20,height:22))
        }
        var pages: [CockpitWindowController] = [], clients = 0
        var engine:PinnedPageJourneyEngine?
        var nextRendered: XCTestExpectation?
        let previous = CommunityCockpitApplicationFactory.verificationPage
        defer { CommunityCockpitApplicationFactory.verificationPage = previous; pages.forEach { $0.discard() } }
        CommunityCockpitApplicationFactory.verificationPage = { page in
            page.verificationPlacement = placement(1000)
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
            cockpitRuntime: .init(client: { _, consumer in clients += 1; let value=PinnedPageJourneyEngine(consumer,data:data);engine=value;return value }, onUnavailable: { XCTFail("Actual pinned-page journey became unavailable") }))
        await app.prepare()
        _ = try await app.settingsHost.application.commit(.motion(.on))
        await app.composition.start()
        XCTAssertTrue(pages.isEmpty, "No prewarm or page injection")
        app.composition.dock.setPresentationAllowed(true)
        var observedEntries = 0, retainedScope = "all"
        for entry in ["menu", "dock", "held-ignition", "tray"] {
            if entry == "held-ignition" {
                let options=XCTExpectedFailure.Options(); options.isStrict=true
                XCTExpectFailure("Partial — completed by #408/#397: M0 A5 geometry",options:options) {
                    XCTAssertFalse(app.composition.dock.consoleButton.isHiddenOrHasHiddenAncestor)
                }
                if app.composition.dock.consoleButton.isHiddenOrHasHiddenAncestor { continue }
            }
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
                let button=app.composition.dock.consoleButton, host=try XCTUnwrap(button.superview)
                let centre=button.convert(CGPoint(x:button.bounds.midX,y:button.bounds.midY),to:host)
                let target=try XCTUnwrap(host.hitTest(centre)); XCTAssertTrue(target === button)
                target.mouseDown(with:try XCTUnwrap(NSEvent.mouseEvent(with:.leftMouseDown,location:centre,modifierFlags:[],timestamp:0,windowNumber:0,context:nil,eventNumber:1,clickCount:1,pressure:1)))
            }
            await fulfillment(of: [rendered], timeout: 10)
            observedEntries += 1
            XCTAssertEqual(pages.count,observedEntries)
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
            let restored=try await waitForDOM(page,label:"session scope restored by the next actual load") { $0["scopeKey"] as? String == retainedScope }
            XCTAssertEqual(try XCTUnwrap(page.verificationShellState).scope,retainedScope)
            XCTAssertEqual(restored["scopeKey"] as? String,retainedScope)
            let client=try XCTUnwrap(engine),queries=await client.cockpitQueries
            for key in ["all","0123456789abcdef","all","0123456789abcdef"] {
                let selector=key == "all" ? ".ek-all" : ".eng-keys .ek[data-scope='0123456789abcdef']"
                try await click(selector,page:page)
                try await waitForCondition("current native session validates scope key") { page.verificationShellState?.scope == key }
                _ = try await waitForDOM(page,label:"scope reflects native-confirmed state") { $0["scopeKey"] as? String == key }
            }
            retainedScope="0123456789abcdef"
            let afterScope=await client.cockpitQueries
            XCTAssertEqual(afterScope,queries,"Scope is local session state, not an engine command/query")
            XCTAssertEqual(page.queryTicket,ticket)
            try await click(".ck-head button[aria-label='Detach']", page: page)
            _ = try await waitForDOM(page, label: "detach reaches native and returns Put back") { self.hasControl($0, label:"Put back") }
            XCTAssertFalse(try XCTUnwrap(page.verificationShellState).attached)
            XCTAssertEqual(page.window?.frame, home, "Detach changes layer in place")
            try await click(".ck-head button[aria-label='Put back']", page: page)
            _ = try await waitForDOM(page, label: "put back returns native attachment") { self.hasControl($0, label:"Detach") }
            XCTAssertTrue(try XCTUnwrap(page.verificationShellState).attached)
            try await waitForCondition("put back completes at home") { page.window?.frame == home }

            XCTAssertEqual(dom["userShutterVisible"] as? Bool,false,"User shutter is post-v1; only forced-closed remains exposed")

            page.verificationPlacement = placement(705)
            let forced = try await waitForDOM(page,label:"705pt forces actual compact closed page") { $0["shell"] as? String == "closed" && $0["layout"] as? String == "640" && $0["bodyHeight"] as? Double == 609 }
            XCTAssertEqual(page.verificationRootHeight, 609)
            let state = try XCTUnwrap(page.verificationShellState)
            XCTAssertTrue(state.forcedClosed); XCTAssertEqual(state.tier,.compact)
            XCTAssertEqual(forced["capVisible"] as? Bool,true)
            XCTAssertEqual(forced["runningAnimations"] as? Int,0)
            XCTAssertEqual(forced["capOpenPresent"] as? Bool,false,"v1 has no user-open shutter control")
            XCTAssertEqual(forced["openUnavailable"] as? Bool,true)
            XCTAssertFalse((forced["reason"] as? String ?? "").isEmpty)
            let stillForced = try await snapshot(page)
            XCTAssertEqual(stillForced["shell"] as? String,"closed")
            XCTAssertTrue(try XCTUnwrap(page.verificationShellState).forcedClosed)
            page.verificationPlacement = placement(1000)
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
        XCTAssertEqual(pages.count,observedEntries,"Only actually reachable normal actions are counted; A5 remains an explicit strict dependency")
        XCTAssertEqual(clients, 1)
        app.composition.dock.setPresentationAllowed(false); await app.composition.stop()
    }
    private func exerciseOwnedTray() async throws {
        let bundlePath=try XCTUnwrap(ProcessInfo.processInfo.environment["MODELPLAN_S6_PINNED_BUNDLE"])
        let edition=ProcessInfo.processInfo.environment["MODELPLAN_S6_EDITION"] ?? "community"
        let input=URL(fileURLWithPath:bundlePath)
        _ = try VerifiedCockpitBundle(root:input,manifestSHA256:try XCTUnwrap(CommunityCockpitApplicationFactory.manifestPins[edition]),allowOfficial:edition == "official")
        let directory=FileManager.default.temporaryDirectory.appendingPathComponent("s6-tray-"+UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:directory) }
        let bundle=try makeSyntheticApp(at:directory,cockpit:input,edition:edition)
        let data=try JSONDecoder().decode(WireCockpitData.self,from:Data(contentsOf:nativeRoot.appendingPathComponent("ModelPlanCockpitWeb/Tests/ModelPlanCockpitWebTests/Fixtures/cockpit.json")))
        var pages:[CockpitWindowController]=[], rendered:XCTestExpectation?
        var closeStart:ContinuousClock.Instant?, discardAt:ContinuousClock.Instant?, duration:TimeInterval?
        let previous=CommunityCockpitApplicationFactory.verificationPage
        defer { CommunityCockpitApplicationFactory.verificationPage=previous; pages.forEach { $0.discard() } }
        let physical=try XCTUnwrap(NSScreen.main).visibleFrame
        CommunityCockpitApplicationFactory.verificationPage = { page in
            page.verificationPlacement=(CGRect(x:physical.minX,y:physical.maxY-1000,width:physical.width,height:1000),CGRect(x:physical.midX-10,y:physical.maxY,width:20,height:22))
            page.onRendered={ print("S6 tray rendered"); let expected=rendered; rendered=nil; expected?.fulfill() }
            page.verificationOutsidePress={ type,hit in print("S6 tray outside",type.rawValue,hit) }
            page.verificationCloseOrigin={ print("S6 tray close origin",$0) }
            page.verificationCloseStarted={ seconds in print("S6 tray close started",seconds); closeStart = .now; duration=seconds }
            page.verificationDidDiscard={ print("S6 tray discarded"); discardAt = .now }
            pages.append(page)
        }
        let app=EngineRowsEntry.make(configuration:.init(executableURL:bundle.appendingPathComponent("Contents/Helpers/modelplan"),applicationVersion:"synthetic",allowedEnvironment:[:],offline:true,readOnly:true),settingsStore:try SettingsStore(url:directory.appendingPathComponent("settings.json")),createsNativePanels:false,bundleURL:bundle,cockpitRuntime:.init(client:{ _,consumer in PinnedPageJourneyEngine(consumer,data:data) },onUnavailable:{ XCTFail("Owned tray page unavailable") }))
        defer { app.verificationRemoveStatusItem() }
        app.verificationStatusAction={ type,open in print("S6 tray action",type.rawValue,open) }
        app.applicationDidFinishLaunching(Notification(name:NSApplication.didFinishLaunchingNotification,object:NSApp))
        try await waitForCondition("normal launch produces status button and ready connection") {
            guard app.verificationStatusButton != nil else { return false }
            if case .ready = app.composition.store.snapshot.connection { return true }; return false
        }
        for (reduced,hold) in [(true,0.0),(false,0.18),(false,0.0)] {
            print("S6 tray scenario",reduced,hold,pages.count)
            _ = try await app.settingsHost.application.commit(.motion(.on))
            let ready=expectation(description:"owned status opens real page"); rendered=ready
            try await clickStatus(app,hold:0)
            await fulfillment(of:[ready],timeout:10)
            let page=try XCTUnwrap(pages.last)
            _ = try await waitForDOM(page,label:"owned status page active") { $0["active"] as? String == "true" }
            var environment=SettingsEnvironment(); environment.reduceMotion=false
            app.settingsHost.application.update(environment:environment)
            _ = try await app.settingsHost.application.commit(.motion(reduced ? .on:.system))
            _ = try await waitForDOM(page,label:"tray close motion selected") { $0["reduceMotion"] as? String == String(reduced) }
            closeStart=nil; discardAt=nil; duration=nil
            let count=pages.count, down=ContinuousClock.now
            try await clickStatus(app,hold:hold)
            try await waitForCondition("second owned status click closes") { page.bridge.disposed }
            // Wait beyond the queued mouse-up turn to catch the original reopen.
            try await Task.sleep(for:.milliseconds(180))
            XCTAssertEqual(pages.count,count,"A second status click must close once, never reopen")
            XCTAssertEqual(duration,reduced ? 0:0.12)
            if let start=closeStart,let end=discardAt {
                let delta=start.duration(to:end)
                if !reduced { XCTAssertGreaterThanOrEqual(delta,.milliseconds(100),"Normal tray close must retain the120ms fade") }
                if hold>0.12 { XCTAssertGreaterThanOrEqual(down.duration(to:start),.milliseconds(150),"Tray mouse-down must not start outside dismissal") }
            } else { XCTFail("Missing actual close/disposal observations") }
            XCTAssertNil(page.window)
            for unexpected in pages.dropFirst(count) { unexpected.discard() }
            XCTAssertTrue(app.composition.dock.isPresentationAllowed)
        }
        await app.composition.stop()
    }
    private func clickStatus(_ app:EngineDockMenuApplication,hold:TimeInterval) async throws {
        // Posted in-process events do not carry WindowServer's inactive-app
        // activation token. Establish actual host activity, never fake it.
        NSApp.unhide(nil); NSApp.activate(ignoringOtherApps:true)
        try await waitForCondition("owned status host is actually active") { NSApp.isActive }
        try await waitForCondition("owned status target is actually registered and visible") {
            guard let button=app.verificationStatusButton,let window=button.window else { return false }
            return window.windowNumber>0 && window.isVisible && !button.bounds.isEmpty && !button.isHiddenOrHasHiddenAncestor
        }
        let button=try XCTUnwrap(app.verificationStatusButton),window=try XCTUnwrap(button.window)
        XCTAssertFalse(button.isHiddenOrHasHiddenAncestor)
        let centre=button.convert(CGPoint(x:button.bounds.midX,y:button.bounds.midY),to:nil)
        let host=try XCTUnwrap(button.superview)
        XCTAssertTrue(host.hitTest(button.convert(CGPoint(x:button.bounds.midX,y:button.bounds.midY),to:host)) === button)
        let down=try XCTUnwrap(NSEvent.mouseEvent(with:.leftMouseDown,location:centre,modifierFlags:[],timestamp:ProcessInfo.processInfo.systemUptime,windowNumber:window.windowNumber,context:nil,eventNumber:1,clickCount:1,pressure:1))
        XCTAssertTrue(down.window === window,"Queued input must belong to the actual owned status window")
        let up=try XCTUnwrap(NSEvent.mouseEvent(with:.leftMouseUp,location:centre,modifierFlags:[],timestamp:ProcessInfo.processInfo.systemUptime+hold,windowNumber:window.windowNumber,context:nil,eventNumber:2,clickCount:1,pressure:0))
        let release=StatusRelease(up)
        let timer=Timer(timeInterval:max(0.01,hold),repeats:false) { _ in MainActor.assumeIsolated { release.post() } }
        defer { timer.invalidate() }
        RunLoop.main.add(timer,forMode:.common); NSApp.postEvent(down,atStart:false)
        try await waitForCondition("owned status mouse-up posted") { release.posted }
    }
    @MainActor private final class StatusRelease {
        let event:NSEvent; var posted=false
        init(_ event:NSEvent) { self.event=event }
        func post() { NSApp.postEvent(event,atStart:false); posted=true }
    }
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
        let value = try await evaluate(web: web, code: "const r=document.getElementById('cockpit'),c=document.querySelector('.s6-closed-cap');return {locale:document.documentElement.lang,theme:document.documentElement.dataset.theme,reduceMotion:document.documentElement.dataset.reduceMotion,reduceTransparency:document.documentElement.dataset.reduceTransparency,state:window.modelPlanCockpit?.state(),active:r?.dataset.active,scopeKey:r?.querySelector('.ek[aria-pressed=true]')?.dataset.scope||'all',shell:r?.dataset.shell,layout:r?.dataset.layout,bodyHeight:r?.getBoundingClientRect().height,capVisible:!!c&&!c.hidden&&getComputedStyle(c).display!=='none',capOpenPresent:!!c?.querySelector('button'),openUnavailable:!c?.querySelector('button')||c.querySelector('button').disabled,userShutterVisible:[...document.querySelectorAll('.ck-head button')].some(b=>['Collapse','Open','收起','打开'].includes(b.getAttribute('aria-label'))&&!b.hidden&&!!(b.offsetWidth||b.offsetHeight)),reason:document.getElementById('s6-closed-reason')?.textContent,runningAnimations:document.getAnimations().filter(a=>a.playState==='running').length,buttons:[...document.querySelectorAll('button')].map(b=>({label:b.getAttribute('aria-label')||b.textContent,disabled:b.disabled,hidden:b.hidden,visible:!!(b.offsetWidth||b.offsetHeight)}))};", arguments: [:])
        return try XCTUnwrap(value as? [String: Any])
    }
    private func hasControl(_ dom:[String:Any],label:String,enabled:Bool=true) -> Bool {
        (dom["buttons"] as? [[String:Any]] ?? []).contains { $0["label"] as? String == label && $0["disabled"] as? Bool == !enabled && $0["hidden"] as? Bool == false && $0["visible"] as? Bool == true }
    }
    private func waitForDOM(_ page:CockpitWindowController,label:String,predicate:([String:Any])->Bool) async throws -> [String:Any] {
        let deadline = ContinuousClock.now.advanced(by:.seconds(3))
        var last:[String:Any] = [:]
        repeat {
            let dom = try await snapshot(page); last = dom
            if predicate(dom) { return dom }
            try await Task.sleep(for:.milliseconds(20))
        } while ContinuousClock.now < deadline
        let diagnostic:[String:Any] = ["stage":label,"active":last["active"] ?? "missing","state":last["state"] ?? "missing","shell":last["shell"] ?? "missing","layout":last["layout"] ?? "missing","appActive":NSApp.isActive,"appRunning":NSApp.isRunning,"windowCanBecomeKey":page.window?.canBecomeKey ?? false,"windowOnActiveSpace":page.window?.isOnActiveSpace ?? false,"windowAlpha":page.window?.alphaValue ?? -1,"windowVisible":page.window?.isVisible ?? false,"windowKey":page.window?.isKeyWindow ?? false,"windowOccluded":!(page.window?.occlusionState.contains(.visible) ?? false)]
        print("S6 synthetic window status:",diagnostic)
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
    var cockpitQueries=0
    let context = EngineDeliveryContext(sessionID: "s-00000000-0000-0000-0000-000000000001", floor: .init(storeEpoch: "synthetic-s6", generation: 1), revision: 1)
    init(_ consumer: any EngineClientEventConsumer, data: WireCockpitData) { self.consumer = consumer; self.data = data }
    func start() async throws -> EngineDeliveryContext { await consumer.consume(.connection(.ready(context))); return context }
    func retry() async throws -> EngineDeliveryContext { try await start() }
    func stop() async {}
    func subscribeRows(timeout: Duration?) async throws -> EngineRequestCompletion { .init(requestID: .string("synthetic")) }
    func cockpit(timeout: Duration?) async throws -> EngineRequestCompletion {
        cockpitQueries += 1
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
