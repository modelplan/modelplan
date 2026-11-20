// SPDX-License-Identifier: MIT
import XCTest
import ModelPlanDock
import ModelPlanResources
@testable import ModelPlanAppIntegration

/// D324/D327 on the widget: the resource ring sits in the subscription ring's place, outer arc memory (solid used,
/// faint cached), inner arc CPU, always orchid (the ring never changes colour; only the readout number takes a tone).
/// The hover card follows variant A: the row matching the readout at full ink, the others secondary, a background only
/// on problem rows.
private func resourceGB(_ v: Double) -> UInt64 { UInt64((v * Double(UInt64(1) << 30)).rounded()) }
/// The board's normal state: memory 47 % (15.1 / 32 GB, 12.8 GB cached), CPU 22 %, disk 76 %.
private func resourceSample(at t: TimeInterval = 0, cpu: Double = 22, pressure: ResourcePressure = .normal, diskFree: Double = 120) -> ResourceSample {
    let gb = resourceGB
    return ResourceSample(unixMs: 1_795_000_000_000 + Int64(t * 1000), uptime: t, cpuUser: cpu * 0.75, cpuSystem: cpu * 0.25, load: 2.4,
                          memTotal: gb(32), memApp: gb(9.2), memWired: gb(4.5), memCompressed: gb(1.4), memCached: gb(12.8), memFree: gb(4.1),
                          swapUsed: 0, pressure: pressure, diskTotal: gb(494), diskFree: gb(diskFree))
}

@MainActor final class ResourceDockBridgeTests: XCTestCase {
    private func sample(at t: TimeInterval = 0, cpu: Double = 22, diskFree: Double = 120) -> ResourceSample {
        resourceSample(at: t, cpu: cpu, diskFree: diskFree)
    }
    private func input(_ s: ResourceSample, key: ResourceReadoutKey, tone: ResourceTone = .normal) throws -> DockInstrumentInput {
        let shown = ResourceShown(key: key, percent: key == .cpu ? Int(s.cpu.rounded()) : Int(s.memoryPercent.rounded()), tone: tone)
        let face = ResourceFace(sample: s, shown: shown, reduceMotion: false)
        let card = ResourceCard(sample: s, shown: shown, cpuPeak: s.cpu, interval: 10, language: .chinese)
        return try XCTUnwrap(ResourceDockBridge.input(face: face, card: card, language: .chinese))
    }

    func testRingIsTwoOrchidArcsThatNeverChangeColour() throws {
        let normal = try DockInstrumentProjection.evaluate(try input(sample(), key: .memory), now: Date())
        XCTAssertEqual(normal.readout, "内存 47%")
        XCTAssertEqual(normal.status, .normal)
        XCTAssertEqual(normal.outer?.fraction ?? 0, 15.1 / 32, accuracy: 0.001, "outer = memory used")
        XCTAssertEqual(normal.pluginRing?.outerFaint ?? 0, 12.8 / 32, accuracy: 0.001, "faint segment = cached")
        XCTAssertEqual(normal.inner?.fraction ?? 0, 0.22, accuracy: 0.001, "inner = CPU")
        let ring = try XCTUnwrap(normal.pluginRing)
        XCTAssertEqual([ring.red, ring.green, ring.blue].map { Int(($0 * 255).rounded()) }, [0xda, 0x66, 0xc2], "orchid #da66c2")
        XCTAssertNil(normal.timeLeftFraction, "no quota clock on a plugin ring")
        XCTAssertFalse(normal.jetEligible)

        let spike = try DockInstrumentProjection.evaluate(try input(sample(cpu: 96), key: .cpu, tone: .critical), now: Date())
        XCTAssertEqual(spike.readout, "CPU 96%")
        XCTAssertEqual(spike.status, .critical, "only the readout number turns red")
        XCTAssertEqual(spike.outer?.status, .normal, "the ring keeps its ink")
        XCTAssertEqual(spike.inner?.status, .normal)
        XCTAssertEqual(spike.pluginRing?.red, ring.red)
        XCTAssertNil(spike.outer?.remainingFraction, "never read as a used-up quota window")
    }

