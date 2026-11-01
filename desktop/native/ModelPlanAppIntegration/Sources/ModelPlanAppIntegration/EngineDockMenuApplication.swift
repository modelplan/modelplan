// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanSettings

/// The rows-backed normal Dock/menu lifecycle. Legacy probe entry remains separate.
@MainActor public final class EngineDockMenuApplication: NSObject, NSApplicationDelegate, NSMenuDelegate {
    public let composition: EngineDockMenuComposition
    private let settings: SettingsApplicationCoordinator
    public let foundationStore: SettingsStore
    private let contextSource: EngineSettingsContext
    private var lastAboutConnectionReady = false
    private var status: NSStatusItem?
    private(set) var liveStatusMenu: NSMenu?
    private var terminating = false
    private var cockpitOpen = false
    private var accessibilityObserver: NSObjectProtocol?
    #if MODELPLAN_TEST_ONLY_SPI
    public var verificationStatusButton: NSStatusBarButton? { status?.button }
    public var verificationStatusAction: ((NSEvent.EventType,Bool)->Void)?
    public func verificationRemoveStatusItem() {
        if let status { NSStatusBar.system.removeStatusItem(status) }; status = nil
    }
    #endif
    #if MODELPLAN_U6_DRIVE
    private var driveGuard: U6DriveGuard?
    #endif
    private let makeSettingsSurface: (@MainActor (SettingsEditor) -> any SettingsWindowSurface)?
    private let makeConsole: (@MainActor (EngineDockMenuComposition) -> any EngineRowsConsoleSurface)?
    private var console: (any EngineRowsConsoleSurface)?
    private let activateSettings: @MainActor () -> Void
    public private(set) lazy var settingsHost = SettingsWindowHost(application: settings, canPresent: { [weak self] in self?.terminating == false }, activate: activateSettings, makeSurface: makeSettingsSurface)
    public init(configuration: EngineClientConfiguration, settingsStore: SettingsStore,
                createsNativePanels: Bool = true, bundleURL: URL = Bundle.main.bundleURL,
                makeClient: (@MainActor (EngineClientConfiguration, ModelPlanEngineStore.EngineStore) -> any EngineClient)? = nil,
                makeSettingsSurface: (@MainActor (SettingsEditor) -> any SettingsWindowSurface)? = nil,
                makeConsole: (@MainActor (EngineDockMenuComposition) -> any EngineRowsConsoleSurface)? = nil,
                activateSettings: @escaping @MainActor () -> Void = { NSApplication.shared.activate() }) {
        let composition = EngineDockMenuComposition(configuration: configuration, createsNativePanels: createsNativePanels, makeClient: makeClient)
        self.composition = composition
        self.foundationStore = settingsStore
        self.makeSettingsSurface = makeSettingsSurface; self.makeConsole = makeConsole; self.activateSettings = activateSettings
        let contextSource = EngineSettingsContext(bundle: bundleURL, executable: configuration.executableURL)
        self.contextSource = contextSource
        settings = SettingsApplicationCoordinator(store: settingsStore, context: contextSource.make(engineReady: false), environment: SettingsWindowController.systemEnvironment()) { composition.dock.apply($0); composition.settingsDidChange?($0) }
        super.init()
        composition.menuDidChange = { [weak self] in
            self?.updateSettingsContext(); self?.renderMenu(); self?.console?.render()
            #if MODELPLAN_U6_DRIVE
            if self?.composition.provider.dockContent.status == .cleared { self?.driveGuard?.recordClear() }
            #endif
        }
        composition.settingsDidChange = { [weak self] in self?.console?.apply($0) }
        composition.dock.showSettings = settingsHost.action
        composition.dock.showConsole = { [weak self] in self?.showConsole() }
    }
    private func updateSettingsContext() {
        let ready: Bool
        if case .ready = composition.store.snapshot.connection { ready = true } else { ready = false }
        guard ready != lastAboutConnectionReady else { return }
        lastAboutConnectionReady = ready
        settings.update(context: contextSource.make(engineReady: ready))
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
        if let latest = settings.latest { console?.apply(latest) }
        console?.show()
    }
    var cockpitAnchor: CGRect? {
        guard let button = status?.button, let window = button.window else { return nil }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }
    func toggleCockpit() {
        if cockpitOpen { console?.close() } else { showConsole() }
    }
    func cockpitVisibilityChanged(_ open: Bool) {
        cockpitOpen = open
        composition.dock.setPresentationAllowed(!open && !terminating)
    }
    public func prepare() async {
        if accessibilityObserver == nil {
            accessibilityObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
                    Task { @MainActor in self?.settings.update(environment: SettingsWindowController.systemEnvironment()) }
                }
        }
        await settings.reload(); renderMenu()
    }
    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        #if MODELPLAN_U6_DRIVE
        do { driveGuard = try U6DriveGuard.attach(ownsMenu: { [weak self] menu in
            guard let self else { return false }; return menu.delegate === self || menu.delegate === self.composition.dock
        }, hasPrivateContent: { [weak self] in
            guard let value = self?.composition.provider.dockContent else { return false }
            return !value.dockRows.isEmpty || !value.menuRows.isEmpty
        }) } catch { NSApplication.shared.terminate(nil); return }
        #endif
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        Task { await prepare(); composition.dock.setPresentationAllowed(true); renderMenu(); await composition.start() }
    }
    private func renderMenu() {
        let menu = liveStatusMenu ?? NSMenu()
        if composition.provider.dockContent.status == .cleared { LivePrivateMenus.scrub(menu) }
        menu.removeAllItems()
        let reading = NSMenuItem(title: composition.menuPresentation.detail, action: nil, keyEquivalent: "")
        reading.isEnabled = false; menu.addItem(reading)
        let refresh = menu.addItem(withTitle: "Refresh / 刷新", action: #selector(refreshRows), keyEquivalent: "")
        refresh.target = self
        menu.addItem(.separator())
        menu.addItem(settingsHost.menuItem(title: "Settings… / 设置…"))
        let consoleItem = menu.addItem(withTitle: "Open Cockpit / 打开驾驶舱", action: #selector(showConsoleMenu), keyEquivalent: "")
        consoleItem.target = self
        menu.addItem(withTitle: "Quit / 退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.delegate = self; liveStatusMenu = menu
        status?.button?.target = self; status?.button?.action = #selector(statusPressed)
        status?.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
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
    @objc private func statusPressed() {
        guard let event = NSApp.currentEvent, let button = status?.button else { return }
        #if MODELPLAN_TEST_ONLY_SPI
        verificationStatusAction?(event.type,cockpitOpen)
        #endif
        if event.type == .rightMouseUp {
            if let menu = liveStatusMenu { NSMenu.popUpContextMenu(menu, with: event, for: button) }
        } else { toggleCockpit() }
    }
    @objc private func showConsoleMenu() { showConsole() }
    @objc private func refreshRows() { Task { await composition.refresh() } }
    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !terminating else { return .terminateLater }
        terminating = true; settingsHost.suspend(); console?.hide()
        if let accessibilityObserver { NSWorkspace.shared.notificationCenter.removeObserver(accessibilityObserver) }
        accessibilityObserver = nil
        Task { await composition.stop(); sender.reply(toApplicationShouldTerminate: true) }
        return .terminateLater
    }
}
