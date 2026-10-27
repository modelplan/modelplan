// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanCore
import ModelPlanShell

@MainActor public final class CommunityDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var status: NSStatusItem?
    private let surfaces: any NativeSurfaceProvider
    private let injectedTransport: (any CLITransport)?
    private let statusItemTitle: String
    private let companion: (any CommunityCompanionSurface)?
    private let makeSettings: (@MainActor (LifecycleCoordinator) throws -> any CommunitySettingsIntegration)?
    private var settings: (any CommunitySettingsIntegration)?
    private var settingsItem: NSMenuItem?
    private var settingsConfigured = false
    private var overview: (any NativeOverviewSurface)?
    private var window: NSWindow?
    private var runtime: CommunityRuntime?
    private var probe: RuntimeProbe?
    private var restoreWindow = false
    private var terminating = false
    public init(surfaces: any NativeSurfaceProvider,
                companion: (any CommunityCompanionSurface)? = nil,
                transport: (any CLITransport)? = nil, statusItemTitle: String = "ModelPlan",
                makeSettings: (@MainActor (LifecycleCoordinator) throws -> any CommunitySettingsIntegration)? = nil) {
        self.surfaces = surfaces; self.companion = companion; self.makeSettings = makeSettings
        self.injectedTransport = transport; self.statusItemTitle = statusItemTitle; super.init()
    }
    /// A single runtime/store owns either the explicit preview feed or the pinned live helper.
    func makeRuntime() -> CommunityRuntime {
        CommunityRuntime(transport: injectedTransport ?? BundledCLI(bundle: Bundle.main.bundleURL))
    }

    /// Initialization does not start the CLI, events or application; the normal launch route calls this once.
    func configureSettings(_ gate: LifecycleCoordinator) -> NSMenuItem? {
        guard let makeSettings else { return nil }
        guard !settingsConfigured else { return settingsItem }
        settingsConfigured = true
        do {
            let integration = try makeSettings(gate); settings = integration
            settingsItem = integration.settingsMenuItem
            Task { await integration.restorePreferences() }
        } catch {
            // Preserve malformed/unavailable preferences; do not create a replacement store or expose paths.
            let item = NSMenuItem(title: "Settings unavailable / 设置不可用", action: nil, keyEquivalent: "")
            item.isEnabled = false; settingsItem = item
        }
        return settingsItem
    }
    func suspendSettings() { settings?.suspend() }
    /// Called only by the normal launch route, after the shared Settings integration is configured.
    func configureCompanion(_ gate: LifecycleCoordinator) {
        companion?.showConsole = { [weak self, weak gate] in
            guard gate?.canPresent == true else { return }
            self?.showStatus()
        }
        companion?.showSettings = { [weak self, weak gate] in
            guard gate?.canPresent == true, let self, !self.terminating, let item = self.settingsItem,
                  item.isEnabled, let action = item.action else { return }
            NSApplication.shared.sendAction(action, to: item.target, from: item)
        }
        (companion as? any CommunityCompanionVisibility)?.visibilityChanged = { [weak self] in
            self?.updateFeedVisibility()
        }
        companion?.setPresentationAllowed(gate.canPresent)
        updateFeedVisibility()
    }
    func updateFeedVisibility() {
        runtime?.store.setSurfacesVisible(
            dock: (companion as? any CommunityCompanionVisibility)?.isVisible == true,
            cockpit: window?.isVisible == true && window?.isMiniaturized == false)
    }
    private func closeCompanion() {
        (companion as? any CommunityCompanionVisibility)?.visibilityChanged = nil
        companion?.setPresentationAllowed(false)
        companion?.showConsole = nil; companion?.showSettings = nil
        companion?.close()
    }
    /// A status-item menu alone is not the app's Command-comma responder menu.
    func applicationMenu(settingsItem: NSMenuItem) -> NSMenu {
        let root = NSMenu(), applicationItem = NSMenuItem(title: "ModelPlan", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        if let copy = settingsItem.copy() as? NSMenuItem { submenu.addItem(copy) }
        submenu.addItem(.separator())
        submenu.addItem(withTitle: "Quit / 退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        applicationItem.submenu = submenu; root.addItem(applicationItem)
        return root
    }
    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let args = CommandLine.arguments
        if let at = args.firstIndex(of: "--access-probe"), args.count > at + 2 {
            let home = URL(fileURLWithPath: args[at + 1], isDirectory: true)
            let output = URL(fileURLWithPath: args[at + 2])
            Task {
                await AccessProbe.run(home: home, result: output)
                NSApp.terminate(nil)
            }
            return
        }
        if let at = args.firstIndex(of: "--runtime-probe"), args.count > at + 3,
           let duration = Double(args[at + 3]), duration >= 1, duration <= 120 {
            probe = RuntimeProbe(home: URL(fileURLWithPath: args[at + 1]), output: URL(fileURLWithPath: args[at + 2]), duration: duration)
            probe?.start(); return
        }
        let runtime = makeRuntime()
        self.runtime = runtime
        runtime.store.onChange = { [weak self] in self?.render() }
        runtime.lifecycle.onPresentationChange = { [weak self] allowed in
            guard let self, !self.terminating else { return }
            if !allowed {
                self.companion?.setPresentationAllowed(false)
                self.restoreWindow = self.window?.isVisible == true; self.window?.orderOut(nil)
                self.suspendSettings()
                (self.overview as? any CommunityInstrumentSurface)?.suspendPresentation()
                self.updateFeedVisibility()
            } else {
                self.render()
                self.companion?.setPresentationAllowed(true)
                if self.restoreWindow { self.window?.orderFront(nil); self.restoreWindow = false; (self.overview as? any CommunityInstrumentSurface)?.resumePresentation() }
                self.updateFeedVisibility()
            }
        }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = statusItemTitle
        let menu = NSMenu()
        let show = menu.addItem(withTitle: "Status…", action: #selector(showStatus), keyEquivalent: "")
        show.target = self
        menu.addItem(withTitle: "Intel untested; 3D may stutter", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        if let settingsItem = configureSettings(runtime.lifecycle) { menu.addItem(settingsItem) }
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu; status = item
        if let settingsItem { NSApplication.shared.mainMenu = applicationMenu(settingsItem: settingsItem) }
        configureCompanion(runtime.lifecycle)
        render()
        runtime.start()
    }
    @objc private func showStatus() {
        guard let runtime, !terminating, runtime.lifecycle.canPresent else { return }
        if window == nil {
            let surface = surfaces.makeOverview(); overview = surface
            if let consumer = surface as? any CommunityInstrumentSurface {
                consumer.requestFreshSelection = { [weak self] in self?.render() }
                consumer.contentSizeChanged = { [weak self, weak surface] in
                    guard let self, let surface, self.overview === surface,
                          let consumer = surface as? any CommunityInstrumentSurface,
                          self.window?.contentView === surface.view else { return }
                    self.window?.setContentSize(consumer.preferredContentSize)
                }
            }
            let size = (surface as? any CommunityInstrumentSurface)?.preferredContentSize ?? CGSize(width:440,height:210)
            let panel = NSWindow(contentRect:NSRect(origin:.zero,size:size),
                styleMask:[.titled,.closable],backing:.buffered,defer:false)
            panel.title = "ModelPlan Community"; panel.contentView = surface.view
            panel.isReleasedWhenClosed = false; panel.delegate = self; panel.center(); window = panel
        }
        render(); runtime.store.refresh()
        guard runtime.lifecycle.canPresent else { return }
        NSApp.activate(ignoringOtherApps:true)
        guard runtime.lifecycle.canPresent else { return }
        window?.makeKeyAndOrderFront(nil)
        (overview as? any CommunityInstrumentSurface)?.resumePresentation()
        updateFeedVisibility()
    }
    private func render() {
        guard let runtime, !terminating else { return }
        let snapshot = runtime.store.view(), diagnostics = runtime.store.diagnostics
        companion?.render(snapshot: snapshot, diagnostics: diagnostics)
        overview?.render(snapshot: snapshot, diagnostics: diagnostics)
        if runtime.lifecycle.canPresent, let consumer = overview as? any CommunityInstrumentSurface, consumer.isPresented {
            let selection = runtime.modelSelection.evaluate(scope: .all, selectedID: consumer.selectedModelID,
                                                            language: consumer.instrumentLanguage)
            consumer.render(selection: selection, publishedAt: runtime.store.modelSelectionFeeds().publication?.publishedAt?.date, now: Date())
        }
    }
    public func windowWillClose(_ notification: Notification) {
        guard let closing = notification.object as? NSWindow, closing === window else { return }
        restoreWindow = false
        runtime?.store.setSurfacesVisible(dock: (companion as? any CommunityCompanionVisibility)?.isVisible == true, cockpit: false)
        (overview as? any CommunityInstrumentSurface)?.closePresentation()
    }
    public func windowDidMiniaturize(_ notification: Notification) { updateFeedVisibility() }
    public func windowDidDeminiaturize(_ notification: Notification) { updateFeedVisibility() }
    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let runtime else { return .terminateNow }
        guard !terminating else { return .terminateLater }
        terminating = true
        closeCompanion()
        (overview as? any CommunityInstrumentSurface)?.suspendPresentation()
        Task { await runtime.stop(); sender.reply(toApplicationShouldTerminate: true) }
        return .terminateLater
    }
}
