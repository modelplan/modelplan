// SPDX-License-Identifier: MIT
import XCTest
import ModelPlanEngineClient
import ModelPlanSettings
import ModelPlanResources
@testable import ModelPlanAppIntegration

/// macrevb-1096-9 (D324/D327): only the installed app samples this Mac. A test or fixture app made through the normal
/// entry, without the SPI flag and without asking, leaves the resource plugin out: no sampler, no reader, no ring, so
/// the empty-Dock fixtures (OfficialDockEntryJourneyTests, SettingsWindowHostTests) keep their empty station.
@MainActor final class ResourcePluginInstallTests: XCTestCase {
    private func make(installs: Bool?, reader: (() -> ResourceReader)? = nil) async throws -> EngineDockMenuApplication {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("resource-install-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let store = try SettingsStore(url: root.appendingPathComponent("settings.json"))
        try await store.update { $0.language = .english; $0.autoHide = false }
        let configuration = EngineClientConfiguration(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic",
                                                      allowedEnvironment: [:], offline: true, readOnly: true)
        if let installs {
            return EngineRowsEntry.make(configuration: configuration, settingsStore: store, createsNativePanels: false,
                                        dockEnvironment: normalEntryTestEnvironment, installsResourcePlugin: installs, resourceReader: reader, activateSettings: {})
        }
        return EngineRowsEntry.make(configuration: configuration, settingsStore: store, createsNativePanels: false,
                                    dockEnvironment: normalEntryTestEnvironment, activateSettings: {})
    }

    func testAFixtureAppLeavesTheResourcePluginOut() async throws {
        let app = try await make(installs: nil)
        await app.prepare(); app.allowDockPresentation()
        let dock = app.composition.dock; defer { dock.close() }
        // The installation is asynchronous (it loads the saved plugin choices first); give it the time it would take.
        try await Task.sleep(nanoseconds: 400_000_000)
        XCTAssertNil(app.resourcePlugin, "a fixture app never samples this Mac")
        XCTAssertNil(app.cockpitPluginModel)
    }

    /// macrevb-1096-10: the fixture that opts in supplies a counting synthetic reader, so installing the plugin can never
    /// reach SystemResourceReader (this Mac's CPU, memory and disk). Only this reader is ever asked to sample.
    private final class CountingReader: ResourceReader {
        private(set) var reads = 0
        func read(uptime: TimeInterval, unixMs: Int64) -> ResourceSample? { reads += 1; return nil }
    }

    func testTheInstalledAppAsksForTheResourcePlugin() async throws {
        let reader = CountingReader()
        let app = try await make(installs: true, reader: { reader })
        await app.prepare(); app.allowDockPresentation()
        let dock = app.composition.dock; defer { dock.close() }
        for _ in 0..<150 where app.resourcePlugin == nil { try await Task.sleep(nanoseconds: 20_000_000) }
        XCTAssertNotNil(app.resourcePlugin, "the app that asks (ModelPlanCommunityApp) gets the default-on resource plugin")
        XCTAssertNotNil(app.cockpitPluginModel)
    }
}
