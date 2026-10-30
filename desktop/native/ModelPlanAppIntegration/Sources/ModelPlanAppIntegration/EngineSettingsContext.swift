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
        if identityMatches { context.about.cliVersion = CommunityConsentBundleIdentity.version }
        base = context
    }
    func make(engineReady: Bool) -> SettingsPageContext {
        var context = base
        context.about.cliState = engineReady && identityMatches ? .ready : .unavailable
        return context
    }
}
