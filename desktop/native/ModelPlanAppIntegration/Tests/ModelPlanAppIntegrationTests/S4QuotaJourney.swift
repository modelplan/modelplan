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
    var revision:UInt64=1
    init(store:EngineStore,rows:WireRowsSnapshot) { self.store=store;self.rows=rows }
    func start() async throws -> EngineDeliveryContext {
        await store.consume(.connection(.ready(context)))
        await store.consume(.context(context))
        await store.consume(.rowsChanged(.init(envelope:try .init(sessionId:context.sessionID,storeEpoch:context.floor.storeEpoch,consentGeneration:1,data:rows),delivery:context),invalidRowCount:0))
        return context
    }
    func replaceRows(_ rows:WireRowsSnapshot) async throws {
        revision += 1
        let next=EngineDeliveryContext(sessionID:context.sessionID,floor:context.floor,revision:revision)
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
    static func resetEvents(capture:URL) async throws {
        let fixture=capture.deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("proposals/fixtures/app-journey-plan-scoped.json")
        let document=try JSONSerialization.jsonObject(with:Data(contentsOf:fixture)) as! [String:Any]
        let result=document["result"] as! [String:Any]
        var data=result["data"] as! [String:Any]
        var projection=data["projection"] as! [String:Any]
        var events=projection["resetEvents"] as! [[String:Any]]
        let clock=Date(),formatter=ISO8601DateFormatter()
        events[0]["publishedAt"]=formatter.string(from:clock.addingTimeInterval(-60))
        events[0]["expiresAt"]=formatter.string(from:clock.addingTimeInterval(3600))
        events[0]["schedule"]=["precision":"window","from":formatter.string(from:clock),"through":formatter.string(from:clock.addingTimeInterval(3600))]
        projection["resetEvents"]=events;data["projection"]=projection
        let rows=try WireDecoder.decode(WireRowsSnapshot.self,from:JSONSerialization.data(withJSONObject:data))
        let directory=FileManager.default.temporaryDirectory.appendingPathComponent("s4-events-"+UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:directory) }
        let store=try SettingsStore(url:directory.appendingPathComponent("settings.json"))
        try await store.update { $0.language = .english; $0.notifications.optedIn = true }
        let entry=EngineRowsEntry.make(configuration:.init(executableURL:URL(fileURLWithPath:"/synthetic/never-launched"),applicationVersion:"s4",allowedEnvironment:[:],offline:true,readOnly:true),settingsStore:store,createsNativePanels:false,makeClient:{_,store in S4RowsClient(store:store,rows:rows)},activateSettings:{})
        var deliveries:[String]=[]
        entry.composition.setResetNotificationDelivery { deliveries.append($0) }
        await entry.prepare();await entry.composition.start()
        defer { entry.composition.dock.close() }
        guard case .available(let decoded)=entry.composition.rowEvents else { throw Failure(description:"normal entry must admit the explicit reset event fixture") }
        try require(decoded.count == 1 && decoded[0].rowID == "codex" && decoded[0].status == "announced", "normal entry must preserve the fixture event and its row")
        for _ in 0..<100 where deliveries.isEmpty { try await Task.sleep(for:.milliseconds(10)) }
        try require(deliveries == [decoded[0].id],"normal entry must deliver one notification for the event")
        guard let synthetic=entry.composition.client as? S4RowsClient else { throw Failure(description:"synthetic rows client missing") }
        try await synthetic.replaceRows(rows)
        try await Task.sleep(for:.milliseconds(50))
        try require(deliveries == [decoded[0].id],"a repeated event must not produce a second notification")
        let presentation=entry.composition.resetEventPresentation
        try require(presentation["0123456789abcdef"]?.first?.unacknowledged == true,"matching member must expose the unacknowledged event")
        try require(presentation["fedcba9876543210"]?.isEmpty == true,"plan-scoped event must not affect the other member")
        let card=try entry.composition.dock.cardContent(for:"0123456789abcdef")
        try require(card?.rows.contains(where:{$0.id == "reset-event:"+decoded[0].id}) == true,"matching card must expose the public reset event")
        try require(entry.composition.menuPresentation.title == "•","unacknowledged event must expose the menu dot")
        try entry.composition.acknowledgeResetEvent(decoded[0].id)
        try require(entry.composition.menuPresentation.title.isEmpty,"acknowledgement must clear the menu dot")
        try require(entry.composition.resetEventPresentation["0123456789abcdef"]?.first?.unacknowledged == false,"acknowledgement must reach the member model")
        let ledgerURL=directory.appendingPathComponent("ledger.json")
        let ledger=try EngineResetEventLedger(url:ledgerURL)
        try ledger.recordDelivered(decoded[0].id);try ledger.acknowledge(decoded[0].id)
        let restored=try EngineResetEventLedger(url:ledgerURL)
        try require(restored.wasDelivered(decoded[0].id) && restored.acknowledged.contains(decoded[0].id),"dedupe and acknowledgement must survive a restart by event id")
        projection["resetEvents"]=[];data["projection"]=projection
        let empty=try WireDecoder.decode(WireRowsSnapshot.self,from:JSONSerialization.data(withJSONObject:data))
        try await synthetic.replaceRows(empty)
        try require(entry.composition.rowEvents == .available([]),"empty event list must remain distinct from unsupported")
        events[0]["publishedAt"]=formatter.string(from:clock.addingTimeInterval(-7200))
        events[0]["expiresAt"]=formatter.string(from:clock.addingTimeInterval(-60))
        events[0]["schedule"]=["precision":"window","from":formatter.string(from:clock.addingTimeInterval(-3600)),"through":formatter.string(from:clock.addingTimeInterval(-60))]
        projection["resetEvents"]=events;data["projection"]=projection
        let expired=try WireDecoder.decode(WireRowsSnapshot.self,from:JSONSerialization.data(withJSONObject:data))
        try await synthetic.replaceRows(expired)
        try require(entry.composition.resetEventPresentation["0123456789abcdef"]?.isEmpty == true,"expired event must not appear on its member")
        try require(entry.composition.menuPresentation.title.isEmpty,"expired event must not leave a menu dot")
        projection.removeValue(forKey:"resetEvents");data["projection"]=projection
        let absent=try WireDecoder.decode(WireRowsSnapshot.self,from:JSONSerialization.data(withJSONObject:data))
        try await synthetic.replaceRows(absent)
        try require(entry.composition.rowEvents == .absentFromSchema,"omitted event list must remain unsupported")
        try require(entry.composition.menuPresentation.title.isEmpty,"missing events must clear the menu dot")
        await entry.composition.stop()
    }
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
            w.removeValue(forKey:"modelScope")
            w["current"]=true;w["resetsAt"]="2099-01-01T00:00:00Z";w["validUntil"]="2099-01-01T00:00:00Z"
            w["limitKey"]=role == "other" ? "other":"main";w["poolKey"]=role == "other" ? "other":"main"
            return w
        }
        // Array order, duration and low extra all disagree with the semantic role.
        var scopedWeekly=window("model","weekly",2,604800);scopedWeekly["modelScope"]=["models":["opus"]]
        var special=window("review","weekly",1,604800);special["limitKey"]="code_review";special["poolKey"]="code_review"
        var unknown=window("unknown","session",3,18000);unknown["limitKey"]="other";unknown["poolKey"]="other"
        account["windows"]=[scopedWeekly,special,unknown,window("weekly","weekly",24,604800),window("extra","other",1,60),window("five","session",63,18000),window("month","monthly",80,2592000)]
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
        try require(reading.remainingPercent == 24,"restricted and special-pool windows must not determine the general tightest")
        try require(reading.inner?.windowID.hasSuffix("five") == true,"inner must use5h role")
        try require(reading.outer?.windowID == "weekly","outer must use the general weekly window")
        try require(input.windows.filter{["model","review","unknown"].contains($0.id)}.allSatisfy{!$0.isGeneral},"scoped, special and unknown limits must stay out of general windows")
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
        for (pin,expected) in [(PercentagePin.fiveHour,63.0),(.week,24.0)] {
            try await store.update { $0.subscriptionSettings[input.id] = .init(percentagePin:pin) }
            await entry.prepare()
            guard let preferences=entry.composition.dock.currentMenuBarPreferences else { throw Failure(description:"normal Dock lost Settings") }
            let pinned=try DockInstrumentProjection.evaluate(preferences.applying(to:input),now:Date())
            try require(pinned.remainingPercent == expected,"member-keyed window pin must select its semantic role")
            try require(pinned.inner?.windowID == "five" && pinned.outer?.windowID == "weekly","pin must not swap ring roles")
        }
        guard let synthetic=entry.composition.client as? S4RowsClient else { throw Failure(description:"synthetic rows client missing") }
        var generalFive=window("general-five","session",63,18000);generalFive["limitKey"]="five_hour"
        var generalWeek=window("general-week","weekly",24,604800);generalWeek["limitKey"]="weekly"
        var scopedFive=window("scoped-five","session",1,18000);scopedFive["modelScope"]=["models":["unknown"]]
        var namedPool=window("named-pool","weekly",2,604800);namedPool["poolKey"]="reserve"
        var future=window("future","weekly",3,604800);future["limitKey"]="future_limit"
        let ordered=[scopedFive,namedPool,future,generalFive,generalWeek]
        for windows in [ordered,Array(ordered.reversed())] {
            account["windows"]=windows;row["accounts"]=[account];projection["rows"]=[row];root["projection"]=projection
            let snapshot=try WireDecoder.decode(WireRowsSnapshot.self,from:JSONSerialization.data(withJSONObject:root))
            try await synthetic.replaceRows(snapshot)
            guard let next=entry.composition.presentedContent.snapshot.inputs.first else { throw Failure(description:"member disappeared on refresh") }
            let reading=try DockInstrumentProjection.evaluate(next,now:Date())
            try require(reading.remainingPercent == 24 && reading.inner?.windowID == "general-five" && reading.outer?.windowID == "general-week","general role selection must not depend on order or include model, named or future pools")
        }
        account["windows"]=[scopedFive,namedPool,future];row["accounts"]=[account];projection["rows"]=[row];root["projection"]=projection
        let restrictedOnly=try WireDecoder.decode(WireRowsSnapshot.self,from:JSONSerialization.data(withJSONObject:root))
        try await synthetic.replaceRows(restrictedOnly)
        guard let only=entry.composition.presentedContent.snapshot.inputs.first else { throw Failure(description:"restricted-only member disappeared") }
        let restrictedReading=try DockInstrumentProjection.evaluate(only,now:Date())
        try require(restrictedReading.remainingPercent == nil && restrictedReading.inner == nil && restrictedReading.outer == nil,"restricted-only accounts must not invent general rings")
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
        window.removeValue(forKey:"modelScope");window["limitKey"]="main";window["poolKey"]="main"
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
        try require(card.sourceAndAge.contains("Reading time unknown"),"missing reading time must not use rendering time")
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
            window.removeValue(forKey:"modelScope")
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
        try require(entry.composition.memberInstability == ["0123456789abcdef":false,"codex#saved_login_api#1":true,"codex#saved_login_api#2":true,"codex#runtime_rpc":false],"the normal provider must expose per-member instability to placement and scope consumers")
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
        accounts.swapAt(1,2);row["accounts"]=accounts;projection["rows"]=[row];root["projection"]=projection
        let reordered=try WireDecoder.decode(WireRowsSnapshot.self,from:JSONSerialization.data(withJSONObject:root))
        try await (entry.composition.client as! S4RowsClient).replaceRows(reordered)
        let refreshed=entry.composition.presentedContent.snapshot.inputs
        try require(refreshed.compactMap{try? DockInstrumentProjection.evaluate($0,now:Date()).remainingPercent} == [70,30,20,40],"refresh must expose the reordered members without carrying their old identity")
        try require(entry.composition.memberInstability["codex#saved_login_api#2"] == true,"the reused ordinal must remain marked unstable after refresh")
        let afterRefresh=entry.composition.accountMembers.persistentPreferences(candidate)
        try require(afterRefresh.subscriptionSettings["codex#saved_login_api#1"] == nil && afterRefresh.subscriptionSettings["codex#saved_login_api#2"] == nil,"old unstable choices must never become durable after refresh")
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
    static func language(capture:URL) async throws {
        var root=try JSONSerialization.jsonObject(with:Data(contentsOf:capture)) as! [String:Any]
        var projection=root["projection"] as! [String:Any],row=(projection["rows"] as! [[String:Any]])[0]
        row["name"]=["en":"Tool","zh":"合成工具"]
        row["reason"]=["code":"ok","text":["en":"Reading ready","zh":"读数已更新"]]
        row["nextStep"]=["action":"open_settings_consent","text":["en":"Open Settings","zh":"打开设置"]]
        row["state"]="fresh";row["surfaces"]=["dock","menu","settings"];row["expiresAt"]="2099-01-01T00:00:00Z"
        let base=(row["accounts"] as! [[String:Any]])[0],original=(base["windows"] as! [[String:Any]])[0]
        row["accounts"]=["money","other","credits"].enumerated().map { index,unit in
            var account=base,window=original
            window.removeValue(forKey:"modelScope")
            account["subscriptionRef"]=String(repeating:String(index+1),count:16)
            account["plan"]=["id":"codex","name":["en":"Standard plan","zh":"标准方案"]]
            account["valueState"]="current";account["observedAt"]="2026-01-01T00:00:00Z";account["freshUntil"]="2099-01-01T00:00:00Z"
            account["credits"]=["balance":12.5,"unit":unit]
            window["id"]="quota";window["role"]="session";window["label"]=["en":"Session quota","zh":"会话额度"]
            window["limitKey"]="main";window["poolKey"]="main";window["current"]=true;window["remainingPercent"]=50
            window["resetsAt"]="2099-01-01T00:00:00Z";window["validUntil"]="2099-01-01T00:00:00Z";account["windows"]=[window]
            return account
        }
        var summary=projection["rowsSummary"] as! [String:Any]
        summary["text"]=["en":"Readings ready","zh":"读数已更新"]
        summary["reason"]=row["reason"];summary["nextStep"]=row["nextStep"]
        projection["rows"]=[row];projection["rowsSummary"]=summary;root["projection"]=projection
        let rows=try WireDecoder.decode(WireRowsSnapshot.self,from:JSONSerialization.data(withJSONObject:root))
        let directory=FileManager.default.temporaryDirectory.appendingPathComponent("s4-language-"+UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:directory) }
        let store=try SettingsStore(url:directory.appendingPathComponent("settings.json"))
        let entry=EngineRowsEntry.make(configuration:.init(executableURL:URL(fileURLWithPath:"/synthetic/never-launched"),applicationVersion:"s4",allowedEnvironment:[:],offline:true,readOnly:true),settingsStore:store,createsNativePanels:false,makeClient:{_,store in S4RowsClient(store:store,rows:rows)},activateSettings:{})
        await entry.prepare();await entry.composition.start()
        defer { entry.composition.dock.close() }
        for language in [SettingsLanguage.chinese,.english,.chinese] {
            try await store.update { $0.language=language };await entry.prepare()
            let content=entry.composition.presentedContent
            var visible=(content.menuStatusLines ?? [])+[content.emptyText ?? ""]+content.snapshot.inputs.map(\.name)
            var cards:[DockCardContent]=[]
            for input in content.snapshot.inputs {
                guard let card=try entry.composition.dock.cardContent(for:input.id) else { throw Failure(description:"localized card missing") }
                cards.append(card);visible += [card.name,card.plan,card.sourceAndAge,card.stateLabel,card.enterLabel,card.dismissLabel]
                visible += card.rows.flatMap{[$0.label,$0.value,$0.detail]}
            }
            if language == .chinese {
                try require(!visible.joined().unicodeScalars.contains{(65...90).contains(Int($0.value)) || (97...122).contains(Int($0.value))},"Chinese projection must not leak raw English unit or fallback text")
                try require(!visible.joined().contains("观测"),"reading age must use user-facing glossary copy")
                try require(content.snapshot.inputs.first?.name == "合成工具 · 账号 1","duplicate member copy must use the account term consistently")
                try require(cards.allSatisfy{$0.rows.first(where:{$0.kind == .quota})?.label == "5小时"},"the short quota row must use the glossary label")
                try require(cards.map{$0.rows.first(where:{$0.kind == .reserve})?.label} == ["余额","储备","点数"],"wire units must map to localized facts without inventing a currency")
            } else {
                try require(!visible.joined().unicodeScalars.contains{(0x3400...0x9FFF).contains(Int($0.value))},"English projection must not retain Chinese strings after language change")
                try require(cards.allSatisfy{$0.rows.first(where:{$0.kind == .quota})?.label == "5h"},"English quota row must use the glossary label")
            }
        }
        await entry.composition.stop()
    }
}
