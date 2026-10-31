// SPDX-License-Identifier: MIT
import AppKit
import XCTest
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
        let raw=try! state.load(.init(theme:.day,locale:.en,profile:.full))
        var value=try! JSONSerialization.jsonObject(with:Data(raw.utf8)) as! [String:Any]
        value["appearance"]=nil;value["type"]="ready";value["sequence"]="1"
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
    @MainActor func testBothActualConsoleActionsUseOneFactoryAndOneClient() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent("u11-route-"+UUID().uuidString)
        defer{try? FileManager.default.removeItem(at:root)}
        let store=try EngineRowsEntry.makeSettingsStore(applicationSupport:root)
        let client=RouteClient(),surface=ConsoleRouteProbe();var constructions=0,clients=0
        let app=EngineRowsEntry.make(configuration:.init(executableURL:URL(fileURLWithPath:"/synthetic/not-launched"),applicationVersion:"synthetic",allowedEnvironment:[:]),settingsStore:store,createsNativePanels:false,
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
