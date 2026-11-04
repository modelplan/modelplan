// SPDX-License-Identifier: MIT
import AppKit
import Foundation
import XCTest
import ModelPlanSettings
import ModelPlanEngineStore
import ModelPlanEngineClient
import ModelPlanWire
@testable import ModelPlanAppIntegration

private actor G1MenuRowsClient: EngineClient {
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

@MainActor final class G1MenuJourneys: XCTestCase {
    func testG1_MENU_05() async throws {
        let profile=FileManager.default.temporaryDirectory.appendingPathComponent("g1-menu-"+UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:profile) }
        let capture=URL(fileURLWithPath:#filePath).deletingLastPathComponent().appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        var root=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:capture)) as? [String:Any])
        var projection=try XCTUnwrap(root["projection"] as? [String:Any])
        var row=try XCTUnwrap((projection["rows"] as? [[String:Any]])?.first)
        var account=try XCTUnwrap((row["accounts"] as? [[String:Any]])?.first)
        var window=try XCTUnwrap((account["windows"] as? [[String:Any]])?.first)
        row["state"]="fresh";row["consent"]="allowed";row["surfaces"]=["dock","menu"];row["expiresAt"]="2099-01-01T00:00:00Z"
        account["subscriptionRef"]="0123456789abcdef";account["valueState"]="current";account["freshUntil"]="2099-01-01T00:00:00Z"
        window["id"]="five";window["role"]="session";window["limitKey"]="main";window["poolKey"]="main"
        window["current"]=true;window["remainingPercent"]=41;window["validUntil"]="2099-01-01T00:00:00Z";window["resetsAt"]="2099-01-01T00:00:00Z"
        account["windows"]=[window];row["accounts"]=[account];projection["rows"]=[row];root["projection"]=projection
        let rows=try WireDecoder.decode(WireRowsSnapshot.self,from:JSONSerialization.data(withJSONObject:root))
        let app=EngineRowsEntry.make(configuration:.init(executableURL:URL(fileURLWithPath:"/synthetic/never-launched"),applicationVersion:"g1",allowedEnvironment:[:],offline:true,readOnly:true),settingsStore:try EngineRowsEntry.makeSettingsStore(applicationSupport:profile,preferredLanguages:["en"]),createsNativePanels:false,makeClient:{_,store in G1MenuRowsClient(store:store,rows:rows)},activateSettings:{})
        await app.prepare();await app.composition.start()
        defer { app.composition.dock.close() }
        let options=XCTExpectedFailure.Options()
        options.isStrict=true
        XCTExpectFailure("MENU-05 remains open",options:options) {
            XCTAssertEqual(app.composition.latestSettings?.effective.menuDisplay,.tightest)
            XCTAssertEqual(app.composition.menuPresentation.title,"41%")
        }
        await app.composition.stop()
    }
}
