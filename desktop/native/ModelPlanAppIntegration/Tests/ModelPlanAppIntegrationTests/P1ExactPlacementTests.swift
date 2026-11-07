// SPDX-License-Identifier: MIT
import AppKit
import ImageIO
import XCTest
@_spi(DockResourceChecks) import ModelPlanDock
import ModelPlanSettings
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanWire
@testable import ModelPlanAppIntegration

private actor P1SyntheticEngine: EngineClient {
    nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool { true }
    let store: EngineStore, rows: WireRowsSnapshot
    let context = EngineDeliveryContext(sessionID: "p1-synthetic", floor: .init(storeEpoch: "p1-synthetic", generation: 1), revision: 1)
    init(store: EngineStore, rows: WireRowsSnapshot) { self.store = store; self.rows = rows }
    func start() async throws -> EngineDeliveryContext {
        await store.consume(.connection(.ready(context))); await store.consume(.context(context))
        return context
    }
    func retry() async throws -> EngineDeliveryContext { try await start() }
    func stop() async {}
    func subscribeRows(timeout: Duration?) async throws -> EngineRequestCompletion {
        await store.consume(.rowsChanged(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch, consentGeneration: 1, data: rows), delivery: context), invalidRowCount: 0))
        return .init(requestID: .string("p1-rows"))
    }
    func consent(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func grant(_ request: WireConsentGrantParams, userAction: EngineUserAction?, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func refresh(_ request: WireRefreshRequestParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func history(_ request: WireHistoryQueryParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func cockpit(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func publication(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func pluginInstall(_ request: WirePluginInstallParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func diagnostics(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
}

@MainActor private final class P1NoWindowSurface: SettingsWindowSurface {
    func prepare() async {}
    func show(paneID: String?) { XCTFail("Unexpected first-run presentation in no-window test") }
    func hide() {}
}

@MainActor final class P1ExactPlacementTests: XCTestCase {
    private func protect(_ app: EngineDockMenuApplication) {
        app.makeFirstRunSurface = { _ in P1NoWindowSurface() }
        app.makeFirstRunSurfaceWithConsent = { _, _ in P1NoWindowSurface() }
        addTeardownBlock { @MainActor in
            await app.stopLifecycle()
            app.composition.dock.close()
        }
    }

    func testBottomSystemDockWithPreferredRightOnNormalEntry() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("p1-bottom-right-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: profile) }
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        let rows = try WireDecoder.decode(WireRowsSnapshot.self, from: Data(contentsOf: capture))
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en"])
        _ = try await store.update { preferences in
            preferences.showDock = true; preferences.autoHide = true; preferences.dockEdge = .right
            for _ in 0..<16 { preferences.onboarding.next() }
        }
        let display = DockDisplayArea(id: "primary", frame: CGRect(x: 0, y: 0, width: 1440, height: 900), visibleFrame: CGRect(x: 0, y: 80, width: 1440, height: 820))
        let app = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: store, createsNativePanels: false, bundleURL: profile.appendingPathComponent("Synthetic.app"),
            dockEnvironment: { .init(displays: [display], layouts: [], primaryDisplayID: "primary", pointer: CGPoint(x: 700, y: 500)) },
            makeClient: { _, store in P1SyntheticEngine(store: store, rows: rows) }, makeSettingsSurface: { _ in P1NoWindowSurface() }, activateSettings: {})
        protect(app)
        await app.prepare()
        app.startLifecycle(workspace: NotificationCenter(), local: NotificationCenter(), lockEvents: NotificationCenter(), displayIDs: { [1] }, onConsole: { true }, displaysAsleep: { _ in false })
        for _ in 0..<1000 { if !app.lifecyclePaused { break }; try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertFalse(app.lifecyclePaused)
        let observed = try XCTUnwrap(app.currentSettingsContext.dockPlacementObservation)
        let actual = try XCTUnwrap(app.composition.dock.edgePresentation?.placement)
        XCTAssertEqual(observed.edge, .right); XCTAssertFalse(observed.recovering)
        XCTAssertEqual(actual.edge, .right); XCTAssertEqual(actual.frame.maxX, display.usableFrame.maxX, accuracy: 0.01)
        await app.stopLifecycle(); app.composition.dock.close()
    }
    func testRegisteredBackgroundDragCommitsCrossDisplayAndSurvivesRestart() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("p1-drag-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: profile) }
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        let rows = try WireDecoder.decode(WireRowsSnapshot.self, from: Data(contentsOf: capture))
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en"])
        _ = try await store.update { p in p.showDock = true; p.autoHide = false; p.dockDisplayID = "primary"; p.dockEdge = .right; p.followActiveDisplay = false; for _ in 0..<16 { p.onboarding.next() } }
        let primary = DockDisplayArea(id: "primary", frame: CGRect(x: 0, y: 0, width: 1200, height: 900), visibleFrame: CGRect(x: 0, y: 0, width: 1200, height: 900))
        let secondary = DockDisplayArea(id: "secondary", frame: CGRect(x: -1000, y: 100, width: 1000, height: 800), visibleFrame: CGRect(x: -1000, y: 100, width: 1000, height: 800))
        var pointer = CGPoint(x: 800, y: 450), presence = DockPresence()
        let environment: @MainActor () -> DockEdgeEnvironment = { .init(displays: [primary, secondary], layouts: [], primaryDisplayID: "primary", pointer: pointer, presence: presence) }
        func make(_ settings: SettingsStore) -> EngineDockMenuApplication {
            EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: settings, createsNativePanels: false, bundleURL: profile.appendingPathComponent("Synthetic.app"), dockEnvironment: environment,
                makeClient: { _, target in P1SyntheticEngine(store: target, rows: rows) }, makeSettingsSurface: { _ in P1NoWindowSurface() }, activateSettings: {})
        }
        let app = make(store); protect(app); await app.prepare()
        app.startLifecycle(workspace: NotificationCenter(), local: NotificationCenter(), lockEvents: NotificationCenter(), displayIDs: { [1,2] }, onConsole: { true }, displaysAsleep: { _ in false })
        for _ in 0..<1000 { if !app.lifecyclePaused { break }; try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertFalse(app.lifecyclePaused)
        let host = app.composition.dock, initial = try XCTUnwrap(host.edgePresentation?.placement)
        XCTAssertEqual(initial.displayID, "primary"); XCTAssertEqual(initial.edge, .right)
        try await Task.sleep(for: .milliseconds(400))
        let handler = try XCTUnwrap(host.dockView.backgroundDragDelegate)
        let bounds = host.dockView.bounds
        let candidates = (0..<Int(bounds.height)).lazy.flatMap { y in (0..<Int(bounds.width)).lazy.map { x in CGPoint(x: CGFloat(x)+0.5, y: CGFloat(y)+0.5) } }
        let local = try XCTUnwrap(candidates.first { handler.backgroundCanDrag(local: $0) && host.dockView.isPainted(atLocal: $0) })
        let start = CGPoint(x: initial.frame.minX + local.x, y: initial.frame.maxY - local.y)
        pointer = start; presence.mouseButtonDown = true
        XCTAssertTrue(handler.beginBackgroundMove(local: local, global: start))
        let destination = CGPoint(x: -999, y: 500); pointer = destination
        handler.updateBackgroundMove(global: destination)
        let preview = try XCTUnwrap(host.edgePresentation?.placement)
        XCTAssertTrue(handler.isBackgroundMoving); XCTAssertEqual(preview.displayID, "secondary"); XCTAssertEqual(preview.edge, .left)
        XCTAssertNotNil(host.dockView.registeredMoveOutlinePath)
        presence.mouseButtonDown = false; handler.endBackgroundMove(global: destination)
        for _ in 0..<1000 { if await store.snapshot().preferences.dockDisplayID == "secondary" { break }; try await Task.sleep(for: .milliseconds(10)) }
        let saved = await store.snapshot().preferences
        XCTAssertEqual(saved.dockDisplayID, "secondary"); XCTAssertEqual(saved.dockEdge, .left)
        XCTAssertFalse(saved.followActiveDisplay)
        XCTAssertEqual(app.currentSettingsContext.dockPlacementObservation?.displayID, "secondary")
        await app.stopLifecycle(); host.close()
        pointer = CGPoint(x: 800, y: 450)
        let reopened = make(try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en"]))
        protect(reopened)
        await reopened.prepare(); reopened.startLifecycle(workspace: NotificationCenter(), local: NotificationCenter(), lockEvents: NotificationCenter(), displayIDs: { [1,2] }, onConsole: { true }, displaysAsleep: { _ in false })
        for _ in 0..<1000 { if !reopened.lifecyclePaused { break }; try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(reopened.composition.dock.edgePresentation?.placement?.displayID, "secondary")
        XCTAssertEqual(reopened.composition.dock.edgePresentation?.placement?.edge, .left)
        XCTAssertFalse(try XCTUnwrap(reopened.currentSettingsContext.dockPlacementObservation).recovering)
        await reopened.stopLifecycle(); reopened.composition.dock.close()
    }
    func testSameEdgeDragKeepsFollowActiveAcrossRelaunch() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("p1-follow-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: profile) }
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        let rows = try WireDecoder.decode(WireRowsSnapshot.self, from: Data(contentsOf: capture))
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en"])
        _ = try await store.update { p in p.showDock = true; p.autoHide = false; p.dockEdge = .right; p.followActiveDisplay = true; for _ in 0..<16 { p.onboarding.next() } }
        let primary = DockDisplayArea(id: "primary", frame: CGRect(x: 0, y: 0, width: 1200, height: 900), visibleFrame: CGRect(x: 0, y: 0, width: 1200, height: 900))
        let secondary = DockDisplayArea(id: "secondary", frame: CGRect(x: 1400, y: 100, width: 1000, height: 800), visibleFrame: CGRect(x: 1400, y: 100, width: 1000, height: 800))
        var pointer = CGPoint(x: 600, y: 450), presence = DockPresence()
        let environment: @MainActor () -> DockEdgeEnvironment = { .init(displays: [primary, secondary], layouts: [], primaryDisplayID: "primary", pointer: pointer, presence: presence) }
        func make(_ settings: SettingsStore) -> EngineDockMenuApplication {
            EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: settings, createsNativePanels: false, bundleURL: profile.appendingPathComponent("Synthetic.app"), dockEnvironment: environment,
                makeClient: { _, target in P1SyntheticEngine(store: target, rows: rows) }, makeSettingsSurface: { _ in P1NoWindowSurface() }, activateSettings: {})
        }
        let app = make(store); protect(app); await app.prepare()
        app.startLifecycle(workspace: NotificationCenter(), local: NotificationCenter(), lockEvents: NotificationCenter(), displayIDs: { [1,2] }, onConsole: { true }, displaysAsleep: { _ in false })
        for _ in 0..<1000 { if !app.lifecyclePaused { break }; try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertFalse(app.lifecyclePaused)
        let host = app.composition.dock, initial = try XCTUnwrap(host.edgePresentation?.placement)
        XCTAssertEqual(initial.displayID, "primary"); XCTAssertEqual(initial.edge, .right)
        try await Task.sleep(for: .milliseconds(400))
        let handler = try XCTUnwrap(host.dockView.backgroundDragDelegate), bounds = host.dockView.bounds
        let candidates = (0..<Int(bounds.height)).lazy.flatMap { y in (0..<Int(bounds.width)).lazy.map { x in CGPoint(x: CGFloat(x)+0.5, y: CGFloat(y)+0.5) } }
        let local = try XCTUnwrap(candidates.first { handler.backgroundCanDrag(local: $0) && host.dockView.isPainted(atLocal: $0) })
        let start = CGPoint(x: initial.frame.minX + local.x, y: initial.frame.maxY - local.y)
        pointer = start; presence.mouseButtonDown = true
        XCTAssertTrue(handler.beginBackgroundMove(local: local, global: start))
        let destination = CGPoint(x: 1199, y: 700); pointer = destination
        handler.updateBackgroundMove(global: destination)
        let preview = try XCTUnwrap(host.edgePresentation?.placement)
        XCTAssertEqual(preview.displayID, "primary"); XCTAssertEqual(preview.edge, .right)
        XCTAssertNotEqual(preview.alongFraction, initial.alongFraction)
        presence.mouseButtonDown = false; handler.endBackgroundMove(global: destination)
        for _ in 0..<1000 { if abs((await store.snapshot().preferences.dockAlongFraction) - preview.alongFraction) < 0.000001 { break }; try await Task.sleep(for: .milliseconds(10)) }
        let saved = await store.snapshot().preferences
        XCTAssertTrue(saved.followActiveDisplay); XCTAssertEqual(saved.dockAlongFraction, preview.alongFraction, accuracy: 0.000001)
        await app.stopLifecycle(); host.close()
        pointer = CGPoint(x: 1900, y: 450)
        let reopened = make(try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en"]))
        protect(reopened)
        await reopened.prepare(); reopened.startLifecycle(workspace: NotificationCenter(), local: NotificationCenter(), lockEvents: NotificationCenter(), displayIDs: { [1,2] }, onConsole: { true }, displaysAsleep: { _ in false })
        for _ in 0..<1000 { if !reopened.lifecyclePaused { break }; try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(reopened.composition.dock.edgePresentation?.placement?.displayID, "secondary")
        let after = await store.snapshot().preferences
        XCTAssertEqual(after.dockAlongFraction, preview.alongFraction, accuracy: 0.000001)
        await reopened.stopLifecycle(); reopened.composition.dock.close()
    }
    func testG323DisabledIgnitionShowsTheRedCapWithoutADarkVeil() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("p1-veil-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: profile) }
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        let rows = try WireDecoder.decode(WireRowsSnapshot.self, from: Data(contentsOf: capture))
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en"])
        _ = try await store.update { p in p.autoHide = false; for _ in 0..<16 { p.onboarding.next() } }
        let screen = DockDisplayArea(id: "primary", frame: CGRect(x: 0, y: 0, width: 1200, height: 900), visibleFrame: CGRect(x: 0, y: 0, width: 1200, height: 900))
        let app = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: store, createsNativePanels: false, bundleURL: profile.appendingPathComponent("Synthetic.app"), cockpitEntryEnabled: false,
            dockEnvironment: { .init(displays: [screen], layouts: [], primaryDisplayID: "primary", pointer: CGPoint(x: 600, y: 450)) },
            makeClient: { _, target in P1SyntheticEngine(store: target, rows: rows) }, makeSettingsSurface: { _ in P1NoWindowSurface() }, activateSettings: {})
        protect(app)
        await app.prepare(); app.startLifecycle(workspace: NotificationCenter(), local: NotificationCenter(), lockEvents: NotificationCenter(), displayIDs: { [1] }, onConsole: { true }, displaysAsleep: { _ in false })
        for _ in 0..<1000 { if !app.lifecyclePaused { break }; try await Task.sleep(for: .milliseconds(10)) }
        let container = try XCTUnwrap(app.composition.dock.dockView.superview)
        let button = try XCTUnwrap(container.subviews.compactMap { $0 as? NSButton }.first)
        XCTAssertFalse(button.isEnabled, "The disabled cockpit must stay disabled")
        // G3-23: nothing dark is painted over the red cap (was a 65 % black veil).
        for view in container.subviews where view !== button && view !== app.composition.dock.dockView && !view.isHidden {
            XCTAssertFalse(view.frame.intersects(button.frame) && (view.layer?.backgroundColor?.alpha ?? 0) > 0,
                           "a view darkens the ignition: \(view)")
        }
        // Snapshot of the presented widget at the cap: the official red, as in the prototype.
        let view = app.composition.dock.dockView
        let skin = try XCTUnwrap(view.presentedSkinForChecks)
        let cap = try XCTUnwrap(skin.fixedLayers.first { $0.resource.contains("cap-night-idle") }).rect
        let image = try XCTUnwrap(view.presentedImageForChecks)
        // The resting image covers the skin bounds (as in HostPairedProjectionTests' crops).
        let scale = CGFloat(image.width) / skin.bounds.width
        let origin = skin.bounds.origin
        let core = cap.insetBy(dx: cap.width * 0.3, dy: cap.height * 0.3).offsetBy(dx: -origin.x, dy: -origin.y)
            .applying(.init(scaleX: scale, y: scale)).integral
        let cropped = try XCTUnwrap(image.cropping(to: core))
        let context = try XCTUnwrap(CGContext(data: nil, width: cropped.width, height: cropped.height, bitsPerComponent: 8,
            bytesPerRow: cropped.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(cropped, in: CGRect(x: 0, y: 0, width: cropped.width, height: cropped.height))
        let bytes = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
        var sum = [0.0, 0.0, 0.0], count = 0.0
        for index in stride(from: 0, to: cropped.width * cropped.height * 4, by: 4) {
            for channel in 0..<3 { sum[channel] += Double(bytes[index + channel]) }
            count += 1
        }
        let (red, green, blue) = (sum[0] / count, sum[1] / count, sum[2] / count)
        XCTAssertGreaterThan(red, 150, "The ignition cap must read red, not dark: rgb(\(red), \(green), \(blue))")
        XCTAssertGreaterThan(red, 2 * green); XCTAssertGreaterThan(red, 2 * blue)
        await app.stopLifecycle(); app.composition.dock.close()
    }

    /// G3-30: the expanded widget's face touches the screen edge exactly like the prototype
    /// (geometry.js: attached side at depth 0, first ring's outer edge 14 x D/52 from the edge).
    /// The collapsed strip and its 20 pt wake band are never part of the expanded window; the only
    /// extra window area is the transparent ceil(D/2) hover canvas on the screen side.
    func testG330ExpandedFaceTouchesTheScreenEdgeAtEverySize() async throws {
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        let rows = try WireDecoder.decode(WireRowsSnapshot.self, from: Data(contentsOf: capture))
        for size in SettingsSize.allCases {
            let profile = FileManager.default.temporaryDirectory.appendingPathComponent("p1-g330-" + UUID().uuidString)
            addTeardownBlock { try? FileManager.default.removeItem(at: profile) }
            let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en"])
            _ = try await store.update { p in
                p.showDock = true; p.autoHide = false; p.dockEdge = .right; p.size = size
                for _ in 0..<16 { p.onboarding.next() }
            }
            let screen = DockDisplayArea(id: "primary", frame: CGRect(x: 0, y: 0, width: 1440, height: 900), visibleFrame: CGRect(x: 0, y: 80, width: 1440, height: 795))
            let app = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: store, createsNativePanels: false, bundleURL: profile.appendingPathComponent("Synthetic.app"),
                dockEnvironment: { .init(displays: [screen], layouts: [], primaryDisplayID: "primary", pointer: CGPoint(x: 600, y: 450)) },
                makeClient: { _, target in P1SyntheticEngine(store: target, rows: rows) }, makeSettingsSurface: { _ in P1NoWindowSurface() }, activateSettings: {})
            protect(app)
            await app.prepare()
            app.startLifecycle(workspace: NotificationCenter(), local: NotificationCenter(), lockEvents: NotificationCenter(), displayIDs: { [1] }, onConsole: { true }, displaysAsleep: { _ in false })
            for _ in 0..<1000 { if !app.lifecyclePaused { break }; try await Task.sleep(for: .milliseconds(10)) }
            let host = app.composition.dock
            let presentation = try XCTUnwrap(host.edgePresentation)
            XCTAssertEqual(presentation.state, .expanded, "\(size)")
            let placement = try XCTUnwrap(presentation.placement)
            let d = size.nozzleDiameter, unit = d / 52
            // The window is flush with the screen edge and holds only the face plus the hover canvas.
            XCTAssertEqual(placement.frame.maxX, screen.usableFrame.maxX, accuracy: 0.01, "\(size) window flush")
            XCTAssertEqual(try XCTUnwrap(presentation.paintedFrame), placement.frame, "\(size) expanded paints the face frame, not the strip")
            let face = try XCTUnwrap(placement.globalHoverRects.first)
            XCTAssertEqual(face.maxX, screen.usableFrame.maxX, accuracy: 0.01, "\(size) face touches the screen edge")
            XCTAssertEqual(placement.frame.width - face.width, ceil(d / 2), accuracy: 0.5, "\(size) only the transparent hover canvas is added, on the screen side")
            // Visible face depth matches the prototype formula (D/2+14s)+(D/2+3s)+7s plus at most the 8s arc sagitta.
            let freeDepth = d + 24 * unit
            XCTAssertGreaterThanOrEqual(face.width, freeDepth - 0.5, "\(size) face depth")
            XCTAssertLessThanOrEqual(face.width, freeDepth + 8 * unit + 1.5, "\(size) face depth")
            // Rings: the first ring's outer edge sits 14 x D/52 from the screen edge (arc adds at most 8 x D/52).
            let view = host.dockView
            let ids = host.interactionEnvironment().catalogue
            XCTAssertFalse(ids.isEmpty)
            for id in ids {
                guard let ring = view.interactionAnchor(id) else { continue }
                let gap = view.bounds.maxX - ring.maxX
                XCTAssertGreaterThanOrEqual(gap, 14 * unit - 0.75, "\(size) \(id) ring to screen edge")
                XCTAssertLessThanOrEqual(gap, 22 * unit + 0.75, "\(size) \(id) ring to screen edge")
            }
            // The resting raster is opaque in its edge-most column at a station: nothing transparent
            // (strip, wake band) separates the face from the screen edge.
            let skin = try XCTUnwrap(view.presentedSkinForChecks)
            let image = try XCTUnwrap(view.presentedImageForChecks)
            let station = try XCTUnwrap(skin.stations.first { $0.subscriptionID != nil })
            let scale = CGFloat(image.width) / skin.bounds.width
            let row = Int(((station.centre.y - skin.bounds.minY) * scale).rounded(.down))
            let pixel = try XCTUnwrap(image.cropping(to: CGRect(x: image.width - 1, y: row, width: 1, height: 1)))
            var rgba = [UInt8](repeating: 0, count: 4)
            let context = try XCTUnwrap(CGContext(data: &rgba, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(pixel, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            XCTAssertGreaterThan(rgba[3], 200, "\(size) the face is painted up to the screen edge")
            await app.stopLifecycle(); host.close()
        }
    }

    /// G3-30: ring centres sit across the face depth exactly where the prototype puts them.
    /// Oracle values come from the prototype's geometry.js (right edge, percentages on), not from
    /// the native port: ring centre to the screen edge per station, and ring centre to the face's
    /// inner edge = (D/2 + 3s + 7s + D/2 + 14s) - (D/2 + 14s) = D/2 + 10s = 36 x D/52.
    /// Prototype: clients/official-visuals/dock-aftview-integration/geometry.js:67-69,119,120-125.
    /// The pixel scan reads the inner edge from the resting raster, so a renderer offset is caught too.
    /// Writes 2x PNGs of the expanded widget (dock-visual/g3-30) as CI evidence.
    func testG330RingCentresSitAcrossTheFaceLikeThePrototype() async throws {
        let oracle: [SettingsSize: [Int: [CGFloat]]] = [
            .small: [1: [27.69], 3: [27.69, 29.73, 28.36], 5: [27.69, 29.94, 30.78, 30.22, 28.24]],
            .medium: [1: [33.85], 3: [33.85, 36.33, 34.66], 5: [33.85, 36.60, 37.62, 36.93, 34.52]],
            .large: [1: [40.00], 3: [40.00, 42.94, 40.96], 5: [40.00, 43.25, 44.47, 43.65, 40.79]]
        ]
        let root = ProcessInfo.processInfo.environment["RUNNER_TEMP"].map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? FileManager.default.temporaryDirectory
        let output = root.appendingPathComponent("dock-instrument-checks/dock-visual/g3-30", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        func png(_ image: CGImage, _ name: String) {
            guard let writer = CGImageDestinationCreateWithURL(output.appendingPathComponent(name + ".png") as CFURL, "public.png" as CFString, 1, nil) else { return }
            CGImageDestinationAddImage(writer, image, nil); CGImageDestinationFinalize(writer)
        }
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        var report = [String]()
        for count in [1, 3, 5] {
            var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: capture)) as? [String: Any])
            var projection = try XCTUnwrap(json["projection"] as? [String: Any])
            var row = try XCTUnwrap((projection["rows"] as? [[String: Any]])?.first)
            let template = try XCTUnwrap((row["accounts"] as? [[String: Any]])?.first)
            row["state"] = "fresh"; row["consent"] = "allowed"; row["surfaces"] = ["dock", "menu", "settings"]
            row["expiresAt"] = "2099-01-01T00:00:00Z"
            row["accounts"] = (0..<count).map { index -> [String: Any] in
                var account = template
                account["subscriptionRef"] = String(repeating: String(index + 1), count: 16)
                account["valueState"] = "current"; account["freshUntil"] = "2099-01-01T00:00:00Z"
                return account
            }
            projection["rows"] = [row]; json["projection"] = projection
            let rows = try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: json))
            for size in SettingsSize.allCases {
                let profile = FileManager.default.temporaryDirectory.appendingPathComponent("p1-g330r-" + UUID().uuidString)
                addTeardownBlock { try? FileManager.default.removeItem(at: profile) }
                let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en"])
                _ = try await store.update { p in
                    p.showDock = true; p.autoHide = false; p.dockEdge = .right; p.size = size; p.showPercentages = true
                    for _ in 0..<16 { p.onboarding.next() }
                }
                let screen = DockDisplayArea(id: "primary", frame: CGRect(x: 0, y: 0, width: 1440, height: 900), visibleFrame: CGRect(x: 0, y: 80, width: 1440, height: 795), backingScale: 2)
                let app = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: store, createsNativePanels: false, bundleURL: profile.appendingPathComponent("Synthetic.app"),
                    dockEnvironment: { .init(displays: [screen], layouts: [], primaryDisplayID: "primary", pointer: CGPoint(x: 600, y: 450)) },
                    makeClient: { _, target in P1SyntheticEngine(store: target, rows: rows) }, makeSettingsSurface: { _ in P1NoWindowSurface() }, activateSettings: {})
                protect(app)
                await app.prepare()
                app.startLifecycle(workspace: NotificationCenter(), local: NotificationCenter(), lockEvents: NotificationCenter(), displayIDs: { [1] }, onConsole: { true }, displaysAsleep: { _ in false })
                let view = app.composition.dock.dockView
                for _ in 0..<1000 {
                    if !app.lifecyclePaused, (view.presentedSkinForChecks?.stations.filter { $0.subscriptionID != nil }.count ?? 0) == count { break }
                    try await Task.sleep(for: .milliseconds(10))
                }
                let label = "\(size.rawValue)-\(count)"
                let skin = try XCTUnwrap(view.presentedSkinForChecks, label)
                let image = try XCTUnwrap(view.presentedImageForChecks, label)
                png(image, "resting-right-\(label)")
                // The whole expanded view (face plus the transparent hover canvas), drawn by AppKit.
                if view.bounds.width > 0, let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(view.bounds.width * 2), pixelsHigh: Int(view.bounds.height * 2),
                       bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) {
                    rep.size = view.bounds.size; view.cacheDisplay(in: view.bounds, to: rep)
                    if let full = rep.cgImage { png(full, "expanded-view-right-\(label)") }
                }
                let d = size.nozzleDiameter, unit = d / 52
                let stations = skin.stations.filter { $0.subscriptionID != nil }.sorted { $0.centre.y < $1.centre.y }
                let expected = try XCTUnwrap(oracle[size]?[count])
                XCTAssertEqual(stations.count, count, label)
                // The resting raster covers the skin bounds; rows run top-down.
                let pixels = CGFloat(image.width) / skin.bounds.width
                let rgba = try XCTUnwrap(CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue))
                rgba.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
                let bytes = try XCTUnwrap(rgba.data).assumingMemoryBound(to: UInt8.self)
                for (index, station) in stations.enumerated() where index < expected.count {
                    let depth = skin.bounds.maxX - station.centre.x
                    let y = Int(((station.centre.y - skin.bounds.minY) * pixels).rounded(.down))
                    // Start just inside the clock dots (radius 28.2 x D/52) so nozzle art never ends the scan.
                    var x = Int(((station.centre.x - 30 * unit - skin.bounds.minX) * pixels).rounded(.down))
                    while x > 0, bytes[(y * image.width + x) * 4 + 3] >= 128 { x -= 1 }
                    let innerEdge = skin.bounds.minX + CGFloat(x + 1) / pixels
                    let inward = station.centre.x - innerEdge
                    report.append("\(label) ring\(index) diameter \(station.diameter) centre-to-screen-edge \(depth) centre-to-inner-edge \(inward) y \(station.centre.y) pitch-prev \(index > 0 ? station.centre.y - stations[index - 1].centre.y : 0)")
                    XCTAssertEqual(depth, expected[index], accuracy: 0.5, "\(label) ring \(index): centre to screen edge (prototype \(expected[index]))")
                    XCTAssertEqual(inward, 36 * unit, accuracy: 1.0, "\(label) ring \(index): centre to the face's inner edge")
                    // The card measures its gap from the painted clock ring (prototype card.js:154-163).
                    let cardRing = try XCTUnwrap(view.cardRingAnchor(try XCTUnwrap(station.subscriptionID)))
                    XCTAssertEqual(cardRing.width, 2 * (26 + 2.2 + 0.75) * unit, accuracy: 0.05, "\(label) card ring")
                }
                await app.stopLifecycle(); app.composition.dock.close()
            }
        }
        try report.joined(separator: "\n").write(to: output.appendingPathComponent("g3-30-rings.txt"), atomically: true, encoding: .utf8)
        print(report.joined(separator: "\n"))
    }

    /// MENU-12: an actually open widget menu protects the widget; when AppKit ends tracking without
    /// the close callback, the flag clears anyway, so it never blocks the collapse.
    func testMENU12OpenMenuProtectsAndAStaleFlagClears() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("p1-menu12-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: profile) }
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        let rows = try WireDecoder.decode(WireRowsSnapshot.self, from: Data(contentsOf: capture))
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en"])
        _ = try await store.update { p in p.autoHide = false; for _ in 0..<16 { p.onboarding.next() } }
        let screen = DockDisplayArea(id: "primary", frame: CGRect(x: 0, y: 0, width: 1440, height: 900), visibleFrame: CGRect(x: 0, y: 80, width: 1440, height: 820))
        let app = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: store, createsNativePanels: false, bundleURL: profile.appendingPathComponent("Synthetic.app"),
            dockEnvironment: { .init(displays: [screen], layouts: [], primaryDisplayID: "primary", pointer: CGPoint(x: 50, y: 200)) },
            makeClient: { _, target in P1SyntheticEngine(store: target, rows: rows) }, makeSettingsSurface: { _ in P1NoWindowSurface() }, activateSettings: {})
        protect(app); await app.prepare()
        app.startLifecycle(workspace: NotificationCenter(), local: NotificationCenter(), lockEvents: NotificationCenter(), displayIDs: { [1] }, onConsole: { true }, displaysAsleep: { _ in false })
        for _ in 0..<1000 { if !app.lifecyclePaused { break }; try await Task.sleep(for: .milliseconds(10)) }
        let host = app.composition.dock
        XCTAssertNotNil(host.edgePresentation?.paintedFrame)
        let menu = host.menu()
        host.menuWillOpen(menu)
        XCTAssertTrue(host.menuOpenForChecks, "an open widget menu protects the widget")
        // AppKit ended tracking but the close callback was missed: the flag must not stay set.
        NotificationCenter.default.post(name: NSMenu.didEndTrackingNotification, object: menu)
        for _ in 0..<100 where host.menuOpenForChecks { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertFalse(host.menuOpenForChecks, "a stale menu flag clears with the end of tracking")
        host.menuWillOpen(menu); host.menuDidClose(menu)
        XCTAssertFalse(host.menuOpenForChecks)
        await app.stopLifecycle(); host.close()
    }

    func testFreshQuotaWidgetShowAndSavedChoicesOnNormalEntry() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("right-placement-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: profile) }
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        let rows = try WireDecoder.decode(WireRowsSnapshot.self, from: Data(contentsOf: capture))
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en"])
        let fresh = await store.snapshot().preferences
        XCTAssertTrue(fresh.showDock); XCTAssertFalse(fresh.autoHide, "Fresh Dock must stay visible until the user opts into hiding")
        XCTAssertEqual(fresh.dockEdge, .right); XCTAssertNil(fresh.dockDisplayID)
        _ = try await store.update { p in for _ in 0..<16 { p.onboarding.next() } }
        let screen = DockDisplayArea(id: "primary", frame: CGRect(x: 0, y: 0, width: 1440, height: 900), visibleFrame: CGRect(x: 0, y: 80, width: 1440, height: 820))
        let entry = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: store, createsNativePanels: false, bundleURL: profile.appendingPathComponent("Synthetic.app"),
            dockEnvironment: { .init(displays: [screen], layouts: [], primaryDisplayID: "primary", pointer: CGPoint(x: 600, y: 450)) },
            makeClient: { _, store in P1SyntheticEngine(store: store, rows: rows) }, makeSettingsSurface: { _ in P1NoWindowSurface() }, activateSettings: {})
        protect(entry)
        await entry.prepare()
        entry.startLifecycle(workspace: NotificationCenter(), local: NotificationCenter(), lockEvents: NotificationCenter(), displayIDs: { [1] }, onConsole: { true }, displaysAsleep: { _ in false })
        for _ in 0..<1000 { if !entry.lifecyclePaused { break }; try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertFalse(entry.lifecyclePaused)
        let observed = try XCTUnwrap(entry.currentSettingsContext.dockPlacementObservation)
        XCTAssertEqual(entry.composition.dock.edgePresentation?.state, .expanded)
        let placement = try XCTUnwrap(entry.composition.dock.edgePresentation?.placement)
        XCTAssertEqual(entry.composition.dock.currentMenuBarPreferences?.dockEdge, .right)
        XCTAssertEqual(observed.edge, .right, "A usable preferred edge must not be silently replaced")
        XCTAssertFalse(observed.recovering)
        XCTAssertEqual(placement.edge, .right)
        XCTAssertEqual(placement.frame.maxX, screen.usableFrame.maxX, accuracy: 0.01)
        // Owner decision 11-06: one checkable Show Quota Widget item; its checkmark is the saved switch.
        let showDock = try XCTUnwrap(entry.liveStatusMenu?.items.first { $0.title == "Show Quota Widget" }, "The status menu must offer the switch")
        XCTAssertTrue(showDock.isEnabled); XCTAssertEqual(showDock.state, .on)
        XCTAssertFalse(entry.composition.dock.menu().items.contains { $0.title == "Hide Quota Widget" })
        XCTAssertTrue(entry.composition.dock.menu().items.contains { $0.title == "Auto-Collapse" && $0.state == .off })
        let editor = entry.settingsHost.application.editor
        _ = try await editor.commit(SettingsB21Edit.autoHide(true))
        for _ in 0..<300 { if entry.composition.dock.edgePresentation?.state == .sliver { break }; try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(entry.composition.dock.edgePresentation?.state, .sliver, "Auto-hide is an explicit saved option")
        XCTAssertTrue(entry.composition.dock.menu().items.contains { $0.title == "Auto-Collapse" && $0.state == .on }, "the widget menu follows Settings")
        var accessibility = SettingsEnvironment(); accessibility.reduceMotion = false
        entry.updateSystemAccessibility(accessibility)
        XCTAssertFalse(try XCTUnwrap(entry.composition.latestSettings).effective.reduceMotion)
        // Unchecking turns the widget off; checking turns it on and locates it with the pulse.
        try await chooseShowQuotaWidget(entry, checked: true)
        XCTAssertEqual(entry.composition.dock.edgePresentation?.state, .suppressed(.userHidden))
        try await chooseShowQuotaWidget(entry, checked: false)
        for _ in 0..<300 { if entry.composition.dock.dockView.layer?.sublayers?.contains(where: { $0.name == "dock.locate-highlight" }) == true { break }; try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(entry.composition.dock.edgePresentation?.state, .expanded)
        let animated = try XCTUnwrap(entry.composition.dock.dockView.layer?.sublayers?.first { $0.name == "dock.locate-highlight" })
        XCTAssertTrue(animated.animationKeys()?.contains("locate-pulse") == true)
        accessibility.reduceMotion = true; entry.updateSystemAccessibility(accessibility)
        XCTAssertFalse(animated.animationKeys()?.contains("locate-pulse") == true)
        for _ in 0..<400 {
            if entry.composition.dock.dockView.layer?.sublayers?.contains(where: { $0.name == "dock.locate-highlight" }) != true { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertFalse(entry.composition.dock.dockView.layer?.sublayers?.contains(where: { $0.name == "dock.locate-highlight" }) == true, "Locating highlight must expire")
        let afterReveal = await store.snapshot().preferences
        XCTAssertTrue(afterReveal.autoHide); XCTAssertTrue(afterReveal.showDock); XCTAssertEqual(afterReveal.dockEdge, .right); XCTAssertNil(afterReveal.dockDisplayID)
        for _ in 0..<400 {
            if entry.composition.dock.edgePresentation?.state == .sliver { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(entry.composition.dock.edgePresentation?.state, .sliver, "The temporary reveal returns to the normal auto-hide rule")
        // The Settings switch and the status checkmark are the same stored setting.
        _ = try await editor.commit(SettingsB21Edit.showDock(false))
        XCTAssertEqual(entry.composition.dock.edgePresentation?.state, .suppressed(.userHidden))
        try await chooseShowQuotaWidget(entry, checked: false)
        for _ in 0..<300 { if entry.composition.dock.dockView.layer?.sublayers?.contains(where: { $0.name == "dock.locate-highlight" }) == true { break }; try await Task.sleep(for: .milliseconds(10)) }
        let staticReveal = try XCTUnwrap(entry.composition.dock.dockView.layer?.sublayers?.first { $0.name == "dock.locate-highlight" })
        XCTAssertTrue(staticReveal.animationKeys()?.isEmpty ?? true, "Reduce Motion uses a static highlight")
        XCTAssertTrue(try XCTUnwrap(entry.composition.dock.currentMenuBarPreferences).showDock)
        XCTAssertEqual(entry.composition.dock.edgePresentation?.state, .expanded)
        _ = try await editor.commit(SettingsB21Edit.language(.chinese))
        XCTAssertNotNil(entry.liveStatusMenu?.items.first { $0.title == "显示额度挂件" && $0.isEnabled && $0.state == .on })
        XCTAssertTrue(entry.composition.dock.menu().items.contains { $0.title == "自动收起" && $0.state == .on })
        XCTAssertFalse(entry.composition.dock.menu().items.contains { $0.title.contains("隐藏") })
        _ = try await editor.commit(SettingsB21Edit.language(.english))
        _ = try await editor.commit(SettingsB21Edit.autoHide(false))
        _ = try await editor.commit(SettingsB21Edit.dockEdge(.left))
        XCTAssertEqual(entry.currentSettingsContext.dockPlacementObservation?.edge, .left)
        _ = try await editor.commit(SettingsB21Edit.dockEdge(.right))
        XCTAssertEqual(entry.currentSettingsContext.dockPlacementObservation?.edge, .right)
        XCTAssertFalse(try XCTUnwrap(entry.currentSettingsContext.dockPlacementObservation).recovering)
        await entry.stopLifecycle(); entry.composition.dock.close()
        let restartedStore = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en"])
        let restarted = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: restartedStore, createsNativePanels: false, bundleURL: profile.appendingPathComponent("Synthetic.app"),
            dockEnvironment: { .init(displays: [screen], layouts: [], primaryDisplayID: "primary", pointer: CGPoint(x: 600, y: 450)) },
            makeClient: { _, store in P1SyntheticEngine(store: store, rows: rows) }, makeSettingsSurface: { _ in P1NoWindowSurface() }, activateSettings: {})
        protect(restarted)
        await restarted.prepare()
        restarted.startLifecycle(workspace: NotificationCenter(), local: NotificationCenter(), lockEvents: NotificationCenter(), displayIDs: { [1] }, onConsole: { true }, displaysAsleep: { _ in false })
        for _ in 0..<1000 { if !restarted.lifecyclePaused { break }; try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(restarted.currentSettingsContext.dockPlacementObservation?.edge, .right)
        XCTAssertFalse(try XCTUnwrap(restarted.currentSettingsContext.dockPlacementObservation).recovering)
        XCTAssertEqual(restarted.composition.dock.edgePresentation?.placement?.edge, .right)
        _ = try await restarted.settingsHost.application.editor.commit(SettingsB21Edit.dockDisplay("missing"))
        XCTAssertTrue(try XCTUnwrap(restarted.currentSettingsContext.dockPlacementObservation).recovering)
        let saved = await restartedStore.snapshot().preferences
        XCTAssertEqual(saved.dockDisplayID, "missing"); XCTAssertEqual(saved.dockEdge, .right)
        await restarted.stopLifecycle(); restarted.composition.dock.close()
    }


    // Hosted-only: normal entry with detached views, synthetic rows and synthetic pointer facts.
    func testNormalEntryCardLeavesAndCardBodyDoesNotPin() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("card-journey-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: profile) }
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        let rows = try WireDecoder.decode(WireRowsSnapshot.self, from: Data(contentsOf: capture))
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en"])
        _ = try await store.update { p in p.autoHide = false; for _ in 0..<16 { p.onboarding.next() } }
        let screen = DockDisplayArea(id: "primary", frame: CGRect(x: 0, y: 0, width: 1440, height: 900), visibleFrame: CGRect(x: 0, y: 80, width: 1440, height: 820))
        var pointer = CGPoint(x: 1400, y: 450), cardFrame: CGRect?
        let app = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: store, createsNativePanels: false, bundleURL: profile.appendingPathComponent("Synthetic.app"),
            dockEnvironment: { .init(displays: [screen], layouts: [], primaryDisplayID: "primary", pointer: pointer, cardFrame: cardFrame) },
            makeClient: { _, target in P1SyntheticEngine(store: target, rows: rows) }, makeSettingsSurface: { _ in P1NoWindowSurface() }, activateSettings: {})
        protect(app); await app.prepare()
        app.startLifecycle(workspace: NotificationCenter(), local: NotificationCenter(), lockEvents: NotificationCenter(), displayIDs: { [1] }, onConsole: { true }, displaysAsleep: { _ in false })
        for _ in 0..<1000 { if !app.lifecyclePaused { break }; try await Task.sleep(for: .milliseconds(10)) }
        let host = app.composition.dock
        let placement = try XCTUnwrap(host.edgePresentation?.placement)
        let id = try XCTUnwrap(host.interactionEnvironment().catalogue.first)
        pointer = CGPoint(x: placement.frame.midX, y: placement.frame.midY)
        let nozzle = try XCTUnwrap(host.dockView.nozzleEventDelegate)
        nozzle.hoverNozzle(id)
        for _ in 0..<100 { if host.detachedCardForChecks != nil { break }; try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertNotNil(host.detachedCardForChecks)
        cardFrame = CGRect(x: placement.frame.minX - 320, y: placement.frame.midY - 90, width: 300, height: 180)
        pointer = CGPoint(x: try XCTUnwrap(cardFrame).midX, y: try XCTUnwrap(cardFrame).midY)
        try await Task.sleep(for: .milliseconds(500))
        XCTAssertNotNil(host.detachedCardForChecks, "Card remains open while pointer is over it")
        pointer = CGPoint(x: 50, y: 200)
        for _ in 0..<200 { if host.detachedCardForChecks == nil { break }; try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertNil(host.detachedCardForChecks, "Ordinary card closes after the shared-region leave grace")
        pointer = CGPoint(x: placement.frame.midX, y: placement.frame.midY)
        // No synthetic nil event: the sampled exit must retire the stale hover itself.
        nozzle.hoverNozzle(id)
        for _ in 0..<100 { if host.detachedCardForChecks != nil { break }; try await Task.sleep(for: .milliseconds(10)) }
        let card = try XCTUnwrap(host.detachedCardForChecks)
        pointer = CGPoint(x: try XCTUnwrap(cardFrame).midX, y: try XCTUnwrap(cardFrame).midY)
        let click = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseDown, location: .init(x: 10, y: 10), modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, eventNumber: 1, clickCount: 1, pressure: 1))
        card.mouseDown(with: click)
        pointer = CGPoint(x: 50, y: 200)
        for _ in 0..<200 { if host.detachedCardForChecks == nil { break }; try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertNil(host.detachedCardForChecks, "Clicking the card body must not pin it")
        await app.stopLifecycle(); host.close()
    }

}

// G3-30 colour and G3-32 ring marks, both through the normal entry (EngineRowsEntry + settings store).
extension P1ExactPlacementTests {
    private struct Station { let id: String; let vendorKey: String; let name: String; let accounts: Int; var remaining: Double? = nil }

    private func synthetic(_ stations: [Station]) throws -> WireRowsSnapshot {
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: capture)) as? [String: Any])
        var projection = try XCTUnwrap(json["projection"] as? [String: Any])
        let template = try XCTUnwrap((projection["rows"] as? [[String: Any]])?.first)
        let account = try XCTUnwrap((template["accounts"] as? [[String: Any]])?.first)
        var serial = 0
        projection["rows"] = stations.enumerated().map { order, station -> [String: Any] in
            var row = template
            row["id"] = station.id; row["order"] = order + 1; row["vendorKey"] = station.vendorKey
            row["name"] = ["en": station.name, "zh": station.name]
            row["state"] = "fresh"; row["consent"] = "allowed"; row["surfaces"] = ["dock", "menu", "settings"]
            row["expiresAt"] = "2099-01-01T00:00:00Z"
            row["accounts"] = (0..<station.accounts).map { _ -> [String: Any] in
                serial += 1
                var copy = account
                copy["subscriptionRef"] = String(format: "%016x", serial)
                copy["valueState"] = "current"; copy["freshUntil"] = "2099-01-01T00:00:00Z"
                if let remaining = station.remaining, var windows = copy["windows"] as? [[String: Any]], !windows.isEmpty {
                    // A live reading: the capture's window is past its validity.
                    let observed = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-60))
                    windows[0]["remainingPercent"] = remaining; windows[0]["role"] = "session"; windows[0]["durationSeconds"] = 18000
                    windows[0]["limitKey"] = "five_hour"; windows[0]["poolKey"] = "main"
                    windows[0]["current"] = true; windows[0]["observedAt"] = observed
                    windows[0]["resetsAt"] = "2099-01-01T00:00:00Z"; windows[0]["validUntil"] = "2099-01-01T00:00:00Z"
                    windows[0].removeValue(forKey: "modelScope")
                    copy["windows"] = [windows[0]]; copy["route"] = "runtime_rpc"; copy["observedAt"] = observed
                }
                return copy
            }
            return row
        }
        json["projection"] = projection
        return try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: json))
    }

    private func launch(_ rows: WireRowsSnapshot, size: SettingsSize, percentages: Bool, stations: Int, tag: String) async throws -> (EngineDockMenuApplication, DockInstrumentView) {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("p1-\(tag)-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: profile) }
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en"])
        _ = try await store.update { p in
            p.showDock = true; p.autoHide = false; p.dockEdge = .right; p.size = size; p.showPercentages = percentages
            for _ in 0..<16 { p.onboarding.next() }
        }
        let screen = DockDisplayArea(id: "primary", frame: CGRect(x: 0, y: 0, width: 1440, height: 900), visibleFrame: CGRect(x: 0, y: 80, width: 1440, height: 795), backingScale: 2)
        let app = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: store, createsNativePanels: false, bundleURL: profile.appendingPathComponent("Synthetic.app"),
            dockEnvironment: { .init(displays: [screen], layouts: [], primaryDisplayID: "primary", pointer: CGPoint(x: 600, y: 450)) },
            makeClient: { _, target in P1SyntheticEngine(store: target, rows: rows) }, makeSettingsSurface: { _ in P1NoWindowSurface() }, activateSettings: {})
        protect(app)
        await app.prepare()
        app.startLifecycle(workspace: NotificationCenter(), local: NotificationCenter(), lockEvents: NotificationCenter(), displayIDs: { [1] }, onConsole: { true }, displaysAsleep: { _ in false })
        let view = app.composition.dock.dockView
        for _ in 0..<1000 {
            if !app.lifecyclePaused, (view.presentedSkinForChecks?.stations.filter { $0.subscriptionID != nil }.count ?? 0) == stations { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        return (app, view)
    }

    private func visualOutput(_ name: String) throws -> URL {
        let root = ProcessInfo.processInfo.environment["RUNNER_TEMP"].map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? FileManager.default.temporaryDirectory
        let output = root.appendingPathComponent("dock-instrument-checks/dock-visual/\(name)", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        return output
    }

    /// G3-30 colour: the face matches the prototype per depth band, within 3 levels per channel.
    /// Reference values are measured from the prototype's own captures (design-handoffs/
    /// dock-aftview-integration/shots/after-right-{4,7}-dark.png and after-right-7-light.png, 52 pt,
    /// right edge, 2x): mean sRGB over face-only rows, banded by depth from the screen edge as a
    /// fraction of the face's free depth (D + 24 x D/52; geometry.js:68,119). The prototype face is
    /// opaque, so light and dark wallpapers give the same bands (they agree within 1.5 levels).
    /// The gradient is laid out over the free depth, so the same bands apply at S and M.
    /// Before this fix the native face measured 16-20 levels brighter in every band.
    func testG330FaceColourMatchesThePrototypePerDepthBand() async throws {
        let reference: [[Double]] = [[12.8, 17.3, 24.8], [14.7, 22.9, 30.9], [20.3, 28.9, 37.0], [25.0, 34.3, 41.8]]
        let output = try visualOutput("g3-30-colour")
        let rows = try synthetic((1...4).map { Station(id: "colour\($0)", vendorKey: "claude", name: "Claude \($0)", accounts: 1) })
        var report = [String]()
        for size in SettingsSize.allCases {
            let (app, view) = try await launch(rows, size: size, percentages: false, stations: 4, tag: "g330c")
            let label = size.rawValue
            let skin = try XCTUnwrap(view.presentedSkinForChecks, label)
            let image = try XCTUnwrap(view.presentedImageForChecks, label)
            if let writer = CGImageDestinationCreateWithURL(output.appendingPathComponent("after-right-\(label)-4.png") as CFURL, "public.png" as CFString, 1, nil) {
                CGImageDestinationAddImage(writer, image, nil); CGImageDestinationFinalize(writer)
            }
            let pixels = CGFloat(image.width) / skin.bounds.width
            let rgba = try XCTUnwrap(CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue))
            rgba.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            let bytes = try XCTUnwrap(rgba.data).assumingMemoryBound(to: UInt8.self)
            let d = size.nozzleDiameter, freeDepth = d + 24 * d / 52
            let stations = skin.stations.filter { $0.subscriptionID != nil }.sorted { $0.centre.y < $1.centre.y }
            XCTAssertEqual(stations.count, 4, label)
            // Face-only rows: +-3 pt about the midpoint between neighbouring rings.
            var sampleRows = [Int]()
            for (a, b) in zip(stations, stations.dropFirst()) {
                let mid = (a.centre.y + b.centre.y) / 2
                let low = Int(((mid - 3 - skin.bounds.minY) * pixels).rounded()), high = Int(((mid + 3 - skin.bounds.minY) * pixels).rounded())
                sampleRows += Array(low...high)
            }
            var sums = Array(repeating: [0.0, 0.0, 0.0, 0.0], count: reference.count)
            for y in sampleRows where y >= 0 && y < image.height {
                for x in 0..<image.width {
                    let depth = skin.bounds.maxX - (skin.bounds.minX + (CGFloat(x) + 0.5) / pixels)
                    let band = Int((depth / freeDepth * 10).rounded(.down))
                    guard band >= 0, band < reference.count else { continue }
                    let p = (y * image.width + x) * 4
                    guard bytes[p + 3] == 255 else { continue }
                    for c in 0..<3 { sums[band][c] += Double(bytes[p + c]) }
                    sums[band][3] += 1
                }
            }
            for (band, sum) in sums.enumerated() {
                let count = try XCTUnwrap(sum[3] > 0 ? sum[3] : nil, "\(label) band \(band) sampled")
                let mean = (0..<3).map { sum[$0] / count }
                let error = (0..<3).map { abs(mean[$0] - reference[band][$0]) }
                report.append(String(format: "%@ band %d (depth %.0f-%.0f%%) native %.1f,%.1f,%.1f prototype %.1f,%.1f,%.1f max error %.1f",
                                     label, band, Double(band) * 10, Double(band + 1) * 10, mean[0], mean[1], mean[2],
                                     reference[band][0], reference[band][1], reference[band][2], error.max() ?? 0))
                XCTAssertLessThanOrEqual(error.max() ?? 99, 3, "\(label) band \(band): native \(mean) vs prototype \(reference[band])")
            }
            await app.stopLifecycle(); app.composition.dock.close()
        }
        try report.joined(separator: "\n").write(to: output.appendingPathComponent("g3-30-colour.txt"), atomically: true, encoding: .utf8)
        print(report.joined(separator: "\n"))
    }

    /// SET-9: each Quota Widget setting changes the running widget; nothing is relaunched.
    /// The red threshold drives the ring's red band, not only the number.
    func testWidgetSettingsChangeTheRunningWidget() async throws {
        let rows = try synthetic([Station(id: "live", vendorKey: "openai", name: "Codex", accounts: 1, remaining: 20)])
        let (app, view) = try await launch(rows, size: .medium, percentages: true, stations: 1, tag: "live")
        addTeardownBlock { @MainActor in await app.stopLifecycle(); app.composition.dock.close() }
        let settings = app.settingsHost.application
        func settled(_ what: String, _ predicate: () -> Bool) async throws {
            for _ in 0..<300 where !predicate() { try await Task.sleep(for: .milliseconds(10)) }
            XCTAssertTrue(predicate(), what)
        }
        func reading() throws -> DockInstrumentReading { try XCTUnwrap(view.presentedReadingsForChecks.values.first) }
        func ringRedPixels() throws -> Int {
            let image = try XCTUnwrap(view.presentedImageForChecks)
            let rgba = try XCTUnwrap(CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue))
            rgba.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            let bytes = try XCTUnwrap(rgba.data).assumingMemoryBound(to: UInt8.self)
            // Only the ring: the ignition cap is red too, and it sits outside this station's box.
            let skin = try XCTUnwrap(view.presentedSkinForChecks)
            let station = try XCTUnwrap(skin.stations.first { $0.subscriptionID != nil })
            let pixels = CGFloat(image.width) / skin.bounds.width, radius = SettingsSize.medium.nozzleDiameter / 2
            let centreX = (station.centre.x - skin.bounds.minX) * pixels, centreY = (station.centre.y - skin.bounds.minY) * pixels
            var count = 0
            for y in max(0, Int(centreY - radius * pixels))..<min(image.height, Int(centreY + radius * pixels)) {
                for x in max(0, Int(centreX - radius * pixels))..<min(image.width, Int(centreX + radius * pixels)) {
                    let p = (y * image.width + x) * 4
                    if bytes[p] > 180, bytes[p + 1] < 110, bytes[p + 2] < 110 { count += 1 }
                }
            }
            return count
        }
        // The default threshold (25) makes 20% red; 16 makes the same reading amber; back to red.
        XCTAssertEqual(try reading().status, .critical)
        XCTAssertEqual(try reading().outer?.status, .critical)
        let red = try ringRedPixels()
        if let image = view.presentedImageForChecks, let writer = CGImageDestinationCreateWithURL(try visualOutput("ring-centre").appendingPathComponent("ring-M-20.png") as CFURL, "public.png" as CFString, 1, nil) {
            CGImageDestinationAddImage(writer, image, nil); CGImageDestinationFinalize(writer)
        }
        XCTAssertGreaterThan(red, 0, "the ring paints its red band at 20% with the default threshold")
        try await settings.commit(.redBelow(16))
        try await settled("the ring leaves red") { (try? reading().outer?.status) == .warning }
        XCTAssertEqual(try reading().status, .warning)
        XCTAssertEqual(try ringRedPixels(), 0, "no red band above the committed threshold")
        try await settings.commit(.redBelow(25))
        try await settled("the ring returns to red") { (try? reading().outer?.status) == .critical }
        XCTAssertEqual(try ringRedPixels(), red)
        // Percentages leave and return with the same running view.
        XCTAssertTrue(view.presentedTextMetricsForChecks.contains { $0.text == "20%" })
        try await settings.commit(.showPercentages(false))
        try await settled("the readout disappears") { !view.presentedTextMetricsForChecks.contains { $0.text == "20%" } }
        try await settings.commit(.showPercentages(true))
        try await settled("the readout returns") { view.presentedTextMetricsForChecks.contains { $0.text == "20%" } }
    }

    /// G3-32: a ring shows the vendor's checked mark; without one, its initials fit the face.
    /// Build 7 showed "ini" (Gemini) and "k B" clipped by the ring: the whole name was drawn
    /// into the 0.27 x D glyph box.
    func testG332NoRingLabelIsClippedForAnyKnownVendor() async throws {
        let marked: Set<String> = ["openai", "claude", "cursor", "copilot", "kimi", "opencode", "deepseek", "gemini", "grok", "x", "qwen", "kiro",
            "minimax", "xiaomi", "antigravity", "amp", "droid", "zai", "zhipu"]
        XCTAssertEqual(["Gemini", "Grok", "GLM", "Z.ai", "智谱清言", "Work Bench B", "Grok · 2"].map(DockVendorFallback.mark), ["Ge", "Gr", "GL", "Za", "智谱", "Wo", "Gr"])
        let vendors: [(String, String)] = [("openai", "Codex"), ("claude", "Claude"), ("cursor", "Cursor"), ("copilot", "Copilot"),
            ("kimi", "Kimi"), ("opencode", "OpenCode"), ("gemini", "Gemini"), ("grok", "Grok"), ("qwen", "Qwen"), ("kiro", "Kiro"),
            ("minimax", "MiniMax"), ("antigravity", "Antigravity"), ("amp", "Amp"), ("zai", "Z.ai"), ("zhipu", "智谱清言"),
            ("deepseek", "DeepSeek"), ("x", "X"), ("xiaomi", "Xiaomi"), ("droid", "Droid"), ("unknown-vendor", "Work Bench B")]
        let output = try visualOutput("g3-32")
        for size in SettingsSize.allCases {
            for batch in stride(from: 0, to: vendors.count, by: 4) {
                let slice = Array(vendors[batch..<min(batch + 4, vendors.count)])
                // The last vendor of each batch has a second account, so its ring is named "<name> · 2".
                let stations = slice.enumerated().map { index, vendor in
                    Station(id: "v\(batch + index)", vendorKey: vendor.0, name: vendor.1, accounts: index == slice.count - 1 ? 2 : 1)
                }
                let expected = stations.reduce(0) { $0 + $1.accounts }
                let (app, view) = try await launch(try synthetic(stations), size: size, percentages: false, stations: expected, tag: "g332")
                let label = "\(size.rawValue) batch \(batch)"
                let skin = try XCTUnwrap(view.presentedSkinForChecks, label)
                let glyphBox = try XCTUnwrap(skin.stations.first { $0.subscriptionID != nil }?.glyphRect, label)
                let metrics = view.presentedTextMetricsForChecks
                let readings = view.presentedReadingsForChecks
                if let image = view.presentedImageForChecks, let writer = CGImageDestinationCreateWithURL(output.appendingPathComponent("rings-\(size.rawValue)-\(batch).png") as CFURL, "public.png" as CFString, 1, nil) {
                    CGImageDestinationAddImage(writer, image, nil); CGImageDestinationFinalize(writer)
                }
                XCTAssertEqual(readings.count, expected, label)
                for reading in readings.values {
                    let mark = DockVendorFallback.mark(reading.name)
                    if let key = reading.vendorResourceKey, marked.contains(key) || (view.zaiMarkEnabled && ["zai", "zhipu", "glm"].contains(key)) {
                        XCTAssertFalse(metrics.contains { $0.text == reading.name }, "\(label) \(key) shows its mark, not its name")
                        continue
                    }
                    XCTAssertLessThanOrEqual(mark.count, 2, "\(label) \(reading.name)")
                    let drawn = metrics.filter { $0.text == mark }
                    XCTAssertFalse(drawn.isEmpty, "\(label) \(reading.name): fallback \(mark) is drawn")
                    for metric in drawn {
                        XCTAssertLessThanOrEqual(CGFloat(metric.advance), glyphBox.width + 0.01, "\(label) \(reading.name): \(mark) fits the ring face width")
                        XCTAssertLessThanOrEqual(metric.ascent + metric.descent, glyphBox.height + 0.01, "\(label) \(reading.name): \(mark) fits the ring face height")
                    }
                    XCTAssertFalse(metrics.contains { $0.text == reading.name && reading.name.count > 2 }, "\(label) the full name \(reading.name) is never drawn in the ring")
                }
                await app.stopLifecycle(); app.composition.dock.close()
            }
        }
    }
}
