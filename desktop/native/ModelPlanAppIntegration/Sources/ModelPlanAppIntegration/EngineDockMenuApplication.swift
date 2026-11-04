// SPDX-License-Identifier: MIT
import AppKit
import OSLog
import ModelPlanCore
import ModelPlanShell
import ModelPlanEngineClient
import ModelPlanDock
import ModelPlanEngineStore
import ModelPlanSettings
#if MODELPLAN_U6_DRIVE
import ModelPlanMenuVerification
#endif

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
    private var statusMenuComponent: DockStatusMenu?
    let noticeIndicator = DockNoticeIndicatorView(frame: .zero)
    public let cockpitEntryEnabled: Bool
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
    public private(set) lazy var settingsHost = SettingsWindowHost(application: settings, canPresent: { [weak self] in self?.terminating == false && self?.lifecyclePaused == false }, activate: activateSettings, scopeConsentEntry: scopeConsentEntry, makeSurface: makeSettingsSurface)
    public init(configuration: EngineClientConfiguration, settingsStore: SettingsStore,
                createsNativePanels: Bool = true, bundleURL: URL = Bundle.main.bundleURL,
                cockpitEntryEnabled: Bool? = nil,
                makeClient: (@MainActor (EngineClientConfiguration, ModelPlanEngineStore.EngineStore) -> any EngineClient)? = nil,
                makeSettingsSurface: (@MainActor (SettingsEditor) -> any SettingsWindowSurface)? = nil,
                makeConsole: (@MainActor (EngineDockMenuComposition) -> any EngineRowsConsoleSurface)? = nil,
                activateSettings: @escaping @MainActor () -> Void = { NSApplication.shared.activate() }) {
        let composition = EngineDockMenuComposition(configuration: configuration, createsNativePanels: createsNativePanels, makeClient: makeClient)
        self.composition = composition
        self.scopeBinding = EngineScopeConsentBinding(composition: composition)
        self.foundationStore = settingsStore
        self.appBundleURL = bundleURL
        self.cockpitEntryEnabled = cockpitEntryEnabled ?? (Bundle(url: bundleURL)?.object(forInfoDictionaryKey: "ModelPlanCockpitEntryEnabled") as? Bool ?? false)
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
        let application=settings
        composition.dock.requestHideDock = { [weak application] in
            Task { _ = try? await application?.editor.commit(SettingsB21Edit.showDock(false)) }
        }
        #if MODELPLAN_U6_DRIVE
        composition.provider.verificationWillClear = { [weak self] invalidation in
            self?.driveGuard?.recordClearInitiated(invalidation)
        }
        #endif
        composition.menuDidChange = { [weak self] in
            self?.updateSettingsContext(); self?.renderMenu(); self?.console?.render()
            #if MODELPLAN_U6_DRIVE
            if self?.composition.provider.dockContent.status == .cleared { self?.driveGuard?.recordClear() }
            #endif
        }
        composition.dock.cockpitEntryEnabled = self.cockpitEntryEnabled
        composition.dock.menuNoticeDidChange = { [weak self] notice, first in self?.applyMenuNotice(notice, first: first) }
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
    var cockpitAnchor: CGRect? {
        guard let button = status?.button, let window = button.window else { return nil }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }
    public func showConsole() {
        guard cockpitEntryEnabled, !terminating, !lifecyclePaused else { return }
        composition.dock.acknowledgeCockpitOpening()
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
                canPresent: { [weak self] in self?.terminating == false && self?.lifecyclePaused == false },
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
        renderMenu()
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
                Task { [weak self] in await self?.restoreFirstRunIfNeeded() }
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
        composition.dock.pauseForLifecycle(); console?.hide(); settingsHost.suspend(); firstRunFlow?.suspend()
        renderMenu()
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
            guard let self else { return false }; return menu === self.liveStatusMenu || self.composition.dock.ownsDockMenu(menu)
        }, hasPrivateContent: { [weak self] in
            guard let value = self?.composition.provider.dockContent else { return false }
            return !value.dockRows.isEmpty || !value.menuRows.isEmpty
        }, privateTitle: { [weak self] in
            self?.composition.provider.dockContent.menuRows.first(where: { !$0.accounts.isEmpty })?.name.en
        },
           dockHost: composition.dock) } catch { NSApplication.shared.terminate(nil); return }
        #endif
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        status?.autosaveName = "ModelPlanCommunity.StatusItem"
        status?.isVisible = true
        #if MODELPLAN_U6_DRIVE
        driveGuard?.observeStatusMenu(ownsStatusMenu: { [weak self] menu in
            guard let self else { return false }; return menu === self.status?.menu
        }, currentStatusMenu: { [weak self] in self?.liveStatusMenu },
           actionForItem: { item in item.action == #selector(EngineDockMenuApplication.refreshRows) ? .refresh : nil })
        #endif
        Task { await prepare(); guard !terminating else { return }; startLifecycle(); renderMenu() }
    }
    func renderMenu() {
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
        let english = language == .english
        func label(_ en: String, _ zh: String) -> String { english ? en : zh }
        let available = !lifecyclePaused
        component.replace(with: [
            .init(title: detail),
            .init(title: label("Refresh", "刷新"), target: (available || canRetry) ? self : nil, selector: (available || canRetry) ? #selector(refreshRows) : nil),
            .init(title: nil),
            .init(title: cockpitEntryEnabled ? label("Open Cockpit", "打开驾驶舱") : EngineRowsText.comingSoon.value(language), action: available && cockpitEntryEnabled ? { [weak self] in self?.showConsoleMenu() } : nil),
            .init(title: label("Website", "网站"), action: { NSWorkspace.shared.open(SettingsPublicLink.website.url) }),
            .init(title: label("Methodology", "方法论"), action: { NSWorkspace.shared.open(SettingsPublicLink.methodology.url) }),
            .init(title: label("Privacy", "隐私"), action: { NSWorkspace.shared.open(SettingsPublicLink.privacy.url) }),
            .init(title: label("Check for updates", "检查更新"), action: settings.editor.context.capabilities.updateServiceAvailable && settings.editor.onHostRequest != nil ? { [weak self] in self?.checkForUpdates() } : nil),
            .init(title: nil),
            .init(title: label("Help…", "说明…")),
            .init(title: label("Settings…", "设置…"), action: available ? { [weak self] in self?.settingsHost.action() } : nil),
            .init(title: label("About", "关于"), action: available ? { [weak self] in self?.showAbout() } : nil),
            .init(title: label("Quit", "退出"), keyEquivalent: "q", target: NSApplication.shared, selector: #selector(NSApplication.terminate(_:))),
        ])
        liveStatusMenu = menu
        if let status { component.attach(to: status) }
        if let button = status?.button {
            Self.configureStatusButton(button,image:CommunityMenuBarResources.templateImage(),barThickness:NSStatusBar.system.thickness); button.contentTintColor = nil
            noticeIndicator.frame = NSRect(x: max(0, button.bounds.width - 7), y: max(0, button.bounds.height - 7), width: 7, height: 7)
            noticeIndicator.autoresizingMask = [.minXMargin, .minYMargin]
            if noticeIndicator.superview !== button { button.addSubview(noticeIndicator) }
        }
        status?.button?.title = composition.menuPresentation.title
        status?.button?.toolTip = detail
        #if MODELPLAN_U6_DRIVE
        if let button = status?.button { driveGuard?.observeStatusButton(button) }
        #endif
    }
    private func applyMenuNotice(_ notice: DockNotice?, first: Bool) {
        let pulse: CABasicAnimation? = first ? CABasicAnimation(keyPath: "opacity") : nil
        pulse?.fromValue = 0.25; pulse?.toValue = 1; pulse?.duration = 0.35
        noticeIndicator.apply(notice, firstAppearanceAnimation: pulse, reducedMotion: composition.latestSettings?.effective.reduceMotion ?? true)
    }
    static func configureStatusButton(_ button:NSButton,image:NSImage?,barThickness:CGFloat) {
        let sized=image?.copy() as? NSImage
        let side=min(16,max(0,barThickness.isFinite ? barThickness : 0))
        sized?.size=NSSize(width:side,height:side);sized?.isTemplate=true
        button.image=sized;button.imageScaling = .scaleProportionallyDown;button.imagePosition = .imageLeading
    }
    public func menuWillOpen(_ menu: NSMenu) {
        let language = composition.latestSettings?.effective.language ?? .english
        let canRetry = lifecyclePaused && (lifecycleController?.canRetry ?? false)
        menu.items.first?.title = lifecyclePaused ? (canRetry ? EngineRowsText.waitingForFresh : EngineRowsText.paused).value(language) : composition.menuPresentation.detail
    }
    @objc private func showConsoleMenu() { showConsole() }
    @objc private func openPublicLink(_ sender:NSMenuItem) {
        guard !terminating,let raw=sender.representedObject as? String,let link=SettingsPublicLink(rawValue:raw) else { return }
        NSWorkspace.shared.open(link.url)
    }
    @objc private func checkForUpdates() { try? settings.editor.request(.checkForUpdates) }
    @objc private func showAbout() { Task { await settingsHost.present(paneID:"about",origin:.userInitiated) } }
    @objc private func refreshRows() {
        if lifecyclePaused { lifecycleController?.retryPending(); return }
        Task {
            #if MODELPLAN_U6_DRIVE
            if let driveGuard {
                // The product handler owns the one RPC; the test hook only observes its result.
                var observer: U6DriveGuard.RefreshObservation?
                for _ in 0..<25 where observer == nil {
                    observer = driveGuard.beginProductRefresh(composition: composition)
                    if observer == nil { try? await Task.sleep(for: .milliseconds(20)) }
                }
                guard let observer else { return }
                await composition.refresh(prepared: observer.prepared, onResult: observer.result)
                return
            }
            #endif
            await composition.refresh()
        }
    }
    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !terminating else { return .terminateLater }
        terminating = true; settings.editor.onHostRequest = nil
        if let accessibilityObserver { NSWorkspace.shared.notificationCenter.removeObserver(accessibilityObserver); self.accessibilityObserver = nil }
        interactionBinding?.stop(); firstRunFlow?.dispose(); settingsHost.suspend(); scopeConsentEntry.suspend(); console?.hide()
        statusMenuComponent?.dispose(); statusMenuComponent = nil; liveStatusMenu = nil
        Task {
            if lifecycleController != nil { await stopLifecycle(); composition.dock.close() }
            else { await composition.stop() }
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
    public func applicationWillTerminate(_ notification: Notification) {
        #if MODELPLAN_U6_DRIVE
        driveGuard?.recordTerminateCompleted()
        #endif
    }
}
