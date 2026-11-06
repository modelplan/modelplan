// SPDX-License-Identifier: MIT
import AppKit
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

#if MODELPLAN_TEST_ONLY_SPI
@MainActor private final class RealDetailsPage: CockpitPageSurface {
    private let bridge: CockpitBridgeState
    var onReady: (() -> Void)?
    var onIntent: ((CockpitIntent) -> Void)?
    var onClosed: (() -> Void)?
    private(set) var received = false
    private(set) var details: WireCockpitDetails?
    private(set) var cleared = false
    var queryTicket: CockpitQueryTicket? { bridge.queryTicket }

    init(_ context: CockpitEngineContext) { bridge = .init(context: context) }

    func open() {
        do {
            let raw = try bridge.load(.init(theme: .night, locale: .en, profile: .full, redBelow: 25),
                shell: .init(closed: false, attached: true, forcedClosed: false, tier: .tall))
            var value = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
            value["appearance"] = nil
            value["shell"] = nil
            value["redBelow"] = nil
            value["type"] = "ready"
            value["sequence"] = "1"
            value["appearanceVersion"] = 2
            value["capabilities"] = ["appearanceUpdates", "shellState", "shellActions"]
            let message = String(decoding: try JSONSerialization.data(withJSONObject: value), as: UTF8.self)
            _ = try bridge.accept(message, source: .init(mainFrame: true, origin: "modelplan-cockpit://bundle"))
            onReady?()
        } catch { XCTFail("Synthetic page failed to become ready: \(error)") }
    }

    func display(_ data: WireCockpitData, ticket: CockpitQueryTicket) {
        received = true
        details = data.details
    }

    func clearPrivateViews(adopting context: CockpitEngineContext?) async {
        details = nil
        cleared = true
        _ = try? bridge.clear(adopting: context)
    }

    func discard() { bridge.dispose(); onClosed?() }
}
#endif

final class CommunityCockpitEntryTests:XCTestCase {
    #if MODELPLAN_TEST_ONLY_SPI
    @MainActor func testNormalEntryReceivesCockpitDetailsFromRealAppServer() async throws {
        guard let path = ProcessInfo.processInfo.environment["MODELPLAN_U11_TEST_CLI"],
              FileManager.default.isExecutableFile(atPath: path) else {
            throw XCTSkip("The real synthetic-test CLI is not available")
        }
        let helper = URL(fileURLWithPath: path)
        let home = FileManager.default.temporaryDirectory.appendingPathComponent("cockpit-details-" + UUID().uuidString)
        let cache = home.appendingPathComponent("Library/Caches/modelplan/observed")
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: home.appendingPathComponent(".codex"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }
        let environment = ["HOME": home.path, "TMPDIR": home.path, "PATH": "/usr/bin:/bin", "LANG": "C"]

        func command(_ arguments: [String], input: [String: Any]? = nil) async throws -> [String: Any] {
            let process = Process(), output = Pipe()
            process.executableURL = helper
            process.arguments = arguments
            process.environment = environment
            process.standardOutput = output
            process.standardError = FileHandle.nullDevice
            let stdin = input.map { _ in Pipe() }
            process.standardInput = stdin ?? FileHandle.nullDevice
            try process.run()
            if let input, let stdin {
                try stdin.fileHandleForWriting.write(contentsOf: JSONSerialization.data(withJSONObject: input))
                try stdin.fileHandleForWriting.close()
            }
            let deadline = ContinuousClock.now + .seconds(5)
            while process.isRunning && ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(10)) }
            if process.isRunning { process.terminate(); throw CocoaError(.fileReadUnknown) }
            XCTAssertEqual(process.terminationStatus, 0, arguments.joined(separator: " "))
            return try XCTUnwrap(JSONSerialization.jsonObject(with: output.fileHandleForReading.readDataToEndOfFile()) as? [String: Any])
        }

        _ = try await command(["consent", "init", "--json"])
        let before = try await command(["consent", "--json"])
        let epoch = try XCTUnwrap(before["storeEpoch"] as? String)
        _ = try await command(["consent", "grant", "--json"], input: [
            "requestId": UUID().uuidString.lowercased(), "expectStoreEpoch": epoch,
            "expectGeneration": try XCTUnwrap(before["generation"] as? Int),
            "consentTextVersion": try XCTUnwrap(before["consentTextVersion"] as? Int),
            "allow": ["codex.local_history"], "deny": [String]()
        ])
        let now = Date(), iso = ISO8601DateFormatter()
        func at(_ offset: Double) -> String { iso.string(from: now.addingTimeInterval(offset)) }
        func record(_ ref: String, source: String, running: Bool, last: Double) -> [String: Any] {
            ["ref": ref, "source": source, "model": "unverified-synthetic-alias", "effort": running ? "high" : "unverified",
             "startedAt": at(-10), "lastAt": at(last), "running": running,
             "grantEpoch": ["storeEpoch": epoch, "revokedGeneration": 0]]
        }
        let ledger: [String: Any] = ["schemaVersion": 1, "since": at(-3600), "rows": [], "live": [
            record("1111111111111111", source: "codex", running: true, last: -1),
            record("2222222222222222", source: "codex", running: false, last: -3),
            record("3333333333333333", source: "claude-code", running: true, last: -1)
        ]]
        try JSONSerialization.data(withJSONObject: ledger).write(to: cache.appendingPathComponent("perf.json"))

        var page: RealDetailsPage?
        let previousFactory = CommunityCockpitApplicationFactory.verificationPageFactory
        CommunityCockpitApplicationFactory.verificationPageFactory = { context in
            let surface = RealDetailsPage(context)
            page = surface
            return surface
        }
        defer { CommunityCockpitApplicationFactory.verificationPageFactory = previousFactory }
        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: home)
        let app = EngineRowsEntry.make(configuration: .init(executableURL: helper, applicationVersion: "synthetic-details-test",
            allowedEnvironment: environment, offline: true, readOnly: true), settingsStore: settings,
            createsNativePanels: false, cockpitEntryEnabled: true)
        await app.prepare()
        await app.composition.start()
        app.showConsole()
        let deadline = ContinuousClock.now + .seconds(5)
        do {
            while page?.received != true && ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(10)) }
            let surface = try XCTUnwrap(page, "The normal cockpit action must construct a page")
            XCTAssertTrue(surface.received, "The real cockpit response must reach the page")
            let details = try XCTUnwrap(surface.details, "The production initialize must negotiate cockpitDetailsV1")
            XCTAssertEqual(details.sessionCoverage, "local-last-seen")
            XCTAssertEqual(details.sessions.map(\.sessionRef), ["1111111111111111", "2222222222222222"])
            XCTAssertEqual(details.sessions.map(\.state), ["running", "idle"])
            XCTAssertEqual(details.sessions.map(\.model), ["unknown", "unknown"])
            XCTAssertTrue(details.sessions.allSatisfy { $0.rate == nil })
            await app.composition.stop()
            XCTAssertTrue(surface.cleared, "The normal engine stop must clear the page")
            XCTAssertNil(surface.details)
        } catch {
            await app.composition.stop()
            throw error
        }
    }
    #endif

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
