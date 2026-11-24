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

/// D397 (energy plan item 5, energy-p0-1124): the owner's 11-24 sample showed `T2Geometry.make` and
/// `T2FaceMaterial.render` below both the Resources sampler and engine row delivery, with nothing on screen changing.
/// These gates drive the official normal entry under a test clock across several 60-second presentation deadlines and
/// count the static work itself. Invariants: identical engine deliveries and identical Resources samples build no
/// geometry, render no material and run no full rebuild; a resource-only change repaints the ring alone and leaves the
/// quota readings as they were; a real quota change still reaches the face. The geometry and material counters come
/// from #1201's prepared official face.
@MainActor final class G3161IdleCompositionGateTests: XCTestCase {
    /// The production deadline scheduler, replaced by a manual clock that fires only what is due.
    @MainActor private final class ManualDeadline: DockEdgeScheduling {
        private var armed: (deadline: TimeInterval, action: @MainActor () -> Void)?
        private(set) var fired = 0
        func arm(at deadline: TimeInterval, _ action: @escaping @MainActor () -> Void) { armed = (deadline, action) }
        func cancel() { armed = nil }
        func fireIfDue(_ elapsed: TimeInterval) {
            guard let armed, armed.deadline <= elapsed else { return }
            self.armed = nil; fired += 1; armed.action()
        }
    }
    private final class Reader: ResourceReader {
        var cpu: Double = 22
        func read(uptime: TimeInterval, unixMs: Int64) -> ResourceSample? {
            let g: UInt64 = 1 << 30
            return ResourceSample(unixMs: 1_795_000_000_000 + Int64(uptime * 1000), uptime: uptime, cpuUser: cpu * 0.75, cpuSystem: cpu * 0.25, load: 2.4,
                                  memTotal: 32 * g, memApp: 9 * g, memWired: 4 * g, memCompressed: g, memCached: 12 * g, memFree: 6 * g,
                                  swapUsed: 0, pressure: .normal, diskTotal: 494 * g, diskFree: 120 * g)
        }
    }
    private struct Entry {
        let app: EngineDockMenuApplication
        let deadline: ManualDeadline
        let advance: @MainActor (TimeInterval) -> Void
    }
    private struct StaticWork: Equatable {
        let geometry: Int, material: Int, fullPasses: Int
        @MainActor init(_ dock: StaticDockPreviewHost) {
            geometry = T2ProductionAppearance.preparationsTotalForChecks
            material = T2ProductionAppearance.materialRendersTotalForChecks
            fullPasses = dock.fullRebuildPassesForChecks
        }
    }

