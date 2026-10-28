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
public enum SettingsDockPlacementText {
    public static func current(_ observation: SettingsDockPlacementObservation?, displays: [SettingsDisplayChoice]) -> SettingsText {
        guard let observation else {
            return .init("Current Dock placement has not been observed.", "尚未观测到挂件的实际位置。")
        }
        let edge: SettingsText
        switch observation.edge {
        case .left: edge = .init("left", "左侧")
        case .right: edge = .init("right", "右侧")
        case .bottom: edge = .init("bottom", "底部")
        }
        let name = displays.first { $0.id == observation.displayID }?.name
        let display = name.map { SettingsText($0, $0) } ?? .init("Unknown display", "未知显示器")
        let fraction = String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), observation.alongFraction * 100) + "%"
        let en = "Currently \(edge.english) · \(fraction) · \(display.english)" + (observation.recovering ? " · temporary recovery" : "")
        let zh = "当前位于\(edge.chinese) · \(fraction) · \(display.chinese)" + (observation.recovering ? " · 临时恢复位置" : "")
        return .init(en, zh)
    }
}
