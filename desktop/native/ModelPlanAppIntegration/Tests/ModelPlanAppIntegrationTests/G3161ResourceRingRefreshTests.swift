// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanSettings
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanWire
@_spi(DockResourceChecks) import ModelPlanDock
import ModelPlanResources
@testable import ModelPlanAppIntegration

/// G3-161 (WP-17 / G3-147 follow-up): the Resources plugin used to rebuild the whole Dock on every admitted sample
/// (`StaticDockPreviewHost.rebuildPass`, the official faces and the CoreImage material), 8.7 % of the app main thread in
/// the owner's `sample`. Invariant: unchanged inputs cause no Dock rebuild; a changed reading repaints the ring alone.
/// Driven through the app composition's `installResourceWidget`, the entry the app uses.
@MainActor final class G3161ResourceRingRefreshTests: XCTestCase {
    private final class Reader: ResourceReader {
        var cpu: Double = 22
        func read(uptime: TimeInterval, unixMs: Int64) -> ResourceSample? {
            let g: UInt64 = 1 << 30
            return ResourceSample(unixMs: 1_795_000_000_000 + Int64(uptime * 1000), uptime: uptime, cpuUser: cpu * 0.75, cpuSystem: cpu * 0.25, load: 2.4,
                                  memTotal: 32 * g, memApp: 9 * g, memWired: 4 * g, memCompressed: g, memCached: 12 * g, memFree: 6 * g,
                                  swapUsed: 0, pressure: .normal, diskTotal: 494 * g, diskFree: 120 * g)
        }
    }

    private func makeEntry() async throws -> EngineDockMenuApplication {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("g3161-ring-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let settings = try await expandedWidgetSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        let wall = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-12-02T00:00:00Z"))
        let rows = try HostPairedProjectionTests.rows(weekly: 75, secondWeekly: 12)
        let app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"),
            applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: settings, createsNativePanels: false,
            dockEnvironment: normalEntryTestEnvironment, deadlineNow: { wall },
            makeClient: { _, store in EntrySyntheticClient(store: store, rows: rows) }, activateSettings: {})
        await app.prepare(); app.allowDockPresentation()
        addTeardownBlock { @MainActor in await app.composition.stop() }
        return app
    }

    /// Installs the resource ring on the entry's Dock and waits for its first draw.
    private func installRing(_ app: EngineDockMenuApplication, reader: Reader) async throws -> (run: (TimeInterval) -> Void, id: String) {
        var clock: TimeInterval = 0
        var timers: [(deadline: TimeInterval, fire: @MainActor () -> Void)] = []
        let sampler = ResourceSampler(reader: reader, clock: { clock }, scheduler: { delay, _, fire in
            timers.append((clock + delay, fire)); let i = timers.count - 1
            return ResourceTimerHandle { timers[i].fire = {} }
        })
        let binding = app.composition.installResourceWidget(sampler: sampler, language: { .english })
        addTeardownBlock { _ = binding }
        func run(until end: TimeInterval) {
            while let i = timers.indices.filter({ timers[$0].deadline <= end }).min(by: { timers[$0].deadline < timers[$1].deadline }) {
                let t = timers[i]; timers[i].deadline = .infinity; clock = max(clock, t.deadline); t.fire()
            }
            clock = end
        }
        binding.setVisibility(.init(pluginEnabled: true, columnShown: false, widgetShown: true, columnSetting: 5))
        run(until: 0)
        let id = ResourceDockBridge.subscriptionID
        for _ in 0..<300 where app.composition.dock.dockView.presentedReadingsForChecks[id] == nil { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertNotNil(app.composition.dock.dockView.presentedReadingsForChecks[id]?.pluginRing, "the resource ring is on the widget")
        return ({ run($0) }, id)
    }

    /// N sampler ticks with unchanged values cause no Dock rebuild pass and no ring repaint.
    func testUnchangedSamplesCauseNoDockRebuild() async throws {
        let app = try await makeEntry()
        await app.composition.start()
        let dock = app.composition.dock
        let reader = Reader()
        let ring = try await installRing(app, reader: reader)
        let passes = dock.fullRebuildPassesForChecks, repaints = dock.ringOnlyRefreshesForChecks
        for tick in 1...12 { ring.run(Double(tick) * 10) }
        XCTAssertEqual(dock.fullRebuildPassesForChecks, passes, "G3-161: unchanged inputs cause no Dock rebuild")
        XCTAssertEqual(dock.ringOnlyRefreshesForChecks, repaints, "and no ring repaint")
    }

    /// A changed value repaints the Resources ring alone: no rebuild pass, and the ring shows the new reading.
    func testAChangedValueRepaintsOnlyTheResourcesRing() async throws {
        let app = try await makeEntry()
        await app.composition.start()
        let dock = app.composition.dock
        let reader = Reader()
        let ring = try await installRing(app, reader: reader)
        let passes = dock.fullRebuildPassesForChecks, repaints = dock.ringOnlyRefreshesForChecks
        let before = try XCTUnwrap(dock.dockView.presentedReadingsForChecks[ring.id]?.pluginRing?.inner)
        reader.cpu = 60
        ring.run(10)
        XCTAssertEqual(dock.fullRebuildPassesForChecks, passes, "G3-161: the ring changed, the Dock was not rebuilt")
        XCTAssertEqual(dock.ringOnlyRefreshesForChecks, repaints + 1, "only the ring was repainted")
        let after = try XCTUnwrap(dock.dockView.presentedReadingsForChecks[ring.id]?.pluginRing?.inner)
        XCTAssertNotEqual(before, after)
        XCTAssertEqual(after, 0.60, accuracy: 0.001, "the ring shows the new CPU")
        XCTAssertFalse(app.composition.presentedContent.snapshot.inputs.isEmpty, "the subscription rings stay")
    }
}
