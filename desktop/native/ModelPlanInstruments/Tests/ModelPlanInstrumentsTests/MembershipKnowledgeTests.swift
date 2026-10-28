// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@testable import ModelPlanInstruments

private let membershipStates: [InstrumentMembershipKnowledge] = [.unknown, .unavailable, .reported]

private enum MembershipFixture {
    static let publication = SelectionPublication(publicationID: "synthetic-membership", selectionRevision: "r")
    static func input(knowledge: InstrumentMembershipKnowledge, fallback: Bool = false) throws -> InstrumentSurfaceInput {
        let model = Fixtures.model()
        let selection = InjectedModelSelection(publication: publication, scope: .all, orderedModelIDs: [model.id],
            selectedModelID: model.id, publicDefaultFallback: fallback)
        return try .init(observationID: "synthetic", columns: [], channels: [.init(model: model)],
            selection: selection, publication: publication, publicationUsable: !fallback, scope: .all,
            language: .english, now: Fixtures.now, compact: false,
            pages: [.init(.effort, effort: .init(models: [model], selection: selection, publication: publication,
                publicationUsable: !fallback, scope: .all, language: .english))], membershipKnowledge: knowledge)
    }
    static func frames() throws -> InstrumentSurfaceFrames {
        try .init(engines: .init(width: 1040, height: 240), console: .init(width: 1040, height: 440),
            mainScreen: .init(x: 0, y: 0, width: 600, height: 440), faders: .init(x: 640, y: 0, width: 400, height: 440))
    }
}

final class MembershipKnowledgeModelTests: XCTestCase {
    func testAllEmptyKnowledgeStatesHaveFixedDistinctLocalizedCopy() {
        let english = ["Subscription data not loaded", "Subscription data unavailable", "No reported subscription bindings"]
        let chinese = ["订阅数据尚未加载", "订阅数据不可用", "已报告的订阅绑定为空"]
        for (index, knowledge) in membershipStates.enumerated() {
            for (language, text) in [(InstrumentLanguage.english, english[index]), (.chinese, chinese[index])] {
                let p = EngineTablePresentation(columns: [], requestedPage: 0, scope: .all, language: language,
                    now: Fixtures.now, membershipKnowledge: knowledge)
                XCTAssertEqual(p.emptyLabel, text + " · modelplan doctor")
                XCTAssertEqual(p.membershipKnowledge, knowledge)
                XCTAssertEqual(p.tracks, 6); XCTAssertEqual(p.pageCount, 1)
            }
        }
    }
    func testLegacyCallsAndAggregateDefaultToUnknownWithoutMembershipInference() throws {
        let p = EngineTablePresentation(columns: [], requestedPage: 0, scope: .all, language: .english, now: Fixtures.now)
        XCTAssertEqual(p.membershipKnowledge, .unknown)
        let input = try InstrumentSurfaceInput(observationID: "empty", columns: [], channels: [], selection: nil,
            publication: nil, publicationUsable: false, scope: .all, language: .english, now: Fixtures.now, compact: false)
        XCTAssertEqual(input.membershipKnowledge, .unknown)
    }
    func testKnowledgeDoesNotChangeReportedIDsPaginationOrRealZeroAndStaleDoesNotBecomeZero() {
        let zero = EngineColumn(id: "reported", quotas: .init(windows: [Fixtures.quota("five", .fiveHours, 0)], now: Fixtures.now),
            todayTokens: 0, todayGenerationTPS: nil)
        let stale = EngineColumn(id: "reported", quotas: zero.quotas, todayTokens: 0, todayGenerationTPS: nil,
            evidence: .init(freshness: .stale))
        for knowledge in membershipStates {
            let p = EngineTablePresentation(columns: [zero], requestedPage: 0, scope: .all, language: .english,
                now: Fixtures.now, membershipKnowledge: knowledge)
            XCTAssertNil(p.emptyLabel); XCTAssertEqual(p.columns.compactMap { $0?.id }, ["reported"])
            XCTAssertEqual(p.columns[0]?.cells[0]?.amount, "0"); XCTAssertEqual(p.tracks, 3)
            let old = EngineTablePresentation(columns: [stale], requestedPage: 0, scope: .all, language: .english,
                now: Fixtures.now, membershipKnowledge: knowledge)
            XCTAssertNil(old.emptyLabel); XCTAssertEqual(old.columns[0]?.id, "reported")
            XCTAssertEqual(old.columns[0]?.cells[0]?.amount, "--")
            let many = EngineTablePresentation(columns: (0..<7).map { Fixtures.column("sub\($0)") }, requestedPage: 1,
                scope: .all, language: .english, now: Fixtures.now, membershipKnowledge: knowledge)
            XCTAssertEqual(many.pageCount, 2); XCTAssertEqual(many.page, 1); XCTAssertEqual(many.tracks, 6)
            XCTAssertEqual(many.columns.compactMap { $0?.id }, ["sub6"])
        }
    }
    func testCatalogueModePagesPublishedModelsButKeepsExactTrialGateClosed() {
        let inputs = (0..<7).map { FaderChannelInput(model: Fixtures.model(id: "model\($0)")) }
        var state = FaderBankController()
        state.update(inputs: inputs, publicationUsable: false)
        XCTAssertTrue(state.ordered.isEmpty, "Legacy unavailable-publication calls retain their behavior")
        state.update(inputs: inputs, publicationUsable: false, catalogueOnly: true)
        XCTAssertEqual(state.bankCount, 3)
        _ = state.changeBank(1)
        let p = FaderBankPresentation(inputs: state.inputs, requestedBank: state.bank, publicationUsable: false,
            language: .english, compact: false, now: Fixtures.now, catalogueOnly: state.catalogueOnly)
        XCTAssertNil(p.emptyLabel); XCTAssertEqual(p.channels.compactMap { $0?.id }, ["model3", "model4", "model5"])
        XCTAssertTrue(p.channels.compactMap { $0 }.allSatisfy { $0.current == nil && $0.trial == nil && $0.costMultiple == nil })
        XCTAssertTrue(state.tryEffort(modelID: "model3", key: "max").isEmpty); XCTAssertNil(state.trial)
    }
    func testCatalogueTransitionRetiresOldInteractionWithoutChangingTheExactMode() {
        let inputs = [FaderChannelInput(model: Fixtures.model())]
        var state = FaderBankController()
        state.update(inputs: inputs, publicationUsable: true)
        _ = state.tryEffort(modelID: "model", key: "max")
        state.beginLCDPress(modelID: "model", at: 0)
        state.preview(modelID: "model", key: "low"); state.setSourceHighlight("model")
        XCTAssertNotNil(state.trial); XCTAssertNotNil(state.nextDeadline); XCTAssertNotNil(state.previewModelID)
        state.update(inputs: inputs, publicationUsable: false, catalogueOnly: true)
        XCTAssertNil(state.trial); XCTAssertNil(state.nextDeadline); XCTAssertNil(state.previewModelID)
        XCTAssertNil(state.draggingModelID); XCTAssertNil(state.sourceHighlightID)
        let p = FaderBankPresentation(inputs: inputs, sourceModelID: "model", draggingModelID: "model", dragPosition: 0.5,
            previewModelID: "model", previewEffort: "low", publicationUsable: false, language: .english,
            compact: false, now: Fixtures.now, catalogueOnly: true)
        XCTAssertNil(p.channels[0]?.dragPosition); XCTAssertNil(p.channels[0]?.previewPosition)
        XCTAssertFalse(p.channels[0]?.sourceHighlighted ?? true)
        state.update(inputs: inputs, publicationUsable: true)
        XCTAssertFalse(state.catalogueOnly)
        XCTAssertFalse(state.tryEffort(modelID: "model", key: "max").isEmpty)
    }
}

