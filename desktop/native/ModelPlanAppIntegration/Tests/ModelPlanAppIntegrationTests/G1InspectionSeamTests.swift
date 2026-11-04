// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanDock
import ModelPlanPrimitives
import ModelPlanSettings
import ModelPlanEngineClient
@testable import ModelPlanAppIntegration

@MainActor private final class G1Surface: SettingsWindowSurface {
    var shows = 0
    func prepare() async {}
    func show(paneID: String?) { shows += 1 }
    func hide() {}
}
@MainActor private final class G1Frames: EffectFrameProvider {
    let identifier = "synthetic-g1", revision = "1"
    func draw(pose: Int, request: EffectFrameRequest, in context: CGContext) throws {
        context.setFillColor(CGColor(gray: Double(pose + 1) / 10, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: context.width, height: context.height))
    }
}
@MainActor final class G1InspectionSeamTests: XCTestCase {
    private func working() throws -> (DockWorkingEffects, DockInstrumentView, EffectResourcePool) {
        let palette = Dictionary(uniqueKeysWithValues: ["body","case","track","notch","clockBack","clock","text","unknown","normal","warning","critical","alias","noticeAmber","noticeBlue","noticeWhite"].map { ($0, DockInk(0.5,0.5,0.5)) })
        let inks = try JSONSerialization.jsonObject(with: JSONEncoder().encode(palette))
        let json: [String: Any] = ["schemaVersion":1,"bounds":[[0,0],[96,96]],"bodyPolygon":[[0,0],[96,0],[96,96],[0,96]],"fixedLayers":[],"palette":inks,
            "text":["size":11,"weight":400],"aliasText":["size":10,"weight":400],
            "stations":[["subscriptionID":"sub","centre":[48,30],"diameter":24,"readout":[[20,50],[56,16]],"eventRect":[[64,52],[12,12]],"glyphRect":[[36,18],[24,24]],"layers":[],"glyphs":[:],"outer":["radius":10,"width":2,"minimumVisibleFraction":0,"opacity":1],"inner":["radius":7,"width":1,"minimumVisibleFraction":0,"opacity":1],"clock":["radius":14,"dotRadius":0.5,"backWidth":1,"positions":10],"notchWidth":1,"caseInnerRadius":5]]]
        let skin = try JSONDecoder().decode(DockInstrumentSkin.self, from: JSONSerialization.data(withJSONObject: json))
        var input = DockInstrumentInput(id: "sub", name: "Synthetic", windows: [.init(id: "quota", period: .fiveHour, label: "5h", remainingPercent: 70, resetsAt: Date().addingTimeInterval(3600), durationSeconds: 18000)])
        input.dataState = .fresh; input.working = DockWorkingSignal(subscriptionID: "sub", bindingVerified: true, fresh: true, observedOutput: true)
        let reading = try DockInstrumentProjection.evaluate(input, now: Date())
        let resources = try DockArtworkStore(root: FileManager.default.temporaryDirectory, manifest: .init(files: [:]))
        let view = DockInstrumentView(frame: skin.bounds)
        try view.applyOfficial(skin: skin, rows: [reading], renderer: DockInstrumentRenderer(resources: resources), scale: 1, locale: "en")
        let pool = EffectResourcePool(), driver = DockWorkingEffects(pool: pool, systemReduceMotion: { false })
        let provider = G1Frames()
        try driver.configure(view: view, skin: skin, readings: [reading], profile: .init(scale: 1), rotation: .init(period: 2), provider: { _ in provider })
        return (driver, view, pool)
    }
    func testFactoryEngineInjectionRetainsActualCockpitFanoutAndPageBoundary() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("g1-factory-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try SettingsStore(url: root.appendingPathComponent("settings.json"))
        let configuration = EngineClientConfiguration(executableURL: root.appendingPathComponent("not-launched"), applicationVersion: "synthetic", allowedEnvironment: [:])
        var fanout: CockpitStoreFanout?, injected: ProcessEngineClient?
        let app = CommunityCockpitApplicationFactory.makeForChecks(configuration: configuration, settingsStore: store, bundleURL: root) { config, consumer in
            fanout = consumer as? CockpitStoreFanout
            let client = ProcessEngineClient(configuration: config, consumer: consumer)
            injected = client
            return client
        }
        defer { app.composition.dock.close() }
        let actual = try XCTUnwrap(fanout)
        XCTAssertTrue(actual.store === app.composition.store)
        XCTAssertTrue(app.composition.client === injected)
        let context = EngineDeliveryContext(sessionID: UUID().uuidString, floor: .init(storeEpoch: "synthetic", generation: 1), revision: 1)
        await actual.consume(.context(context))
        XCTAssertEqual(app.composition.store.snapshot.delivery, context)
        var unavailable = 0
        actual.cockpit.onUnavailable = { unavailable += 1 }
        actual.cockpit.open()
        XCTAssertEqual(unavailable, 1, "The actual production page boundary must reject a synthetic unverified bundle")
        await actual.consume(.clearPrivateViews(.init(revision: 2, reason: .connectionLost, previous: context, nextFloor: nil)))
        XCTAssertNil(app.composition.store.snapshot.delivery)
        XCTAssertFalse(try XCTUnwrap(injected).isCurrent(context), "Construction must not launch or admit an engine session")
    }
    func testSliverQuotaRolesAreNotInferredFromNoticeMarksOrPixels() {
        let sliver = DockSliverView(frame: .init(x: 0, y: 0, width: 4, height: 100))
        XCTAssertNil(sliver.quotaSegmentColorRolesForChecks)
        sliver.noticeMarks = []
        XCTAssertNil(sliver.quotaSegmentColorRolesForChecks, "An empty notice set cannot prove neutral quota segments")
        sliver.dispose()
    }

