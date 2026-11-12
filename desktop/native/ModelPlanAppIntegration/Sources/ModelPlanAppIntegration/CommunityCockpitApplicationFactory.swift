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
    /// The manifest SHA-256 of each canonical cockpit edition. Never committed: whoever compiles the App first builds
    /// the editions and runs check-bundle-pins.py, which writes CockpitBundlePins.generated.swift from those exact
    /// bytes. Without that file the App has no pins and admits no cockpit page.
    public static let manifestPins = CockpitBuildPins.manifest
    #if MODELPLAN_TEST_ONLY_SPI
    public static var verificationPage: ((CockpitWindowController) -> Void)?
    static var verificationPageFactory: EngineCockpitCoordinator.PageFactory?
    static var verificationConsoleNotice: (@MainActor (CockpitUnavailableNotice) -> Void)?
    static var verificationNoticeGrace: Duration?
    /// The coordinator's prewarm and open steps, for timing tests.
    public static var verificationCockpitTrace: ((String) -> Void)?
    /// False measures the open without a prewarmed page, as before CKP-SHELL-20.
    static var verificationPrewarm = true
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
        let verificationNotice = verificationConsoleNotice
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
                #if MODELPLAN_TEST_ONLY_SPI
                coordinator.verificationTrace = { CommunityCockpitApplicationFactory.verificationCockpitTrace?($0) }
                #endif
                let client=ProcessEngineClient(configuration:configuration,consumer:CockpitStoreFanout(store:store,cockpit:coordinator))
                coordinator.bind(client:client) // borrowed; hiding cockpit must not stop Dock/Settings.
                coordinator.currentDate = deadlineNow // CKP-ENTRY-04: the scope's day is the app clock's day.
                coordinator.scopeMemory = FileCockpitScopeMemory(url: settingsStore.directory.appendingPathComponent("cockpit-scope.json"))
                coordinator.cautionMemory = FileCockpitCautionMemory(url: settingsStore.directory.appendingPathComponent("cockpit-cautions.json"))
                coordinator.pinMemory = FileCockpitPinMemory(url: settingsStore.directory.appendingPathComponent("cockpit-pins.json"))
                return client
            },makeSettingsSurface:makeSettingsSurface,
            makeConsole: { composition in
                if let makeConsole { return makeConsole(composition) }
                #if MODELPLAN_TEST_ONLY_SPI
                if let verificationNotice {
                    return SharedEngineCockpitConsole(owner:owner,composition:composition,isForeground:{ true },activate:{},requestNotice:verificationNotice,
                                                     noticeGrace:CommunityCockpitApplicationFactory.verificationNoticeGrace ?? SharedEngineCockpitConsole.defaultNoticeGrace)
                }
                if verificationFactory != nil {
                    return SharedEngineCockpitConsole(owner:owner,composition:composition,activate:{})
                }
                #endif
                return SharedEngineCockpitConsole(owner:owner,composition:composition)
            },activateSettings:activateSettings)
        owner.anchor = { [weak application] in application?.cockpitAnchor }
        owner.openPoint = { [weak application] in application?.cockpitOpenPoint }
        owner.ignitionFrame = { [weak application] in application?.composition.dock.ignitionScreenFrame }
        if application.cockpitEntryEnabled {
            owner.prepare()
            // CKP-SHELL-20: a synthetic page from a test factory is made only by a click.
            #if MODELPLAN_TEST_ONLY_SPI
            let prewarms = verificationFactory == nil && verificationPrewarm
            #else
            let prewarms = true
            #endif
            if prewarms { owner.startPrewarm(applied: { [weak application] in application?.composition.latestSettings }) }
        }
        owner.settings = { [weak application] in Task { await application?.presentSettings() } }
        owner.currentSize = { [weak application] in application?.composition.latestSettings?.snapshot.preferences.size }
        owner.setSize = { [weak application] size in Task { await application?.setWidgetSize(size) } }
        application.resetCockpitPosition = { [weak owner] in owner?.currentPage?.resetPosition() }
        return application
    }
}

