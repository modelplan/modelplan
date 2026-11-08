// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanDock
import ModelPlanSettings
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanWire
@testable import ModelPlanAppIntegration

private actor D56SyntheticEngine: EngineClient {
    nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool { true }
    let store: EngineStore, rows: WireRowsSnapshot
    let context = EngineDeliveryContext(sessionID: "d56-synthetic", floor: .init(storeEpoch: "d56-synthetic", generation: 1), revision: 1)
    init(store: EngineStore, rows: WireRowsSnapshot) { self.store = store; self.rows = rows }
    func start() async throws -> EngineDeliveryContext {
        await store.consume(.connection(.ready(context))); await store.consume(.context(context))
        return context
    }
    func retry() async throws -> EngineDeliveryContext { try await start() }
    func stop() async {}
    func subscribeRows(timeout: Duration?) async throws -> EngineRequestCompletion {
        await store.consume(.rowsChanged(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch, consentGeneration: 1, data: rows), delivery: context), invalidRowCount: 0))
        return .init(requestID: .string("d56-rows"))
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

@MainActor private final class D56QuietSurface: SettingsWindowSurface {
    private(set) var shows = 0
    func prepare() async {}
    func show(paneID: String?) { shows += 1 }
    func hide() {}
}

@MainActor private final class D56ShortcutRegistrar: EngineShortcutRegistering {
    var onPress: ((ShortcutAction) -> Void)?
    private(set) var registered: [ShortcutAction: ShortcutChord] = [:]
    func register(_ chord: ShortcutChord, action: ShortcutAction) -> ShortcutRegistration { registered[action] = chord; return .registered }
    func unregisterAll() { registered = [:] }
}

/// D56 (owner 2026-11-08) through the normal entry, without windows: a fresh profile starts with
/// the Quota Widget collapsed and a saved choice is kept; Find Quota Widget from the status menu,
/// the shortcut and the end of first run slides the widget out, dims only the widget's display,
/// ends on any click or key, honours Reduce Motion, and lets the widget collapse again afterwards.
/// The native overlay window itself is checked in FindQuotaWidgetWindowTests (GUI leg).
@MainActor final class FindQuotaWidgetJourneyTests: XCTestCase {
    private let primary = DockDisplayArea(id: "primary", frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
                                          visibleFrame: CGRect(x: 0, y: 80, width: 1440, height: 795))
    private let second = DockDisplayArea(id: "second", frame: CGRect(x: 1440, y: 0, width: 1920, height: 1080),
                                         visibleFrame: CGRect(x: 1440, y: 0, width: 1920, height: 1055))

    private func profile() -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("d56-find-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root
    }

    private func rows() throws -> WireRowsSnapshot {
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        return try WireDecoder.decode(WireRowsSnapshot.self, from: Data(contentsOf: capture))
    }

