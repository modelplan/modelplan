// SPDX-License-Identifier: MIT
import AppKit
import Foundation
import ModelPlanCockpitWeb
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanSettings

/// Keep #332's single showConsole route and one protocol client/store.
/// Clear the existing synchronous sinks first, then await WK clear/disposal,
/// before the shared client's event is acknowledged. No DTO Task/cache exists.
@MainActor final class CockpitStoreFanout: EngineClientEventConsumer {
    let store: EngineStore
    let cockpit: EngineCockpitCoordinator
    init(store: EngineStore, cockpit: EngineCockpitCoordinator) { self.store=store; self.cockpit=cockpit }
    func consume(_ event: EngineClientEvent) async {
        await store.consume(event)
        await cockpit.consume(event)
    }
}

@MainActor public enum CommunityCockpitApplicationFactory {
    public static let webSource = "16aadf3e0c6248902a9f63e96845e448905ad05f"
    public static let manifestPins = [
        "community":"1e8022118f25d4593f4cb575702948c23aa1faa11c7a10358754ece248b30558",
        "official":"5dd26b770d8491ff3661f54f4e86aa576cc9dbb05a13200a0d0238e2097122bd",
    ]
    #if MODELPLAN_TEST_ONLY_SPI
    public static var verificationPage: ((CockpitWindowController) -> Void)?
    #endif
    public static func make(configuration: EngineClientConfiguration, settingsStore: SettingsStore,
                            createsNativePanels: Bool = true, bundleURL: URL = Bundle.main.bundleURL,
                            makeClient: (@MainActor (EngineClientConfiguration, EngineStore) -> any EngineClient)? = nil,
                            makeSettingsSurface: (@MainActor (SettingsEditor) -> any SettingsWindowSurface)? = nil,
                            makeConsole: (@MainActor (EngineDockMenuComposition) -> any EngineRowsConsoleSurface)? = nil,
                            activateSettings: @escaping @MainActor () -> Void = { NSApplication.shared.activate() }) -> EngineDockMenuApplication {
        // Preserve the existing injected-client/console seam used by its callers.
        if let makeClient {
            return EngineDockMenuApplication(configuration:configuration,settingsStore:settingsStore,
                createsNativePanels:createsNativePanels,bundleURL:bundleURL,makeClient:makeClient,
                makeSettingsSurface:makeSettingsSurface,makeConsole:makeConsole,activateSettings:activateSettings)
        }
        let owner = CockpitConsoleOwner(bundle:bundleURL,settingsStore:settingsStore)
        let application = EngineDockMenuApplication(configuration:configuration,settingsStore:settingsStore,
            createsNativePanels:createsNativePanels,bundleURL:bundleURL,
            makeClient: { configuration, store in
                let coordinator = EngineCockpitCoordinator { [weak owner] context in
                    guard let owner else { throw CockpitBridgeError.unavailable }
                    return try owner.makePage(context:context,executable:configuration.executableURL)
                }
                owner.coordinator=coordinator
                let client=ProcessEngineClient(configuration:configuration,consumer:CockpitStoreFanout(store:store,cockpit:coordinator))
                coordinator.bind(client:client) // borrowed; hiding cockpit must not stop Dock/Settings.
                return client
            },makeSettingsSurface:makeSettingsSurface,
            makeConsole: { composition in
                if let makeConsole { return makeConsole(composition) }
                return SharedEngineCockpitConsole(owner:owner,composition:composition)
            },activateSettings:activateSettings)
        owner.settings = { [weak application] in Task { await application?.presentSettings() } }
        return application
    }
}

