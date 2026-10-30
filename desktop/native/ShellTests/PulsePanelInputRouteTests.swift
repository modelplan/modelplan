// SPDX-License-Identifier: MIT
import XCTest
import AppKit
@testable import ModelPlanShell

@MainActor private final class Handler: PulsePanelMouseHandling {
    var accepts = true, downs = 0, drags = 0, ups = 0, cancels = 0
    func beginPanelMove(windowPoint: CGPoint, globalPoint: CGPoint) -> Bool { downs += 1; return accepts }
    func continuePanelMove(globalPoint: CGPoint) { drags += 1 }
    func finishPanelMove(globalPoint: CGPoint) { ups += 1 }
    func cancelPanelMove() { cancels += 1 }
}
@MainActor final class PulsePanelInputRouteTests: XCTestCase {
    func testAcceptedNativeTransactionReleasesExactlyOnce() {
        let route = PulsePanelInputRoute(), handler = Handler(); route.handler = handler
        XCTAssertTrue(route.begin(windowPoint: .zero, globalPoint: .zero, controlClick: false))
        XCTAssertTrue(route.drag(globalPoint: .init(x: 30, y: 40)))
        XCTAssertTrue(route.end(globalPoint: .init(x: 30, y: 40)))
        XCTAssertFalse(route.end(globalPoint: .zero)); route.cancel()
        XCTAssertEqual(handler.downs, 1); XCTAssertEqual(handler.drags, 1)
        XCTAssertEqual(handler.ups, 1); XCTAssertEqual(handler.cancels, 0)
    }
    func testControlsAndControlClickFallThroughWithoutCapture() {
        let route = PulsePanelInputRoute(), handler = Handler(); route.handler = handler
        XCTAssertFalse(route.begin(windowPoint: .zero, globalPoint: .zero, controlClick: true))
        XCTAssertEqual(handler.downs, 0)
        handler.accepts = false
        XCTAssertFalse(route.begin(windowPoint: .zero, globalPoint: .zero, controlClick: false))
        XCTAssertFalse(route.drag(globalPoint: .zero)); XCTAssertFalse(route.end(globalPoint: .zero))
        XCTAssertEqual(handler.drags, 0); XCTAssertEqual(handler.ups, 0)
    }
    func testHideOrReplacementCancelsHeldGestureWithoutLateDrop() {
        let route = PulsePanelInputRoute(), handler = Handler(); route.handler = handler
        XCTAssertTrue(route.begin(windowPoint: .zero, globalPoint: .zero, controlClick: false))
        route.cancel(); route.cancel()
        XCTAssertEqual(handler.cancels, 1)
        XCTAssertFalse(route.end(globalPoint: .zero)); XCTAssertEqual(handler.ups, 0)
    }
    func testAsymmetricNotchUsesDisplayCentreAndMissingCasesFailClosed() {
        let frame = CGRect(x: 0, y: 0, width: 1800, height: 1125)
        let left = CGRect(x: 0, y: 1093, width: 791, height: 32)
        let right = CGRect(x: 1012, y: 1093, width: 788, height: 32)
        XCTAssertEqual(PanelScreen.notch(in: frame, topInset: 32, left: left, right: right),
                       CGRect(x: 789.5, y: 1093, width: 221, height: 32))
        XCTAssertNil(PanelScreen.notch(in: frame, topInset: 0, left: left, right: right))
        XCTAssertNil(PanelScreen.notch(in: frame, topInset: 32, left: nil, right: right))
        XCTAssertNil(PanelScreen.notch(in: frame, topInset: 32, left: left, right: nil))
    }
}
