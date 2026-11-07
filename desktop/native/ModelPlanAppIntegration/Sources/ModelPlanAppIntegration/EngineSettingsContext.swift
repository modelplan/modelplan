// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanSettings

/// Bundle metadata is cached once; live readiness is supplied only by accepted engine state.
@MainActor struct EngineSettingsContext {
    private let base: SettingsPageContext
    private let identityMatches: Bool
    init(bundle: URL, executable: URL) {
        identityMatches = executable.standardizedFileURL == bundle.appendingPathComponent("Contents/Helpers/modelplan").standardizedFileURL && CommunityConsentBundleIdentity.matches(bundle: bundle)
        var context = CommunityApplicationFactory.makeSettingsContext(bundle: bundle, availability: .unverified)
        context.configureV1NormalEntry()
        // The normal Dock applies the pin to the selected member's paint, and the status item
        // shows the chosen menu-bar display (MENU-04/05). The widget's own controls are
        // reported by its host (StaticDockPreviewHost.consumedSettingKeys).
        for key in [SettingKey.percentagePin, .menuDisplay] {
            context.unavailableControls.removeValue(forKey: key)
        }
        if identityMatches { context.about.cliVersion = CommunityConsentBundleIdentity.version }
        base = context
    }
    func make(engineReady: Bool) -> SettingsPageContext {
        var context = base
        context.about.cliState = engineReady && identityMatches ? .ready : .unavailable
        return context
    }
}
