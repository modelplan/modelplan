// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanSettings
import ModelPlanCommunityHost

@MainActor private final class ConnectionFirstRunSurface: SettingsWindowSurface {
    private let controller: SettingsFirstRunController
    init(editor: SettingsEditor) { controller = SettingsFirstRunController(editor: editor) }
    func prepare() async { await controller.prepare() }
    func show(paneID: String?) { controller.showWindow(nil); controller.window?.makeKeyAndOrderFront(nil) }
    func hide() { controller.suspend(); controller.window?.orderOut(nil) }
}

/// App composition retains this module over its existing editor. Construction has no backend/UI effects.
@MainActor public final class CommunityConnectionFlow {
    public let application: SettingsApplicationCoordinator
    private let canPresent: @MainActor () -> Bool
    private let showSettings: @MainActor (String?) async -> Void
    private let activate: @MainActor () -> Void
    private let makeFirstRun: @MainActor (SettingsEditor) -> any SettingsWindowSurface
    private var surface: (any SettingsWindowSurface)?
    private var generation: UInt64 = 0
    private var observer: UUID?, navigation: UUID?
    private var projected: SettingsConnectionSnapshot?
    private var disposed = false

    public init(application: SettingsApplicationCoordinator, backend: (any SettingsConnectionAllowing)? = nil,
                canPresent: @escaping @MainActor () -> Bool,
                showSettings: @escaping @MainActor (String?) async -> Void,
                activate: @escaping @MainActor () -> Void = {},
                makeFirstRun: (@MainActor (SettingsEditor) -> any SettingsWindowSurface)? = nil) throws {
        self.application = application; self.canPresent = canPresent; self.showSettings = showSettings
        self.activate = activate; self.makeFirstRun = makeFirstRun ?? { ConnectionFirstRunSurface(editor: $0) }
        let editor = application.editor
        navigation = editor.bindFirstRunPresentation({ [weak self] in Task { await self?.openFirstRun() } },
            about: { [weak self] in Task { await self?.perform(.about) } })
        guard let navigation else { throw SettingsConnectionFailure.unavailable }
        if let backend, !editor.connections.bind(service: backend) {
            editor.unbindFirstRunPresentation(navigation); self.navigation = nil
            throw SettingsConnectionFailure.unavailable
        }
        observer = editor.connections.observe { [weak self] in self?.projectCurrentSnapshot() }
        var context = editor.context; context.capabilities.firstRunPreviewAvailable = true
        application.update(context: context)
        projectCurrentSnapshot()
    }
    deinit {
        let editor = application.editor, observer = observer, navigation = navigation
        Task { @MainActor in
            if let observer { editor.connections.removeObserver(observer) }
            if let navigation { editor.unbindFirstRunPresentation(navigation) }
        }
    }
    /// Read-only facts and safe bundled About input come from the same existing runtime.
    public func apply(_ facts: CommunityConnectionFacts) {
        guard !disposed else { return }
        application.editor.connections.receive(facts.connections)
        guard !disposed, application.editor.connections.snapshot == facts.connections else { return }
        projected = facts.connections
        application.update(context: facts.updating(application.editor.context))
    }
    private func projectCurrentSnapshot() {
        guard !disposed, let value = application.editor.connections.snapshot, value != projected else { return }
        projected = value // Set before notifying the shared application/editor observers.
        application.update(context: CommunityConnectionFacts(connections: value).updating(application.editor.context))
    }
    public func restoreFirstRunIfNeeded() async {
        generation &+= 1; let token = generation
        guard !disposed, !Task.isCancelled else { return }
        await application.reload()
        guard !disposed, generation == token, !Task.isCancelled else { return }
        // Restore canonical admission even when onboarding is complete or no window may be shown.
        await application.editor.connections.refresh()
        guard !disposed, generation == token, !Task.isCancelled,
              application.editor.snapshot?.preferences.onboarding.completed == false else { return }
        await showFirstRun(token: token, userInitiated: false, inspect: false)
    }
    public func openFirstRun() async { await route(.allowUsage, forceFirstRun: true) }
    public func openSettings() async { await route(nil) }
    public func perform(_ destination: CommunityConnectionDestination) async { await route(destination) }
    public func action(for step: CommunityConnectionNextStep) -> @MainActor () -> Void {
        { [weak self] in Task { await self?.perform(step.destination) } }
    }
    private func route(_ destination: CommunityConnectionDestination?, forceFirstRun: Bool = false,
                       userInitiated: Bool = true) async {
        generation &+= 1; let token = generation
        guard eligible(token) else { return }
        await application.reload()
        guard eligible(token), let saved = application.editor.snapshot else { return }
        let incomplete = !saved.preferences.onboarding.completed
        let firstRun = forceFirstRun || (incomplete && destination != .about)
        if !firstRun {
            guard eligible(token) else { return }
            await showSettings(destination == .about ? "about" : destination == nil ? nil : "subscriptions")
            return
        }
        await showFirstRun(token: token, userInitiated: userInitiated, inspect: true)
    }
    private func showFirstRun(token: UInt64, userInitiated: Bool, inspect: Bool) async {
        // Presence/preview only; the injected backend owns canonical gate restoration.
        if inspect { await application.editor.connections.refresh() }
        guard eligible(token) else { return }
        if surface == nil { surface = makeFirstRun(application.editor) }
        guard let surface, eligible(token) else { return }
        await surface.prepare()
        guard eligible(token) else { return }
        if userInitiated { activate() }
        guard eligible(token) else { return }
        surface.show(paneID: nil)
    }
    private func eligible(_ token: UInt64) -> Bool { !disposed && generation == token && canPresent() && !disposed && generation == token }
    public func requireBackend() throws {
        guard application.editor.connections.hasAllowanceBackend else { throw CommunityConnectionWiringError.backendMissing }
    }
    public func suspend() {
        generation &+= 1; application.editor.connections.cancel(); surface?.hide()
    }
    public func dispose() {
        guard !disposed else { return }; disposed = true; suspend()
        let editor = application.editor
        if let observer { editor.connections.removeObserver(observer); self.observer = nil }
        if let navigation { editor.unbindFirstRunPresentation(navigation); self.navigation = nil }
    }
}

