// SPDX-License-Identifier: MIT
#if MODELPLAN_VERIFICATION_ROWS
import AppKit
import XCTest
import ModelPlanSettings
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanWire
@_spi(DockResourceChecks) import ModelPlanDock
@testable import ModelPlanAppIntegration

@MainActor final class VerificationRowsTests: XCTestCase {
    func testEverySnapshotReachesTheNormalDockEntry() async throws {
        _ = NSApplication.shared
        let fixtures = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../verification/fixtures/dock-scenarios").standardizedFileURL
        let cases = [("mixed-overflow.json", 64), ("single-window.json", 3), ("reset-announced.json", 1), ("reset-confirmed.json", 1), ("stale.json", 3), ("credits-grouped.json", 3), ("credits-under-one.json", 3), ("reserve-unknown-unit.json", 3)]
        for (name, count) in cases {
            let home = FileManager.default.temporaryDirectory.appendingPathComponent("modelplan-verification-test-" + UUID().uuidString)
            try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: home) }
            try Data("MODELPLAN VERIFICATION HOME\n".utf8).write(to: home.appendingPathComponent(".modelplan-verification-home"))
            try FileManager.default.copyItem(at: fixtures.appendingPathComponent(name), to: home.appendingPathComponent(".modelplan-verification-rows.json"))
            let decoded = try WireDecoder.decode(WireRowsSnapshot.self, from: Data(contentsOf: fixtures.appendingPathComponent(name)))
            XCTAssertEqual(decoded.projection.invalidRowCount, 0, name)
            if name == "reset-announced.json" { XCTAssertEqual(decoded.projection.resetEvents?.map(\.status.rawValue), ["announced"]) }
            if name == "reset-confirmed.json" { XCTAssertEqual(decoded.projection.resetEvents?.map(\.status.rawValue), ["announced", "confirmed"]) }
            let store = try SettingsStore(url: home.appendingPathComponent("settings.json"))
            let app = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/never-launched"), applicationVersion: "verification", allowedEnvironment: [:], offline: true, readOnly: true), settingsStore: store, createsNativePanels: false, makeClient: { _, store in VerificationRowsClient(store: store, home: home) })
            await app.prepare(); app.allowDockPresentation(); await app.composition.start()
            XCTAssertEqual(app.composition.provider.dockContent.dockRows.count, count, name)
            let content = app.composition.presentedContent
            XCTAssertEqual(content.snapshot.inputs.count, count, name)
            XCTAssertNil(app.composition.dock.lastAppearanceError, name)
            let skin = try XCTUnwrap(app.composition.dock.dockView.presentedSkinForChecks, name)
            XCTAssertNotNil(app.composition.dock.dockView.presentedImageForChecks, name)
            if name == "mixed-overflow.json" {
                XCTAssertTrue(skin.stations.contains { ($0.overflowCount ?? 0) > 0 }, "overflow must be rendered")
            }
            if name == "single-window.json" {
                XCTAssertTrue(content.snapshot.inputs.allSatisfy { $0.windows.count == 1 && $0.windows[0].period == .week && $0.windows[0].isGeneral }, "single weekly window must be the general outer-ring input")
            }
            if name == "reset-announced.json" { XCTAssertEqual(content.signals.first?.reset?.id, "reset-announced") }
            if name == "reset-confirmed.json" { XCTAssertEqual(content.signals.first?.reset?.id, "reset-confirmed") }
            if name.hasPrefix("credits-") || name == "reserve-unknown-unit.json" {
                let reserves = content.snapshot.presentationRows.values.flatMap(\.additionalRows).filter { $0.kind == .reserve }
                XCTAssertEqual(reserves.count, 1, name)
                if name == "credits-grouped.json" { XCTAssertEqual(reserves.first?.value, "19,614") }
                if name == "credits-under-one.json" { XCTAssertEqual(reserves.first?.value, "<1") }
                if name == "reserve-unknown-unit.json" { XCTAssertEqual(reserves.first?.label, "Reserve") }
            }
            XCTAssertNil(app.composition.dock.nativePanel)
            await app.composition.stop()
        }
    }
    func testMissingMarkerFailsClosed() async throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent("missing-marker-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }
        let client = VerificationRowsClient(store: EngineStore(), home: home)
        do { _ = try await client.start(); XCTFail("unmarked home was accepted") } catch { }
    }
    func testChangedSyntheticSnapshotIsPublishedWhileClientRuns() async throws {
        let fixtures = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../verification/fixtures/dock-scenarios").standardizedFileURL
        let home = FileManager.default.temporaryDirectory.appendingPathComponent("verification-transition-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }
        try Data("MODELPLAN VERIFICATION HOME\n".utf8).write(to: home.appendingPathComponent(".modelplan-verification-home"))
        let target = home.appendingPathComponent(".modelplan-verification-rows.json")
        try Data(contentsOf: fixtures.appendingPathComponent("stale.json")).write(to: target, options: .atomic)
        let store = EngineStore()
        let client = VerificationRowsClient(store: store, home: home)
        let context = try await client.start()
        XCTAssertTrue(client.isCurrent(context))
        XCTAssertEqual(store.snapshot.rows?.sequence, 7)
        var fresh = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: fixtures.appendingPathComponent("single-window.json"))) as? [String: Any])
        fresh["sequence"] = 8
        try JSONSerialization.data(withJSONObject: fresh).write(to: target, options: .atomic)
        for _ in 0..<50 {
            if store.snapshot.rows?.sequence == 8 { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertEqual(store.snapshot.rows?.sequence, 8, "a new synthetic reading must arrive without restarting the app")
        await client.stop()
        XCTAssertFalse(client.isCurrent(context))
    }
}
#endif
