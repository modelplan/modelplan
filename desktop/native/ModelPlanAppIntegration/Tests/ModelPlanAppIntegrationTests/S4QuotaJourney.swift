// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanDock
import ModelPlanSettings
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanWire
import ModelPlanAppIntegration

private actor S4RowsClient: EngineClient {
    nonisolated func isCurrent(_ context:EngineDeliveryContext) -> Bool { true }
    let store:EngineStore, rows:WireRowsSnapshot
    let context=EngineDeliveryContext(sessionID:"s4-fixture",floor:.init(storeEpoch:"s4-fixture",generation:1),revision:1)
    init(store:EngineStore,rows:WireRowsSnapshot) { self.store=store;self.rows=rows }
    func start() async throws -> EngineDeliveryContext {
        await store.consume(.connection(.ready(context)))
        await store.consume(.rowsChanged(.init(envelope:try .init(sessionId:context.sessionID,storeEpoch:context.floor.storeEpoch,consentGeneration:1,data:rows),delivery:context),invalidRowCount:0))
        return context
    }
    func stop() async {}
    func retry() async throws -> EngineDeliveryContext { try await start() }
    func subscribeRows(timeout:Duration?) async throws -> EngineRequestCompletion { .init(requestID:.string("s4-rows")) }
    func refresh(_ request:WireRefreshRequestParams,timeout:Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func consent(timeout:Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func grant(_ request:WireConsentGrantParams,userAction:EngineUserAction?,timeout:Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func history(_ request:WireHistoryQueryParams,timeout:Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func cockpit(timeout:Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func publication(timeout:Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func pluginInstall(_ request:WirePluginInstallParams,timeout:Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func diagnostics(timeout:Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
}

/// Runs through the real normal entry; only the external engine is synthetic.
/// It opens no windows, starts no engine child, and posts no input.
@MainActor enum S4QuotaJourney {
    struct Failure:Error,CustomStringConvertible { let description:String }
    static func require(_ condition:Bool,_ message:String) throws { if !condition { throw Failure(description:message) } }
    static func roles(capture:URL) async throws {
        var root=try JSONSerialization.jsonObject(with:Data(contentsOf:capture)) as! [String:Any]
        var projection=root["projection"] as! [String:Any]
        var row=(projection["rows"] as! [[String:Any]])[0]
        row["state"]="fresh";row["surfaces"]=["dock","menu"];row["expiresAt"]="2099-01-01T00:00:00Z"
        var account=(row["accounts"] as! [[String:Any]])[0]
        account["valueState"]="current";account["freshUntil"]="2099-01-01T00:00:00Z"
        let original=(account["windows"] as! [[String:Any]])[0]
        func window(_ id:String,_ role:String,_ remaining:Double,_ duration:Int) -> [String:Any] {
            var w=original;w["id"]=id;w["role"]=role;w["remainingPercent"]=remaining;w["durationSeconds"]=duration
            w["current"]=true;w["resetsAt"]="2099-01-01T00:00:00Z";w["validUntil"]="2099-01-01T00:00:00Z"
            w["limitKey"]=role == "other" ? "other":"main";w["poolKey"]=role == "other" ? "other":"main"
            return w
        }
        // Array order, duration and low extra all disagree with the semantic role.
        account["windows"]=[window("extra","other",1,60),window("weekly","weekly",24,604800),window("five","session",63,18000),window("month","monthly",80,2592000)]
        row["accounts"]=[account];projection["rows"]=[row];root["projection"]=projection
        let rows=try WireDecoder.decode(WireRowsSnapshot.self,from:JSONSerialization.data(withJSONObject:root))
        let directory=FileManager.default.temporaryDirectory.appendingPathComponent("s4-journey-"+UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:directory) }
        let store=try SettingsStore(url:directory.appendingPathComponent("settings.json"))
        let entry=EngineRowsEntry.make(configuration:.init(executableURL:URL(fileURLWithPath:"/synthetic/never-launched"),applicationVersion:"s4",allowedEnvironment:[:],offline:true,readOnly:true),settingsStore:store,createsNativePanels:false,makeClient:{_,store in S4RowsClient(store:store,rows:rows)},activateSettings:{})
        await entry.prepare();await entry.composition.start()
        defer { entry.composition.dock.close() }
        guard let input=entry.composition.presentedContent.snapshot.inputs.first else { throw Failure(description:"normal entry lost the quota member") }
        let reading=try DockInstrumentProjection.evaluate(input,now:Date())
        try require(reading.remainingPercent == 24,"tightest must exclude model-specific extra (expected24)")
        try require(reading.inner?.windowID.hasSuffix("five") == true,"inner must use5h role")
        try require(reading.outer?.windowID.hasSuffix("weekly") == true,"outer must useweekly role")
        try require(input.windows.first(where:{$0.id.hasSuffix("month")})?.period == .month,"monthly role must survive")
        await entry.composition.stop()
    }
    static func members(capture:URL) async throws {
        var root=try JSONSerialization.jsonObject(with:Data(contentsOf:capture)) as! [String:Any]
        var projection=root["projection"] as! [String:Any],row=(projection["rows"] as! [[String:Any]])[0]
        var first=(row["accounts"] as! [[String:Any]])[0],second=first
        first["subscriptionRef"]="0123456789abcdef";second["subscriptionRef"]="fedcba9876543210"
        first["credits"]=["balance":42.5,"unit":"credits"];second["credits"]=["balance":7,"unit":"credits"]
        row["surfaces"]=["dock","menu","settings"];row["accounts"]=[first,second]
        projection["rows"]=[row];root["projection"]=projection
        let rows=try WireDecoder.decode(WireRowsSnapshot.self,from:JSONSerialization.data(withJSONObject:root))
        let directory=FileManager.default.temporaryDirectory.appendingPathComponent("s4-members-"+UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:directory) }
        let store=try SettingsStore(url:directory.appendingPathComponent("settings.json"))
        try await store.update { $0.language = .english }
        let entry=EngineRowsEntry.make(configuration:.init(executableURL:URL(fileURLWithPath:"/synthetic/never-launched"),applicationVersion:"s4",allowedEnvironment:[:],offline:true,readOnly:true),settingsStore:store,createsNativePanels:false,makeClient:{_,store in S4RowsClient(store:store,rows:rows)},activateSettings:{})
        await entry.prepare();await entry.composition.start()
        defer { entry.composition.dock.close() }
        let content=entry.composition.presentedContent
        try require(content.snapshot.inputs.map(\.id) == ["0123456789abcdef","fedcba9876543210"],"two account members must have their verified display keys")
        try require(content.snapshot.inputs.allSatisfy{$0.windows.count == 1},"one account's windows must not be duplicated into its neighbour")
        try require(content.snapshot.inputs.map(\.name) == ["synthetic · Account 1","synthetic · Account 2"],"each duplicate-account nozzle needs its tag")
        try require(content.snapshot.subscriptions.map(\.id) == ["0123456789abcdef","fedcba9876543210"],"Settings catalogue must use the same member keys")
        await entry.composition.stop()
    }
}
