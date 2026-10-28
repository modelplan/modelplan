// SPDX-License-Identifier: MIT
import ModelPlanDock
import ModelPlanSettings

/// The Dock owns geometry; Settings consumes observations and saves explicit placement choices.
@MainActor public protocol CommunityPlacementProducing: AnyObject {
    var onPlacementObserved: ((DockEdgePlacement?, Bool) -> Void)? { get set }
}
/// Existing Dock return ports; all writes still go through the shared Settings editor.
@MainActor public protocol CommunityDockSettingsRouting: CommunityPlacementProducing {
    var commitDisplayPlacement: ((String, SettingsDockEdge, Double) -> Void)? { get set }
    var displayChoicesChanged: (([SettingsDisplayChoice]) -> Void)? { get set }
    var catalogueChanged: (([SettingsSubscription]) -> Void)? { get set }
}
extension StaticDockPreviewHost: CommunityDockSettingsRouting {}

@MainActor public enum CommunityPlacementBinding {
    public static func install(on producer: any CommunityPlacementProducing, application: SettingsApplicationCoordinator) {
        if let dock = producer as? any CommunityDockSettingsRouting {
            dock.commitDisplayPlacement = { [weak application] id, edge, fraction in
                guard let application else { return }
                Task { _ = try? await application.editor.commit(.dockPlacement(displayID: id, edge: edge, alongFraction: fraction)) }
            }
            dock.displayChoicesChanged = { [weak application] displays in
                guard let application else { return }
                var context = application.editor.context; context.displays = displays
                application.update(context: context)
            }
            dock.catalogueChanged = { [weak application] rows in
                guard let application else { return }
                var context = application.editor.context; context.subscriptions = rows
                application.update(context: context)
            }
        }
        producer.onPlacementObserved = { [weak application] placement, recovering in
            guard let application else { return }
            // Inputs come from the same resolver/producer; invalid facts become unknown, never preferences.
            do { try CommunityDockPlacementFacts.apply(placement, recovering: recovering, application: application) }
            catch { try? CommunityDockPlacementFacts.apply(nil, recovering: false, application: application) }
        }
    }
}
