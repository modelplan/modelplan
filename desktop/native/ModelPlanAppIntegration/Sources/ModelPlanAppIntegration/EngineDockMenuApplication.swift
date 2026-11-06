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

struct StatusNoticePresentation {
    let frameInButton: CGRect
    let buttonBounds: CGRect
    let buttonIsFlipped: Bool
    let tone: DockNotice.Tone?
    let shape: DockNotice.Shape?
    let isVisible: Bool
}

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
    private lazy var applicationSettingsItem: NSMenuItem = {
        let item = settingsHost.menuItem(title: "Settings…")
        item.isEnabled = false
        item.keyEquivalent = ""
        return item
    }()
    private let applicationQuitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    private(set) lazy var applicationMenu: NSMenu = {
        let root = NSMenu()
        let application = NSMenuItem(title: "ModelPlan", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        submenu.addItem(applicationSettingsItem)
        submenu.addItem(.separator())
        submenu.addItem(applicationQuitItem)
        application.submenu = submenu
        root.addItem(application)
        return root
    }()
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
            // Same bounded path as Show: a hint-ledger write must not silently drop Hide.
            Task { @MainActor in
                guard let editor = application?.editor else { return }
                _ = await ShowQuotaWidgetRequest.setVisible(false, editor: editor)
            }
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
        let observedAuthorization = await notificationAuthorizationService?.authorization() ?? .unavailable
        guard !terminating else { return }
        notificationConsumer.observeAuthorization(observedAuthorization)
        var context = settings.editor.context
        context.capabilities.login = loginServiceAdapter?.observedState ?? .unavailable
        context.notificationAuthorization = observedAuthorization
        context.unavailableControls.removeValue(forKey: .sliverAlert)
        context.unavailableControls.removeValue(forKey: .magnification)
        if context.capabilities.login != .unavailable { context.unavailableControls.removeValue(forKey: .login) }
        if notificationAuthorizationService != nil && observedAuthorization != .unavailable {
            context.unavailableControls.removeValue(forKey: .notificationConsent)
        }
        for key in [SettingKey.websiteLink, .methodologyLink, .privacyLink, .repositoryLink, .feedback] {
            context.unavailableControls.removeValue(forKey: key)
        }
        settings.update(context: context)
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
    private var dockPresentationGateOpen: Bool {
        lifecycleController?.canRetry ?? !lifecyclePaused
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
            }, onGateOpen: { [weak self] in
                self?.allowDockPresentation()
                self?.renderMenu()
            })
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
        // A retry or engine failure can withdraw rows while the OS gate remains open.
        if dockPresentationGateOpen { allowDockPresentation() }
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
        NSApp.mainMenu = applicationMenu
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
        #if MODELPLAN_DOCK_NATIVE_JOURNEY
        installStatusItem(autosaveName: EngineRowsEntry.nativeJourneyProfile == nil ? "ModelPlanCommunity.StatusItem" : nil)
        #else
        installStatusItem(autosaveName: "ModelPlanCommunity.StatusItem")
        #endif
        #if MODELPLAN_U6_DRIVE
        driveGuard?.observeStatusMenu(ownsStatusMenu: { [weak self] menu in
            guard let self else { return false }; return menu === self.status?.menu
        }, currentStatusMenu: { [weak self] in self?.liveStatusMenu },
           actionForItem: { item in item.action == #selector(EngineDockMenuApplication.refreshRows) ? .refresh : nil })
        #endif
        renderMenu()
        Task { await prepare(); guard !terminating else { return }; startLifecycle(); renderMenu() }
    }
    /// A caller supplying no autosave name owns a temporary, non-persisted item.
    func installStatusItem(autosaveName: NSStatusItem.AutosaveName? = nil) {
        guard status == nil, !terminating else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let autosaveName { item.autosaveName = autosaveName }
        item.isVisible = true
        status = item
    }

    func removeStatusItem() {
        guard let status else { return }
        self.status = nil
        noticeIndicator.removeFromSuperview()
        status.menu = nil
        NSStatusBar.system.removeStatusItem(status)
    }

    var statusNoticePresentation: StatusNoticePresentation? {
        guard let status, let button = status.button, noticeIndicator.superview === button else { return nil }
        let windowVisible = button.window.map { $0.isVisible && $0.alphaValue > 0 && $0.occlusionState.contains(.visible) } ?? false
        return StatusNoticePresentation(frameInButton: noticeIndicator.frame, buttonBounds: button.bounds,
            buttonIsFlipped: button.isFlipped, tone: noticeIndicator.notice?.tone, shape: noticeIndicator.notice?.shape,
            isVisible: status.isVisible && windowVisible && noticeIndicator.notice != nil && !noticeIndicator.isHiddenOrHasHiddenAncestor)
    }

    func renderMenu() {
        guard !terminating else { return }
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
        let settingsTitle = label("Settings…", "设置…")
        let quitTitle = label("Quit", "退出")
        applicationSettingsItem.title = settingsTitle
        applicationSettingsItem.isEnabled = available && !terminating
        applicationSettingsItem.keyEquivalent = applicationSettingsItem.isEnabled ? "," : ""
        applicationQuitItem.title = quitTitle
        let showAvailability = ShowQuotaWidgetRequest.availability(paused: terminating,
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
            .init(title: label("Website", "网站"), action: { NSWorkspace.shared.open(SettingsPublicLink.website.url) }),
            .init(title: label("Methodology", "方法论"), action: { NSWorkspace.shared.open(SettingsPublicLink.methodology.url) }),
            .init(title: label("Privacy", "隐私"), action: { NSWorkspace.shared.open(SettingsPublicLink.privacy.url) }),
        ]
        let admitted = composition.presentedContent.snapshot.presentationRows
        unavailableMemberRefreshes.formIntersection(Set(admitted.keys))
        let content = composition.provider.dockContent
        // Some reader failures publish an admitted provider row without any
        // account. Such failures still need the same Diagnostics action.
        var diagnosticFacts = (content.menuRows + content.dockRows).compactMap { row -> ProviderDiagnosticFact? in
            guard row.state == .failed, row.accounts.isEmpty else { return nil }
            return .init(providerID: row.id, name: english ? row.name.en : row.name.zh, condition: .failed)
        }
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
        menuItems += [
            .init(title: nil),
            .init(title: label("Help…", "说明…"), action: available ? { [weak self] in self?.showHelp() } : nil),
            .init(title: settingsTitle, keyEquivalent: available ? "," : "", action: available ? { [weak self] in self?.settingsHost.action() } : nil),
            .init(title: label("About", "关于"), action: available ? { [weak self] in self?.showAbout() } : nil),
            .init(title: quitTitle, keyEquivalent: "q", target: NSApplication.shared, selector: #selector(NSApplication.terminate(_:))),
        ]
        LivePrivateMenus.scrubItems(menu)
        component.replace(with: menuItems)
        liveStatusMenu = menu
        if let status { component.attach(to: status) }
        if let button = status?.button {
            Self.configureStatusButton(button,image:CommunityMenuBarResources.templateImage(),barThickness:NSStatusBar.system.thickness); button.contentTintColor = nil
            noticeIndicator.attach(to: button)
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
        button.title = composition.menuPresentation.title
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
        guard ShowQuotaWidgetRequest.availability(paused: terminating,
                loaded: settings.editor.snapshot != nil, saving: settings.editor.isSaving || showRequestInFlight) == .ready else { return }
        showRequestInFlight = true; showFeedback = nil; renderMenu()
        Task { @MainActor [weak self] in
            guard let self else { return }
            let outcome = await ShowQuotaWidgetRequest.perform(editor: self.settings.editor)
            self.showRequestInFlight = false
            guard !self.terminating else { return }
            let currentOutcome: ShowQuotaWidgetOutcome = outcome == .ready && self.settings.editor.snapshot?.preferences.showDock != true ? .changed : outcome
            self.showFeedback = currentOutcome == .ready ? nil : currentOutcome
            if currentOutcome == .ready { self.composition.dock.revealForUser() }
            self.renderMenu()
        }
    }
    @objc private func showConsoleMenu() { showConsole() }
    @objc private func openPublicLink(_ sender:NSMenuItem) {
        guard !terminating,let raw=sender.representedObject as? String,let link=SettingsPublicLink(rawValue:raw) else { return }
        NSWorkspace.shared.open(link.url)
    }
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
    private func retireApplicationSurfaces() {
        settings.editor.onHostRequest = nil
        applicationSettingsItem.isEnabled = false
        applicationSettingsItem.keyEquivalent = ""
        dockHelp?.suspend()
        if let showSettingsObserver { settings.editor.removeChangeObserver(showSettingsObserver); self.showSettingsObserver = nil }
        if let accessibilityObserver { NSWorkspace.shared.notificationCenter.removeObserver(accessibilityObserver); self.accessibilityObserver = nil }
        interactionBinding?.stop(); firstRunFlow?.dispose(); settingsHost.suspend(); scopeConsentEntry.suspend(); console?.hide()
        statusMenuComponent?.dispose(); statusMenuComponent = nil; liveStatusMenu = nil
    }

    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !terminating else { return .terminateLater }
        terminating = true
        retireApplicationSurfaces()
        Task {
            if lifecycleController != nil { await stopLifecycle(); composition.dock.close() }
            else { await composition.stop() }
            await dockHelp?.dispose(); dockHelp = nil
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
    #if MODELPLAN_DOCK_NATIVE_JOURNEY
    var nativeJourneyStatusVisible: Bool {
        guard let status, status.isVisible, let button = status.button, button.image != nil,
              let window = button.window else { return false }
        return window.isVisible && !button.isHiddenOrHasHiddenAncestor && button.bounds.width > 0
    }

    func stopNativeDockJourney() async {
        terminating = true
        if let status { NSStatusBar.system.removeStatusItem(status); self.status = nil }
        retireApplicationSurfaces()
        await stopLifecycle()
        await composition.stop()
        await dockHelp?.dispose()
        dockHelp = nil
    }
    #endif

    public func applicationWillTerminate(_ notification: Notification) {
        #if MODELPLAN_U6_DRIVE
        driveGuard?.recordTerminateCompleted()
        #endif
    }
}
