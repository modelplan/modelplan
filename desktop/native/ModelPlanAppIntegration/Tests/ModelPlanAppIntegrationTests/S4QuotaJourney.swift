// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanDock
import ModelPlanSettings
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanWire
@testable import ModelPlanAppIntegration

private actor S4RowsClient: EngineClient {
    nonisolated func isCurrent(_ context:EngineDeliveryContext) -> Bool { true }
    let store:EngineStore, rows:WireRowsSnapshot
    let context=EngineDeliveryContext(sessionID:"s4-fixture",floor:.init(storeEpoch:"s4-fixture",generation:1),revision:1)
    var revision:UInt64=1
    init(store:EngineStore,rows:WireRowsSnapshot) { self.store=store;self.rows=rows }
    func start() async throws -> EngineDeliveryContext {
        await store.consume(.connection(.ready(context)))
        await store.consume(.context(context))
        await store.consume(.rowsChanged(.init(envelope:try .init(sessionId:context.sessionID,storeEpoch:context.floor.storeEpoch,consentGeneration:1,data:rows),delivery:context),invalidRowCount:rows.projection.invalidRowCount))
        return context
    }
    func replaceRows(_ rows:WireRowsSnapshot) async throws {
        revision += 1
        let next=EngineDeliveryContext(sessionID:context.sessionID,floor:context.floor,revision:revision)
        await store.consume(.context(next))
        await store.consume(.rowsChanged(.init(envelope:try .init(sessionId:next.sessionID,storeEpoch:next.floor.storeEpoch,consentGeneration:next.floor.generation,data:rows),delivery:next),invalidRowCount:rows.projection.invalidRowCount))
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
    static func strictScopeAndEvents(capture:URL) async throws {
        var root=try JSONSerialization.jsonObject(with:Data(contentsOf:capture)) as! [String:Any]
        var projection=root["projection"] as! [String:Any],row=(projection["rows"] as! [[String:Any]])[0]
        var account=(row["accounts"] as! [[String:Any]])[0],window=(account["windows"] as! [[String:Any]])[0]
        row["state"]="fresh";row["consent"]="allowed";row["surfaces"]=["dock","menu"];row["expiresAt"]="2099-01-01T00:00:00Z"
        account["subscriptionRef"]="0123456789abcdef";account["valueState"]="current";account["freshUntil"]="2099-01-01T00:00:00Z"
        window["id"]="scope-check";window["role"]="session";window["limitKey"]="five_hour";window["poolKey"]="main"
        window["current"]=true;window["remainingPercent"]=41;window["validUntil"]="2099-01-01T00:00:00Z"
        window.removeValue(forKey:"modelScope");projection.removeValue(forKey:"resetEvents")
        func decode() throws -> WireDecoded<WireRowsSnapshot> {
            account["windows"]=[window];row["accounts"]=[account];projection["rows"]=[row];root["projection"]=projection
            return try WireDecoder.decodeWithDiagnostics(WireRowsSnapshot.self,from:JSONSerialization.data(withJSONObject:root))
        }
        func rejected(_ description:String) throws {
            var accepted=false
            do { _ = try decode();accepted=true } catch { }
            try require(!accepted,description)
        }
        let initial=try decode().value,directory=FileManager.default.temporaryDirectory.appendingPathComponent("s4-strict-wire-"+UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:directory) }
        let store=try SettingsStore(url:directory.appendingPathComponent("settings.json"))
        let entry=EngineRowsEntry.make(configuration:.init(executableURL:URL(fileURLWithPath:"/synthetic/never-launched"),applicationVersion:"s4",allowedEnvironment:[:],offline:true,readOnly:true),settingsStore:store,createsNativePanels:false,makeClient:{_,engine in S4RowsClient(store:engine,rows:initial)},activateSettings:{})
        await entry.prepare();await entry.composition.start()
        defer { entry.composition.dock.close() }
        guard let client=entry.composition.client as? S4RowsClient else { throw Failure(description:"synthetic rows client missing") }
        func input() throws -> DockInstrumentInput {
            guard let input=entry.composition.presentedContent.snapshot.inputs.first else { throw Failure(description:"normal entry lost the valid member") }
            return input
        }
        try require(try input().windows.first?.isGeneral == true,"an omitted scope must remain general")
        try require(entry.composition.rowEvents == .absentFromSchema,"omitted events must remain absent")
        window["modelScope"]=["models":["opus"]]
        try await client.replaceRows(decode().value)
        try require(try input().windows.first?.isGeneral == false,"a valid scoped window must not become general")
        window["modelScope"]=NSNull()
        let isolated=try decode()
        try require(isolated.invalidRowCount == 1 && isolated.value.projection.rows.first?.invalid == true,"null scope must isolate the semantic row")
        try await client.replaceRows(isolated.value)
        try require(entry.composition.presentedContent.snapshot.inputs.isEmpty,"an isolated scope must not produce general capacity")
        for bad:Any in ["malformed",["models":[42]]] {
            window["modelScope"]=bad
            try rejected("structurally malformed scope must reject the frame")
        }
        window.removeValue(forKey:"modelScope")
        let fixture=capture.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("proposals/fixtures/app-journey-plan-scoped.json")
        let document=try JSONSerialization.jsonObject(with:Data(contentsOf:fixture)) as! [String:Any]
        let data=(document["result"] as! [String:Any])["data"] as! [String:Any]
        var event=((data["projection"] as! [String:Any])["resetEvents"] as! [[String:Any]])[0]
        let clock=Date(),formatter=ISO8601DateFormatter()
        event["rowId"]=row["id"];event.removeValue(forKey:"planIds")
        event["publishedAt"]=formatter.string(from:clock.addingTimeInterval(-60));event["expiresAt"]=formatter.string(from:clock.addingTimeInterval(3600))
        event["schedule"]=["precision":"window","from":formatter.string(from:clock),"through":formatter.string(from:clock.addingTimeInterval(3600))]
        projection["resetEvents"]=[event]
        try await client.replaceRows(decode().value)
        guard case .available(let admitted)=entry.composition.rowEvents else { throw Failure(description:"valid event treated as absent") }
        try require(admitted.count == 1 && entry.composition.resetSignals.contains(where:{$0.reset?.id == admitted[0].id}),"valid event must reach the normal projection")
        for bad:Any in [NSNull(),"malformed",[["version":1]],[["version":"malformed"]]] {
            projection["resetEvents"]=bad
            try rejected("null or malformed events must reject the frame")
            guard case .available(let retained)=entry.composition.rowEvents else { throw Failure(description:"rejected events were treated as absent") }
            try require(retained.count == 1,"rejected event frames must not replace admitted events")
        }
        projection["resetEvents"]=[];try await client.replaceRows(decode().value)
        try require(entry.composition.rowEvents == .available([]),"valid empty events must not be absent")
        projection.removeValue(forKey:"resetEvents");try await client.replaceRows(decode().value)
        try require(entry.composition.rowEvents == .absentFromSchema,"omitted events must remain absent on refresh")
        await entry.composition.stop()
    }
    static func unstablePersistence(capture:URL) async throws {
        var root=try JSONSerialization.jsonObject(with:Data(contentsOf:capture)) as! [String:Any]
        var projection=root["projection"] as! [String:Any], row=(projection["rows"] as! [[String:Any]])[0]
        let original=(row["accounts"] as! [[String:Any]])[0]
        var accounts=(0..<2).map { index -> [String:Any] in
            var account=original
            account["subscriptionRef"]=NSNull();account["route"]="saved_login_api"
            account["accountLocator"]=String(repeating:String(index+1),count:16)
            account["credits"]=["balance":index == 0 ? 11:22,"unit":"credits"]
            return account
        }
        row["accounts"]=accounts;row["surfaces"]=["dock","menu","settings"]
        projection["rows"]=[row];root["projection"]=projection
        func snapshot() throws -> WireRowsSnapshot { try WireDecoder.decode(WireRowsSnapshot.self,from:JSONSerialization.data(withJSONObject:root)) }
        let initial=try snapshot(), directory=FileManager.default.temporaryDirectory.appendingPathComponent("s4-unstable-"+UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:directory) }
        let url=directory.appendingPathComponent("settings.json"),store=try SettingsStore(url:url)
        let configuration=EngineClientConfiguration(executableURL:URL(fileURLWithPath:"/synthetic/never-launched"),applicationVersion:"s4",allowedEnvironment:[:],offline:true,readOnly:true)
        func makeEntry(_ store:SettingsStore,_ rows:WireRowsSnapshot) -> EngineDockMenuApplication {
            EngineRowsEntry.make(configuration:configuration,settingsStore:store,createsNativePanels:false,makeClient:{_,engine in S4RowsClient(store:engine,rows:rows)},activateSettings:{})
        }
        let entry=makeEntry(store,initial);await entry.prepare();await entry.composition.start()
        defer { entry.composition.dock.close() }
        let editor=entry.settingsHost.application.editor, members=editor.context.subscriptions
        try require(members.count == 2 && members.allSatisfy(\.isUnstable),"normal Settings must flag both order-derived members")
        try require(members.allSatisfy { $0.persistenceDisabledReason?.english == "Unverified account — changes can't be saved yet" && $0.persistenceDisabledReason?.chinese == "未验证账号，暂不能保存设置" },"Settings must expose the localized reason")
        let ids=members.map(\.id), before=await store.snapshot()
        var draft=AliasDraft(subscriptionID:ids[0],committed:"");draft.input("wrong account",composing:false)
        for edit in [SettingsB21Edit.visible(ids[0],false),.alias(draft),.moveSubscription(ids[0],to:1,expectedOrder:ids)] {
            do { _ = try await editor.commit(edit); throw Failure(description:"an unstable member edit was persisted") }
            catch is SettingsEditorError { }
        }
        do { _ = try await editor.commit(SettingsB20Edit.percentagePin(ids[0],.week)); throw Failure(description:"an unstable scope was persisted") }
        catch is SettingsEditorError { }
        let rejected=await store.snapshot()
        try require(rejected.revision == before.revision,"rejected edits must not write")
        accounts.swapAt(0,1);row["accounts"]=accounts;projection["rows"]=[row];root["projection"]=projection
        let refreshed=try snapshot();try await (entry.composition.client as! S4RowsClient).replaceRows(refreshed)
        let persisted=await store.snapshot().preferences
        try require(ids.allSatisfy { persisted.subscriptionSettings[$0] == nil && !persisted.subscriptions.hiddenIDs.contains($0) && !persisted.subscriptions.order.contains($0) },"unstable keys must not be saved")
        try require(entry.composition.presentedContent.snapshot.inputs.count == 2,"refresh must keep both members visible")
        await entry.composition.stop()
        let restart=makeEntry(try SettingsStore(url:url),refreshed);await restart.prepare();await restart.composition.start()
        defer { restart.composition.dock.close() }
        let after=await restart.foundationStore.snapshot().preferences
        try require(ids.allSatisfy { after.subscriptionSettings[$0] == nil && !after.subscriptions.hiddenIDs.contains($0) && !after.subscriptions.order.contains($0) },"restart must not transfer any unstable choice")
        try require(restart.composition.presentedContent.snapshot.inputs.count == 2,"restart must retain both members")
        await restart.composition.stop()
    }
    static func sourceStates(capture:URL) async throws {
        var root=try JSONSerialization.jsonObject(with:Data(contentsOf:capture)) as! [String:Any]
        var projection=root["projection"] as! [String:Any],row=(projection["rows"] as! [[String:Any]])[0]
        var account=(row["accounts"] as! [[String:Any]])[0]
        row["state"]="fresh";row["consent"]="allowed";row["surfaces"]=["dock","menu","settings"];row["expiresAt"]="2099-01-01T00:00:00Z"
        account["subscriptionRef"]="0123456789abcdef";account["valueState"]="current";account["freshUntil"]="2099-01-01T00:00:00Z"
        row["accounts"]=[account];projection["rows"]=[row];root["projection"]=projection
        func snapshot() throws -> WireRowsSnapshot { try WireDecoder.decode(WireRowsSnapshot.self,from:JSONSerialization.data(withJSONObject:root)) }
        let directory=FileManager.default.temporaryDirectory.appendingPathComponent("s4-sources-"+UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:directory) }
        let store:SettingsStore
        do { store=try SettingsStore(url:directory.appendingPathComponent("settings.json")) } catch { throw Failure(description:"settings initialization: \(error)") }
        do { try await store.update { $0.language = .english } } catch { throw Failure(description:"settings fixture: \(error)") }
        let initial:WireRowsSnapshot
        do { initial=try snapshot() } catch { throw Failure(description:"source fixture decode: \(error)") }
        let entry=EngineRowsEntry.make(configuration:.init(executableURL:URL(fileURLWithPath:"/synthetic/never-launched"),applicationVersion:"s4",allowedEnvironment:[:],offline:true,readOnly:true),settingsStore:store,createsNativePanels:false,makeClient:{_,store in S4RowsClient(store:store,rows:initial)},activateSettings:{})
        await entry.prepare();await entry.composition.start()
        defer { entry.composition.dock.close() }
        func source() -> SubscriptionSourceState? { entry.currentSettingsContext.subscriptions.first(where:{$0.id == "0123456789abcdef"})?.source }
        if source() != .fresh {
            let observed=source();await entry.composition.stop()
            throw Failure(description:"the normal Settings catalogue must report a fresh admitted member (observed: \(String(describing:observed)))")
        }
        guard let client=entry.composition.client as? S4RowsClient else { throw Failure(description:"synthetic rows client missing") }
        for (state,consent,value,expected) in [("stale","allowed","retained",SubscriptionSourceState.stale)] {
            row["state"]=state;row["consent"]=consent;account["valueState"]=value;row["accounts"]=[account]
            projection["rows"]=[row];root["projection"]=projection
            do { try await client.replaceRows(snapshot()) } catch { throw Failure(description:"refresh \(state): \(error)") }
            try require(source() == expected,"the normal Settings catalogue must reflect \(state)/\(consent)/\(value)")
        }
        await entry.composition.stop()
    }
    static func announcedMenuIndicator(capture:URL) async throws -> Bool {
        let fixture=capture.deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("proposals/fixtures/app-journey-plan-scoped.json")
        let document=try JSONSerialization.jsonObject(with:Data(contentsOf:fixture)) as! [String:Any]
        let result=document["result"] as! [String:Any]
        var data=result["data"] as! [String:Any], projection=data["projection"] as! [String:Any]
        var events=projection["resetEvents"] as! [[String:Any]]
        let now=Date(),formatter=ISO8601DateFormatter()
        events[0]["publishedAt"]=formatter.string(from:now.addingTimeInterval(-60))
        events[0]["expiresAt"]=formatter.string(from:now.addingTimeInterval(3600))
        events[0]["schedule"]=["precision":"window","from":formatter.string(from:now),"through":formatter.string(from:now.addingTimeInterval(3600))]
        projection["resetEvents"]=events;data["projection"]=projection
        let rows=try WireDecoder.decode(WireRowsSnapshot.self,from:JSONSerialization.data(withJSONObject:data))
        let directory=FileManager.default.temporaryDirectory.appendingPathComponent("s4-menu-notice-"+UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:directory) }
        let store=try SettingsStore(url:directory.appendingPathComponent("settings.json"))
        let entry=EngineRowsEntry.make(configuration:.init(executableURL:URL(fileURLWithPath:"/synthetic/never-launched"),applicationVersion:"s4",allowedEnvironment:[:],offline:true,readOnly:true),settingsStore:store,createsNativePanels:false,makeClient:{_,store in S4RowsClient(store:store,rows:rows)},activateSettings:{})
        await entry.prepare();await entry.composition.start()
        defer { entry.composition.dock.close() }
        guard case .available(let admitted)=entry.composition.rowEvents,
              admitted.count == 1, admitted[0].status == "announced",
              entry.composition.resetSignals.contains(where:{$0.reset?.id == admitted[0].id}),
              entry.composition.dock.menuNotice != nil else {
            await entry.composition.stop()
            throw Failure(description:"announced event must reach the normal host before the menu indicator is tested")
        }
        let displayed = entry.noticeIndicator.notice == entry.composition.dock.menuNotice
        entry.composition.dock.setPresentationAllowed(true)
        try require(!entry.cockpitEntryEnabled, "the interim beta must keep cockpit disabled")
        entry.composition.dock.acknowledgeDockReveal()
        try require(entry.noticeIndicator.notice == nil, "opening Dock must clear the indicator without cockpit")
        await entry.composition.stop()
        return displayed
    }
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
        let entry=EngineRowsEntry.make(configuration:.init(executableURL:URL(fileURLWithPath:"/synthetic/never-launched"),applicationVersion:"s4",allowedEnvironment:[:],offline:true,readOnly:true),settingsStore:store,createsNativePanels:false,cockpitEntryEnabled:true,makeClient:{_,store in S4RowsClient(store:store,rows:rows)},activateSettings:{})
        var deliveries:[String]=[]
        entry.composition.setResetNotificationDelivery { deliveries.append($0) }
        await entry.prepare();await entry.composition.start()
        defer { entry.composition.dock.close() }
        guard case .available(let decoded)=entry.composition.rowEvents else { throw Failure(description:"normal entry must admit the explicit reset event fixture") }
        try require(decoded.count == 1 && decoded[0].rowID == "codex" && decoded[0].status == "announced", "normal entry must preserve the fixture event and its row")
        for _ in 0..<100 where deliveries.isEmpty { try await Task.sleep(for:.milliseconds(10)) }
        try require(deliveries == [decoded[0].id+":announced"],"normal entry must deliver one notification for the event episode")
        guard let synthetic=entry.composition.client as? S4RowsClient else { throw Failure(description:"synthetic rows client missing") }
        try await synthetic.replaceRows(rows)
        try await Task.sleep(for:.milliseconds(50))
        try require(deliveries == [decoded[0].id+":announced"],"a repeated event must not produce a second notification")
        let cacheURL=directory.appendingPathComponent("notification-cache.json")
        var replay:[String]=[]
        let firstNotifier=try EngineResetNotifier(composition:entry.composition,settings:store,cacheURL:cacheURL,deliverToSystem:false)
        firstNotifier.deliveryOverride={ replay.append($0) };firstNotifier.start()
        for _ in 0..<100 where replay.isEmpty { try await Task.sleep(for:.milliseconds(10)) }
        try require(replay == [decoded[0].id+":announced"],"fresh notification cache must admit one event")
        firstNotifier.stop()
        let secondNotifier=try EngineResetNotifier(composition:entry.composition,settings:store,cacheURL:cacheURL,deliverToSystem:false)
        secondNotifier.deliveryOverride={ replay.append($0) };secondNotifier.start()
        try await Task.sleep(for:.milliseconds(50))
        try require(replay.count == 1,"restored Settings notification ledger must deduplicate across notifier restart")
        secondNotifier.stop()
        let corruptURL=directory.appendingPathComponent("corrupt-reset-notifications.json")
        let corrupt=Data("{broken".utf8);try corrupt.write(to:corruptURL)
        var recoveredDeliveries:[String]=[]
        let recovered=try EngineResetNotifier.recovering(composition:entry.composition,settings:store,cacheURL:corruptURL,deliverToSystem:false)
        recovered.deliveryOverride={ recoveredDeliveries.append($0) };recovered.start()
        for _ in 0..<100 where recoveredDeliveries.isEmpty { try await Task.sleep(for:.milliseconds(10)) }
        try require(recoveredDeliveries == [decoded[0].id+":announced"],"a quarantined corrupt ledger must not disable reset delivery")
        let quarantined=try FileManager.default.contentsOfDirectory(at:directory,includingPropertiesForKeys:nil)
            .filter { $0.lastPathComponent.hasPrefix("corrupt-reset-notifications.json.corrupt-") }
        try require(quarantined.count == 1 && (try Data(contentsOf:quarantined[0])) == corrupt,"recovery must retain the exact corrupt bytes in one quarantine file")
        try await synthetic.replaceRows(rows);try await Task.sleep(for:.milliseconds(50))
        try require(recoveredDeliveries.count == 1,"recovered ledger must deduplicate repeated events")
        recovered.stop()
        entry.composition.dock.setPresentationAllowed(true)
        try require(entry.noticeIndicator.notice != nil, "normal entry must show the projected menu notice")
        entry.composition.dock.showConsole = {}
        entry.composition.dock.perform(NSSelectorFromString("openConsole"))
        try require(entry.noticeIndicator.notice == nil, "cockpit acknowledgement must clear the menu indicator")
        let signals=entry.composition.presentedContent.signals
        guard let matching=signals.first(where:{$0.id == "0123456789abcdef"}),let unmatched=signals.first(where:{$0.id == "fedcba9876543210"}) else { throw Failure(description:"event members missing") }
        try require(matching.reset?.id == decoded[0].id && unmatched.reset == nil,"only the matching member must expose the event signal")
        let card=try entry.composition.dock.cardContent(for:"0123456789abcdef")
        try require(card?.rows.contains(where:{$0.id == "reset-event:"+decoded[0].id+":announced"}) == true,"matching card must expose the public reset event")
        var attention=DockAttentionState()
        let stations=[matching.id:"station"]
        let initial=try attention.project(signals,stationBySubscription:stations,at:clock)
        try require(initial.menuNotice != nil && initial.dots.count == 1,"an announced signal must project menu and sliver notices")
        guard let firstNotice=initial.menuNotice else { throw Failure(description:"menu notice missing") }
        try require(attention.firstAppearance(of:firstNotice.key,on:.dock) && !attention.firstAppearance(of:firstNotice.key,on:.dock),"notice pulse must occur on first appearance only")
        try attention.acknowledge(.cockpitOpening,signals:signals,at:clock)
        let cockpitOpened=try attention.project(signals,stationBySubscription:stations,at:clock)
        try require(cockpitOpened.menuNotice == nil && cockpitOpened.dots.count == 1,"opening cockpit must acknowledge only the menu notice")
        try attention.acknowledge(.dockRevealed,signals:signals,at:clock)
        let acknowledged=try attention.project(signals,stationBySubscription:stations,at:clock)
        try require(acknowledged.menuNotice == nil && acknowledged.dots.isEmpty,"revealing Dock must acknowledge both indicators")
        try require(DockNoticeProjection.selected(for:matching,at:clock) != nil,"acknowledgement must not erase the Dock-face notice")
        events[0]["status"]="confirmed";events[0]["confirms"]=decoded[0].id
        events[0]["expiresAt"]=formatter.string(from:clock.addingTimeInterval(30))
        var superseded=events[0];superseded["status"]="announced";superseded.removeValue(forKey:"confirms")
        superseded["publishedAt"]=formatter.string(from:clock.addingTimeInterval(-10))
        projection["resetEvents"]=[superseded,events[0]];data["projection"]=projection
        let confirmed=try WireDecoder.decode(WireRowsSnapshot.self,from:JSONSerialization.data(withJSONObject:data))
        try await synthetic.replaceRows(confirmed)
        guard let confirmedSignal=entry.composition.resetSignals.first(where:{$0.id == matching.id}),let notice=DockNoticeProjection.selected(for:confirmedSignal,at:clock) else { throw Failure(description:"linked confirmation was not projected") }
        try require(notice.key.kind == .resetConfirmed && notice.shape == .solid,"linked confirmation must project the solid confirmed notice")
        for _ in 0..<100 where deliveries.count < 2 { try await Task.sleep(for:.milliseconds(10)) }
        try require(deliveries == [decoded[0].id+":announced",decoded[0].id+":confirmed"],"confirmation must have a distinct notification episode")
        try require(DockNoticeProjection.selected(for:confirmedSignal,at:clock.addingTimeInterval(31)) == nil,"wire expiry must cap the confirmed notice before the 24-hour default")
        let captured=try JSONSerialization.jsonObject(with:Data(contentsOf:capture)) as! [String:Any]
        let originalProjection=captured["projection"] as! [String:Any]
        let originalRow=(originalProjection["rows"] as! [[String:Any]])[0]
        let originalAccount=(originalRow["accounts"] as! [[String:Any]])[0]
        var restartedWindow=(originalAccount["windows"] as! [[String:Any]])[0]
        restartedWindow.removeValue(forKey:"modelScope");restartedWindow["current"]=true
        restartedWindow["observedAt"]=formatter.string(from:clock);restartedWindow["resetsAt"]=formatter.string(from:clock.addingTimeInterval(3600))
        var eventRows=projection["rows"] as! [[String:Any]], eventAccounts=eventRows[0]["accounts"] as! [[String:Any]]
        eventAccounts[0]["valueState"]="current";eventAccounts[0]["windows"]=[restartedWindow]
        eventRows[0]["accounts"]=eventAccounts;projection["rows"]=eventRows;data["projection"]=projection
        let restarted=try WireDecoder.decode(WireRowsSnapshot.self,from:JSONSerialization.data(withJSONObject:data))
        try await synthetic.replaceRows(restarted)
        guard let restartedSignal=entry.composition.resetSignals.first(where:{$0.id == matching.id}) else { throw Failure(description:"restarted member missing") }
        try require(restartedSignal.reset?.restartedReading == true && DockNoticeProjection.selected(for:restartedSignal,at:clock) == nil,"a current reading restarted after confirmation must clear the confirmed notice")
        events[0].removeValue(forKey:"confirms");projection["resetEvents"]=events;data["projection"]=projection
        let unlinked=try WireDecoder.decode(WireRowsSnapshot.self,from:JSONSerialization.data(withJSONObject:data))
        try await synthetic.replaceRows(unlinked)
        try require(entry.composition.resetSignals.first(where:{$0.id == matching.id})?.reset == nil,"unlinked confirmations must be discarded")
        var linked=events[0];linked["confirms"]=decoded[0].id
        projection["resetEvents"]=[events[0],linked];data["projection"]=projection
        let mixed=try WireDecoder.decode(WireRowsSnapshot.self,from:JSONSerialization.data(withJSONObject:data))
        try await synthetic.replaceRows(mixed)
        guard case .available(let retained)=entry.composition.rowEvents else { throw Failure(description:"linked confirmation missing") }
        try require(retained.count == 1 && retained[0].status == "confirmed","an invalid confirmation must not shadow a later valid confirmation")
        events[0]["status"]="announced"
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
        try require(entry.composition.resetSignals.first(where:{$0.id == "0123456789abcdef"})?.reset == nil,"expired event must not appear on its member")
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
        try require(reading.outer?.windowID.hasSuffix("five") == true,"outer must use the shortest general window")
        try require(reading.inner?.windowID == "weekly","inner must use the remaining weekly window")
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
            try require(pinned.outer?.windowID == "five" && pinned.inner?.windowID == "weekly","pin must not swap ring roles")
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
            try require(reading.remainingPercent == 24 && reading.outer?.windowID == "general-five" && reading.inner?.windowID == "general-week","general role selection must not depend on order or include model, named or future pools")
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
        try require(firstCard.rows.contains { $0.id == "source" && $0.value == "Saved sign-in" },"card must retain its localized reported source")
        try require(firstCard.rows.contains{$0.kind == .reserve && $0.value == "43"},"first card needs its own rounded credits")
        try require(secondCard.rows.contains{$0.kind == .reserve && $0.value == "7"},"second card needs its own reported credits")
        try require(!secondCard.rows.contains{$0.kind == .reserve && $0.value == "43"},"source totals must not leak across members")
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
            $0.persistenceDisabledReason?.english == "Unverified account — changes can't be saved yet" && $0.persistenceDisabledReason?.chinese == "未验证账号，暂不能保存设置"
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
