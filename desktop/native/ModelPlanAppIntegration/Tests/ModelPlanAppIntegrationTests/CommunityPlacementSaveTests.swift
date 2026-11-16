// SPDX-License-Identifier: MIT
import XCTest
import ModelPlanDock
import ModelPlanSettings
@testable import ModelPlanAppIntegration

/// The Dock's committed-placement port, as the widget host calls it after a drop.
@MainActor private final class PlacementRouteProbe: CommunityDockSettingsRouting {
    var onPlacementObserved: ((DockEdgePlacement?, Bool) -> Void)?
    var commitDisplayPlacement: ((String, SettingsDockEdge, Double) -> Void)?
    var displayChoicesChanged: (([SettingsDisplayChoice]) -> Void)?
    var catalogueChanged: (([SettingsSubscription]) -> Void)?
}

/// An edge-changing ring carry presented its drop while the help-hint host (which writes the same store directly)
/// saved hint state, so the drop's single `try?` commit met a stale revision and the new edge was never saved.
@MainActor final class CommunityPlacementSaveTests: XCTestCase {
    private func coordinator() throws -> (SettingsStore, SettingsApplicationCoordinator, PlacementRouteProbe) {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("placement-save-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let store = try SettingsStore(url: folder.appendingPathComponent("settings.json"))
        let application = SettingsApplicationCoordinator(store: store) { _ in }
        let probe = PlacementRouteProbe()
        CommunityPlacementBinding.install(on: probe, application: application)
        return (store, application, probe)
    }
    private func saved(_ store: SettingsStore, until condition: (SettingsPreferences) -> Bool) async throws -> SettingsPreferences {
        let deadline = ContinuousClock.now + .seconds(5)
        var value = await store.snapshot().preferences
        while !condition(value) && ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(20)); value = await store.snapshot().preferences
        }
        return value
    }

    func testADropIsSavedWhenAnotherWriterAdvancedTheStoreFirst() async throws {
        let (store, application, probe) = try coordinator()
        await application.reload()
        let loaded = try XCTUnwrap(application.editor.snapshot?.revision)
        // Another app-owned writer (the help-hint host) saves to the same store behind the editor's back.
        _ = try await store.update { $0.autoHide = false }
        let current = await store.snapshot().revision
        XCTAssertGreaterThan(current, loaded, "precondition: the editor's revision is stale")

        let commit = try XCTUnwrap(probe.commitDisplayPlacement, "the binding installs the placement commit")
        commit("primary", .bottom, 0.25)
        let value = try await saved(store) { $0.dockEdge == .bottom }
        XCTAssertEqual(value.dockEdge, .bottom, "the drop is saved, not dropped on a stale revision")
        XCTAssertEqual(value.dockDisplayID, "primary")
        XCTAssertEqual(value.dockAlongFraction, 0.25, accuracy: 1e-9)
        XCTAssertFalse(value.autoHide, "the other writer's change is kept")
    }

    func testANewerDropReplacesAnUnsavedOlderOne() async throws {
        let (store, application, probe) = try coordinator()
        await application.reload()
        let commit = try XCTUnwrap(probe.commitDisplayPlacement)
        commit("primary", .left, 0.2)
        commit("primary", .top, 0.7)
        let value = try await saved(store) { $0.dockEdge == .top && !application.editor.isSaving }
        try await Task.sleep(for: .milliseconds(100))
        let settled = await store.snapshot().preferences
        XCTAssertEqual(value.dockEdge, .top)
        XCTAssertEqual(settled.dockEdge, .top, "the last drop wins")
        XCTAssertEqual(settled.dockAlongFraction, 0.7, accuracy: 1e-9)
    }
}
