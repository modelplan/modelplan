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

    /// Sample S17 (macrevb-1096-6): the card action carries the Dock ID; the cockpit bridge takes the plugin ID only.
    func testDockIDConvertsToTheCockpitPluginID() {
        XCTAssertEqual(ResourceDockBridge.subscriptionID, "plugin:resources")
        XCTAssertEqual(ResourceDockBridge.pluginID(dockID: ResourceDockBridge.subscriptionID), ResourcePluginHost.pluginID)
        XCTAssertNil(ResourceDockBridge.pluginID(dockID: "codex"), "a subscription ring is not a plugin")
        XCTAssertNil(ResourceDockBridge.pluginID(dockID: "plugin:"))
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

    // MARK: macrevb-1096-4: the hover card follows every sample, not the last ring redraw

    func testHoverCardFollowsDiskPressureAndCadenceWithoutARingRedraw() throws {
        final class Reader: ResourceReader {
            var cpu: Double = 22, diskFree: Double = 494 * 0.11, pressure: ResourcePressure = .normal
            func read(uptime: TimeInterval, unixMs: Int64) -> ResourceSample? {
                resourceSample(at: uptime, cpu: cpu, pressure: pressure, diskFree: diskFree)
            }
        }
        var now: TimeInterval = 0
        var timers: [(deadline: TimeInterval, fire: @MainActor () -> Void)] = []
        let reader = Reader()
        let sampler = ResourceSampler(reader: reader, clock: { now }, scheduler: { delay, _, fire in
            timers.append((now + delay, fire)); let i = timers.count - 1
            return ResourceTimerHandle { timers[i].fire = {} }
        })
        func run(until end: TimeInterval) {
            while let i = timers.indices.filter({ timers[$0].deadline <= end }).min(by: { timers[$0].deadline < timers[$1].deadline }) {
                let t = timers[i]; timers[i].deadline = .infinity; now = max(now, t.deadline); t.fire()
            }
            now = end
        }
        let provider = ResourceDockContentProvider(base: LegacyDockContentProvider())
        var redraws = 0, cardRefreshes = 0
        let binding = ResourceWidgetBinding(sampler: sampler, provider: provider, language: { .chinese },
                                            refreshCard: { cardRefreshes += 1 }) { redraws += 1 }
        binding.setVisibility(.init(pluginEnabled: true, columnShown: false, widgetShown: true, columnSetting: 5))
        run(until: 0)
        XCTAssertEqual(redraws, 1)
        func disk() throws -> DockCardRow { try XCTUnwrap(binding.liveCard()?.rows.first { $0.id == "resource:disk" }) }
        XCTAssertEqual(try disk().value, "89%")
        XCTAssertEqual(try disk().plugin?.tinted, false)

        // Disk 89 % -> 91 %: the ring face (memory, CPU, readout) is unchanged, so the ring does not redraw.
        reader.diskFree = 494 * 0.09
        let before = cardRefreshes
        run(until: 10)
        XCTAssertEqual(redraws, 1, "equal ring faces: no ring redraw")
        XCTAssertGreaterThan(cardRefreshes, before, "an open card is refreshed on the new sample")
        XCTAssertEqual(try disk().value, "91%", "the card shows the current disk")
        XCTAssertEqual(try disk().plugin?.tinted, true, "and its warning tint")
        XCTAssertEqual(try disk().tone, .warning)
        XCTAssertEqual(provider.resourceInput?.pluginRing?.cardRows.first { $0.id == "resource:disk" }?.value, "89%",
                       "the captured input is stale; the host reads the live card instead")
        let input = try XCTUnwrap(provider.resourceInput)
        let shown = try DockCardProjection.content(input: StaticDockPreviewHost.livePluginInput(input, live: binding.liveCard()), at: Date())
        XCTAssertEqual(shown.rows.first { $0.id == "resource:disk" }?.value, "91%", "the host's card content uses the live rows")

        // CPU takes the readout, then memory pressure changes: the readout stays CPU, so again no redraw.
        reader.cpu = 75
        run(until: 40)
        XCTAssertEqual(provider.resourceInput?.pluginRing?.readout, "CPU 75%")
        let drawn = redraws
        reader.pressure = .warn
        run(until: 50)
        XCTAssertEqual(redraws, drawn, "pressure alone does not change the ring face")
        let memory = try XCTUnwrap(binding.liveCard()?.rows.first { $0.id == "resource:memory" })
        XCTAssertEqual(memory.tone, .warning, "the memory number takes the pressure tone at once")
        XCTAssertEqual(memory.plugin?.tinted, true)
        XCTAssertEqual(binding.liveCard()?.footer, "内存压力 偏高 · 每 10 秒")

        // The cadence changes (the cockpit column opens at 2 s): the footer follows without a redraw.
        binding.setVisibility(.init(pluginEnabled: true, columnShown: true, widgetShown: true, columnSetting: 2))
        XCTAssertEqual(redraws, drawn)
        XCTAssertEqual(binding.liveCard()?.footer, "内存压力 偏高 · 每 2 秒")

        binding.setVisibility(.init(pluginEnabled: false, columnShown: false, widgetShown: true, columnSetting: 2))
        XCTAssertNil(binding.liveCard(), "plugin off: no card")
    }

    // MARK: macrevb-1096-6: the card's action and header mark

    func testCardCarriesTheScreenActionAndTheLineMark() throws {
        let card = try DockCardProjection.content(input: try input(sample(), key: .memory), at: Date())
        XCTAssertEqual(card.actionLabel, "驾驶舱大屏 ›", "the footer action opens the resource big screen")
        let english = ResourceCard(sample: sample(), shown: .init(key: .memory, percent: 47, tone: .normal), cpuPeak: 22, interval: 10, language: .english)
        XCTAssertEqual(ResourceDockBridge.card(english).action, "Cockpit screen ›")
        let paths = DockPluginIcon.paths(in: CGRect(x: 0, y: 0, width: 16, height: 16))
        XCTAssertEqual(paths.count, 2, "the screen outline and the heartbeat line")
        XCTAssertEqual(paths[0].boundingBox.width, 14, accuracy: 0.01)
        XCTAssertTrue(StaticDockPreviewHost.pluginCardMark.size == CGSize(width: 16, height: 16))
    }

    // MARK: macrevb-1096-5: only the readout number takes a tone

    func testReadoutLabelStaysNeutralAndOnlyTheNumberIsToned() throws {
        XCTAssertEqual(DockPluginRing.readoutParts("CPU 96%").label, "CPU ")
        XCTAssertEqual(DockPluginRing.readoutParts("CPU 96%").number, "96%")
        XCTAssertEqual(DockPluginRing.readoutParts("内存 47%").number, "47%")
        XCTAssertEqual(DockPluginRing.readoutParts("47%").label, "")
        XCTAssertEqual(DockInstrumentView.communityNumberColor(.critical), .systemRed)
        XCTAssertEqual(DockInstrumentView.communityNumberColor(.normal), .labelColor)
    }

    /// The neutral edition (no reserved art) draws the two orchid arcs beside a plain readout; the row is not dimmed
    /// or marked unavailable.
    func testNeutralEditionDrawsTheOrchidArcs() throws {
        let reading = try DockInstrumentProjection.evaluate(try input(sample(cpu: 96), key: .cpu, tone: .critical), now: Date())
        let view = DockInstrumentView(frame: .zero)
        try view.applyCommunity([reading], locale: "zh-Hans")
        XCTAssertEqual(view.communityRowText(ResourceDockBridge.subscriptionID), "资源占用  CPU 96%", "no 'unavailable' line")
        XCTAssertFalse(view.communityRowIsDimmed(ResourceDockBridge.subscriptionID))
        let rep = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: rep)
        let ring = DockInstrumentView.communityPluginGeometry(row: CGRect(x: 0, y: 0, width: view.bounds.width, height: 44), scale: 1).ring
        var orchid = 0
        let sx = CGFloat(rep.pixelsWide) / view.bounds.width, sy = CGFloat(rep.pixelsHigh) / view.bounds.height
        for x in stride(from: ring.minX, to: ring.maxX, by: 0.5) {
            for y in stride(from: ring.minY, to: ring.maxY, by: 0.5) {
                guard let c = rep.colorAt(x: Int(x * sx), y: Int(y * sy))?.usingColorSpace(.sRGB) else { continue }
                if c.redComponent > 0.75, c.greenComponent < 0.55, c.blueComponent > 0.6, c.alphaComponent > 0.5 { orchid += 1 }
            }
        }
        XCTAssertGreaterThan(orchid, 20, "the orchid arcs are drawn in the neutral row")
    }
}
