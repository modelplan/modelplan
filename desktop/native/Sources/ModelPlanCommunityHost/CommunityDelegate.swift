// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanCore
import ModelPlanShell

@MainActor public final class CommunityDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var status: NSStatusItem?
    private let surfaces: any NativeSurfaceProvider
    private let injectedTransport: (any CLITransport)?
    private let statusItemTitle: String
    private let statusItemImage: NSImage?
    private let menuBarProvider: (any CommunityMenuBarProviding)?
    public private(set) var menuBarPresentation = CommunityMenuBarPresentation.empty
    public private(set) lazy var menuBarReadingItem: NSMenuItem = {
        let item = NSMenuItem(title: menuBarPresentation.detail, action: nil, keyEquivalent: "")
        item.isEnabled = false; return item
    }()
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
                statusItemImage: NSImage? = nil, menuBarProvider: (any CommunityMenuBarProviding)? = nil,
                makeSettings: (@MainActor (LifecycleCoordinator) throws -> any CommunitySettingsIntegration)? = nil) {
        self.surfaces = surfaces; self.companion = companion; self.makeSettings = makeSettings
        self.injectedTransport = transport; self.statusItemTitle = statusItemTitle
        self.statusItemImage = (statusItemImage ?? NSImage(named: NSImage.actionTemplateName))?.copy() as? NSImage
        self.menuBarProvider = menuBarProvider
        self.statusItemImage?.isTemplate = true; self.statusItemImage?.size = .init(width: 18, height: 18)
        super.init()
    }
    /// A single runtime/store owns either the explicit preview feed or the pinned live helper.
    func makeRuntime() -> CommunityRuntime {
        CommunityRuntime(transport: injectedTransport ?? BundledCLI(bundle: Bundle.main.bundleURL))
    }

    /// Normal runtime composition, separate from starting OS events or creating a status item.
    @discardableResult func configureRuntime() -> CommunityRuntime {
        if let runtime { return runtime }
        let runtime = makeRuntime(); self.runtime = runtime
        runtime.store.onChange = { [weak self] in self?.render() }
        return runtime
    }
    /// Re-evaluate the existing store view after a Settings receipt; no producer/CLI refresh is enqueued.
    public func refreshMenuBar() {
        guard let runtime, !terminating else { return }
        updateMenuBar(snapshot: runtime.store.view(), diagnostics: runtime.store.diagnostics, now: Date())
    }

    /// Read-only references to the actual retained composition; never inferred from status flags.
    public var settingsIntegration: (any CommunitySettingsIntegration)? { settings }
    public var companionSurface: (any CommunityCompanionSurface)? { companion }

    /// Retain Settings once and schedule its normal restore under the caller's presentation gate.
    /// Does not start the app runtime or OS events; restore may inspect the bundled consent component.
    @discardableResult public func configureSettings(_ gate: LifecycleCoordinator) -> NSMenuItem? {
        guard let makeSettings else { return nil }
        guard !settingsConfigured else { return settingsItem }
        settingsConfigured = true
        do {
            let integration = try makeSettings(gate); settings = integration
            settingsItem = integration.settingsMenuItem
            Task { await integration.restorePreferences() }
        } catch {
            // Preserve malformed/unavailable preferences; do not create a replacement store or expose paths.
            let item = NSMenuItem(title: "Settings could not open — quit and reopen ModelPlan / 设置未能打开，请退出并重新打开 ModelPlan", action: nil, keyEquivalent: "")
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
        let appVisible = NSApp?.isHidden != true
        runtime?.store.setSurfacesVisible(
            dock: appVisible && (companion as? any CommunityCompanionVisibility)?.isVisible == true,
            cockpit: appVisible && window?.isVisible == true && window?.isMiniaturized == false)
    }
    public func applicationDidHide(_ notification: Notification) { updateFeedVisibility() }
    public func applicationDidUnhide(_ notification: Notification) { updateFeedVisibility() }
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
        let runtime = configureRuntime()
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
        let menu = NSMenu()
        menu.addItem(menuBarReadingItem); menu.addItem(.separator())
        let show = menu.addItem(withTitle: "Status…", action: #selector(showStatus), keyEquivalent: "")
        show.target = self
        menu.addItem(withTitle: "Intel untested; 3D may stutter", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        if let settingsItem = configureSettings(runtime.lifecycle) { menu.addItem(settingsItem) }
        if let remediation = settings as? any CommunityUsageRemediation { menu.addItem(remediation.usageAccessMenuItem) }
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu; status = item
        if let settingsItem { NSApplication.shared.mainMenu = applicationMenu(settingsItem: settingsItem) }
        configureCompanion(runtime.lifecycle)
        render()
        runtime.start()
    }
    /// Used by the normal Status window path; binding does not construct or show a window.
    func configureOverview(_ surface: any NativeOverviewSurface) {
        overview = surface
        if let consumer = surface as? any CommunityInstrumentSurface {
            consumer.requestFreshSelection = { [weak self] in self?.render() }
            consumer.contentSizeChanged = { [weak self, weak surface] in
                guard let self, let surface, self.overview === surface,
                      let consumer = surface as? any CommunityInstrumentSurface,
                      self.window?.contentView === surface.view else { return }
                self.window?.setContentSize(consumer.preferredContentSize)
            }
        }
        if let navigation = surface as? any CommunityInstrumentSettingsRouting {
            navigation.requestSubscriptionsSettings = { [weak self, weak surface] in
                guard let self, let surface, !self.terminating, self.overview === surface,
                      (surface as? any CommunityInstrumentSurface)?.isPresented == true,
                      let settings = self.settings as? any CommunitySubscriptionsSettingsPresenting else { return }
                await settings.presentSubscriptionsSettings()
            }
        }
    }
    @objc private func showStatus() {
        guard let runtime, !terminating, runtime.lifecycle.canPresent else { return }
        if window == nil {
            let surface = surfaces.makeOverview()
            configureOverview(surface)
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
        updateMenuBar(snapshot: snapshot, diagnostics: diagnostics, now: Date())
        (settings as? any CommunityUsageRemediation)?.updateUsageState(snapshot: snapshot, diagnostics: diagnostics, now: Date())
        companion?.render(snapshot: snapshot, diagnostics: diagnostics)
        overview?.render(snapshot: snapshot, diagnostics: diagnostics)
        (overview as? any CommunityPublicCatalogueConsumer)?.render(publication: runtime.store.modelSelectionFeeds().publication)
        if runtime.lifecycle.canPresent, let consumer = overview as? any CommunityInstrumentSurface, consumer.isPresented {
            let selection = runtime.selection(for: consumer)
            consumer.render(selection: selection, publishedAt: runtime.store.modelSelectionFeeds().publication?.publishedAt?.date, now: Date())
        }
    }
    /// Shared by the real status button and in-memory construction checks; never creates an item/window.
    func updateMenuBar(snapshot: JoinedSnapshot?, diagnostics: StoreDiagnostics, now: Date, button: NSButton? = nil) {
        let next = menuBarProvider?.make(snapshot: snapshot, diagnostics: diagnostics, now: now) ?? .empty
        menuBarPresentation = next; menuBarReadingItem.title = next.detail
        guard let button = button ?? status?.button else { return }
        statusItemImage?.isTemplate = true
        button.image = statusItemImage
        button.imageScaling = .scaleProportionallyDown
        button.contentTintColor = nil
        button.attributedTitle = NSAttributedString(string: next.title)
        button.imagePosition = next.title.isEmpty ? .imageOnly : .imageLeading
        button.toolTip = statusItemTitle + " — " + next.detail
        button.setAccessibilityLabel(statusItemTitle + " — " + next.detail)
    }
    public func windowWillClose(_ notification: Notification) {
        guard let closing = notification.object as? NSWindow, closing === window else { return }
        restoreWindow = false
        runtime?.store.setSurfacesVisible(dock: NSApp?.isHidden != true && (companion as? any CommunityCompanionVisibility)?.isVisible == true, cockpit: false)
        (overview as? any CommunityInstrumentSurface)?.closePresentation()
    }
    /// The existing serialized store/transport owns the refresh; no new timer, helper or window is created.
    public func refreshAfterCanonicalConsent() {
        guard !terminating else { return }
        runtime?.store.refresh()
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
