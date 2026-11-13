// SPDX-License-Identifier: MIT
import XCTest
import AppKit
@testable import ModelPlanShell

@MainActor final class PulsePlacementTests: XCTestCase {
    private let room = CGRect(x: 0, y: 0, width: 1440, height: 900)
    private let rail = CGSize(width: 80, height: 180)
    private let panel = CGSize(width: 400, height: 450)
    func testFreshDefaultUsesRightRailAndWindow() {
        let model = PanelPlacement()
        let layout = model.layout(in: room, topEdge: room.maxY, panel: panel, rail: rail)
        XCTAssertEqual(model.dock, .edge(.right))
        XCTAssertEqual(layout.railOrigin.x + rail.width, room.maxX)
        XCTAssertEqual(layout.frame.maxX, room.maxX)
    }
    func testSavedExplicitLeftIsNotReplacedByDefault() {
        let model = PanelPlacement(dock: .edge(.left), verticalRatio: 0.25)
        let layout = model.layout(in: room, topEdge: room.maxY, panel: panel, rail: rail)
        XCTAssertEqual(layout.railOrigin.x, room.minX)
        XCTAssertEqual(layout.frame.minX, room.minX)
    }
    func testNegativeOriginDisplayStillPlacesAtItsRight() {
        let display = CGRect(x: -1440, y: 0, width: 1440, height: 900)
        let layout = PanelPlacement().layout(in: display, topEdge: display.maxY, panel: panel, rail: rail)
        XCTAssertEqual(layout.frame.maxX, 0)
        XCTAssertEqual(layout.railOrigin.x + rail.width, 0)
    }
    func testTransientPlacementDoesNotPersistAndCommitUsesOnlyInjectedSink() {
        let model = PanelPlacement(display: "saved-display")
        var writes: [PanelPlacement.SavedPlacement] = []
        model.onPersist = { writes.append($0) }
        model.record(dock: .edge(.bottom), horizontalRatio: 0.2, verticalRatio: 0.8, display: "chosen-display", persist: false)
        XCTAssertTrue(writes.isEmpty)
        model.record(dock: .edge(.left), horizontalRatio: 0.3, verticalRatio: 0.7, display: "chosen-display")
        XCTAssertEqual(writes.count, 1)
        XCTAssertEqual(writes[0].dock, .edge(.left))
        XCTAssertEqual(writes[0].display, "chosen-display")
    }
    func testLayoutOnFallbackDisplayDoesNotReplaceSavedUUID() {
        let model = PanelPlacement(display: "unplugged-display")
        var writes = 0; model.onPersist = { _ in writes += 1 }
        _ = model.layout(in: room, topEdge: room.maxY, panel: panel, rail: rail)
        XCTAssertEqual(model.display, "unplugged-display")
        XCTAssertEqual(writes, 0)
    }
    func testRailRatiosRoundTripWithoutWindowOriginLeak() {
        let origin = CGPoint(x: 1360, y: 360)
        let ratios = PanelPlacement.ratios(forRailAt: origin, in: room, rail: rail)
        let model = PanelPlacement(dock: .edge(.right), horizontalRatio: ratios.h, verticalRatio: ratios.v)
        let layout = model.layout(in: room, topEdge: room.maxY, panel: panel, rail: rail)
        XCTAssertEqual(layout.railOrigin.x, origin.x)
        XCTAssertEqual(layout.railOrigin.y - rail.height, origin.y, accuracy: 0.001)
    }
    func testCardGapIsCallerOwnedRatherThanUpstreamVisualConstant() {
        let value = PanelPlacement.cardRoom(edge: .bottom, railOrigin: .init(x: 10, y: 180), rail: rail, in: room, gap: 17)
        XCTAssertEqual(value, 703)
        XCTAssertNil(PanelPlacement.cardRoom(edge: .right, railOrigin: .zero, rail: rail, in: room, gap: 17))
    }
}
