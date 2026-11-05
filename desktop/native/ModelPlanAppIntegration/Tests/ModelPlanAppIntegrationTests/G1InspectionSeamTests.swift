// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@_spi(DockResourceChecks) import ModelPlanDock
import ModelPlanOfficialDock
import ModelPlanPrimitives
import ModelPlanSettings
import ModelPlanEngineClient
import ModelPlanCockpitWeb
import CryptoKit
@_spi(DockResourceChecks) @testable import ModelPlanAppIntegration

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
    func testFaceMaterialReportsOnlyCompletedRenderRecipeWithoutRetainingPixels() throws {
        let geometry = try T2Geometry.make(subscriptions: [.init(id: "synthetic")], input: .init(coordinates: .init(edge: .right, width: 300, height: 400, menuBarExclusion: 26)))
        let material = T2FaceMaterial(), viewport = CGRect(x: 200, y: 100, width: 100, height: 220)
        XCTAssertNil(material.renderedMaterialForChecks); XCTAssertTrue(material.renderedLayerRolesForChecks.isEmpty)
        let image = try material.render(geometry: geometry, viewport: viewport, scale: 1)
        let receipt = try XCTUnwrap(material.renderedMaterialForChecks)
        XCTAssertEqual(receipt.sourceIdentity, "ModelPlanOfficialDock.T2FaceMaterial")
        XCTAssertEqual(receipt.viewport, viewport); XCTAssertEqual(receipt.pixelSize, CGSize(width:100,height:220))
        XCTAssertEqual(receipt.gradientRGB, [[21,29,35],[54,63,68],[38,50,57],[16,27,36],[3,9,17]])
        XCTAssertEqual(receipt.gradientLocations, [0,0.17,0.43,0.74,1]); XCTAssertEqual(receipt.grainOpacity,0.018)
        XCTAssertEqual(material.renderedLayerRolesForChecks, ["face.gradient","face.grain","face.soot","ignition.well","grip"])
        let bytes = image.dataProvider?.data as Data?
        _ = material.renderedMaterialForChecks; _ = material.renderedLayerRolesForChecks
        XCTAssertEqual(image.dataProvider?.data as Data?, bytes)
        XCTAssertThrowsError(try material.render(geometry: geometry, viewport: .zero, scale: 1))
        XCTAssertNil(material.renderedMaterialForChecks); XCTAssertTrue(material.renderedLayerRolesForChecks.isEmpty)
    }
    private func working(alias: String? = nil) throws -> (DockWorkingEffects, DockInstrumentView, EffectResourcePool) {
        let palette = Dictionary(uniqueKeysWithValues: ["body","case","track","notch","clockBack","clock","text","unknown","normal","warning","critical","alias","noticeAmber","noticeBlue","noticeWhite"].map { ($0, DockInk(0.5,0.5,0.5)) })
        let inks = try JSONSerialization.jsonObject(with: JSONEncoder().encode(palette))
        let json: [String: Any] = ["schemaVersion":1,"bounds":[[0,0],[96,96]],"bodyPolygon":[[0,0],[96,0],[96,96],[0,96]],"fixedLayers":[],"palette":inks,
            "text":["size":11,"weight":400],"aliasText":["size":10,"weight":400],
            "stations":[["subscriptionID":"sub","centre":[48,30],"diameter":24,"readout":[[20,50],[56,16]],"aliasRect":[[10,20],[30,14]],"eventRect":[[64,52],[12,12]],"glyphRect":[[36,18],[24,24]],"layers":[],"glyphs":[:],"outer":["radius":10,"width":2,"minimumVisibleFraction":0,"opacity":1],"inner":["radius":7,"width":1,"minimumVisibleFraction":0,"opacity":1],"clock":["radius":14,"dotRadius":0.5,"backWidth":1,"positions":10],"notchWidth":1,"caseInnerRadius":5]]]
        let skin = try JSONDecoder().decode(DockInstrumentSkin.self, from: JSONSerialization.data(withJSONObject: json))
        var input = DockInstrumentInput(id: "sub", name: "Synthetic", windows: [.init(id: "quota", period: .fiveHour, label: "5h", remainingPercent: 70, resetsAt: Date().addingTimeInterval(3600), durationSeconds: 18000)])
        input.alias = alias; input.dataState = .fresh; input.working = DockWorkingSignal(subscriptionID: "sub", bindingVerified: true, fresh: true, observedOutput: true)
        let reading = try DockInstrumentProjection.evaluate(input, now: Date())
        let resources = try DockArtworkStore(root: FileManager.default.temporaryDirectory, manifest: .init(files: [:]))
        let view = DockInstrumentView(frame: skin.bounds)
        try view.applyOfficial(skin: skin, rows: [reading], renderer: DockInstrumentRenderer(resources: resources), scale: 1, locale: "en")
        let pool = EffectResourcePool(), driver = DockWorkingEffects(pool: pool, systemReduceMotion: { false })
        let provider = G1Frames()
        try driver.configure(view: view, skin: skin, readings: [reading], profile: .init(scale: 1), rotation: .init(period: 2), provider: { _ in provider })
        return (driver, view, pool)
    }
    func testRenderedTextClipAndTransformShareKnownParentCoordinates() throws {
        let (_,view,_) = try working(alias:"Synthetic alias")
        defer { view.dispose() }
        let readout = try XCTUnwrap(view.renderedReadoutBackingForChecks["sub"])
        let alias = try XCTUnwrap(view.renderedAliasBackingForChecks["sub"])
        XCTAssertEqual(readout.frame,CGRect(x:20,y:50,width:56,height:16))
        XCTAssertEqual(alias.frame,CGRect(x:10,y:20,width:30,height:14))
        XCTAssertEqual(G1SnapshotReader.rasterRect(readout.frame,transform:readout.frameTransform,scale:1,pixelHeight:96),CGRect(x:20,y:50,width:56,height:16))
        XCTAssertEqual(G1SnapshotReader.rasterRect(alias.frame,transform:alias.frameTransform,scale:1,pixelHeight:96),CGRect(x:10,y:20,width:30,height:14))
        XCTAssertNotEqual(readout.frameTransform,readout.glyphTransform,"The CoreText glyph basis is separately recorded")
    }
    func testNormalCockpitRouteCanBeObservedWithoutOpeningWebKitOrAWindow() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("g1-headless-cockpit-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        func digest(_ data: Data) -> String { SHA256.hash(data:data).map { String(format:"%02x",$0) }.joined() }
        let resources = root.appendingPathComponent("bundle")
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        let html = Data("<html>synthetic</html>".utf8)
        try html.write(to: resources.appendingPathComponent("index.html"))
        let manifest = try JSONSerialization.data(withJSONObject: ["schemaVersion":1,"edition":"community","interfaceOnly":true,"files":["index.html":digest(html)]])
        try manifest.write(to: resources.appendingPathComponent("bundle-manifest.json"))
        let verified = try VerifiedCockpitBundle(root: resources, manifestSHA256: digest(manifest))
        let store = try SettingsStore(url: root.appendingPathComponent("profile/settings.json"))
        _ = try await store.update { $0.theme = .night }
        var fanout: CockpitStoreFanout?
        let app = CommunityCockpitApplicationFactory.makeForChecks(configuration: .init(executableURL: root.appendingPathComponent("not-launched"), applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: store, bundleURL: root, verifiedBundleForChecks: verified) { config, consumer in
            fanout = consumer as? CockpitStoreFanout
            return ProcessEngineClient(configuration: config, consumer: consumer)
        }
        defer { app.composition.dock.close() }
        XCTAssertNil(app.cockpitStateForChecks)
        let actual = try XCTUnwrap(fanout)
        let context = EngineDeliveryContext(sessionID: UUID().uuidString, floor: .init(storeEpoch:"synthetic", generation:1), revision:1)
        await actual.consume(.context(context))
        app.showConsole()
        let deadline = ContinuousClock.now + .seconds(5)
        while app.cockpitStateForChecks == nil, ContinuousClock.now < deadline { await Task.yield() }
        let state = try XCTUnwrap(app.cockpitStateForChecks)
        XCTAssertTrue(state.openRequested)
        XCTAssertFalse(state.hasWindow); XCTAssertFalse(state.hasWebView)
        XCTAssertTrue(state.blocked, "A headless inspection must not invent a page-ready receipt")
        XCTAssertEqual(state.context.storeEpoch, "synthetic")
        let observed=try XCTUnwrap(app.composition.renderedSnapshotForChecks().element("cockpit"))
        XCTAssertEqual(observed.attributes["selectedScope"],"all")
        XCTAssertNotNil(observed.unavailable["webTree"],"Headless shell state must not fabricate a drawn web tree")
        await actual.consume(.clearPrivateViews(.init(revision:2,reason:.connectionLost,previous:context,nextFloor:nil)))
        XCTAssertNil(app.cockpitStateForChecks)
    }
    func testWindowAndDetachedEntryBothUseTheIsolatedNotificationLedgerBeforePresentation() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("g1-window-ledger-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let ledger = root.appendingPathComponent("isolated/notifications.json")
        let previous = EngineRowsEntry.isolatedNativeNotificationLedgerForChecks
        EngineRowsEntry.isolatedNativeNotificationLedgerForChecks = ledger
        defer { EngineRowsEntry.isolatedNativeNotificationLedgerForChecks = previous }
        for native in [false, true] {
            let app = EngineRowsEntry.make(configuration:.init(executableURL:root.appendingPathComponent("not-launched"),applicationVersion:"synthetic",allowedEnvironment:[:]),settingsStore:try EngineRowsEntry.makeSettingsStore(applicationSupport:root.appendingPathComponent(native ? "window-profile":"detached-profile")),createsNativePanels:native,activateSettings:{})
            XCTAssertEqual(app.composition.nativeNotificationLedgerForChecks, ledger)
            XCTAssertNil(app.composition.dock.nativePanel, "Construction must not present a window")
            await app.composition.stop()
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath:ledger.path), "No event was delivered, so no ledger write is needed")
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
    func testSliverReportsDrawnColourRunsWithoutInventingQuotaProvenance() throws {
        let sliver = DockSliverView(frame: .init(x: 0, y: 0, width: 4, height: 20))
        defer { sliver.dispose() }
        XCTAssertTrue(sliver.quotaSegmentColorRolesForChecks.isEmpty)
        let context = try XCTUnwrap(CGContext(data: nil, width: 4, height: 20, bitsPerComponent: 8, bytesPerRow: 16,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1)); context.fill(.init(x: 0, y: 0, width: 4, height: 10))
        context.setFillColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1)); context.fill(.init(x: 0, y: 10, width: 4, height: 10))
        try sliver.apply(image: try XCTUnwrap(context.makeImage()), logicalSize: .init(width: 4, height: 20), scale: 1, accessibilityLabel: "Synthetic")
        let frame = sliver.frame, bytes = sliver.retainedBytes
        let segments = sliver.rasterColorRunsForChecks
        // AppKit colour-matches supplied images. Inspect the actual resolved channels,
        // while keeping the exact RGBA available to a controlled-profile acceptance test.
        let rgb = segments.map { segment -> [Int] in
            let hex = Array(segment.rgbaHex.dropFirst())
            return stride(from: 0, to: 6, by: 2).map { Int(String(hex[$0...($0 + 1)]), radix: 16)! }
        }
        XCTAssertTrue(rgb.contains { $0[0] > 230 && $0[1] < 70 && $0[2] < 70 })
        XCTAssertTrue(rgb.contains { $0[2] > 230 && $0[0] < 70 && $0[1] < 70 })
        XCTAssertTrue(segments.allSatisfy { $0.rgbaHex.count == 9 && $0.rgbaHex.hasSuffix("FF") })
        XCTAssertEqual(segments.first?.from, 0); XCTAssertEqual(segments.last?.through, 1)
        XCTAssertTrue(segments.allSatisfy { $0.remainingPercent == nil && $0.quotaRole == nil })
        XCTAssertEqual(sliver.frame, frame); XCTAssertEqual(sliver.retainedBytes, bytes)
        XCTAssertEqual(sliver.rasterColorRunsForChecks, segments, "Inspection must not alter drawing state")
        XCTAssertTrue(sliver.quotaSegmentColorRolesForChecks.isEmpty, "Pixels alone must not create member quota facts")
        try sliver.apply(image: nil, logicalSize: .init(width: 4, height: 20), scale: 1, accessibilityLabel: "Synthetic")
        XCTAssertFalse(sliver.rasterColorRunsForChecks.isEmpty, "The neutral metal also has observable colours")
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
        XCTAssertEqual(driver.frameBoundsForChecks["sub"], CGRect(x:0,y:0,width:24,height:24))
        driver.stop(); XCTAssertTrue(driver.frameBoundsForChecks.isEmpty)
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
    func testNormalEntryFrameInspectionDoesNotInstallAnEffectOrOpenAWindow() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("g1-frame-inspection-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = EngineRowsEntry.make(configuration: .init(executableURL: root.appendingPathComponent("not-launched"), applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: try EngineRowsEntry.makeSettingsStore(applicationSupport: root), createsNativePanels: false, activateSettings: {})
        defer { app.composition.dock.close() }
        let dock = app.composition.dock
        XCTAssertTrue(dock.workingEffectFramesForChecks.isEmpty)
        XCTAssertTrue(dock.workingEffectFramesForChecks.isEmpty)
        XCTAssertTrue(dock.workingEffectFrameBoundsForChecks.isEmpty)
        XCTAssertTrue(dock.activeWorkingEffectIDs.isEmpty)
        XCTAssertNil(dock.nativePanel)
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
