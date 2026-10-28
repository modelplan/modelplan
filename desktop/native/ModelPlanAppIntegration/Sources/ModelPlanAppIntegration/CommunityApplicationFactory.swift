// SPDX-License-Identifier: MIT
import ModelPlanCore
import ModelPlanShell
import ModelPlanCommunityHost
import ModelPlanSettings

/// The normal executable and construction checks share this required-companion boundary.
@MainActor public enum CommunityApplicationFactory {
    public static func connectSettings(base: CommunitySettingsSession,
                                       application: SettingsApplicationCoordinator,
                                       backend: any SettingsConnectionAllowing,
                                       placementSource: any CommunityPlacementProducing,
                                       canPresent: @escaping @MainActor () -> Bool,
                                       makeFirstRun: (@MainActor (SettingsEditor) -> any SettingsWindowSurface)? = nil) throws -> CommunityConnectionIntegration {
        let flow = try CommunityConnectionFlow(application: application, backend: backend,
            canPresent: canPresent, showSettings: { [weak base] pane in
                await base?.windowHost.present(paneID: pane)
            }, makeFirstRun: makeFirstRun)
        CommunityPlacementBinding.install(on: placementSource, application: application)
        let entry = try CommunityConnectionIntegration(base: base, flow: flow)
        try CommunityConnectionWiring.requireInstalled(entry, application: application, backend: backend)
        return entry
    }
    public static func makeDelegate(surfaces: any NativeSurfaceProvider,
                                    companion: any CommunityCompanionSurface,
                                    consentBackend: CommunityConnectionBackend,
                                    transport: (any CLITransport)? = nil,
                                    statusItemTitle: String = "ModelPlan",
                                    makeSettings: @escaping @MainActor (LifecycleCoordinator) throws -> any CommunitySettingsIntegration) -> CommunityDelegate {
        let delegate = CommunityDelegate(surfaces: surfaces, companion: companion, transport: transport,
                                         statusItemTitle: statusItemTitle, makeSettings: makeSettings)
        consentBackend.onCanonicalReadback = { [weak delegate] _ in delegate?.refreshAfterCanonicalConsent() }
        return delegate
    }
}
