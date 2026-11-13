// SPDX-License-Identifier: MIT
import Foundation
import AppKit
import ModelPlanSettings
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanWire
import ModelPlanAppIntegration

@MainActor private final class U8MenuBackend:SettingsConnectionAllowing,SettingsConnectionAvailabilityProviding {
    enum Unused:Error { case command }
    let settingsConnectionAvailability=SettingsConnectionAvailability(canInspect:true,canGrant:true,canForget:true)
    func detect() async throws -> SettingsConnectionSnapshot { throw Unused.command }
    func applyStandardConsent(allow:[SettingsConnectionTool],deny:[SettingsConnectionTool],request:SettingsConnectionRequestContext) async throws -> SettingsConnectionSnapshot { throw Unused.command }
    func connect(_ tool:SettingsConnectionTool,access:SettingsConnectionAccess,request:SettingsConnectionRequestContext) async throws -> SettingsConnectionSnapshot { throw Unused.command }
    func disconnect(_ tool:SettingsConnectionTool,request:SettingsConnectionRequestContext) async throws -> SettingsConnectionSnapshot { throw Unused.command }
    func installPlugin(_ tool:SettingsPluginTool,request:SettingsConnectionRequestContext) async throws -> SettingsPluginInstallResult { throw Unused.command }
}

