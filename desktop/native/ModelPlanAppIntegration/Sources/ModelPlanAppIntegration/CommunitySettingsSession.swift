// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanSettings
import ModelPlanCommunityHost

/// Concrete retained integration passed to the Community host. No second editor/store, service or reader.
@MainActor public final class CommunitySettingsSession: CommunitySettingsIntegration {
    public let windowHost: SettingsWindowHost
    public let settingsMenuItem: NSMenuItem
    public init(application: SettingsApplicationCoordinator,
                canPresent: @escaping @MainActor () -> Bool,
                environment: (@MainActor () -> SettingsEnvironment)? = nil,
                activate: @escaping @MainActor () -> Void = { NSApplication.shared.activate() },
                makeSurface: (@MainActor (SettingsEditor) -> any SettingsWindowSurface)? = nil) {
        windowHost = SettingsWindowHost(application: application, canPresent: canPresent,
            environment: environment, activate: activate, makeSurface: makeSurface)
        settingsMenuItem = windowHost.menuItem(title: "Settings… / 设置…")
    }
    public func restorePreferences() async { await windowHost.application.reload() }
    public func suspend() { windowHost.suspend() }
}
