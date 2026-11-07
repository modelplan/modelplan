// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanSettings

/// Supplied by the real surface owner. No geometry or visibility is inferred here.
public struct DockHelpSurface: Equatable {
    public let revealID: UUID
    public let layoutID: UUID
    public let visible: Bool
    public let dragging: Bool
    public let anchors: [FirstUseHintKind: CGRect]
    var mapAnchors: [DockRequestedHelpAnchor] = []
    public init(revealID: UUID, layoutID: UUID, visible: Bool, dragging: Bool,
                anchors: [FirstUseHintKind: CGRect]) {
        self.revealID = revealID; self.layoutID = layoutID; self.visible = visible
        self.dragging = dragging; self.anchors = anchors
    }
}

/// An adapter for a separately supplied presenter; all admission and persistence remain in host.
@MainActor public final class DockHelpBinding: HintOverlayPresenting {
    private let presenter: any HintOverlayPresenting
    private let isCurrent: @MainActor (DockHelpSurface) -> Bool
    private var surface: DockHelpSurface?
    private var shown: [UUID: DockHelpSurface] = [:]
    private var retired = false
    private var generation: UInt64 = 0

    public init(presenter: any HintOverlayPresenting, isCurrent: @escaping @MainActor (DockHelpSurface) -> Bool) {
        self.presenter = presenter; self.isCurrent = isCurrent
    }
    private func valid(_ surface: DockHelpSurface, kind: FirstUseHintKind) -> Bool {
        let token = generation
        guard !retired, self.surface == surface, surface.visible, !surface.dragging,
              let rect = surface.anchors[kind], !rect.isNull, !rect.isInfinite,
              rect.width > 0, rect.height > 0,
              rect.origin.x.isFinite, rect.origin.y.isFinite, rect.width.isFinite, rect.height.isFinite else { return false }
        return isCurrent(surface) && !retired && generation == token && self.surface == surface
    }
    public func placeableKinds(context: HintContext, trial: InstrumentHintSourceSnapshot?) -> Set<FirstUseHintKind> {
        guard let surface, context.dockReveal == surface.revealID else { return [] }
        let offered = presenter.placeableKinds(context: context, trial: trial)
        return Set(offered.filter { [.ignition, .drag, .pinned, .ringRefresh, .findWidget, .widgetOff].contains($0) && valid(surface, kind: $0) })
    }
    public func showAndVerify(_ offer: HintOffer, trial: InstrumentHintSourceSnapshot?) -> Bool {
        guard let surface, valid(surface, kind: offer.kind) else { return false }
        shown[offer.id] = surface
        let result = presenter.showAndVerify(offer, trial: trial)
        return result && valid(surface, kind: offer.kind)
    }
    public func updateAndVerify(_ presentation: HintPresentation) -> Bool {
        guard let surface = shown[presentation.offer.id], valid(surface, kind: presentation.offer.kind) else { return false }
        let result = presenter.updateAndVerify(presentation)
        return result && valid(surface, kind: presentation.offer.kind)
    }
    public func hide(offerID: UUID) {
        guard shown.removeValue(forKey: offerID) != nil else { return }
        presenter.hide(offerID: offerID)
    }

    /// The widget republishes its layout on most refreshes, a few times a second while it settles.
    /// Only a new reveal, a drag or a moved anchor means the shown hint no longer points at its target.
    private static func keepsHint(_ kind: FirstUseHintKind, from old: DockHelpSurface?, to new: DockHelpSurface?) -> Bool {
        guard let old, let new, old.revealID == new.revealID, new.visible, !new.dragging,
              let anchor = new.anchors[kind] else { return false }
        return old.anchors[kind] == anchor
    }

    /// The composition supplies the complete current context, including cockpit/map state.
    /// It must call this on actual visibility, drag, layout and retirement transitions.
    public func update(_ next: DockHelpSurface?, context: HintContext, host: HintExecutionHost) throws {
        guard !retired else { return }
        generation &+= 1; let token = generation
        let changed = surface != next, previous = surface
        if changed {
            host.cancelDwell(.ignition); host.cancelDwell(.drag)
            if let kind = host.hints.visible?.offer.kind,
               kind == .ignition || kind == .drag || kind == .ringRefresh || kind == .findWidget || kind == .widgetOff || (kind == .pinned && host.hints.context.cockpitOpen == nil),
               !Self.keepsHint(kind, from: previous, to: next) {
                host.dismiss()
            }
            guard generation == token, !retired else { return }
        }
        surface = next
        // A hint that survived the change stays shown on the surface that replaced its own.
        if changed, let previous, let next {
            for (id, value) in shown where value == previous { shown[id] = next }
        }
        let visible = next.map { $0.visible && isCurrent($0) } ?? false
        guard generation == token, !retired, surface == next else { return }
        let reveal = visible ? next?.revealID : nil
        let revealChanged = host.hints.context.dockReveal != reveal
        var merged = context
        merged.dockReveal = reveal
        try host.updateContext(merged)
        guard generation == token, !retired, surface == next else { return }
        if (changed || revealChanged), let next, visible, !next.dragging, isCurrent(next),
           generation == token, surface == next, !retired {
            try host.beginDockRevealDwell()
        }
    }
    public func retire(context: HintContext, host: HintExecutionHost) throws {
        guard !retired else { return }
        retired = true; generation &+= 1; surface = nil
        host.cancelDwell(.ignition); host.cancelDwell(.drag)
        if let kind = host.hints.visible?.offer.kind,
           kind == .ignition || kind == .drag || kind == .ringRefresh || kind == .findWidget || kind == .widgetOff || (kind == .pinned && host.hints.context.cockpitOpen == nil) {
            host.dismiss()
        }
        var merged = context; merged.dockReveal = nil
        try host.updateContext(merged)
    }
}
