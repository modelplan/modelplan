// SPDX-License-Identifier: MIT
import Foundation

/// Spec 5.3 A (behaviour from CodexBar `MenuBarStatusItemPlacementPreflight.prepare`, own code): before the status
/// item is created, a stored menu-bar position that cannot be real is removed, so AppKit places the item afresh instead
/// of off the end of the bar. A position the user dragged (⌘-drag) is a finite positive distance from the right edge
/// within the widest display and is never touched. Only this app's own key for the given autosave name is read.
public enum StatusItemPlacement {
    /// A position this far past the widest display is stale (a display that is gone, a corrupted write).
    public static let implausiblePadding: Double = 512

    /// The key AppKit itself writes for an autosaved status item in the app's defaults domain.
    public static func key(autosaveName: String) -> String { "NSStatusItem Preferred Position \(autosaveName)" }

    /// True when a stored value is not a usable position: not a finite number, not positive, or wider than the widest
    /// display plus `implausiblePadding`. With no displays known, only the first two rules apply.
    public static func isImplausible(_ value: Any, screenWidths: [Double]) -> Bool {
        let number: Double
        switch value {
        case let value as NSNumber where CFGetTypeID(value) != CFBooleanGetTypeID(): number = value.doubleValue
        case let value as Double: number = value
        case let value as Int: number = Double(value)
        default: return true
        }
        guard number.isFinite, number > 0 else { return true }
        guard let widest = screenWidths.filter({ $0.isFinite && $0 > 0 }).max() else { return false }
        return number > widest + implausiblePadding
    }

    /// Removes this app's stored position for `autosaveName` when it is implausible. Returns true when it removed one.
    /// An absent value is fine (AppKit picks the default place).
    @discardableResult
    public static func clearImplausiblePosition(autosaveName: String, defaults: UserDefaults = .standard,
                                                screenWidths: [Double]) -> Bool {
        let key = key(autosaveName: autosaveName)
        guard let value = defaults.object(forKey: key), isImplausible(value, screenWidths: screenWidths) else { return false }
        defaults.removeObject(forKey: key)
        return true
    }
}
