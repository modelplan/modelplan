// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanSettings
#if MODELPLAN_U6_DRIVE
import ModelPlanMenuVerification
#endif

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
        settings = SettingsApplicationCoordinator(store: settingsStore, context: contextSource.make(engineReady: false)) { composition.dock.apply($0) }
        super.init()
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
        console?.show()
    }
    public func prepare() async { await settings.reload() }
    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        #if MODELPLAN_U6_DRIVE
        do { driveGuard = try U6DriveGuard.attach(ownsMenu: { [weak self] menu in
            guard let self else { return false }; return menu.delegate === self || menu.delegate === self.composition.dock
        }, hasPrivateContent: { [weak self] in
            guard let value = self?.composition.provider.dockContent else { return false }
            return !value.dockRows.isEmpty || !value.menuRows.isEmpty
        }, dockHost: composition.dock) } catch { NSApplication.shared.terminate(nil); return }
        #endif
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        #if MODELPLAN_U6_DRIVE
        driveGuard?.observeStatusMenu(ownsStatusMenu: { [weak self] menu in
            guard let self else { return false }; return menu === self.status?.menu
        }, actionForItem: { item in item.action == #selector(EngineDockMenuApplication.refreshRows) ? .refresh : nil })
        #endif
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
        let consoleItem = menu.addItem(withTitle: "Dock readings… / Dock 读数…", action: #selector(showConsoleMenu), keyEquivalent: "")
        consoleItem.target = self
        menu.addItem(withTitle: "Quit / 退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
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
    @objc private func refreshRows() {
        Task {
            #if MODELPLAN_U6_DRIVE
            if let driveGuard {
                // The product handler owns the one RPC; the test hook only observes its result.
                var observer: (@MainActor (Result<Void,Error>) -> Void)?
                for _ in 0..<25 where observer == nil {
                    observer = driveGuard.beginProductRefresh(composition: composition)
                    if observer == nil { try? await Task.sleep(for: .milliseconds(20)) }
                }
                guard let observer else { return }
                await composition.refresh(onResult: observer)
                return
            }
            #endif
            await composition.refresh()
        }
    }
    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !terminating else { return .terminateLater }
        terminating = true; settingsHost.suspend(); console?.hide()
        Task { await composition.stop(); sender.reply(toApplicationShouldTerminate: true) }
        return .terminateLater
    }
    public func applicationWillTerminate(_ notification: Notification) {
        #if MODELPLAN_U6_DRIVE
        driveGuard?.recordTerminateCompleted()
        #endif
    }
}
