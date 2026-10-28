// SPDX-License-Identifier: MIT
import AppKit
import CoreText
import ModelPlanInstruments
import XCTest
import ModelPlanCore
import ModelPlanField
import ModelPlanAssembly
import ModelPlanCockpitShell
@testable import ModelPlanAppIntegration

@MainActor private final class RecordingFieldWindow: CommunityFieldWindow {
    var shown = 0, hidden = 0
    func show(content: NSView, onClose: @escaping () -> Void) { shown += 1 }
    func hide() { hidden += 1 }
}
@MainActor private final class ReentrantFieldWindow: CommunityFieldWindow {
    var onHide: (() -> Void)?
    func show(content: NSView, onClose: @escaping () -> Void) {}
    func hide() { let action = onHide; onHide = nil; action?() }
}
@MainActor private final class UnusedReplacementInputs: CockpitInstrumentInputProviding {
    func input(for observation: CockpitInstrumentObservation) throws -> InstrumentSurfaceInput {
        XCTFail("Replacement construction must not evaluate or render a feed")
        throw InstrumentSurfaceError.invalidInput
    }
}
/// Synthetic sizes below the neutral minimums, with no official geometry/paint or private assets.
@MainActor private final class CompactTestSkin: CockpitShellSkin {
    func layout(for state: CockpitSurfaceState) throws -> CockpitSurfaceLayout {
        .init(rootSize: .init(width: 510, height: 540), drawableBounds: .init(x: 0, y: 0, width: 510, height: 540),
            slots: [.window: .init(x: 0, y: 0, width: 510, height: 100),
                    .engines: .init(x: 0, y: 110, width: 510, height: 220),
                    .console: .init(x: 0, y: 340, width: 510, height: 200)], expectedStillKey: nil)
    }
    func backdrop(for state: CockpitSurfaceState, layout: CockpitSurfaceLayout, matchingStill: CGImage?) throws -> CGImage {
        try NeutralCockpitShellSkin().backdrop(for: state, layout: layout, matchingStill: matchingStill)
    }
    func stationLayers(for state: CockpitSurfaceState, layout: CockpitSurfaceLayout) throws -> [CALayer] { [] }
    func discardTransientResources() {}
}
@MainActor private final class CompactTestRecipes: EngineTableRecipeProvider, FaderBankRecipeProvider, MainScreenRecipeProvider {
    var engines: [CGSize] = [], faders: [CGSize] = [], main: [CGSize] = []
    func font(_ request: EngineFontRequest) throws -> CTFont { try NeutralEngineTableRecipe().font(request) }
    func image(_ id: String) throws -> CGImage { throw EngineTableError.missingResource(id) }
    func recipe(for presentation: EngineTablePresentation, size: CGSize) throws -> EngineTableRecipe {
        engines.append(size); return .init(size: size, commands: [], regions: [])
    }
    func recipe(for presentation: FaderBankPresentation, size: CGSize) throws -> FaderBankRecipe {
        faders.append(size); return .init(size: size, commands: [], regions: [], caps: [])
    }
    func recipe(for presentation: MainScreenPresentation, size: CGSize) throws -> MainScreenRecipe {
        main.append(size); return .init(size: size, commands: [], regions: [])
    }
    func minimumSize(for presentation: FaderBankPresentation) -> CGSize { .init(width: 200, height: 200) }
    func minimumSize(for presentation: MainScreenPresentation) -> CGSize { .init(width: 300, height: 200) }
}
@MainActor final class CommunityFieldProductionWiringTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private func publication(_ active: String = "a", revision: String = "r1") throws -> PublicPublication {
        let models: [[String: Any]] = ["a", "b"].map { id in
            ["id": id, "name": id, "developerId": "example", "lineageId": id, "lineageStatus": "current",
             "defaultSelected": id == active, "recommended": "high",
             "efforts": [["effort": "high", "label": "High", "available": false, "ability": 10, "cost": 2, "time": 3]]]
        }
        return try FeedDecoder.publication(JSONSerialization.data(withJSONObject: ["schemaVersion": 1,
            "publicationId": revision, "selectionRevision": revision,
            "units": ["ability": "websiteAbility", "cost": "usdPerReferenceTask", "time": "taskTimeCrossModel"],
            "models": models, "lineups": []]))
    }
    private func render(_ surface: CommunityInstrumentView, publication: PublicPublication?) {
        var assembly = SelectionAssembly()
        surface.render(publication: publication)
        surface.render(selection: assembly.evaluate(feeds: .init(publication: publication, personal: nil, personalUsable: false),
            scope: .all, now: now), publishedAt: now, now: now)
    }
    func testNormalEntryMountsCockpitAndPickerRatherThanLeavingOptInNil() async throws {
        let provider = CommunityApplicationFactory.makeSurfaces()
        let surface = try XCTUnwrap(provider.makeOverview() as? CommunityInstrumentView)
        defer { surface.dispose() }
        XCTAssertNotNil(surface.cockpitComposition, "Normal entry must mount the cockpit, not only the old MainScreen")
        let field = try XCTUnwrap(surface.cockpitComposition?.field, "Removing the actual factory field mount must fail")
        XCTAssertFalse(field.picker.isPresented)
        XCTAssertThrowsError(try field.open(), "A hidden or unfed factory must not open")
        let shell = try XCTUnwrap(surface.cockpitComposition?.rootView as? CockpitShellSurface)
        XCTAssertGreaterThan(shell.backdropBytes, 0)
        surface.dispose()
        XCTAssertNil(surface.cockpitComposition)
        XCTAssertNil(shell.state, "Retaining the actual factory shell must not retain a retired frame")
        XCTAssertNil(shell.surfaceLayout)
        XCTAssertEqual(shell.backdropBytes, 0)
        XCTAssertEqual(shell.stationLayerCount, 0)
    }
    func testSameFactoryForwardsPublicFocusPersistsAndRestoresLatestScope() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let preferences = PreferenceFile(url: directory.appendingPathComponent("ui.json"))
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(#"{"schemaVersion":1,"favouriteModelIDs":["a"]}"#.utf8).write(to: preferences.url)
        let window = RecordingFieldWindow()
        var scopes: [[String]] = []
        let neutral = CommunityCockpitSupply.neutral()
        let supply = CommunityCockpitSupply(skin: neutral.skin, recipes: neutral.recipes, containsFieldPoint: neutral.containsFieldPoint, frames: neutral.frames, still: { scope in
            scopes.append(scope.admittedPublicIDs); return nil
        })
        let provider = CommunityApplicationFactory.makeSurfaces(supply: supply, preferences: preferences, makeFieldWindow: { window })
        let surface = try XCTUnwrap(provider.makeOverview() as? CommunityInstrumentView)
        defer { surface.dispose() }
        render(surface, publication: try publication()); surface.resumePresentation()
        XCTAssertFalse(surface.renderFailure)
        let field = try XCTUnwrap(surface.cockpitComposition?.field)
        XCTAssertEqual(field.currentScope?.admittedPublicIDs, ["a"])
        XCTAssertEqual(field.currentScope?.projection.models.first?.efforts.first?.available, false, "Preserve the published nullable availability tuple without defaulting true")
        // Synthetic native lifecycle delivery: no App/Window/input is launched in this check.
        field.setPresented(true)
        try field.open(); XCTAssertEqual(window.shown, 1)
        field.picker.focus("b")
        XCTAssertEqual(field.focusedPublicID, "b", "The mounted production comparison must receive focus")
        XCTAssertEqual(field.enlargedProjection?.models.map(\.id), ["a", "b"])
        XCTAssertEqual(try preferences.load().favouriteModelIDs, ["a"], "The same existing preferences preserve other UI values")
        let saved = try XCTUnwrap(preferences.load().fieldPickerValue)
        XCTAssertEqual((try JSONSerialization.jsonObject(with: saved) as? [String: Any])?["ids"] as? [String], ["a", "b"])
        render(surface, publication: try publication("b", revision: "r2"))
        try field.close()
        XCTAssertEqual(scopes.last, ["b"], "Close uses current scope, never extra field models or an old capture")
        XCTAssertNil(field.enlargedProjection); XCTAssertNil(field.focusedPublicID)
        XCTAssertFalse(field.picker.isPresented)
        XCTAssertEqual(surface.requestedInstrumentScope, .all)
    }
    func testPersistenceFailureClosesTheActualProductionFieldAndRetryWorks() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let blocker = directory.appendingPathComponent("blocker")
        try Data().write(to: blocker)
        let window = RecordingFieldWindow()
        let preferences = PreferenceFile(url: blocker.appendingPathComponent("ui.json"))
        let provider = CommunityApplicationFactory.makeSurfaces(preferences: preferences, makeFieldWindow: { window })
        let surface = try XCTUnwrap(provider.makeOverview() as? CommunityInstrumentView)
        defer { surface.dispose() }
        render(surface, publication: try publication()); surface.resumePresentation()
        let field = try XCTUnwrap(surface.cockpitComposition?.field)
        field.setPresented(true); try field.open(); field.picker.focus("b")
        XCTAssertNotNil(field.binding.lastError)
        XCTAssertNil(field.enlargedProjection); XCTAssertFalse(field.picker.isPresented)
        XCTAssertGreaterThan(window.hidden, 0)
        try FileManager.default.removeItem(at: blocker)
        field.setPresented(true); try field.open(); field.picker.focus("b")
        XCTAssertNil(field.binding.lastError); XCTAssertEqual(field.focusedPublicID, "b")
        surface.suspendPresentation()
        XCTAssertNil(field.enlargedProjection); XCTAssertFalse(field.picker.isPresented)
        XCTAssertThrowsError(try field.open())
    }
    func testRealCockpitInputUsesVerifiedQuotaAndKeepsMonthlyOutOfUpperRows() async throws {
        let date = ISO8601DateFormatter()
        let raw: [String: Any] = ["schemaVersion": 1, "kind": "modelplan.personal-snapshot", "generatedAt": date.string(from: now),
            "validUntil": date.string(from: now.addingTimeInterval(600)), "accounts": [
                ["source": "cursor", "plan": "Cursor", "observedAt": date.string(from: now),
                 "subscription": ["subscriptionRef": "verified", "status": "verified"],
                 "windows": [["kind": "monthly", "windowMinutes": 43200, "remainingPercent": 60]]],
                ["source": "unknown", "windows": [["kind": "5h", "windowMinutes": 300, "remainingPercent": 90]]]
            ]]
        let personal = try FeedDecoder.personal(JSONSerialization.data(withJSONObject: raw))
        var ledger = ExpiryLedger()
        let projection = PersonalProjection.evaluate(personal, now: now, ledger: &ledger)
        let provider = CommunityApplicationFactory.makeSurfaces()
        let surface = try XCTUnwrap(provider.makeOverview() as? CommunityInstrumentView)
        defer { surface.dispose() }
        surface.render(snapshot: .make(personal: personal, presentation: projection, publication: nil), diagnostics: .init())
        render(surface, publication: try publication()); surface.resumePresentation()
        let input = try XCTUnwrap(surface.cockpitComposition?.surface.input)
        XCTAssertEqual(input.columns.map(\.id), ["verified"])
        let column = try XCTUnwrap(input.columns.first)
        XCTAssertNil(column.quotas.fiveHours); XCTAssertNil(column.quotas.weekly)
        XCTAssertEqual(column.quotas.other.first?.remaining, 60)
        XCTAssertNil(column.todayTokens, "Do not copy source-wide usage into a subscription")
    }
    func testSuspensionHidesOwnedPanelEvenWhenScopeSupplierFails() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let neutral = CommunityCockpitSupply.neutral(), window = RecordingFieldWindow()
        var failStill = false
        let supply = CommunityCockpitSupply(skin: neutral.skin, recipes: neutral.recipes, containsFieldPoint: neutral.containsFieldPoint, frames: neutral.frames, still: { _ in
            if failStill { throw FieldPickerConnectionError.disconnected }; return nil
        })
        let provider = CommunityApplicationFactory.makeSurfaces(supply: supply,
            preferences: PreferenceFile(url: directory.appendingPathComponent("ui.json")), makeFieldWindow: { window })
        let surface = try XCTUnwrap(provider.makeOverview() as? CommunityInstrumentView)
        defer { surface.dispose() }
        render(surface, publication: try publication()); surface.resumePresentation()
        let field = try XCTUnwrap(surface.cockpitComposition?.field)
        field.setPresented(true); try field.open()
        let hides = window.hidden; failStill = true
        field.setPresented(false)
        XCTAssertGreaterThan(window.hidden, hides, "Suspension must hide the actual owned panel despite recovery failure")
        XCTAssertNotNil(field.binding.recoveryError)
        XCTAssertThrowsError(try field.open(), "Hidden retry controls cannot reopen the field")
        failStill = false; field.setPresented(true); try field.open()
        XCTAssertNil(field.binding.lastError)
    }
    private func compactSupply(_ recipes: CommunityCockpitInstrumentRecipes) -> CommunityCockpitSupply {
        .init(skin: CompactTestSkin(), recipes: recipes,
            containsFieldPoint: { point, scope in
                CGRect(x: 0, y: 0, width: scope.viewport.width, height: scope.viewport.height).insetBy(dx: 20, dy: 20).contains(point)
            },
            frames: { _ in try .init(engines: .init(width: 510, height: 220), console: .init(width: 510, height: 200),
                mainScreen: .init(x: 210, y: 0, width: 300, height: 200), faders: .init(x: 0, y: 0, width: 200, height: 200)) },
            still: { _ in nil })
    }
    func testSameFactoryInjectsAllInstrumentRecipesWithExactSupplierFrames() async throws {
        let recipes = CompactTestRecipes()
        let provider = CommunityApplicationFactory.makeSurfaces(supply: compactSupply(.init(engines: recipes, faders: recipes, mainScreen: recipes)))
        let surface = try XCTUnwrap(provider.makeOverview() as? CommunityInstrumentView)
        defer { surface.dispose() }
        render(surface, publication: try publication()); surface.resumePresentation()
        let composition = try XCTUnwrap(surface.cockpitComposition)
        XCTAssertTrue(surface.mainScreen === composition.surface.mainScreen)
        XCTAssertTrue(surface.mainScreen.recipeProvider === recipes)
        XCTAssertTrue(composition.surface.engineTable.recipeProvider === recipes)
        XCTAssertTrue(composition.surface.faders.recipeProvider === recipes)
        // Synthetic presentation delivery forces the actual recipe path without an App/Window.
        try composition.surface.setPresentationAllowed(true)
        XCTAssertEqual(recipes.engines.last, .init(width: 510, height: 220))
        XCTAssertEqual(recipes.main.last, .init(width: 300, height: 200))
        XCTAssertEqual(recipes.faders.last, .init(width: 200, height: 200))
    }
    func testCompactSupplierCannotSilentlyRelaxTheNeutralMinimum() async throws {
        let provider = CommunityApplicationFactory.makeSurfaces(supply: compactSupply(.neutral()))
        let surface = try XCTUnwrap(provider.makeOverview() as? CommunityInstrumentView)
        defer { surface.dispose() }
        render(surface, publication: try publication()); surface.resumePresentation()
        let composition = try XCTUnwrap(surface.cockpitComposition)
        XCTAssertThrowsError(try composition.surface.setPresentationAllowed(true))
        XCTAssertNil(composition.surface.mainScreen.recipe)
    }
    func testActualNormalLeafUsesSupplierApertureBeforeChildHits() async throws {
        let provider = CommunityApplicationFactory.makeSurfaces(supply: compactSupply(.neutral()))
        let surface = try XCTUnwrap(provider.makeOverview() as? CommunityInstrumentView)
        defer { surface.dispose() }
        render(surface, publication: try publication()); surface.resumePresentation()
        let field = try XCTUnwrap(surface.cockpitComposition?.field)
        let leaf = field.normalFieldView
        XCTAssertTrue(leaf.isFlipped)
        let outside = leaf.convert(.init(x: 1, y: 1), to: leaf.superview)
        let inside = leaf.convert(.init(x: leaf.bounds.midX, y: leaf.bounds.midY), to: leaf.superview)
        XCTAssertNil(leaf.hitTest(outside), "The rectangular slot must not admit clipped supplier corners")
        XCTAssertNotNil(leaf.hitTest(inside))
    }
    func testFieldDisposalRevokesRestoreBeforeCallingTheExternalWindow() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let neutral = CommunityCockpitSupply.neutral(), window = ReentrantFieldWindow()
        var restores = 0, callbacks = 0
        let supply = CommunityCockpitSupply(skin: neutral.skin, recipes: neutral.recipes,
            containsFieldPoint: neutral.containsFieldPoint, frames: neutral.frames, still: { _ in restores += 1; return nil })
        let provider = CommunityApplicationFactory.makeSurfaces(supply: supply,
            preferences: PreferenceFile(url: directory.appendingPathComponent("ui.json")), makeFieldWindow: { window })
        let view = try XCTUnwrap(provider.makeOverview() as? CommunityInstrumentView)
        defer { view.dispose() }
        render(view, publication: try publication()); view.resumePresentation()
        let composition = try XCTUnwrap(view.cockpitComposition)
        let field = try XCTUnwrap(composition.field), shell = try XCTUnwrap(composition.rootView as? CockpitShellSurface)
        field.setPresented(true); try field.open(); let before = restores
        window.onHide = {
            callbacks += 1
            do { try field.closeEnlargedFieldAndRestoreCurrentScopeStill(); XCTFail("Retired field restored a scope") }
            catch { XCTAssertEqual(error as? FieldPickerConnectionError, .disconnected) }
            do { try field.open(); XCTFail("Retired field reopened") }
            catch { XCTAssertEqual(error as? FieldPickerConnectionError, .disconnected) }
        }
        view.dispose()
        XCTAssertEqual(callbacks, 1); XCTAssertEqual(restores, before)
        XCTAssertNil(shell.state); XCTAssertNil(shell.surfaceLayout); XCTAssertEqual(shell.backdropBytes, 0)
        XCTAssertNil(field.normalFieldView.superview)
    }
    func testReplacementInstalledByFieldRetirementKeepsItsShellLease() async throws {
        let window = ReentrantFieldWindow(), supply = CommunityCockpitSupply.neutral()
        let provider = CommunityApplicationFactory.makeSurfaces(supply: supply, makeFieldWindow: { window })
        let view = try XCTUnwrap(provider.makeOverview() as? CommunityInstrumentView)
        let shell = try XCTUnwrap(view.cockpitComposition?.rootView as? CockpitShellSurface)
        let bytes = shell.backdropBytes
        var replacement: CockpitInstrumentComposition?
        window.onHide = {
            replacement = CockpitInstrumentComposition(mainScreen: MainScreenView(), shell: shell,
                provider: UnusedReplacementInputs(), ownsShell: true, frames: {
                    try supply.frames(XCTUnwrap(shell.surfaceLayout))
                })
        }
        view.dispose()
        let next = try XCTUnwrap(replacement)
        XCTAssertNotNil(shell.state); XCTAssertNotNil(shell.surfaceLayout); XCTAssertEqual(shell.backdropBytes, bytes)
        XCTAssertTrue(next.surface.engines.isDescendant(of: shell))
        XCTAssertTrue(next.surface.console.isDescendant(of: shell))
        next.dispose()
        XCTAssertNil(shell.state); XCTAssertNil(shell.surfaceLayout); XCTAssertEqual(shell.backdropBytes, 0)
        XCTAssertFalse(next.surface.engines.isDescendant(of: shell))
    }
    func testMissingSupplierPortFailsActualFactoryAndCannotClaimConnected() async throws {
        let neutral = CommunityCockpitSupply.neutral()
        let supply = CommunityCockpitSupply(skin: neutral.skin, recipes: neutral.recipes, containsFieldPoint: neutral.containsFieldPoint, frames: { _ in throw FieldPickerConnectionError.disconnected }, still: neutral.still)
        let provider = CommunityApplicationFactory.makeSurfaces(supply: supply, makeFieldWindow: { RecordingFieldWindow() })
        let surface = try XCTUnwrap(provider.makeOverview() as? CommunityInstrumentView)
        defer { surface.dispose() }
        render(surface, publication: try publication()); surface.resumePresentation()
        XCTAssertTrue(surface.renderFailure, "Disconnected real factory ports must fail, not silently fall back")
    }
}
