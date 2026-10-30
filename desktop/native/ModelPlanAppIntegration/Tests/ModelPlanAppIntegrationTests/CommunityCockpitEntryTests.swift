// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanCockpitWeb
import ModelPlanWire
@testable import ModelPlanAppIntegration

private actor RouteClient: EngineClient {
    nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool { false }
    var stops=0
    func start() throws -> EngineDeliveryContext { throw EngineClientError.notReady }
    func retry() throws -> EngineDeliveryContext { throw EngineClientError.notReady }
    func stop() { stops += 1 }
    func cockpit(timeout:Duration?) throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
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

}
