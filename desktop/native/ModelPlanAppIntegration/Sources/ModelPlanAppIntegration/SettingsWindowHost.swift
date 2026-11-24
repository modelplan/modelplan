// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanSettings
import ModelPlanShell

public enum SettingsPresentationOrigin: Sendable { case userInitiated, restoration, programmatic }

/// The app host checks lifecycle eligibility after asynchronous preparation and before ordering a window.
@MainActor public protocol SettingsWindowSurface: AnyObject {
    func prepare() async
    func show(paneID: String?)
    func hide()
}

/// While Settings is open the app is a regular app (Dock icon, standard main menu, so Command-comma, -W and -Q
/// work). Native-shell spec item 4: the app's one `PulseDockPresence` decides, so closing Settings while a detached
/// cockpit is open keeps the Dock icon (the old Settings-only presence dropped it).
@MainActor final class NativeSettingsWindowSurface: SettingsWindowSurface {
    private let presence: PulseDockPresence
    private var closeObserver: NSObjectProtocol?
    private let controller: SettingsWindowController
    init(editor: SettingsEditor, environment: @escaping @MainActor () -> SettingsEnvironment, scopeConsentEntry: ScopeConsentEntry?,
         presence: PulseDockPresence) {
        controller = SettingsWindowController(editor: editor, environmentProvider: environment, scopeConsentEntry: scopeConsentEntry)
        self.presence = presence
        // G3-161: an engine update does not rebuild Settings while its window is closed; showing it refreshes once.
        controller.defersContextRefreshWhileHidden = true
    }
    func prepare() async { await controller.prepare() }
    func show(paneID: String?) {
        if let paneID { controller.selectPane(paneID) }
        controller.showWindow(nil)
        if let window = controller.window {
            presence.track(window)
            if closeObserver == nil {
                closeObserver = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self, weak window] _ in
                    MainActor.assumeIsolated { self?.presence.apply(closing: window) }
                }
            }
        }
        // The host activates for user entry; a restoration or programmatic open never steals focus.
        presence.apply()
        controller.window?.makeKeyAndOrderFront(nil)
    }
    func hide() { controller.window?.orderOut(nil); presence.apply(closing: controller.window) }
    func attachCockpitPlugins(_ model: CockpitPluginSettingsModel) { controller.attachCockpitPlugins(model) }
}

/// Retain one per app. All Settings entry points share the existing application editor and one lazy window.
/// Activates only for explicit user entry; restoration/programmatic presentation never steals focus.
/// The native lifecycle owner supplies canPresent; no service permission is granted.
@MainActor public final class SettingsWindowHost: NSObject {
    public let application: SettingsApplicationCoordinator
    let scopeConsentEntry: ScopeConsentEntry?
    private let canPresent: @MainActor () -> Bool
    private let activate: @MainActor () -> Void
    private let environment: @MainActor () -> SettingsEnvironment
    private let makeSurface: @MainActor (SettingsEditor) -> any SettingsWindowSurface
    private var surface: (any SettingsWindowSurface)? {
        didSet { attachPlugins() }
    }
    /// Settings › Plugins (switch, interval, pin to page 1) edits this model.
    public var cockpitPlugins: CockpitPluginSettingsModel? { didSet { attachPlugins() } }
    private func attachPlugins() {
        guard let cockpitPlugins, let native = surface as? NativeSettingsWindowSurface else { return }
        native.attachCockpitPlugins(cockpitPlugins)
    }
    private var request: UInt64 = 0

    public init(application: SettingsApplicationCoordinator,
                canPresent: @escaping @MainActor () -> Bool,
                environment: (@MainActor () -> SettingsEnvironment)? = nil,
                activate: @escaping @MainActor () -> Void = { NSApplication.shared.activate() },
                scopeConsentEntry: ScopeConsentEntry? = nil,
                presence: PulseDockPresence? = nil,
                makeSurface: (@MainActor (SettingsEditor) -> any SettingsWindowSurface)? = nil) {
        let presence = presence ?? PulseDockPresence(currentPolicy: { NSApplication.shared.activationPolicy() },
            setPolicy: { _ = NSApplication.shared.setActivationPolicy($0) }, activate: { NSApplication.shared.activate() })
        let resolveEnvironment: @MainActor () -> SettingsEnvironment = environment ?? {
            // OS UI observations cannot replace app-owned fullscreen or entrance acceptance.
            var current = application.editor.environment
            let observed = SettingsWindowController.systemEnvironment()
            current.darkAppearance = observed.darkAppearance
            current.reduceMotion = observed.reduceMotion
            current.reduceTransparency = observed.reduceTransparency
            current.increaseContrast = observed.increaseContrast
            current.macOSMajor = observed.macOSMajor
            return current
        }
        self.application = application; self.scopeConsentEntry = scopeConsentEntry; self.canPresent = canPresent; self.environment = resolveEnvironment
        self.activate = activate
        self.makeSurface = makeSurface ?? { NativeSettingsWindowSurface(editor: $0, environment: resolveEnvironment, scopeConsentEntry: scopeConsentEntry, presence: presence) }
        super.init()
    }

    /// Gear and other app-owned buttons may call this; the returned action retains no window or host.
    public var action: @MainActor () -> Void { { [weak self] in self?.showSettings(nil) } }

    /// Reuse this action for the tray item and the Settings menu's reserved Command-comma shortcut.
    public func menuItem(title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(showSettings(_:)), keyEquivalent: ",")
        item.keyEquivalentModifierMask = .command; item.target = self
        return item
    }
    @objc private func showSettings(_ sender: Any?) {
        request &+= 1
        let current = request
        Task { [weak self] in
            guard let self, self.request == current else { return }
            await self.present(origin: .userInitiated)
        }
    }

    public func present(paneID: String? = nil, origin: SettingsPresentationOrigin = .programmatic) async {
        request &+= 1
        let current = request
        guard canPresent() else { return }
        application.update(environment: environment())
        await application.reload()
        guard current == request, canPresent() else { return }
        if surface == nil { surface = makeSurface(application.editor) }
        guard let surface else { return }
        await surface.prepare()
        guard current == request, canPresent() else { return }
        // The surface may reload its shared editor while preparing; forward that committed truth too.
        await application.reload()
        guard current == request, canPresent() else { return }
        if case .userInitiated = origin { activate() }
        guard current == request, canPresent() else { return }
        surface.show(paneID: paneID)
        // The first activation ran while the app was still an accessory; once Settings has made it a regular app
        // (menu bar, Dock icon) activate again on the next turn so the menu bar and window really come forward.
        if case .userInitiated = origin { await Task.yield(); guard current == request else { return }; activate() }
    }

    /// Lifecycle loss retires pending requests; resumption never opens Settings without a new user action.
    public func suspend() {
        request &+= 1
        surface?.hide()
    }
}
