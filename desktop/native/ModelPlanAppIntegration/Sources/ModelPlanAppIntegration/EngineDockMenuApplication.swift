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
    public init(configuration: EngineClientConfiguration, settingsStore: SettingsStore,
                createsNativePanels: Bool = true,
                makeClient: (@MainActor (EngineClientConfiguration, ModelPlanEngineStore.EngineStore) -> any EngineClient)? = nil) {
        let composition = EngineDockMenuComposition(configuration: configuration, createsNativePanels: createsNativePanels, makeClient: makeClient)
        self.composition = composition
        settings = SettingsApplicationCoordinator(store: settingsStore) { composition.dock.apply($0) }
        super.init()
        composition.menuDidChange = { [weak self] in self?.renderMenu() }
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
        menu.addItem(withTitle: "Quit / 退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.delegate = self; status?.menu = menu
        let image = CommunityMenuBarResources.templateImage()
        image?.isTemplate = true
        status?.button?.image = image; status?.button?.contentTintColor = nil
        status?.button?.title = composition.menuPresentation.title
        status?.button?.toolTip = composition.menuPresentation.detail
    }
    public func menuWillOpen(_ menu: NSMenu) { menu.items.first?.title = composition.menuPresentation.detail }
    @objc private func refreshRows() { Task { await composition.refresh() } }
    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !terminating else { return .terminateLater }
        terminating = true
        Task { await composition.stop(); sender.reply(toApplicationShouldTerminate: true) }
        return .terminateLater
    }
}
