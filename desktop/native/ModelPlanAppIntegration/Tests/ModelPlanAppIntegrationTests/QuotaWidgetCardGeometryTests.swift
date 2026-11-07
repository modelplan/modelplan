// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanOfficialDock

final class QuotaWidgetCardGeometryTests: XCTestCase {
    func testReportedStructuralMeasurements() {
        XCTAssertEqual(QuotaWidgetCardGeometry.plateWidth, 304)
        XCTAssertEqual(QuotaWidgetCardGeometry.plateRadius, 12)
        XCTAssertEqual(QuotaWidgetCardGeometry.plateVerticalPadding, 10)
        XCTAssertEqual(QuotaWidgetCardGeometry.plateHorizontalPadding, 11)
        XCTAssertEqual(QuotaWidgetCardGeometry.lcdRadius, 8)
        XCTAssertEqual(QuotaWidgetCardGeometry.lcdVerticalPadding, 5)
        XCTAssertEqual(QuotaWidgetCardGeometry.lcdHorizontalPadding, 7)
        XCTAssertEqual(QuotaWidgetCardGeometry.headingIconSize, 20)
        XCTAssertEqual(QuotaWidgetCardGeometry.headingGap, 8)
        XCTAssertEqual(QuotaWidgetCardGeometry.headingBottomGap, 7)
        XCTAssertEqual(QuotaWidgetCardGeometry.rowFixedColumns, [56, 78, 34])
        XCTAssertEqual(QuotaWidgetCardGeometry.rowColumnGap, 5)
        XCTAssertEqual(QuotaWidgetCardGeometry.rowMinimumHeight, 19)
        XCTAssertEqual(QuotaWidgetCardGeometry.rowVerticalMargin, 2)
        XCTAssertEqual(QuotaWidgetCardGeometry.barSegments, 10)
        XCTAssertEqual(QuotaWidgetCardGeometry.barHeight, 7)
        XCTAssertEqual(QuotaWidgetCardGeometry.barSegmentGap, 1.5)
        XCTAssertEqual(QuotaWidgetCardGeometry.arrowTransverseSize, 16)
        XCTAssertEqual(QuotaWidgetCardGeometry.arrowTipBeyondRing, 2)
        XCTAssertEqual(QuotaWidgetCardGeometry.arrowPlateOverlap, 1)
    }

    func testSpacingRequiresActualPositiveDiameter() {
        XCTAssertEqual(QuotaWidgetCardGeometry.anchorSpacing(nozzleDiameter: 52), 12)
        XCTAssertEqual(QuotaWidgetCardGeometry.anchorSpacing(nozzleDiameter: 26), 6)
        XCTAssertNil(QuotaWidgetCardGeometry.anchorSpacing(nozzleDiameter: 0))
        XCTAssertNil(QuotaWidgetCardGeometry.anchorSpacing(nozzleDiameter: .infinity))
    }

    func testColumnsAndSegmentsUseAvailableWidth() throws {
        XCTAssertEqual(QuotaWidgetCardGeometry.rowColumnWidths(availableWidth: 200), [56, 78, 34, 17])
        XCTAssertNil(QuotaWidgetCardGeometry.rowColumnWidths(availableWidth: 174))
        XCTAssertNil(QuotaWidgetCardGeometry.rowColumnWidths(availableWidth: .infinity))
        XCTAssertEqual(try XCTUnwrap(QuotaWidgetCardGeometry.barSegmentWidth(availableWidth: 113.5)), 10, accuracy: 0.0001)
        XCTAssertNil(QuotaWidgetCardGeometry.barSegmentWidth(availableWidth: 13))
    }

    func testPlacementPrefersFittingCandidateAndFlipsWhenNeeded() throws {
        let frame = CGRect(x: 0, y: 0, width: 400, height: 400)
        let anchor = CGRect(x: 370, y: 170, width: 20, height: 20)
        let preferred = CGRect(x: 390, y: 140, width: 100, height: 100)
        let opposite = CGRect(x: 270, y: 140, width: 100, height: 100)
        let result = try XCTUnwrap(QuotaWidgetCardGeometry.place(anchorRing: anchor, preferred: preferred, flipped: opposite, available: frame))
        XCTAssertEqual(result.plate, opposite)
        XCTAssertEqual(result.anchorRing, anchor)
        XCTAssertTrue(result.flipped)
        let fits = try XCTUnwrap(QuotaWidgetCardGeometry.place(anchorRing: anchor, preferred: opposite, flipped: preferred, available: frame))
        XCTAssertEqual(fits.plate, opposite)
        XCTAssertFalse(fits.flipped)
    }

