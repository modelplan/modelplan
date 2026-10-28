// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@testable import ModelPlanInstruments

private enum SurfaceFixture {
    static let publication = SelectionPublication(publicationID: "synthetic", selectionRevision: "r")
    static func input(id: String = "model", scope: InstrumentScope = .all, fallback: Bool = false,
                      readers: [InstrumentReaderObservation] = []) throws -> InstrumentSurfaceInput {
        let selection = InjectedModelSelection(publication: publication, scope: scope,
            orderedModelIDs: [id], selectedModelID: id, publicDefaultFallback: fallback)
        let model = Fixtures.model(current: fallback ? nil : .init("high"), id: id)
        return try .init(observationID: "synthetic-" + id, columns: [Fixtures.column("a", tokens: 0)],
            channels: [.init(model: model)], selection: selection, publication: publication,
            publicationUsable: !fallback, scope: scope, language: .english, now: Fixtures.now,
            compact: false, pages: [.init(.effort, effort: .init(models: [model], selection: selection,
                publication: publication, publicationUsable: !fallback, scope: scope, language: .english))], readers: readers)
    }
    static func frames() throws -> InstrumentSurfaceFrames {
        try .init(engines: .init(width: 1040, height: 240), console: .init(width: 1040, height: 440),
                  mainScreen: .init(x: 0, y: 0, width: 600, height: 440),
                  faders: .init(x: 640, y: 0, width: 400, height: 440))
    }
}

final class InstrumentSurfaceInputTests: XCTestCase {
    func testExplicitReaderStatesAndKnownZeroArePreservedWithoutEmptyInference() throws {
        let states: [InstrumentReaderState] = [.unknown, .notDetected, .noConsent, .notConnectedYet, .stale, .available]
        for state in states {
            let input = try SurfaceFixture.input(readers: [.init(sourceID: "synthetic", state: state,
                evidence: .init(freshness: .unknown))])
            XCTAssertEqual(input.readers.first?.state, state)
            XCTAssertEqual(input.columns.first?.todayTokens, 0)
        }
        XCTAssertTrue(try SurfaceFixture.input().readers.isEmpty)
    }
    func testFallbackHasNoInventedCurrentAndMismatchedSelectionRejects() throws {
        let input = try SurfaceFixture.input(fallback: true)
        XCTAssertNil(input.channels.first?.model.current)
        XCTAssertTrue(input.selection?.publicDefaultFallback == true)
        XCTAssertFalse(input.publicationUsable)
        XCTAssertThrowsError(try InstrumentSurfaceInput(observationID: "bad", columns: [], channels: input.channels,
            selection: input.selection, publication: .init(publicationID: "other", selectionRevision: "r"),
            publicationUsable: false, scope: .all, language: .english, now: Fixtures.now, compact: false))
    }
    func testFramesMustBeExplicitFiniteContainedAndDisjoint() throws {
        _ = try SurfaceFixture.frames()
        XCTAssertThrowsError(try InstrumentSurfaceFrames(engines: .zero, console: .init(width: 1, height: 1),
            mainScreen: .zero, faders: .zero))
        XCTAssertThrowsError(try InstrumentSurfaceFrames(engines: .init(width: 2, height: 2), console: .init(width: 10, height: 10),
            mainScreen: .init(x: 0, y: 0, width: 8, height: 8), faders: .init(x: 1, y: 1, width: 2, height: 2)))
    }
}