    func testHoverCardRowsFollowVariantA() throws {
        let card = try DockCardProjection.content(input: try input(sample(), key: .memory), at: Date())
        let rows = card.rows.filter { $0.kind == .quota }
        XCTAssertEqual(rows.map(\.label), ["CPU", "内存", "磁盘"], "CPU, then memory, then disk")
        XCTAssertEqual(rows.map(\.value), ["22%", "47%", "76%"])
        XCTAssertEqual(rows.map(\.emphasised), [false, true, false], "the row matching the readout is at full ink")
        XCTAssertEqual(rows.map { $0.plugin?.tinted }, [false, false, false], "emphasis is ink only, never a background")
        XCTAssertTrue(rows.allSatisfy { $0.plugin.map { Int(($0.red * 255).rounded()) == 0xda } == true }, "orchid bars")
        XCTAssertEqual(rows[1].plugin?.faintFill ?? 0, 12.8 / 32, accuracy: 0.001)
        XCTAssertEqual(rows.map { $0.plugin?.notch }, [0.7, nil, 0.9])
        XCTAssertEqual(card.rows.last?.kind, .footnote)
        XCTAssertEqual(card.rows.last?.value, "内存压力 正常 · 每 10 秒")
        XCTAssertFalse(card.rows.contains { $0.id.hasPrefix("quota:") }, "no quota windows on a plugin card")

        let spike = try DockCardProjection.content(input: try input(sample(cpu: 96, diskFree: 30), key: .cpu, tone: .critical), at: Date())
        let spikeRows = spike.rows.filter { $0.kind == .quota }
        XCTAssertEqual(spikeRows.map(\.emphasised), [true, false, false], "the emphasis follows the readout to CPU")
        XCTAssertEqual(spikeRows.map { $0.plugin?.tinted }, [true, false, true], "background only on problem rows (CPU ≥ 70 %, disk ≥ 90 %)")
        XCTAssertEqual(spikeRows.map(\.tone), [.critical, .normal, .warning], "amber/red numbers keep their tone, emphasised or not")
    }

    func testProviderPutsTheRingFirstAndRemovesIt() throws {
        final class Base: DockContentProvider {
            func makeContent(_ context: DockContentContext) -> DockContent {
                .init(snapshot: .init(inputs: [DockInstrumentInput(id: "codex", name: "Codex", windows: [])]), emptyText: "x")
            }
        }
        let provider = ResourceDockContentProvider(base: Base())
        let context = DockContentContext(snapshot: nil, diagnostics: .init(), now: Date())
        XCTAssertEqual(provider.makeContent(context).snapshot.inputs.map(\.id), ["codex"], "no sample yet: no ring")
        provider.resourceInput = try input(sample(), key: .memory)
        let content = provider.makeContent(context)
        XCTAssertEqual(content.snapshot.inputs.map(\.id), [ResourceDockBridge.subscriptionID, "codex"])
        XCTAssertEqual(content.emptyText, "x")
        provider.resourceInput = nil
        XCTAssertEqual(provider.makeContent(context).snapshot.inputs.map(\.id), ["codex"])
    }

    func testBindingRedrawsFromTheSamplerAndDropsTheRingWhenOff() throws {
        final class Reader: ResourceReader {
            var cpu: Double = 22
            let make: (TimeInterval, Double) -> ResourceSample
            init(_ make: @escaping (TimeInterval, Double) -> ResourceSample) { self.make = make }
            func read(uptime: TimeInterval, unixMs: Int64) -> ResourceSample? { make(uptime, cpu) }
        }
        var now: TimeInterval = 0
        var timers: [(deadline: TimeInterval, fire: @MainActor () -> Void)] = []
        let reader = Reader { t, c in resourceSample(at: t, cpu: c) }
        let sampler = ResourceSampler(reader: reader, clock: { now }, scheduler: { delay, _, fire in
            timers.append((now + delay, fire)); let i = timers.count - 1
            return ResourceTimerHandle { timers[i].fire = {} }
        })
        let provider = ResourceDockContentProvider(base: LegacyDockContentProvider())
        var refreshes = 0
        let binding = ResourceWidgetBinding(sampler: sampler, provider: provider, language: { .chinese }) { refreshes += 1 }
        binding.setVisibility(.init(pluginEnabled: true, columnShown: false, widgetShown: true, columnSetting: 5))
        func run(until end: TimeInterval) {
            while let i = timers.indices.filter({ timers[$0].deadline <= end }).min(by: { timers[$0].deadline < timers[$1].deadline }) {
                let t = timers[i]; timers[i].deadline = .infinity; now = max(now, t.deadline); t.fire()
            }
            now = end
        }
        run(until: 0)
        XCTAssertEqual(refreshes, 1)
        XCTAssertEqual(provider.resourceInput?.pluginRing?.readout, "内存 47%")
        XCTAssertEqual(provider.resourceInput?.pluginRing?.cardFooter, "内存压力 正常 · 每 10 秒", "widget shown: every 10 s")
        run(until: 10)
        XCTAssertEqual(refreshes, 1, "no redraw without a ≥ 1 point change")
        reader.cpu = 40
        run(until: 20)
        XCTAssertEqual(refreshes, 2)
        XCTAssertEqual(provider.resourceInput?.pluginRing?.inner ?? 0, 0.40, accuracy: 0.001)
        binding.setVisibility(.init(pluginEnabled: false, columnShown: false, widgetShown: true, columnSetting: 5))
        XCTAssertNil(provider.resourceInput, "plugin off: the ring goes at once")
        XCTAssertEqual(refreshes, 3)
        run(until: 600)
        XCTAssertEqual(refreshes, 3, "no sampling while off")
    }
}
