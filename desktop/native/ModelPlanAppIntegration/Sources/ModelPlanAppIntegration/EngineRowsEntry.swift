// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanSettings
import ModelPlanEngineStore
import ModelPlanEngineClient

/// The exact construction route called by the community executable and synthetic-profile checks.
@MainActor public enum EngineRowsEntry {
    /// One foundation document backs the normal Settings and Core entry.
    public static func makeSettingsStore(applicationSupport: URL, rowIDMap: [String: String] = [:],
                                         preferredLanguages: [String] = Locale.preferredLanguages) throws -> SettingsStore {
        let language = preferredLanguages.lazy.compactMap { value -> SettingsLanguage? in
            let tag = value.lowercased().replacingOccurrences(of: "_", with: "-")
            if tag == "zh" || tag.hasPrefix("zh-") { return .chinese }
            if tag == "en" || tag.hasPrefix("en-") { return .english }
            return nil
        }.first ?? .english
        return try SettingsStore(foundationAt: applicationSupport, product: .community,
                                 rowIDMap: rowIDMap, defaultLanguage: language)
    }
    public static func make(configuration: EngineClientConfiguration, settingsStore: SettingsStore,
                            createsNativePanels: Bool = true, bundleURL: URL = Bundle.main.bundleURL,
                            makeClient: (@MainActor (EngineClientConfiguration, EngineStore) -> any EngineClient)? = nil,
                            makeSettingsSurface: (@MainActor (SettingsEditor) -> any SettingsWindowSurface)? = nil,
                            makeConsole: (@MainActor (EngineDockMenuComposition) -> any EngineRowsConsoleSurface)? = nil,
                            activateSettings: @escaping @MainActor () -> Void = { NSApplication.shared.activate() }) -> EngineDockMenuApplication {
        CommunityCockpitApplicationFactory.make(configuration: configuration, settingsStore: settingsStore, createsNativePanels: createsNativePanels, bundleURL: bundleURL, makeClient: makeClient, makeSettingsSurface: makeSettingsSurface, makeConsole: makeConsole, activateSettings: activateSettings)
    }
}
