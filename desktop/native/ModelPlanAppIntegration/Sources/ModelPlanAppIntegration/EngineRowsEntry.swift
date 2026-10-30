// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanSettings
import ModelPlanEngineStore
import ModelPlanEngineClient

/// The exact construction route called by the community executable and synthetic-profile checks.
@MainActor public enum EngineRowsEntry {
    public static func make(configuration: EngineClientConfiguration, settingsStore: SettingsStore,
                            createsNativePanels: Bool = true,
                            makeClient: (@MainActor (EngineClientConfiguration, EngineStore) -> any EngineClient)? = nil,
                            makeSettingsSurface: (@MainActor (SettingsEditor) -> any SettingsWindowSurface)? = nil,
                            makeConsole: (@MainActor (EngineDockMenuComposition) -> any EngineRowsConsoleSurface)? = nil,
                            activateSettings: @escaping @MainActor () -> Void = { NSApplication.shared.activate() }) -> EngineDockMenuApplication {
        .init(configuration: configuration, settingsStore: settingsStore, createsNativePanels: createsNativePanels, makeClient: makeClient, makeSettingsSurface: makeSettingsSurface, makeConsole: makeConsole, activateSettings: activateSettings)
    }
}
