// SPDX-License-Identifier: MIT
#if MODELPLAN_DOCK_REAL_STRIP_JOURNEY
import AppKit
import Foundation
import XCTest
import ModelPlanDock
import ModelPlanSettings
@testable import ModelPlanAppIntegration

/// Uses a reviewed CLI and a disposable profile through the normal detached Dock entry.
@MainActor final class DockStripRealServerTests: XCTestCase {
    func testD20RealServerPaintsOnlyTheAffectedStripPitches() async throws {
        try await exercise(native: false)
    }

    #if MODELPLAN_DOCK_NATIVE_JOURNEY
    func testD20NativeStripPaintsOnlyTheAffectedPitches() async throws {
        try await exercise(native: true)
    }
    #endif

    private func exercise(native: Bool) async throws {
        let path = try XCTUnwrap(ProcessInfo.processInfo.environment["MODELPLAN_DOCK_TEST_CLI"])
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: path))
        let executable = URL(fileURLWithPath: path)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("d20-real-strip-" + UUID().uuidString)
        let config = root.appendingPathComponent(".config/modelplan")
        try FileManager.default.createDirectory(at: config, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: root) }
        let environment = ["HOME": root.path, "TMPDIR": root.path, "PATH": "/usr/bin:/bin", "LANG": "C"]
        let seed = Process()
        seed.executableURL = executable
        seed.arguments = ["consent", "init", "--json"]
        seed.environment = environment
        seed.standardInput = FileHandle.nullDevice
        seed.standardOutput = FileHandle.nullDevice
        seed.standardError = FileHandle.nullDevice
        try seed.run()
        let seedDeadline = ContinuousClock.now + .seconds(5)
        while seed.isRunning, ContinuousClock.now < seedDeadline { try await Task.sleep(for: .milliseconds(10)) }
        if seed.isRunning { seed.terminate(); return XCTFail("Temporary consent initialization timed out") }
        XCTAssertEqual(seed.terminationStatus, 0)

        // The actual producer reads local.json as declared quota, with no provider credentials or calls.
        let ids = ["synthetic-ok", "synthetic-mid", "synthetic-critical"]
        let iso = ISO8601DateFormatter()
        func writeReadings(_ remaining: [Int]) throws {
            let now = Date()
            let windows = zip(ids, remaining).map { id, percent -> [String: Any] in
                ["planId": id, "kind": "five_hour", "remainingPercent": percent, "resetMode": "rolling",
                 "observedAt": iso.string(from: now.addingTimeInterval(-15)),
                 "resetAt": iso.string(from: now.addingTimeInterval(7_200))]
            }
            let fixture: [String: Any] = ["schemaVersion": 1, "plans": ids.map { ["planId": $0] }, "windows": windows]
            try JSONSerialization.data(withJSONObject: fixture).write(to: config.appendingPathComponent("local.json"), options: .atomic)
        }
        try writeReadings([51, 50, 25])

        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        let defaults = await store.snapshot()
        XCTAssertTrue(defaults.preferences.sliverAlert)
        _ = try await store.update { $0.autoHide = true; $0.motion = .on; $0.dockEdge = .bottom }
        let display: DockDisplayArea
        if native {
            _ = NSApplication.shared
            let screen = try XCTUnwrap(NSScreen.main)
            display = .init(id: "synthetic", frame: screen.frame, visibleFrame: screen.visibleFrame)
        } else {
            let frame = CGRect(x: 0, y: 0, width: 1440, height: 900)
            display = .init(id: "synthetic", frame: frame, visibleFrame: frame)
        }
        #if MODELPLAN_DOCK_NATIVE_JOURNEY
        if native { EngineRowsEntry.nativeJourneyProfile = root }
        defer { if native { EngineRowsEntry.nativeJourneyProfile = nil } }
        #endif
        let pointer = CGPoint(x: display.visibleFrame.midX, y: display.visibleFrame.midY)
        let app = EngineRowsEntry.make(configuration: .init(executableURL: executable, applicationVersion: "synthetic-d20",
            allowedEnvironment: environment, offline: true, readOnly: true), settingsStore: store, createsNativePanels: native,
            bundleURL: root.appendingPathComponent("Synthetic.app"),
            dockEnvironment: { .init(displays: [display], layouts: [], primaryDisplayID: display.id, pointer: pointer) },
            activateSettings: {})
        addTeardownBlock { @MainActor in await app.composition.stop() }
        await app.prepare()
        XCTAssertNil(app.loginServiceAdapter)
        XCTAssertNil(app.notificationAuthorizationService)
        app.allowDockPresentation()
        let delivery = try await app.composition.client.start()
        XCTAssertEqual(app.composition.store.snapshot.connection, .ready(delivery))

        let dock = app.composition.dock
        func wait(_ description: String, until predicate: () -> Bool) async throws {
            let deadline = ContinuousClock.now + .seconds(4)
            while !predicate(), ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(10)) }
            XCTAssertTrue(predicate(), description)
        }
        func readings() -> [String: Double] {
            let rows = app.composition.store.snapshot.rows?.projection.rows ?? []
            return Dictionary(uniqueKeysWithValues: rows.compactMap { row in
                guard row.id.hasPrefix("declared:synthetic-"),
                      let value = row.accounts.first?.windows.first?.remainingPercent else { return nil }
                return (String(row.id.dropFirst("declared:".count)), value)
            })
        }
        try await wait("Require all three real-server quota readings") { readings() == [ids[0]: 51, ids[1]: 50, ids[2]: 25] }
        XCTAssertEqual(dock.edgePresentation?.state, .sliver)
        func currentStrip() throws -> DockSliverView {
            let placement = try XCTUnwrap(dock.edgePresentation?.placement)
            XCTAssertEqual(placement.edge, .bottom)
            #if MODELPLAN_DOCK_NATIVE_JOURNEY
            if native {
                let panel = try XCTUnwrap(dock.nativePanel)
                XCTAssertTrue(panel.isVisible)
                XCTAssertEqual(panel.frame.minY, display.visibleFrame.minY, accuracy: 1)
                return try XCTUnwrap(panel.contentView as? DockSliverView)
            }
            #endif
            return try dock.prepareSliver(size: placement.sliverFrame.size)
        }
        let strip = try currentStrip()
        func capture() throws -> NSBitmapImageRep {
            let bitmap = try XCTUnwrap(strip.bitmapImageRepForCachingDisplay(in: strip.bounds))
            strip.cacheDisplay(in: strip.bounds, to: bitmap)
            return bitmap
        }
        func sample(_ bitmap: NSBitmapImageRep, at segment: DockSliverResolvedColorSegment) throws -> NSColor {
            let along = (segment.from + segment.through) / 2
            let x = min(bitmap.pixelsWide - 1, Int(Double(bitmap.pixelsWide) * along))
            let color = try XCTUnwrap(bitmap.colorAt(x: x, y: bitmap.pixelsHigh / 2)?.usingColorSpace(.sRGB))
            XCTAssertGreaterThan(color.alphaComponent, 0)
            return color
        }
        func assertRole(_ percent: Double, _ role: DockQuotaStatus?, line: UInt = #line) throws {
            let binding = try XCTUnwrap(strip.quotaSegmentColorRolesForChecks.first { $0.remainingPercent == percent }, line: line)
            XCTAssertEqual(binding.quotaRole, role, line: line)
            XCTAssertEqual(binding.opacity, role == nil ? 0 : 0.18, line: line)
        }
        XCTAssertEqual(strip.quotaSegmentColorRolesForChecks.count, 3)
        try assertRole(51, nil)
        try assertRole(50, .warning)
        try assertRole(25, .critical)
        let original = strip.quotaSegmentColorRolesForChecks
        let normal = try XCTUnwrap(original.first { $0.remainingPercent == 51 })
        let warning = try XCTUnwrap(original.first { $0.remainingPercent == 50 })
        let critical = try XCTUnwrap(original.first { $0.remainingPercent == 25 })
        XCTAssertEqual(warning.through - warning.from, critical.through - critical.from, accuracy: 0.001)
        let overlap = min(warning.through, critical.through) - max(warning.from, critical.from)
        // Adjacent registered pitches can share a subpixel edge. Reject an
        // overlap larger than a quarter of a 2x backing pixel.
        XCTAssertLessThanOrEqual(overlap * Double(strip.bounds.width), 0.125)
        let withAlerts = try capture()
        XCTAssertTrue(strip.accessibilityPerformPress())
        XCTAssertEqual(dock.edgePresentation?.state, .expanded)
        try await wait("The normal leave policy returns to the strip") { dock.edgePresentation?.state == .sliver }
        XCTAssertTrue(try currentStrip() === strip)
        XCTAssertEqual(try capture().tiffRepresentation, withAlerts.tiffRepresentation)

        try writeReadings([51, 52, 25])
        _ = try await app.composition.client.subscribeRows(timeout: .seconds(4))
        try await wait("Require the improved reading from the real server") { readings()[ids[1]] == 52 }
        XCTAssertEqual(app.composition.store.snapshot.delivery, delivery)
        XCTAssertTrue(try currentStrip() === strip)
        try assertRole(52, nil)
        try assertRole(25, .critical)
        let improved = try capture()
        _ = try await app.settingsHost.application.editor.commit(SettingsB20Edit.sliverAlert(false))
        XCTAssertTrue(try currentStrip() === strip)
        XCTAssertTrue(strip.quotaSegmentColorRolesForChecks.isEmpty)
        let neutral = try capture()
        XCTAssertEqual(try sample(withAlerts, at: normal), try sample(neutral, at: normal), "OK pitch must stay neutral")
        XCTAssertNotEqual(try sample(withAlerts, at: warning), try sample(neutral, at: warning), "Warning pitch is painted")
        XCTAssertNotEqual(try sample(withAlerts, at: critical), try sample(neutral, at: critical), "Critical pitch is painted")
        XCTAssertEqual(try sample(improved, at: warning), try sample(neutral, at: warning), "Improvement clears only the warning paint")
        XCTAssertEqual(try sample(improved, at: critical), try sample(withAlerts, at: critical), "The critical pitch survives unrelated improvement")
    }
}
#endif
