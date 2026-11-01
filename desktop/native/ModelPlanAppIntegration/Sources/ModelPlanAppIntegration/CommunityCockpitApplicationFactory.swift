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

/// Synthetic process/notice boundaries for normal-entry journeys. Page creation
/// always uses the production verifier and WK controller, never a substituted page.
@MainActor public struct CockpitRuntimeFactory {
    public let client: (EngineClientConfiguration, any EngineClientEventConsumer) -> any EngineClient
    public let onUnavailable: (() -> Void)?
    public init(client: @escaping (EngineClientConfiguration, any EngineClientEventConsumer) -> any EngineClient,
                onUnavailable: (() -> Void)? = nil) {
        self.client = client; self.onUnavailable = onUnavailable
    }
}

@MainActor public enum CommunityCockpitApplicationFactory {
    public static let webSource = "b9ceb86a9f083101aafd7f776f5439c97dd19b8d"
    public static let manifestPins = [
        "community":"c979c8f7bd5799f0c432f61f5e25e6ba2b603515f5b1cb15bcc0e73e559f250c",
        "official":"743796c2fa7507baf96ae65ebde5ce9efa62b4d11c2fe85cc365f04357ac12d2",
    ]
    #if MODELPLAN_TEST_ONLY_SPI
    public static var verificationPage: ((CockpitWindowController) -> Void)?
    #endif
    public static func make(configuration: EngineClientConfiguration, settingsStore: SettingsStore,
                            createsNativePanels: Bool = true, bundleURL: URL = Bundle.main.bundleURL,
                            cockpitRuntime: CockpitRuntimeFactory? = nil,
                            makeClient: (@MainActor (EngineClientConfiguration, EngineStore) -> any EngineClient)? = nil,
                            makeSettingsSurface: (@MainActor (SettingsEditor) -> any SettingsWindowSurface)? = nil,
                            makeConsole: (@MainActor (EngineDockMenuComposition) -> any EngineRowsConsoleSurface)? = nil,
                            activateSettings: @escaping @MainActor () -> Void = { NSApplication.shared.activate() }) -> EngineDockMenuApplication {
        // Preserve the existing injected-client/console seam used by its callers.
        if let makeClient, cockpitRuntime == nil {
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
                let fanout = CockpitStoreFanout(store:store,cockpit:coordinator)
                let client = cockpitRuntime?.client(configuration, fanout) ?? ProcessEngineClient(configuration:configuration,consumer:fanout)
                coordinator.bind(client:client) // borrowed; hiding cockpit must not stop Dock/Settings.
                return client
            },makeSettingsSurface:makeSettingsSurface,
            makeConsole: { composition in
                if let makeConsole { return makeConsole(composition) }
                return SharedEngineCockpitConsole(owner:owner,composition:composition,activate:activateSettings,
                    requestNotice: cockpitRuntime?.onUnavailable.map { callback in { (_: CockpitUnavailableNotice) in callback() } })
            },activateSettings:activateSettings)
        owner.anchor = { [weak application] in application?.cockpitAnchor }
        owner.visibility = { [weak application] in application?.cockpitVisibilityChanged($0) }
        owner.settings = { [weak application] in Task { await application?.presentSettings() } }
        return application
    }
}

@MainActor final class CockpitConsoleOwner {
    let bundle: URL
    let settingsStore: SettingsStore
    var coordinator: EngineCockpitCoordinator?
    var settings: (() -> Void)?
    var pageFailure: (() -> Void)?
    var anchor: (() -> CGRect?)?
    var visibility: ((Bool) -> Void)?
    let shell = CockpitShellSession()
    var appearance=CockpitAppearance(theme:.night,locale:.en,profile:.full)
    init(bundle: URL,settingsStore: SettingsStore) { self.bundle=bundle;self.settingsStore=settingsStore }
    func makePage(context: CockpitEngineContext, executable: URL) throws -> any CockpitPageSurface {
        guard executable.standardizedFileURL == bundle.appendingPathComponent("Contents/Helpers/modelplan").standardizedFileURL,
              CommunityConsentBundleIdentity.matches(bundle:bundle) else { throw CockpitBridgeError.unavailable }
        let editionURL=bundle.appendingPathComponent("Contents/Resources/build-edition.json")
        var edition="community"
        if let data=try? Data(contentsOf:editionURL),data.count<=1024,
           let value=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],value["edition"] as? String == "official" { edition="official" }
        let verified=try VerifiedCockpitBundle(root:bundle.appendingPathComponent("Contents/Resources/Cockpit"),
            manifestSHA256:CommunityCockpitApplicationFactory.manifestPins[edition]!,allowOfficial:edition == "official")
        let page=CockpitWindowController(bundle:verified,context:context,appearance:appearance, shellSession:shell, anchor:{ [weak self] in self?.anchor?() })
        page.onFailure = { [weak self] _ in self?.pageFailure?() }
        #if MODELPLAN_TEST_ONLY_SPI
        CommunityCockpitApplicationFactory.verificationPage?(page)
        #endif
        return page
    }
}

