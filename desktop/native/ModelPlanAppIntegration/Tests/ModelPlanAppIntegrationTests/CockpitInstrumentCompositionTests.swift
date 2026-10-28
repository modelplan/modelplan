// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanCore
import ModelPlanAssembly
import ModelPlanInstruments
import ModelPlanCockpitShell
@testable import ModelPlanAppIntegration

@MainActor private final class SyntheticInstrumentInputs: CockpitInstrumentInputProviding {
    var observations: [CockpitInstrumentObservation] = []
    var clockOffset: TimeInterval = 0
    func input(for observation: CockpitInstrumentObservation) throws -> InstrumentSurfaceInput {
        observations.append(observation)
        let selection = observation.selection.instruments
        let models = observation.selection.models
        let usable = selection != nil && selection?.publicDefaultFallback == false
        return try .init(observationID: "injected-synthetic", columns: [],
            channels: models.map { .init(model: $0) }, selection: selection, publication: selection?.publication,
            publicationUsable: usable, scope: observation.scope, language: observation.language,
            now: observation.now.addingTimeInterval(clockOffset), compact: false, showProjectNames: observation.showProjectNames,
            pages: [.init(.effort, effort: .init(models: models, selection: selection,
                publication: selection?.publication, publicationUsable: usable, scope: observation.scope,
                language: observation.language))],
            readers: [.init(sourceID: "synthetic", state: .unknown, evidence: .init(freshness: .unknown))])
    }
}

@MainActor final class CockpitInstrumentCompositionTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private func selection() throws -> AssembledModelSelection {
        let wire: [String: Any] = ["schemaVersion": 1, "publicationId": "synthetic", "selectionRevision": "r",
            "units": ["ability": "websiteAbility", "cost": "usdPerReferenceTask", "time": "taskTimeCrossModel"],
            "models": [["id": "model", "name": "Example", "developerId": "example", "lineageId": "example",
                        "lineageStatus": "current", "defaultSelected": true, "recommended": "high",
                        "efforts": [["effort": "high", "label": "High", "ability": 10, "cost": 2, "time": 3]]]],
            "lineups": []]
        var assembly = SelectionAssembly()
        return assembly.evaluate(feeds: .init(publication: try FeedDecoder.publication(JSONSerialization.data(withJSONObject: wire)),
            personal: nil, personalUsable: false), scope: .all, now: now)
    }
    private func frames() throws -> InstrumentSurfaceFrames {
        try .init(engines: .init(width: 1040, height: 240), console: .init(width: 1040, height: 440),
            mainScreen: .init(x: 0, y: 0, width: 600, height: 440), faders: .init(x: 640, y: 0, width: 400, height: 440))
    }
    private func observation(scope: InstrumentScope = .all) throws -> CockpitInstrumentObservation {
        try .init(snapshot: nil, selection: selection(), scope: scope, language: .chinese,
                  publishedAt: now, now: now, showProjectNames: false)
    }
    private func composition(main: MainScreenView? = nil, provider: SyntheticInstrumentInputs) throws -> CockpitInstrumentComposition {
        let root = NSView(frame: .init(x: 0, y: 0, width: 1040, height: 680)), layout = try frames()
        return .init(mainScreen: main ?? MainScreenView(), rootView: root, provider: provider, frames: { layout },
            mount: { root.addSubview($0); root.addSubview($1) })
    }
    func testInjectedSlotsShareTheExistingMainViewAndRemainUnpreparedWhileHidden() async throws {
        let provider = SyntheticInstrumentInputs(), main = MainScreenView()
        let composition = try composition(main: main, provider: provider)
        XCTAssertTrue(composition.surface.mainScreen === main)
        XCTAssertTrue(composition.surface.engines.superview === composition.rootView)
        XCTAssertTrue(composition.surface.console.superview === composition.rootView)
        try composition.update(observation())
        XCTAssertNil(composition.surface.mainScreen.recipe)
        XCTAssertNil(composition.surface.engineTable.recipe)
        XCTAssertNil(composition.surface.faders.recipe)
        XCTAssertNil(provider.observations.first?.snapshot)
        XCTAssertTrue(composition.surface.input?.columns.isEmpty == true, "A public catalogue does not create subscriptions")
        XCTAssertEqual(composition.surface.input?.readers.first?.state, .unknown)
        composition.dispose()
    }
    func testRealShellMountRequiresItsFrozenRegisteredSlotsAndNeverInventsFrames() async throws {
        let shell = CockpitShellSurface(skin: NeutralCockpitShellSkin()), provider = SyntheticInstrumentInputs()
        let layout = try frames()
        let composition = CockpitInstrumentComposition(mainScreen: MainScreenView(), shell: shell,
            provider: provider, frames: { layout })
        XCTAssertTrue(composition.surface.engines.isDescendant(of: shell))
        XCTAssertTrue(composition.surface.console.isDescendant(of: shell))
        XCTAssertThrowsError(try composition.update(observation()))
        XCTAssertNil(composition.surface.input)
        composition.dispose()
        XCTAssertFalse(composition.surface.engines.isDescendant(of: shell))
    }
    func testScopeChangeRetiresOldObservationBeforeRequestingFreshHostFacts() async throws {
        let composition = try composition(provider: SyntheticInstrumentInputs())
        try composition.update(observation()); try composition.setPresentationAllowed(true)
        var requests: [InstrumentSurfaceIntent] = []
        composition.onIntent = { requests.append($0) }
        try composition.surface.engineTable.update(columns: [], language: .chinese, now: now, scope: .subscription("a"))
        composition.surface.binding.receiveEngine(.selectScope(.subscription("a")))
        XCTAssertEqual(requests, [.requestScope(.subscription("a"))])
        XCTAssertEqual(composition.requestedScope, .subscription("a"))
        XCTAssertNil(composition.surface.input); XCTAssertTrue(composition.surface.console.isHidden)
        XCTAssertThrowsError(try composition.update(observation()))
        composition.dispose()
    }
    func testUpperProviderUsesOptInCompositionAndPreservesSingleMainScreenLifecycle() async throws {
        let inputs = SyntheticInstrumentInputs(), layout = try frames()
        let provider = CommunityInstrumentSurfaceProvider(makeCockpit: { main in
            let root = NSView(frame: .init(x: 0, y: 0, width: 1040, height: 680))
            return .init(mainScreen: main, rootView: root, provider: inputs, frames: { layout },
                         mount: { root.addSubview($0); root.addSubview($1) })
        })
        let view = try XCTUnwrap(provider.makeOverview() as? CommunityInstrumentView)
        view.render(selection: try selection(), publishedAt: now, now: now)
        view.resumePresentation()
        let composition = try XCTUnwrap(view.cockpitComposition)
        XCTAssertTrue(view.mainScreen === composition.surface.mainScreen)
        XCTAssertNotNil(composition.surface.engineTable.recipe)
        XCTAssertFalse(view.renderFailure); XCTAssertTrue(view.modelPicker.isHidden)
        let count = view.mainScreen.surfaceRenders
        view.suspendPresentation(); view.render(selection: try selection(), publishedAt: now, now: now)
        XCTAssertEqual(count, view.mainScreen.surfaceRenders)
        view.closePresentation(); XCTAssertNil(composition.surface.input)
        view.dispose(); XCTAssertTrue(composition.surface.isDisposed)
    }
    func testMismatchedObservationCannotKeepTheLastGoodInstrumentPixels() async throws {
        let inputs = SyntheticInstrumentInputs(), composition = try composition(provider: inputs)
        try composition.update(observation()); try composition.setPresentationAllowed(true)
        XCTAssertNotNil(composition.surface.input)
        inputs.clockOffset = -1
        XCTAssertThrowsError(try composition.update(observation()))
        XCTAssertNil(composition.surface.input); XCTAssertTrue(composition.surface.console.isHidden)
        composition.dispose()
    }
}