    func testSettingsSurfaceReadDoesNotConstructOrPresent() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("g1-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let application = SettingsApplicationCoordinator(store: try SettingsStore(url: root.appendingPathComponent("settings.json")), apply: { _ in })
        let surface = G1Surface()
        var constructions = 0
        let host = SettingsWindowHost(application: application, canPresent: { true }, environment: { .init() }, activate: {}, makeSurface: { _ in constructions += 1; return surface })
        XCTAssertNil(host.currentSurfaceForChecks); XCTAssertEqual(constructions, 0)
        await host.present()
        XCTAssertTrue(host.currentSurfaceForChecks === surface)
        XCTAssertEqual(surface.shows, 1); XCTAssertEqual(constructions, 1)
        _ = host.currentSurfaceForChecks
        XCTAssertEqual(surface.shows, 1)
        host.suspend()
    }
    func testCardFragmentsObserveExistingLayoutOnly() throws {
        let card = DockCardView(frame: .zero)
        XCTAssertTrue(card.renderedLineFragmentsForChecks.isEmpty)
        try card.apply(.init(subscriptionID: "synthetic", name: "Synthetic card", rows: []))
        card.layoutSubtreeIfNeeded()
        let before = card.frame, fragments = card.renderedLineFragmentsForChecks
        XCTAssertFalse(try XCTUnwrap(fragments["dock.card.text.name"]).isEmpty)
        XCTAssertEqual(card.frame, before)
        card.dispose(); XCTAssertTrue(card.renderedLineFragmentsForChecks.isEmpty)
    }
    func testFrameIndicesAreSampledWithoutAdvancingTheEffect() throws {
        let (driver, view, pool) = try working(); defer { driver.stop(); view.dispose() }
        let leases = pool.activeLeaseCount
        XCTAssertEqual(driver.frameIndicesForChecks["sub"], 0)
        XCTAssertEqual(driver.frameIndicesForChecks["sub"], 0)
        XCTAssertEqual(pool.activeLeaseCount, leases)
    }
    func testRotationRecipeIsTheConfiguredRecipe() throws {
        let (driver, view, _) = try working(); defer { driver.stop(); view.dispose() }
        XCTAssertEqual(driver.rotationRecipesForChecks["sub"], .init(period: 2))
        driver.stop(); XCTAssertTrue(driver.rotationRecipesForChecks.isEmpty)
    }
    func testLifecycleReportsOnlyCurrentlyAttachedConsumers() throws {
        let (driver, view, _) = try working(); defer { view.dispose() }
        XCTAssertEqual(driver.animationLifecycleForChecks["sub"], true)
        driver.stop(); XCTAssertTrue(driver.animationLifecycleForChecks.isEmpty)
    }
    func testCadenceComesFromTheActiveContentsAnimation() throws {
        let (driver, view, _) = try working(); defer { driver.stop(); view.dispose() }
        XCTAssertEqual(try XCTUnwrap(driver.cadenceForChecks), 1.0 / 9, accuracy: 0.000001)
        driver.stop(); XCTAssertNil(driver.cadenceForChecks)
    }
    func testMissingStationLayoutHasNoInventedFrames() {
        let host = StaticDockPreviewHost(currentDate: { Date() }, createsNativePanels: false)
        defer { host.close() }
        XCTAssertTrue(host.renderedStationFramesForChecks.isEmpty)
        XCTAssertNil(host.nativePanel)
    }
    func testPulseHistoryIsExplicitlyUnsupported() {
        let view = DockInstrumentView(frame: .zero)
        XCTAssertNil(view.noticePulseReceiptsForChecks)
        XCTAssertFalse(view.pulseNotice("not-admitted"))
        XCTAssertNil(view.noticePulseReceiptsForChecks)
        view.dispose()
    }
    func testEffectRequestHistoryIsExplicitlyUnsupported() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("g1-effects-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"), applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: try EngineRowsEntry.makeSettingsStore(applicationSupport: root), createsNativePanels: false, activateSettings: {})
        XCTAssertNil(app.effectRequestsForChecks)
        app.composition.dock.close()
    }
    func testEdgeAnimationRolesAreExplicitlyUnsupported() {
        let edge = DockEdgeController(read: { .init(displays: [], layouts: []) })
        XCTAssertNil(edge.animationRolesForChecks)
        XCTAssertNil(edge.presentation)
    }
}
