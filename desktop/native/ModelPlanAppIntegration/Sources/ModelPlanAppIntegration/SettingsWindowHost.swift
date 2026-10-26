// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanSettings

public enum SettingsPresentationOrigin: Sendable { case userInitiated, restoration, programmatic }

/// The app host checks lifecycle eligibility after asynchronous preparation and before ordering a window.
@MainActor public protocol SettingsWindowSurface: AnyObject {
    func prepare() async
    func show(paneID: String?)
    func hide()
}

@MainActor private final class NativeSettingsWindowSurface: SettingsWindowSurface {
    private let controller: SettingsWindowController
    init(editor: SettingsEditor, environment: @escaping @MainActor () -> SettingsEnvironment) {
        controller = SettingsWindowController(editor: editor, environmentProvider: environment)
    }
    func prepare() async { await controller.prepare() }
    func show(paneID: String?) {
        if let paneID { controller.selectPane(paneID) }
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
    }
    func hide() { controller.window?.orderOut(nil) }
}

/// Retain one per app. All Settings entry points share the existing application editor and one lazy window.
/// Activates only for explicit user entry; restoration/programmatic presentation never steals focus.
/// The native lifecycle owner supplies canPresent; no service permission is granted.
@MainActor public final class SettingsWindowHost: NSObject {
    public let application: SettingsApplicationCoordinator
    private let canPresent: @MainActor () -> Bool
    private let activate: @MainActor () -> Void
    private let environment: @MainActor () -> SettingsEnvironment
    private let makeSurface: @MainActor (SettingsEditor) -> any SettingsWindowSurface
    private var surface: (any SettingsWindowSurface)?
    private var request: UInt64 = 0

    public init(application: SettingsApplicationCoordinator,
                canPresent: @escaping @MainActor () -> Bool,
                environment: (@MainActor () -> SettingsEnvironment)? = nil,
                activate: @escaping @MainActor () -> Void = { NSApplication.shared.activate() },
                makeSurface: (@MainActor (SettingsEditor) -> any SettingsWindowSurface)? = nil) {
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
        self.application = application; self.canPresent = canPresent; self.environment = resolveEnvironment
        self.activate = activate
        self.makeSurface = makeSurface ?? { NativeSettingsWindowSurface(editor: $0, environment: resolveEnvironment) }
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
    }

    /// Lifecycle loss retires pending requests; resumption never opens Settings without a new user action.
    public func suspend() {
        request &+= 1
        surface?.hide()
    }
}
