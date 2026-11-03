// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanInstruments
import ModelPlanSettings

/// Connects the real Dock surface to the same app-scoped hint arbiter and ledger
/// used by the existing Help composition. It creates no independent hint queue.
@MainActor final class DockHelpCoordinator {
    private weak var dock: StaticDockPreviewHost?
    private let application: SettingsApplicationCoordinator
    private let composition: InstrumentHelpComposition
    private let router: HelpOverlayRouter
    private var presenter: DockHelpPresenter?
    private var binding: DockHelpBinding?
    private var suspended = false
    private var retired = false
    var isInstalled: Bool { !retired && presenter != nil && binding != nil }

    private init(dock: StaticDockPreviewHost, application: SettingsApplicationCoordinator,
                 composition: InstrumentHelpComposition, router: HelpOverlayRouter) {
        self.dock = dock; self.application = application
        self.composition = composition; self.router = router
    }

    static func restored(dock: StaticDockPreviewHost,
                         application: SettingsApplicationCoordinator) async -> DockHelpCoordinator? {
        var routed: HelpOverlayRouter?
        let composition = await InstrumentHelpComposition.restored(application: application, overlayFactory: { cockpit in
            let router = HelpOverlayRouter(cockpit: cockpit)
            routed = router
            return router
        })
        guard let router = routed else { composition.dispose(); return nil }
        let owner = DockHelpCoordinator(dock: dock, application: application,
                                        composition: composition, router: router)
        owner.install()
        return owner
    }

    private func install() {
        guard let dock, !retired else { return }
        let presenter = DockHelpPresenter(currentSurface: { [weak dock] in dock?.currentDockHelpSurface },
            isCurrent: { [weak dock] surface in dock?.isCurrentDockHelpSurface(surface) == true },
            blockers: { [weak dock] surface in dock?.dockHelpBlockingRects(surface) ?? [] },
            windowPolicy: { [weak dock] surface in dock?.dockHelpWindowPolicy(surface) },
            language: { [weak self] in self?.application.latest?.effective.language == .chinese ? .chinese : .english },
            accessibility: { [weak self] in
                let effective = self?.application.latest?.effective
                return (effective?.reduceMotion ?? true, effective?.reduceTransparency ?? true)
            }, copy: { kind, language in
                let zh = language == .chinese
                switch kind {
                case .ignition: return (zh ? "点按打开驾驶舱" : "Tap to open Cockpit", zh ? "关闭" : "Close")
                case .drag: return (zh ? "拖喷口换顺序，拖底座换到别的边" : "Drag a nozzle to reorder; drag the base to move to another edge", zh ? "关闭" : "Close")
                case .pinned: return (zh ? "已固定；使用关闭按钮收起" : "Pinned. Use Close to dismiss.", zh ? "关闭" : "Close")
                default: return nil
                }
            }, dismiss: { [weak self] _ in self?.composition.host.dismiss() })
        let binding = DockHelpBinding(presenter: presenter,
            isCurrent: { [weak dock] surface in dock?.isCurrentDockHelpSurface(surface) == true })
        self.presenter = presenter; self.binding = binding
        router.installDock(binding)
        dock.dockHelpSurfaceDidChange = { [weak self] surface in self?.update(surface) }
    }

    private func update(_ surface: DockHelpSurface?) {
        guard !retired, !suspended, let binding else { return }
        let eligible = application.latest?.snapshot.preferences.onboarding.completed == true
        let admittedSurface = eligible ? surface : nil
        var context = composition.host.hints.context
        context.ignitionAvailable = dock?.cockpitEntryEnabled == true
        context.cardPinned = admittedSurface?.anchors[.pinned] != nil
        context.reducedMotion = application.latest?.effective.reduceMotion ?? true
        do {
            if !composition.host.isRunning { try composition.host.resume(context: context) }
            try binding.update(admittedSurface, context: context, host: composition.host)
        } catch {
            // Do not mark an unverified offer as shown on invalid geometry or time.
            composition.host.suspend()
        }
    }

    func refresh() { update(dock?.currentDockHelpSurface) }
    func suspend() {
        guard !retired, !suspended else { return }
        suspended = true
        if let binding { try? binding.update(nil, context: composition.host.hints.context, host: composition.host) }
        composition.host.suspend()
    }
    func resume() {
        guard !retired, suspended else { return }
        suspended = false
        update(dock?.currentDockHelpSurface)
    }
    func dispose() async {
        guard !retired else { return }
        retired = true; dock?.dockHelpSurfaceDidChange = nil
        if let binding { try? binding.retire(context: composition.host.hints.context, host: composition.host) }
        router.installDock(nil); presenter?.dispose(); presenter = nil; binding = nil
        await composition.flush()
        composition.dispose()
    }
}
