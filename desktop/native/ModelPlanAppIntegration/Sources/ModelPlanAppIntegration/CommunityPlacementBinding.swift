// SPDX-License-Identifier: MIT
import ModelPlanDock
import ModelPlanSettings

/// The interactive Dock producer owns geometry; Settings owns only observation consumption.
@MainActor public protocol CommunityPlacementProducing: AnyObject {
    var onPlacementObserved: ((DockEdgePlacement?, Bool) -> Void)? { get set }
}
extension StaticDockPreviewHost: CommunityPlacementProducing {}

@MainActor public enum CommunityPlacementBinding {
    public static func install(on producer: any CommunityPlacementProducing, application: SettingsApplicationCoordinator) {
        producer.onPlacementObserved = { [weak application] placement, recovering in
            guard let application else { return }
            // Inputs come from the same resolver/producer; invalid facts become unknown, never preferences.
            do { try CommunityDockPlacementFacts.apply(placement, recovering: recovering, application: application) }
            catch { try? CommunityDockPlacementFacts.apply(nil, recovering: false, application: application) }
        }
    }
}
