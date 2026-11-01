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
        settings = SettingsApplicationCoordinator(store: settingsStore, context: contextSource.make(engineReady: false)) {
            composition.setLanguage($0.snapshot.preferences.language.rawValue)
            composition.dock.apply($0)
            composition.menuDidChange?()
        }
        super.init()
        CommunityPlacementBinding.install(on:composition.dock,application:settings)
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
        Task { await prepare(); composition.dock.setPresentationAllowed(true); renderMenu(); await composition.start() }
    }
    private func renderMenu() {
        let menu = liveStatusMenu ?? NSMenu()
        if composition.provider.dockContent.status == .cleared { LivePrivateMenus.scrub(menu) }
        menu.removeAllItems()
        menu.autoenablesItems = false
        let english = settings.editor.snapshot?.preferences.language == .english
        func label(_ en: String, _ zh: String) -> String { english ? en : zh }
        let reading = NSMenuItem(title: composition.menuPresentation.detail, action: nil, keyEquivalent: "")
        reading.isEnabled = false; menu.addItem(reading)
        let refresh = menu.addItem(withTitle: label("Refresh", "刷新"), action: #selector(refreshRows), keyEquivalent: "")
        refresh.target = self
        menu.addItem(.separator())
        let consoleItem = menu.addItem(withTitle: label("Open Cockpit", "打开驾驶舱"), action: #selector(showConsoleMenu), keyEquivalent: "")
        consoleItem.target = self
        // r7 SPEC §6.6: public links, update check, Help directly above Settings, About, Quit.
        for (link, title) in [(SettingsPublicLink.website,label("Website", "网站")), (.methodology,label("Methodology", "方法论")), (.privacy,label("Privacy", "隐私"))] {
            let item = menu.addItem(withTitle:title,action:#selector(openPublicLink(_:)),keyEquivalent:"")
            item.target=self;item.representedObject=link.rawValue
        }
        let updates=menu.addItem(withTitle:label("Check for updates", "检查更新"),action:#selector(checkForUpdates),keyEquivalent:"")
        updates.target=self;updates.isEnabled=settings.editor.context.capabilities.updateServiceAvailable && settings.editor.onHostRequest != nil
        menu.addItem(.separator())
        let help=menu.addItem(withTitle:label("Help…", "说明…"),action:nil,keyEquivalent:"")
        // The engine Cockpit does not yet expose an Option-map action. Do not fake delivery.
        help.isEnabled=false
        menu.addItem(settingsHost.menuItem(title:label("Settings…", "设置…")))
        let about=menu.addItem(withTitle:label("About", "关于"),action:#selector(showAbout),keyEquivalent:"");about.target=self
        menu.addItem(withTitle: label("Quit", "退出"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.delegate = self; liveStatusMenu = menu; status?.menu = menu
        if let button=status?.button {
            Self.configureStatusButton(button,image:CommunityMenuBarResources.templateImage(),barThickness:NSStatusBar.system.thickness)
            button.contentTintColor = nil
        }
        status?.button?.title = composition.menuPresentation.title
        status?.button?.toolTip = composition.menuPresentation.detail
        #if MODELPLAN_U6_DRIVE
        if let button = status?.button { driveGuard?.observeStatusButton(button) }
        #endif
    }
    static func configureStatusButton(_ button:NSButton,image:NSImage?,barThickness:CGFloat) {
        let sized=image?.copy() as? NSImage
        let side=min(16,max(0,barThickness.isFinite ? barThickness : 0))
        sized?.size=NSSize(width:side,height:side);sized?.isTemplate=true
        button.image=sized;button.imageScaling = .scaleProportionallyDown;button.imagePosition = .imageLeading
    }
    public func menuWillOpen(_ menu: NSMenu) { menu.items.first?.title = composition.menuPresentation.detail }
    @objc private func showConsoleMenu() { showConsole() }
    @objc private func openPublicLink(_ sender:NSMenuItem) {
        guard !terminating,let raw=sender.representedObject as? String,let link=SettingsPublicLink(rawValue:raw) else { return }
        NSWorkspace.shared.open(link.url)
    }
    @objc private func checkForUpdates() { try? settings.editor.request(.checkForUpdates) }
    @objc private func showAbout() { Task { await settingsHost.present(paneID:"about",origin:.userInitiated) } }
    @objc private func refreshRows() {
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
