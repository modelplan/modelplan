// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanInstruments

final class SelectionFallbackTests: XCTestCase {
    let publication = SelectionPublication(publicationID: "public-p", selectionRevision: nil)

    func testExplicitCatalogueFallbackSurvivesMissingPersonalAndOrdinaryUnavailableReason() {
        let selection = InjectedModelSelection(publication: publication, scope: .all, orderedModelIDs: ["model"],
                                               unavailableReason: "personal-unavailable", publicDefaultFallback: true,
                                               selectionNotice: "按公开默认")
        let page = EffortPagePresentation(models: [Fixtures.model()], selection: selection, scope: .all,
                                          publication: publication, publicationUsable: false, language: .chinese)
        XCTAssertEqual(page.models.map(\.id), ["model"]); XCTAssertNil(page.unavailableReason)
        XCTAssertTrue(page.publicDefaultFallback); XCTAssertEqual(page.selectionNotice, "按公开默认")
        XCTAssertNil(page.publication?.selectionRevision); XCTAssertNil(selection.publication.selectionRevision)
        XCTAssertNil(page.emptyStateNotice); XCTAssertFalse(selection.matchesExact(publication, scope: .all))
    }

    func testOrdinaryMissingRevisionStillRejectsAndDefaultsRemainCompatible() {
        let selection = InjectedModelSelection(publication: publication, scope: .all, orderedModelIDs: ["model"])
        XCTAssertFalse(selection.publicDefaultFallback); XCTAssertNil(selection.selectionNotice)
        XCTAssertTrue(selection.modelAvailabilityNotes.isEmpty)
        XCTAssertFalse(selection.matches(publication, scope: .all)); XCTAssertFalse(selection.matchesExact(publication, scope: .all))
        let page = EffortPagePresentation(models: [Fixtures.model()], selection: selection, scope: .all,
                                          publication: publication, publicationUsable: true)
        XCTAssertTrue(page.models.isEmpty); XCTAssertNotNil(page.emptyStateNotice)
        XCTAssertFalse(page.publicDefaultFallback)
    }

    func testFallbackNeverBypassesPublicationIdentityOrScope() {
        let selection = InjectedModelSelection(publication: publication, scope: .subscription("a"), orderedModelIDs: ["model"], publicDefaultFallback: true)
        for expected in [nil, SelectionPublication(publicationID: "", selectionRevision: nil),
                         .init(publicationID: "other", selectionRevision: nil)] {
            XCTAssertFalse(selection.matches(expected, scope: .subscription("a")))
            XCTAssertTrue(EffortPagePresentation(models: [Fixtures.model()], selection: selection, scope: .subscription("a"),
                                                 publication: expected, publicationUsable: false).models.isEmpty)
        }
        XCTAssertFalse(selection.matches(publication, scope: .all))
        XCTAssertFalse(selection.matches(publication, scope: .subscription("b")))
    }

    func testNoticeAndToolUseLabelsPreserveCallerOrderAndOnlyVisibleModels() {
        let selection = InjectedModelSelection(publication: publication, scope: .subscription("a"), orderedModelIDs: ["used", "tool"],
                                               publicDefaultFallback: true, selectionNotice: "Public defaults",
                                               modelAvailabilityNotes: ["tool": "Available in this tool; not subscription entitlement",
                                                                        "used": "Actually used; not subscription entitlement", "outside": "hidden"])
        let page = EffortPagePresentation(models: [Fixtures.model(id: "tool"), Fixtures.model(id: "used")], selection: selection,
                                          scope: .subscription("a"), publication: publication, publicationUsable: false)
        XCTAssertEqual(page.models.map(\.id), ["used", "tool"]); XCTAssertEqual(page.selectionNotice, "Public defaults")
        XCTAssertEqual(page.modelAvailabilityNotes["tool"], selection.modelAvailabilityNotes["tool"])
        XCTAssertEqual(page.modelAvailabilityNotes["used"], selection.modelAvailabilityNotes["used"])
        XCTAssertNil(page.modelAvailabilityNotes["outside"])
    }

    func testEmptyPublicDataHasAnExplanationAndDoesNotInventModels() {
        let selection = InjectedModelSelection(publication: publication, scope: .all, orderedModelIDs: ["missing"],
                                               publicDefaultFallback: true, selectionNotice: "按公开默认")
        let page = EffortPagePresentation(models: [], selection: selection, scope: .all,
                                          publication: publication, publicationUsable: false, language: .chinese)
        XCTAssertTrue(page.models.isEmpty); XCTAssertEqual(page.missingModelIDs, ["missing"])
        XCTAssertTrue(page.emptyStateNotice?.contains("暂无") == true); XCTAssertEqual(page.selectionNotice, "按公开默认")
        XCTAssertTrue(page.modelAvailabilityNotes.isEmpty)
    }

    func testKnownConflictingRevisionsStillRejectAndExactModeIsNeverAttestedByFallback() {
        let known = SelectionPublication(publicationID: "public-p", selectionRevision: "r1")
        let fallback = InjectedModelSelection(publication: known, scope: .all, orderedModelIDs: ["model"], publicDefaultFallback: true)
        XCTAssertTrue(fallback.matches(known, scope: .all)); XCTAssertFalse(fallback.matchesExact(known, scope: .all))
        XCTAssertFalse(fallback.matches(.init(publicationID: "public-p", selectionRevision: "r2"), scope: .all))
        let missing = InjectedModelSelection(publication: publication, scope: .all, orderedModelIDs: ["model"], publicDefaultFallback: true)
        XCTAssertTrue(missing.matches(known, scope: .all)); XCTAssertNil(missing.publication.selectionRevision)
        let comparison = EffortComparison(model: Fixtures.model(), trial: .init("max"), publicationUsable: false)
        XCTAssertTrue(comparison.panels.allSatisfy { $0.values == nil })
    }
}
