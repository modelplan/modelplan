// SPDX-License-Identifier: MIT
import AppKit
import OSLog
import ModelPlanEngineClient
import ModelPlanDock
import ModelPlanEngineStore
import ModelPlanSettings
import ModelPlanShell

/// The rows-backed normal Dock/menu lifecycle. Legacy probe entry remains separate.
@MainActor public final class EngineDockMenuApplication: NSObject, NSApplicationDelegate, NSMenuDelegate {
    public let composition: EngineDockMenuComposition
    private let scopeBinding: EngineScopeConsentBinding
    public var scopeConsentEntry: ScopeConsentEntry { scopeBinding.entry }
    private let settings: SettingsApplicationCoordinator
    private var interactionBinding: EngineDockInteractionBinding?
    public let foundationStore: SettingsStore
    private let contextSource: EngineSettingsContext
    private let appBundleURL: URL
    private var lastAboutConnectionReady = false
    private var status: NSStatusItem?
    private(set) var liveStatusMenu: NSMenu?
    private var terminating = false
    private var accessibilityObserver: NSObjectProtocol?
    #if MODELPLAN_U6_DRIVE
    private var driveGuard: U6DriveGuard?
    #endif
    private let makeSettingsSurface: (@MainActor (SettingsEditor) -> any SettingsWindowSurface)?
    private let makeConsole: (@MainActor (EngineDockMenuComposition) -> any EngineRowsConsoleSurface)?
    private var console: (any EngineRowsConsoleSurface)?
    private var firstRunFlow: CommunityConnectionFlow?
    var firstRunFlowBuilder: (@MainActor () throws -> CommunityConnectionFlow)?
    var reportFirstRunWiringFailure: @MainActor (String) -> Void = { assertionFailure($0) }
    /// Injection point for the OS login service; the normal entry supplies the live adapter.
    public var loginServiceAdapter: CommunityLoginServiceAdapter?
    public var notificationAuthorizationService: (any SettingsNotificationAuthorizationServing)?
    private let notificationConsumer = SettingsNotificationConsumer()
    /// The default uses the native first-run window. Synthetic composition tests
    /// may supply an in-memory surface before preparation; no system service runs.
    public var makeFirstRunSurface: (@MainActor (SettingsEditor) -> any SettingsWindowSurface)?
    public var makeFirstRunSurfaceWithConsent: (@MainActor (SettingsEditor, ScopeConsentEntry) -> any SettingsWindowSurface)?
    private let activateSettings: @MainActor () -> Void
    public private(set) lazy var settingsHost = SettingsWindowHost(application: settings, canPresent: { [weak self] in self?.terminating == false }, activate: activateSettings, scopeConsentEntry: scopeConsentEntry, makeSurface: makeSettingsSurface)
    public init(configuration: EngineClientConfiguration, settingsStore: SettingsStore,
                createsNativePanels: Bool = true, bundleURL: URL = Bundle.main.bundleURL,
                makeClient: (@MainActor (EngineClientConfiguration, ModelPlanEngineStore.EngineStore) -> any EngineClient)? = nil,
                makeSettingsSurface: (@MainActor (SettingsEditor) -> any SettingsWindowSurface)? = nil,
                makeConsole: (@MainActor (EngineDockMenuComposition) -> any EngineRowsConsoleSurface)? = nil,
                activateSettings: @escaping @MainActor () -> Void = { NSApplication.shared.activate() }) {
        let composition = EngineDockMenuComposition(configuration: configuration, createsNativePanels: createsNativePanels, makeClient: makeClient)
        self.composition = composition
        self.scopeBinding = EngineScopeConsentBinding(composition: composition)
        self.foundationStore = settingsStore
        self.appBundleURL = bundleURL
        self.makeSettingsSurface = makeSettingsSurface; self.makeConsole = makeConsole; self.activateSettings = activateSettings
        let contextSource = EngineSettingsContext(bundle: bundleURL, executable: configuration.executableURL)
        self.contextSource = contextSource
        var environment = SettingsEnvironment(); environment.v1NormalEntry = true
        settings = SettingsApplicationCoordinator(store: settingsStore, context: contextSource.make(engineReady: false), environment: environment) { composition.applySettings($0) }
        super.init()
        CommunityPlacementBinding.install(on: composition.dock, application: settings)
        // M0's host opts in only when the native interaction port exists.
        if let host = (composition.dock as AnyObject) as? any DockInteractionHostPort {
            let clock = { ProcessInfo.processInfo.systemUptime }
            interactionBinding = EngineDockInteractionBinding(host: host, application: settings,
                scheduler: DockCommonModeScheduler(clock: clock), clock: clock)
        }
        composition.settingsDidChange = { [weak self] value in
            guard let self, !self.terminating else { return }
            if self.liveStatusMenu != nil { self.renderMenu() }
            self.console?.applySettings(value)
        }
        composition.menuDidChange = { [weak self] in
            self?.updateSettingsContext(); self?.renderMenu(); self?.console?.render()
            #if MODELPLAN_U6_DRIVE
            if self?.composition.provider.dockContent.status == .cleared { self?.driveGuard?.recordClear() }
            #endif
        }
        composition.dock.showSettings = settingsHost.action
        composition.dock.showConsole = { [weak self] in self?.showConsole() }
    }
    private func updateSettingsContext() {
        let ready: Bool
        if case .ready = composition.store.snapshot.connection { ready = true } else { ready = false }
        guard ready != lastAboutConnectionReady else { return }
        lastAboutConnectionReady = ready
        // Preserve Dock-owned catalogue, display and placement facts when the
        // engine connection changes; only About's CLI readiness comes from here.
        var context = settings.editor.context
        context.about.cliState = contextSource.make(engineReady: ready).about.cliState
        settings.update(context: context)
    }
    /// Core preferences share the exact foundation store used by Settings.
    public func coreSnapshot() async -> FoundationCorePreferences? { await foundationStore.coreSnapshot() }
    @discardableResult public func updateCore(_ value: FoundationCorePreferences, expectedRevision: UInt64? = nil) async throws -> SettingsSnapshot {
        try await foundationStore.updateCore(value, expectedRevision: expectedRevision)
    }
    var currentSettingsContext: SettingsPageContext { settings.editor.context }
    public func presentSettings() async { await settingsHost.present() }
    public func showConsole() {
        guard !terminating else { return }
        if console == nil { console = makeConsole?(composition) ?? EngineRowsConsole(composition: composition) }
        if let value = composition.latestSettings { console?.applySettings(value) }
        console?.show()
    }
    /// OS accessibility changes are presentation facts, never saved user choices.
    func updateSystemAccessibility(_ observed: SettingsEnvironment) {
        guard !terminating else { return }
        var current = settings.editor.environment
        current.reduceMotion = observed.reduceMotion
        current.reduceTransparency = observed.reduceTransparency
        current.increaseContrast = observed.increaseContrast
        current.macOSMajor = observed.macOSMajor
        settings.update(environment: current)
    }
    public func prepare() async {
        if loginServiceAdapter == nil, let bundle = Bundle(url: appBundleURL),
           bundle.bundleURL.standardizedFileURL == appBundleURL.standardizedFileURL,
           bundle.bundleURL.standardizedFileURL == Bundle.main.bundleURL.standardizedFileURL {
            loginServiceAdapter = CommunityLoginServiceAdapter(item: PulseLoginItem(bundle: bundle))
        }
        if notificationAuthorizationService == nil, let bundle = Bundle(url: appBundleURL),
           bundle.bundleURL.standardizedFileURL == appBundleURL.standardizedFileURL,
           bundle.bundleURL.standardizedFileURL == Bundle.main.bundleURL.standardizedFileURL,
           bundle.bundleIdentifier != nil, bundle.bundleURL.pathExtension == "app" {
            notificationAuthorizationService = SystemNotificationAuthorizationService()
        }
        let observedAuthorization = await notificationAuthorizationService?.authorization() ?? .unavailable
        guard !terminating else { return }
        notificationConsumer.observeAuthorization(observedAuthorization)
        var context = settings.editor.context
        context.capabilities.login = loginServiceAdapter?.observedState ?? .unavailable
        context.notificationAuthorization = observedAuthorization
        if context.capabilities.login != .unavailable { context.unavailableControls.removeValue(forKey: .login) }
        context.updateNotificationConsentAvailability(serviceAvailable: notificationAuthorizationService != nil && observedAuthorization != .unavailable)
        for key in [SettingKey.websiteLink, .methodologyLink, .privacyLink, .repositoryLink, .feedback] {
            context.unavailableControls.removeValue(forKey: key)
        }
        settings.update(context: context)
        settings.editor.onHostRequest = { [weak self] request in self?.dispatchHostRequest(request) }
        if firstRunFlow == nil {
            do { firstRunFlow = try firstRunFlowBuilder?() ?? CommunityConnectionFlow(application: settings,
                canPresent: { [weak self] in self?.terminating == false },
                showSettings: { [weak self] pane in await self?.settingsHost.present(paneID: pane) },
                activate: activateSettings, scopeConsentEntry: scopeConsentEntry,
                makeFirstRun: makeFirstRunSurface, makeFirstRunWithConsent: makeFirstRunSurfaceWithConsent)
            } catch {
                Logger(subsystem: "org.modelplan.community", category: "first-run").error("First-run presentation wiring failed")
                reportFirstRunWiringFailure("First-run presentation wiring failed")
            }
        }
        updateSystemAccessibility(SettingsWindowController.systemEnvironment())
        await settings.reload()
        guard !terminating else { return }
        interactionBinding?.install()
    }
    func allowDockPresentation() {
        guard !terminating else { return }
        composition.dock.setPresentationAllowed(true)
        interactionBinding?.start()
    }
    private func dispatchHostRequest(_ request: SettingsHostRequest) {
        guard !terminating, let current = settings.editor.snapshot, request.revision == current.revision else { return }
        if let adapter = loginServiceAdapter {
            let result = adapter.handle(request, current: current, mayChangeLoginItem: true)
            if result != .unhandled {
                var context = settings.editor.context
                context.capabilities.login = adapter.observedState
                settings.update(context: context)
            }
        }
        switch request.intent {
        case .notificationConsentChanged:
            guard settings.editor.context.unavailableControls[.notificationConsent] == nil else { return }
            let effect = notificationConsumer.committedConsent(request, snapshot: current)
            if case .requestAuthorization(let token) = effect, let service = notificationAuthorizationService {
                Task { [weak self] in
                    let observed = await service.requestAuthorization()
                    guard let self, !self.terminating else { return }
                    self.notificationConsumer.receivedAuthorization(observed, request: token)
                    var context = self.settings.editor.context
                    context.notificationAuthorization = self.notificationConsumer.policy.authorization
                    self.settings.update(context: context)
                }
            }
        case .openPublicLink(let link): NSWorkspace.shared.open(link.url)
        case .firstRunCompleted(let effects, _):
            for effect in effects {
                switch effect {
                case .revealDock: composition.dock.setPresentationAllowed(true)
                case .returnToSettings: Task { [weak self] in await self?.settingsHost.present() }
                case .openCockpit: showConsole()
                case .closeFirstRunPopup, .latchOptionHelp: break
                }
            }
        default:
            // Shortcut, notification delivery and help actions remain explicitly deferred
            // in this draft until their owners supply production consumers.
            break
        }
    }
    /// The same restore used by the real launch; it never grants access itself.
    public func restoreFirstRunIfNeeded() async { await firstRunFlow?.restoreFirstRunIfNeeded() }
    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.appearance = NSAppearance(named: .darkAqua)
        if accessibilityObserver == nil {
            accessibilityObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.updateSystemAccessibility(SettingsWindowController.systemEnvironment())
                }
            }
        }
        #if MODELPLAN_U6_DRIVE
        do { driveGuard = try U6DriveGuard.attach(ownsMenu: { [weak self] menu in
            guard let self else { return false }; return menu.delegate === self || menu.delegate === self.composition.dock
        }, hasPrivateContent: { [weak self] in
            guard let value = self?.composition.provider.dockContent else { return false }
            return !value.dockRows.isEmpty || !value.menuRows.isEmpty
        }) } catch { NSApplication.shared.terminate(nil); return }
        #endif
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        Task {
            await prepare(); guard !terminating else { return }
            allowDockPresentation(); renderMenu(); await composition.start()
            guard !terminating else { return }; await restoreFirstRunIfNeeded()
        }
    }
    private func renderMenu() {
        let language = composition.latestSettings?.effective.language ?? .english
        let menu = liveStatusMenu ?? NSMenu()
        if composition.provider.dockContent.status == .cleared { LivePrivateMenus.scrub(menu) }
        menu.removeAllItems()
        let reading = NSMenuItem(title: composition.menuPresentation.detail, action: nil, keyEquivalent: "")
        reading.isEnabled = false; menu.addItem(reading)
        let refresh = menu.addItem(withTitle: EngineRowsText.refresh.value(language), action: #selector(refreshRows), keyEquivalent: "")
        refresh.target = self
        menu.addItem(.separator())
        menu.addItem(settingsHost.menuItem(title: EngineRowsText.settings.value(language)))
        let consoleItem = menu.addItem(withTitle: EngineRowsText.cockpitMenu.value(language), action: #selector(showConsoleMenu), keyEquivalent: "")
        consoleItem.target = self
        menu.addItem(withTitle: EngineRowsText.quit.value(language), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.delegate = self; liveStatusMenu = menu; status?.menu = menu
        let image = CommunityMenuBarResources.templateImage()
        image?.isTemplate = true
        status?.button?.image = image; status?.button?.contentTintColor = nil
        status?.button?.title = composition.menuPresentation.title
        status?.button?.toolTip = composition.menuPresentation.detail
        #if MODELPLAN_U6_DRIVE
        if let button = status?.button { driveGuard?.recordStatusButtonFrame(button) }
        #endif
    }
    public func menuWillOpen(_ menu: NSMenu) { menu.items.first?.title = composition.menuPresentation.detail }
    @objc private func showConsoleMenu() { showConsole() }
    @objc private func refreshRows() { Task { await composition.refresh() } }
    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !terminating else { return .terminateLater }
        terminating = true; settings.editor.onHostRequest = nil
        if let accessibilityObserver { NSWorkspace.shared.notificationCenter.removeObserver(accessibilityObserver); self.accessibilityObserver = nil }
        interactionBinding?.stop(); firstRunFlow?.dispose(); settingsHost.suspend(); scopeConsentEntry.suspend(); console?.hide()
        Task { await composition.stop(); sender.reply(toApplicationShouldTerminate: true) }
        return .terminateLater
    }
}
