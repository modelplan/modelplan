// SPDX-License-Identifier: MIT
import Foundation

/// Current placement supplied by the existing Dock producer, separate from durable user intent.
public struct SettingsDockPlacementObservation: Equatable, Sendable {
    public let displayID: String
    public let edge: SettingsDockEdge
    public let alongFraction: Double
    public let recovering: Bool
    public init(displayID: String, edge: SettingsDockEdge, alongFraction: Double, recovering: Bool) throws {
        guard !displayID.isEmpty, displayID.utf8.count <= 256,
              !displayID.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains),
              alongFraction.isFinite, (0...1).contains(alongFraction) else { throw SettingsError.invalidPreference }
        self.displayID = displayID; self.edge = edge; self.alongFraction = alongFraction; self.recovering = recovering
    }
}