    func testPlacementClampsWithinAvailableFrameWithoutMovingAnchor() throws {
        let frame = CGRect(x: 10, y: 20, width: 200, height: 150)
        let anchor = CGRect(x: 140, y: 25, width: 20, height: 20)
        let preferred = CGRect(x: -10, y: -10, width: 100, height: 80)
        let flipped = CGRect(x: 170, y: 150, width: 100, height: 80)
        let result = try XCTUnwrap(QuotaWidgetCardGeometry.place(anchorRing: anchor, preferred: preferred, flipped: flipped, available: frame))
        XCTAssertTrue(frame.contains(result.plate))
        XCTAssertEqual(result.plate, CGRect(x: 10, y: 20, width: 100, height: 80))
        XCTAssertEqual(result.anchorRing, anchor)
    }

    func testPlacementFlipsWhenClampedPreferredOverlapsRing() throws {
        let frame = CGRect(x: 0, y: 0, width: 200, height: 100)
        let anchor = CGRect(x: 20, y: 30, width: 20, height: 20)
        let preferred = CGRect(x: -1, y: 0, width: 100, height: 100)
        let flipped = CGRect(x: 110, y: 0, width: 100, height: 100)
        let result = try XCTUnwrap(QuotaWidgetCardGeometry.place(anchorRing: anchor, preferred: preferred, flipped: flipped, available: frame))
        XCTAssertEqual(result.plate, CGRect(x: 100, y: 0, width: 100, height: 100))
        XCTAssertTrue(result.flipped)
    }

    func testPlacementRejectsWhenBothClampedCandidatesOverlapRing() {
        let frame = CGRect(x: 0, y: 0, width: 200, height: 100)
        let anchor = CGRect(x: 95, y: 30, width: 10, height: 20)
        let preferred = CGRect(x: -10, y: 0, width: 100, height: 100)
        let flipped = CGRect(x: 110, y: 0, width: 100, height: 100)
        XCTAssertNil(QuotaWidgetCardGeometry.place(anchorRing: anchor, preferred: preferred, flipped: flipped, available: frame))
    }

    func testPlacementAllowsEdgeTouchingRing() throws {
        let frame = CGRect(x: 0, y: 0, width: 200, height: 100)
        let anchor = CGRect(x: 100, y: 30, width: 10, height: 20)
        let preferred = CGRect(x: 0, y: 0, width: 100, height: 100)
        let flipped = CGRect(x: 100, y: 0, width: 100, height: 100)
        let result = try XCTUnwrap(QuotaWidgetCardGeometry.place(anchorRing: anchor, preferred: preferred, flipped: flipped, available: frame))
        XCTAssertEqual(result.plate, preferred)
        XCTAssertFalse(result.flipped)
    }

    func testPlacementRejectsMissingAnchorAndInsufficientOrInvalidFrame() {
        let candidate = CGRect(x: 0, y: 0, width: 100, height: 100)
        let frame = CGRect(x: 0, y: 0, width: 200, height: 200)
        XCTAssertNil(QuotaWidgetCardGeometry.place(anchorRing: nil, preferred: candidate, flipped: candidate, available: frame))
        XCTAssertNil(QuotaWidgetCardGeometry.place(anchorRing: .zero, preferred: candidate, flipped: candidate, available: frame))
        XCTAssertNil(QuotaWidgetCardGeometry.place(anchorRing: candidate, preferred: candidate, flipped: candidate, available: CGRect(x: 0, y: 0, width: 99, height: 100)))
        XCTAssertNil(QuotaWidgetCardGeometry.place(anchorRing: candidate, preferred: candidate, flipped: CGRect(x: 0, y: 0, width: 90, height: 100), available: frame))
    }
}
