// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanCore
import ModelPlanShell
import ModelPlanEngineClient
import ModelPlanDock
import ModelPlanEngineStore
import ModelPlanSettings

/// The rows-backed normal Dock/menu lifecycle. Legacy probe entry remains separate.
@MainActor public final class EngineDockMenuApplication: NSObject, NSApplicationDelegate, NSMenuDelegate {
    public let composition: EngineDockMenuComposition
    private let scopeBinding: EngineScopeConsentBinding
    public var scopeConsentEntry: ScopeConsentEntry { scopeBinding.entry }
    private let settings: SettingsApplicationCoordinator
    private var interactionBinding: EngineDockInteractionBinding?
    public let foundationStore: SettingsStore
    private let contextSource: EngineSettingsContext
    private var lastAboutConnectionReady = false
    private var status: NSStatusItem?
    private(set) var liveStatusMenu: NSMenu?
    private var statusMenuComponent: DockStatusMenu?
    private var terminating = false
    private var lifecycleController: EngineLifecycleController?
    private var activityPaused = false
    private(set) var lifecyclePaused = false
    private var accessibilityObserver: NSObjectProtocol?
    #if MODELPLAN_U6_DRIVE
    private var driveGuard: U6DriveGuard?
    #endif
    private let makeSettingsSurface: (@MainActor (SettingsEditor) -> any SettingsWindowSurface)?
    private let makeConsole: (@MainActor (EngineDockMenuComposition) -> any EngineRowsConsoleSurface)?
    private var console: (any EngineRowsConsoleSurface)?
    private let activateSettings: @MainActor () -> Void
    public private(set) lazy var settingsHost = SettingsWindowHost(application: settings, canPresent: { [weak self] in self?.terminating == false && self?.lifecyclePaused == false }, activate: activateSettings, scopeConsentEntry: scopeConsentEntry, makeSurface: makeSettingsSurface)
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
        guard !terminating, !lifecyclePaused else { return }
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
    func startLifecycle(workspace: NotificationCenter = NSWorkspace.shared.notificationCenter,
                        local: NotificationCenter = .default,
                        lockEvents: NotificationCenter = DistributedNotificationCenter.default(),
                        displayIDs: @escaping @MainActor () -> Set<UInt32> = { SystemEvents.currentDisplayIDs() },
                        onConsole: @escaping @MainActor () -> Bool? = { SystemEvents.currentConsoleState() },
                        displaysAsleep: @escaping @MainActor (Set<UInt32>) -> Bool = { SystemEvents.allDisplaysAsleep($0) }) {
        guard !terminating, lifecycleController == nil else { return }
        lifecyclePaused = true
        let controller = EngineLifecycleController(composition: composition, workspace: workspace, local: local,
            lockEvents: lockEvents, displayIDs: displayIDs, onConsole: onConsole, displaysAsleep: displaysAsleep,
            onPause: { [weak self] in self?.withdrawForLifecycle() },
            onReady: { [weak self] in
                guard let self, !self.terminating else { return }
                self.lifecyclePaused = false; self.composition.dock.resumeFromLifecycle()
                self.allowDockPresentation(); self.renderMenu()
            }, onGateOpen: { [weak self] in self?.renderMenu() })
        lifecycleController = controller
        controller.setActivityPaused(activityPaused)
        withdrawForLifecycle(); controller.start()
    }
    /// M4's activity observer sets an independent pause reason; it never clears OS reasons.
    public func setActivityPaused(_ paused: Bool) {
        activityPaused = paused; lifecycleController?.setActivityPaused(paused)
    }
    func stopLifecycle() async {
        guard let controller = lifecycleController else { return }
        await controller.stop(); lifecycleController = nil
    }
    private func withdrawForLifecycle() {
        guard !terminating else { return }
        lifecyclePaused = true
        // Scrub before Dock suspension: its callbacks may synchronously rebuild the status menu.
        if let liveStatusMenu { LivePrivateMenus.scrub(liveStatusMenu) }
        composition.dock.pauseForLifecycle(); console?.hide(); settingsHost.suspend()
        renderMenu()
    }
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
            guard let self else { return false }; return menu === self.liveStatusMenu || self.composition.dock.ownsDockMenu(menu)
        }, hasPrivateContent: { [weak self] in
            guard let value = self?.composition.provider.dockContent else { return false }
            return !value.dockRows.isEmpty || !value.menuRows.isEmpty
        }) } catch { NSApplication.shared.terminate(nil); return }
        #endif
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        Task { await prepare(); guard !terminating else { return }; startLifecycle(); renderMenu() }
    }
    private func renderMenu() {
        let language = composition.latestSettings?.effective.language ?? .english
        let component: DockStatusMenu
        if let current = statusMenuComponent { component = current }
        else {
            component = DockStatusMenu(labels: [:], handlers: [:])
            component.onMenuActuallyOpen = { [weak self] open in
                guard open, let self, let menu = self.liveStatusMenu else { return }
                self.menuWillOpen(menu)
            }
            statusMenuComponent = component
        }
        let menu = component.menu
        let canRetry = lifecyclePaused && (lifecycleController?.canRetry ?? false)
        let detail = lifecyclePaused ? (canRetry ? EngineRowsText.waitingForFresh : EngineRowsText.paused).value(language) : composition.menuPresentation.detail
        if composition.provider.dockContent.status == .cleared { LivePrivateMenus.scrub(menu) }
        component.replace(with: [
            .init(title: detail),
            .init(title: EngineRowsText.refresh.value(language), target: (!lifecyclePaused || canRetry) ? self : nil,
                  selector: (!lifecyclePaused || canRetry) ? #selector(refreshRows) : nil),
            .init(title: nil),
            .init(title: EngineRowsText.settings.value(language), keyEquivalent: ",", action: !lifecyclePaused ? { [weak self] in self?.settingsHost.action() } : nil),
            .init(title: EngineRowsText.cockpitMenu.value(language), action: !lifecyclePaused ? { [weak self] in self?.showConsoleMenu() } : nil),
            .init(title: EngineRowsText.quit.value(language), keyEquivalent: "q", action: { NSApplication.shared.terminate(nil) }),
        ])
        liveStatusMenu = menu
        if let status { component.attach(to: status) }
        let image = CommunityMenuBarResources.templateImage()
        image?.isTemplate = true
        status?.button?.image = image; status?.button?.contentTintColor = nil
        status?.button?.title = composition.menuPresentation.title
        status?.button?.toolTip = detail
        #if MODELPLAN_U6_DRIVE
        if let button = status?.button { driveGuard?.recordStatusButtonFrame(button) }
        #endif
    }
    public func menuWillOpen(_ menu: NSMenu) {
        let language = composition.latestSettings?.effective.language ?? .english
        let canRetry = lifecyclePaused && (lifecycleController?.canRetry ?? false)
        menu.items.first?.title = lifecyclePaused ? (canRetry ? EngineRowsText.waitingForFresh : EngineRowsText.paused).value(language) : composition.menuPresentation.detail
    }
    @objc private func showConsoleMenu() { showConsole() }
    @objc private func refreshRows() {
        if lifecyclePaused { lifecycleController?.retryPending(); return }
        Task { await composition.refresh() }
    }
    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !terminating else { return .terminateLater }
        terminating = true
        if let accessibilityObserver { NSWorkspace.shared.notificationCenter.removeObserver(accessibilityObserver); self.accessibilityObserver = nil }
        interactionBinding?.stop(); settingsHost.suspend(); scopeConsentEntry.suspend(); console?.hide()
        statusMenuComponent?.dispose(); statusMenuComponent = nil; liveStatusMenu = nil
        Task {
            if lifecycleController != nil { await stopLifecycle(); composition.dock.close() }
            else { await composition.stop() }
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