@MainActor private final class CockpitConsoleOwner {
    let bundle: URL
    let settingsStore: SettingsStore
    var coordinator: EngineCockpitCoordinator?
    var settings: (() -> Void)?
    var appearance=CockpitAppearance(theme:.night,locale:.en,profile:.full)
    init(bundle: URL,settingsStore: SettingsStore) { self.bundle=bundle;self.settingsStore=settingsStore }
    func makePage(context: CockpitEngineContext, executable: URL) throws -> CockpitWindowController {
        guard executable.standardizedFileURL == bundle.appendingPathComponent("Contents/Helpers/modelplan").standardizedFileURL,
              CommunityConsentBundleIdentity.matches(bundle:bundle) else { throw CockpitBridgeError.unavailable }
        let editionURL=bundle.appendingPathComponent("Contents/Resources/build-edition.json")
        var edition="community"
        if let data=try? Data(contentsOf:editionURL),data.count<=1024,
           let value=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],value["edition"] as? String == "official" { edition="official" }
        let verified=try VerifiedCockpitBundle(root:bundle.appendingPathComponent("Contents/Resources/Cockpit"),
            manifestSHA256:CommunityCockpitApplicationFactory.manifestPins[edition]!,allowOfficial:edition == "official")
        let page=CockpitWindowController(bundle:verified,context:context,appearance:appearance)
        #if MODELPLAN_TEST_ONLY_SPI
        CommunityCockpitApplicationFactory.verificationPage?(page)
        #endif
        return page
    }
}

/// Both menu and Dock actions are retained by EngineDockMenuApplication.showConsole.
/// Rendering comes only from the same client's ordered typed response, never
/// from retagging the Store's cached cockpit DTO with a newer context.
@MainActor private final class SharedEngineCockpitConsole: EngineRowsConsoleSurface {
    let owner: CockpitConsoleOwner
    let composition: EngineDockMenuComposition
    var showTask: Task<Void,Never>?
    var wantsVisible=false
    var fallback: EngineRowsConsole?
    init(owner:CockpitConsoleOwner,composition:EngineDockMenuComposition) {
        self.owner=owner;self.composition=composition
        owner.coordinator?.onUnavailable = { [weak self] in self?.unavailable() }
        owner.coordinator?.onClosed = { [weak self] in self?.wantsVisible=false }
    }
    func show() {
        wantsVisible=true
        guard showTask == nil else { return }
        showTask=Task { @MainActor [weak self] in
            guard let self else { return }
            let snapshot=await owner.settingsStore.snapshot()
            guard !Task.isCancelled,wantsVisible else { showTask=nil;return }
            let theme:CockpitAppearance.Theme
            switch snapshot.preferences.theme {
            case .day:theme = .day
            case .night:theme = .night
            case .system:theme=NSApp.effectiveAppearance.bestMatch(from:[.aqua,.darkAqua]) == .darkAqua ? .night:.day
            }
            owner.appearance = .init(theme:theme,locale:snapshot.preferences.language == .english ? .en:.zhCN,profile:.full)
            owner.coordinator?.onIntent = { [weak self] intent in
                guard let self,self.wantsVisible else { return }
                switch intent {
                case .chooseSetup,.openSettings:self.owner.settings?()
                case .openHistory:self.unavailable(history:true)
                }
            }
            if !NSApp.isActive { NSApplication.shared.activate() }
            owner.coordinator?.open();showTask=nil
        }
    }
    func render() { fallback?.render() } // typed event delivery itself owns WK display.
    func hide() { wantsVisible=false;showTask?.cancel();showTask=nil;owner.coordinator?.close();fallback?.hide() }
    private func unavailable(history:Bool=false) {
        guard wantsVisible else { return }
        Task { @MainActor [weak self] in
            guard let self,NSApp.isActive else { return }
            let alert=NSAlert();alert.messageText="Cockpit unavailable / 驾驶舱暂不可用"
            alert.informativeText=history
                ? "History is unavailable in this candidate. Open Settings to check connected tools. / 当前候选版尚无历史窗口，请打开设置查看已连接工具。"
                : "Check tool access in Settings, or reinstall this candidate if bundled content is missing. / 请在设置中检查工具授权；若缺少随附内容，请重新安装候选版。"
            alert.addButton(withTitle:"Open Settings / 打开设置");alert.addButton(withTitle:"Dock readings / Dock 读数");alert.addButton(withTitle:"Cancel / 取消")
            switch alert.runModal() {
            case .alertFirstButtonReturn:owner.settings?()
            case .alertSecondButtonReturn:
                if fallback == nil { fallback=EngineRowsConsole(composition:composition) };fallback?.show()
            default:break
            }
        }
    }
}
