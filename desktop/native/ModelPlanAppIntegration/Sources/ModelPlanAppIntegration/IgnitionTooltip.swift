// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanSettings

/// Master spec §7.4 / C28 (D473, option a): the ignition key acts on the cockpit's visibility (D204 v3), so the same press
/// does different things; only the tooltip says which. Short words, the same text in the `aria-label` (accessibility
/// label). No mark on the key, and a hold (the v1.1 entrance) does not change the words.
public enum IgnitionCockpitState: Equatable, Sendable {
    /// Closed, docked or detached: the press opens it (docked under the menu bar, detached at its last position).
    case closed
    /// Docked under the menu bar and open: the press closes it.
    case dockedOpen
    /// Detached and open (in front, covered, on another Space or minimised): the press brings it to the front here.
    case detachedOpen

    public var text: SettingsText {
        switch self {
        case .closed: return SettingsText("Open cockpit", "打开驾驶舱")
        case .dockedOpen: return SettingsText("Close cockpit", "收起驾驶舱")
        case .detachedOpen: return SettingsText("Show cockpit", "切到驾驶舱")
        }
    }
}
