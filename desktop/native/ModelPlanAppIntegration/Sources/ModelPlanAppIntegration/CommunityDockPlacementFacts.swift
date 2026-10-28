// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanDock
import ModelPlanSettings

/// Called by the existing Dock placement producer on presentation/topology change. No polling or geometry owner.
public enum CommunityDockPlacementFacts {
    public static func observation(_ placement: DockEdgePlacement?, recovering: Bool) throws -> SettingsDockPlacementObservation? {
        guard let placement else { return nil }
        guard let edge = SettingsDockEdge(rawValue: String(describing: placement.edge)) else { throw SettingsError.invalidPreference }
        return try .init(displayID: placement.displayID, edge: edge, alongFraction: placement.alongFraction, recovering: recovering)
    }
    /// Context-only: recovery never persists an alternative over the user's preferred edge/display/fraction.
    @MainActor @discardableResult public static func apply(_ placement: DockEdgePlacement?, recovering: Bool,
                                                           application: SettingsApplicationCoordinator) throws -> Bool {
        let next = try observation(placement, recovering: recovering)
        var context = application.editor.context
        guard context.dockPlacementObservation != next else { return false }
        context.dockPlacementObservation = next
        application.update(context: context)
        return true
    }
    /// Run against the actual Host presentation in the owner's wiring test, not a separate model fixture.
    @MainActor public static func requireSynchronized(_ placement: DockEdgePlacement?, recovering: Bool,
                                                      application: SettingsApplicationCoordinator) throws {
        guard application.editor.context.dockPlacementObservation == (try observation(placement, recovering: recovering))
        else { throw SettingsEditorError.staleContext }
    }
}
