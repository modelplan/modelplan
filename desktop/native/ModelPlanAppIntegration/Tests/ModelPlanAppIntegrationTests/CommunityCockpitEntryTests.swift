// SPDX-License-Identifier: MIT
import AppKit
import CryptoKit
import XCTest
import ModelPlanSettings
import ModelPlanEngineClient
import ModelPlanEngineStore
@testable import ModelPlanCockpitWeb
import ModelPlanWire
@testable import ModelPlanAppIntegration

private actor RouteClient: EngineClient {
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
        value["appearance"]=nil;value["shell"]=nil;value["redBelow"]=nil;value["type"]="ready";value["sequence"]="1"
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
}

final class CommunityCockpitEntryTests:XCTestCase {
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
        let origin=CGPoint(x:window.frame.minX-20,y:window.frame.minY-20)
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
        let origin=CGPoint(x:window.frame.minX-20,y:window.frame.minY-20)
        window.setFrameOrigin(origin)
        _=app.perform(NSSelectorFromString("showConsoleMenu"))
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
    @MainActor func testProductionPinsAdmitCanonicalBundles() async throws {
        var repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 {
            if FileManager.default.fileExists(atPath: repo.appendingPathComponent("desktop/cockpit/build.mjs").path) { break }
            repo.deleteLastPathComponent()
        }
        let builds = repo.appendingPathComponent("desktop/cockpit/.tmp")
        guard FileManager.default.fileExists(atPath: builds.appendingPathComponent("community/bundle-manifest.json").path),
              FileManager.default.fileExists(atPath: builds.appendingPathComponent("official/bundle-manifest.json").path)
        else { throw XCTSkip("Build both canonical cockpit editions before running the admission check") }
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
        _=app.perform(NSSelectorFromString("showConsoleMenu"))
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
            let item=try XCTUnwrap(menu.items.first { $0.title == (enabled ? "Open Cockpit" : "Coming soon") })
            XCTAssertEqual(item.isEnabled,enabled)
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
                XCTAssertFalse(try XCTUnwrap(chineseDock.items.first { $0.title == "即将推出" }).isEnabled)
                app.composition.dock.pauseForLifecycle()
                let paused = app.composition.dock.menu()
                XCTAssertTrue(paused.items.contains { $0.title == "退出 ModelPlan" })
                XCTAssertTrue(paused.items.contains { $0.title == "即将推出" && !$0.isEnabled })
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
            let surface=SharedEngineCockpitConsole(owner:owner,composition:composition,isForeground:{true},activate:{},requestNotice:{notices.append($0)})
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

}