/// Wrap the existing session in the private entry; no root-host protocol or second editor is needed.
@MainActor public final class CommunityConnectionIntegration: NSObject, CommunitySettingsIntegration {
    public let flow: CommunityConnectionFlow
    private let base: any CommunitySettingsIntegration
    private var restoration: Task<Void, Never>?
    private var restorationGeneration: UInt64 = 0
    private var restored = false
    public private(set) lazy var settingsMenuItem: NSMenuItem = {
        let item = NSMenuItem(title: base.settingsMenuItem.title, action: #selector(openSettings), keyEquivalent: ",")
        item.keyEquivalentModifierMask = .command; item.target = self; return item
    }()
    public init(base: any CommunitySettingsIntegration, flow: CommunityConnectionFlow) throws {
        try flow.requireBackend()
        self.base = base; self.flow = flow
    }
    @objc private func openSettings() { Task { await flow.openSettings() } }
    public func restorePreferences() async {
        guard !restored else { return }
        if let restoration { await restoration.value; return }
        let token = restorationGeneration
        let task = Task { @MainActor [weak self, base, flow] in
            await base.restorePreferences()
            guard let self, self.restorationGeneration == token, !Task.isCancelled else { return }
            await flow.restoreFirstRunIfNeeded()
            guard self.restorationGeneration == token, !Task.isCancelled else { return }
            self.restored = true
        }
        restoration = task
        await task.value
        if restorationGeneration == token { restoration = nil }
    }
    public func suspend() {
        restorationGeneration &+= 1; restoration?.cancel(); restoration = nil
        flow.suspend(); base.suspend()
    }
}

public enum CommunityConnectionWiringError: Error, Equatable { case entryMissing, backendMissing, differentApplication, differentBackend }
/// The actual entry's construction test must call this on its returned integration, not a parallel fixture.
@MainActor public enum CommunityConnectionWiring {
    public static func requireInstalled(_ entry: any CommunitySettingsIntegration,
                                        application: SettingsApplicationCoordinator,
                                        backend: any SettingsConnectionAllowing) throws {
        guard let entry = entry as? CommunityConnectionIntegration else { throw CommunityConnectionWiringError.entryMissing }
        guard entry.flow.application === application else { throw CommunityConnectionWiringError.differentApplication }
        try entry.flow.requireBackend()
        guard application.editor.connections.isBound(to: backend) else { throw CommunityConnectionWiringError.differentBackend }
    }
}
