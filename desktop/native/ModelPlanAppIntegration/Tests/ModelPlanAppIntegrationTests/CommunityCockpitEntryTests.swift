// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanSettings
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanDock
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
    var appearances:[CockpitAppearance]=[]
    func updateAppearance(_ appearance:CockpitAppearance){appearances.append(appearance)}
}

final class CommunityCockpitEntryTests:XCTestCase {
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
        surface.handle(.openField)
        XCTAssertTrue(surface.fieldIsOpen)
        surface.hide()
        XCTAssertFalse(surface.fieldIsOpen,"Closing the cockpit closes the field")
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