/// Both menu and Dock actions are retained by EngineDockMenuApplication.showConsole.
/// Rendering comes only from the same client's ordered typed response, never
/// from retagging the Store's cached cockpit DTO with a newer context.
enum CockpitRecoveryAction: Equatable { case settings, dockReadings, cancel }
struct CockpitUnavailableNotice {
    let history: Bool
    let actions: [CockpitRecoveryAction] = [.settings, .dockReadings, .cancel]
}

@MainActor final class SharedEngineCockpitConsole: EngineRowsConsoleSurface {
    let owner: CockpitConsoleOwner
    let composition: EngineDockMenuComposition
    var showTask: Task<Void,Never>?
    var wantsVisible=false
    var fallback: EngineRowsConsole?
    private let isForeground: @MainActor () -> Bool
    private let activate: @MainActor () -> Void
    private let requestNotice: (@MainActor (CockpitUnavailableNotice) -> Void)?
    init(owner:CockpitConsoleOwner,composition:EngineDockMenuComposition,
         isForeground: @escaping @MainActor () -> Bool = { NSApp.isActive },
         activate: @escaping @MainActor () -> Void = { if !NSApp.isActive { NSApplication.shared.activate() } },
         requestNotice: (@MainActor (CockpitUnavailableNotice) -> Void)? = nil) {
        self.owner=owner;self.composition=composition
        self.isForeground=isForeground;self.activate=activate;self.requestNotice=requestNotice
        owner.coordinator?.onUnavailable = { [weak self] in self?.unavailable() }
        owner.pageFailure = { [weak self] in self?.unavailable() }
        owner.coordinator?.onOpened = { [weak self] in self?.owner.visibility?(true) }
        owner.coordinator?.onClosed = { [weak self] in
            self?.wantsVisible=false; self?.owner.visibility?(false)
        }
    }
    func show() {
        wantsVisible=true
        guard showTask == nil else { return }
        showTask=Task { @MainActor [weak self] in
            guard let self else { return }
            let snapshot=await owner.settingsStore.snapshot()
            guard !Task.isCancelled,wantsVisible else { showTask=nil;return }
            // v1 is night-only, regardless of a retained Day preference.
            owner.appearance = .init(theme:.night,locale:snapshot.preferences.language == .english ? .en:.zhCN,
                profile:owner.appearance.profile, reduceMotion: snapshot.preferences.motion == .on ||
                (snapshot.preferences.motion == .system && NSWorkspace.shared.accessibilityDisplayShouldReduceMotion),
                reduceTransparency: snapshot.preferences.transparency == .on ||
                (snapshot.preferences.transparency == .system && NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency),
                shutterClosed: owner.shell.shutterClosed, detached:owner.shell.detached)
            owner.coordinator?.onIntent = { [weak self] intent in
                guard let self,self.wantsVisible else { return }
                switch intent {
                case .chooseSetup,.openSettings:self.owner.settings?()
                case .openHistory:self.unavailable(history:true)
                case .close:self.hide()
                case .detach,.putBack,.shutterToggle,.scopeSelect:break // handled by the native page
                }
            }
            activate()
            owner.coordinator?.open();showTask=nil
        }
    }
    func applySettings(_ transaction: SettingsApplication) {
        owner.appearance = .init(theme:.night, locale:transaction.effective.language == .english ? .en:.zhCN,
            profile:owner.appearance.profile, reduceMotion:transaction.effective.reduceMotion, reduceTransparency:transaction.effective.reduceTransparency,
            shutterClosed:owner.shell.shutterClosed, detached:owner.shell.detached)
        owner.coordinator?.updateAppearance(owner.appearance)
    }
    func render() { fallback?.render() } // typed event delivery itself owns WK display.
    func close() { wantsVisible=false;showTask?.cancel();showTask=nil;owner.coordinator?.requestClose();fallback?.hide() }
    func hide() { wantsVisible=false;showTask?.cancel();showTask=nil;owner.coordinator?.close();owner.visibility?(false);fallback?.hide() }
    private func unavailable(history:Bool=false) {
        guard wantsVisible else { return }
        let initiatedInForeground=isForeground()
        let notice=CockpitUnavailableNotice(history:history)
        Task { @MainActor [weak self] in
            guard let self,initiatedInForeground else { return }
            if let requestNotice { requestNotice(notice); return }
            let alert=NSAlert();alert.messageText="Cockpit unavailable / 驾驶舱暂不可用"
            alert.informativeText=history
                ? "History is unavailable in this candidate. Open Settings to check connected tools. / 当前候选版尚无历史窗口，请打开设置查看已连接工具。"
                : "Check tool access in Settings, or reinstall this candidate if bundled content is missing. / 请在设置中检查工具授权；若缺少随附内容，请重新安装候选版。"
            for action in notice.actions {
                switch action {
                case .settings:alert.addButton(withTitle:"Open Settings / 打开设置")
                case .dockReadings:alert.addButton(withTitle:"Dock readings / Dock 读数")
                case .cancel:alert.addButton(withTitle:"Cancel / 取消")
                }
            }
            switch alert.runModal() {
            case .alertFirstButtonReturn:owner.settings?()
            case .alertSecondButtonReturn:
                if fallback == nil { fallback=EngineRowsConsole(composition:composition) };fallback?.show()
            default:break
            }
        }
    }
}