/// Build-time cockpit pins. The gitignored CockpitBundlePins.generated.swift declares `manifest` on
/// CockpitBuildPins itself, which takes precedence over this empty default; without it nothing is admitted.
protocol CockpitBuildPinSource {}
extension CockpitBuildPinSource { static var manifest: [String: String] { [:] } }
enum CockpitBuildPins: CockpitBuildPinSource {}

@MainActor final class CockpitConsoleOwner {
    let bundle: URL
    let settingsStore: SettingsStore
    var coordinator: EngineCockpitCoordinator?
    var settings: (() -> Void)?
    /// Right-click menu hooks, set by the factory beside `settings`.
    var setSize: ((SettingsSize) -> Void)?
    var currentSize: (() -> SettingsSize?)?
    weak var currentPage: CockpitWindowController?
    private var contextMenu: CockpitContextMenu?
    /// The cockpit's own right-click menu: Settings…, Reset Position, Quota Widget Size, Help.
    func makeContextMenu(page: CockpitWindowController?) -> NSMenu {
        let menu = CockpitContextMenu(language: appearance.locale == .en ? .english : .chinese, size: currentSize?(),
            actions: .init(settings: { [weak self] in self?.settings?() },
                           resetPosition: { [weak page] in page?.resetPosition() },
                           help: { [weak page] in page?.showHelpMap() },
                           setSize: { [weak self] in self?.setSize?($0) }))
        contextMenu = menu
        return menu.menu
    }
    /// The one way a cockpit website link leaves the app; tests read the URL instead of a browser.
    var openWebsite: @MainActor (URL) -> Void = { NSWorkspace.shared.open($0) }
    var pageFailure: ((CockpitWindowFailure) -> Void)?
    var anchor: (() -> CGRect?)?
    /// Build 14c (G3-79): where the latest open was clicked; nil opens on the menu bar icon's display.
    var openPoint: (() -> CGPoint?)?
    /// D204 (G3-94): the widget ignition's frame on screen; its press is not an outside click.
    var ignitionFrame: (() -> CGRect?)?
    var verifiedBundle: VerifiedCockpitBundle?
    let shell = CockpitShellSession()
    var appearance=CockpitAppearance(theme:.night,locale:.en,profile:.full)
    init(bundle: URL,settingsStore: SettingsStore) { self.bundle=bundle;self.settingsStore=settingsStore }
    /// G3-42: hashing the helper and every bundle file took the main thread on each click. The app's identity and
    /// bundle are checked once per launch, away from the click; every served file is still checked again as it loads.
    /// A click before this finishes checks on the spot, and a failure here is reported by that click.
    func prepare() {
        guard verifiedBundle == nil, preparation == nil else { return }
        let bundle=self.bundle,pins=CommunityCockpitApplicationFactory.manifestPins
        let work=Task.detached(priority:.utility) { try? Self.admit(bundle:bundle,pins:pins) }
        preparation=work
        Task { @MainActor [weak self] in
            let verified=await work.value
            guard let self else { return }
            preparation=nil
            if verifiedBundle == nil { verifiedBundle=verified }
        }
    }
    private var preparation: Task<VerifiedCockpitBundle?,Never>?
    nonisolated private static func admit(bundle: URL,pins: [String:String]) throws -> VerifiedCockpitBundle {
        guard CommunityConsentBundleIdentity.matches(bundle:bundle) || CommunityConsentBundleIdentity.matchesOwnerTest(bundle:bundle)
        else { throw CockpitBridgeError.unavailable }
        let editionURL=bundle.appendingPathComponent("Contents/Resources/build-edition.json")
        var edition="community"
        if let data=try? Data(contentsOf:editionURL),data.count<=1024,
           let value=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],value["edition"] as? String == "official" { edition="official" }
        guard let pin=pins[edition] else { throw CockpitBridgeError.unavailable }
        return try VerifiedCockpitBundle(root:bundle.appendingPathComponent("Contents/Resources/Cockpit"),
            manifestSHA256:pin,allowOfficial:edition == "official")
    }
    /// CKP-SHELL-20 (owner D50): the hidden page starts with the saved appearance, so the first frame
    /// shown is already in the user's language and settings.
    func startPrewarm(applied: @escaping @MainActor () -> SettingsApplication?) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let snapshot = await settingsStore.snapshot()
            if coordinator?.presented != true { adoptAppearance(snapshot, applied: applied()) }
            coordinator?.prewarmEnabled = true
        }
    }
    func adoptAppearance(_ snapshot: SettingsSnapshot, applied: SettingsApplication?) {
        let theme:CockpitAppearance.Theme
        switch snapshot.preferences.theme {
        case .day:theme = .day
        case .night:theme = .night
        case .system:theme=NSApplication.shared.effectiveAppearance.bestMatch(from:[.aqua,.darkAqua]) == .darkAqua ? .night:.day
        }
        appearance = .init(theme:CockpitDayPolicy.resolve(theme),locale:snapshot.preferences.language == .english ? .en:.zhCN,profile:.full,
            redBelow:snapshot.preferences.redBelow,showProjectNames:snapshot.preferences.showProjectNames,showUsedPercent:snapshot.preferences.percentageMode == .used,showAllModels:snapshot.preferences.showAllModels,
            size:CockpitSize(snapshot.preferences.cockpitSize))
        if let applied { appearance=cockpitAppearance(applied) }
    }
    func cockpitAppearance(_ value: SettingsApplication) -> CockpitAppearance {
        let e=value.effective
        return .init(theme:appearance.theme,locale:e.language == .english ? .en:.zhCN,profile:.full,
            reduceMotion:e.reduceMotion,reduceTransparency:e.reduceTransparency,redBelow:e.redBelow,showProjectNames:e.showProjectNames,showUsedPercent:e.showUsedPercent,showAllModels:e.showAllModels,
            size:CockpitSize(e.cockpitSize))
    }
    func makePage(context: CockpitEngineContext, executable: URL) throws -> CockpitWindowController {
        guard executable.standardizedFileURL == bundle.appendingPathComponent("Contents/Helpers/modelplan").standardizedFileURL
        else { throw CockpitBridgeError.unavailable }
        let verified=try verifiedBundle ?? Self.admit(bundle:bundle,pins:CommunityCockpitApplicationFactory.manifestPins)
        verifiedBundle=verified
        return makePage(context:context,verified:verified)
    }
    func makePage(context: CockpitEngineContext, verified: VerifiedCockpitBundle) -> CockpitWindowController {
        let page=CockpitWindowController(bundle:verified,context:context,appearance:appearance,
            shellSession:shell,anchor:{ [weak self] in self?.anchor?() },openPoint:{ [weak self] in self?.openPoint?() })
        page.ignitionFrame = { [weak self] in self?.ignitionFrame?() }
        page.onFailure = { [weak self] failure in self?.pageFailure?(failure) }
        currentPage = page
        page.contextMenuProvider = { [weak self, weak page] in self?.makeContextMenu(page: page) }
        #if MODELPLAN_TEST_ONLY_SPI
        CommunityCockpitApplicationFactory.verificationPage?(page)
        #endif
        return page
    }
}

