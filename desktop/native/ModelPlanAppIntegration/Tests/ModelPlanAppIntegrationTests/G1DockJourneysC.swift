// SPDX-License-Identifier: MIT
import AppKit
import Foundation
import XCTest
import ModelPlanSettings
import ModelPlanEngineStore
import ModelPlanEngineClient
import ModelPlanWire
@testable import ModelPlanAppIntegration

private actor G1PartCRowsClient: EngineClient {
    nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool { true }
    let store: EngineStore, rows: WireRowsSnapshot
    let context = EngineDeliveryContext(sessionID: "g1-part-c", floor: .init(storeEpoch: "g1-part-c", generation: 1), revision: 1)
    private var revision: UInt64 = 1
    init(store: EngineStore, rows: WireRowsSnapshot) { self.store=store; self.rows=rows }
    func start() async throws -> EngineDeliveryContext {
        await store.consume(.connection(.ready(context)))
        await store.consume(.context(context))
        await store.consume(.rowsChanged(.init(envelope: try .init(sessionId:context.sessionID,storeEpoch:context.floor.storeEpoch,consentGeneration:1,data:rows),delivery:context),invalidRowCount:0))
        return context
    }
    func stop() async {}
    func replaceRows(_ nextRows: WireRowsSnapshot) async throws {
        revision += 1
        let next=EngineDeliveryContext(sessionID:context.sessionID,floor:context.floor,revision:revision)
        await store.consume(.context(next))
        await store.consume(.rowsChanged(.init(envelope:try .init(sessionId:next.sessionID,storeEpoch:next.floor.storeEpoch,consentGeneration:next.floor.generation,data:nextRows),delivery:next),invalidRowCount:0))
    }
    func retry() async throws -> EngineDeliveryContext { try await start() }
    func subscribeRows(timeout:Duration?) async throws -> EngineRequestCompletion { .init(requestID:.string("g1-rows")) }
    func consent(timeout:Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func grant(_ request:WireConsentGrantParams,userAction:EngineUserAction?,timeout:Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func refresh(_ request:WireRefreshRequestParams,timeout:Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func history(_ request:WireHistoryQueryParams,timeout:Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func cockpit(timeout:Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func publication(timeout:Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func pluginInstall(_ request:WirePluginInstallParams,timeout:Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func diagnostics(timeout:Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
}

@MainActor final class G1DockJourneysC: XCTestCase {
    func testG1_DOCK_3_3_04() async throws {
        let profile=FileManager.default.temporaryDirectory.appendingPathComponent("g1-tightest-"+UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:profile) }
        let capture=URL(fileURLWithPath:#filePath).deletingLastPathComponent().appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        var root=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:capture)) as? [String:Any])
        var projection=try XCTUnwrap(root["projection"] as? [String:Any])
        var row=try XCTUnwrap((projection["rows"] as? [[String:Any]])?.first)
        var account=try XCTUnwrap((row["accounts"] as? [[String:Any]])?.first)
        let original=try XCTUnwrap((account["windows"] as? [[String:Any]])?.first)
        row["state"]="fresh";row["consent"]="allowed";row["surfaces"]=["dock","menu"];row["expiresAt"]="2099-01-01T00:00:00Z"
        account["subscriptionRef"]="0123456789abcdef";account["valueState"]="current";account["freshUntil"]="2099-01-01T00:00:00Z"
        func snapshot(_ amounts:[Double]) throws -> WireRowsSnapshot {
            account["windows"]=zip([( "five","session",18000),("week","weekly",604800),("month","monthly",2592000)],amounts).map { spec,amount -> [String:Any] in
                var window=original;window["id"]=spec.0;window["role"]=spec.1;window["durationSeconds"]=spec.2
                window["remainingPercent"]=amount;window["limitKey"]="main";window["poolKey"]="main"
                window["current"]=true;window["validUntil"]="2099-01-01T00:00:00Z";window["resetsAt"]="2099-01-01T00:00:00Z"
                window.removeValue(forKey:"modelScope");return window
            }
            row["accounts"]=[account];projection["rows"]=[row];root["projection"]=projection
            return try WireDecoder.decode(WireRowsSnapshot.self,from:JSONSerialization.data(withJSONObject:root))
        }
        let initial=try snapshot([41,25,70])
        let app=EngineRowsEntry.make(configuration:.init(executableURL:URL(fileURLWithPath:"/synthetic/never-launched"),applicationVersion:"g1",allowedEnvironment:[:],offline:true,readOnly:true),settingsStore:try EngineRowsEntry.makeSettingsStore(applicationSupport:profile,preferredLanguages:["en"]),createsNativePanels:false,makeClient:{_,store in G1PartCRowsClient(store:store,rows:initial)},activateSettings:{})
        await app.prepare();app.composition.dock.setPresentationAllowed(true);await app.composition.start()
        defer { app.composition.dock.close() }
        func readout() throws -> String {
            let nodes=(app.composition.dock.dockView.accessibilityChildren() ?? []).compactMap { $0 as? NSAccessibilityElement }
            return try XCTUnwrap(nodes.first { $0.accessibilityIdentifier() == "dock.subscription.0123456789abcdef" }?.accessibilityValue() as? String)
        }
        XCTAssertEqual(try readout(),"25%")
        let client=try XCTUnwrap(app.composition.client as? G1PartCRowsClient)
        try await client.replaceRows(snapshot([41,55,10]))
        XCTAssertEqual(try readout(),"10%")
        try await client.replaceRows(snapshot([5,55,60]))
        XCTAssertEqual(try readout(),"5%")
        await app.composition.stop()
    }
    // DOCK-3.3-06: observe the actual retained widget's accessibility value,
    // not a separately evaluated projection. The profile survives app recreation.
    func testG1_DOCK_3_3_06() async throws {
        let profile=FileManager.default.temporaryDirectory.appendingPathComponent("g1-dock-c-"+UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:profile) }
        let capture=URL(fileURLWithPath:#filePath).deletingLastPathComponent().appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        var root=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:capture)) as? [String:Any])
        var projection=try XCTUnwrap(root["projection"] as? [String:Any])
        var row=try XCTUnwrap((projection["rows"] as? [[String:Any]])?.first)
        var account=try XCTUnwrap((row["accounts"] as? [[String:Any]])?.first)
        var window=try XCTUnwrap((account["windows"] as? [[String:Any]])?.first)
        row["state"]="fresh";row["consent"]="allowed";row["surfaces"]=["dock","menu"];row["expiresAt"]="2099-01-01T00:00:00Z"
        account["subscriptionRef"]="0123456789abcdef";account["valueState"]="current";account["freshUntil"]="2099-01-01T00:00:00Z"
        window["id"]="five";window["role"]="session";window["limitKey"]="five_hour";window["poolKey"]="main"
        window["current"]=true;window["remainingPercent"]=41;window["validUntil"]="2099-01-01T00:00:00Z";window["resetsAt"]="2099-01-01T00:00:00Z"
        account["windows"]=[window];row["accounts"]=[account];projection["rows"]=[row];root["projection"]=projection
        let rows=try WireDecoder.decode(WireRowsSnapshot.self,from:JSONSerialization.data(withJSONObject:root))
        func makeApp() throws -> EngineDockMenuApplication {
            EngineRowsEntry.make(configuration:.init(executableURL:URL(fileURLWithPath:"/synthetic/never-launched"),applicationVersion:"g1",allowedEnvironment:[:],offline:true,readOnly:true),settingsStore:try EngineRowsEntry.makeSettingsStore(applicationSupport:profile,preferredLanguages:["en"]),createsNativePanels:false,makeClient:{_,store in G1PartCRowsClient(store:store,rows:rows)},activateSettings:{})
        }
        func readout(_ app:EngineDockMenuApplication) throws -> String {
            let nodes=(app.composition.dock.dockView.accessibilityChildren() ?? []).compactMap { $0 as? NSAccessibilityElement }
            let node=try XCTUnwrap(nodes.first { $0.accessibilityIdentifier() == "dock.subscription.0123456789abcdef" })
            return try XCTUnwrap(node.accessibilityValue() as? String)
        }
        let first=try makeApp();await first.prepare();first.composition.dock.setPresentationAllowed(true);await first.composition.start()
        XCTAssertEqual(first.settingsHost.application.editor.snapshot?.preferences.percentageMode,.remaining)
        XCTAssertEqual(try readout(first),"41%")
        _=try await first.settingsHost.application.editor.commit(SettingsB20Edit.percentageMode(.used))
        XCTAssertEqual(try readout(first),"59%")
        await first.composition.stop();first.composition.dock.close()
        let second=try makeApp();await second.prepare();second.composition.dock.setPresentationAllowed(true);await second.composition.start()
        XCTAssertEqual(second.settingsHost.application.editor.snapshot?.preferences.percentageMode,.used)
        XCTAssertEqual(try readout(second),"59%")
        await second.composition.stop();second.composition.dock.close()
    }
}