@MainActor final class MembershipKnowledgeViewTests: XCTestCase {
    func testEmptyCopyUsesExistingTextAreaAndRoutesAndSurvivesInternalReflow() async throws {
        let view = EngineTableView()
        var textRect: CGRect?, regionIDs: [String]?
        for knowledge in membershipStates {
            try view.update(columns: [], language: .english, now: Fixtures.now, membershipKnowledge: knowledge)
            XCTAssertEqual(view.presentation?.membershipKnowledge, knowledge)
            let command = try XCTUnwrap(view.recipe?.commands.compactMap { command -> EngineTextCommand? in
                if case .text(let text) = command, text.id == "engine.empty.message" { return text }; return nil
            }.first)
            if let textRect { XCTAssertEqual(command.rect, textRect) } else { textRect = command.rect }
            if let regionIDs { XCTAssertEqual(view.recipe?.regions.map(\.id), regionIDs) }
            else { regionIDs = view.recipe?.regions.map(\.id) }
            XCTAssertTrue(view.recipe!.regions.filter { $0.id.hasSuffix(".body") }.allSatisfy { $0.intent == .openSubscriptionsSettings })
            view.setFrameSize(view.frame.size)
            XCTAssertEqual(view.presentation?.membershipKnowledge, knowledge)
        }
        try view.update(columns: [], language: .english, now: Fixtures.now)
        XCTAssertEqual(view.presentation?.membershipKnowledge, .unknown)
        view.dispose()
    }
    func testAggregatePassesExplicitKnowledgeToTheExistingEngineView() async throws {
        let surface = InstrumentSurfaceView()
        for knowledge in membershipStates {
            try surface.update(MembershipFixture.input(knowledge: knowledge), frames: MembershipFixture.frames())
            try surface.setPresentationAllowed(true)
            XCTAssertEqual(surface.engineTable.presentation?.membershipKnowledge, knowledge)
            XCTAssertEqual(surface.engineTable.presentation?.emptyLabel, knowledge.emptyLabel(language: .english))
            XCTAssertEqual(surface.faders.presentation?.channels[0]?.current, EffortConfiguration("high"),
                           "Membership copy knowledge does not revoke separately verified Current facts")
        }
        surface.dispose()
    }
    func testMissingPersonalMembershipDoesNotBlankCatalogueFadersOrEnableExactComparison() async throws {
        let surface = InstrumentSurfaceView()
        for knowledge in membershipStates {
            try surface.update(MembershipFixture.input(knowledge: knowledge, fallback: true), frames: MembershipFixture.frames())
            try surface.setPresentationAllowed(true)
            XCTAssertEqual(surface.faders.presentation?.channels.compactMap { $0?.id }, ["model"])
            XCTAssertNil(surface.faders.presentation?.channels[0]?.current)
            XCTAssertEqual(surface.faders.presentation?.channels[0]?.state, "--")
            surface.mainScreen.selectPage(.init(.effort))
            XCTAssertEqual(surface.mainScreen.controller.pages.first?.effort?.orderedIDs, ["model"])
            surface.mainScreen.openComparison(modelID: "model", from: .fader("model"), toggle: false)
            XCTAssertNil(surface.mainScreen.controller.trial)
            XCTAssertThrowsError(try surface.faders.setTrial(.init(modelID: "model", configuration: .init("max"))))
        }
        surface.dispose()
    }
}
