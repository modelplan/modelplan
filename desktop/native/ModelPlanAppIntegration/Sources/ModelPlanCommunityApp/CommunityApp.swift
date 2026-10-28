// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanSettings
import ModelPlanCore
import ModelPlanShell
import ModelPlanCommunityHost
import ModelPlanAppIntegration

/// Normal entry is above both packages. Probe modes remain in the shared root host and skip Settings.
@main struct CommunityApp {
    @MainActor static func main() {
        let surfaces = CommunityInstrumentSurfaceProvider(openWebsite: { link in
            guard let url=URL(string:link.url),url.scheme=="https",url.host=="modelplan.ai",
                  url.user==nil,url.password==nil,url.port==nil else { return }
            NSWorkspace.shared.open(url)
        })
        let delegate = CommunityDelegate(surfaces: surfaces) { gate in
            let support = try FileManager.default.url(for: .applicationSupportDirectory,
                in: .userDomainMask, appropriateFor: nil, create: false)
            let url = support.appendingPathComponent("ModelPlan/Native/settings-v1.json")
            let store = try SettingsStore(url: url)
            let application = SettingsApplicationCoordinator(store: store,
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
            return CommunitySettingsSession(application: application, canPresent: { [weak gate] in gate?.canPresent == true },
                makeHelp: { application in
                    let help = await InstrumentHelpComposition.restored(application: application)
                    surfaces.bindHelp(help)
                    return help
                })
        }
        // Explicit packaged-app test mode: inspect the existing factory; never start the app lifecycle.
        if ProcessInfo.processInfo.environment["MODELPLAN_APP_SMOKE"] == "1" {
            fputs("app-smoke entry started\n", stderr); _ = NSApplication.shared
            Task { @MainActor in
                do {
                    fputs("app-smoke task started\n", stderr)
                    func field(_ object: Any, _ name: String) -> Any? {
                        guard let value = Mirror(reflecting: object).children.first(where: { $0.label == name })?.value else { return nil }
                        let mirror = Mirror(reflecting: value)
                        return mirror.displayStyle == .optional ? mirror.children.first?.value : value
                    }
                    func views(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(views) }
                    let factory = field(delegate, "makeSettings") as! (@MainActor (LifecycleCoordinator) throws -> any CommunitySettingsIntegration); fputs("app-smoke factory resolved\n", stderr)
                    let gate = LifecycleCoordinator(store: SnapshotStore(transport: BundledCLI(bundle: Bundle.main.bundleURL)))
                    let session = try factory(gate) as! CommunitySettingsSession; fputs("app-smoke factory called\n", stderr); await session.restorePreferences()
                    let editor = session.windowHost.application.editor, firstRun = SettingsFirstRunController(editor: session.windowHost.application.editor)
                    await firstRun.prepare(); fputs("app-smoke first run prepared\n", stderr)
                    let preferences = editor.snapshot!.preferences, connections = editor.connections
                    let section = views(firstRun.window!.contentView!).first { $0.accessibilityIdentifier() == "settings.connections" }
                    let status = section?.subviews.compactMap { $0 as? NSTextField }.dropFirst().first?.stringValue
                    let service = field(connections, "service"), dock = field(delegate, "companion")
                    let port = service.flatMap { field($0, "consentPort") } ?? field(delegate, "consentPort")
                    let helper = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/modelplan"), process = Process(), pipe = Pipe()
                    process.executableURL = helper; process.arguments = ["--help"]; process.standardInput = FileHandle.nullDevice
                    process.standardOutput = pipe; process.standardError = pipe; try process.run()
                    let help = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self); process.waitUntilExit()
                    let consentJSON = help.range(of: #"(?m)^\s*modelplan\s+consent\b"#, options: .regularExpression) != nil && help.contains("--json")
                    let report: [String: Any] = ["schemaVersion": 1, "dockHostType": dock.map { String(reflecting: type(of: $0)) as Any } ?? NSNull(),
                        "connectionServicePresent": service != nil, "connectionAvailable": connections.isAvailable,
                        "firstRunConnectionStatus": status.map { $0 as Any } ?? NSNull(), "consentPortPresent": port != nil,
                        "consentAPIAvailable": port.flatMap { field($0, "apiAvailable") } ?? NSNull(),
                        "cliSupportsConsentJSON": process.terminationStatus == 0 && consentJSON, "cliHelp": help, "cliHelpExitCode": process.terminationStatus, "cliPath": helper.path,
                        "showDock": preferences.showDock, "autoHide": preferences.autoHide, "edge": preferences.dockEdge.rawValue,
                        "home": NSHomeDirectory(), "visibleWindows": NSApplication.shared.windows.filter(\.isVisible).count]
                    let output = ProcessInfo.processInfo.environment["MODELPLAN_APP_SMOKE_REPORT"]!
                    try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: URL(fileURLWithPath: output), options: .atomic)
                    exit(0)
                } catch { fputs("app-smoke report FAIL \(error)\n", stderr); exit(70) }
            }
            NSApplication.shared.run(); return
        }
        NSApplication.shared.delegate = delegate
        withExtendedLifetime(delegate) { NSApplication.shared.run() }
    }
}
