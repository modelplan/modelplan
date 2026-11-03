// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanDock
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
        let preview = try XCTUnwrap(host.edgePresentation?.snapPreview)
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
        let preview = try XCTUnwrap(host.edgePresentation?.snapPreview)
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
    func testDisabledIgnitionVeilIsShapeLimitedOnNormalEntry() async throws {
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
        let veil = try XCTUnwrap(container.subviews.first { view in view !== button && view.frame == button.frame && view.layer?.backgroundColor != nil })
        let layer = try XCTUnwrap(veil.layer)
        XCTAssertFalse(button.isEnabled, "The disabled cockpit must stay disabled")
        XCTAssertTrue(layer.masksToBounds, "The dimming must be clipped rather than paint a square")
        XCTAssertEqual(layer.cornerRadius, min(veil.bounds.width, veil.bounds.height) / 2, accuracy: 0.01)
        await app.stopLifecycle(); app.composition.dock.close()
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
        let showDock = try XCTUnwrap(entry.liveStatusMenu?.items.first { $0.title == "Show Quota Widget" }, "The status menu must offer the locating action")
        XCTAssertTrue(showDock.isEnabled)
        XCTAssertTrue(entry.composition.dock.menu().items.contains { $0.title == "Hide Quota Widget" })
        let editor = entry.settingsHost.application.editor
        _ = try await editor.commit(SettingsB21Edit.autoHide(true))
        for _ in 0..<300 { if entry.composition.dock.edgePresentation?.state == .sliver { break }; try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(entry.composition.dock.edgePresentation?.state, .sliver, "Auto-hide is an explicit saved option")
        var accessibility = SettingsEnvironment(); accessibility.reduceMotion = false
        entry.updateSystemAccessibility(accessibility)
        XCTAssertFalse(try XCTUnwrap(entry.composition.latestSettings).effective.reduceMotion)
        let reveal = try XCTUnwrap(entry.liveStatusMenu?.items.first { $0.title == "Show Quota Widget" })
        _ = (try XCTUnwrap(reveal.target as? NSObject)).perform(try XCTUnwrap(reveal.action), with: reveal)
        for _ in 0..<300 { if entry.composition.dock.dockView.layer?.sublayers?.contains(where: { $0.name == "dock.locate-highlight" }) == true { break }; try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(entry.composition.dock.edgePresentation?.state, .expanded)
        let animated = try XCTUnwrap(entry.composition.dock.dockView.layer?.sublayers?.first { $0.name == "dock.locate-highlight" })
        XCTAssertTrue(animated.animationKeys()?.contains("locate-pulse") == true)
        accessibility.reduceMotion = true; entry.updateSystemAccessibility(accessibility)
        XCTAssertFalse(animated.animationKeys()?.contains("locate-pulse") == true)
        let staticReveal = try XCTUnwrap(entry.liveStatusMenu?.items.first { $0.title == "Show Quota Widget" })
        _ = (try XCTUnwrap(staticReveal.target as? NSObject)).perform(try XCTUnwrap(staticReveal.action), with: staticReveal)
        for _ in 0..<300 { if entry.composition.dock.dockView.layer?.sublayers?.first(where: { $0.name == "dock.locate-highlight" }) !== animated { break }; try await Task.sleep(for: .milliseconds(10)) }
        let still = try XCTUnwrap(entry.composition.dock.dockView.layer?.sublayers?.first { $0.name == "dock.locate-highlight" })
        XCTAssertTrue(still.animationKeys()?.isEmpty ?? true, "Reduce Motion uses a static highlight")
        for _ in 0..<400 {
            if entry.composition.dock.dockView.layer?.sublayers?.contains(where: { $0.name == "dock.locate-highlight" }) != true { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertFalse(entry.composition.dock.dockView.layer?.sublayers?.contains(where: { $0.name == "dock.locate-highlight" }) == true, "Locating highlight must expire")
        let afterReveal = await store.snapshot().preferences
        XCTAssertTrue(afterReveal.autoHide); XCTAssertEqual(afterReveal.dockEdge, .right); XCTAssertNil(afterReveal.dockDisplayID)
        _ = try await editor.commit(SettingsB21Edit.showDock(false))
        XCTAssertEqual(entry.composition.dock.edgePresentation?.state, .suppressed(.userHidden))
        let enable = try XCTUnwrap(entry.liveStatusMenu?.items.first { $0.title == "Show Quota Widget" })
        _ = (try XCTUnwrap(enable.target as? NSObject)).perform(try XCTUnwrap(enable.action), with: enable)
        for _ in 0..<300 { if entry.composition.dock.currentMenuBarPreferences?.showDock == true && entry.composition.dock.edgePresentation?.state == .expanded { break }; try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertTrue(try XCTUnwrap(entry.composition.dock.currentMenuBarPreferences).showDock)
        XCTAssertEqual(entry.composition.dock.edgePresentation?.state, .expanded)
        _ = try await editor.commit(SettingsB21Edit.language(.chinese))
        XCTAssertNotNil(entry.liveStatusMenu?.items.first { $0.title == "显示额度挂件" && $0.isEnabled })
        XCTAssertTrue(entry.composition.dock.menu().items.contains { $0.title == "隐藏额度挂件" })
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
    func testNormalEntryCardLeavesAndCardBodyExplicitlyPins() async throws {
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
        host.dockView.onAction?(.subscription(id))
        XCTAssertNotNil(host.detachedCardForChecks); XCTAssertFalse(host.cardPinsDock)
        cardFrame = CGRect(x: placement.frame.minX - 320, y: placement.frame.midY - 90, width: 300, height: 180)
        pointer = CGPoint(x: try XCTUnwrap(cardFrame).midX, y: try XCTUnwrap(cardFrame).midY)
        try await Task.sleep(for: .milliseconds(500))
        XCTAssertNotNil(host.detachedCardForChecks, "Card remains open while pointer is over it")
        pointer = CGPoint(x: 50, y: 200)
        for _ in 0..<200 { if host.detachedCardForChecks == nil { break }; try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertNil(host.detachedCardForChecks, "Ordinary card closes after the shared-region leave grace")
        pointer = CGPoint(x: placement.frame.midX, y: placement.frame.midY)
        host.dockView.onAction?(.subscription(id))
        let card = try XCTUnwrap(host.detachedCardForChecks)
        XCTAssertTrue(card.accessibilityPerformPress()); XCTAssertTrue(host.cardPinsDock)
        pointer = CGPoint(x: 50, y: 200); try await Task.sleep(for: .milliseconds(600))
        XCTAssertNotNil(host.detachedCardForChecks, "An explicitly pinned card remains open")
        card.onDismiss?(); XCTAssertNil(host.detachedCardForChecks)
        await app.stopLifecycle(); host.close()
    }

}