private actor U8JourneyEngine:EngineClient {
    nonisolated func isCurrent(_ context:EngineDeliveryContext) -> Bool { true }
    let store:EngineStore,facts:WireConsentFacts
    let context=EngineDeliveryContext(sessionID:"u8-journey",floor:.init(storeEpoch:"u8-journey",generation:1),revision:1)
    var grants:[WireConsentGrantParams]=[]
    init(store:EngineStore,facts:WireConsentFacts) { self.store=store;self.facts=facts }
    func start() async throws -> EngineDeliveryContext {
        await store.consume(.connection(.ready(context)))
        await store.consume(.context(context))
        await store.consume(.consentChanged(.init(envelope:try .init(sessionId:context.sessionID,storeEpoch:context.floor.storeEpoch,consentGeneration:1,data:facts),delivery:context)))
        return context
    }
    func recorded() -> [WireConsentGrantParams] { grants }
    func restoreWithoutSavedGrant() async throws {
        let restored=EngineDeliveryContext(sessionID:context.sessionID,floor:context.floor,revision:3)
        await store.consume(.connection(.ready(restored)))
        await store.consume(.context(restored))
        await store.consume(.consentChanged(.init(envelope:try .init(sessionId:restored.sessionID,storeEpoch:restored.floor.storeEpoch,consentGeneration:restored.floor.generation,data:facts),delivery:restored)))
    }
    func stop() async {}
    func retry() async throws -> EngineDeliveryContext { try await start() }
    func subscribeRows(timeout:Duration?) async throws -> EngineRequestCompletion { .init(requestID:.string("u8-rows")) }
    func consent(timeout:Duration?) async throws -> EngineRequestCompletion { .init(requestID:.string("u8-facts")) }
    func grant(_ request:WireConsentGrantParams,userAction:EngineUserAction?,timeout:Duration?) async throws -> EngineRequestCompletion { grants.append(request);return .init(requestID:.string(request.requestId)) }
    func refresh(_ request:WireRefreshRequestParams,timeout:Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func history(_ request:WireHistoryQueryParams,timeout:Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func cockpit(timeout:Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func publication(timeout:Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func pluginInstall(_ request:WirePluginInstallParams,timeout:Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func diagnostics(timeout:Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
}

@MainActor enum U8ConsentJourney {
    struct Failure:Error,CustomStringConvertible { let description:String }
    static func require(_ condition:Bool,_ reason:String) throws { if !condition { throw Failure(description:reason) } }
    static func run(capture:URL) async throws {
        var object=try JSONSerialization.jsonObject(with:Data(contentsOf:capture)) as! [String:Any]
        let base=(object["scopes"] as! [[String:Any]])[0]
        object["scopes"]=[("codex.local_history","local_log"),("cursor.saved_login","saved_login_api"),("cursor.browser_session","browser_session"),("cursor.unknown_path","unknown")].map { id,route in
            var scope=base;scope["scope"]=id;scope["tool"]=id.hasPrefix("codex") ? "codex":"cursor"
            scope["route"]=route;scope["state"]="unset";scope["detected"]=true;scope["retired"]=false
            scope["defaultCheck"]=true;scope["cleanupPending"]=false;scope.removeValue(forKey:"disabledReason");scope.removeValue(forKey:"keychain")
            return scope
        }
        let facts=try WireDecoder.decode(WireConsentFacts.self,from:JSONSerialization.data(withJSONObject:object))
        let directory=FileManager.default.temporaryDirectory.appendingPathComponent("u8-consent-journey-"+UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:directory) }
        let store=try SettingsStore(url:directory.appendingPathComponent("settings.json"))
        let app=EngineRowsEntry.make(configuration:.init(executableURL:URL(fileURLWithPath:"/synthetic/never-launched"),applicationVersion:"u8",allowedEnvironment:[:],offline:true,readOnly:true),settingsStore:store,createsNativePanels:false,makeClient:{_,store in U8JourneyEngine(store:store,facts:facts)},activateSettings:{})
        await app.prepare()
        defer { app.composition.dock.close() }
        let entry=app.scopeConsentEntry
        let firstRun=try entry.makeFirstRunView(language:.english)
        try require(firstRun !== entry.view,"first run must not steal the Settings view")
        try require(firstRun.window == nil && entry.view.window == nil,"journey must remain non-windowed")
        await app.composition.start()
        try require(entry.controller.facts?.scopes.count == 4,"normal entry must share accepted consent facts")
        var settingsContext=app.settingsHost.application.editor.context
        settingsContext.subscriptions=[.init(id:"synthetic-sub",name:.init("Synthetic subscription","合成订阅"),source:.fresh)]
        app.settingsHost.application.update(context:settingsContext)
        let preferences=await store.snapshot().preferences
        for (pane,query) in [(Optional("subscriptions"),""),(nil,"synthetic-sub")] {
            let rows=try SettingsCatalogue.rows(preferences:preferences,context:settingsContext,paneID:pane,query:query)
            let retained=entry.retainingNonConsentRows(rows)
            try require(Set(retained.map(\.key)).isSuperset(of:[.visible,.alias]),"SET-9-16 per-subscription visibility and alias must survive consent replacement in pane and search")
            try require(!retained.contains{[SettingKey.detectedReaders,.optionalReaders].contains($0.key)},"only replaced legacy consent rows may be suppressed")
        }
        let diagnosticsRows=try SettingsCatalogue.rows(preferences:preferences,context:settingsContext,paneID:"diagnostics")
        try require(entry.retainingNonConsentRows(diagnosticsRows).contains{$0.key == .source},"per-subscription source belongs in Diagnostics")
        try require(entry.controller.selectedIDs.isEmpty,"first-run facts must not pre-check standard or browser scopes")
        entry.controller.selectAll()
        try require(entry.controller.selectedIDs == ["codex.local_history","cursor.saved_login"],"select all must include only known standard paths, never browser or unknown routes")
        try require(try entry.makeFirstRunView(language:.chinese) === firstRun,"first-run redisplay must reuse its draft")
        try require(entry.controller.selectedIDs == ["codex.local_history","cursor.saved_login"],"language/redisplay must not reset explicit selection")
        let engine=app.composition.client as! U8JourneyEngine
        try require(await engine.recorded().isEmpty,"construction/selection must not grant")
        guard let confirmation=entry.controller.requestAllow() else { throw Failure(description:"one shared grant factory must serve first run") }
        await entry.controller.confirm(confirmation.id)
        let requests=await engine.recorded()
        try require(requests.count == 1 && Set(requests[0].allow) == ["codex.local_history","cursor.saved_login"],"only the explicitly confirmed scopes may be sent")
        try require(requests[0].consentTextVersion == facts.consentTextVersion,"first run must use the current accepted consent version")
        try require(requests[0].keychain?.isEmpty != false,"first run must not assume or request cross-build Keychain persistence")
        try require(!entry.controller.isAllowed("cursor.saved_login"),"completion or code signing cannot invent an accepted grant")
        func texts(_ view:NSView) -> [String] { (view as? NSTextField).map{[$0.stringValue]} ?? view.subviews.flatMap(texts) }
        func hasCopy(_ view:NSView) -> Bool { view.accessibilityIdentifier() == "scope.copyDiagnostics" || view.subviews.contains(where:hasCopy) }
        guard let delivery=app.composition.store.snapshot.delivery else { throw Failure(description:"accepted delivery missing") }
        let diagnostics=try WireDiagnostics(protocolVersion:"path-canary",serverVersion:"token-canary",uptimeSeconds:12,scopes:[],lastErrorClass:"account-canary")
        await app.composition.store.consume(.response(requestID:.string("u8-diagnostics"),.diagnostics(.init(envelope:try .init(sessionId:delivery.sessionID,storeEpoch:delivery.floor.storeEpoch,consentGeneration:delivery.floor.generation,data:diagnostics),delivery:delivery))))
        entry.view.apply(language:.chinese)
        try require(texts(entry.view).contains{$0.contains("读取路径数量")},"scope diagnostics must localize the numeric presentation")
        try require(!texts(entry.view).joined().contains("canary"),"localized diagnostics must keep the numeric allowlist")
        for signing in [ScopeConsentBuildSigning.unsigned,.signed,.unknown] {
            let view=SettingsScopeConsentView(controller:entry.controller,language:.english,buildSigning:signing)
            try require(texts(view).contains{$0.contains("needs a signed build")} == (signing == .unsigned),"signed-build notice must describe only an actually unsigned build")
            try require(!hasCopy(view),"scope Copy diagnostics must not duplicate About")
            view.retirePresentation()
        }
        entry.endFirstRunPresentation()
        try require(firstRun.arrangedSubviews.isEmpty && entry.controller.facts != nil,"closing first run must retire only its view, not accepted permissions")
        await app.composition.store.consume(.clearPrivateViews(.init(revision:2,reason:.connectionLost,previous:nil,nextFloor:nil)))
        try require(entry.controller.facts == nil && entry.controller.selectedIDs.isEmpty && entry.controller.diagnosticsSummary == nil && entry.controller.diagnosticsPresentation == nil,"privacy clear must withdraw every shared consent state")
        let restored=try entry.makeFirstRunView(language:.english)
        try await engine.restoreWithoutSavedGrant()
        try require(entry.controller.selectedIDs.isEmpty && !entry.controller.isAllowed("cursor.saved_login"),"a missing saved grant after update must ask again without assuming entitlement")
        try require(await engine.recorded().count == 1,"restore must not replay a consent mutation")
        entry.endFirstRunPresentation()
        try require(restored.arrangedSubviews.isEmpty,"restored first-run view must retire independently")
        await app.composition.stop()
    }
    static func menu() async throws {
        let directory=FileManager.default.temporaryDirectory.appendingPathComponent("u8-menu-journey-"+UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:directory) }
        let application=SettingsApplicationCoordinator(store:try SettingsStore(url:directory.appendingPathComponent("settings.json"))) { _ in }
        let base=CommunitySettingsSession(application:application,canPresent:{false},activate:{})
        let flow=try CommunityConnectionFlow(application:application,backend:U8MenuBackend(),canPresent:{false},showSettings:{_ in},activate:{})
        defer { flow.dispose() }
        let wrapper=try CommunityConnectionIntegration(base:base,flow:flow),item=wrapper.settingsMenuItem
        base.settingsMenuItem.title="设置…"
        try require(item.title == "设置…","consent wrapper must retain live menu title updates")
        base.settingsMenuItem.title="Settings…"
        try require(item.title == "Settings…" && item.target === wrapper && item.action != nil,"live label must preserve consent routing")
    }
}
