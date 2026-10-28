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
        let dock = ProductionDockFactory.community()
        let readOnly = BundledCLI(bundle: Bundle.main.bundleURL)
        let normal = BundledCLI(bundle: Bundle.main.bundleURL, desktopReadMode: .normal)
        let transport = ConsentGatedDesktopTransport(readOnly: readOnly, normal: normal)
        // Disabled until packaging verifies a containing consent-API release and its fixtures.
        let consent = CommunityCLIConsentPort(transport: readOnly)
        let backend = CommunityConnectionBackend(port: consent, desktop: transport)
        let surfaces = CommunityInstrumentSurfaceProvider(openWebsite: { link in
            guard let url=URL(string:link.url),url.scheme=="https",url.host=="modelplan.ai",
                  url.user==nil,url.password==nil,url.port==nil else { return }
            NSWorkspace.shared.open(url)
        })
        let delegate = CommunityApplicationFactory.makeDelegate(surfaces: surfaces, companion: dock, transport: transport) { gate in
            let support = try FileManager.default.url(for: .applicationSupportDirectory,
                in: .userDomainMask, appropriateFor: nil, create: false)
            let url = support.appendingPathComponent("ModelPlan/Native/settings-v1.json")
            let store = try SettingsStore(url: url)
            let application = SettingsApplicationCoordinator(store: store,
                environment: SettingsWindowController.systemEnvironment()) { transaction in
                dock.apply(transaction)
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
            dock.commitDisplayPlacement = { [weak application] id, edge, fraction in
                guard let application else { return }
                Task { _ = try? await application.editor.commit(.dockPlacement(displayID: id, edge: edge, alongFraction: fraction)) }
            }
            dock.displayChoicesChanged = { [weak application] displays in
                guard let application else { return }
                var context = application.editor.context; context.displays = displays
                application.update(context: context)
            }
            dock.catalogueChanged = { [weak application] rows in
                guard let application else { return }
                var context = application.editor.context; context.subscriptions = rows
                application.update(context: context)
            }
            let base = CommunitySettingsSession(application: application, canPresent: { [weak gate] in gate?.canPresent == true },
                makeHelp: { application in
                    let help = await InstrumentHelpComposition.restored(application: application)
                    surfaces.bindHelp(help)
                    return help
                })
            return try CommunityApplicationFactory.connectSettings(base: base, application: application,
                backend: backend, canPresent: { [weak gate] in gate?.canPresent == true })
        }
        NSApplication.shared.delegate = delegate
        withExtendedLifetime((delegate, dock, surfaces)) { NSApplication.shared.run() }
    }
}
