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
                                       canPresent: @escaping @MainActor () -> Bool) throws -> CommunityConnectionIntegration {
        let flow = try CommunityConnectionFlow(application: application, backend: backend,
            canPresent: canPresent, showSettings: { [weak base] pane in
                await base?.windowHost.present(paneID: pane)
            })
        let entry = try CommunityConnectionIntegration(base: base, flow: flow)
        try CommunityConnectionWiring.requireInstalled(entry, application: application, backend: backend)
        return entry
    }
    public static func makeDelegate(surfaces: any NativeSurfaceProvider,
                                    companion: any CommunityCompanionSurface,
                                    transport: (any CLITransport)? = nil,
                                    makeSettings: @escaping @MainActor (LifecycleCoordinator) throws -> any CommunitySettingsIntegration) -> CommunityDelegate {
        CommunityDelegate(surfaces: surfaces, companion: companion, transport: transport, makeSettings: makeSettings)
    }
}