/// D64: the cockpit scope and its local day in one small file beside the settings. A consent or store change removes it.
@MainActor final class FileCockpitScopeMemory: CockpitScopeMemory {
    let url: URL
    init(url: URL) { self.url = url }
    func load() -> (key: String, day: String)? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              ((attributes[.size] as? NSNumber)?.intValue ?? Int.max) <= 1024,
              let data = try? Data(contentsOf: url),
              let value = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let key = value["scope"] as? String, let day = value["day"] as? String else { return nil }
        return (key, day)
    }
    func save(_ value: (key: String, day: String)?) {
        guard let value else { try? FileManager.default.removeItem(at: url); return }
        guard let data = try? JSONSerialization.data(withJSONObject: ["scope": value.key, "day": value.day], options: [.sortedKeys]) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

/// G3-56: the acknowledged caution identities in one small file beside the settings. Opaque ids only, no readings.
@MainActor final class FileCockpitCautionMemory: CockpitCautionMemory {
    let url: URL
    init(url: URL) { self.url = url }
    func load() -> [String] {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              ((attributes[.size] as? NSNumber)?.intValue ?? Int.max) <= 16 * 1024,
              let data = try? Data(contentsOf: url),
              let value = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let ids = value["acked"] as? [String], CockpitCautionIdentities.valid(ids) else { return [] }
        return ids
    }
    func save(_ ids: [String]) {
        guard !ids.isEmpty else { try? FileManager.default.removeItem(at: url); return }
        guard let data = try? JSONSerialization.data(withJSONObject: ["acked": ids], options: [.sortedKeys]) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

/// D136: the favourite (long-press pinned) model ids in one small file beside the settings. Public model ids only.
@MainActor final class FileCockpitPinMemory: CockpitPinMemory {
    let url: URL
    init(url: URL) { self.url = url }
    func load() -> [String] {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              ((attributes[.size] as? NSNumber)?.intValue ?? Int.max) <= 16 * 1024,
              let data = try? Data(contentsOf: url),
              let value = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let ids = value["pinned"] as? [String], CockpitCautionIdentities.valid(ids), Set(ids).count == ids.count else { return [] }
        return ids
    }
    func save(_ ids: [String]) {
        guard !ids.isEmpty else { try? FileManager.default.removeItem(at: url); return }
        guard let data = try? JSONSerialization.data(withJSONObject: ["pinned": ids], options: [.sortedKeys]) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

/// Both menu and Dock actions are retained by EngineDockMenuApplication.showConsole.
/// Rendering comes only from the same client's ordered typed response, never
/// from retagging the Store's cached cockpit DTO with a newer context.
enum CockpitRecoveryAction: Equatable { case settings, dockReadings, cancel }
struct CockpitUnavailableNotice {
    let history: Bool
    /// G3-95: only a bundle that cannot be admitted or read is a reinstall problem. Every other cause is a state
    /// that can pass (engine, page, query), so the copy asks for a retry and the settings check instead.
    let bundleProblem: Bool
    let actions: [CockpitRecoveryAction] = [.settings, .dockReadings, .cancel]
    init(history: Bool, bundleProblem: Bool = false) { self.history = history; self.bundleProblem = bundleProblem }
    private static let bundleErrors: Set<String> = ["unavailable", "invalidManifest", "unsafePath", "unsafeRoot", "unsafeInventory", "unsafeOpen", "unsafeRegular", "integrity", "limit"]
    /// True when a page could not be created because the bundle or its pins failed (the path ends in the error's case name).
    static func isBundleProblem(path: String) -> Bool {
        if path == "page.bundleResource" { return true } // an admitted bundle that later could not serve a file
        guard path.hasPrefix("open.pageCreation.") else { return false }
        return bundleErrors.contains(String(path.dropFirst("open.pageCreation.".count)))
    }
}

@MainActor final class SharedEngineCockpitConsole: EngineRowsConsoleSurface {
    let owner: CockpitConsoleOwner
    let composition: EngineDockMenuComposition
    var showTask: Task<Void,Never>?
    var wantsVisible=false
    private var pageOpened = false
    private var entrance: CockpitEntrance = .fade
    var fallback: EngineRowsConsole?
    private var appliedSettings: SettingsApplication?
    private let isForeground: @MainActor () -> Bool
    private let activate: @MainActor () -> Void
    private let requestNotice: (@MainActor (CockpitUnavailableNotice) -> Void)?
    /// G3-66: how long a failed open may still recover before the notice appears.
    static let defaultNoticeGrace: Duration = .seconds(4)
    private let noticeGrace: Duration
    /// Counts successful page opens; a notice is dropped when one happened after the failure it was raised for.
    private var openCount = 0
    /// True when the latest thing that happened was a page open, false when it was a failure. A grace period only ends
    /// as a recovery if the page opened and nothing failed after it: a rebuild that opens and then fails, or whose
    /// next page cannot be created, is not a recovery (macrevc-786-1).
    private var lastEventWasOpen = false
    private var noticeTask: Task<Void,Never>?
    /// The engine reported the cockpit feature failed: the close the coordinator makes next is that failure's, and its
    /// notice outlives it. Any other close of a presented cockpit is the user's and retires the notice (audit A-5).
    private var failureClosesPage = false
    private var rebuilding = false
    private var rebuilds = 0
    /// G3-95: the path that started the current grace period (named in the notice's log line) and whether the one
    /// silent retry of a non-page failure has been spent.
    private var noticePath = ""
    private var retriedOpen = false
    /// The quiet retry waiting to run, and the click it belongs to. A retry never outlives its click (hide, close, a new
    /// click), so a reopen cannot be retried by the attempt before it.
    private var retryTask: Task<Void,Never>?
    private var attempt = 0
    static let openRetryDelay: Duration = .milliseconds(700)
    static let maxRebuilds = 2
    init(owner:CockpitConsoleOwner,composition:EngineDockMenuComposition,
         isForeground: @escaping @MainActor () -> Bool = { NSApp.isActive },
         activate: @escaping @MainActor () -> Void = { if !NSApp.isActive { NSApplication.shared.activate() } },
         requestNotice: (@MainActor (CockpitUnavailableNotice) -> Void)? = nil,
         noticeGrace: Duration = SharedEngineCockpitConsole.defaultNoticeGrace) {
        self.owner=owner;self.composition=composition;self.noticeGrace=noticeGrace
        self.isForeground=isForeground;self.activate=activate;self.requestNotice=requestNotice
        owner.coordinator?.onUnavailable = { [weak self] reason in self?.unavailable(path:reason.path) }
        owner.pageFailure = { [weak self] failure in self?.unavailable(path:"page."+failure.rawValue) }
        let onOpened = owner.coordinator?.onOpened
        owner.coordinator?.onOpened = { [weak self] in
            self?.pageOpened = true
            self?.openCount += 1
            self?.lastEventWasOpen = true
            // A successful open after a failure is the recovery: the grace period and the rebuild state end here, so a
            // later user close (page button, outside click) is an ordinary close, not another failure to rebuild from.
            self?.noticeTask?.cancel(); self?.noticeTask=nil; self?.retryTask?.cancel(); self?.retryTask=nil; self?.rebuilding=false
            self?.noticePath="" // the episode is over: a later failure names its own cause
            onOpened?()
        }
        // Audit A-5: fresh data on the presented page is a recovery too. A query that failed and then succeeded on the
        // same page must not announce an unavailable cockpit.
        let onDisplayed = owner.coordinator?.onDisplayed
        owner.coordinator?.onDisplayed = { [weak self] in
            if let self, self.noticeTask != nil, !self.rebuilding {
                self.lastEventWasOpen = true
                self.noticeTask?.cancel(); self.noticeTask=nil; self.retryTask?.cancel(); self.retryTask=nil; self.noticePath=""
            }
            onDisplayed?()
        }
        // D88: a detach, a put back or the settled open refreshes the icon highlight and the hints.
        owner.coordinator?.onShellChanged = { [weak self] in self?.onShowingChanged?() }
        owner.coordinator?.onClosed = { [weak self] in
            guard let self else { return }
            if self.rebuilding, self.wantsVisible, self.noticeTask != nil {
                // A failed page inside the grace period: keep the presentation and build the page again.
                self.pageOpened=false
                Task { @MainActor [weak self] in
                    try? await Task.sleep(for:.milliseconds(150))
                    guard let self,self.rebuilding,self.wantsVisible,self.noticeTask != nil else { return }
                    self.owner.coordinator?.open()
                }
                return
            }
            // Audit A-5: a user close (the page's close key, an outside click) retires a notice still in its grace
            // period; the close that follows an engine feature failure keeps it.
            if self.failureClosesPage { self.failureClosesPage = false }
            else { self.noticeTask?.cancel(); self.noticeTask=nil; self.retryTask?.cancel(); self.retryTask=nil; self.rebuilding=false }
            self.wantsVisible = false
            self.onShowingChanged?()
            self.fieldPanel?.close()
            self.pageOpened = false
        }
    }
    /// Public model data only: the launch field never receives personal readings. The official page is
    /// the only one that asks; a community bundle has no field page, so the panel is not offered.
    private struct FieldPayload:Encodable {
        let language:String,reduceMotion:Bool,lowPower:Bool,models:[WireCockpitPublicationModel],mine:[String],focus:String?
    }
    private var fieldPanel:CockpitFieldPanel?
    /// G3-80 seams: where the pointer is, the cockpit's frame and the displays the field is placed on.
    var pointerLocation: @MainActor () -> CGPoint = { NSEvent.mouseLocation }
    var cockpitFrameForField: (@MainActor () -> CGRect?)?
    var fieldScreens: (@MainActor () -> [CockpitScreen])?
    var fieldWindowFrame: CGRect? { fieldPanel?.isOpen == true ? fieldPanel?.windowFrame : nil }
    var fieldIsOpen:Bool { fieldPanel?.isOpen == true }
    /// `focusName`: the published display name of a rocket clicked in the porthole still (D63); an unknown name
    /// focuses nothing. Only the matching public model ID crosses.
    /// `lowPower` is the Low Power Mode state at open (D63): the scene mounts quiet and on demand when it is on.
    func fieldPayload(focusName:String?=nil,lowPower:Bool=ProcessInfo.processInfo.isLowPowerModeEnabled) -> String? {
        guard let details=composition.store.snapshot.cockpit?.details,let models=details.publishedModels,!models.isEmpty else { return nil }
        let mine=details.publication?.models.map(\.id) ?? []
        let focus=focusName.flatMap { name in models.first { $0.name == name }?.id }
        let value=FieldPayload(language:owner.appearance.locale == .en ? "en":"zh",reduceMotion:owner.appearance.reduceMotion,lowPower:lowPower,models:models,mine:mine,focus:focus)
        return (try? JSONEncoder().encode(value)).flatMap { String(data:$0,encoding:.utf8) }
    }
    func handle(_ intent:CockpitIntent) {
        guard wantsVisible else { return }
        switch intent {
        case .chooseSetup,.openSettings:owner.settings?()
        case .openHistory:unavailable(path:"intent.openHistory",history:true)
        case .openField:openField()
        case .openFieldAt(let name):openField(focusName:name)
        case .openWebsite(let link):owner.openWebsite(link.url)
        case .close:owner.coordinator?.requestClose()
        case .detach,.putBack,.shutterToggle,.scopeSelect,.cautionAck,.pinnedModels:
            // The page owns shell controls; the coordinator validates and
            // consumes scope selection. An unexpected escape fails closed.
            hide()
        }
    }
    private func openField(focusName:String?=nil) {
        guard let bundle=owner.verifiedBundle else { return }
        let panel=fieldPanel ?? CockpitFieldPanel(bundle:bundle)
        guard let payload=fieldPayload(focusName:focusName,lowPower:panel.isLowPower) else { return }
        if let fieldScreens { panel.screens=fieldScreens }
        // Build 14c (G3-80): on the cockpit's display. The intent does not say whether a click or a key opened it, so
        // the pointer counts only while it is over the cockpit (macrev2-845-2).
        let cockpit=cockpitFrameForField?() ?? owner.coordinator?.cockpitFrame
        fieldPanel=panel;panel.open(payload:payload,cockpit:cockpit,pointer:pointerLocation(),fallback:owner.anchor?())
    }
    /// The page follows the committed settings live; a cockpit opened later starts from them.
    func applySettings(_ value: SettingsApplication) {
        appliedSettings=value
        owner.appearance=owner.cockpitAppearance(value)
        owner.coordinator?.updateAppearance(owner.appearance)
    }
    var isDetached: Bool { owner.shell.detached }
    var attachmentHintAnchor: CockpitAttachmentHintAnchor? { wantsVisible ? owner.coordinator?.attachmentHintAnchor : nil }
    func show() { show(fromStatusItem: false) }
    func show(fromStatusItem: Bool) {
        // D88: only the menu bar icon grows the cockpit out of itself; the ignition keeps its own entrance.
        entrance = fromStatusItem ? .growFromIcon : .fade
        wantsVisible=true
        retryTask?.cancel(); retryTask=nil; attempt += 1
        noticeTask?.cancel(); noticeTask=nil; rebuilding=false; rebuilds=0; retriedOpen=false; noticePath=""; failureClosesPage=false // a new click starts its own grace period
        guard showTask == nil else { return }
        // G3-42: open stages in the timing log are measured from here, before the settings hop.
        CockpitTimingLog.markClick()
        composition.dock.prepareForCockpit()
        showTask=Task { @MainActor [weak self] in
            guard let self else { return }
            let snapshot=await owner.settingsStore.snapshot()
            guard !Task.isCancelled else { return }
            guard wantsVisible else { showTask = nil; return }
            owner.adoptAppearance(snapshot,applied:appliedSettings)
            // A prewarmed page was made before this open; it shows with the settings of this moment.
            if owner.coordinator?.presented == false { owner.coordinator?.updateAppearance(owner.appearance) }
            owner.coordinator?.onIntent = { [weak self] intent in self?.handle(intent) }
            activate()
            owner.shell.nextEntrance = entrance
            owner.coordinator?.open()
            owner.shell.nextEntrance = .fade
            showTask = nil
        }
    }
    var isShowing: Bool { wantsVisible }
    var onShowingChanged: (() -> Void)?
    /// The page closes through its normal transition; an open still waiting for its page is just cancelled.
    func requestClose() {
        noticeTask?.cancel(); noticeTask=nil; retryTask?.cancel(); retryTask=nil
        if pageOpened { owner.coordinator?.requestClose() } else { hide() }
    }
    func render() { fallback?.render() } // typed event delivery itself owns WK display.
    func hide() {
        wantsVisible = false
        noticeTask?.cancel(); noticeTask=nil; retryTask?.cancel(); retryTask=nil
        onShowingChanged?()
        showTask?.cancel()
        showTask = nil
        fieldPanel?.close()
        owner.coordinator?.close()
        pageOpened = false
        fallback?.hide()
    }
    /// G3-66: a failure is only worth a notice when it lasts. The log line is written for every failure, with the
    /// path, the time since launch and the engine's state. An open that finds no engine context yet is completed
    /// by the first context (the coordinator keeps it pending); a failed page is rebuilt and reopened while the
    /// window stays up. A later successful open drops the notice; a failure that outlasts the grace period, or
    /// that keeps repeating, is announced.
    private func unavailable(path:String,history:Bool=false) {
        // The open already being waited on reports again (a late open step): that says nothing new and must not
        // undo a recovery already seen. Decided before any state changes, so it cannot race the open event.
        // The coordinator closes the page right after a feature failure; that close is the failure's, not the user's.
        if wantsVisible, path == CockpitUnavailableReason.featureFailure.path { failureClosesPage = true }
        if noticeTask != nil, !history, !path.hasPrefix("page.") {
            // macrevc-887-2: a failure that follows a pending open (open.noDelivery, then the bundle error when the first
            // context delivers it) is the more meaningful cause. It is named in the log and in the notice, without
            // restarting the grace period. A bundle problem is never replaced by a milder cause.
            if wantsVisible, path != noticePath, !CockpitUnavailableNotice.isBundleProblem(path: noticePath) {
                CockpitFailureLog.record("unavailable path=\(path) wantsVisible=\(wantsVisible) foreground=\(isForeground()) pageOpened=\(pageOpened) "
                    + "sinceLaunchMs=\(CockpitFailureLog.msSinceLaunch) engine=[\(owner.coordinator?.diagnosticState ?? "no-coordinator")] rebuilds=\(rebuilds) during-grace=true")
                noticePath = path
            }
            // G3-95: a pending open that started this grace period spent no retry; a retryable failure that follows it
            // (a context the bridge could not use, a page that could not be made) gets the one quiet retry.
            scheduleOpenRetry(path:path)
            return
        }
        lastEventWasOpen = false
        let initiatedInForeground=isForeground()
        // A failure in the background or after a close shows nothing, so the log is all there is.
        CockpitFailureLog.record("unavailable path=\(path) wantsVisible=\(wantsVisible) foreground=\(initiatedInForeground) pageOpened=\(pageOpened) "
            + "sinceLaunchMs=\(CockpitFailureLog.msSinceLaunch) engine=[\(owner.coordinator?.diagnosticState ?? "no-coordinator")] rebuilds=\(rebuilds)")
        guard wantsVisible else { return }
        if !history, !CockpitUnavailableNotice.isBundleProblem(path:noticePath) { noticePath=path } // a bundle cause is never replaced by a milder one; the cause that starts the grace period; a later non-page cause replaces it above
        if history { presentNotice(history:true,initiatedInForeground:initiatedInForeground); return }
        if path.hasPrefix("page.") {
            rebuilds += 1
            if rebuilds > Self.maxRebuilds { noticeTask?.cancel(); noticeTask=nil; presentNotice(history:false,initiatedInForeground:initiatedInForeground); return }
            rebuilding=true // the coordinator's close that follows must not retire the presentation
        }
        guard noticeTask == nil else { return }
        scheduleOpenRetry(path:path)
        let epoch=openCount
        noticeTask=Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for:self.noticeGrace)
            guard !Task.isCancelled else { return }
            self.noticeTask=nil; self.retryTask?.cancel(); self.retryTask=nil; self.rebuilding=false
            guard !(self.openCount != epoch && self.lastEventWasOpen) else { return } // a page opened and nothing failed after it: recovered
            self.presentNotice(history:false,initiatedInForeground:initiatedInForeground)
        }
    }
    /// G3-95: a failed open that nothing else retries (no client yet, a context the bridge could not use, a page that
    /// could not be made) gets one more open after a short wait, inside the grace period. A bundle problem will not
    /// change in 700 ms, and a no-context open is already completed by the first context.
    private func scheduleOpenRetry(path:String) {
        guard !retriedOpen,path.hasPrefix("open.") || path.hasPrefix("adopt."),path != CockpitUnavailableReason.noDelivery.path,
              !CockpitUnavailableNotice.isBundleProblem(path:path) else { return }
        retriedOpen=true
        let scheduledFor=attempt
        retryTask=Task { @MainActor [weak self] in
            try? await Task.sleep(for:Self.openRetryDelay)
            guard !Task.isCancelled,let self,self.attempt == scheduledFor,self.wantsVisible,self.noticeTask != nil,!self.pageOpened else { return }
            self.retryTask=nil
            CockpitFailureLog.record("open-retry after=\(path)")
            self.owner.coordinator?.open()
        }
    }
    private func presentNotice(history:Bool,initiatedInForeground:Bool) {
        let bundleProblem=CockpitUnavailableNotice.isBundleProblem(path:noticePath)
        CockpitFailureLog.record("notice-shown cause=\(history ? "history" : noticePath.isEmpty ? "unknown" : noticePath) bundleProblem=\(bundleProblem) foreground=\(initiatedInForeground) rebuilds=\(rebuilds) retriedOpen=\(retriedOpen)")
        let notice=CockpitUnavailableNotice(history:history,bundleProblem:bundleProblem)
        Task { @MainActor [weak self] in
            guard let self,initiatedInForeground else { return }
            if let requestNotice { requestNotice(notice); return }
            let english=await owner.settingsStore.snapshot().preferences.language == .english
            let alert=NSAlert();alert.messageText=english ? "Cockpit unavailable" : "驾驶舱暂不可用"
            alert.informativeText=history
                ? (english ? "History is unavailable in this candidate. Open Settings to check connected tools." : "当前候选版尚无历史窗口，请打开设置查看已连接工具。")
                : notice.bundleProblem
                ? (english ? "Check tool access in Settings, or reinstall this candidate if bundled content is missing." : "请在设置中检查工具授权；若缺少随附内容，请重新安装候选版。")
                : (english ? "The cockpit could not open just now. Try again in a moment, or check tool access in Settings." : "驾驶舱刚才没能打开。请稍后再试，或在设置中检查工具授权。")
            for action in notice.actions {
                switch action {
                case .settings:alert.addButton(withTitle:english ? "Open Settings" : "打开设置")
                case .dockReadings:alert.addButton(withTitle:english ? "Readings" : "读数")
                case .cancel:alert.addButton(withTitle:english ? "Cancel" : "取消")
                }
            }
            switch alert.runModal() {
            case .alertFirstButtonReturn:owner.settings?()
            case .alertSecondButtonReturn:
                if fallback == nil { fallback=EngineRowsConsole(composition:composition) };fallback?.show()
            default:
                // Cancel also cancels the open still waiting for the engine context, so the cockpit cannot appear uninvited later.
                hide()
            }
        }
    }
}

/// Settings "Cockpit size" (CKP-SHELL-07) to the cockpit window's size: the same five choices.
extension CockpitSize {
    init(_ value: SettingsCockpitSize) {
        switch value {
        case .automatic: self = .automatic
        case .percent80: self = .percent80
        case .percent85: self = .percent85
        case .percent90: self = .percent90
        case .percent100: self = .percent100
        }
    }
}
