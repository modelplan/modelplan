// SPDX-License-Identifier: MIT
import AppKit
import CryptoKit
import WebKit
import XCTest
import ModelPlanSettings
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanDock
@testable import ModelPlanCockpitWeb
import ModelPlanWire
@testable import ModelPlanAppIntegration

actor RouteClient: EngineClient { // internal: the real-page size test (OwnerTestCockpitPageTests) routes through it too
    nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool { false }
    var stops=0
    var holdCockpit=false
    var cockpitWaiter:CheckedContinuation<EngineRequestCompletion,Error>?
    var cockpitPending:Bool { cockpitWaiter != nil }
    func suspendCockpit(){holdCockpit=true}
    func failCockpit(){cockpitWaiter?.resume(throwing:EngineClientError.featureDecode(.cockpit));cockpitWaiter=nil}
    func start() throws -> EngineDeliveryContext { throw EngineClientError.notReady }
    func retry() throws -> EngineDeliveryContext { throw EngineClientError.notReady }
    func stop() { stops += 1 }
    func cockpit(timeout:Duration?) async throws -> EngineRequestCompletion {
        if holdCockpit { return try await withCheckedThrowingContinuation { cockpitWaiter=$0 } }
        throw EngineClientError.unsupportedCapability
    }
    func subscribeRows(timeout:Duration?) throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func consent(timeout:Duration?) throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func grant(_ request:WireConsentGrantParams,userAction:EngineUserAction?,timeout:Duration?) throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func refresh(_ request:WireRefreshRequestParams,timeout:Duration?) throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func history(_ query:WireHistoryQueryParams,timeout:Duration?) throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func pluginInstall(_ request:WirePluginInstallParams,timeout:Duration?) throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func publication(timeout:Duration?) throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func diagnostics(timeout:Duration?) throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
}
@MainActor private final class ConsoleRouteProbe:EngineRowsConsoleSurface {
    var shows=0
    func show(){shows += 1}
    func render(){}
    func hide(){}
}

@MainActor private final class ClearSink: EngineStoreSink {
    var cleared=false
    func clearPrivateViews(_ invalidation:EngineInvalidation){cleared=true}
    func apply(_ snapshot:EngineStoreSnapshot){}
}
@MainActor private final class ClearingPage:CockpitPageSurface {
    let state:CockpitBridgeState
    let sink:ClearSink
    var onReady:(()->Void)?,onIntent:((CockpitIntent)->Void)?,onClosed:(()->Void)?
    var waiter:CheckedContinuation<Void,Never>?
    var sawStoreClearFirst=false
    var queryTicket:CockpitQueryTicket?{state.queryTicket}
    init(_ context:CockpitEngineContext,sink:ClearSink){state = .init(context:context);self.sink=sink}
    func open(){
        let raw=try! state.load(.init(theme:.day,locale:.en,profile:.full),shell:.init(closed:false,attached:true,forcedClosed:false,tier:.tall))
        var value=try! JSONSerialization.jsonObject(with:Data(raw.utf8)) as! [String:Any]
        value["appearance"]=nil;value["shell"]=nil;value["redBelow"] = nil; value["showUsedPercent"] = nil; value["showAllModels"] = nil;value["type"]="ready";value["sequence"]="1"
        value["appearanceVersion"]=2;value["capabilities"]=["appearanceUpdates","shellState","shellActions"]
        _=try! state.accept(String(decoding:try! JSONSerialization.data(withJSONObject:value),as:UTF8.self),source:.init(mainFrame:true,origin:"modelplan-cockpit://bundle"));onReady?()
    }
    func display(_ data:WireCockpitData,ticket:CockpitQueryTicket){}
    func clearPrivateViews(adopting:CockpitEngineContext?) async {
        sawStoreClearFirst=sink.cleared
        _=try! state.clear(adopting:adopting)
        await withCheckedContinuation{waiter=$0}
    }
    func discard(){state.dispose();onClosed?()}
    var appearances:[CockpitAppearance]=[]
    func updateAppearance(_ appearance:CockpitAppearance){appearances.append(appearance)}
}

