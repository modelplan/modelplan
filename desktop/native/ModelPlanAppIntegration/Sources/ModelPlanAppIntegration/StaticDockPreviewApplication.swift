// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanSettings
import ModelPlanCore
import ModelPlanCommunityHost

/// Explicit self-test entry; it never replaces the normal Community launch or production updater.
@MainActor public enum StaticDockPreviewApplication {
    public static func run(appearance: StaticDockPreviewHost.Appearance? = nil,
                           transport: (any CLITransport)? = nil, statusItemTitle: String = "ModelPlan",
                           settingsURL: URL? = nil) {
        let dock = StaticDockPreviewHost(purpose: .selfTest, appearance: appearance)
        let surfaces = CommunityInstrumentSurfaceProvider(openWebsite: { link in
            guard let url = URL(string: link.url), url.scheme == "https", url.host == "modelplan.ai",
                  url.user == nil, url.password == nil, url.port == nil else { return }
            NSWorkspace.shared.open(url)
        })
        let environment: @MainActor () -> SettingsEnvironment = {
            var value = SettingsWindowController.systemEnvironment()
            value.reduceMotion = true; value.entranceAccepted = false
            return value
        }
        let delegate = CommunityDelegate(surfaces: surfaces, companion: dock, transport: transport,
                                         statusItemTitle: statusItemTitle) { gate in
            let support = try FileManager.default.url(for: .applicationSupportDirectory,
                in: .userDomainMask, appropriateFor: nil, create: false)
            let store = try SettingsStore(url: settingsURL ?? support.appendingPathComponent("ModelPlan/DockSelfTest/settings-v1.json"))
            var context = SettingsPageContext()
            context.capabilities.login = .unavailable
            context.about.appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "self-test"
            let application = SettingsApplicationCoordinator(store: store, context: context, environment: environment()) { value in
                dock.apply(value); surfaces.apply(value)
                let name: NSAppearance.Name? = value.snapshot.preferences.theme == .system ? nil : value.snapshot.preferences.theme == .day ? .aqua : .darkAqua
                if NSApplication.shared.appearance?.name != name { NSApplication.shared.appearance = name.flatMap { NSAppearance(named: $0) } }
            }
            dock.commitDisplayPlacement = { [weak application] displayID, next, fraction in
                guard let application else { return }
                Task { try? await application.editor.commit(.dockPlacement(displayID: displayID, edge: next, alongFraction: fraction)) }
            }
            dock.displayChoicesChanged = { [weak application] displays in
                guard let application else { return }
                var current = application.editor.context
                current.displays = displays
                application.update(context: current)
            }
            dock.catalogueChanged = { [weak application] subscriptions in
                guard let application else { return }
                var current = application.editor.context
                current.subscriptions = subscriptions
                application.update(context: current)
            }
            return CommunitySettingsSession(application: application, canPresent: { [weak gate] in gate?.canPresent == true },
                environment: environment, makeHelp: { application in
                    let help = await InstrumentHelpComposition.restored(application: application)
                    surfaces.bindHelp(help)
                    return help
                })
        }
        NSApplication.shared.delegate = delegate
        withExtendedLifetime((delegate, dock, surfaces)) { NSApplication.shared.run() }
    }
}
