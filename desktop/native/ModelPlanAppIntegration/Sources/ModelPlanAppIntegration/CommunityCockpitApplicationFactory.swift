// SPDX-License-Identifier: MIT
import AppKit
import Foundation
import ModelPlanCockpitWeb
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanSettings
import ModelPlanWire
import ModelPlanDock

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
    public static let webSource = "f25e1e821411bdd58cb09d9a388b9064505e856c"
    public static let manifestPins = [
        "community":"03d4e9e0f504cd8bbfeae9c2f96663d3026e4796f2ffa49a8af9c27fe7e7ba72",
        "official":"e76613231de3c82e7335380089a71da50d90182c2a37fdf5d990b0eaf753ec59",
    ]
    #if MODELPLAN_TEST_ONLY_SPI
    public static var verificationPage: ((CockpitWindowController) -> Void)?
    static var verificationPageFactory: EngineCockpitCoordinator.PageFactory?
    #endif
    public static func make(configuration: EngineClientConfiguration, settingsStore: SettingsStore,
                            createsNativePanels: Bool = true, bundleURL: URL = Bundle.main.bundleURL,
                            cockpitEntryEnabled: Bool? = nil,
                            dockEnvironment: (@MainActor () -> DockEdgeEnvironment)? = nil,
                            deadlineNow: @escaping @MainActor () -> Date = { Date() },
                            deadlineElapsed: (() -> TimeInterval)? = nil, deadlineScheduling: (any DockEdgeScheduling)? = nil,
                            makeClient: (@MainActor (EngineClientConfiguration, EngineStore) -> any EngineClient)? = nil,
                            makeSettingsSurface: (@MainActor (SettingsEditor) -> any SettingsWindowSurface)? = nil,
                            makeConsole: (@MainActor (EngineDockMenuComposition) -> any EngineRowsConsoleSurface)? = nil,
                            activateSettings: @escaping @MainActor () -> Void = { NSApplication.shared.activate() }) -> EngineDockMenuApplication {
        // Preserve the existing injected-client/console seam used by its callers.
        if let makeClient {
            return EngineDockMenuApplication(configuration:configuration,settingsStore:settingsStore,
                createsNativePanels:createsNativePanels,bundleURL:bundleURL,cockpitEntryEnabled:cockpitEntryEnabled,dockEnvironment:dockEnvironment,deadlineNow:deadlineNow,deadlineElapsed:deadlineElapsed,deadlineScheduling:deadlineScheduling,makeClient:makeClient,
                makeSettingsSurface:makeSettingsSurface,makeConsole:makeConsole,activateSettings:activateSettings)
        }
        #if MODELPLAN_TEST_ONLY_SPI
        let verificationFactory = verificationPageFactory
        #endif
        let owner = CockpitConsoleOwner(bundle:bundleURL,settingsStore:settingsStore)
        let application = EngineDockMenuApplication(configuration:configuration,settingsStore:settingsStore,
            createsNativePanels:createsNativePanels,bundleURL:bundleURL,cockpitEntryEnabled:cockpitEntryEnabled,dockEnvironment:dockEnvironment,deadlineNow:deadlineNow,deadlineElapsed:deadlineElapsed,deadlineScheduling:deadlineScheduling,
            makeClient: { configuration, store in
                let coordinator = EngineCockpitCoordinator { [weak owner] context in
                    #if MODELPLAN_TEST_ONLY_SPI
                    if let verificationFactory { return try verificationFactory(context) }
                    #endif
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
                #if MODELPLAN_TEST_ONLY_SPI
                if verificationFactory != nil {
                    return SharedEngineCockpitConsole(owner:owner,composition:composition,activate:{})
                }
                #endif
                return SharedEngineCockpitConsole(owner:owner,composition:composition)
            },activateSettings:activateSettings)
        owner.anchor = { [weak application] in application?.cockpitAnchor }
        owner.settings = { [weak application] in Task { await application?.presentSettings() } }
        return application
    }
}

