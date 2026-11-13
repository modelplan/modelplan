// SPDX-License-Identifier: MIT
import CoreGraphics
import XCTest
import ModelPlanDock
@testable import ModelPlanAppIntegration

@MainActor final class DockHelpAnchorSearchTests: XCTestCase {
    func testUsesOnlyVisibleRegisteredNonControlPoint() throws {
        let body = CGPath(rect: CGRect(x: 0, y: 0, width: 80, height: 80), transform: nil)
        let blocked = CGRect(x: 0, y: 0, width: 40, height: 80)
        let regions = DockBackgroundDragRegions(body: body, excludedControls: [blocked])
        let anchor = try XCTUnwrap(DockHelpAnchorSearch.find(paths: [body],
            visible: CGRect(x: 0, y: 0, width: 80, height: 80), contains: regions.contains))
        XCTAssertTrue(regions.contains(CGPoint(x: anchor.midX, y: anchor.midY)))
        XCTAssertFalse(blocked.contains(CGPoint(x: anchor.midX, y: anchor.midY)))
    }
    func testRejectsMissingOrUnhittableGeometryWithoutFallback() {
        let body = CGPath(rect: CGRect(x: 0, y: 0, width: 80, height: 80), transform: nil)
        XCTAssertNil(DockHelpAnchorSearch.find(paths: [], visible: CGRect(x: 0, y: 0, width: 80, height: 80), contains: { _ in true }))
        XCTAssertNil(DockHelpAnchorSearch.find(paths: [body], visible: CGRect(x: 0, y: 0, width: 80, height: 80), contains: { _ in false }))
        XCTAssertNil(DockHelpAnchorSearch.find(paths: [body], visible: .zero, contains: { _ in true }))
    }
}
