// SPDX-License-Identifier: MIT
import AppKit

/// The upper composition package owns Settings. The root host retains this integration without
/// depending back on Settings (which already consumes root Dock).
@MainActor public protocol CommunitySettingsIntegration: AnyObject {
    var settingsMenuItem: NSMenuItem { get }
    func restorePreferences() async
    func suspend()
}
