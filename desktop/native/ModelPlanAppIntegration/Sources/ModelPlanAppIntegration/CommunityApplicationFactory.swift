// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanCore
import ModelPlanShell
import ModelPlanCommunityHost
import ModelPlanSettings

/// Consent/Settings composition shared by the normal executable and construction checks.
@MainActor public enum CommunityApplicationFactory {
    public static func makeConsentPort(bundle: URL, transport: any ConsentJSONTransport) -> CommunityCLIConsentPort {
        CommunityCLIConsentPort(transport: transport, apiAvailable: CommunityConsentBundleIdentity.matches(bundle: bundle))
    }
    public static func makeSettingsContext(bundle: URL, availability: SettingsConnectionAvailability,
                                           operatingSystem: OperatingSystemVersion = ProcessInfo.processInfo.operatingSystemVersion) -> SettingsPageContext {
        var context = SettingsPageContext()
        let infoURL = bundle.appendingPathComponent("Contents/Info.plist")
        if let size = try? infoURL.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 65536,
           let data = try? Data(contentsOf: infoURL), data.count <= 65536,
           let info = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
            context.about.appVersion = info["CFBundleShortVersionString"] as? String ?? info["CFBundleVersion"] as? String ?? "unknown"
        }
        let verified = availability.reason == nil && availability.canInspect
        context.about.cliVersion = verified ? CommunityConsentBundleIdentity.version : "unknown"
        context.about.cliState = verified ? .ready : .unavailable
        context.about.macOSVersion = "\(operatingSystem.majorVersion).\(operatingSystem.minorVersion).\(operatingSystem.patchVersion)"
        #if arch(x86_64)
        context.about.architecture = .intelUntested
        #endif
        return context
    }
    public static func connectSettings(base: CommunitySettingsSession,
                                       application: SettingsApplicationCoordinator,
                                       backend: any SettingsConnectionAllowing,
                                       placementSource: (any CommunityPlacementProducing)? = nil,
                                       canPresent: @escaping @MainActor () -> Bool,
                                       makeFirstRun: (@MainActor (SettingsEditor) -> any SettingsWindowSurface)? = nil) throws -> CommunityConnectionIntegration {
        let flow = try CommunityConnectionFlow(application: application, backend: backend,
            canPresent: canPresent, showSettings: { [weak base] pane in
                await base?.windowHost.present(paneID: pane)
            }, makeFirstRun: makeFirstRun)
        if let canonical = backend as? CommunityConnectionBackend { try canonical.bindPresentation(to: application.editor) }
        if let placementSource { CommunityPlacementBinding.install(on: placementSource, application: application) }
        let entry = try CommunityConnectionIntegration(base: base, flow: flow)
        try CommunityConnectionWiring.requireInstalled(entry, application: application, backend: backend)
        return entry
    }
    public static func makeDelegate(surfaces: any NativeSurfaceProvider,
                                    companion: (any CommunityCompanionSurface)? = nil,
                                    consentBackend: CommunityConnectionBackend,
                                    transport: (any CLITransport)? = nil,
                                    statusItemTitle: String = "ModelPlan",
                                    makeSettings: @escaping @MainActor (LifecycleCoordinator) throws -> any CommunitySettingsIntegration) -> CommunityDelegate {
        let delegate = CommunityDelegate(surfaces: surfaces, companion: companion, transport: transport,
                                         statusItemTitle: statusItemTitle, statusItemImage: CommunityMenuBarResources.templateImage(),
                                         menuBarProvider: CommunityMenuBarProjector(), makeSettings: makeSettings)
        consentBackend.onCanonicalReadback = { [weak delegate] _ in delegate?.refreshAfterCanonicalConsent() }
        return delegate
    }
}
