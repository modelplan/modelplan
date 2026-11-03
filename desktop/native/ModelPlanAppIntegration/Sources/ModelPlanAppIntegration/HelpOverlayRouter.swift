// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanSettings

/// Routes the one existing arbiter to its surface presenters. It owns no ledger or timer.
@MainActor public final class HelpOverlayRouter: HintOverlayPresenting {
    private let cockpit: any HintOverlayPresenting
    private var dock: (any HintOverlayPresenting)?
    private var context = HintContext()
    private struct Owner {
        let presenter: any HintOverlayPresenting
        let isDock: Bool
    }
    private var owners: [UUID: Owner] = [:]

    public init(cockpit: any HintOverlayPresenting) { self.cockpit = cockpit }
    public func installDock(_ presenter: (any HintOverlayPresenting)?) {
        guard dock !== presenter else { return }
        let old = dock
        dock = presenter
        guard let old else { return }
        let withdrawn = owners.filter { $0.value.isDock && $0.value.presenter === old }
        // Remove all ownership before calling out: a hide can reenter and install a new surface.
        for id in withdrawn.keys { owners.removeValue(forKey: id) }
        for (id, owner) in withdrawn { owner.presenter.hide(offerID: id) }
    }

    private func usesDock(_ kind: FirstUseHintKind) -> Bool {
        kind == .ignition || kind == .drag || kind == .ringRefresh || kind == .findWidget || (kind == .pinned && context.cockpitOpen == nil)
    }
    public func placeableKinds(context: HintContext, trial: InstrumentHintSourceSnapshot?) -> Set<FirstUseHintKind> {
        self.context = context
        let cockpitKinds = cockpit.placeableKinds(context: context, trial: trial)
        let dockKinds = dock?.placeableKinds(context: context, trial: trial) ?? []
        return Set(FirstUseHintKind.allCases.filter { usesDock($0) ? dockKinds.contains($0) : cockpitKinds.contains($0) })
    }
    public func showAndVerify(_ offer: HintOffer, trial: InstrumentHintSourceSnapshot?) -> Bool {
        let isDock = usesDock(offer.kind)
        guard let presenter = isDock ? dock : cockpit else { return false }
        owners[offer.id] = Owner(presenter: presenter, isDock: isDock)
        let shown = presenter.showAndVerify(offer, trial: trial)
        guard let owner = owners[offer.id], owner.isDock == isDock, owner.presenter === presenter,
              !isDock || presenter === dock else {
            // The presenter may have finished showing after a reentrant withdrawal.
            presenter.hide(offerID: offer.id)
            return false
        }
        return shown
    }
    public func updateAndVerify(_ presentation: HintPresentation) -> Bool {
        guard let owner = owners[presentation.offer.id] else { return false }
        if owner.isDock, owner.presenter !== dock { return false }
        return owner.presenter.updateAndVerify(presentation)
    }
    public func hide(offerID: UUID) {
        owners.removeValue(forKey: offerID)?.presenter.hide(offerID: offerID)
    }
}
