// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanCore

/// The upper composition package owns Settings. The root host retains this integration without
/// depending back on Settings (which already consumes root Dock).
@MainActor public protocol CommunitySettingsIntegration: AnyObject {
    var settingsMenuItem: NSMenuItem { get }
    func restorePreferences() async
    func suspend()
}
/// Optional upper-layer reason/action; Root renders it without importing Settings or duplicating its policy.
@MainActor public protocol CommunityUsageRemediation: CommunitySettingsIntegration {
    var usageAccessMenuItem: NSMenuItem { get }
    func updateUsageState(snapshot: JoinedSnapshot?, diagnostics: StoreDiagnostics, now: Date)
}

/// Optional navigation on the actual retained integration, without a Settings import in Root.
@MainActor public protocol CommunitySubscriptionsSettingsPresenting: CommunitySettingsIntegration {
    func presentSubscriptionsSettings() async
}