final class CommunityCockpitEntryTests:XCTestCase {
    // verificationPlacement is test-only SPI; u11-native defines MODELPLAN_TEST_ONLY_SPI and runs this class.
    #if MODELPLAN_TEST_ONLY_SPI
    private func d88Bundle() throws -> VerifiedCockpitBundle {
      let root = FileManager.default.temporaryDirectory.appendingPathComponent("cockpit-d88-" + UUID().uuidString)
      try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
      addTeardownBlock { try? FileManager.default.removeItem(at: root) }
      let html = Data("synthetic".utf8); try html.write(to: root.appendingPathComponent("index.html"))
      let manifest = try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "edition": "community", "interfaceOnly": true, "files": ["index.html": VerifiedCockpitBundle.digest(html)]])
      try manifest.write(to: root.appendingPathComponent("bundle-manifest.json"))
      return try VerifiedCockpitBundle(root: root, manifestSHA256: VerifiedCockpitBundle.digest(manifest))
    }

    /// CKP-SHELL-07 with D88: at 85 % a resize (grow animation, snap-back) must keep the scaled canvas and page
    /// zoom, and the one-time hint anchor must sit on the detach key as drawn at that scale.
    @MainActor func testD88ScaledCockpitKeepsBoundsZoomAndHintAnchorAfterResize() throws {
      guard NSScreen.main != nil else { throw XCTSkip("needs a display") }
      _ = NSApplication.shared
      let usable = CGRect(x: 0, y: 0, width: 1440, height: 876)
      let icon = CGRect(x: 700, y: usable.maxY, width: 28, height: 24)
      let context = try CockpitEngineContext(sessionID: UUID(), storeEpoch: "synthetic", generation: 1)
      let session = CockpitShellSession()
      let page = CockpitWindowController(bundle: try d88Bundle(), context: context,
        appearance: .init(theme: .night, locale: .en, profile: .full, reduceMotion: true, size: .percent85),
        shellSession: session, anchor: { icon })
      page.verificationPlacement = (usable: usable, anchor: icon)
      defer { page.discard() }
      session.nextEntrance = .fade
      page.open()
      let window = try XCTUnwrap(page.window)
      (window.contentView?.subviews.first as? WKWebView)?.navigationDelegate = nil
      let layout = try XCTUnwrap(CockpitShellLayout.fit(usable: usable, anchor: icon, shutterClosed: false, size: .percent85, screenWidth: usable.width))
      XCTAssertEqual(layout.scale, 0.85, accuracy: 0.001)
      let content = try XCTUnwrap(window.contentView)
      let web = try XCTUnwrap(content.subviews.first as? WKWebView)
      // A resize (as the grow animation and a snap-back do) must not undo the scaled canvas.
      window.setFrame(layout.frame.insetBy(dx: 40, dy: 40), display: true)
      window.setFrame(layout.frame, display: true)
      XCTAssertEqual(content.bounds.size, window.frame.size, "bounds stay the scaled frame after a resize")
      XCTAssertEqual(web.pageZoom, 0.85, accuracy: 0.001, "the page zoom stays the layout scale")
      // The anchor lands on the detach key at the page position times the scale; the page is top-anchored in the
      // whole-point window, so the key is measured from the window's top edge (2 CSS px below the canvas top).
      let anchor = try XCTUnwrap(page.attachmentHintAnchor)
      let size = CockpitWindowController.attachmentKeySize
      let key = CGRect(x: window.frame.minX + CockpitWindowController.attachmentKeyX * 0.85, y: window.frame.maxY - (size + 2) * 0.85,
                       width: size * 0.85, height: size * 0.85)
      XCTAssertEqual(anchor.frame.midX, key.midX, accuracy: 0.5)
      XCTAssertEqual(anchor.frame.midY, key.midY, accuracy: 0.5)
      XCTAssertTrue(window.frame.contains(anchor.frame))
    }
    #endif
    @MainActor private func shellFixture() throws -> (CockpitConsoleOwner, VerifiedCockpitBundle, CockpitEngineContext, CGRect) {
        guard ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] == "true", let screen=NSScreen.main,
              screen.visibleFrame.height > 706, screen.visibleFrame.width > 700 else {
            throw XCTSkip("Requires the CI graphical session and a display large enough for the shell")
        }
        let root=FileManager.default.temporaryDirectory.appendingPathComponent("shell-entry-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        addTeardownBlock { try? FileManager.default.removeItem(at:root) }
        func digest(_ data:Data) -> String { SHA256.hash(data:data).map { String(format:"%02x",$0) }.joined() }
        let html=Data("<html>synthetic</html>".utf8)
        try html.write(to:root.appendingPathComponent("index.html"))
        let manifest=try JSONSerialization.data(withJSONObject:["schemaVersion":1,"edition":"community","interfaceOnly":true,"files":["index.html":digest(html)]])
        try manifest.write(to:root.appendingPathComponent("bundle-manifest.json"))
        let verified=try VerifiedCockpitBundle(root:root,manifestSHA256:digest(manifest))
        let settings=try EngineRowsEntry.makeSettingsStore(applicationSupport:root.appendingPathComponent("settings"))
        let owner=CockpitConsoleOwner(bundle:root,settingsStore:settings)
        owner.appearance = .init(theme:.night,locale:.en,profile:.full,reduceMotion:true)
        let anchor=CGRect(x:screen.visibleFrame.midX,y:screen.visibleFrame.maxY,width:20,height:20)
        owner.anchor = { anchor }
        let context=try CockpitEngineContext(sessionID:UUID(),storeEpoch:"synthetic",generation:1)
        return (owner,verified,context,anchor)
    }
    @MainActor func testNormalFactoryReopenRetainsDetachedPositionAndShutter() throws {
        let (owner,bundle,context,anchor)=try shellFixture()
        let first=owner.makePage(context:context,verified:bundle)
        first.open()
        let window=try XCTUnwrap(first.window)
        first.setAttached(false)
        first.toggleShutter()
        // The scaled cockpit (D51) fills the room above the Dock, so the open window's bottom edge is the screen's lowest allowed y;
        // move up, not down, or the remembered origin would be clamped back and the position could not be told from a clamp.
        let origin=CGPoint(x:window.frame.minX-20,y:window.frame.minY+20)
        window.setFrameOrigin(origin)
        first.discard()
        let second=owner.makePage(context:context,verified:bundle)
        defer { second.discard() }
        second.open()
        XCTAssertTrue(owner.shell.detached)
        XCTAssertTrue(owner.shell.shutterClosed)
        let reopened=try XCTUnwrap(second.window)
        XCTAssertEqual(reopened.frame.origin.x,origin.x,accuracy:1)
        XCTAssertEqual(reopened.frame.origin.y,origin.y,accuracy:1)
        let fit=try XCTUnwrap(CockpitShellLayout.fit(usable:try XCTUnwrap(NSScreen.main).visibleFrame,anchor:anchor,shutterClosed:true))
        XCTAssertEqual(reopened.frame.height,fit.frame.height,accuracy:1)
    }
    @MainActor func testNormalFactoryTrayPressDoesNotCloseButOutsidePressDoes() throws {
        let (owner,bundle,context,anchor)=try shellFixture()
        let page=owner.makePage(context:context,verified:bundle)
        defer { page.discard() }
        page.open()
        page.outsidePress(CGPoint(x:anchor.midX,y:anchor.midY),eventType:.leftMouseDown)
        XCTAssertFalse(page.bridge.disposed)
        page.outsidePress(CGPoint(x:anchor.maxX+40,y:anchor.midY),eventType:.leftMouseDown)
        XCTAssertTrue(page.bridge.disposed)
    }
    @MainActor func testNormalEntryDockAndMenuToggleRestoresDetachedShell() async throws {
        let (owner,bundle,context,anchor)=try shellFixture()
        let client=RouteClient()
        var pages:[CockpitWindowController]=[]
        let coordinator=EngineCockpitCoordinator { context in
            let page=owner.makePage(context:context,verified:bundle);pages.append(page);return page
        }
        coordinator.bind(client:client);owner.coordinator=coordinator
        let delivery=EngineDeliveryContext(sessionID:"s-"+context.sessionID.uuidString.lowercased(),floor:.init(storeEpoch:context.storeEpoch,generation:context.generation),revision:1)
        await coordinator.consume(.context(delivery))
        let app=EngineRowsEntry.make(configuration:.init(executableURL:URL(fileURLWithPath:"/synthetic/not-launched"),applicationVersion:"synthetic",allowedEnvironment:[:]),settingsStore:owner.settingsStore,createsNativePanels:false,cockpitEntryEnabled:true,
            makeClient:{_,_ in client},makeConsole:{ composition in
                SharedEngineCockpitConsole(owner:owner,composition:composition,activate:{})
            },activateSettings:{})
        app.composition.dock.setPresentationAllowed(true)
        _=app.composition.dock.perform(NSSelectorFromString("openConsole"))
        for _ in 0..<100 { if pages.count == 1 { break }; await Task.yield() }
        let first=try XCTUnwrap(pages.first)
        let window=try XCTUnwrap(first.window)
        first.setAttached(false);first.toggleShutter()
        // The scaled cockpit (D51) fills the room above the Dock, so the open window's bottom edge is the screen's lowest allowed y;
        // move up, not down, or the remembered origin would be clamped back and the position could not be told from a clamp.
        let origin=CGPoint(x:window.frame.minX-20,y:window.frame.minY+20)
        window.setFrameOrigin(origin)
        app.toggleConsole() // G3-40: only the status icon toggles; the menu item only opens
        for _ in 0..<200 where !first.bridge.disposed { try await Task.sleep(for:.milliseconds(10)) }
        XCTAssertTrue(first.bridge.disposed)
        _=app.composition.dock.perform(NSSelectorFromString("openConsole"))
        for _ in 0..<100 { if pages.count == 2 { break }; await Task.yield() }
        XCTAssertEqual(pages.count,2)
        let second=try XCTUnwrap(pages.last)
        let reopened=try XCTUnwrap(second.window)
        XCTAssertTrue(owner.shell.detached);XCTAssertTrue(owner.shell.shutterClosed)
        XCTAssertEqual(reopened.frame.origin.x,origin.x,accuracy:1)
        XCTAssertEqual(reopened.frame.origin.y,origin.y,accuracy:1)
        let fit=try XCTUnwrap(CockpitShellLayout.fit(usable:try XCTUnwrap(NSScreen.main).visibleFrame,anchor:anchor,shutterClosed:true))
        XCTAssertEqual(reopened.frame.height,fit.frame.height,accuracy:1)
        second.discard();await coordinator.shutdown();await app.composition.stop()
    }
    /// G3-108 (owner, build 14e) through the normal entry: the Dock's console button opens the cockpit through the real
    /// composition with the cockpit entry enabled, and the page's shutterToggle intent (the controller's handler) closes
    /// and reopens the porthole. Attached, the top edge stays under the icon and the body slides by the porthole band
    /// in one motion; detached, the body (bottom edge) never moves and only the top edge does. Never rescaled: the
    /// content bounds follow the live frame and the web view keeps the open canvas. CKP-PORT-09 (amended G3-108, 250 ms),
    /// CKP-SHELL-07 (closing keeps the open scale), CKP-SHELL-05.
    @MainActor func testG3_108NormalEntryShutterMovesOnlyWhereTheOwnerAsked() async throws {
        let (owner,bundle,context,_)=try shellFixture()
        owner.appearance = .init(theme:.night,locale:.en,profile:.full,reduceMotion:false)
        let client=RouteClient()
        var pages:[CockpitWindowController]=[]
        let coordinator=EngineCockpitCoordinator { context in
            let page=owner.makePage(context:context,verified:bundle);pages.append(page);return page
        }
        coordinator.bind(client:client);owner.coordinator=coordinator
        let delivery=EngineDeliveryContext(sessionID:"s-"+context.sessionID.uuidString.lowercased(),floor:.init(storeEpoch:context.storeEpoch,generation:context.generation),revision:1)
        await coordinator.consume(.context(delivery))
        let app=EngineRowsEntry.make(configuration:.init(executableURL:URL(fileURLWithPath:"/synthetic/not-launched"),applicationVersion:"synthetic",allowedEnvironment:[:]),settingsStore:owner.settingsStore,createsNativePanels:false,cockpitEntryEnabled:true,
            makeClient:{_,_ in client},makeConsole:{ composition in
                SharedEngineCockpitConsole(owner:owner,composition:composition,activate:{})
            },activateSettings:{})
        app.composition.dock.setPresentationAllowed(true)
        _=app.composition.dock.perform(NSSelectorFromString("openConsole"))
        for _ in 0..<100 { if pages.count == 1 { break }; await Task.yield() }
        let page=try XCTUnwrap(pages.first), window=try XCTUnwrap(page.window)
        let content=try XCTUnwrap(window.contentView), web=try XCTUnwrap(content.subviews.first as? WKWebView)
        web.navigationDelegate=nil
        try await Task.sleep(for:.milliseconds(400))
        let scale=web.pageZoom, canvas=web.frame.size
        let band=((253-CockpitShellLayout.closedSlabBand)*scale).rounded(.down)
        func toggle() async throws -> [CGRect] {
            var frames=[window.frame]
            page.toggleShutter()
            let deadline=ContinuousClock.now + .seconds(2)
            var still=0
            while ContinuousClock.now < deadline, still < 20 {
                frames.append(window.frame)
                XCTAssertEqual(content.bounds.size.width,window.frame.width,accuracy:0.5,"never rescaled")
                XCTAssertEqual(content.bounds.size.height,window.frame.height,accuracy:0.5,"never rescaled")
                XCTAssertEqual(web.frame.size,canvas,"the page canvas never changes");XCTAssertEqual(web.frame.minY,0)
                still = frames[frames.count-2]==window.frame && !page.shutterMoving && !page.shutterPending ? still+1 : 0
                try await Task.sleep(for:.milliseconds(5))
            }
            XCTAssertEqual(web.pageZoom,scale,"the toggle never changes the fit scale")
            return frames
        }
        // Attached.
        let start=window.frame
        let closing=try await toggle()
        XCTAssertTrue(owner.shell.shutterClosed)
        for frame in closing { XCTAssertEqual(frame.maxY,start.maxY,accuracy:0.5,"attached, the top edge stays under the icon") }
        XCTAssertEqual(window.frame.minY-start.minY,band,accuracy:0.5,"the body rose by the porthole band")
        XCTAssertTrue(closing.contains { $0.minY > start.minY+1 && $0.minY < start.minY+band-1 },"one motion, not a jump: \(closing.map(\.minY))")
        let opening=try await toggle()
        for frame in opening { XCTAssertEqual(frame.maxY,start.maxY,accuracy:0.5) }
        XCTAssertEqual(window.frame,start)
        // Detached, lowered so the porthole has room above in both states.
        page.setAttached(false)
        window.setFrameOrigin(.init(x:window.frame.minX,y:window.frame.minY-60))
        let floating=window.frame
        let detachedClose=try await toggle()
        for frame in detachedClose { XCTAssertEqual(frame.minY,floating.minY,accuracy:0.5,"detached, the body never moves") }
        XCTAssertEqual(window.frame.maxY,floating.maxY-band,accuracy:0.5,"only the top edge came down")
        let detachedOpen=try await toggle()
        for frame in detachedOpen { XCTAssertEqual(frame.minY,floating.minY,accuracy:0.5) }
        XCTAssertEqual(window.frame,floating)
        page.discard();await coordinator.shutdown();await app.composition.stop()
    }
    // G3-13 / R-06: exercise the ordinary entry and real CLI transport. No
    // refresh or second subscription is sent after the synthetic local update.
    @MainActor func testG313RealCLIRecoversRetainedWeeklyCard() async throws {
        guard let binary = ProcessInfo.processInfo.environment["MODELPLAN_U11_TEST_CLI"], !binary.isEmpty else {
            if ProcessInfo.processInfo.environment["MODELPLAN_U11_TEST_REQUIRED"] == "1" {
                XCTFail("U11 must provide the real synthetic-test CLI")
                throw CancellationError()
            }
            throw XCTSkip("Build the real synthetic-test CLI for the normal-entry recovery test")
        }
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: binary), "U11 CLI must be executable")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("g313-entry-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let sessions = root.appendingPathComponent(".codex/sessions/2026/11/05", isDirectory: true)
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        let log = sessions.appendingPathComponent("rollout-synthetic.jsonl")
        let old = Date().addingTimeInterval(-3 * 3600 - 10)
        func record(_ at: Date, used: Int) throws -> Data {
            let formatter = ISO8601DateFormatter()
            let value: [String: Any] = ["timestamp": formatter.string(from: at), "type": "event_msg",
                "payload": ["type": "token_count", "rate_limits": ["limit_id": "codex", "plan_type": "plus",
                    "primary": ["used_percent": used, "window_minutes": 10080,
                                "resets_at": Int(Date().addingTimeInterval(86400).timeIntervalSince1970)]]]]
            var data = try JSONSerialization.data(withJSONObject: value)
            data.append(0x0a)
            return data
        }
        try record(old, used: 80).write(to: log)
        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: root.appendingPathComponent("settings"), preferredLanguages: ["en-US"])
        let app = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: binary),
            applicationVersion: "g313-synthetic", allowedEnvironment: ["HOME": root.path, "TMPDIR": root.path, "PATH": "/usr/bin:/bin"], offline: true),
            settingsStore: settings, createsNativePanels: false, dockEnvironment: normalEntryTestEnvironment, activateSettings: {})
        do {
            await app.prepare()
            await app.composition.start()
            var memberID: String?
            var oldCard: DockCardContent?
            for _ in 0..<300 {
                if let member = app.composition.accountMembers.members.first(where: { $0.rowID == "codex" }),
                   let card = try app.composition.dock.cardContent(for: member.id), card.stateLabel.contains("Stale") {
                    memberID = member.id; oldCard = card; break
                }
                try await Task.sleep(for: .milliseconds(50))
            }
            let id = try XCTUnwrap(memberID, "the real CLI must deliver a retained Codex card")
            let before = try XCTUnwrap(oldCard)
            XCTAssertTrue(before.sourceAndAge.contains("Local history"), before.sourceAndAge)
            XCTAssertTrue(before.sourceAndAge.contains("3h ago"), before.sourceAndAge)
            XCTAssertTrue(before.stateLabel.contains("Stale"), before.stateLabel)
            XCTAssertTrue(before.rows.contains { $0.label == "Weekly" }, "the retained card must have a weekly row")
            let file = try FileHandle(forWritingTo: log)
            try file.seekToEnd()
            let updatedAt = Date()
            try file.write(contentsOf: record(updatedAt, used: 30))
            try file.close()
            var recovered: DockCardContent?
            for _ in 0..<300 {
                if let card = try app.composition.dock.cardContent(for: id), card.stateLabel.isEmpty,
                   card.rows.contains(where: { $0.label == "Weekly" && $0.value == "70%" }) {
                    recovered = card; break
                }
                try await Task.sleep(for: .milliseconds(50))
            }
            let after = try XCTUnwrap(recovered, "new local observation did not automatically recover the card")
            XCTAssertTrue(after.sourceAndAge.contains("Local history"), after.sourceAndAge)
            XCTAssertTrue(after.sourceAndAge.contains("just now"), after.sourceAndAge)
            let observed = try XCTUnwrap(app.composition.presentedContent.snapshot.presentationRows[id]?.originalObservedAt)
            XCTAssertLessThan(abs(observed.timeIntervalSince(updatedAt)), 2)
            // R-01: two more real local observations show 4% then 3% on the
            // same subscribed normal-entry card, with the latter's real age.
            for (used, expected) in [(96, "4%"), (97, "3%")] {
                let nextAt = Date()
                let writer = try FileHandle(forWritingTo: log)
                try writer.seekToEnd()
                try writer.write(contentsOf: record(nextAt, used: used))
                try writer.close()
                var current: DockCardContent?
                for _ in 0..<300 {
                    if let card = try app.composition.dock.cardContent(for: id), card.stateLabel.isEmpty,
                       card.rows.contains(where: { $0.label == "Weekly" && $0.value == expected }) {
                        current = card; break
                    }
                    try await Task.sleep(for: .milliseconds(50))
                }
                let card = try XCTUnwrap(current, "subscribed card did not deliver \(expected)")
                XCTAssertTrue(card.sourceAndAge.contains("Local history"), card.sourceAndAge)
                XCTAssertTrue(card.sourceAndAge.contains("just now"), card.sourceAndAge)
                let actual = try XCTUnwrap(app.composition.presentedContent.snapshot.presentationRows[id]?.originalObservedAt)
                XCTAssertLessThan(abs(actual.timeIntervalSince(nextAt)), 2)
            }
            await app.composition.stop()
        } catch {
            await app.composition.stop()
            throw error
        }
    }
    @MainActor func testNormalEntryRejectsOutdatedCLI() async throws {
        guard let path = ProcessInfo.processInfo.environment["MODELPLAN_U11_TEST_CLI"] else {
            throw XCTSkip("Build the unversioned synthetic CLI for the normal-entry test")
        }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("g5-cli-version-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let config = EngineClientConfiguration(executableURL: URL(fileURLWithPath: path), applicationVersion: "synthetic",
            allowedEnvironment: ["HOME":root.path,"TMPDIR":root.path,"PATH":"/usr/bin:/bin"],
            minimumServerVersion: EngineRowsEntry.minimumAppServerVersion)
        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        let app = EngineRowsEntry.make(configuration: config, settingsStore: settings, createsNativePanels: false)
        await app.composition.start()
        for _ in 0..<300 {
            if case .stopped(.protocolMismatch) = app.composition.store.snapshot.connection { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        guard case .stopped(.protocolMismatch) = app.composition.store.snapshot.connection else {
            await app.composition.stop()
            XCTFail("normal entry admitted an outdated CLI")
            return
        }
        XCTAssertNil(app.composition.store.snapshot.rows)
        await app.composition.stop()
    }
    /// The manifest pins are generated at build time from the canonical build (check-bundle-pins.py) into a
    /// gitignored Swift file; U11 native builds and generates before it compiles this test. Without them
    /// the factory has no pins, so it admits no cockpit page at all.
    @MainActor func testProductionPinsAdmitCanonicalBundles() async throws {
        guard !CommunityCockpitApplicationFactory.manifestPins.isEmpty else {
            throw XCTSkip("Built without generated cockpit pins (check-bundle-pins.py)")
        }
        XCTAssertEqual(Set(CommunityCockpitApplicationFactory.manifestPins.keys), ["community", "official"])
        var repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 {
            if FileManager.default.fileExists(atPath: repo.appendingPathComponent("desktop/cockpit/build.mjs").path) { break }
            repo.deleteLastPathComponent()
        }
        let builds = repo.appendingPathComponent("desktop/cockpit/.tmp")
        // The generated pins exist only after both editions were built, so a missing build is a failure here.
        XCTAssertTrue(FileManager.default.fileExists(atPath: builds.appendingPathComponent("community/bundle-manifest.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: builds.appendingPathComponent("official/bundle-manifest.json").path))
        for edition in ["community", "official"] {
            let pin = try XCTUnwrap(CommunityCockpitApplicationFactory.manifestPins[edition])
            let bundle = try VerifiedCockpitBundle(root: builds.appendingPathComponent(edition), manifestSHA256: pin, allowOfficial: edition == "official")
            XCTAssertFalse(try bundle.resource(path: "index.html").isEmpty, edition)
        }
        do {
            _ = try VerifiedCockpitBundle(root: builds.appendingPathComponent("community"), manifestSHA256: String(repeating: "0", count: 64), allowOfficial: false)
            XCTFail("Incorrect pin must not be admitted")
        } catch {}
    }

    @MainActor func testBothActualConsoleActionsUseOneFactoryAndOneClient() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent("u11-route-"+UUID().uuidString)
        defer{try? FileManager.default.removeItem(at:root)}
        let store=try EngineRowsEntry.makeSettingsStore(applicationSupport:root)
        let client=RouteClient(),surface=ConsoleRouteProbe();var constructions=0,clients=0
        let app=EngineRowsEntry.make(configuration:.init(executableURL:URL(fileURLWithPath:"/synthetic/not-launched"),applicationVersion:"synthetic",allowedEnvironment:[:]),settingsStore:store,createsNativePanels:false,cockpitEntryEnabled:true,
            makeClient:{_,_ in clients += 1;return client},makeConsole:{_ in constructions += 1;return surface},activateSettings:{})
        app.composition.dock.setPresentationAllowed(true)
        _=app.composition.dock.perform(NSSelectorFromString("openConsole"))
        _=app.perform(NSSelectorFromString("showConsoleMenu"))
        XCTAssertEqual(surface.shows,2);XCTAssertEqual(constructions,1);XCTAssertEqual(clients,1)
        app.composition.dock.setPresentationAllowed(false)
        _=app.composition.dock.perform(NSSelectorFromString("openConsole"))
        XCTAssertEqual(surface.shows,2)
        await app.composition.stop()
    }
    @MainActor func testNormalEntryRapidDockMenuToggleRetainsShellSession() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent("shell-toggle-"+UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:root) }
        let settings=try EngineRowsEntry.makeSettingsStore(applicationSupport:root)
        let owner=CockpitConsoleOwner(bundle:root,settingsStore:settings)
        owner.shell.detached=true;owner.shell.shutterClosed=true
        let origin=CGPoint(x:123,y:456);owner.shell.remember(origin,arrangement:"synthetic")
        let client=RouteClient();var surface:SharedEngineCockpitConsole?
        let app=EngineRowsEntry.make(configuration:.init(executableURL:URL(fileURLWithPath:"/synthetic/not-launched"),applicationVersion:"synthetic",allowedEnvironment:[:]),settingsStore:settings,createsNativePanels:false,cockpitEntryEnabled:true,
            makeClient:{_,_ in client},makeConsole:{ composition in
                let value=SharedEngineCockpitConsole(owner:owner,composition:composition,activate:{})
                surface=value;return value
            },activateSettings:{})
        app.composition.dock.setPresentationAllowed(true)
        _=app.composition.dock.perform(NSSelectorFromString("openConsole"))
        XCTAssertTrue(try XCTUnwrap(surface).wantsVisible)
        app.toggleConsole() // G3-40: the status icon closes; a menu item only opens
        XCTAssertFalse(try XCTUnwrap(surface).wantsVisible)
        _=app.composition.dock.perform(NSSelectorFromString("openConsole"))
        XCTAssertTrue(try XCTUnwrap(surface).wantsVisible)
        XCTAssertTrue(owner.shell.detached);XCTAssertTrue(owner.shell.shutterClosed)
        XCTAssertEqual(owner.shell.origin(for:"synthetic"),origin)
        surface?.hide();await app.composition.stop()
    }
    // #403 normal-entry journey: use the actual menu actions with a synthetic
    // console/client, without opening a panel or launching an engine process.
    @MainActor func testStatusAndDockMenusOpenSameEnabledConsole() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent("s6-menu-journey-"+UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:root) }
        let store=try EngineRowsEntry.makeSettingsStore(applicationSupport:root,preferredLanguages:["en"])
        let client=RouteClient(),surface=ConsoleRouteProbe();var constructions=0,clients=0
        let app=EngineRowsEntry.make(configuration:.init(executableURL:URL(fileURLWithPath:"/synthetic/not-launched"),applicationVersion:"synthetic",allowedEnvironment:[:]),settingsStore:store,createsNativePanels:false,cockpitEntryEnabled:true,
            makeClient:{_,_ in clients += 1;return client},makeConsole:{_ in constructions += 1;return surface},activateSettings:{})
        await app.prepare();app.composition.dock.setPresentationAllowed(true);app.renderMenu()
        let status=try XCTUnwrap(app.liveStatusMenu)
        let statusIndex=try XCTUnwrap(status.items.firstIndex { $0.title == "Open Cockpit" })
        XCTAssertTrue(status.items[statusIndex].isEnabled)
        status.performActionForItem(at:statusIndex)
        let dock=app.composition.dock.menu()
        let dockIndex=try XCTUnwrap(dock.items.firstIndex { $0.title == "Open Cockpit" })
        XCTAssertTrue(dock.items[dockIndex].isEnabled)
        dock.performActionForItem(at:dockIndex)
        XCTAssertEqual(surface.shows,2);XCTAssertEqual(constructions,1);XCTAssertEqual(clients,1)
        await app.composition.stop()
    }
    // Owner D39/D-E: package-neutral.sh --owner-test writes ModelPlanCockpitEntryEnabled=true; the release and
    // --unverified packages write false (preflight PF-08). The normal entry reads only the packaged Info.plist here
    // (no cockpitEntryEnabled override), so this is the packaged switch, not a test seam.
    @MainActor func testOwnerTestPackageOpensCockpitAndReleasePackageDoesNot() async throws {
        for (mode, enabled) in [("owner-test", true), ("release", false)] {
            let root=FileManager.default.temporaryDirectory.appendingPathComponent("d-e-\(mode)-"+UUID().uuidString)
            defer { try? FileManager.default.removeItem(at:root) }
            let app=root.appendingPathComponent("ModelPlan Community.app"),contents=app.appendingPathComponent("Contents")
            try FileManager.default.createDirectory(at:contents.appendingPathComponent("MacOS"),withIntermediateDirectories:true)
            let info:[String:Any]=["CFBundleIdentifier":"org.modelplan.community.swift.scaffold","CFBundleExecutable":"ModelPlanCommunity",
                                   "CFBundlePackageType":"APPL","ModelPlanCockpitEntryEnabled":enabled]
            try PropertyListSerialization.data(fromPropertyList:info,format:.xml,options:0).write(to:contents.appendingPathComponent("Info.plist"))
            let store=try EngineRowsEntry.makeSettingsStore(applicationSupport:root,preferredLanguages:["en"])
            let surface=ConsoleRouteProbe(); var constructed=0
            let entry=EngineRowsEntry.make(configuration:.init(executableURL:URL(fileURLWithPath:"/synthetic/not-launched"),applicationVersion:"synthetic",allowedEnvironment:[:]),settingsStore:store,createsNativePanels:false,bundleURL:app,
                makeClient:{_,_ in RouteClient()},makeConsole:{_ in constructed += 1; return surface},activateSettings:{})
            await entry.prepare(); entry.composition.dock.setPresentationAllowed(true); entry.renderMenu()
            let status=try XCTUnwrap(entry.liveStatusMenu)
            let item=try XCTUnwrap(status.items.first { $0.title == (enabled ? "Open Cockpit" : "Coming soon") }, mode)
            XCTAssertEqual(item.isEnabled,enabled,mode)
            entry.perform(NSSelectorFromString("showConsoleMenu"))
            entry.composition.dock.perform(NSSelectorFromString("openConsole"))
            XCTAssertEqual(constructed,enabled ? 1 : 0,mode)
            XCTAssertEqual(surface.shows,enabled ? 2 : 0,mode)
            await entry.composition.stop()
        }
    }
    @MainActor func testNormalEntryCockpitSwitchBlocksBothRoutesWithoutConstructingSurface() async throws {
        for enabled in [false, true] {
            let root=FileManager.default.temporaryDirectory.appendingPathComponent("cockpit-switch-"+UUID().uuidString)
            defer { try? FileManager.default.removeItem(at:root) }
            let store=try EngineRowsEntry.makeSettingsStore(applicationSupport:root,preferredLanguages:["en"])
            let surface=ConsoleRouteProbe(); var constructed=0
            let app=EngineRowsEntry.make(configuration:.init(executableURL:URL(fileURLWithPath:"/synthetic/not-launched"),applicationVersion:"synthetic",allowedEnvironment:[:]),settingsStore:store,createsNativePanels:false,cockpitEntryEnabled:enabled,
                makeClient:{_,_ in RouteClient()},makeConsole:{_ in constructed += 1; return surface},activateSettings:{})
            await app.prepare(); app.composition.dock.setPresentationAllowed(true)
            app.renderMenu()
            let status=try XCTUnwrap(app.liveStatusMenu)
            let statusItem=try XCTUnwrap(status.items.first { $0.title == (enabled ? "Open Cockpit" : "Coming soon") })
            XCTAssertEqual(statusItem.isEnabled,enabled)
            let menu=app.composition.dock.menu()
            // The widget menu lists the cockpit only when its entry is on (owner HIG decision 11-06).
            if enabled { XCTAssertTrue(try XCTUnwrap(menu.items.first { $0.title == "Open Cockpit" }).isEnabled) }
            else { XCTAssertFalse(menu.items.contains { $0.title == "Coming soon" || $0.title == "Open Cockpit" }) }
            app.composition.dock.perform(NSSelectorFromString("openConsole"))
            app.perform(NSSelectorFromString("showConsoleMenu"))
            XCTAssertEqual(constructed,enabled ? 1 : 0)
            XCTAssertEqual(surface.shows,enabled ? 2 : 0)
            if !enabled {
                let editor = app.settingsHost.application.editor
                _ = try await editor.commit(SettingsB21Edit.language(.chinese))
                app.renderMenu()
                let chinese = try XCTUnwrap(app.liveStatusMenu?.items.first { $0.title == "即将推出" })
                XCTAssertFalse(chinese.isEnabled)
                let chineseDock = app.composition.dock.menu()
                XCTAssertFalse(chineseDock.items.contains { $0.title == "即将推出" })
                app.composition.dock.pauseForLifecycle()
                let paused = app.composition.dock.menu()
                XCTAssertTrue(paused.items.contains { $0.title == "退出 ModelPlan" })
                XCTAssertTrue(paused.items.contains { $0.title == "自动收起" && !$0.isEnabled })
                XCTAssertTrue(paused.items.contains { $0.title == "设置…" && !$0.isEnabled })
            }
            await app.composition.stop()
        }
    }
    @MainActor func testSharedStoreClearsBeforeWebBarrierAndBorrowerCannotStopClient() async throws {
        let store=EngineStore(),sink=ClearSink();_ = store.attach(sink)
        let client=RouteClient();var page:ClearingPage?
        let coordinator=EngineCockpitCoordinator{context in let p=ClearingPage(context,sink:sink);page=p;return p}
        coordinator.bind(client:client)
        let fanout=CockpitStoreFanout(store:store,cockpit:coordinator)
        let context=EngineDeliveryContext(sessionID:"s-"+UUID().uuidString.lowercased(),floor:.init(storeEpoch:"synthetic",generation:1),revision:1)
        await fanout.consume(.context(context));coordinator.open()
        var acknowledged=false
        let turn=Task{@MainActor in await fanout.consume(.clearPrivateViews(.init(revision:2,reason:.generationAdvanced,previous:context,nextFloor:nil)));acknowledged=true}
        for _ in 0..<100 {if page?.waiter != nil{break};await Task.yield()}
        XCTAssertTrue(sink.cleared);XCTAssertTrue(page?.sawStoreClearFirst == true)
        XCTAssertNil(store.snapshot.delivery);XCTAssertFalse(acknowledged)
        page?.waiter?.resume();page?.waiter=nil;await turn.value
        XCTAssertTrue(acknowledged)
        await coordinator.shutdown()
        let stops=await client.stops
        XCTAssertEqual(stops,0,"Cockpit shutdown must not stop the application's borrowed client")
        await client.stop()
    }

    /// D-A: the page's openField action reaches the panel through the production console, with public model data only.
    @MainActor func testOpenFieldIntentOpensThePanelWithPublicModelsAndHideClosesIt() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent("u11-field-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        defer{try? FileManager.default.removeItem(at:root)}
        let html=Data("<!doctype html><title>synthetic field</title>".utf8)
        for name in ["index.html","field.html"] { try html.write(to:root.appendingPathComponent(name)) }
        let manifest=try JSONSerialization.data(withJSONObject:["schemaVersion":1,"edition":"community","interfaceOnly":true,
            "files":["index.html":VerifiedCockpitBundle.digest(html),"field.html":VerifiedCockpitBundle.digest(html)]])
        try manifest.write(to:root.appendingPathComponent("bundle-manifest.json"))
        let support=FileManager.default.temporaryDirectory.appendingPathComponent("u11-field-support-"+UUID().uuidString)
        defer{try? FileManager.default.removeItem(at:support)}
        let settings=try EngineRowsEntry.makeSettingsStore(applicationSupport:support)
        let client=RouteClient()
        let composition=EngineDockMenuComposition(configuration:.init(executableURL:URL(fileURLWithPath:"/synthetic/not-launched"),applicationVersion:"synthetic",allowedEnvironment:[:]),createsNativePanels:false,makeClient:{_,_ in client})
        let owner=CockpitConsoleOwner(bundle:root,settingsStore:settings)
        owner.verifiedBundle=try VerifiedCockpitBundle(root:root,manifestSHA256:VerifiedCockpitBundle.digest(manifest))
        let surface=SharedEngineCockpitConsole(owner:owner,composition:composition,isForeground:{true},activate:{})
        surface.wantsVisible=true
        surface.handle(.openField)
        XCTAssertFalse(surface.fieldIsOpen,"No published models, no field")
        var capture=URL(fileURLWithPath:#filePath).deletingLastPathComponent()
        while !FileManager.default.fileExists(atPath:capture.appendingPathComponent("schema/app-cli/captures").path) { capture.deleteLastPathComponent() }
        capture=capture.appendingPathComponent("schema/app-cli/captures/WireCockpitData.json")
        var data=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:capture)) as? [String:Any])
        var details=try XCTUnwrap(data["details"] as? [String:Any])
        details["publishedModels"]=[["id":"synthetic-model","name":"Synthetic","developerId":"openai","recommended":"medium",
            "efforts":[["effort":"medium","label":"Med","star":true,"ability":40.0,"cost":0.2,"time":30.0]]]]
        data["details"]=details
        let wire=try WireDecoder.decode(WireCockpitData.self,from:JSONSerialization.data(withJSONObject:data))
        let context=EngineDeliveryContext(sessionID:"s-field",floor:.init(storeEpoch:"synthetic",generation:1),revision:1)
        await composition.store.consume(.connection(.ready(context)));await composition.store.consume(.context(context))
        await composition.store.consume(.response(requestID:.string("cockpit"),.cockpit(.init(envelope:try .init(sessionId:context.sessionID,storeEpoch:context.floor.storeEpoch,consentGeneration:1,data:wire),delivery:context))))
        let payload=try XCTUnwrap(surface.fieldPayload())
        XCTAssertTrue(payload.contains("synthetic-model"));XCTAssertFalse(payload.contains("subscriptionRef"),"Only public model data crosses")
        XCTAssertTrue(payload.contains(#""lowPower":"#),"D63: the payload says whether Low Power Mode is on")
        XCTAssertTrue(try XCTUnwrap(surface.fieldPayload(lowPower:true)).contains(#""lowPower":true"#))
        XCTAssertTrue(try XCTUnwrap(surface.fieldPayload(lowPower:false)).contains(#""lowPower":false"#))
        XCTAssertTrue(payload.contains(#""focus":null"#) || !payload.contains(#""focus""#),"No rocket clicked, no focus")
        XCTAssertTrue(try XCTUnwrap(surface.fieldPayload(focusName:"Synthetic")).contains(#""focus":"synthetic-model""#),"D63: the clicked rocket's name resolves to its published ID")
        XCTAssertFalse(try XCTUnwrap(surface.fieldPayload(focusName:"Not published")).contains("Not published"),"An unknown name focuses nothing")
        // CKP-PORT-11D: the payload is exactly presentation plus published models; no account or local field is in it.
        let object=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(payload.utf8)) as? [String:Any])
        XCTAssertTrue(Set(object.keys).isSubset(of:["language","reduceMotion","lowPower","models","mine","focus"]),"only presentation and published models: \(object.keys.sorted())")
        for forbidden in ["account","email","subscriptionRef","usedPercent","remaining","projectName","token"] { XCTAssertFalse(payload.contains(forbidden),"no \(forbidden) in the field payload") }
        surface.handle(.openField)
        XCTAssertTrue(surface.fieldIsOpen)
        surface.hide()
        XCTAssertFalse(surface.fieldIsOpen,"Closing the cockpit closes the field")
        await composition.stop()
    }

    /// G3-80 / macrev2-845-2: the openField intent carries no pointer, and Enter or Space on the enlarge key sends the
    /// same intent as a click. The field opens on the cockpit's display; the pointer decides only while it is over the
    /// cockpit (a click), never when it rests on another display (a keyboard open).
    @MainActor func testOpenFieldUsesTheCockpitDisplayUnlessThePointerIsOnTheCockpit() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent("u11-field-screen-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        defer{try? FileManager.default.removeItem(at:root)}
        let html=Data("<!doctype html><title>synthetic field</title>".utf8)
        for name in ["index.html","field.html"] { try html.write(to:root.appendingPathComponent(name)) }
        let manifest=try JSONSerialization.data(withJSONObject:["schemaVersion":1,"edition":"community","interfaceOnly":true,
            "files":["index.html":VerifiedCockpitBundle.digest(html),"field.html":VerifiedCockpitBundle.digest(html)]])
        try manifest.write(to:root.appendingPathComponent("bundle-manifest.json"))
        let support=FileManager.default.temporaryDirectory.appendingPathComponent("u11-field-screen-support-"+UUID().uuidString)
        defer{try? FileManager.default.removeItem(at:support)}
        let settings=try EngineRowsEntry.makeSettingsStore(applicationSupport:support)
        let client=RouteClient()
        let composition=EngineDockMenuComposition(configuration:.init(executableURL:URL(fileURLWithPath:"/synthetic/not-launched"),applicationVersion:"synthetic",allowedEnvironment:[:]),createsNativePanels:false,makeClient:{_,_ in client})
        let owner=CockpitConsoleOwner(bundle:root,settingsStore:settings)
        owner.verifiedBundle=try VerifiedCockpitBundle(root:root,manifestSHA256:VerifiedCockpitBundle.digest(manifest))
        let surface=SharedEngineCockpitConsole(owner:owner,composition:composition,isForeground:{true},activate:{})
        var capture=URL(fileURLWithPath:#filePath).deletingLastPathComponent()
        while !FileManager.default.fileExists(atPath:capture.appendingPathComponent("schema/app-cli/captures").path) { capture.deleteLastPathComponent() }
        capture=capture.appendingPathComponent("schema/app-cli/captures/WireCockpitData.json")
        var data=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:capture)) as? [String:Any])
        var details=try XCTUnwrap(data["details"] as? [String:Any])
        details["publishedModels"]=[["id":"synthetic-model","name":"Synthetic","developerId":"openai","recommended":"medium",
            "efforts":[["effort":"medium","label":"Med","star":true,"ability":40.0,"cost":0.2,"time":30.0]]]]
        data["details"]=details
        let wire=try WireDecoder.decode(WireCockpitData.self,from:JSONSerialization.data(withJSONObject:data))
        let context=EngineDeliveryContext(sessionID:"s-field-screen",floor:.init(storeEpoch:"synthetic",generation:1),revision:1)
        await composition.store.consume(.connection(.ready(context)));await composition.store.consume(.context(context))
        await composition.store.consume(.response(requestID:.string("cockpit"),.cockpit(.init(envelope:try .init(sessionId:context.sessionID,storeEpoch:context.floor.storeEpoch,consentGeneration:1,data:wire),delivery:context))))
        // A: the built-in display with the menu bar icon; B: a larger display to its right.
        let a=CockpitScreen(frame:CGRect(x:0,y:0,width:1512,height:982),visibleFrame:CGRect(x:0,y:0,width:1512,height:949))
        let b=CockpitScreen(frame:CGRect(x:1512,y:0,width:2560,height:1440),visibleFrame:CGRect(x:1512,y:0,width:2560,height:1415))
        let displays=[a,b]
        var cockpit=CGRect(x:3000,y:400,width:636,height:900)
        var pointer=CGPoint(x:300,y:300)
        surface.fieldScreens={ displays }
        surface.cockpitFrameForField={ cockpit }
        surface.pointerLocation={ pointer }
        owner.anchor={ CGRect(x:1100,y:949,width:28,height:24) }
        func open() throws -> CGRect {
            surface.wantsVisible=true
            surface.handle(.openField)
            XCTAssertTrue(surface.fieldIsOpen)
            let frame=try XCTUnwrap(surface.fieldWindowFrame)
            surface.hide()
            return frame
        }
        // Keyboard: cockpit on B, pointer resting on A.
        var frame=try open()
        XCTAssertTrue(b.visibleFrame.contains(frame),"a keyboard open lands on the cockpit's display B, not the pointer's A: \(NSStringFromRect(frame))")
        // Click on the cockpit on B.
        pointer=CGPoint(x:3100,y:800)
        frame=try open()
        XCTAssertTrue(b.visibleFrame.contains(frame),"a click on the cockpit on B: \(NSStringFromRect(frame))")
        // A cockpit straddling A and B, clicked on its A part: the click's display A.
        cockpit=CGRect(x:1300,y:300,width:636,height:600)
        pointer=CGPoint(x:1400,y:600)
        frame=try open()
        XCTAssertTrue(a.visibleFrame.contains(frame),"a click on the cockpit's A part opens on A: \(NSStringFromRect(frame))")
        await composition.stop()
    }

    /// glm-660-3: the cockpit's own close button ends in the page's onClosed, not in `hide()`; the field panel closes with it.
    /// D49 review (#695): the widget stays at `.floating` under the cockpit, and every window the cockpit
    /// brings up is not hidden behind it. The snap guide shares its level so it can sit just below it.
    @MainActor func testD49WindowsAroundTheCockpitStackInOrder() {
        let cockpit = CockpitWindowController.panelLevel.rawValue
        XCTAssertGreaterThan(cockpit, NSWindow.Level.floating.rawValue, "the cockpit opens above the widget")
        XCTAssertLessThan(cockpit, NSWindow.Level.statusBar.rawValue, "a widget being dragged still rises above it")
        XCTAssertGreaterThan(CockpitFieldPanel.level.rawValue, cockpit, "the launch field opens above the cockpit")
        XCTAssertGreaterThan(DockHelpPresenter.overlayLevel.rawValue, cockpit, "Help draws above the cockpit")
        XCTAssertEqual(CockpitWindowController.snapGuideLevel.rawValue, cockpit, "the snap guide orders just below the cockpit")
    }

    @MainActor func testTheCockpitsOwnCloseAlsoClosesTheField() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent("u11-field-close-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        defer{try? FileManager.default.removeItem(at:root)}
        let html=Data("<!doctype html><title>synthetic field</title>".utf8)
        for name in ["index.html","field.html"] { try html.write(to:root.appendingPathComponent(name)) }
        let manifest=try JSONSerialization.data(withJSONObject:["schemaVersion":1,"edition":"community","interfaceOnly":true,
            "files":["index.html":VerifiedCockpitBundle.digest(html),"field.html":VerifiedCockpitBundle.digest(html)]])
        try manifest.write(to:root.appendingPathComponent("bundle-manifest.json"))
        let support=FileManager.default.temporaryDirectory.appendingPathComponent("u11-field-close-support-"+UUID().uuidString)
        defer{try? FileManager.default.removeItem(at:support)}
        let settings=try EngineRowsEntry.makeSettingsStore(applicationSupport:support)
        let client=RouteClient();await client.suspendCockpit()
        let composition=EngineDockMenuComposition(configuration:.init(executableURL:URL(fileURLWithPath:"/synthetic/not-launched"),applicationVersion:"synthetic",allowedEnvironment:[:]),createsNativePanels:false,makeClient:{_,_ in client})
        let owner=CockpitConsoleOwner(bundle:root,settingsStore:settings)
        owner.verifiedBundle=try VerifiedCockpitBundle(root:root,manifestSHA256:VerifiedCockpitBundle.digest(manifest))
        let page=ClearingPage(try .init(sessionID:UUID(),storeEpoch:"synthetic",generation:1),sink:ClearSink())
        let coordinator=EngineCockpitCoordinator { _ in page }
        coordinator.bind(client:client);owner.coordinator=coordinator
        let surface=SharedEngineCockpitConsole(owner:owner,composition:composition,isForeground:{true},activate:{})
        var capture=URL(fileURLWithPath:#filePath).deletingLastPathComponent()
        while !FileManager.default.fileExists(atPath:capture.appendingPathComponent("schema/app-cli/captures").path) { capture.deleteLastPathComponent() }
        capture=capture.appendingPathComponent("schema/app-cli/captures/WireCockpitData.json")
        var data=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:capture)) as? [String:Any])
        var details=try XCTUnwrap(data["details"] as? [String:Any])
        details["publishedModels"]=[["id":"synthetic-model","name":"Synthetic","developerId":"openai","recommended":"medium",
            "efforts":[["effort":"medium","label":"Med","star":true,"ability":40.0,"cost":0.2,"time":30.0]]]]
        data["details"]=details
        let wire=try WireDecoder.decode(WireCockpitData.self,from:JSONSerialization.data(withJSONObject:data))
        let context=EngineDeliveryContext(sessionID:"s-"+page.state.context.sessionID.uuidString.lowercased(),floor:.init(storeEpoch:"synthetic",generation:1),revision:1)
        await composition.store.consume(.connection(.ready(context)));await composition.store.consume(.context(context))
        await composition.store.consume(.response(requestID:.string("cockpit"),.cockpit(.init(envelope:try .init(sessionId:context.sessionID,storeEpoch:context.floor.storeEpoch,consentGeneration:1,data:wire),delivery:context))))
        await coordinator.consume(.context(context));surface.show()
        // show() opens the page from a task; only an open page has the coordinator's onClosed.
        for _ in 0..<200 where page.onClosed == nil { try await Task.sleep(for:.milliseconds(10)) }
        XCTAssertNotNil(page.onClosed,"The cockpit page opened")
        surface.handle(.openField)
        XCTAssertTrue(surface.fieldIsOpen)
        page.discard()
        XCTAssertFalse(surface.fieldIsOpen,"The cockpit's own close closes the field")
        surface.hide();await coordinator.shutdown();await composition.stop()
    }

    /// G3-40 / MENU-07: the production console behind the icon. The toggle goes through the page's close,
    /// a close during the wait for a page cancels the open, and the console can open again afterwards.
    @MainActor func testG3_40ConsoleToggleClosesThePageAndOpensAgain() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent("u11-toggle-"+UUID().uuidString)
        defer{try? FileManager.default.removeItem(at:root)}
        let settings=try EngineRowsEntry.makeSettingsStore(applicationSupport:root)
        let client=RouteClient();await client.suspendCockpit()
        let composition=EngineDockMenuComposition(configuration:.init(executableURL:URL(fileURLWithPath:"/synthetic/not-launched"),applicationVersion:"synthetic",allowedEnvironment:[:]),createsNativePanels:false,makeClient:{_,_ in client})
        let owner=CockpitConsoleOwner(bundle:root,settingsStore:settings)
        let sessionID=UUID(),sink=ClearSink();var made=0
        let coordinator=EngineCockpitCoordinator { _ in made+=1;return ClearingPage(try .init(sessionID:sessionID,storeEpoch:"synthetic",generation:1),sink:sink) }
        coordinator.bind(client:client);owner.coordinator=coordinator
        let surface=SharedEngineCockpitConsole(owner:owner,composition:composition,isForeground:{true},activate:{})
        let context=EngineDeliveryContext(sessionID:"s-"+sessionID.uuidString.lowercased(),floor:.init(storeEpoch:"synthetic",generation:1),revision:1)
        await coordinator.consume(.context(context))
        XCTAssertFalse(surface.isShowing)
        surface.show();XCTAssertTrue(surface.isShowing)
        surface.requestClose();XCTAssertFalse(surface.isShowing,"A close before the page exists cancels the open")
        try await Task.sleep(for:.milliseconds(50));XCTAssertEqual(made,0)
        surface.show()
        for _ in 0..<200 where made==0 { try await Task.sleep(for:.milliseconds(10)) }
        XCTAssertEqual(made,1);XCTAssertTrue(surface.isShowing)
        surface.requestClose()
        XCTAssertFalse(surface.isShowing,"The second click closes the open page")
        surface.show()
        for _ in 0..<200 where made==1 { try await Task.sleep(for:.milliseconds(10)) }
        XCTAssertEqual(made,2,"The next click opens a new page");XCTAssertTrue(surface.isShowing)
        surface.hide();await coordinator.shutdown();await composition.stop()
    }

    /// MOT-2.3-04: Settings Reduce Motion reaches the page at open and when it changes. The normal entry's
    /// settings fan-out into `applySettings` is covered by NormalEntrySettingsJourneyTests.
    @MainActor func testReduceMotionSettingReachesTheCockpitAtOpenAndOnChange() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent("u11-reduce-motion-"+UUID().uuidString)
        defer{try? FileManager.default.removeItem(at:root)}
        let settings=try EngineRowsEntry.makeSettingsStore(applicationSupport:root)
        _=try await settings.update { $0.motion = .on;$0.language = .chinese;$0.redBelow=15 }
        var applied:[SettingsApplication]=[]
        let app=SettingsApplicationCoordinator(store:settings) { applied.append($0) }
        await app.reload()
        let client=RouteClient();await client.suspendCockpit()
        let composition=EngineDockMenuComposition(configuration:.init(executableURL:URL(fileURLWithPath:"/synthetic/not-launched"),applicationVersion:"synthetic",allowedEnvironment:[:]),createsNativePanels:false,makeClient:{_,_ in client})
        let owner=CockpitConsoleOwner(bundle:root,settingsStore:settings)
        XCTAssertFalse(owner.appearance.reduceMotion)
        let page=ClearingPage(try .init(sessionID:UUID(),storeEpoch:"synthetic",generation:1),sink:ClearSink())
        let coordinator=EngineCockpitCoordinator { _ in page }
        coordinator.bind(client:client);owner.coordinator=coordinator
        let surface=SharedEngineCockpitConsole(owner:owner,composition:composition,isForeground:{true},activate:{})
        surface.applySettings(try XCTUnwrap(applied.last))
        let context=EngineDeliveryContext(sessionID:"s-"+page.state.context.sessionID.uuidString.lowercased(),floor:.init(storeEpoch:"synthetic",generation:1),revision:1)
        await coordinator.consume(.context(context));surface.show()
        for _ in 0..<100 { if await client.cockpitPending { break };try await Task.sleep(for:.milliseconds(10)) }
        XCTAssertTrue(owner.appearance.reduceMotion,"Opening keeps the setting")
        XCTAssertEqual(owner.appearance.locale,.zhCN);XCTAssertEqual(owner.appearance.redBelow,15)
        _=try await settings.update { $0.motion = .system;$0.language = .english }
        await app.reload()
        surface.applySettings(try XCTUnwrap(applied.last))
        let delivered=try XCTUnwrap(page.appearances.last,"A change reaches the open page")
        XCTAssertFalse(delivered.reduceMotion);XCTAssertEqual(delivered.locale,.en)
        surface.hide();await coordinator.shutdown();await composition.stop()
    }

    /// CKP-MFD-24: a website link from the page opens the typed public address, built natively.
    @MainActor func testWebsiteLinkFromThePageOpensTheTypedPublicAddress() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent("u11-website-link-"+UUID().uuidString)
        defer{try? FileManager.default.removeItem(at:root)}
        let settings=try EngineRowsEntry.makeSettingsStore(applicationSupport:root)
        let client=RouteClient();await client.suspendCockpit()
        let composition=EngineDockMenuComposition(configuration:.init(executableURL:URL(fileURLWithPath:"/synthetic/not-launched"),applicationVersion:"synthetic",allowedEnvironment:[:]),createsNativePanels:false,makeClient:{_,_ in client})
        let owner=CockpitConsoleOwner(bundle:root,settingsStore:settings)
        var opened:[URL]=[]
        owner.openWebsite = { opened.append($0) }
        let page=ClearingPage(try .init(sessionID:UUID(),storeEpoch:"synthetic",generation:1),sink:ClearSink())
        let coordinator=EngineCockpitCoordinator { _ in page }
        coordinator.bind(client:client);owner.coordinator=coordinator
        let surface=SharedEngineCockpitConsole(owner:owner,composition:composition,isForeground:{true},activate:{})
        let context=EngineDeliveryContext(sessionID:"s-"+page.state.context.sessionID.uuidString.lowercased(),floor:.init(storeEpoch:"synthetic",generation:1),revision:1)
        await coordinator.consume(.context(context));surface.show()
        for _ in 0..<100 { if await client.cockpitPending { break };try await Task.sleep(for:.milliseconds(10)) }
        for (name,value) in [("plans","openai"),("effort","gpt-6.1-sol"),("methodology","effort-ladder")] {
            page.onIntent?(.openWebsite(try XCTUnwrap(CockpitWebsiteLink(page:name,value:value))))
        }
        XCTAssertEqual(opened.map(\.absoluteString),["https://modelplan.ai/plans?seller=openai","https://modelplan.ai/effort?model=gpt-6.1-sol","https://modelplan.ai/methodology#effort-ladder"])
        surface.hide();await coordinator.shutdown();await composition.stop()
    }

    /// CKP-SHELL-39: the empty engine screen's button reaches the owner as Settings on its Subscriptions pane, and the
    /// plain Settings key keeps opening Settings as before.
    @MainActor func testEmptyScreenButtonOpensSettingsOnTheSubscriptionsPane() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent("ckp-shell-39-"+UUID().uuidString)
        defer{try? FileManager.default.removeItem(at:root)}
        let settings=try EngineRowsEntry.makeSettingsStore(applicationSupport:root)
        let client=RouteClient();await client.suspendCockpit()
        let composition=EngineDockMenuComposition(configuration:.init(executableURL:URL(fileURLWithPath:"/synthetic/not-launched"),applicationVersion:"synthetic",allowedEnvironment:[:]),createsNativePanels:false,makeClient:{_,_ in client})
        let owner=CockpitConsoleOwner(bundle:root,settingsStore:settings)
        var opened:[String]=[]
        owner.settings = { opened.append("settings") }
        owner.settingsSubscriptions = { opened.append("subscriptions") }
        let page=ClearingPage(try .init(sessionID:UUID(),storeEpoch:"synthetic",generation:1),sink:ClearSink())
        let coordinator=EngineCockpitCoordinator { _ in page }
        coordinator.bind(client:client);owner.coordinator=coordinator
        let surface=SharedEngineCockpitConsole(owner:owner,composition:composition,isForeground:{true},activate:{})
        let context=EngineDeliveryContext(sessionID:"s-"+page.state.context.sessionID.uuidString.lowercased(),floor:.init(storeEpoch:"synthetic",generation:1),revision:1)
        await coordinator.consume(.context(context));surface.show()
        for _ in 0..<100 { if await client.cockpitPending { break };try await Task.sleep(for:.milliseconds(10)) }
        page.onIntent?(.openSettingsSubscriptions)
        page.onIntent?(.openSettings)
        XCTAssertEqual(opened,["subscriptions","settings"])
        surface.hide();await coordinator.shutdown();await composition.stop()
    }

    /// SET-9-19: the committed setting reaches the appearance the page is given.
    @MainActor func testProjectNamesSettingReachesTheCockpitAppearance() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent("u11-project-names-"+UUID().uuidString)
        defer{try? FileManager.default.removeItem(at:root)}
        let settings=try EngineRowsEntry.makeSettingsStore(applicationSupport:root)
        _=try await settings.update { $0.showProjectNames=false;$0.redBelow=15 }
        var applied:[SettingsApplication]=[]
        let app=SettingsApplicationCoordinator(store:settings) { applied.append($0) }
        await app.reload()
        let client=RouteClient()
        let composition=EngineDockMenuComposition(configuration:.init(executableURL:URL(fileURLWithPath:"/synthetic/not-launched"),applicationVersion:"synthetic",allowedEnvironment:[:]),createsNativePanels:false,makeClient:{_,_ in client})
        let owner=CockpitConsoleOwner(bundle:root,settingsStore:settings)
        XCTAssertTrue(owner.appearance.showProjectNames)
        let surface=SharedEngineCockpitConsole(owner:owner,composition:composition,isForeground:{true},activate:{})
        surface.applySettings(try XCTUnwrap(applied.last))
        XCTAssertFalse(owner.appearance.showProjectNames)
        XCTAssertEqual(owner.appearance.redBelow,15)
        await composition.stop()
    }

    /// CKP-ENG-23 / SET-9-10: Settings "Percentage mode" reaches the appearance the page is given, at open and on change.
    @MainActor func testPercentageModeSettingReachesTheCockpitAppearanceAtOpenAndLive() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent("ckp-eng-23-"+UUID().uuidString)
        defer{try? FileManager.default.removeItem(at:root)}
        let settings=try EngineRowsEntry.makeSettingsStore(applicationSupport:root)
        var applied:[SettingsApplication]=[]
        let app=SettingsApplicationCoordinator(store:settings) { applied.append($0) }
        _=try await settings.update { $0.percentageMode = .used }
        await app.reload()
        let client=RouteClient()
        let composition=EngineDockMenuComposition(configuration:.init(executableURL:URL(fileURLWithPath:"/synthetic/not-launched"),applicationVersion:"synthetic",allowedEnvironment:[:]),createsNativePanels:false,makeClient:{_,_ in client})
        let owner=CockpitConsoleOwner(bundle:root,settingsStore:settings)
        XCTAssertFalse(owner.appearance.showUsedPercent, "Default is remaining")
        let surface=SharedEngineCockpitConsole(owner:owner,composition:composition,isForeground:{true},activate:{})
        surface.applySettings(try XCTUnwrap(applied.last))
        XCTAssertTrue(owner.appearance.showUsedPercent)
        _=try await settings.update { $0.percentageMode = .remaining }
        await app.reload()
        surface.applySettings(try XCTUnwrap(applied.last))
        XCTAssertFalse(owner.appearance.showUsedPercent)
        await composition.stop()
    }

    @MainActor func testForegroundFeatureFailureRequestsExactlyOneRecoveryNoticeInBothOrders() async throws {
        for eventFirst in [true,false] {
            let root=FileManager.default.temporaryDirectory.appendingPathComponent("u11-failure-order-"+UUID().uuidString)
            defer{try? FileManager.default.removeItem(at:root)}
            let settings=try EngineRowsEntry.makeSettingsStore(applicationSupport:root)
            _=try await settings.update { $0.theme = .day }
            let client=RouteClient();await client.suspendCockpit()
            let composition=EngineDockMenuComposition(configuration:.init(executableURL:URL(fileURLWithPath:"/synthetic/not-launched"),applicationVersion:"synthetic",allowedEnvironment:[:]),createsNativePanels:false,makeClient:{_,_ in client})
            let owner=CockpitConsoleOwner(bundle:root,settingsStore:settings)
            let page=ClearingPage(try .init(sessionID:UUID(),storeEpoch:"synthetic",generation:1),sink:ClearSink())
            let coordinator=EngineCockpitCoordinator { _ in page }
            coordinator.bind(client:client);owner.coordinator=coordinator
            var notices:[CockpitUnavailableNotice]=[]
            let surface=SharedEngineCockpitConsole(owner:owner,composition:composition,isForeground:{true},activate:{},requestNotice:{notices.append($0)},noticeGrace:.zero)
            let context=EngineDeliveryContext(sessionID:"s-"+page.state.context.sessionID.uuidString.lowercased(),floor:.init(storeEpoch:"synthetic",generation:1),revision:1)
            await coordinator.consume(.context(context));surface.show()
            for _ in 0..<100 { if await client.cockpitPending { break };try await Task.sleep(for:.milliseconds(10)) }
            let pending=await client.cockpitPending;XCTAssertTrue(pending)
            if eventFirst {
                await coordinator.consume(.featureFailure(.cockpit,.featureDecode(.cockpit)))
                await client.failCockpit()
            } else {
                await client.failCockpit()
                await coordinator.joinCurrentQueryForVerification()
                await coordinator.consume(.featureFailure(.cockpit,.featureDecode(.cockpit)))
            }
            for _ in 0..<20 { await Task.yield() }
            XCTAssertTrue(page.state.disposed,"Feature failure must discard the page")
            XCTAssertFalse(surface.wantsVisible,"Production close callback must retire presentation")
            XCTAssertEqual(notices.count,1,"One recovery notice regardless of event/continuation order")
            XCTAssertEqual(notices.first?.actions,[.settings,.dockReadings,.cancel])
            let stops=await client.stops;XCTAssertEqual(stops,0)
            surface.hide();await coordinator.shutdown();await composition.stop()
        }
    }

    /// CKP-SHELL-01 (D118): through the normal factory, the cockpit opens directly below the menu-bar icon: its top sits a
    /// fixed 6 pt under the icon's bottom edge and it is centred on the icon (D88: the 636 px raster has the same 8 px
    /// margin on both sides of the shell, so the frame's centre is the shell's), shifted only as far as the screen's edges require. Parameterised over the icon's position.
    @MainActor func testNormalFactoryOpensDirectlyBelowTheMenuBarIcon() throws {
        let (owner,bundle,context,_)=try shellFixture()
        let usable=try XCTUnwrap(NSScreen.main).visibleFrame
        let cases:[(String,CGFloat)]=[("near the left edge",usable.minX+2),("middle",usable.midX),("near the right edge",usable.maxX-22)]
        for (name,x) in cases {
            let anchor=CGRect(x:x,y:usable.maxY,width:20,height:20)
            owner.anchor={ anchor }
            let page=owner.makePage(context:context,verified:bundle)
            page.open()
            let window=try XCTUnwrap(page.window,name)
            XCTAssertEqual(window.frame.maxY,anchor.minY-6,accuracy:1,"\(name): top is 6 pt under the icon")
            XCTAssertLessThanOrEqual(window.frame.maxY,anchor.minY,"\(name): never above the icon")
            let expectedX=max(usable.minX,min(anchor.midX-window.frame.width/2,usable.maxX-window.frame.width))
            XCTAssertEqual(window.frame.minX,expectedX,accuracy:1,"\(name): centred on the icon, clamped to the screen")
            XCTAssertGreaterThanOrEqual(window.frame.minX,usable.minX-1,name)
            XCTAssertLessThanOrEqual(window.frame.maxX,usable.maxX+1,name)
            page.discard()
        }
    }

    /// macrev2-435-1 (D118): the Reduce transparency setting is read back by the cockpit at open and on change, as reduceMotion is.
    @MainActor func testReduceTransparencySettingReachesTheCockpitAtOpenAndOnChange() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent("u11-reduce-transparency-"+UUID().uuidString)
        defer{try? FileManager.default.removeItem(at:root)}
        let settings=try EngineRowsEntry.makeSettingsStore(applicationSupport:root)
        _=try await settings.update { $0.transparency = .on }
        var applied:[SettingsApplication]=[]
        let app=SettingsApplicationCoordinator(store:settings) { applied.append($0) }
        await app.reload()
        let client=RouteClient();await client.suspendCockpit()
        let composition=EngineDockMenuComposition(configuration:.init(executableURL:URL(fileURLWithPath:"/synthetic/not-launched"),applicationVersion:"synthetic",allowedEnvironment:[:]),createsNativePanels:false,makeClient:{_,_ in client})
        let owner=CockpitConsoleOwner(bundle:root,settingsStore:settings)
        XCTAssertFalse(owner.appearance.reduceTransparency)
        let page=ClearingPage(try .init(sessionID:UUID(),storeEpoch:"synthetic",generation:1),sink:ClearSink())
        let coordinator=EngineCockpitCoordinator { _ in page }
        coordinator.bind(client:client);owner.coordinator=coordinator
        let surface=SharedEngineCockpitConsole(owner:owner,composition:composition,isForeground:{true},activate:{})
        surface.applySettings(try XCTUnwrap(applied.last))
        let context=EngineDeliveryContext(sessionID:"s-"+page.state.context.sessionID.uuidString.lowercased(),floor:.init(storeEpoch:"synthetic",generation:1),revision:1)
        await coordinator.consume(.context(context));surface.show()
        for _ in 0..<100 { if await client.cockpitPending { break };try await Task.sleep(for:.milliseconds(10)) }
        XCTAssertTrue(owner.appearance.reduceTransparency,"Opening keeps the setting")
        _=try await settings.update { $0.transparency = .system }
        await app.reload()
        surface.applySettings(try XCTUnwrap(applied.last))
        let delivered=try XCTUnwrap(page.appearances.last,"A change reaches the open page")
        XCTAssertFalse(delivered.reduceTransparency,"System follows the (unreduced) CI display setting")
        surface.hide();await coordinator.shutdown();await composition.stop()
    }

    /// CKP-PORT-12 (D118): the three porthole gestures, through the Swift path from the page's intent to the panel. The
    /// page sends an unfocused openField for the ⤢ key and for a double-click, and openField with the rocket's published
    /// name for a click on a rocket; the console opens the field, focused only when the name is published.
    /// (The bridge's own message validation is covered by V2BridgeContractTests.)
    @MainActor func testPortholeGesturesOpenTheFieldThroughTheProductionConsole() async throws {
        let cases:[(String,CockpitIntent,String?)]=[("expand key",.openField,nil),("double-click",.openField,nil),
            ("rocket click",.openFieldAt("Synthetic"),"synthetic-model"),("unpublished rocket",.openFieldAt("Not published"),nil)]
        for (name,intent,focus) in cases {
            let root=FileManager.default.temporaryDirectory.appendingPathComponent("u11-port12-"+UUID().uuidString)
            // The bundle sits in its own folder: the verified bundle refuses any file its manifest does not list, so the
            // settings store's support folder must not share the bundle's root.
            let bundleRoot=root.appendingPathComponent("bundle")
            try FileManager.default.createDirectory(at:bundleRoot,withIntermediateDirectories:true)
            defer{try? FileManager.default.removeItem(at:root)}
            let html=Data("<!doctype html><title>synthetic field</title>".utf8)
            for file in ["index.html","field.html"] { try html.write(to:bundleRoot.appendingPathComponent(file)) }
            let manifest=try JSONSerialization.data(withJSONObject:["schemaVersion":1,"edition":"community","interfaceOnly":true,
                "files":["index.html":VerifiedCockpitBundle.digest(html),"field.html":VerifiedCockpitBundle.digest(html)]])
            try manifest.write(to:bundleRoot.appendingPathComponent("bundle-manifest.json"))
            let settings=try EngineRowsEntry.makeSettingsStore(applicationSupport:root.appendingPathComponent("support"))
            let client=RouteClient();await client.suspendCockpit()
            let composition=EngineDockMenuComposition(configuration:.init(executableURL:URL(fileURLWithPath:"/synthetic/not-launched"),applicationVersion:"synthetic",allowedEnvironment:[:]),createsNativePanels:false,makeClient:{_,_ in client})
            let owner=CockpitConsoleOwner(bundle:bundleRoot,settingsStore:settings)
            owner.verifiedBundle=try VerifiedCockpitBundle(root:bundleRoot,manifestSHA256:VerifiedCockpitBundle.digest(manifest))
            let page=ClearingPage(try .init(sessionID:UUID(),storeEpoch:"synthetic",generation:1),sink:ClearSink())
            let coordinator=EngineCockpitCoordinator { _ in page }
            coordinator.bind(client:client);owner.coordinator=coordinator
            let surface=SharedEngineCockpitConsole(owner:owner,composition:composition,isForeground:{true},activate:{})
            var capture=URL(fileURLWithPath:#filePath).deletingLastPathComponent()
            while !FileManager.default.fileExists(atPath:capture.appendingPathComponent("schema/app-cli/captures").path) { capture.deleteLastPathComponent() }
            capture=capture.appendingPathComponent("schema/app-cli/captures/WireCockpitData.json")
            var data=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:capture)) as? [String:Any])
            var details=try XCTUnwrap(data["details"] as? [String:Any])
            details["publishedModels"]=[["id":"synthetic-model","name":"Synthetic","developerId":"openai","recommended":"medium",
                "efforts":[["effort":"medium","label":"Med","star":true,"ability":40.0,"cost":0.2,"time":30.0]]]]
            data["details"]=details
            let wire=try WireDecoder.decode(WireCockpitData.self,from:JSONSerialization.data(withJSONObject:data))
            let context=EngineDeliveryContext(sessionID:"s-"+page.state.context.sessionID.uuidString.lowercased(),floor:.init(storeEpoch:"synthetic",generation:1),revision:1)
            await composition.store.consume(.connection(.ready(context)));await composition.store.consume(.context(context))
            await composition.store.consume(.response(requestID:.string("cockpit"),.cockpit(.init(envelope:try .init(sessionId:context.sessionID,storeEpoch:context.floor.storeEpoch,consentGeneration:1,data:wire),delivery:context))))
            await coordinator.consume(.context(context));surface.show()
            for _ in 0..<200 where page.onClosed == nil { try await Task.sleep(for:.milliseconds(10)) }
            XCTAssertNotNil(page.onClosed,"\(name): the cockpit page opened")
            XCTAssertFalse(surface.fieldIsOpen,name)
            let deliver=try XCTUnwrap(page.onIntent,"\(name): the coordinator listens to the page")
            deliver(intent)
            XCTAssertTrue(surface.fieldIsOpen,"\(name): the gesture opens the enlarged field")
            let payload=try XCTUnwrap(surface.fieldPayload(focusName:{ if case .openFieldAt(let n)=intent { return n }; return nil }()))
            if let focus { XCTAssertTrue(payload.contains(#""focus":"\#(focus)""#),"\(name): \(payload)") }
            else { XCTAssertTrue(payload.contains(#""focus":null"#) || !payload.contains(#""focus""#),"\(name): no focus") }
            surface.hide()
            XCTAssertFalse(surface.fieldIsOpen,"\(name): closing the cockpit closes the field")
            await coordinator.shutdown();await composition.stop()
        }
    }

#if MODELPLAN_TEST_ONLY_SPI
    /// CKP-FAD-04 (D118): on the real official page opened by the normal factory, a published model's fader shows its
    /// effort bars and the recommended-effort star marker. Needs the canonical official cockpit and the synthetic CLI.
    @MainActor func testFaderBarsAndStarShowOnTheRealPageThroughTheNormalEntry() async throws {
        let official=Self.repoRoot().appendingPathComponent("desktop/cockpit/.tmp/official")
        guard let path=ProcessInfo.processInfo.environment["MODELPLAN_U11_TEST_CLI"],FileManager.default.isExecutableFile(atPath:path),
              FileManager.default.fileExists(atPath:official.appendingPathComponent("bundle-manifest.json").path),
              !CommunityCockpitApplicationFactory.manifestPins.isEmpty else {
            throw XCTSkip("The real page needs the canonical official cockpit, its pins and the synthetic-test CLI")
        }
        _ = NSApplication.shared
        let root=FileManager.default.temporaryDirectory.appendingPathComponent("fad04-"+UUID().uuidString).resolvingSymlinksInPath()
        defer{try? FileManager.default.removeItem(at:root)}
        let helper=URL(fileURLWithPath:path)
        let app=try Self.ownerTestShapedApp(at:root,helper:helper,ownerTest:true,official:official)
        let settings=try EngineRowsEntry.makeSettingsStore(applicationSupport:root.appendingPathComponent("support"),preferredLanguages:["en"])
        let owner=CockpitConsoleOwner(bundle:app,settingsStore:settings)
        let capture=Self.repoRoot().appendingPathComponent("schema/app-cli/captures/WireCockpitData.json")
        var json=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:capture)) as? [String:Any])
        let details=try XCTUnwrap(json["details"] as? [String:Any])
        let publication=try XCTUnwrap(details["publication"] as? [String:Any])
        let model=try XCTUnwrap((publication["models"] as? [[String:Any]])?.first)
        XCTAssertEqual(model["id"] as? String,"synthetic-model","the capture's one published model")
        let wire=try WireDecoder.decode(WireCockpitData.self,from:JSONSerialization.data(withJSONObject:json))
        let context=try CockpitEngineContext(sessionID:UUID(),storeEpoch:"synthetic-fad04",generation:1)
        let page=try owner.makePage(context:context,executable:app.appendingPathComponent("Contents/Helpers/modelplan"))
        defer{page.discard()}
        var ready=false;page.onReady={ready=true}
        // The page takes data only once it is confirmed visible (a hidden page drops it), so send it from onShown, as the
        // coordinator does, instead of repeating display while the first receipt is pending.
        var trace=[String]()
        page.onShown={ trace.append("onShown ticket=\(page.queryTicket != nil)"); if let ticket=page.queryTicket { page.display(wire,ticket:ticket); trace.append("display sent") } }
        page.onRendered={ trace.append("onRendered") }
        page.open()
        let deadline=ContinuousClock.now + .seconds(30)
        while !ready && ContinuousClock.now<deadline { try await Task.sleep(for:.milliseconds(20)) }
        XCTAssertTrue(ready,"the real page becomes ready")
        let paintDeadline=ContinuousClock.now + .seconds(30)
        let web=try XCTUnwrap(page.verificationWebView)
        let script="""
        (()=>{const ch=document.querySelector('.fd-ch:not(.empty)');if(!ch)return 'no-fader';
        const bars=[...ch.querySelectorAll('.fd-strip .eb')].filter(e=>/px$/.test(e.style.getPropertyValue('--h'))).length;
        const rec=ch.querySelector('.fd-marks .fd-rec');const k=rec?rec.style.getPropertyValue('--k'):'';
        return bars+'|'+(rec?'rec':'norec')+'|'+(k!==''&&Number.isFinite(Number(k))?'k':'nok');})()
        """
        var result="none"
        while ContinuousClock.now<paintDeadline {
            try await Task.sleep(for:.milliseconds(200))
            result=((try? await web.evaluateJavaScript(script)) as? String) ?? "none"
            if result != "none" && result != "no-fader" { break }
        }
        // Diagnostics for a failed paint: the controller's own flags and the page's raw DOM state.
        let dom=((try? await web.evaluateJavaScript("""
        (()=>{const all=document.querySelectorAll('.fd-ch').length,filled=document.querySelectorAll('.fd-ch:not(.empty)').length,
        models=[...document.querySelectorAll('.fd-ch')].map(e=>e.dataset.model).join(','),root=document.querySelector('#cockpit');
        return 'fd-ch='+all+' filled='+filled+' models=['+models+'] hidden='+document.hidden+' detailsAvailable='+(root?root.dataset.detailsAvailable:'noroot')
        +' bank='+(document.querySelector('.bank-lcd')?.textContent??'none')+' waiting='+(document.querySelector('.mp-empty')?.textContent??'none');})()
        """)) as? String) ?? "unreadable"
        let diagnostics="trace=\(trace) dom={\(dom)} windowVisible=\(page.window?.isVisible ?? false) occlusion=\(page.window?.occlusionState.contains(.visible) ?? false) appActive=\(NSApp.isActive) key=\(page.window?.isKeyWindow ?? false)"
        let parts=result.split(separator:"|").map(String.init)
        XCTAssertEqual(parts.count,3,"the fader painted: \(result) \(diagnostics)")
        XCTAssertGreaterThan(Int(parts.first ?? "0") ?? 0,0,"the fader shows effort bars (\(result))")
        XCTAssertEqual(parts.dropFirst().first,"rec","the recommended-effort star marker is on the fader (\(result))")
        XCTAssertEqual(parts.last,"k","and sits at a numeric travel position (\(result))")
    }
#endif
}