@MainActor final class CockpitConsoleOwner {
    let bundle: URL
    let settingsStore: SettingsStore
    var coordinator: EngineCockpitCoordinator?
    var settings: (() -> Void)?
    /// The one way a cockpit website link leaves the app; tests read the URL instead of a browser.
    var openWebsite: @MainActor (URL) -> Void = { NSWorkspace.shared.open($0) }
    var pageFailure: ((CockpitWindowFailure) -> Void)?
    var anchor: (() -> CGRect?)?
    var verifiedBundle: VerifiedCockpitBundle?
    let shell = CockpitShellSession()
    var appearance=CockpitAppearance(theme:.night,locale:.en,profile:.full)
    init(bundle: URL,settingsStore: SettingsStore) { self.bundle=bundle;self.settingsStore=settingsStore }
    func makePage(context: CockpitEngineContext, executable: URL) throws -> CockpitWindowController {
        guard executable.standardizedFileURL == bundle.appendingPathComponent("Contents/Helpers/modelplan").standardizedFileURL,
              CommunityConsentBundleIdentity.matches(bundle:bundle) || CommunityConsentBundleIdentity.matchesOwnerTest(bundle:bundle)
        else { throw CockpitBridgeError.unavailable }
        let editionURL=bundle.appendingPathComponent("Contents/Resources/build-edition.json")
        var edition="community"
        if let data=try? Data(contentsOf:editionURL),data.count<=1024,
           let value=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],value["edition"] as? String == "official" { edition="official" }
        let verified=try VerifiedCockpitBundle(root:bundle.appendingPathComponent("Contents/Resources/Cockpit"),
            manifestSHA256:CommunityCockpitApplicationFactory.manifestPins[edition]!,allowOfficial:edition == "official")
        verifiedBundle=verified
        let page=CockpitWindowController(bundle:verified,context:context,appearance:appearance,
            shellSession:shell,anchor:{ [weak self] in self?.anchor?() })
        page.onFailure = { [weak self] failure in self?.pageFailure?(failure) }
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
    private var pageOpened = false
    var fallback: EngineRowsConsole?
    private var appliedSettings: SettingsApplication?
    private let isForeground: @MainActor () -> Bool
    private let activate: @MainActor () -> Void
    private let requestNotice: (@MainActor (CockpitUnavailableNotice) -> Void)?
    init(owner:CockpitConsoleOwner,composition:EngineDockMenuComposition,
         isForeground: @escaping @MainActor () -> Bool = { NSApp.isActive },
         activate: @escaping @MainActor () -> Void = { if !NSApp.isActive { NSApplication.shared.activate() } },
         requestNotice: (@MainActor (CockpitUnavailableNotice) -> Void)? = nil) {
        self.owner=owner;self.composition=composition
        self.isForeground=isForeground;self.activate=activate;self.requestNotice=requestNotice
        owner.coordinator?.onUnavailable = { [weak self] reason in self?.unavailable(path:reason.path) }
        owner.pageFailure = { [weak self] failure in self?.unavailable(path:"page."+failure.rawValue) }
        let onOpened = owner.coordinator?.onOpened
        owner.coordinator?.onOpened = { [weak self] in
            self?.pageOpened = true
            onOpened?()
        }
        owner.coordinator?.onClosed = { [weak self] in
            guard let self else { return }
            self.wantsVisible = false
            self.fieldPanel?.close()
            self.pageOpened = false
            self.composition.dock.setCockpitPresentationBlocked(false)
        }
    }
    /// Public model data only: the launch field never receives personal readings. The official page is
    /// the only one that asks; a community bundle has no field page, so the panel is not offered.
    private struct FieldPayload:Encodable {
        let language:String,reduceMotion:Bool,models:[WireCockpitPublicationModel],mine:[String],focus:String?
    }
    private var fieldPanel:CockpitFieldPanel?
    var fieldIsOpen:Bool { fieldPanel?.isOpen == true }
    func fieldPayload() -> String? {
        guard let details=composition.store.snapshot.cockpit?.details,let models=details.publishedModels,!models.isEmpty else { return nil }
        let mine=details.publication?.models.map(\.id) ?? []
        let value=FieldPayload(language:owner.appearance.locale == .en ? "en":"zh",reduceMotion:owner.appearance.reduceMotion,models:models,mine:mine,focus:nil)
        return (try? JSONEncoder().encode(value)).flatMap { String(data:$0,encoding:.utf8) }
    }
    func handle(_ intent:CockpitIntent) {
        guard wantsVisible else { return }
        switch intent {
        case .chooseSetup,.openSettings:owner.settings?()
        case .openHistory:unavailable(path:"intent.openHistory",history:true)
        case .openField:openField()
        case .openWebsite(let link):owner.openWebsite(link.url)
        case .close:owner.coordinator?.requestClose()
        case .detach,.putBack,.shutterToggle,.scopeSelect:
            // The page owns shell controls; the coordinator validates and
            // consumes scope selection. An unexpected escape fails closed.
            hide()
        }
    }
    private func openField() {
        guard let bundle=owner.verifiedBundle,let payload=fieldPayload() else { return }
        let panel=fieldPanel ?? CockpitFieldPanel(bundle:bundle)
        fieldPanel=panel;panel.open(payload:payload,near:owner.anchor?())
    }
    /// The page follows the committed settings live; a cockpit opened later starts from them.
    func applySettings(_ value: SettingsApplication) {
        appliedSettings=value
        owner.appearance=cockpitAppearance(value)
        owner.coordinator?.updateAppearance(owner.appearance)
    }
    private func cockpitAppearance(_ value: SettingsApplication) -> CockpitAppearance {
        let e=value.effective
        return .init(theme:owner.appearance.theme,locale:e.language == .english ? .en:.zhCN,profile:.full,
            reduceMotion:e.reduceMotion,reduceTransparency:e.reduceTransparency,redBelow:e.redBelow,showProjectNames:e.showProjectNames)
    }
    func show() {
        wantsVisible=true
        guard showTask == nil else { return }
        composition.dock.setCockpitPresentationBlocked(true)
        showTask=Task { @MainActor [weak self] in
            guard let self else { return }
            let snapshot=await owner.settingsStore.snapshot()
            guard !Task.isCancelled else { return }
            guard wantsVisible else { showTask = nil; return }
            let theme:CockpitAppearance.Theme
            switch snapshot.preferences.theme {
            case .day:theme = .day
            case .night:theme = .night
            case .system:theme=NSApp.effectiveAppearance.bestMatch(from:[.aqua,.darkAqua]) == .darkAqua ? .night:.day
            }
            owner.appearance = .init(theme:theme,locale:snapshot.preferences.language == .english ? .en:.zhCN,profile:.full,
                redBelow:snapshot.preferences.redBelow,showProjectNames:snapshot.preferences.showProjectNames)
            if let appliedSettings { owner.appearance=cockpitAppearance(appliedSettings) }
            owner.coordinator?.onIntent = { [weak self] intent in self?.handle(intent) }
            activate()
            owner.coordinator?.open()
            if !pageOpened { composition.dock.setCockpitPresentationBlocked(false) }
            showTask = nil
        }
    }
    func render() { fallback?.render() } // typed event delivery itself owns WK display.
    func hide() {
        wantsVisible = false
        showTask?.cancel()
        showTask = nil
        fieldPanel?.close()
        owner.coordinator?.close()
        pageOpened = false
        composition.dock.setCockpitPresentationBlocked(false)
        fallback?.hide()
    }
    private func unavailable(path:String,history:Bool=false) {
        let initiatedInForeground=isForeground()
        // A failure in the background or after a close shows nothing, so the log is all there is.
        CockpitFailureLog.record("unavailable path=\(path) wantsVisible=\(wantsVisible) foreground=\(initiatedInForeground) pageOpened=\(pageOpened)")
        guard wantsVisible else { return }
        let notice=CockpitUnavailableNotice(history:history)
        Task { @MainActor [weak self] in
            guard let self,initiatedInForeground else { return }
            if let requestNotice { requestNotice(notice); return }
            let english=await owner.settingsStore.snapshot().preferences.language == .english
            let alert=NSAlert();alert.messageText=english ? "Cockpit unavailable" : "驾驶舱暂不可用"
            alert.informativeText=history
                ? (english ? "History is unavailable in this candidate. Open Settings to check connected tools." : "当前候选版尚无历史窗口，请打开设置查看已连接工具。")
                : (english ? "Check tool access in Settings, or reinstall this candidate if bundled content is missing." : "请在设置中检查工具授权；若缺少随附内容，请重新安装候选版。")
            for action in notice.actions {
                switch action {
                case .settings:alert.addButton(withTitle:english ? "Open Settings" : "打开设置")
                case .dockReadings:alert.addButton(withTitle:english ? "Cockpit" : "驾驶舱")
                case .cancel:alert.addButton(withTitle:english ? "Cancel" : "取消")
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
