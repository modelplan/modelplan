// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanDock
@testable import ModelPlanSettings

final class DockPlacementPresentationTests: XCTestCase {
    func testInnerEdgeReportsActualRightPlacementAndPreservesIntent() throws {
        let frame = CGRect(x: 0, y: 0, width: 1200, height: 900)
        let displays = [DockDisplayArea(id: "main", frame: frame, visibleFrame: frame),
                        DockDisplayArea(id: "adjacent", frame: frame.offsetBy(dx: 1200, dy: 0), visibleFrame: frame.offsetBy(dx: 1200, dy: 0))]
        let layouts = [DockEdge.left, .right].map { edge in
            DockEdgeLayout(displayID: "main", edge: edge, expandedSize: CGSize(width: 60, height: 200),
                           sliverLength: 100, sliverThickness: 4, hoverRects: [CGRect(x: 0, y: 0, width: 60, height: 200)])
        }
        let intent = DockEdgePreference(displayID: "main", edge: .right, alongFraction: 0.5)
        let placement = try XCTUnwrap(DockEdgeGeometry.resolve(preference: intent, displays: displays, layouts: layouts,
                                                              pointer: nil, primaryID: "main"))
        XCTAssertEqual(placement.edge, .right); XCTAssertEqual(intent.edge, .right)
        var preferences = SettingsPreferences(); preferences.dockEdge = .right
        var context = SettingsPageContext(); context.displays = [.init(id: "main", name: "Fixture display")]
        context.dockPlacementObservation = try .init(displayID: placement.displayID, edge: .right,
            alongFraction: placement.alongFraction, recovering: false)
        let row = try XCTUnwrap(SettingsCatalogue.rows(preferences: preferences, context: context).first { $0.key == .dockEdge })
        XCTAssertEqual(row.title.english, "Preferred Quota Widget edge")
        XCTAssertTrue(row.subtitle.english.contains("Currently right"))
        XCTAssertTrue(row.subtitle.chinese.contains("当前位于右侧"))
        guard case .choice(let value, _) = row.value else { return XCTFail("saved choice missing") }
        XCTAssertEqual(value, "right"); XCTAssertEqual(preferences.dockEdge, .right)
    }
    func testMissingObservationDoesNotPretendThePreferenceIsActualPlacement() throws {
        var preferences = SettingsPreferences(); preferences.dockEdge = .left
        let rows = try SettingsCatalogue.rows(preferences: preferences, context: .init())
        for key in [SettingKey.dockEdge, .dockDisplay, .dockPosition] {
            let row = try XCTUnwrap(rows.first { $0.key == key })
            XCTAssertTrue(row.title.english.hasPrefix("Preferred"))
            XCTAssertTrue(row.subtitle.english.contains("has not been observed"))
            XCTAssertTrue(row.subtitle.chinese.contains("尚未观测"))
        }
    }
    func testActualFactsCanChangeWithoutRewritingSavedIntentOrExposingRawDisplayID() throws {
        let preferences = SettingsPreferences(); var context = SettingsPageContext()
        context.dockPlacementObservation = try .init(displayID: "opaque-display-id", edge: .bottom, alongFraction: 0.25, recovering: false)
        let row = try XCTUnwrap(SettingsCatalogue.rows(preferences: preferences, context: context).first { $0.key == .dockEdge })
        XCTAssertTrue(row.subtitle.english.contains("Currently bottom")); XCTAssertTrue(row.subtitle.english.contains("25.0%"))
        XCTAssertFalse(row.subtitle.english.contains("opaque-display-id")); XCTAssertFalse(row.subtitle.english.contains("recovery"))
        XCTAssertEqual(preferences.dockEdge, .right)
        XCTAssertThrowsError(try SettingsDockPlacementObservation(displayID: "screen", edge: .left, alongFraction: .nan, recovering: true))
    }
    /// G3-27: the top edge is a saved choice of its own and reports where the widget actually is.
    func testTopEdgeIsOfferedSavedAndReportedBelowTheMenuBar() throws {
        var preferences = SettingsPreferences(); preferences.dockEdge = .top
        let decoded = try JSONDecoder().decode(SettingsPreferences.self, from: JSONEncoder().encode(preferences))
        XCTAssertEqual(decoded.dockEdge, .top)
        var context = SettingsPageContext()
        context.dockPlacementObservation = try .init(displayID: "screen", edge: .top, alongFraction: 0.5, recovering: false)
        let row = try XCTUnwrap(SettingsCatalogue.rows(preferences: preferences, context: context).first { $0.key == .dockEdge })
        guard case .choice(let value, let options) = row.value else { return XCTFail("saved choice missing") }
        XCTAssertEqual(value, "top"); XCTAssertTrue(options.contains("top"))
        XCTAssertTrue(row.subtitle.english.contains("Currently top")); XCTAssertTrue(row.subtitle.chinese.contains("当前位于顶部"))
    }
}
