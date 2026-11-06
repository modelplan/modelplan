// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanSettings
import ModelPlanDock
import ModelPlanEngineStore
import ModelPlanEngineClient

/// The exact construction route called by the community executable and synthetic-profile checks.
@MainActor public enum EngineRowsEntry {
    #if MODELPLAN_DOCK_NATIVE_JOURNEY
    static var nativeJourneyProfile: URL?
    #endif

    /// One foundation document backs the normal Settings and Core entry.
    public static func makeSettingsStore(applicationSupport: URL, rowIDMap: [String: String] = [:],
                                         preferredLanguages: [String] = Locale.preferredLanguages) throws -> SettingsStore {
        let tag = (preferredLanguages.first ?? "").lowercased().replacingOccurrences(of: "_", with: "-")
        let language: SettingsLanguage = tag == "zh" || tag.hasPrefix("zh-") ? .chinese : .english
        return try SettingsStore(foundationAt: applicationSupport, product: .community,
                                 rowIDMap: rowIDMap, defaultLanguage: language)
    }
    public static func make(configuration: EngineClientConfiguration, settingsStore: SettingsStore,
                            createsNativePanels: Bool = true, bundleURL: URL = Bundle.main.bundleURL,
                            cockpitEntryEnabled: Bool? = nil,
                            dockEnvironment: (@MainActor () -> DockEdgeEnvironment)? = nil,
                            deadlineNow: @escaping @MainActor () -> Date = { Date() },
                            deadlineElapsed: (() -> TimeInterval)? = nil, deadlineScheduling: (any DockEdgeScheduling)? = nil,
                            makeClient: (@MainActor (EngineClientConfiguration, EngineStore) -> any EngineClient)? = nil,
                            makeSettingsSurface: (@MainActor (SettingsEditor) -> any SettingsWindowSurface)? = nil,
                            makeConsole: (@MainActor (EngineDockMenuComposition) -> any EngineRowsConsoleSurface)? = nil,
                            isolatedResetNotificationLedger: URL? = nil,
                            activateSettings: @escaping @MainActor () -> Void = { NSApplication.shared.activate() }) -> EngineDockMenuApplication {
        let app=CommunityCockpitApplicationFactory.make(configuration: configuration, settingsStore: settingsStore, createsNativePanels: createsNativePanels, bundleURL: bundleURL, cockpitEntryEnabled: cockpitEntryEnabled, dockEnvironment: dockEnvironment, deadlineNow: deadlineNow, deadlineElapsed: deadlineElapsed, deadlineScheduling: deadlineScheduling, makeClient: makeClient, makeSettingsSurface: makeSettingsSurface, makeConsole: makeConsole, activateSettings: activateSettings)
        #if MODELPLAN_DOCK_NATIVE_JOURNEY
        let ledger = isolatedResetNotificationLedger ?? nativeJourneyProfile?.appendingPathComponent("reset-notifications.json")
        #else
        let ledger = isolatedResetNotificationLedger
        #endif
        app.composition.installResetEvents(settings: settingsStore, live: createsNativePanels, isolatedLedger: ledger)
        return app
    }
}
