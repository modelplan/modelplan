// SPDX-License-Identifier: MIT
import AppKit
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
    private var forecastCheckedSession: String?
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
    private var showSettingsObserver: UUID?
    private var showRequestInFlight = false
    private var showFeedback: ShowQuotaWidgetOutcome?
    private var memberRefreshInFlight = Set<String>()
    private var unavailableMemberRefreshes = Set<String>()
    public var memberRefreshAdapter: (any DockMemberRefreshAdapting)? {
        didSet {
            composition.dock.ringRefreshAvailable = memberRefreshAdapter != nil
            if dockHelp?.isInstalled == true {
                var context = settings.editor.context
                context.capabilities.helpMapAvailable = true
                settings.update(context: context)
            }
            dockHelp?.refresh()
        }
    }
    private var dockHelp: DockHelpCoordinator?
    var dockHelpInstalled: Bool { dockHelp?.isInstalled == true }
    private var helpMapUnavailable = false
    /// The presentation boundary remains replaceable for synthetic, window-free tests.
    var requestHelpMap: (() -> Bool)?
    private var dockHelpSetupInProgress = false
    #if MODELPLAN_U6_DRIVE
    private var driveGuard: U6DriveGuard?
    #endif
    private let makeSettingsSurface: (@MainActor (SettingsEditor) -> any SettingsWindowSurface)?
    private let makeConsole: (@MainActor (EngineDockMenuComposition) -> any EngineRowsConsoleSurface)?
    private var console: (any EngineRowsConsoleSurface)?
    private var firstRunFlow: CommunityConnectionFlow?
    /// Injection point for the OS login service; the normal entry supplies the live adapter.
    public var loginServiceAdapter: CommunityLoginServiceAdapter?
    public var notificationAuthorizationService: (any SettingsNotificationAuthorizationServing)?
    /// Injection point for opening System Settings; the normal entry uses NSWorkspace.
    public var openSystemSettings: (URL) -> Void = { NSWorkspace.shared.open($0) }
    /// Injection point for the cache action; the normal entry clears the app's own folder.
    public var clearAppCache: () -> Void = { EngineAppCache.clearCurrentApp() }
    /// Injection point for global shortcuts; the normal entry supplies the system registrar.
    var shortcutRegistrar: (any EngineShortcutRegistering)?
    private let notificationConsumer = SettingsNotificationConsumer()
    /// The default uses the native first-run window. Synthetic composition tests
    /// may supply an in-memory surface before preparation; no system service runs.
    public var makeFirstRunSurface: (@MainActor (SettingsEditor) -> any SettingsWindowSurface)?
    public var makeFirstRunSurfaceWithConsent: (@MainActor (SettingsEditor, ScopeConsentEntry) -> any SettingsWindowSurface)?
    private let activateSettings: @MainActor () -> Void
    /// Every public link from a menu or Settings leaves through here; tests read the URL instead of a browser.
    var openExternalURL: @MainActor (URL) -> Void = { NSWorkspace.shared.open($0) }
    public private(set) lazy var settingsHost = SettingsWindowHost(application: settings, canPresent: { [weak self] in self?.terminating == false && self?.lifecyclePaused == false }, activate: activateSettings, scopeConsentEntry: scopeConsentEntry, makeSurface: makeSettingsSurface)
    public init(configuration: EngineClientConfiguration, settingsStore: SettingsStore,
                createsNativePanels: Bool = true, bundleURL: URL = Bundle.main.bundleURL,
                cockpitEntryEnabled: Bool? = nil,
                dockEnvironment: (@MainActor () -> DockEdgeEnvironment)? = nil,
                deadlineNow: @escaping @MainActor () -> Date = { Date() },
                deadlineElapsed: (() -> TimeInterval)? = nil, deadlineScheduling: (any DockEdgeScheduling)? = nil,
                makeClient: (@MainActor (EngineClientConfiguration, ModelPlanEngineStore.EngineStore) -> any EngineClient)? = nil,
                makeSettingsSurface: (@MainActor (SettingsEditor) -> any SettingsWindowSurface)? = nil,
                makeConsole: (@MainActor (EngineDockMenuComposition) -> any EngineRowsConsoleSurface)? = nil,
                activateSettings: @escaping @MainActor () -> Void = { NSApplication.shared.activate() }) {
        let composition = EngineDockMenuComposition(configuration: configuration, createsNativePanels: createsNativePanels, dockEnvironment: dockEnvironment, deadlineNow: deadlineNow, deadlineElapsed: deadlineElapsed, deadlineScheduling: deadlineScheduling, makeClient: makeClient)
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
        showSettingsObserver = settings.editor.observeChanges { [weak self] in
            guard let self, !self.terminating, self.liveStatusMenu != nil else { return }
            self.renderMenu()
        }
        CommunityPlacementBinding.install(on: composition.dock, application: settings)
        // M0's host opts in only when the native interaction port exists.
        if let host = (composition.dock as AnyObject) as? any DockInteractionHostPort {
            let clock = deadlineElapsed ?? { ProcessInfo.processInfo.systemUptime }
            interactionBinding = EngineDockInteractionBinding(host: host, application: settings,
                scheduler: DockCommonModeScheduler(clock: clock), clock: clock)
            interactionBinding?.onActivate = { [weak self] id in self?.activateMember(id) }
        }
        composition.settingsDidChange = { [weak self] value in
            guard let self, !self.terminating else { return }
            if self.liveStatusMenu != nil { self.renderMenu() }
            self.console?.applySettings(value)
            self.dockHelp?.refresh()
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
            guard let self else { return }
            if self.composition.provider.dockContent.status == .cleared { self.unavailableMemberRefreshes.removeAll() }
            self.updateMemberRefreshCapability()
            self.updateForecastProducerCapability()
            self.updateSettingsContext(); self.renderMenu(); self.console?.render()
            #if MODELPLAN_U6_DRIVE
            if self.composition.provider.dockContent.status == .cleared { self.driveGuard?.recordClear() }
            #endif
        }
        composition.dock.cockpitEntryEnabled = self.cockpitEntryEnabled
        composition.dock.menuNoticeDidChange = { [weak self] notice, first in self?.applyMenuNotice(notice, first: first) }
        composition.dock.showSettings = settingsHost.action
        composition.dock.showConsole = { [weak self] in self?.showConsole() }
    }
    private func updateMemberRefreshCapability() {
        guard let delivery = composition.store.snapshot.delivery, composition.client.isCurrent(delivery) else {
            if memberRefreshAdapter is AppServerMemberRefreshAdapter { memberRefreshAdapter = nil }
            return
        }
        guard memberRefreshAdapter == nil else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            let supported = await self.composition.client.supportsCapability("memberRefreshV1")
            guard !self.terminating, self.composition.client.isCurrent(delivery), self.memberRefreshAdapter == nil else { return }
            if supported { self.memberRefreshAdapter = AppServerMemberRefreshAdapter(client: self.composition.client, store: self.composition.store) }
        }
    }
    /// SET-9-29: capabilities are fixed per engine session, so each session asks once. The
    /// forecast producer (F1) reports `forecastProducerV1`; until then the kind stays hidden.
    private func updateForecastProducerCapability() {
        guard let delivery = composition.store.snapshot.delivery, composition.client.isCurrent(delivery),
              forecastCheckedSession != delivery.sessionID else { return }
        forecastCheckedSession = delivery.sessionID
        Task { @MainActor [weak self] in
            guard let self else { return }
            let supported = await self.composition.client.supportsCapability("forecastProducerV1")
            guard !self.terminating, self.composition.client.isCurrent(delivery),
                  supported != self.settings.editor.context.capabilities.forecastProducerAvailable else { return }
            var context = self.settings.editor.context
            context.observeForecastProducer(supported)
            self.settings.update(context: context)
        }
    }
    private func updateSettingsContext() {
        let ready: Bool
        if case .ready = composition.store.snapshot.connection { ready = true } else { ready = false }
        let admitted = composition.presentedContent.snapshot.presentationRows
        let readers: [SettingsReaderDiagnostic] = composition.accountMembers.members.compactMap { member in
            guard let row = admitted[member.id] else { return nil }
            return .init(name: .init(member.name(english: true), member.name(english: false)),
                         source: row.sourceName.isEmpty ? nil : .init(EngineDockContentProvider.sourceName(member.account.route, english: true), EngineDockContentProvider.sourceName(member.account.route, english: false)),
                         lastRead: row.originalObservedAt, nextRefresh: nil)
        }
        guard ready != lastAboutConnectionReady || readers != settings.editor.context.readerDiagnostics else { return }
        lastAboutConnectionReady = ready
        // Preserve Dock-owned catalogue, display and placement facts when the
        // engine connection changes; only About's CLI readiness comes from here.
        var context = settings.editor.context
        context.about.cliState = contextSource.make(engineReady: ready).about.cliState
        context.readerDiagnostics = readers
        settings.update(context: context)
    }
    private func activateMember(_ id: String) {
        guard !terminating, !lifecyclePaused,
              composition.presentedContent.snapshot.inputs.contains(where: { $0.id == id }) else { return }
        _ = composition.dock.sweepRefresh(id)
        guard !memberRefreshInFlight.contains(id),
              let member = composition.accountMembers.members.first(where: { $0.id == id && $0.isStable }),
              let delivery = composition.store.snapshot.delivery, composition.client.isCurrent(delivery) else { return }
        guard let adapter = memberRefreshAdapter else { unavailableMemberRefreshes.insert(id); renderMenu(); return }
        let admission = adapter.admission(for: member, delivery: delivery, now: Date())
        guard admission == .ready else {
            if admission == .unavailable { unavailableMemberRefreshes.insert(id) }
            else { unavailableMemberRefreshes.remove(id) }
            renderMenu(); return
        }
        unavailableMemberRefreshes.remove(id)
        memberRefreshInFlight.insert(id)
        Task { @MainActor [weak self, weak adapter] in
            guard let self else { return }
            defer { self.memberRefreshInFlight.remove(id) }
            guard let adapter, !self.terminating, !self.lifecyclePaused,
                  self.composition.client.isCurrent(delivery),
                  self.composition.presentedContent.snapshot.inputs.contains(where: { $0.id == id }),
                  self.composition.accountMembers.members.contains(where: {
                      $0.id == id && $0.isStable && $0.rowID == member.rowID && $0.source == member.source &&
                      $0.account.subscriptionRef == member.account.subscriptionRef && $0.account.accountLocator == member.account.accountLocator
                  }),
                  adapter.admission(for: member, delivery: delivery, now: Date()) == .ready else { return }
            do { try await adapter.request(member: member, delivery: delivery) }
            catch {
                guard !self.terminating, self.composition.client.isCurrent(delivery),
                      self.composition.presentedContent.snapshot.inputs.contains(where: { $0.id == id }) else { return }
                self.unavailableMemberRefreshes.insert(id); self.renderMenu()
            }
        }
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
        if shortcutRegistrar == nil, let bundle = Bundle(url: appBundleURL),
           bundle.bundleURL.standardizedFileURL == Bundle.main.bundleURL.standardizedFileURL, bundle.bundleURL.pathExtension == "app" {
            shortcutRegistrar = CarbonShortcutRegistrar()
        }
        let observedAuthorization = await notificationAuthorizationService?.authorization() ?? .unavailable
        guard !terminating else { return }
        notificationConsumer.observeAuthorization(observedAuthorization)
        var context = settings.editor.context
        context.capabilities.login = loginServiceAdapter?.observedState ?? .unavailable
        context.notificationAuthorization = observedAuthorization
        context.loginServiceObserved = true
        context.notificationServiceObserved = true
        // The choice stays visible; a service macOS refuses gets an honest reason and the fallback row.
        if context.capabilities.login != .unavailable { context.unavailableControls.removeValue(forKey: .login) }
        else { context.unavailableControls[.login] = .init("Unavailable for this copy of the app. Use Login Items in System Settings.", "此应用副本不可用，请使用系统设置中的登录项。") }
        if notificationAuthorizationService != nil && observedAuthorization != .unavailable {
            context.unavailableControls.removeValue(forKey: .notificationConsent)
        } else { context.unavailableControls[.notificationConsent] = .init("Unavailable for this copy of the app. Use Notifications in System Settings.", "此应用副本不可用，请使用系统设置中的通知。") }
        for key in [SettingKey.websiteLink, .methodologyLink, .privacyLink, .repositoryLink, .feedback] {
            context.unavailableControls.removeValue(forKey: key)
        }
        // SET-9-18: the reset and official kinds are usable once delivery is wired.
        if composition.notificationDeliveryAvailable { context.observeNotificationDelivery(true) }
        // Dock, card and menu bar all read these through `applying(to:)` and `presentedSubscriptionIDs`.
        for key in [SettingKey.percentagePin, .order, .visible, .alias] {
            context.unavailableControls.removeValue(forKey: key)
        }
        // Language reaches every surface through `applySettings`; the menu bar reads its own display.
        for key in [SettingKey.language, .menuDisplay] { context.unavailableControls.removeValue(forKey: key) }
        context.capabilities.appCacheClearAvailable = true
        for key in [SettingKey.clearAppCache, .resetHints] { context.unavailableControls.removeValue(forKey: key) }
        if shortcutRegistrar != nil {
            context.unavailableControls.removeValue(forKey: .dockShortcut)
            // A build without the cockpit entry has nothing for this shortcut to open.
            if cockpitEntryEnabled { context.unavailableControls.removeValue(forKey: .openShortcut) }
            else { context.unavailableControls[.openShortcut] = .init("Unavailable until this build can open the cockpit.", "此版本可打开驾驶舱前不可用。") }
        }
        // Project names reach the cockpit through `applySettings`, so the row is a real control.
        context.unavailableControls.removeValue(forKey: .projectNames)
        settings.update(context: context)
        shortcutRegistrar?.onPress = { [weak self] action in self?.performShortcut(action) }
        settings.editor.onHostRequest = { [weak self] request in self?.dispatchHostRequest(request) }
        if firstRunFlow == nil {
            firstRunFlow = try? CommunityConnectionFlow(application: settings,
                canPresent: { [weak self] in self?.terminating == false && self?.lifecyclePaused == false },
                showSettings: { [weak self] pane in await self?.settingsHost.present(paneID: pane) },
                activate: activateSettings, scopeConsentEntry: scopeConsentEntry,
                makeFirstRun: makeFirstRunSurface, makeFirstRunWithConsent: makeFirstRunSurfaceWithConsent)
        }
        updateSystemAccessibility(SettingsWindowController.systemEnvironment())
        await settings.reload()
        guard !terminating else { return }
        // Saved chords exist only after the store has loaded.
        if let preferences = settings.editor.snapshot?.preferences {
            registerShortcuts(openCockpit: preferences.openShortcut, toggleDock: preferences.dockShortcut)
        }
        if dockHelp == nil, !dockHelpSetupInProgress {
            dockHelpSetupInProgress = true
            let help = await DockHelpCoordinator.restored(dock: composition.dock, application: settings, statusAnchor: { [weak self] in
                guard let self, let status = self.status, status.isVisible,
                      let button = status.button, !button.isHiddenOrHasHiddenAncestor,
                      let window = button.window, window.isVisible, !window.isMiniaturized,
                      window.alphaValue > 0, window.occlusionState.contains(.visible) else { return nil }
                let frame = window.convertToScreen(button.convert(button.bounds, to: nil))
                guard !frame.isNull, !frame.isInfinite, frame.width > 0, frame.height > 0,
                      [frame.minX, frame.minY, frame.width, frame.height].allSatisfy(\.isFinite) else { return nil }
                return DockStatusHelpAnchor(frame: frame, sharing: window.sharingType, collection: window.collectionBehavior)
            })
            dockHelpSetupInProgress = false
            if terminating { await help?.dispose(); return }
            if dockHelp == nil { dockHelp = help }
            else { await help?.dispose() }
            if dockHelp?.isInstalled == true {
                if requestHelpMap == nil { requestHelpMap = { [weak self] in self?.dockHelp?.presentRequestedMap() == true } }
                var context = settings.editor.context
                context.capabilities.helpMapAvailable = true
                context.capabilities.helpMapUsesDock = true
                settings.update(context: context)
            }
        }
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
                self.lifecyclePaused = false; self.composition.dock.resumeFromLifecycle(); self.composition.resumeDeadlines()
                self.allowDockPresentation(); self.dockHelp?.resume(); self.renderMenu()
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
        dockHelp?.suspend()
        composition.suspendDeadlines(); composition.dock.pauseForLifecycle(); console?.hide(); settingsHost.suspend(); firstRunFlow?.suspend()
        renderMenu()
    }
    /// D37: an unassigned chord registers nothing. Each outcome is recorded for that exact chord.
    private func registerShortcuts(openCockpit: ShortcutChord, toggleDock: ShortcutChord) {
        guard let shortcutRegistrar else { return }
        shortcutRegistrar.unregisterAll()
        var observations: [SettingsShortcutObservation] = []
        for (action, chord) in [(ShortcutAction.openCockpit, openCockpit), (.toggleDock, toggleDock)]
        where !chord.isUnassigned && (action != .openCockpit || cockpitEntryEnabled) {
            let outcome = chord.isValid ? shortcutRegistrar.register(chord, action: action) : .unavailable
            observations.append(.init(action: action, chord: chord, registration: outcome))
        }
        var context = settings.editor.context
        context.shortcutObservations = observations
        settings.update(context: context)
    }
    private func performShortcut(_ action: ShortcutAction) {
        guard !terminating, !lifecyclePaused else { return }
        switch action {
        case .openCockpit: showConsole()
        case .toggleDock:
            guard settings.editor.snapshot?.preferences.showDock == true else { showDock(); return }
            Task { @MainActor [weak self] in _ = try? await self?.settings.editor.commit(SettingsB21Edit.showDock(false)) }
        }
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
        case .openPublicLink(let link): openExternalURL(link.url)
        case .openSystemSettings(let pane): openSystemSettings(pane.url)
        case .action(.clearAppCache): clearAppCache()
        case .shortcutPreferencesChanged(let openCockpit, let toggleDock):
            registerShortcuts(openCockpit: openCockpit, toggleDock: toggleDock)
        case .firstRunCompleted(let effects, _):
            for effect in effects {
                switch effect {
                case .revealDock: composition.dock.setPresentationAllowed(true)
                case .returnToSettings: Task { [weak self] in await self?.settingsHost.present() }
                case .openCockpit: showConsole()
                case .latchOptionHelp: showHelp()
                case .closeFirstRunPopup: break
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
        let helpError = helpMapUnavailable ? SettingsText("Help unavailable. Try again when the Quota Widget is visible.", "说明暂不可用，请在额度挂件可见时重试。").value(language) : nil
        let detail = helpError ?? showFeedbackText(language) ?? (lifecyclePaused ? (canRetry ? EngineRowsText.waitingForFresh : EngineRowsText.paused).value(language) : composition.menuPresentation.detail)
        if composition.provider.dockContent.status == .cleared { LivePrivateMenus.scrub(menu) }
        let english = language == .english
        func label(_ en: String, _ zh: String) -> String { english ? en : zh }
        let available = !lifecyclePaused
        let showAvailability = ShowQuotaWidgetRequest.availability(paused: lifecyclePaused || terminating,
            loaded: settings.editor.snapshot != nil, saving: settings.editor.isSaving || showRequestInFlight)
        let showTitle: String
        switch showAvailability {
        case .loading: showTitle = label("Show Quota Widget — Loading Settings", "显示额度挂件 — 正在载入设置")
        case .saving: showTitle = label("Show Quota Widget — Saving Settings", "显示额度挂件 — 正在保存设置")
        case .ready, .paused: showTitle = EngineRowsText.showQuotaWidget.value(language)
        }
        var menuItems: [DockMenuPresentationItem] = []
        if let feedback = helpError ?? showFeedbackText(language) { menuItems.append(.init(title: feedback)) }
        else if lifecyclePaused { menuItems.append(.init(title: (canRetry ? EngineRowsText.waitingForFresh : EngineRowsText.paused).value(language))) }
        menuItems += [
            .init(title: label("Refresh", "刷新"), target: (available || canRetry) ? self : nil, selector: (available || canRetry) ? #selector(refreshRows) : nil),
            .init(title: showTitle, action: showAvailability == .ready ? { [weak self] in self?.showDock() } : nil),
            .init(title: nil),
            .init(title: cockpitEntryEnabled ? label("Open Cockpit", "打开驾驶舱") : EngineRowsText.comingSoon.value(language), action: available && cockpitEntryEnabled ? { [weak self] in self?.showConsoleMenu() } : nil),
            .init(title: label("Website", "网站"), action: { [weak self] in self?.openExternalURL(SettingsPublicLink.website.url) }),
            .init(title: label("Methodology", "方法论"), action: { [weak self] in self?.openExternalURL(SettingsPublicLink.methodology.url) }),
            .init(title: label("Privacy", "隐私"), action: { [weak self] in self?.openExternalURL(SettingsPublicLink.privacy.url) }),
        ]
        let admitted = composition.presentedContent.snapshot.presentationRows
        unavailableMemberRefreshes.formIntersection(Set(admitted.keys))
        var diagnosticFacts: [ProviderDiagnosticFact] = []
        for member in composition.accountMembers.members {
            guard let row = admitted[member.id] else { continue }
            let condition: ProviderDiagnosticCondition
            switch row.cardReadingState {
            case .ok: condition = unavailableMemberRefreshes.contains(member.id) ? .refreshUnavailable : .normal
            case .loading: condition = .loading
            case .stale: condition = .stale
            case .errorLastGood: condition = .failed
            case .error:
                if member.row.consent == .denied || member.row.consent == .unset || member.row.state == .needsConsent || member.row.state == .needsKeychain {
                    condition = .permission
                } else if member.row.state == .failed {
                    condition = .failed
                } else { condition = .normal }
            }
            let provider = english ? member.row.name.en : member.row.name.zh
            diagnosticFacts.append(.init(providerID: member.rowID, name: provider, condition: condition))
        }
        for summary in ProviderDiagnosticSummary.lines(diagnosticFacts, english: english) {
            menuItems.append(.init(title: summary,
                action: available ? { [weak self] in Task { await self?.settingsHost.present(paneID: "diagnostics", origin: .userInitiated) } } : nil))
        }
        if settings.editor.context.capabilities.updateServiceAvailable, settings.editor.onHostRequest != nil {
            menuItems.append(.init(title: label("Check for updates", "检查更新"), action: { [weak self] in self?.checkForUpdates() }))
        }
        menuItems += [
            .init(title: nil),
            .init(title: label("Help…", "说明…"), action: available ? { [weak self] in self?.showHelp() } : nil),
            .init(title: label("Settings…", "设置…"), action: available ? { [weak self] in self?.settingsHost.action() } : nil),
            .init(title: label("About", "关于"), action: available ? { [weak self] in self?.showAbout() } : nil),
            .init(title: label("Quit", "退出"), keyEquivalent: "q", target: NSApplication.shared, selector: #selector(NSApplication.terminate(_:))),
        ]
        component.replace(with: menuItems)
        liveStatusMenu = menu
        if let status { component.attach(to: status) }
        if let button = status?.button {
            Self.configureStatusButton(button,image:CommunityMenuBarResources.templateImage(),barThickness:NSStatusBar.system.thickness); button.contentTintColor = nil
            noticeIndicator.frame = NSRect(x: max(0, button.bounds.width - 7), y: max(0, button.bounds.height - 7), width: 7, height: 7)
            noticeIndicator.autoresizingMask = [.minXMargin, .minYMargin]
            if noticeIndicator.superview !== button { button.addSubview(noticeIndicator) }
        }
        if let button = status?.button { applyStatusContent(to: button, detail: detail) }
        dockHelp?.refresh()
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
        // renderMenu keeps this menu current; never overwrite its first action with a reader diagnostic.
    }
    /// Shared by the native status item and detached presentation checks.
    /// Feedback belongs to the menu/accessibility detail; the title remains the quota value.
    func applyStatusContent(to button: NSButton, detail: String) {
        let title = composition.menuPresentation.title
        button.title = title
        button.imagePosition = title.isEmpty ? .imageOnly : .imageLeading
        button.toolTip = detail
        button.setAccessibilityHelp(detail)
    }
    private func showHelp() {
        guard !terminating, !lifecyclePaused else { return }
        helpMapUnavailable = requestHelpMap?() != true
        renderMenu()
    }
    private func showFeedbackText(_ language: SettingsLanguage) -> String? {
        switch showFeedback {
        case .changed: return SettingsText("Settings changed. Choose Show Quota Widget again.", "设置已更改，请再次选择显示额度挂件。").value(language)
        case .failed, .unavailable: return SettingsText("Could not show Quota Widget. Check Settings and try again.", "无法显示额度挂件，请检查设置后重试。").value(language)
        case .ready, nil: return nil
        }
    }
    private func showDock() {
        guard ShowQuotaWidgetRequest.availability(paused: terminating || lifecyclePaused,
                loaded: settings.editor.snapshot != nil, saving: settings.editor.isSaving || showRequestInFlight) == .ready,
              let revision = settings.editor.snapshot?.revision else { return }
        showRequestInFlight = true; showFeedback = nil; renderMenu()
        Task { @MainActor [weak self] in
            guard let self else { return }
            let outcome = await ShowQuotaWidgetRequest.perform(editor: self.settings.editor, expectedRevision: revision)
            self.showRequestInFlight = false
            guard !self.terminating else { return }
            let currentOutcome: ShowQuotaWidgetOutcome = outcome == .ready && self.settings.editor.snapshot?.preferences.showDock != true ? .changed : outcome
            self.showFeedback = currentOutcome == .ready ? nil : currentOutcome
            if currentOutcome == .ready && !self.lifecyclePaused { self.composition.dock.revealForUser() }
            self.renderMenu()
        }
    }
    @objc private func showConsoleMenu() { showConsole() }
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
        shortcutRegistrar?.unregisterAll()
        dockHelp?.suspend()
        if let showSettingsObserver { settings.editor.removeChangeObserver(showSettingsObserver); self.showSettingsObserver = nil }
        if let accessibilityObserver { NSWorkspace.shared.notificationCenter.removeObserver(accessibilityObserver); self.accessibilityObserver = nil }
        interactionBinding?.stop(); firstRunFlow?.dispose(); settingsHost.suspend(); scopeConsentEntry.suspend(); console?.hide()
        statusMenuComponent?.dispose(); statusMenuComponent = nil; liveStatusMenu = nil
        Task {
            if lifecycleController != nil { await stopLifecycle(); composition.dock.close() }
            else { await composition.stop() }
            await dockHelp?.dispose(); dockHelp = nil
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
