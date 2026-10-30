// SPDX-License-Identifier: MIT
import ModelPlanSettings
import ModelPlanEngineStore
import ModelPlanEngineClient

/// The exact construction route called by the community executable and synthetic-profile checks.
@MainActor public enum EngineRowsEntry {
    public static func make(configuration: EngineClientConfiguration, settingsStore: SettingsStore,
                            createsNativePanels: Bool = true,
                            makeClient: (@MainActor (EngineClientConfiguration, EngineStore) -> any EngineClient)? = nil) -> EngineDockMenuApplication {
        .init(configuration: configuration, settingsStore: settingsStore, createsNativePanels: createsNativePanels, makeClient: makeClient)
    }
}
