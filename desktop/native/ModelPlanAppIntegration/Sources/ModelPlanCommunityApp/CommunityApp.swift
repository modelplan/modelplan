// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanSettings
import ModelPlanShell
import ModelPlanCommunityHost
import ModelPlanAppIntegration
import ModelPlanCore

/// Normal entry is above both packages. Probe modes remain in the shared root host and skip Settings.
@main struct CommunityApp {
    @MainActor static func main() {
        let readOnly = BundledCLI(bundle: Bundle.main.bundleURL)
        let normal = BundledCLI(bundle: Bundle.main.bundleURL, desktopReadMode: .normal)
        let transport = ConsentGatedDesktopTransport(readOnly: readOnly, normal: normal)
        let consent = CommunityApplicationFactory.makeConsentPort(bundle: Bundle.main.bundleURL, transport: readOnly)
        let backend = CommunityConnectionBackend(port: consent, desktop: transport)
        let surfaces = CommunityInstrumentSurfaceProvider(openWebsite: { link in
            guard let url=URL(string:link.url),url.scheme=="https",url.host=="modelplan.ai",
                  url.user==nil,url.password==nil,url.port==nil else { return }
            NSWorkspace.shared.open(url)
        })
        let delegate = CommunityApplicationFactory.makeDelegate(surfaces: surfaces, consentBackend: backend, transport: transport) { gate in
            let support = try FileManager.default.url(for: .applicationSupportDirectory,
                in: .userDomainMask, appropriateFor: nil, create: false)
            let url = support.appendingPathComponent("ModelPlan/Native/settings-v1.json")
            let store = try SettingsStore(url: url)
            let context = CommunityApplicationFactory.makeSettingsContext(bundle: Bundle.main.bundleURL, availability: consent.availability)
            let application = SettingsApplicationCoordinator(store: store, context: context,
                environment: SettingsWindowController.systemEnvironment()) { transaction in
                surfaces.apply(transaction)
                // Apply the committed theme to existing neutral AppKit consumers; no OS preference is written.
                let desired: NSAppearance.Name?
                switch transaction.snapshot.preferences.theme {
                case .system: desired = nil
                case .day: desired = .aqua
                case .night: desired = .darkAqua
                }
                // Clearing the override restores real OS following, rather than reading our own old override.
                if NSApplication.shared.appearance?.name != desired {
                    NSApplication.shared.appearance = desired.flatMap { NSAppearance(named: $0) }
                }
            }
            let base = CommunitySettingsSession(application: application, canPresent: { [weak gate] in gate?.canPresent == true },
                makeHelp: { application in
                    let help = await InstrumentHelpComposition.restored(application: application)
                    surfaces.bindHelp(help)
                    return help
                })
            return try CommunityApplicationFactory.connectSettings(base: base, application: application, backend: backend,
                canPresent: { [weak gate] in gate?.canPresent == true })
        }
        NSApplication.shared.delegate = delegate
        withExtendedLifetime(delegate) { NSApplication.shared.run() }
    }
}
