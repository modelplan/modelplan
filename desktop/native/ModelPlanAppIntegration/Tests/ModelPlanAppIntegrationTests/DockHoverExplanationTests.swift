// SPDX-License-Identifier: MIT
import XCTest
import ModelPlanInstruments
@testable import ModelPlanAppIntegration

/// G3-10 / S-07: each hovered or focused Quota Widget element has its catalogue explanation,
/// and the nozzle only promises a refresh click when refresh is available.
@MainActor final class DockHoverExplanationTests: XCTestCase {
    func testEveryWidgetElementHasItsExplanationInBothLanguages() throws {
        for language in [InstrumentLanguage.english, .chinese] {
            let catalog = HelpCatalog(language)
            let cases: [(String, HelpTopic)] = [
                ("dock.rings.a", .ring), ("dock.nozzle.a", .nozzle), ("dock.number.a", .dockQuota),
                ("dock.notice.a", .event), ("dock.grip.0", .dockMove), ("dock.move", .dockMove), ("dock.ignition", .ignition),
            ]
            for (anchor, topic) in cases {
                let shown = try XCTUnwrap(DockHoverExplanation.explanation(anchorID: anchor, language: language, refreshAvailable: true), anchor)
                XCTAssertEqual(shown, catalog.explanation(topic), anchor)
            }
            XCTAssertNil(DockHoverExplanation.explanation(anchorID: "dock.card", language: language, refreshAvailable: true))
            let noRefresh = try XCTUnwrap(DockHoverExplanation.explanation(anchorID: "dock.nozzle.a", language: language, refreshAvailable: false))
            XCTAssertEqual(noRefresh.title, catalog.explanation(.nozzle).title)
            XCTAssertFalse(noRefresh.body.contains(language == .chinese ? "刷新" : "refresh"))
            XCTAssertFalse(catalog.explanation(.dockMove).body.contains(language == .chinese ? "预览" : "preview"),
                           "the widget itself is carried; there is no snap preview (owner 11-05)")
        }
    }
}
