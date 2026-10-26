// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanCore
import ModelPlanAssembly
import ModelPlanInstruments
import ModelPlanSettings
@testable import ModelPlanAppIntegration

@MainActor private final class ContextScheduler: HintDeadlineScheduling {
    var arms = 0
    func arm(at: Double, _ action: @escaping @MainActor () -> Void) { arms += 1 }
    func cancel() {}
}
@MainActor final class CommunityContextHelpTests: XCTestCase {
    private func setup() async throws -> (CommunityInstrumentSurfaceProvider, CommunityInstrumentView, InstrumentHelpComposition, ContextScheduler) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("context-help-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let provider = CommunityInstrumentSurfaceProvider()
        let app = SettingsApplicationCoordinator(store: try SettingsStore(url: directory.appendingPathComponent("prefs.json"))) { provider.apply($0) }
        let scheduler = ContextScheduler()
        let help = await InstrumentHelpComposition.restored(application: app, scheduler: scheduler, uptime: { 0 })
        provider.bindHelp(help)
        let surface = try XCTUnwrap(provider.makeOverview() as? CommunityInstrumentView)
        let wire: [String: Any] = ["schemaVersion": 1, "publicationId": "p", "selectionRevision": "r",
            "units": ["ability": "websiteAbility", "cost": "usdPerReferenceTask", "time": "taskTimeCrossModel"],
            "models": [["id": "model", "name": "Model", "developerId": "dev", "lineageId": "line", "lineageStatus": "current", "defaultSelected": true]], "lineups": []]
        var assembly = SelectionAssembly()
        surface.render(selection: assembly.evaluate(feeds: .init(publication: try FeedDecoder.publication(JSONSerialization.data(withJSONObject: wire)), personal: nil, personalUsable: false), scope: .all, now: Date()), publishedAt: nil, now: Date())
        surface.resumePresentation()
        return (provider, surface, help, scheduler)
    }
    private func show(_ surface: CommunityInstrumentView) throws -> MainScreenHitRegion {
        let region = try XCTUnwrap(surface.mainScreen.recipe?.regions.first)
        surface.mainScreen.onHelpChange?(region.help, region.rect)
        return region
    }
    func testActualProviderEmbedsTheRetainedLayerAndConvertsRealSourceCoordinatesWithoutSpending() async throws {
        let (_, surface, help, scheduler) = try await setup()
        let region = try show(surface)
        XCTAssertTrue(help.layer.superview === surface.view)
        XCTAssertEqual(help.layer.input?.anchors.first?.rect, surface.mainScreen.convert(region.rect, to: help.layer))
        XCTAssertNotNil(help.layer.input?.contextual)
        XCTAssertNotNil(help.layer.presentation?.card)
        XCTAssertFalse(help.layer.input?.liveReadings.isEmpty ?? true)
        XCTAssertNil(help.host.hints.context.cockpitOpen); XCTAssertNil(help.host.hints.context.dockReveal)
        XCTAssertTrue(help.host.hints.preferences.seen.isEmpty); XCTAssertFalse(help.host.hints.cockpitBudgetUsed)
        XCTAssertEqual(scheduler.arms, 0); XCTAssertNil(help.layer.window)
        XCTAssertTrue(help.layer.handleEscape()); XCTAssertNil(help.layer.input?.contextual)
        surface.dispose(); help.dispose()
    }
    func testOnlyCurrentRecipeExplanationAndRectangleCanEnterTheLayer() async throws {
        let (_, surface, help, _) = try await setup()
        let region = try show(surface); XCTAssertNotNil(help.layer.input?.contextual)
        surface.mainScreen.onHelpChange?(region.help, region.rect.offsetBy(dx: 1, dy: 0))
        XCTAssertNil(help.layer.input?.contextual)
        surface.mainScreen.onHelpChange?(HelpCatalog(.english).explanation(.window), region.rect)
        XCTAssertNil(help.layer.input?.contextual)
        surface.dispose(); help.dispose()
    }
    func testSuspensionCloseAndDisposeRetireContextWithoutReplayingItOnResume() async throws {
        let (_, surface, help, _) = try await setup(); _ = try show(surface)
        surface.suspendPresentation(); XCTAssertNil(help.layer.presentation?.card)
        surface.resumePresentation(); XCTAssertNil(help.layer.input?.contextual)
        _ = try show(surface); surface.closePresentation(); XCTAssertNil(help.layer.presentation?.card)
        surface.resumePresentation(); _ = try show(surface)
        let held = surface.mainScreen.onHelpChange; let region = try XCTUnwrap(surface.mainScreen.recipe?.regions.first)
        surface.dispose(); held?(region.help, region.rect)
        XCTAssertNil(help.layer.superview); XCTAssertNil(help.layer.presentation?.card)
        help.dispose()
    }
    func testHeldOldSourceAndDismissalCallbacksCannotChangeReplacementComposition() async throws {
        let (provider, surface, old, _) = try await setup(); let region = try show(surface)
        let heldSource = surface.mainScreen.onHelpChange, heldAction = old.onHelpAction
        let oldID = try XCTUnwrap(old.layer.input?.contextual?.id)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("context-replacement-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let app = SettingsApplicationCoordinator(store: try SettingsStore(url: directory.appendingPathComponent("prefs.json"))) { _ in }
        let replacement = await InstrumentHelpComposition.restored(application: app, scheduler: ContextScheduler(), uptime: { 0 })
        provider.bindHelp(replacement); _ = try show(surface)
        let input = replacement.layer.input
        heldSource?(region.help, region.rect); heldAction?(.dismissContext(id: oldID, returnFocusID: nil))
        XCTAssertEqual(replacement.layer.input, input); XCTAssertNil(old.layer.superview)
        XCTAssertTrue(replacement.layer.superview === surface.view)
        surface.dispose(); old.dispose(); replacement.dispose()
    }
    func testReentrantCloseFromLayerPresentationCannotRestoreOldContext() async throws {
        let (_, surface, help, _) = try await setup()
        help.layer.onPresentation = { presentation in
            if presentation.card != nil { surface.closePresentation() }
        }
        _ = try show(surface)
        XCTAssertFalse(surface.isPresented)
        XCTAssertNil(help.layer.presentation?.card)
        XCTAssertFalse(help.host.isRunning)
        XCTAssertTrue(help.host.hints.preferences.seen.isEmpty)
        help.layer.onPresentation = nil; surface.dispose(); help.dispose()
    }
    func testProviderCanBeReleasedWithoutACompositionApplicationCycle() async throws {
        var tuple: (CommunityInstrumentSurfaceProvider, CommunityInstrumentView, InstrumentHelpComposition, ContextScheduler)? = try await setup()
        weak var surface = tuple?.1
        weak var composition = tuple?.2
        tuple = nil
        XCTAssertNil(composition); XCTAssertNil(surface)
        surface = nil; composition = nil
    }
}