@MainActor final class InstrumentSurfaceBindingTests: XCTestCase {
    private func surface() throws -> InstrumentSurfaceView {
        let surface = InstrumentSurfaceView()
        try surface.update(SurfaceFixture.input(), frames: SurfaceFixture.frames())
        try surface.setPresentationAllowed(true)
        return surface
    }
    func testHiddenUpdatesDoNotPreparePixelsAndIdenticalVisibleUpdateDoesNotRepaint() async throws {
        let surface = InstrumentSurfaceView(), input = try SurfaceFixture.input(), frames = try SurfaceFixture.frames()
        try surface.update(input, frames: frames)
        XCTAssertNil(surface.mainScreen.recipe); XCTAssertNil(surface.engineTable.recipe); XCTAssertNil(surface.faders.recipe)
        try surface.setPresentationAllowed(true)
        let counts = [surface.mainScreen.surfaceRenders, surface.faders.surfaceRenders, surface.engineTable.displayRequests]
        try surface.update(input, frames: frames)
        XCTAssertEqual(counts, [surface.mainScreen.surfaceRenders, surface.faders.surfaceRenders, surface.engineTable.displayRequests])
        try surface.setPresentationAllowed(false)
        surface.applyAppearance(NSAppearance(named: .aqua))
        try surface.update(SurfaceFixture.input(id: "replacement"), frames: frames)
        XCTAssertEqual(counts, [surface.mainScreen.surfaceRenders, surface.faders.surfaceRenders, surface.engineTable.displayRequests])
        surface.dispose()
    }
    func testFaderTrialUsesExistingMainControllerAndCloseClearsMirrorWithoutRaster() async throws {
        let surface = try surface()
        surface.binding.receiveFader(.trialChanged(.init(modelID: "model", configuration: .init("max"))))
        XCTAssertEqual(surface.mainScreen.controller.trial?.configuration.effort, "max")
        XCTAssertEqual(surface.faders.controller.trial, surface.mainScreen.controller.trial)
        let count = surface.faders.surfaceRenders
        surface.close()
        XCTAssertNil(surface.mainScreen.controller.trial); XCTAssertNil(surface.faders.controller.trial)
        XCTAssertNil(surface.faders.recipe); XCTAssertEqual(surface.faders.surfaceRenders, count)
        surface.dispose()
    }
    func testRemovedModelClearsMirroredTrialAndRejectsForgedOldMainIntent() async throws {
        let surface = try surface(); var effects: [InstrumentSurfaceIntent] = []
        surface.binding.onIntent = { effects.append($0) }
        surface.binding.receiveFader(.trialChanged(.init(modelID: "model", configuration: .init("max"))))
        try surface.update(SurfaceFixture.input(id: "replacement"), frames: SurfaceFixture.frames())
        XCTAssertNil(surface.faders.controller.trial); XCTAssertNil(surface.mainScreen.controller.trial)
        effects.removeAll(); surface.binding.receiveMain([.modelSelected("model")])
        XCTAssertTrue(effects.isEmpty); surface.dispose()
    }
    func testScopeRequestReturnsToHostAndNoHiddenOrDisposedEffectEscapes() async throws {
        let surface = try surface(); var effects: [InstrumentSurfaceIntent] = []
        surface.binding.onIntent = { effects.append($0) }
        try surface.engineTable.update(columns: [Fixtures.column("a")], language: .english,
            now: Fixtures.now, scope: .subscription("a"))
        surface.binding.receiveEngine(.selectScope(.subscription("a")))
        XCTAssertEqual(effects, [.requestScope(.subscription("a"))])
        let held = surface.mainScreen.onIntents
        try surface.setPresentationAllowed(false)
        held?([.modelSelected("model")]); surface.binding.receiveEngine(.openSubscriptionsSettings)
        XCTAssertEqual(effects.count, 1)
        surface.dispose(); held?([.modelSelected("model")]); XCTAssertEqual(effects.count, 1)
    }
    func testClearObservationCannotResumeStaleFrameOrTrial() async throws {
        let surface = try surface()
        surface.binding.receiveFader(.trialChanged(.init(modelID: "model", configuration: .init("max"))))
        surface.clearObservation(); try surface.setPresentationAllowed(true)
        XCTAssertNil(surface.input); XCTAssertTrue(surface.console.isHidden)
        XCTAssertNil(surface.faders.controller.trial); surface.dispose()
    }
    func testSuspensionForwardsCancellationButCannotStartAnotherHintRest() async throws {
        let surface = try surface(); var values: [InstrumentHintInput] = []
        surface.binding.onHintInput = { _, input in values.append(input) }
        let held = surface.faders.onHintInput
        try surface.setPresentationAllowed(false)
        let count = values.count
        held?(.faderRestCandidate(anchor: .init(modelID: "model", regionID: "example", travel: .zero), pointer: .zero, at: 1))
        XCTAssertEqual(values.count, count)
        held?(.cancelFaderRest(.teardown, at: 1))
        XCTAssertEqual(values.last, .cancelFaderRest(.teardown, at: 1))
        surface.dispose()
    }
    func testWebsiteEffectsRequireTheCurrentExistingPageLinkAndPresentation() async throws {
        let surface = try surface(); var effects: [InstrumentSurfaceIntent] = []
        surface.binding.onIntent = { effects.append($0) }
        surface.mainScreen.selectPage(.init(.effort))
        let link = try XCTUnwrap(surface.mainScreen.presentation?.websiteLinks.first)
        surface.binding.receiveMain([.openWebsite(link)])
        XCTAssertEqual(effects, [.openWebsite(link)])
        surface.binding.receiveMain([.openWebsite(.compare(publicModelID: "other", language: .english))])
        XCTAssertEqual(effects.count, 1)
        try surface.setPresentationAllowed(false)
        surface.binding.receiveMain([.openWebsite(link)])
        XCTAssertEqual(effects.count, 1); surface.dispose()
    }
    func testRejectedProviderSizeWithholdsEveryRegionAndItsOldEffects() async throws {
        let surface = try surface(); var effects: [InstrumentSurfaceIntent] = []
        surface.binding.onIntent = { effects.append($0) }
        let tooSmall = try InstrumentSurfaceFrames(engines: .init(width: 1040, height: 240),
            console: .init(width: 1040, height: 440), mainScreen: .init(x: 0, y: 0, width: 600, height: 440),
            faders: .init(x: 640, y: 0, width: 1, height: 440))
        XCTAssertThrowsError(try surface.update(SurfaceFixture.input(), frames: tooSmall))
        XCTAssertTrue(surface.engines.isHidden); XCTAssertTrue(surface.console.isHidden)
        surface.binding.receiveEngine(.openSubscriptionsSettings)
        XCTAssertTrue(effects.isEmpty); surface.dispose()
    }
    func testReentrantLayoutCancellationCannotRebuildADisposedSurface() async throws {
        let surface = try surface(); var retired = false
        surface.binding.onHintInput = { _, input in
            if case .cancelFaderRest = input, !retired { retired = true; surface.dispose() }
        }
        let changed = try InstrumentSurfaceFrames(engines: .init(width: 1040, height: 240),
            console: .init(width: 1040, height: 440), mainScreen: .init(x: 0, y: 0, width: 600, height: 440),
            faders: .init(x: 630, y: 0, width: 400, height: 440))
        try surface.update(SurfaceFixture.input(), frames: changed)
        XCTAssertTrue(surface.isDisposed); XCTAssertNil(surface.mainScreen.recipe); XCTAssertNil(surface.faders.recipe)
        XCTAssertTrue(surface.engines.isHidden); XCTAssertTrue(surface.console.isHidden)
    }
}
