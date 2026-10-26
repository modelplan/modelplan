// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@testable import ModelPlanInstruments

final class FaderBankModelTests: XCTestCase {
    private func input(_ id: String = "m", current: EffortConfiguration? = .init("high"), count: Int? = nil) -> FaderChannelInput {
        if let count {
            let efforts = (0..<count).map { i in InstrumentEffort(key: "native\(i)", label: "E\(i)", ability: Fixtures.metric(Double(i)), cost: Fixtures.metric(Double(i + 1)), time: Fixtures.metric(nil)) }
            return .init(model: Fixtures.model(current: current, rec: efforts.last?.key ?? "none", efforts: efforts, id: id))
        }
        return .init(model: Fixtures.model(current: current, id: id))
    }
    func testThreeSlotsUniqueModelsFavoritesAndBankClampPreserveInputOrder() {
        let values = [input("a"), input("a"), input("b"), input("c"), input("d")]
        let p = FaderBankPresentation(inputs: values, requestedBank: 99, favoriteIDs: ["c", "c", "missing"], publicationUsable: true, language: .english, compact: false, now: Fixtures.now)
        XCTAssertEqual(p.bank, 1); XCTAssertEqual(p.bankCount, 2); XCTAssertEqual(p.channels.compactMap { $0?.id }, ["d"])
        XCTAssertEqual(FaderBankPresentation.ordered(inputs: values, favoriteIDs: ["c"]).map { $0.model.id }, ["c", "a", "b", "d"])
    }
    func testUnknownAndSingleNativeSettingDoNotInventCurrentOrLadder() throws {
        let p = FaderBankPresentation(inputs: [input(current: nil, count: 1), input("six", current: nil, count: 6)], publicationUsable: true, language: .english, compact: true, now: Fixtures.now)
        let single = try XCTUnwrap(p.channels[0]); XCTAssertEqual(single.efforts.map(\.key), ["native0"])
        XCTAssertNil(single.current); XCTAssertTrue(single.parked); XCTAssertEqual(single.state, "--"); XCTAssertNil(single.costMultiple)
        XCTAssertEqual(single.efforts[0].position, 0.5)
        XCTAssertEqual(p.channels[1]?.efforts.count, 6); XCTAssertNil(p.channels[1]?.current)
    }
    func testOneTrialGhostNeverMovesReportedRealAndUsesCurrentCostBasis() throws {
        var state = FaderBankController(); state.update(inputs: [input(), input("other")], publicationUsable: true)
        let before = FaderBankPresentation(inputs: state.inputs, publicationUsable: true, language: .chinese, compact: false, now: Fixtures.now)
        _ = state.beginDrag(modelID: "m", position: 0)
        let during = FaderBankPresentation(inputs: state.inputs, trial: state.trial, draggingModelID: state.draggingModelID, dragPosition: state.dragPosition, publicationUsable: true, language: .chinese, compact: false, now: Fixtures.now)
        XCTAssertEqual(during.channels[0]?.realPosition, before.channels[0]?.realPosition)
        XCTAssertEqual(during.channels[0]?.current, .init("high")); XCTAssertEqual(during.channels[0]?.trial, .init("max"))
        XCTAssertEqual(during.channels[0]?.costMultiple, "×2.8"); XCTAssertEqual(during.channels[0]?.dragPosition, 0)
        _ = state.tryEffort(modelID: "other", key: "low"); XCTAssertEqual(state.trial?.modelID, "other")
        state.finishDrag(); XCTAssertNil(state.dragPosition)
        _ = state.endTrial(); XCTAssertNil(state.trial)
    }
    func testEqualCurrentAndRecommendationHaveNoMultipleAndNoEqualCurrentGhost() {
        for key in ["high", "medium"] {
            let p = FaderBankPresentation(inputs: [input()], trial: .init(modelID: "m", configuration: .init(key)), publicationUsable: true, language: .english, compact: false, now: Fixtures.now)
            XCTAssertNil(p.channels[0]?.costMultiple)
            if key == "high" { XCTAssertNil(p.channels[0]?.ghostPosition) }
        }
        let compact = FaderBankPresentation(inputs: [input()], trial: .init(modelID: "m", configuration: .init("max")), publicationUsable: true, language: .english, compact: true, now: Fixtures.now)
        XCTAssertNil(compact.channels[0]?.costMultiple)
    }
    func testHoldDeadline520msSuppressesReleaseClickAndResetsBank() {
        var state = FaderBankController(); state.update(inputs: (0..<7).map { input("m\($0)") }, publicationUsable: true)
        _ = state.changeBank(2); state.beginLCDPress(modelID: "m6", at: 10)
        XCTAssertEqual(state.nextDeadline, 10.52); XCTAssertTrue(state.advance(at: 10.519).isEmpty)
        let intents = state.advance(at: 10.52)
        XCTAssertTrue(intents.contains(.favoritesChanged(["m6"]))); XCTAssertEqual(state.bank, 0)
        XCTAssertTrue(state.releaseLCD(inside: true, at: 11).isEmpty); XCTAssertNil(state.nextDeadline)
        XCTAssertEqual(state.ordered.first?.model.id, "m6")
        state.beginLCDPress(modelID: "m0", at: 20)
        XCTAssertTrue(state.releaseLCD(inside: true, at: 20.1).contains(.inspectModel("m0")))
    }
    func testNativeKeyboardOrderPreviewAndBankEndTrial() {
        var state = FaderBankController(); state.update(inputs: [input("six", current: .init("native2"), count: 6)], publicationUsable: true)
        _ = state.step(modelID: "six", upward: true); XCTAssertEqual(state.trial?.configuration.effort, "native3")
        state.preview(modelID: "six", key: "native5"); XCTAssertEqual(state.previewEffort, "native5")
        let p = FaderBankPresentation(inputs: state.inputs, trial: state.trial, previewModelID: state.previewModelID, previewEffort: state.previewEffort, publicationUsable: true, language: .english, compact: false, now: Fixtures.now)
        XCTAssertEqual(p.channels[0]?.previewPosition, 0)
        _ = state.changeBank(0); XCTAssertNil(state.trial); XCTAssertNil(state.previewEffort)
    }
    func testInvalidPublicationTierAndUnknownMetricsStayUnavailable() {
        let p = FaderBankPresentation(inputs: [input()], publicationUsable: false, language: .english, compact: false, now: Fixtures.now)
        XCTAssertTrue(p.channels.allSatisfy { $0 == nil })
        let raw = input(); let model = InstrumentModel(id: raw.model.id, name: raw.model.name, efforts: raw.model.efforts, recommended: raw.model.recommended, current: .init("high", fast: true))
        var state = FaderBankController(); state.update(inputs: [.init(model: model)], publicationUsable: true)
        XCTAssertTrue(state.tryEffort(modelID: "m", key: "max").isEmpty); XCTAssertNil(state.trial)
    }
}

