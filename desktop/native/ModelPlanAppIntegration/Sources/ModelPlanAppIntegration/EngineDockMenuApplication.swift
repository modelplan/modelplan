// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanSettings

/// The rows-backed normal Dock/menu lifecycle. Legacy probe entry remains separate.
@MainActor public final class EngineDockMenuApplication: NSObject, NSApplicationDelegate, NSMenuDelegate {
    public let composition: EngineDockMenuComposition
    private let settings: SettingsApplicationCoordinator
    private var status: NSStatusItem?
    private var terminating = false
    private let makeSettingsSurface: (@MainActor (SettingsEditor) -> any SettingsWindowSurface)?
    private let makeConsole: (@MainActor (EngineDockMenuComposition) -> any EngineRowsConsoleSurface)?
    private var console: (any EngineRowsConsoleSurface)?
    private let activateSettings: @MainActor () -> Void
    public private(set) lazy var settingsHost = SettingsWindowHost(application: settings, canPresent: { [weak self] in self?.terminating == false }, activate: activateSettings, makeSurface: makeSettingsSurface)
    public init(configuration: EngineClientConfiguration, settingsStore: SettingsStore,
                createsNativePanels: Bool = true,
                makeClient: (@MainActor (EngineClientConfiguration, ModelPlanEngineStore.EngineStore) -> any EngineClient)? = nil,
                makeSettingsSurface: (@MainActor (SettingsEditor) -> any SettingsWindowSurface)? = nil,
                makeConsole: (@MainActor (EngineDockMenuComposition) -> any EngineRowsConsoleSurface)? = nil,
                activateSettings: @escaping @MainActor () -> Void = { NSApplication.shared.activate() }) {
        let composition = EngineDockMenuComposition(configuration: configuration, createsNativePanels: createsNativePanels, makeClient: makeClient)
        self.composition = composition
        self.makeSettingsSurface = makeSettingsSurface; self.makeConsole = makeConsole; self.activateSettings = activateSettings
        settings = SettingsApplicationCoordinator(store: settingsStore) { composition.dock.apply($0) }
        super.init()
        composition.menuDidChange = { [weak self] in self?.renderMenu(); self?.console?.render() }
        composition.dock.showSettings = settingsHost.action
        composition.dock.showConsole = { [weak self] in self?.showConsole() }
    }
    public func presentSettings() async { await settingsHost.present() }
    public func showConsole() {
        guard !terminating else { return }
        if console == nil { console = makeConsole?(composition) ?? EngineRowsConsole(composition: composition) }
        console?.show()
    }
    public func prepare() async { await settings.reload() }
    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        Task { await prepare(); composition.dock.setPresentationAllowed(true); renderMenu(); await composition.start() }
    }
    private func renderMenu() {
        let menu = NSMenu()
        let reading = NSMenuItem(title: composition.menuPresentation.detail, action: nil, keyEquivalent: "")
        reading.isEnabled = false; menu.addItem(reading)
        let refresh = menu.addItem(withTitle: "Refresh / 刷新", action: #selector(refreshRows), keyEquivalent: "")
        refresh.target = self
        menu.addItem(.separator())
        menu.addItem(settingsHost.menuItem(title: "Settings… / 设置…"))
        let consoleItem = menu.addItem(withTitle: "Dock readings… / Dock 读数…", action: #selector(showConsoleMenu), keyEquivalent: "")
        consoleItem.target = self
        menu.addItem(withTitle: "Quit / 退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.delegate = self; status?.menu = menu
        let image = CommunityMenuBarResources.templateImage()
        image?.isTemplate = true
        status?.button?.image = image; status?.button?.contentTintColor = nil
        status?.button?.title = composition.menuPresentation.title
        status?.button?.toolTip = composition.menuPresentation.detail
    }
    public func menuWillOpen(_ menu: NSMenu) { menu.items.first?.title = composition.menuPresentation.detail }
    @objc private func showConsoleMenu() { showConsole() }
    @objc private func refreshRows() { Task { await composition.refresh() } }
    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !terminating else { return .terminateLater }
        terminating = true; settingsHost.suspend(); console?.hide()
        Task { await composition.stop(); sender.reply(toApplicationShouldTerminate: true) }
        return .terminateLater
    }
}
