// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanCore
import ModelPlanShell

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

/// Optional upper-layer language choice, so root-host strings follow Settings without importing it (SET-9-38).
@MainActor public protocol CommunityLanguageReporting: CommunitySettingsIntegration {
    var prefersChinese: Bool { get }
}
/// Host text before a Settings choice exists follows the macOS list through the Shell rule (SET-9-39).
public enum CommunityHostLanguage {
    public static func prefersChinese(preferredLanguages: [String] = Locale.preferredLanguages) -> Bool {
        NativeSurfaceLanguage.prefersChinese(preferredLanguages: preferredLanguages)
    }
    public static func text(_ english: String, _ chinese: String, chinese isChinese: Bool) -> String {
        NativeSurfaceLanguage.text(english, chinese, chinese: isChinese)
    }
}