@MainActor final class FaderBankViewTests: XCTestCase {
    func testNativeRegionsFocusAXIncrementAndNoRepeatedRepaint() async throws {
        let view = FaderBankView(); var shown: HelpExplanation?
        view.onHelpChange = { value, _ in shown = value }
        let input = FaderChannelInput(model: Fixtures.model())
        try view.update(inputs: [input], publicationUsable: true, language: .english, compact: false, now: Fixtures.now)
        let slider = try XCTUnwrap(view.control(for: "fader.slot.0.travel")); XCTAssertTrue(slider.becomeFirstResponder())
        XCTAssertEqual(shown, view.presentation?.channels[0]?.travelHelp)
        XCTAssertTrue(slider.accessibilityPerformIncrement())
        XCTAssertEqual(view.controller.trial?.configuration.effort, "max")
        XCTAssertEqual(view.presentation?.channels[0]?.current, .init("high"))
        let requests = view.displayRequests, renders = view.surfaceRenders
        for _ in 0..<100 {
            try view.update(inputs: [input], publicationUsable: true, language: .english, compact: false, now: Fixtures.now)
        }
        XCTAssertEqual(view.controller.trial?.configuration.effort, "max")
        XCTAssertEqual(view.displayRequests, requests); XCTAssertEqual(view.surfaceRenders, renders)
        XCTAssertTrue(slider === view.control(for: "fader.slot.0.travel"))
        XCTAssertEqual(FaderTiming.glide, 0.28); XCTAssertEqual(FaderTiming.readingFade, 0.08)
    }
    func testNeutralRecipesNativeSixSettingsSpacingDensitiesAndCompactCost() async throws {
        let efforts = (0..<6).map { InstrumentEffort(key: "native\($0)", label: "E\($0)", ability: Fixtures.metric(Double($0)), cost: Fixtures.metric(Double($0 + 1)), time: Fixtures.metric(nil)) }
        let model = Fixtures.model(current: .init("native2"), rec: "native3", efforts: efforts)
        for language in [InstrumentLanguage.chinese, .english] { for compact in [false, true] {
            let view = FaderBankView(); view.onHelpChange = { _, _ in }
            try view.update(inputs: [.init(model: model)], publicationUsable: true, language: language, compact: compact, now: Fixtures.now,
                            trial: .init(modelID: model.id, configuration: .init("native5")))
            try view.recipe!.validate()
            let slider = try XCTUnwrap(view.recipe?.regions.first { $0.role == .slider })
            let ys = slider.detents.map { slider.top! + $0.position * (slider.bottom! - slider.top!) }.sorted()
            for i in ys.indices.dropFirst() { XCTAssertGreaterThanOrEqual(ys[i] - ys[i - 1], 20) }
            for scale in [1, 2] { XCTAssertEqual(try view.rasterImage(scale: scale).width, 330 * scale) }
            if compact && language == .english { XCTAssertNil(view.presentation?.channels[0]?.costMultiple) }
        }}
    }
    func testInvalidLayoutDoesNotReplaceCommittedStateOrControls() async throws {
        let view = FaderBankView(); view.onHelpChange = { _, _ in }
        try view.update(inputs: [.init(model: Fixtures.model())], publicationUsable: true, language: .english, compact: false, now: Fixtures.now)
        let previous = view.presentation, slider = view.control(for: "fader.slot.0.travel")
        view.setFrameSize(CGSize(width: 100, height: 100))
        XCTAssertNotNil(view.renderError); XCTAssertEqual(view.presentation, previous)
        XCTAssertTrue(slider === view.control(for: "fader.slot.0.travel"))
        view.setFrameSize(CGSize(width: 330, height: 320)); XCTAssertNil(view.renderError)
    }
}
