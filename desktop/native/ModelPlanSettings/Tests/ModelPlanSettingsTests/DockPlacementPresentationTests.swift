// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanDock
@testable import ModelPlanSettings

final class DockPlacementPresentationTests: XCTestCase {
    func testExposedEdgeRecoveryIsShownSeparatelyFromSavedRightIntent() throws {
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
        XCTAssertTrue(DockEdgeGeometry.exposedIntervals(on: displays[0], edge: .right, displays: displays).isEmpty)
        XCTAssertEqual(placement.edge, .left); XCTAssertEqual(intent.edge, .right)
        var preferences = SettingsPreferences(); preferences.dockEdge = .right
        var context = SettingsPageContext(); context.displays = [.init(id: "main", name: "Fixture display")]
        context.dockPlacementObservation = try .init(displayID: placement.displayID, edge: .left,
            alongFraction: placement.alongFraction, recovering: true)
        let row = try XCTUnwrap(SettingsCatalogue.rows(preferences: preferences, context: context).first { $0.key == .dockEdge })
        XCTAssertEqual(row.title.english, "Preferred Dock edge")
        XCTAssertTrue(row.subtitle.english.contains("Currently left"))
        XCTAssertTrue(row.subtitle.chinese.contains("当前位于左侧"))
        guard case .choice(let value, _) = row.value else { return XCTFail("saved choice missing") }
        XCTAssertEqual(value, "right"); XCTAssertEqual(preferences.dockEdge, .right)
    }
}
