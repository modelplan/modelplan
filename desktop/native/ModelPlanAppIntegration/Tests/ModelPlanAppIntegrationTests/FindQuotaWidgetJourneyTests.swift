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

/// D56 (owner 2026-11-08) through the normal entry, without windows. D114 (owner 2026-11-10) then made
/// auto-collapse off by default: a fresh profile starts with the Quota Widget expanded and a saved
/// choice either way is kept. The Find journeys below start from a saved "on" (collapsed widget); Find Quota Widget from the status menu,
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
    /// The Find journeys need a collapsed widget, so the profile is saved with auto-collapse on; pass
    /// `freshDefault: true` to leave the setting untouched (D114: a new profile starts expanded).
    private func make(_ root: URL, displays: [DockDisplayArea]? = nil, firstRunDone: Bool = true,
                      freshDefault: Bool = false,
                      surface given: D56QuietSurface? = nil, registrar: D56ShortcutRegistrar? = nil,
                      edit: ((inout SettingsPreferences) -> Void)? = nil) async throws -> EngineDockMenuApplication {
        let surface = given ?? D56QuietSurface()
        let fixture = try rows()
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        if firstRunDone || edit != nil || !freshDefault {
            _ = try await store.update { p in
                if firstRunDone { for _ in 0..<16 { p.onboarding.next() } }
                if !freshDefault { p.autoHide = true }
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

    private func start(_ app: EngineDockMenuApplication, reduceMotion: Bool = false, presented: Bool = true) async throws {
        app.startLifecycle(workspace: NotificationCenter(), local: NotificationCenter(), lockEvents: NotificationCenter(),
                           displayIDs: { [1] }, onConsole: { true }, displaysAsleep: { _ in false })
        try await wait { !app.lifecyclePaused }
        var environment = SettingsEnvironment(); environment.reduceMotion = reduceMotion
        app.updateSystemAccessibility(environment)
        guard presented else { return }
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

    func testD114FreshProfileStartsExpanded() async throws {
        let app = try await make(profile(), freshDefault: true)
        let editor = app.settingsHost.application.editor
        let preferences = try XCTUnwrap(editor.snapshot).preferences
        XCTAssertTrue(preferences.showDock, "the widget is on")
        XCTAssertFalse(preferences.autoHide, "D114: auto-collapse is off for a fresh install")
        let rows = try SettingsCatalogue.rows(preferences: preferences, context: editor.context, paneID: "dock")
        XCTAssertEqual(rows.first { $0.key == .autoHide }?.value, .toggle(false), "Settings shows the switch off")
        try await start(app)
        try await wait { app.composition.dock.edgePresentation?.state == .expanded }
        try await Task.sleep(for: .seconds(1))
        XCTAssertEqual(app.composition.dock.edgePresentation?.state, .expanded, "the widget stays out after first run")
        XCTAssertTrue(app.composition.dock.menu().items.contains { $0.title == "Auto-Collapse" && $0.state == .off },
                      "the widget menu shows the same setting")
        XCTAssertEqual(app.composition.dock.currentMenuBarPreferences?.autoHide, false)
    }

    func testD114SavedAutoCollapseOnIsKeptAcrossRelaunchAndCollapses() async throws {
        let root = profile()
        let first = try await make(root) { $0.autoHide = true }
        try await start(first)
        try await wait { first.composition.dock.edgePresentation?.state == .sliver }
        await first.stopLifecycle(); first.composition.dock.close()
        let relaunched = try await make(root, firstRunDone: false, freshDefault: true)
        XCTAssertEqual(relaunched.settingsHost.application.editor.snapshot?.preferences.autoHide, true,
                       "a saved 'on' is not replaced by the new default")
        try await start(relaunched)
        try await wait { relaunched.composition.dock.edgePresentation?.state == .sliver }
    }

    /// The first manual collapse (turning Auto-Collapse on) takes the widget to its strip; the
    /// one-time "where it went" hint then follows (FirstUseHints and DockHelpBinding cover it once-only).
    func testD114ManualCollapseFoldsTheExpandedWidget() async throws {
        let app = try await make(profile(), freshDefault: true)
        try await start(app)
        try await wait { app.composition.dock.edgePresentation?.state == .expanded }
        let editor = app.settingsHost.application.editor
        try await editor.commit(SettingsB21Edit.autoHide(true))
        try await wait { app.composition.dock.edgePresentation?.state == .sliver }
        XCTAssertEqual(editor.snapshot?.preferences.autoHide, true)
    }

    func testD56SavedAutoCollapseOffIsKeptAcrossRelaunch() async throws {
        let root = profile()
        let first = try await make(root) { $0.autoHide = false }
        try await start(first)
        try await wait { first.composition.dock.edgePresentation?.state == .expanded }
        await first.stopLifecycle(); first.composition.dock.close()
        let relaunched = try await make(root, firstRunDone: false, freshDefault: true)
        XCTAssertEqual(relaunched.settingsHost.application.editor.snapshot?.preferences.autoHide, false,
                       "an existing user's saved choice is not replaced by the new default")
        try await start(relaunched)
        try await wait { relaunched.composition.dock.edgePresentation?.state == .expanded }
        try await Task.sleep(for: .seconds(1))
        XCTAssertEqual(relaunched.composition.dock.edgePresentation?.state, .expanded, "a kept 'off' never collapses")
    }

    // MARK: DOCK-3.6-20 values

    func testD56DimHoleAndFeatherMatchTheDecidedValues() throws {
        let target = QuotaWidgetSpotlightTarget(widget: CGRect(x: 1_300, y: 300, width: 64, height: 320),
                                                display: CGRect(x: 0, y: 0, width: 1_440, height: 900), displayID: "primary")
        XCTAssertEqual(QuotaWidgetSpotlightStyle.dimAlpha, 0.4)
        XCTAssertEqual(QuotaWidgetSpotlightStyle.holePadding, 8)
        XCTAssertEqual(QuotaWidgetSpotlightStyle.holeCornerRadius, 12, "fallback outline only")
        XCTAssertTrue((16...28).contains(QuotaWidgetSpotlightStyle.featherRadius), "a 16 to 28 pt falloff")
        XCTAssertEqual(QuotaWidgetSpotlightStyle.dimAlpha(atDistance: 0), 0)
        XCTAssertEqual(QuotaWidgetSpotlightStyle.dimAlpha(atDistance: -5), 0)
        XCTAssertEqual(QuotaWidgetSpotlightStyle.dimAlpha(atDistance: QuotaWidgetSpotlightStyle.featherRadius), 0.4, accuracy: 0.0001)
        XCTAssertEqual(QuotaWidgetSpotlightStyle.dimAlpha(atDistance: 500), 0.4, accuracy: 0.0001)
        var last: CGFloat = -1
        for step in 0...24 {
            let a = QuotaWidgetSpotlightStyle.dimAlpha(atDistance: CGFloat(step))
            XCTAssertGreaterThanOrEqual(a, last, "the falloff never steps back"); last = a
        }
        let hole = QuotaWidgetSpotlightStyle.hole(for: target)
        XCTAssertEqual(hole, CGRect(x: 1_292, y: 292, width: 80, height: 336), "fallback (no silhouette): 8 pt around the widget")
        // A widget at the display edge keeps its hole on that display.
        let edge = QuotaWidgetSpotlightTarget(widget: CGRect(x: 1_376, y: 300, width: 64, height: 320), display: target.display, displayID: "primary")
        XCTAssertEqual(QuotaWidgetSpotlightStyle.hole(for: edge).maxX, 1_440)

        let view = QuotaWidgetSpotlightView(frame: CGRect(origin: .zero, size: target.display.size))
        view.hole = hole
        let drawn = view.drawnForChecks
        XCTAssertEqual(drawn.dimAlpha, 0.4, accuracy: 0.001)
        XCTAssertFalse(drawn.dimContainsHoleCentre, "the hole is undimmed")
        XCTAssertTrue(drawn.dimContainsCorner, "the rest of the display is dimmed")
        XCTAssertFalse(drawn.hasStrokeOrBorder, "no ring, frame or stroke of any colour")
        XCTAssertFalse(drawn.hasShadow, "no glow layer either")
        XCTAssertTrue(drawn.featherHasImage, "the edge is a soft gradient")
        let inner = try? XCTUnwrap(drawn.alphaAt(CGPoint(x: hole.minX - 1, y: hole.midY)))
        let mid = try? XCTUnwrap(drawn.alphaAt(CGPoint(x: hole.minX - 12, y: hole.midY)))
        let far = try? XCTUnwrap(drawn.alphaAt(CGPoint(x: hole.minX - 23, y: hole.midY)))
        XCTAssertLessThan(inner ?? 1, 0.05, "almost clear right at the hole's edge")
        XCTAssertGreaterThan(mid ?? 0, 0.1); XCTAssertLessThan(mid ?? 1, 0.3)
        XCTAssertGreaterThan(far ?? 0, 0.37, "reaches the dim level at the end of the feather")
        XCTAssertEqual(drawn.alphaAt(CGPoint(x: hole.midX, y: hole.midY)) ?? 1, 0, accuracy: 0.01, "the hole is clear")
    }

    /// Owner 2026-11-10: the clearing follows the widget's real drawn silhouette, not a rounded rectangle.
    func testD56HoleFollowsTheWidgetsDrawnSilhouette() throws {
        let display = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        // A stand-in widget: a fully rounded capsule (64 x 320) with a 12 pt ring bump on its left side near the top.
        let frame = CGRect(x: 1_288, y: 300, width: 76, height: 320)
        let body = CGRect(x: 1_300, y: 300, width: 64, height: 320)
        let capsuleRadius: CGFloat = 32
        // Asymmetric top to bottom on purpose: the bump sits 60 pt below the top, so a flipped row mapping fails.
        let bump = CGPoint(x: body.minX, y: body.maxY - 60), bumpRadius: CGFloat = 12
        func painted(_ p: CGPoint) -> Bool {
            let inner = body.insetBy(dx: capsuleRadius, dy: capsuleRadius)
            let nearest = CGPoint(x: min(max(p.x, inner.minX), inner.maxX), y: min(max(p.y, inner.minY), inner.maxY))
            return hypot(p.x - nearest.x, p.y - nearest.y) <= capsuleRadius || hypot(p.x - bump.x, p.y - bump.y) <= bumpRadius
        }
        let silhouette = try XCTUnwrap(QuotaWidgetSilhouette(frame: frame, step: 0.5, covered: painted))
        let target = QuotaWidgetSpotlightTarget(widget: frame, display: display, displayID: "primary", silhouette: silhouette)
        XCTAssertEqual(QuotaWidgetSpotlightStyle.hole(for: target), frame)

        let view = QuotaWidgetSpotlightView(frame: CGRect(origin: .zero, size: display.size))
        view.silhouette = silhouette
        view.hole = QuotaWidgetSpotlightStyle.hole(for: target)
        let drawn = view.drawnForChecks
        XCTAssertFalse(drawn.hasStrokeOrBorder, "no ring, frame or stroke"); XCTAssertFalse(drawn.hasShadow)
        XCTAssertEqual(drawn.dimAlpha, 0.4, accuracy: 0.001)
        func alpha(_ x: CGFloat, _ y: CGFloat) throws -> CGFloat { try XCTUnwrap(drawn.alphaAt(CGPoint(x: x, y: y)), "inside the drawn image at \(x),\(y)") }

        // On the widget: clear. The body, the bump and the middle of the rounded end.
        XCTAssertEqual(try alpha(body.midX, body.midY), 0, accuracy: 0.01)
        XCTAssertEqual(try alpha(body.minX - 6, bump.y), 0, accuracy: 0.01, "on the ring bump")
        XCTAssertGreaterThan(try alpha(body.minX - 6, body.minY + 60), 0.04, "the same spot mirrored to the bottom has no bump, so it is dimmed")
        XCTAssertEqual(try alpha(body.midX, body.maxY - 2), 0, accuracy: 0.01, "on the rounded end")
        // Just outside the rounded end, at the corner the old rectangle (8 pt padded) cleared: now dimmed (about 9 pt from the edge).
        let corner = try alpha(body.minX + 3, body.maxY - 3)
        XCTAssertGreaterThan(corner, 0.08, "the corner beyond the rounded end is no longer cleared")
        XCTAssertGreaterThan(try alpha(body.maxX - 3, body.minY + 3), 0.08, "same at the bottom corner")
        // Beside the bump, above it: 10 pt from the nearest painted edge; the old rectangle (bump included, padded) cleared it.
        let besideBump = try alpha(body.minX - 10, bump.y - 30)
        XCTAssertGreaterThan(besideBump, 0.12, "beside the ring bump the dim has already started")
        // Right at the edge the dim is almost none.
        XCTAssertLessThan(try alpha(body.maxX + 1, body.midY), 0.05)
        // Monotonic falloff away from the edge: straight out of the body, out of the bump and out of the end.
        for (name, point) in [("body", { (d: CGFloat) in CGPoint(x: body.maxX + d, y: body.midY) }),
                              ("bump", { d in CGPoint(x: body.minX - bumpRadius - d, y: bump.y) }),
                              ("end", { d in CGPoint(x: body.midX, y: body.maxY + d) })] {
            var last: CGFloat = -1
            for d in stride(from: CGFloat(0.5), through: 24, by: 0.5) {
                let p = point(d)
                let a = try alpha(p.x, p.y)
                XCTAssertGreaterThanOrEqual(a, last - 0.004, "\(name): the falloff never steps back at \(d) pt"); last = a
            }
            XCTAssertGreaterThan(last, 0.37, "\(name): reaches the dim level 24 pt out")
        }
    }


    /// The silhouette sampler: nothing painted and everything painted both mean "no outline to follow" (nil, so the
    /// overlay uses the padded rounded rectangle); lookups clamp at the frame's edges and survive a move.
    func testD56SilhouetteSamplerHandlesEmptyFullAndEdges() throws {
        let frame = CGRect(x: 100, y: 200, width: 20, height: 40)
        XCTAssertNil(QuotaWidgetSilhouette(frame: frame, covered: { _ in false }), "nothing painted")
        XCTAssertNil(QuotaWidgetSilhouette(frame: frame, covered: { _ in true }), "everything painted (community mode)")
        XCTAssertNil(QuotaWidgetSilhouette(frame: .zero, covered: { _ in true }))
        // Only the upper half is painted.
        let upper = try XCTUnwrap(QuotaWidgetSilhouette(frame: frame, covered: { $0.y > frame.midY }))
        XCTAssertTrue(upper.contains(CGPoint(x: frame.minX, y: frame.maxY - 0.01)), "top-left corner of the frame")
        XCTAssertTrue(upper.contains(CGPoint(x: frame.maxX - 0.01, y: frame.maxY - 0.01)))
        XCTAssertFalse(upper.contains(CGPoint(x: frame.minX, y: frame.minY)), "bottom edge is not painted")
        XCTAssertFalse(upper.contains(CGPoint(x: frame.maxX + 1, y: frame.maxY)), "outside the frame")
        let moved = upper.offsetBy(dx: 1_000, dy: -50)
        XCTAssertTrue(moved.contains(CGPoint(x: frame.minX + 1_000, y: frame.maxY - 50.01)))
        XCTAssertFalse(moved.contains(CGPoint(x: frame.minX, y: frame.maxY - 0.01)), "the old place is outside the moved frame")
    }

    /// A pixel-less (nil silhouette) target keeps the old padded rounded rectangle; no covered pixel never dims the whole display.
    func testD56NoSilhouetteAndNoCoveredPixelFallBackToThePaddedRoundedRectangle() throws {
        let display = CGRect(x: 0, y: 0, width: 400, height: 300)
        let widget = CGRect(x: 300, y: 100, width: 64, height: 120)
        let target = QuotaWidgetSpotlightTarget(widget: widget, display: display, displayID: "primary")
        XCTAssertEqual(QuotaWidgetSpotlightStyle.hole(for: target), widget.insetBy(dx: -8, dy: -8))
        XCTAssertNil(QuotaWidgetSpotlightView.signedDistances(width: 8, height: 8, region: widget, scale: 1, inside: { _ in false }), "no covered pixel: no distance field")
        let view = QuotaWidgetSpotlightView(frame: CGRect(origin: .zero, size: display.size))
        view.setGeometry(frame: CGRect(origin: .zero, size: display.size), hole: QuotaWidgetSpotlightStyle.hole(for: target), silhouette: nil)
        let drawn = view.drawnForChecks
        XCTAssertEqual(drawn.alphaAt(CGPoint(x: widget.midX, y: widget.midY)) ?? 1, 0, accuracy: 0.01, "the hole is clear")
        XCTAssertGreaterThan(try XCTUnwrap(drawn.alphaAt(CGPoint(x: widget.minX - 20, y: widget.midY))), 0.2, "dimmed beyond the padded edge")
    }

    /// The host: the polled target is frame and display only; the silhouette is built once, for the presented target, and
    /// maps screen points to the widget's own pixels (attached branch needs native panels; this is the detached branch).
    func testD56HostTargetIsCheapAndSilhouetteIsBuiltOnceForThePresentedTarget() async throws {
        let app = try await make(profile(), freshDefault: true)
        try await start(app)
        let dock = app.composition.dock
        try await wait { dock.edgePresentation?.state == .expanded }
        let target = try XCTUnwrap(dock.spotlightTarget)
        XCTAssertNil(target.silhouette, "the polled target never carries a silhouette")
        XCTAssertEqual(target.displayID, "primary")
        // Detached views may not be rasterised; the builder then falls back (nil) rather than guessing.
        guard let silhouette = dock.spotlightSilhouette(for: target) else {
            XCTAssertEqual(QuotaWidgetSpotlightStyle.hole(for: target), target.widget.insetBy(dx: -8, dy: -8).intersection(target.display), "nil silhouette: padded fallback")
            return
        }
        XCTAssertEqual(silhouette.frame, target.widget)
        XCTAssertTrue(silhouette.contains(CGPoint(x: target.widget.midX, y: target.widget.midY)), "the widget's centre is painted")
        XCTAssertEqual(dock.spotlightSilhouette(for: target)?.id, silhouette.id, "the same geometry reuses the sample")
        let farAway = QuotaWidgetSpotlightTarget(widget: target.widget.offsetBy(dx: -500, dy: 0), display: target.display, displayID: target.displayID)
        XCTAssertNotEqual(dock.spotlightSilhouette(for: farAway)?.id, silhouette.id, "another geometry is sampled again")
    }

    /// The runner polls `target` cheaply and asks for the silhouette once, for the target it presents.
    func testD56RunnerBuildsTheSilhouetteOnceNotOnEveryPoll() async throws {
        let surface = DetachedQuotaWidgetSpotlightSurface(), input = DetachedQuotaWidgetSpotlightInput()
        let spotlight = QuotaWidgetSpotlight(makeSurface: { surface }, makeInput: { input })
        spotlight.timing.hold = 0.35; spotlight.timing.tick = 0.05; spotlight.timing.fadeIn = 0
        let target = QuotaWidgetSpotlightTarget(widget: CGRect(x: 300, y: 100, width: 64, height: 120),
                                                display: CGRect(x: 0, y: 0, width: 400, height: 300), displayID: "primary")
        var polls = 0, builds = 0
        let silhouette = QuotaWidgetSilhouette(frame: target.widget, covered: { $0.x < target.widget.midX })
        spotlight.run(reduceMotion: { true }, prepare: { true }, target: { polls += 1; return target },
                      silhouette: { _ in builds += 1; return silhouette })
        let end = ContinuousClock.now + .seconds(4)
        while spotlight.isActive && ContinuousClock.now < end { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(spotlight.lastEnd, .timeout)
        XCTAssertGreaterThan(polls, 3, "the hold keeps polling")
        XCTAssertEqual(builds, 1, "the silhouette is built once, not per poll")
        XCTAssertEqual(spotlight.lastTarget?.silhouette?.id, silhouette?.id, "the presented target carries it")
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
        XCTAssertTrue(painted.insetBy(dx: -0.5, dy: -0.5).contains(target.widget), "the clearing follows the widget")
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
        try await start(app, presented: false)
        try await wait { app.composition.dock.edgePresentation?.state == .suppressed(.userHidden) }
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
