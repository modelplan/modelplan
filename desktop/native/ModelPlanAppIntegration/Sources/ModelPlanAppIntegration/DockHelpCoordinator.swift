// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanCockpitWeb
import ModelPlanInstruments
import ModelPlanSettings

struct DockStatusHelpAnchor {
    let frame: CGRect
    let sharing: NSWindow.SharingType
    let collection: NSWindow.CollectionBehavior
}

/// A status-menu focus return is valid only for the user dismissal of its own map.
struct DockStatusHelpDismissal {
    private var requestID: UUID?
    mutating func arm(_ id: UUID?) { requestID = id }
    mutating func take(reason: HelpUIDismissReason?) -> UUID? {
        let id = requestID; requestID = nil
        guard reason == .escape || reason == .pointer else { return nil }
        return id
    }
}

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
    private let statusAnchor: @MainActor () -> DockStatusHelpAnchor?
    /// D88: the open cockpit's detach / put-back key, for its two one-time hints.
    private let cockpitAnchor: @MainActor () -> CockpitAttachmentHintAnchor?
    private var cockpitSurface: DockHelpSurface?
    private let statusRequestID: @MainActor () -> UUID?
    private let statusDidDismiss: @MainActor (UUID) -> Void
    private var statusDismissal = DockStatusHelpDismissal()
    private var activeSurface: DockHelpSurface?
    private var statusSurface: DockHelpSurface?
    private var requestedMap: RequestedHelpMap?
    private var mapSurface: DockHelpSurface?
    private var mapStatusFrame: CGRect?
    private var dismissingMap = false
    private var explanationTask: Task<Void, Never>?
    private var explanationInteraction: DockHelpInteraction?
    var shownExplanationForChecks: HelpExplanation? { presenter?.shownExplanationForChecks }
    var isInstalled: Bool { !retired && presenter != nil && binding != nil }

    private init(dock: StaticDockPreviewHost, application: SettingsApplicationCoordinator,
                 composition: InstrumentHelpComposition, router: HelpOverlayRouter,
                 statusAnchor: @escaping @MainActor () -> DockStatusHelpAnchor?,
                 cockpitAnchor: @escaping @MainActor () -> CockpitAttachmentHintAnchor?,
                 statusRequestID: @escaping @MainActor () -> UUID?,
                 statusDidDismiss: @escaping @MainActor (UUID) -> Void) {
        self.dock = dock; self.application = application
        self.composition = composition; self.router = router
        self.statusAnchor = statusAnchor; self.cockpitAnchor = cockpitAnchor
        self.statusRequestID = statusRequestID; self.statusDidDismiss = statusDidDismiss
    }

    static func restored(dock: StaticDockPreviewHost,
                         application: SettingsApplicationCoordinator,
                         statusAnchor: @escaping @MainActor () -> DockStatusHelpAnchor? = { nil },
                         cockpitAnchor: @escaping @MainActor () -> CockpitAttachmentHintAnchor? = { nil },
                         statusRequestID: @escaping @MainActor () -> UUID? = { nil },
                         statusDidDismiss: @escaping @MainActor (UUID) -> Void = { _ in }) async -> DockHelpCoordinator? {
        var routed: HelpOverlayRouter?
        let composition = await InstrumentHelpComposition.restored(application: application, overlayFactory: { cockpit in
            let router = HelpOverlayRouter(cockpit: cockpit)
            routed = router
            return router
        })
        guard let router = routed else { composition.dispose(); return nil }
        let owner = DockHelpCoordinator(dock: dock, application: application,
                                        composition: composition, router: router, statusAnchor: statusAnchor,
                                        cockpitAnchor: cockpitAnchor,
                                        statusRequestID: statusRequestID, statusDidDismiss: statusDidDismiss)
        owner.install()
        return owner
    }

    private func install() {
        guard let dock, !retired else { return }
        let presenter = DockHelpPresenter(currentSurface: { [weak self] in
            guard let self, self.mapSurface == nil else { return nil }
            return self.activeSurface
        },
            isCurrent: { [weak self] surface in self?.isCurrent(surface) == true },
            blockers: { [weak self] surface in
                guard let self else { return [] }
                return self.statusSurface == surface || self.cockpitSurface == surface ? Array(surface.anchors.values) : (self.dock?.dockHelpBlockingRects(surface) ?? [])
            },
            windowPolicy: { [weak self] surface in
                guard let self else { return nil }
                if self.statusSurface == surface, let anchor = self.statusAnchor() { return (anchor.sharing, anchor.collection) }
                if self.cockpitSurface == surface, let anchor = self.cockpitAnchor() { return (anchor.sharing, anchor.collection) }
                return self.dock?.dockHelpWindowPolicy(surface)
            },
            language: { [weak self] in self?.application.latest?.effective.language == .chinese ? .chinese : .english },
            accessibility: { [weak self] in
                let effective = self?.application.latest?.effective
                return (effective?.reduceMotion ?? true, effective?.reduceTransparency ?? true)
            }, copy: { kind, language in
                let zh = language == .chinese
                switch kind {
                case .ringRefresh: return (zh ? "悬停查看详情 · 点击刷新" : "Hover to see details · click to refresh", zh ? "不再显示" : "Don't show again")
                case .findWidget: return (zh ? "右键点菜单栏图标，选「找到额度挂件」可再次找到" : "Find it again: right-click the menu bar icon, Find Quota Widget", zh ? "不再显示" : "Don't show again")
                case .widgetOff: return (EngineRowsText.widgetTurnedOffHint.value(zh ? .chinese : .english), zh ? "知道了" : "OK")
                case .ignition: return (zh ? "点按打开驾驶舱" : "Tap to open Cockpit", zh ? "关闭" : "Close")
                case .drag: return (zh ? "拖喷口换顺序，拖底座换到别的边" : "Drag a nozzle to reorder; drag the base to move to another edge", zh ? "关闭" : "Close")
                // D88: the keys' glyphs are an arrow out of a box (detach) and an arrow into it (put back).
                case .detach: return (zh ? "拖动标题条或点 ↗ 可把驾驶舱分离出来单独放" : "Drag the title strip or press ↗ to detach the cockpit", zh ? "关闭" : "Close")
                case .putBack: return (zh ? "点 ↙ 或拖回菜单栏图标即可放回" : "Press ↙ or drag it back to the menu-bar icon to put it back", zh ? "关闭" : "Close")
                default: return nil
                }
            }, dismiss: { [weak self] _ in
                guard let self else { return }
                self.composition.host.dismiss()
                self.refresh()
            }, layer: composition.layer)
        let binding = DockHelpBinding(presenter: presenter,
            isCurrent: { [weak self] surface in self?.isCurrent(surface) == true })
        self.presenter = presenter; self.binding = binding
        requestedMap = RequestedHelpMap(composition: composition, isCurrent: { [weak self] input in
            guard let self, let surface = self.mapSurface else { return false }
            return input.sessionID == surface.layoutID && self.isCurrent(surface) &&
                (self.mapStatusFrame == nil || self.statusAnchor()?.frame == self.mapStatusFrame)
        })
        composition.onHelpAction = { [weak self] action in
            guard let self else { return }
            let current = self.mapSurface.map { self.isCurrent($0) } == true
            self.dismissingMap = true
            let handled = (try? self.requestedMap?.handleHelpAction(action)) == true
            self.dismissingMap = false
            if handled {
                let reason: HelpUIDismissReason?
                if current, case .dismissMap(let value, _) = action { reason = value } else { reason = nil }
                self.finishMap(reason: reason); self.refresh()
            }
        }
        composition.onSettingsReceipt = { [weak self] edit, accepted in
            guard accepted, case .resetHelpHints = edit.kind else { return }
            self?.refresh()
        }
        router.installDock(binding)
        dock.dockHelpSurfaceDidChange = { [weak self] surface in self?.update(surface) }
        dock.dockHelpInteractionDidChange = { [weak self] interaction in self?.interactionDidChange(interaction) }
    }

    /// G3-10: hover (after the 500 ms dwell) or keyboard focus (at once) shows the element's
    /// explanation; VoiceOver reads the same text on the focused control. Leaving clears it.
    private func interactionDidChange(_ interaction: DockHelpInteraction?) {
        explanationTask?.cancel(); explanationTask = nil
        presenter?.hideExplanation()
        explanationInteraction = interaction
        guard let interaction, !retired, !suspended, mapSurface == nil else { return }
        let dwell: Duration = interaction.source == .keyboard ? .zero : .milliseconds(500)
        explanationTask = Task { @MainActor [weak self] in
            if dwell > .zero { try? await Task.sleep(for: dwell) }
            guard let self, !Task.isCancelled else { return }
            self.explanationTask = nil
            self.presentExplanation(interaction)
        }
    }

    private func presentExplanation(_ interaction: DockHelpInteraction) {
        guard !retired, !suspended, mapSurface == nil, explanationInteraction == interaction, let dock,
              !dock.spotlightHold, dock.currentDockHelpInteraction == interaction, let surface = dock.currentDockHelpSurface,
              dock.isCurrentDockHelpSurface(surface) else { return }
        let language: InstrumentLanguage = application.latest?.effective.language == .chinese ? .chinese : .english
        guard let explanation = DockHoverExplanation.explanation(anchorID: interaction.anchor.id, language: language,
                                                                 refreshAvailable: dock.ringRefreshAvailable) else { return }
        if interaction.source == .keyboard {
            dock.setDockHelpAccessibilityExplanation(explanation.accessibleDescription, for: interaction, on: surface)
        }
        // A pointer explanation never covers the open quota card or a first-use hint.
        guard presenter?.showsHint != true, interaction.source == .keyboard || dock.card.isHidden else { return }
        _ = presenter?.showExplanation(explanation, id: interaction.receipt.uuidString,
                                        anchor: interaction.anchor.rect, surface: surface)
    }

    private func update(_ surface: DockHelpSurface?) {
        guard !retired, !suspended, let binding else { return }
        if let mapSurface, surface != mapSurface { dismissRequestedMap() }
        // D56: no hint is offered while Find Quota Widget dims the display; the first hint
        // follows once the spotlight has ended, so the two read as one automatic hint.
        let eligible = application.latest?.snapshot.preferences.onboarding.completed == true && dock?.spotlightHold != true
        let concealed: Bool, turnedOff: Bool
        switch dock?.edgePresentation?.state {
        case .sliver?: concealed = true; turnedOff = false
        case .suppressed(.userHidden)?: concealed = true; turnedOff = true
        default: concealed = false; turnedOff = false
        }
        if eligible, concealed, let anchor = statusAnchor(), !anchor.frame.isEmpty {
            // G3-28: turning the widget off also anchors the one-time "turned off" hint here.
            let anchors: [FirstUseHintKind: CGRect] = turnedOff ? [.findWidget: anchor.frame, .widgetOff: anchor.frame] : [.findWidget: anchor.frame]
            if statusSurface?.anchors != anchors {
                statusSurface = DockHelpSurface(revealID: UUID(), layoutID: UUID(), visible: true, dragging: false,
                                                anchors: anchors)
            }
        } else { statusSurface = nil }
        // D88: while the cockpit is open and its next one-time hint is unseen, that hint's key is the surface.
        let cockpit = eligible ? cockpitAnchor() : nil
        let cockpitKind: FirstUseHintKind? = cockpit.map { $0.attached ? .detach : .putBack }
        if let cockpit, let cockpitKind, !composition.host.hints.preferences.seen.contains(cockpitKind) {
            let anchors: [FirstUseHintKind: CGRect] = [cockpitKind: cockpit.frame]
            if cockpitSurface?.anchors != anchors {
                cockpitSurface = DockHelpSurface(revealID: UUID(), layoutID: UUID(), visible: true, dragging: false, anchors: anchors)
            }
        } else { cockpitSurface = nil }
        let admittedSurface = eligible ? (cockpitSurface ?? statusSurface ?? surface) : nil
        activeSurface = admittedSurface
        var context = composition.host.hints.context
        context.helpMapVisible = mapSurface != nil
        context.v1MinimalHints = true
        context.ringRefreshAvailable = statusSurface == nil && dock?.ringRefreshAvailable == true
        context.widgetConcealed = concealed
        context.widgetTurnedOff = turnedOff
        context.statusAnchorAvailable = statusSurface != nil
        context.cockpitAttached = cockpitSurface == nil ? nil : cockpit?.attached
        context.ignitionAvailable = dock?.cockpitEntryEnabled == true
        context.cardPinned = false
        context.reducedMotion = application.latest?.effective.reduceMotion ?? true
        do {
            if !composition.host.isRunning { try composition.host.resume(context: context) }
            try binding.update(admittedSurface, context: context, host: composition.host)
        } catch {
            // Do not mark an unverified offer as shown on invalid geometry or time.
            composition.host.suspend()
        }
    }

    @discardableResult func presentRequestedMap() -> Bool {
        guard !retired, !suspended, let surface = dock?.currentDockHelpSurface else { return false }
        let requestID = statusRequestID()
        if mapSurface != nil { dismissRequestedMap() }
        update(surface)
        guard isCurrent(surface), let presenter, let requestedMap else { return false }
        composition.host.dismiss()
        guard let viewport = presenter.prepareMap(surface: surface) else { return false }
        mapSurface = surface
        func local(_ rect: CGRect) -> CGRect {
            CGRect(x: rect.minX - viewport.minX, y: viewport.maxY - rect.maxY, width: rect.width, height: rect.height)
        }
        var anchors = surface.mapAnchors.map { DockRequestedHelpAnchor(id: $0.id, region: $0.region, rect: local($0.rect), visible: $0.visible, caption: $0.caption) }
        if let status = statusAnchor(), viewport.contains(status.frame) {
            mapStatusFrame = status.frame
            let caption = application.latest?.effective.language == .chinese ? "右键点菜单栏图标，选「找到额度挂件」。" : "Right-click the menu bar icon and choose Find Quota Widget."
            anchors.append(.init(id: "status.menu", region: .sliver, rect: local(status.frame), visible: true, caption: caption))
        } else { mapStatusFrame = nil }
        let blockers = (dock?.dockHelpMapBlockingRects(surface) ?? []).map(local)
        let avoid = (dock?.dockHelpMapAvoidRects(surface) ?? []).map(local)
        let language: InstrumentLanguage = application.latest?.effective.language == .chinese ? .chinese : .english
        guard var input = DockRequestedHelpLayout.make(session: surface.layoutID, viewport: viewport.size,
                language: language, anchors: anchors, blocked: blockers, avoid: avoid, recipe: composition.layer.recipeProvider,
                refreshAvailable: dock?.ringRefreshAvailable == true) else {
            finishMap(); return false
        }
        input.reduceMotion = application.latest?.effective.reduceMotion ?? true
        input.reduceTransparency = application.latest?.effective.reduceTransparency ?? true
        do {
            guard try requestedMap.presentHelpMap(input: input, content: [:], context: composition.host.hints.context),
                  presenter.showPreparedMap(surface: surface, dismissMap: { [weak self] reason in self?.dismissRequestedMap(reason: reason) }) else {
                try? requestedMap.dismissHelpMap(); finishMap(); return false
            }
            guard mapSurface == surface, !retired, !suspended, isCurrent(surface) else { finishMap(); return false }
            statusDismissal.arm(requestID)
            dock?.helpMapHold = true
            return true
        } catch { finishMap(); return false }
    }

    func dismissRequestedMap(reason: HelpUIDismissReason? = nil) {
        guard let surface = mapSurface else { return }
        let userReason = isCurrent(surface) && !retired && !suspended ? reason : nil
        dismissingMap = true
        try? requestedMap?.dismissHelpMap()
        dismissingMap = false
        finishMap(reason: userReason)
        if !retired && !suspended { update(dock?.currentDockHelpSurface) }
    }
    private func finishMap(reason: HelpUIDismissReason? = nil) {
        dock?.helpMapHold = false
        let id = statusDismissal.take(reason: reason)
        mapSurface = nil; mapStatusFrame = nil; presenter?.endMap()
        if let id { statusDidDismiss(id) }
    }

    private func isCurrent(_ surface: DockHelpSurface) -> Bool {
        guard !retired, !suspended, !dismissingMap, activeSurface == surface else { return false }
        if statusSurface == surface { return statusAnchor()?.frame == surface.anchors[.findWidget] }
        if cockpitSurface == surface {
            guard let anchor = cockpitAnchor() else { return false }
            return surface.anchors[anchor.attached ? .detach : .putBack] == anchor.frame
        }
        return dock?.isCurrentDockHelpSurface(surface) == true
    }

    func refresh() {
        // New content leaves the surface stale until the next publish, which reports the change
        // itself. Read as "no surface", that gap would end a shown hint and spend it.
        guard dock?.dockHelpSurfaceAwaitsPublish != true else { return }
        update(dock?.currentDockHelpSurface)
    }
    func suspend() {
        guard !retired, !suspended else { return }
        explanationTask?.cancel(); explanationTask = nil; explanationInteraction = nil; presenter?.hideExplanation()
        dismissRequestedMap()
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
        explanationTask?.cancel(); explanationTask = nil; explanationInteraction = nil
        dismissRequestedMap(); retired = true; activeSurface = nil; statusSurface = nil; cockpitSurface = nil; dock?.dockHelpSurfaceDidChange = nil
        dock?.dockHelpInteractionDidChange = nil
        if let binding { try? binding.retire(context: composition.host.hints.context, host: composition.host) }
        router.installDock(nil); presenter?.dispose(); presenter = nil; binding = nil
        await composition.flush()
        composition.dispose()
    }
}
