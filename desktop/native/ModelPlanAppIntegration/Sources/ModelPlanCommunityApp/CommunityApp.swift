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
        #if DEBUG && MODELPLAN_E2E_JOURNEY
        // Headless native panels keep the real store on desktop polling, not visible-account refresh.
        let dock = ProductionDockFactory.community(createsNativePanels: !CommunityJourneyCI.enabled)
        #else
        let dock = ProductionDockFactory.community()
        #endif
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
        let delegate = CommunityApplicationFactory.makeDelegate(surfaces: surfaces, companion: dock, consentBackend: backend, transport: transport) { gate in
            let support = try FileManager.default.url(for: .applicationSupportDirectory,
                in: .userDomainMask, appropriateFor: nil, create: false)
            let url = support.appendingPathComponent("ModelPlan/Native/settings-v1.json")
            let store = try SettingsStore(url: url)
            let context = CommunityApplicationFactory.makeSettingsContext(bundle: Bundle.main.bundleURL, availability: consent.availability)
            let application = SettingsApplicationCoordinator(store: store, context: context,
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
            let base = CommunitySettingsSession(application: application, canPresent: { [weak gate] in gate?.canPresent == true },
                makeHelp: { application in
                    let help = await InstrumentHelpComposition.restored(application: application)
                    surfaces.bindHelp(help)
                    return help
                })
            #if DEBUG && MODELPLAN_E2E_JOURNEY
            if CommunityJourneyCI.enabled {
                return try CommunityApplicationFactory.connectSettings(base: base, application: application, backend: backend, placementSource: dock,
                    canPresent: { [weak gate] in gate?.canPresent == true }, makeFirstRun: E2EJourney.makeFirstRun)
            }
            #endif
            return try CommunityApplicationFactory.connectSettings(base: base, application: application, backend: backend, placementSource: dock,
                canPresent: { [weak gate] in gate?.canPresent == true })
        }
        #if DEBUG && MODELPLAN_E2E_JOURNEY
        if CommunityJourneyCI.enabled {
            NSApplication.shared.delegate = delegate
            Task { @MainActor in await E2EJourney.run(delegate: delegate, dock: dock, backend: backend, consent: consent) }
            withExtendedLifetime((delegate, dock, surfaces)) { NSApplication.shared.run() }
            return
        }
        #endif
        // Inspect only the composition retained by normal Settings configuration; do not start the runtime.
        if ProcessInfo.processInfo.environment["MODELPLAN_APP_SMOKE"] == "1" {
            _ = NSApplication.shared
            Task { @MainActor in
                do {
                    @MainActor func views(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(views) }
                    let gate = LifecycleCoordinator(store: SnapshotStore(transport: transport))
                    delegate.configureSettings(gate)
                    let integration = delegate.settingsIntegration as? CommunityConnectionIntegration
                    await integration?.restorePreferences()
                    let application = integration?.flow.application
                    let firstRun = application.map { SettingsFirstRunController(editor: $0.editor) }
                    await firstRun?.prepare()
                    let connections = application?.editor.connections, preferences = application?.editor.snapshot?.preferences
                    let bound = connections?.isBound(to: backend) == true
                    let capability: SettingsConnectionAvailability? = bound ? backend.settingsConnectionAvailability : nil
                    let actualDock = delegate.companionSurface as? StaticDockPreviewHost
                    let section = (firstRun?.window?.contentView).flatMap { views($0).first { $0.accessibilityIdentifier() == "settings.connections" } }
                    let status = section?.subviews.compactMap { $0 as? NSTextField }.dropFirst().first?.stringValue
                    let helper = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/modelplan"), process = Process(), pipe = Pipe()
                    process.executableURL = helper; process.arguments = ["--help"]; process.standardInput = FileHandle.nullDevice
                    process.standardOutput = pipe; process.standardError = pipe; try process.run()
                    let help = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self); process.waitUntilExit()
                    let consentJSON = help.range(of: #"(?m)^\s*modelplan\s+consent\b"#, options: .regularExpression) != nil && help.contains("--json")
                    let report: [String: Any] = ["schemaVersion": 1,
                        "dockHostType": delegate.companionSurface.map { String(reflecting: type(of: $0)) as Any } ?? NSNull(),
                        "dockHostPurpose": actualDock.map { String(describing: $0.purpose) as Any } ?? NSNull(),
                        "connectionServicePresent": connections.map { $0.hasAllowanceBackend as Any } ?? NSNull(), "connectionServiceBound": bound,
                        "connectionAvailable": connections.map { $0.isAvailable as Any } ?? NSNull(), "connectionBackendAvailable": capability.map { $0.hasAnyAction as Any } ?? NSNull(),
                        "firstRunConnectionStatus": status.map { $0 as Any } ?? NSNull(), "consentPortPresent": bound,
                        "consentAPIAvailable": capability.map { $0.canInspect as Any } ?? NSNull(),
                        "connectionAvailabilityReason": capability.flatMap { $0.reason }.map { $0.rawValue as Any } ?? NSNull(),
                        "cliSupportsConsentJSON": process.terminationStatus == 0 && consentJSON, "cliHelp": help, "cliHelpExitCode": process.terminationStatus, "cliPath": helper.path,
                        "showDock": preferences.map { $0.showDock as Any } ?? NSNull(), "autoHide": preferences.map { $0.autoHide as Any } ?? NSNull(), "edge": preferences.map { $0.dockEdge.rawValue as Any } ?? NSNull(),
                        "home": NSHomeDirectory(), "visibleWindows": NSApplication.shared.windows.filter(\.isVisible).count]
                    let output = ProcessInfo.processInfo.environment["MODELPLAN_APP_SMOKE_REPORT"]!
                    try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: URL(fileURLWithPath: output), options: .atomic)
                    exit(0)
                } catch { fputs("app-smoke report FAIL \(error)\n", stderr); exit(70) }
            }
            NSApplication.shared.run(); return
        }
        NSApplication.shared.delegate = delegate
        withExtendedLifetime((delegate, dock, surfaces)) { NSApplication.shared.run() }
    }
}
