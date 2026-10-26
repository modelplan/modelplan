// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanSettings
import ModelPlanShell
import ModelPlanCommunityHost
import ModelPlanAppIntegration

/// Normal entry is above both packages. Probe modes remain in the shared root host and skip Settings.
@main struct CommunityApp {
    @MainActor static func main() {
        let delegate = CommunityDelegate(surfaces: NeutralSurfaceProvider()) { gate in
            let support = try FileManager.default.url(for: .applicationSupportDirectory,
                in: .userDomainMask, appropriateFor: nil, create: false)
            let url = support.appendingPathComponent("ModelPlan/Native/settings-v1.json")
            let store = try SettingsStore(url: url)
            let application = SettingsApplicationCoordinator(store: store,
                environment: SettingsWindowController.systemEnvironment()) { transaction in
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
            return CommunitySettingsSession(application: application, canPresent: { [weak gate] in gate?.canPresent == true })
        }
        NSApplication.shared.delegate = delegate
        withExtendedLifetime(delegate) { NSApplication.shared.run() }
    }
}