    /// `firstRunDone` skips first run, as a returning user. The pointer rests away from every edge.
    private func make(_ root: URL, displays: [DockDisplayArea]? = nil, firstRunDone: Bool = true,
                      surface: D56QuietSurface = D56QuietSurface(), registrar: D56ShortcutRegistrar? = nil,
                      edit: ((inout SettingsPreferences) -> Void)? = nil) async throws -> EngineDockMenuApplication {
        let fixture = try rows()
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        if firstRunDone || edit != nil {
            _ = try await store.update { p in
                if firstRunDone { for _ in 0..<16 { p.onboarding.next() } }
                edit?(&p)
            }
        }
        let screens = displays ?? [primary]
        let app = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic",
                                                            allowedEnvironment: [:], offline: true, readOnly: true),
            settingsStore: store, createsNativePanels: false, bundleURL: root.appendingPathComponent("Synthetic.app"),
            dockEnvironment: { .init(displays: screens, layouts: [], primaryDisplayID: "primary", pointer: CGPoint(x: 600, y: 450)) },
            makeClient: { _, store in D56SyntheticEngine(store: store, rows: fixture) },
            makeSettingsSurface: { _ in surface }, activateSettings: {})
        app.makeFirstRunSurface = { _ in surface }
        app.makeFirstRunSurfaceWithConsent = { _, _ in surface }
        if let registrar { app.shortcutRegistrar = registrar }
        // Short hold keeps the journey quick; the fade durations stay the shipped ones.
        app.spotlight.timing.hold = 0.5
        addTeardownBlock { @MainActor in await app.stopLifecycle(); app.composition.dock.close() }
        await app.prepare()
        return app
    }

    private func start(_ app: EngineDockMenuApplication, reduceMotion: Bool = false) async throws {
        app.startLifecycle(workspace: NotificationCenter(), local: NotificationCenter(), lockEvents: NotificationCenter(),
                           displayIDs: { [1] }, onConsole: { true }, displaysAsleep: { _ in false })
        try await wait { !app.lifecyclePaused }
        var environment = SettingsEnvironment(); environment.reduceMotion = reduceMotion
        app.updateSystemAccessibility(environment)
        try await wait { app.composition.dock.edgePresentation?.paintedFrame != nil }
    }

    private func wait(seconds: Double = 4, file: StaticString = #filePath, line: UInt = #line,
                      _ predicate: @escaping @MainActor () -> Bool) async throws {
        let end = ContinuousClock.now + .seconds(seconds)
        while !predicate() && ContinuousClock.now < end { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertTrue(predicate(), "Expected state did not arrive within \(seconds) s", file: file, line: line)
    }

    private func chooseFind(_ app: EngineDockMenuApplication, title: String = "Find Quota Widget") async throws {
        try await wait { app.liveStatusMenu?.items.first { $0.title == title }?.isEnabled == true }
        let item = try XCTUnwrap(app.liveStatusMenu?.items.first { $0.title == title }, "The status menu must offer \(title)")
        XCTAssertEqual(item.keyEquivalent, "", "No shortcut hint on the item")
        _ = try XCTUnwrap(item.target as? NSObject).perform(try XCTUnwrap(item.action), with: item)
    }

    private func surface(_ app: EngineDockMenuApplication) throws -> DetachedQuotaWidgetSpotlightSurface {
        try XCTUnwrap(app.spotlight.surfaceForChecks as? DetachedQuotaWidgetSpotlightSurface)
    }

    // MARK: Default

    func testD56FreshProfileStartsCollapsed() async throws {
        let app = try await make(profile())
        let editor = app.settingsHost.application.editor
        let preferences = try XCTUnwrap(editor.snapshot).preferences
        XCTAssertTrue(preferences.showDock, "the widget is on")
        XCTAssertTrue(preferences.autoHide, "D56: auto-collapse is on for a fresh install")
        let rows = try SettingsCatalogue.rows(preferences: preferences, context: editor.context, paneID: "dock")
        XCTAssertEqual(rows.first { $0.key == .autoHide }?.value, .toggle(true), "Settings shows the switch on")
        try await start(app)
        try await wait { app.composition.dock.edgePresentation?.state == .sliver }
        XCTAssertTrue(app.composition.dock.menu().items.contains { $0.title == "Auto-Collapse" && $0.state == .on },
                      "the widget menu shows the same setting")
        XCTAssertEqual(app.composition.dock.currentMenuBarPreferences?.autoHide, true)
    }

    func testD56SavedAutoCollapseOffIsKeptAcrossRelaunch() async throws {
        let root = profile()
        let first = try await make(root) { $0.autoHide = false }
        try await start(first)
        try await wait { first.composition.dock.edgePresentation?.state == .expanded }
        await first.stopLifecycle(); first.composition.dock.close()
        let relaunched = try await make(root, firstRunDone: false)
        XCTAssertEqual(relaunched.settingsHost.application.editor.snapshot?.preferences.autoHide, false,
                       "an existing user's saved choice is not replaced by the new default")
        try await start(relaunched)
        try await wait { relaunched.composition.dock.edgePresentation?.state == .expanded }
        try await Task.sleep(for: .seconds(1))
        XCTAssertEqual(relaunched.composition.dock.edgePresentation?.state, .expanded, "a kept 'off' never collapses")
    }

    // MARK: Find Quota Widget

    func testD56StatusMenuFindsTheCollapsedWidgetThenItCollapsesAgain() async throws {
        let app = try await make(profile())
        try await start(app)
        let dock = app.composition.dock
        try await wait { dock.edgePresentation?.state == .sliver }
        let menu = try XCTUnwrap(app.liveStatusMenu).items.filter { !$0.isSeparatorItem }.map(\.title)
        let show = try XCTUnwrap(menu.firstIndex(of: "Show Quota Widget"))
        XCTAssertEqual(menu[show + 1], "Find Quota Widget", "Find sits right after the Show switch")
        XCTAssertFalse(dock.menu().items.contains { $0.title == "Find Quota Widget" }, "MENU-11: the widget menu is unchanged")
        try await chooseFind(app)
        try await wait { app.spotlight.phase == .shown }
        XCTAssertEqual(dock.edgePresentation?.state, .expanded, "the collapsed widget slides out")
        XCTAssertTrue(dock.spotlightHold)
        let target = try XCTUnwrap(try surface(app).shown)
        XCTAssertEqual(target.displayID, "primary"); XCTAssertEqual(target.display, primary.frame, "the whole display, menu bar included")
        let painted = try XCTUnwrap(dock.edgePresentation?.paintedFrame)
        XCTAssertTrue(painted.insetBy(dx: -0.5, dy: -0.5).contains(target.widget), "the ring follows the widget")
        XCTAssertTrue(target.display.contains(QuotaWidgetSpotlightStyle.hole(for: target)))
        XCTAssertEqual(app.spotlight.lastFadeIn, 0.2, "dims within 0.2 s")
        XCTAssertEqual(app.settingsHost.application.editor.snapshot?.preferences.showDock, true, "Find never turns the widget off")
        // It holds, then fades, and the normal auto-collapse rules apply again.
        try await wait { app.spotlight.phase == .idle }
        XCTAssertEqual(app.spotlight.lastEnd, .timeout); XCTAssertEqual(app.spotlight.lastFadeOut, 0.3)
        XCTAssertNil(try surface(app).shown); XCTAssertFalse(dock.spotlightHold)
        try await wait { dock.edgePresentation?.state == .sliver }
        XCTAssertEqual(app.settingsHost.application.editor.snapshot?.preferences.autoHide, true, "Find never changes Auto-Collapse")
        XCTAssertEqual(app.spotlight.shownCount, 1)
    }

    func testD56ShortcutFindsTheWidgetAndAnyInputEndsItAtOnce() async throws {
        let registrar = D56ShortcutRegistrar()
        let app = try await make(profile(), registrar: registrar)
        try await start(app)
        let editor = app.settingsHost.application.editor
        let chord = ShortcutChord("K", modifiers: [.command, .option])
        try await editor.commit(SettingsB21Edit.shortcut(.toggleDock, chord))
        XCTAssertEqual(registrar.registered[.toggleDock], chord)
        registrar.onPress?(.toggleDock)
        try await wait { app.spotlight.phase == .shown }
        XCTAssertEqual(app.composition.dock.edgePresentation?.state, .expanded)
        XCTAssertEqual(editor.snapshot?.preferences.showDock, true, "the shortcut finds the widget; it does not hide it")
        let input = try XCTUnwrap(app.spotlight.inputForChecks as? DetachedQuotaWidgetSpotlightInput)
        XCTAssertTrue(input.listening)
        input.send()
        XCTAssertEqual(app.spotlight.phase, .idle, "a click or key ends it at once")
        XCTAssertEqual(app.spotlight.lastEnd, .input); XCTAssertEqual(app.spotlight.lastFadeOut, 0, "no fade after input")
        XCTAssertFalse(input.listening)
        try await wait { app.composition.dock.edgePresentation?.state == .sliver }
    }

    func testD56FindTurnsAHiddenWidgetOn() async throws {
        let app = try await make(profile()) { $0.showDock = false }
        try await start(app)
        XCTAssertEqual(app.composition.dock.edgePresentation?.state, .suppressed(.userHidden))
        try await chooseFind(app)
        try await wait { app.spotlight.phase == .shown }
        XCTAssertEqual(app.settingsHost.application.editor.snapshot?.preferences.showDock, true)
        XCTAssertEqual(app.composition.dock.edgePresentation?.state, .expanded)
        XCTAssertEqual(app.liveStatusMenu?.items.first { $0.title == "Show Quota Widget" }?.state, .on)
    }

    func testD56ReduceMotionDimsAndRestoresWithoutFades() async throws {
        let app = try await make(profile())
        try await start(app, reduceMotion: true)
        XCTAssertTrue(try XCTUnwrap(app.composition.latestSettings).effective.reduceMotion)
        try await chooseFind(app)
        try await wait { app.spotlight.phase == .shown }
        XCTAssertEqual(app.spotlight.lastFadeIn, 0, "Reduce Motion: no fade in")
        try await wait { app.spotlight.phase == .idle }
        XCTAssertEqual(app.spotlight.lastEnd, .timeout)
        XCTAssertEqual(app.spotlight.lastFadeOut, 0, "Reduce Motion: restore without a fade")
        XCTAssertEqual(try surface(app).fadeIns, [0]); XCTAssertEqual(try surface(app).fadeOuts, [0])
    }

    func testD56SpotlightDimsOnlyTheWidgetsDisplay() async throws {
        let app = try await make(profile(), displays: [primary, second]) { $0.dockDisplayID = "second"; $0.dockEdge = .right }
        try await start(app)
        try await wait { app.composition.dock.edgePresentation?.placement?.displayID == "second" }
        try await chooseFind(app)
        try await wait { app.spotlight.phase == .shown }
        let target = try XCTUnwrap(try surface(app).shown)
        XCTAssertEqual(target.displayID, "second")
        XCTAssertEqual(target.display, second.frame, "only the widget's display dims")
        XCTAssertTrue(second.frame.contains(target.widget))
        XCTAssertFalse(primary.frame.intersects(target.display.insetBy(dx: 1, dy: 1)))
    }

    func testD56TurningTheWidgetOffEndsTheSpotlight() async throws {
        let app = try await make(profile())
        app.spotlight.timing.hold = 3
        try await start(app)
        try await chooseFind(app)
        try await wait { app.spotlight.phase == .shown }
        try await chooseShowQuotaWidget(app, checked: true)
        try await wait { app.spotlight.phase == .idle }
        XCTAssertEqual(app.spotlight.lastEnd, .withdrawn, "never dims around a widget that is gone")
    }

    // MARK: End of first run

    func testD56EndOfFirstRunFindsTheWidgetOnce() async throws {
        let root = profile(), surface = D56QuietSurface()
        let app = try await make(root, firstRunDone: false, surface: surface)
        try await start(app)
        try await wait { surface.shows > 0 }
        XCTAssertEqual(app.spotlight.shownCount, 0, "no spotlight before first run ends")
        let editor = app.settingsHost.application.editor
        let fresh = try XCTUnwrap(editor.snapshot)
        _ = try await editor.completeFirstRun(options: .init(preferences: fresh.preferences), action: .done,
                                              host: .popup, expectedRevision: fresh.revision)
        try await wait { app.spotlight.phase == .shown }
        XCTAssertEqual(app.composition.dock.edgePresentation?.state, .expanded, "shows where the collapsed widget is")
        XCTAssertTrue(app.composition.dock.spotlightHold, "the first hint waits until the spotlight has ended")
        try await wait { app.spotlight.phase == .idle }
        XCTAssertEqual(app.spotlight.shownCount, 1)
        try await wait { app.composition.dock.edgePresentation?.state == .sliver }
        await app.stopLifecycle(); app.composition.dock.close()
        let relaunched = try await make(root, firstRunDone: false)
        try await start(relaunched)
        try await Task.sleep(for: .seconds(1))
        XCTAssertEqual(relaunched.spotlight.shownCount, 0, "only once: not on a later launch")
    }
}
