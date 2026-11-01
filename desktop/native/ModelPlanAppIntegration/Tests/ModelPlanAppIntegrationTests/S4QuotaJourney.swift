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
        await store.consume(.context(context))
        await store.consume(.rowsChanged(.init(envelope:try .init(sessionId:context.sessionID,storeEpoch:context.floor.storeEpoch,consentGeneration:1,data:rows),delivery:context),invalidRowCount:0))
        return context
    }
    func replaceRows(_ rows:WireRowsSnapshot) async throws {
        let next=EngineDeliveryContext(sessionID:context.sessionID,floor:context.floor,revision:2)
        await store.consume(.context(next))
        await store.consume(.rowsChanged(.init(envelope:try .init(sessionId:next.sessionID,storeEpoch:next.floor.storeEpoch,consentGeneration:next.floor.generation,data:rows),delivery:next),invalidRowCount:0))
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
    static func collisions(capture:URL) async throws {
        var root=try JSONSerialization.jsonObject(with:Data(contentsOf:capture)) as! [String:Any]
        var projection=root["projection"] as! [String:Any],row=(projection["rows"] as! [[String:Any]])[0]
        let base=(row["accounts"] as! [[String:Any]])[0]
        let original=(base["windows"] as! [[String:Any]])[0]
        let specs:[(String?,String,Double)]=[("0123456789abcdef","saved_login_api",70),(nil,"saved_login_api",20),(nil,"saved_login_api",30),(nil,"runtime_rpc",40)]
        row["accounts"]=specs.enumerated().map { index,spec in
            var account=base,window=original
            account["subscriptionRef"]=spec.0.map{$0 as Any} ?? NSNull()
            account["accountLocator"]=String(repeating:String(index+1),count:16)
            account["route"]=spec.1;account["valueState"]="current";account["freshUntil"]="2099-01-01T00:00:00Z"
            window["id"]="quota";window["role"]="session";window["durationSeconds"]=18000
            window["current"]=true;window["remainingPercent"]=spec.2;window["resetsAt"]="2099-01-01T00:00:00Z";window["validUntil"]="2099-01-01T00:00:00Z"
            window["limitKey"]="main";window["poolKey"]="main";account["windows"]=[window]
            return account
        }
        row["state"]="fresh";row["surfaces"]=["dock","menu","settings"];row["expiresAt"]="2099-01-01T00:00:00Z"
        projection["rows"]=[row];root["projection"]=projection
        let rows=try WireDecoder.decode(WireRowsSnapshot.self,from:JSONSerialization.data(withJSONObject:root))
        let directory=FileManager.default.temporaryDirectory.appendingPathComponent("s4-collisions-"+UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:directory) }
        let store=try SettingsStore(url:directory.appendingPathComponent("settings.json"))
        try await store.update { $0.language = .english }
        let entry=EngineRowsEntry.make(configuration:.init(executableURL:URL(fileURLWithPath:"/synthetic/never-launched"),applicationVersion:"s4",allowedEnvironment:[:],offline:true,readOnly:true),settingsStore:store,createsNativePanels:false,makeClient:{_,store in S4RowsClient(store:store,rows:rows)},activateSettings:{})
        await entry.prepare();await entry.composition.start()
        defer { entry.composition.dock.close() }
        let inputs=entry.composition.presentedContent.snapshot.inputs
        try require(inputs.map(\.id) == ["0123456789abcdef","codex#saved_login_api#1","codex#saved_login_api#2","codex#runtime_rpc"],"colliding unbound members need separate CLI-order keys, counting only the colliding members")
        try require(inputs.map(\.name) == ["synthetic · Account 1","synthetic · Account 2","synthetic · Account 3","synthetic · Account 4"],"every nozzle must retain its duplicate-account tag")
        try require(inputs.compactMap(\.duplicateAccountTag) == [1,2,3,4],"official appearance must receive structured duplicate tags without parsing names")
        try require(inputs.compactMap{try? DockInstrumentProjection.evaluate($0,now:Date()).remainingPercent} == [70,20,30,40],"collision handling must not copy a source total into multiple members")
        let catalogue=entry.composition.accountMembers
        let temporary:Set<String>=["codex#saved_login_api#1","codex#saved_login_api#2"]
        try require(catalogue.unstableKeys == temporary && catalogue.members.map(\.isStable) == [true,false,false,true],"only the colliding unbound keys are unstable")
        try require(catalogue.members.filter{!$0.isStable}.allSatisfy {
            $0.persistenceDisabledReason?.english == "can't be told apart until the account is verified" && $0.persistenceDisabledReason?.chinese == "账号验证前无法区分"
        },"Settings must receive the exact localized persistence-disabled reason")
        var candidate=SettingsPreferences()
        candidate.subscriptionSettings["0123456789abcdef"] = .init(alias:"Stable")
        candidate.subscriptionSettings["codex#saved_login_api#1"] = .init(alias:"Temporary one",percentagePin:.fiveHour)
        candidate.subscriptionSettings["codex#saved_login_api#2"] = .init(alias:"Temporary two")
        candidate.subscriptions = .init(order:["codex#saved_login_api#1","0123456789abcdef","codex#saved_login_api#2"],hiddenIDs:["codex#saved_login_api#1","0123456789abcdef"])
        let durable=catalogue.persistentPreferences(candidate)
        try require(Set(durable.subscriptionSettings.keys) == ["0123456789abcdef"] && durable.subscriptions.order == ["0123456789abcdef"] && durable.subscriptions.hiddenIDs == ["0123456789abcdef"],"the writer guard must exclude every unstable choice while retaining stable choices")
        var accounts=row["accounts"] as! [[String:Any]]
        accounts[1]["subscriptionRef"]="fedcba9876543210";row["accounts"]=accounts
        projection["rows"]=[row];root["projection"]=projection;root["sequence"]=8
        let verified=try WireDecoder.decode(WireRowsSnapshot.self,from:JSONSerialization.data(withJSONObject:root))
        try await (entry.composition.client as! S4RowsClient).replaceRows(verified)
        let updated=entry.composition.accountMembers
        let promoted=updated.members.first{$0.id == "fedcba9876543210"}
        try require(promoted?.isStable == true && promoted?.persistenceDisabledReason == nil,"a verified ref must immediately replace its unstable key")
        let afterVerification=updated.migratingRowPreferences(candidate)
        try require(afterVerification.subscriptionSettings["fedcba9876543210"] == nil && afterVerification.subscriptionSettings["codex#saved_login_api#1"] == nil && afterVerification.subscriptionSettings["codex#saved_login_api#2"] == nil,"verification must not migrate any old unstable choice")
        await entry.composition.store.consume(.clearPrivateViews(.init(revision:3,reason:.connectionLost,previous:nil,nextFloor:nil)))
        try require(entry.composition.accountMembers.persistentPreferences(candidate).subscriptionSettings.count == 1,"the unstable namespace must remain non-persistent even after rows are cleared")
        await entry.composition.stop()
    }
}
