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
        var scopedWeekly=window("model","weekly",2,604800)
        scopedWeekly["limitKey"]="other";scopedWeekly["poolKey"]="other"
        scopedWeekly["label"]=["en":"Model-only looking label","zh":"看似专项的名称"]
        account["windows"]=[window("weekly","weekly",24,604800),window("extra","other",1,60),scopedWeekly,window("five","session",63,18000),window("month","monthly",80,2592000)]
        row["accounts"]=[account];projection["rows"]=[row];root["projection"]=projection
        let rows=try WireDecoder.decode(WireRowsSnapshot.self,from:JSONSerialization.data(withJSONObject:root))
        let directory=FileManager.default.temporaryDirectory.appendingPathComponent("s4-journey-"+UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:directory) }
        let store=try SettingsStore(url:directory.appendingPathComponent("settings.json"))
        try await store.update { $0.language = .english }
        let entry=EngineRowsEntry.make(configuration:.init(executableURL:URL(fileURLWithPath:"/synthetic/never-launched"),applicationVersion:"s4",allowedEnvironment:[:],offline:true,readOnly:true),settingsStore:store,createsNativePanels:false,makeClient:{_,store in S4RowsClient(store:store,rows:rows)},activateSettings:{})
        await entry.prepare();await entry.composition.start()
        defer { entry.composition.dock.close() }
        guard let input=entry.composition.presentedContent.snapshot.inputs.first else { throw Failure(description:"normal entry lost the quota member") }
        let reading=try DockInstrumentProjection.evaluate(input,now:Date())
        try require(reading.remainingPercent == 2,"without an explicit model-scope field, generic weekly windows must participate regardless of names/limit/pool keys")
        try require(reading.inner?.windowID.hasSuffix("five") == true,"inner must use5h role")
        try require(reading.outer?.windowID == "model","outer must use the tightest weekly role without guessing model scope")
        try require(input.windows.first(where:{$0.id == "model"})?.isGeneral == true,"metadata that merely looks scoped must not become a scope field")
        try require(input.windows.first(where:{$0.id.hasSuffix("month")})?.period == .month,"monthly role must survive")
        guard let card=try entry.composition.dock.cardContent(for:input.id) else { throw Failure(description:"normal card missing") }
        try require(card.rows.first(where:{$0.id == "quota:five"})?.detail.hasPrefix("Resets in ") == true,"card must carry the reported relative reset")
        try require(card.rows.contains{$0.id == "quota:extra" && $0.kind == .extraQuota && $0.value == "1%"},"extra quota belongs in the card only")
        let afterReset=Date(timeIntervalSince1970:4_102_444_800) // 2100-01-01
        let expired=try entry.composition.dock.cardContent(for:input.id,at:afterReset)
        try require(expired?.rows.first(where:{$0.id == "quota:five"})?.detail == "Reset time passed","relative reset text must use presentation time, not cached projection time")
        var old=SettingsPreferences();old.subscriptionSettings["codex"] = .init(alias:"Saved",percentagePin:.week)
        old.subscriptions = .init(order:["codex"],hiddenIDs:["codex"])
        let migrated=entry.composition.accountMembers.migratingRowPreferences(old)
        try require(migrated.subscriptionSettings[input.id]?.alias == "Saved" && migrated.subscriptionSettings["codex"] == nil,"single member must inherit row preference exactly once")
        try require(migrated.subscriptions.order == [input.id] && migrated.subscriptions.hiddenIDs == [input.id],"single-member order/hide migration must use its key")
        var explicit=old;explicit.subscriptionSettings[input.id] = .init(alias:"Member")
        try require(entry.composition.accountMembers.migratingRowPreferences(explicit).subscriptionSettings[input.id]?.alias == "Member","explicit member choice must win over row migration")
        for (pin,expected) in [(PercentagePin.fiveHour,63.0),(.week,2.0)] {
            try await store.update { $0.subscriptionSettings[input.id] = .init(percentagePin:pin) }
            await entry.prepare()
            guard let preferences=entry.composition.dock.currentMenuBarPreferences else { throw Failure(description:"normal Dock lost Settings") }
            let pinned=try DockInstrumentProjection.evaluate(preferences.applying(to:input),now:Date())
            try require(pinned.remainingPercent == expected,"member-keyed window pin must select its semantic role")
            try require(pinned.inner?.windowID == "five" && pinned.outer?.windowID == "model","pin must not swap ring roles")
        }
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
        guard let firstCard=try entry.composition.dock.cardContent(for:"0123456789abcdef"),
              let secondCard=try entry.composition.dock.cardContent(for:"fedcba9876543210") else { throw Failure(description:"normal Dock must expose the actual member card content") }
        try require(firstCard.plan == "synthetic","card must carry the reported plan name")
        try require(firstCard.rows.contains{$0.kind == .reserve && $0.value.contains("42.5")},"first card needs only its own reported credits")
        try require(secondCard.rows.contains{$0.kind == .reserve && $0.value.contains("7")},"second card needs its own reported credits")
        try require(!secondCard.rows.contains{$0.value.contains("42.5")},"source totals must not leak across members")
        var old=SettingsPreferences();old.subscriptionSettings["codex"] = .init(alias:"Wrong shared alias",percentagePin:.fiveHour)
        old.subscriptions = .init(order:["codex"],hiddenIDs:["codex"])
        let migrated=entry.composition.accountMembers.migratingRowPreferences(old)
        try require(migrated.subscriptionSettings.isEmpty && migrated.subscriptions.order.isEmpty && migrated.subscriptions.hiddenIDs.isEmpty,"multi-member row preference must be dropped, never copied")
        try require(entry.composition.accountMembers.members.map(\.id) == content.snapshot.inputs.map(\.id),"placement member list must match the Dock")
        // Invalidation must withdraw member identity and card facts on the same delivery turn.
        await entry.composition.store.consume(.clearPrivateViews(.init(revision:2,reason:.connectionLost,previous:nil,nextFloor:nil)))
        try require(entry.composition.accountMembers.members.isEmpty && entry.composition.presentedContent.snapshot.inputs.isEmpty,"clear must withdraw identity with readings")
        try require(try entry.composition.dock.cardContent(for:"0123456789abcdef") == nil,"clear must withdraw the old card facts")
        await entry.composition.stop()
    }
    static func unknownFacts(capture:URL) async throws {
        var root=try JSONSerialization.jsonObject(with:Data(contentsOf:capture)) as! [String:Any]
        var projection=root["projection"] as! [String:Any],row=(projection["rows"] as! [[String:Any]])[0]
        var account=(row["accounts"] as! [[String:Any]])[0]
        account["plan"]=["id":"unknown"];account["valueState"]="none"
        account["credits"]=["balance":55,"unit":"credits"];account.removeValue(forKey:"observedAt")
        var window=(account["windows"] as! [[String:Any]])[0]
        window.removeValue(forKey:"remainingPercent");window.removeValue(forKey:"resetsAt");account["windows"]=[window]
        row["accounts"]=[account];projection["rows"]=[row];root["projection"]=projection
        let rows=try WireDecoder.decode(WireRowsSnapshot.self,from:JSONSerialization.data(withJSONObject:root))
        let directory=FileManager.default.temporaryDirectory.appendingPathComponent("s4-unknown-"+UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:directory) }
        let store=try SettingsStore(url:directory.appendingPathComponent("settings.json"))
        try await store.update { $0.language = .english }
        let entry=EngineRowsEntry.make(configuration:.init(executableURL:URL(fileURLWithPath:"/synthetic/never-launched"),applicationVersion:"s4",allowedEnvironment:[:],offline:true,readOnly:true),settingsStore:store,createsNativePanels:false,makeClient:{_,store in S4RowsClient(store:store,rows:rows)},activateSettings:{})
        await entry.prepare();await entry.composition.start()
        defer { entry.composition.dock.close() }
        guard let input=entry.composition.presentedContent.snapshot.inputs.first,
              let card=try entry.composition.dock.cardContent(for:input.id) else { throw Failure(description:"unknown-facts member/card missing") }
        try require(card.plan.isEmpty && !card.rows.contains{$0.kind == .reserve},"unavailable plan/reserve must stay absent, not become zero or an inferred current value")
        try require(card.rows.first(where:{$0.kind == .quota})?.value == "--","unknown quota must not become zero fuel")
        try require(card.rows.first(where:{$0.kind == .quota})?.detail == "--","unknown reset time must stay unknown")
        try require(card.sourceAndAge.contains("Observation time unknown"),"missing observation must not use rendering time")
        await entry.composition.stop()
    }
}