    private func makeOfficialEntry() async throws -> Entry {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("g3161-idle-gate-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let settings = try await expandedWidgetSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        var wall = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-12-02T00:00:00Z")), elapsed: TimeInterval = 1_000
        let deadline = ManualDeadline()
        let rows = try HostPairedProjectionTests.rows(weekly: 75, secondWeekly: 12, includeSession: false)
        let app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"),
            applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: settings, createsNativePanels: false,
            dockEnvironment: normalEntryTestEnvironment, edition: .official, deadlineNow: { wall }, deadlineElapsed: { elapsed },
            deadlineScheduling: deadline, makeClient: { _, store in EntrySyntheticClient(store: store, rows: rows) }, activateSettings: {})
        await app.prepare(); app.allowDockPresentation()
        addTeardownBlock { @MainActor in await app.composition.stop() }
        await app.composition.start()
        XCTAssertFalse(app.composition.presentedContent.snapshot.inputs.isEmpty, "the normal entry admitted the fixture")
        XCTAssertGreaterThan(app.composition.dock.officialFacePaintsForChecks, 0, "the official face is drawn")
        return Entry(app: app, deadline: deadline, advance: { seconds in
            wall.addTimeInterval(seconds); elapsed += seconds
            deadline.fireIfDue(elapsed)
        })
    }

    private func deliver(_ app: EngineDockMenuApplication, weekly: Double = 75, sequence: Int) async throws {
        let context = EngineDeliveryContext(sessionID: "synthetic", floor: .init(storeEpoch: "synthetic", generation: 1), revision: 1)
        let rows = try HostPairedProjectionTests.rows(weekly: weekly, secondWeekly: 12, sequence: sequence, includeSession: false)
        let reply = try EngineReply(envelope: .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch,
            consentGeneration: context.floor.generation, data: rows), delivery: context)
        await app.composition.store.consume(.rowsChanged(reply, invalidRowCount: rows.projection.invalidRowCount))
    }

    /// Installs the Resources ring through the app composition's entry and waits for its first draw.
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
        return ({ run(until: $0) }, id)
    }

    /// Identical deliveries, with Resources off and then on, over six presentation deadlines: no geometry, no material,
    /// no full rebuild and no face paint for the deliveries themselves. The deadline ticks still run (countdowns advance)
    /// and may repaint readouts, but never the static face.
    func testIdenticalDeliveriesAcrossDeadlinesBuildNoGeometryOrMaterial() async throws {
        let entry = try await makeOfficialEntry()
        let app = entry.app, dock = app.composition.dock
        var sequence = 8
        let settled = StaticWork(dock)

        // Back-to-back identical deliveries: nothing on screen changes, so nothing is drawn at all.
        var paints = dock.officialFacePaintsForChecks
        for _ in 1...12 { try await deliver(app, sequence: sequence); sequence += 1 }
        XCTAssertEqual(StaticWork(dock), settled, "identical deliveries build no geometry, material or full pass")
        XCTAssertEqual(dock.officialFacePaintsForChecks, paints, "identical deliveries paint nothing")

        // Resources off: six minutes in 30 s steps, an identical delivery every 90 s, so the 60-second presentation
        // deadline comes due between deliveries.
        let fired = entry.deadline.fired
        for step in 1...12 {
            entry.advance(30)
            if step.isMultiple(of: 3) { try await deliver(app, sequence: sequence); sequence += 1 }
        }
        XCTAssertGreaterThanOrEqual(entry.deadline.fired - fired, 3, "the presentation deadlines ran")
        XCTAssertEqual(T2ProductionAppearance.preparationsTotalForChecks, settled.geometry, "no geometry across deadlines")
        XCTAssertEqual(T2ProductionAppearance.materialRendersTotalForChecks, settled.material, "no material across deadlines")

        // Resources on, sampling identical values every 10 s, interleaved with identical deliveries and deadlines.
        let ring = try await installRing(app, reader: Reader())
        let withRing = StaticWork(dock), repaints = dock.ringOnlyRefreshesForChecks
        paints = dock.officialFacePaintsForChecks
        for tick in 1...18 {
            entry.advance(10); ring.run(Double(tick) * 10)
            if tick.isMultiple(of: 3) { try await deliver(app, sequence: sequence); sequence += 1 }
        }
        XCTAssertEqual(T2ProductionAppearance.preparationsTotalForChecks, withRing.geometry, "Resources on: no geometry")
        XCTAssertEqual(T2ProductionAppearance.materialRendersTotalForChecks, withRing.material, "Resources on: no material")
        XCTAssertEqual(dock.ringOnlyRefreshesForChecks, repaints, "identical samples do not repaint the ring")

        // Control: a changed quota still reaches the face, over the same layout and material.
        let shown = dock.dockView.presentedReadingsForChecks
        let before = StaticWork(dock)
        paints = dock.officialFacePaintsForChecks
        try await deliver(app, weekly: 40, sequence: sequence)
        XCTAssertNotEqual(dock.dockView.presentedReadingsForChecks, shown, "the changed reading is presented")
        XCTAssertGreaterThan(dock.officialFacePaintsForChecks, paints, "and painted")
        XCTAssertEqual(T2ProductionAppearance.preparationsTotalForChecks, before.geometry, "with the same geometry")
        XCTAssertEqual(T2ProductionAppearance.materialRendersTotalForChecks, before.material, "and the same material")
    }

    /// Resource-only deltas repaint the Resources ring alone: one ring refresh per changed reading, no full rebuild,
    /// no geometry, no material, and every quota reading stays exactly as it was. Identical samples in between do nothing.
    func testResourceOnlyDeltasUpdateOnlyTheRing() async throws {
        let app = try await makeOfficialEntry().app, dock = app.composition.dock
        let reader = Reader(), ring = try await installRing(app, reader: reader)
        let quota = dock.dockView.presentedReadingsForChecks.filter { $0.key != ring.id }
        XCTAssertFalse(quota.isEmpty, "the quota rings are on the widget")
        let settled = StaticWork(dock), repaints = dock.ringOnlyRefreshesForChecks
        var clock: TimeInterval = 0
        for (step, cpu) in [30.0, 45, 60, 75, 90].enumerated() {
            reader.cpu = cpu
            clock += 10; ring.run(clock)
            XCTAssertEqual(dock.ringOnlyRefreshesForChecks, repaints + step + 1, "a changed reading repaints the ring once")
            let inner = try XCTUnwrap(dock.dockView.presentedReadingsForChecks[ring.id]?.pluginRing?.inner)
            XCTAssertEqual(inner, cpu / 100, accuracy: 0.001, "the ring shows the new CPU")
            // The same value again for a minute of samples: nothing more.
            for _ in 1...6 { clock += 10; ring.run(clock) }
            XCTAssertEqual(dock.ringOnlyRefreshesForChecks, repaints + step + 1, "an unchanged sample repaints nothing")
        }
        XCTAssertEqual(StaticWork(dock), settled, "resource-only deltas build no geometry, material or full pass")
        let after = dock.dockView.presentedReadingsForChecks.filter { $0.key != ring.id }
        XCTAssertEqual(Set(after.keys), Set(quota.keys), "the quota stations are unchanged")
        for (id, reading) in quota {
            XCTAssertEqual(after[id]?.remainingPercent, reading.remainingPercent, "quota reading \(id) is untouched by the ring")
        }
    }
}
