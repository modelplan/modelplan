// SPDX-License-Identifier: MIT
import Foundation
import XCTest
@testable import ModelPlanCockpitShell

final class CockpitGeometryTests: XCTestCase {
    // Injected test dimensions, not a frozen official presentation profile.
    private let metrics = CockpitMetrics(contentWidth: 620, silhouetteWidth: 636,
                                         closedFullHeight: 683, closedCompactHeight: 601)

    private func fit(height: CGFloat, width: CGFloat = 1200, origin: CGPoint = .zero,
                     anchor: CGFloat = 800, window: CockpitWindowState = .init()) throws -> CockpitFit {
        try XCTUnwrap(CockpitLayout.fit(.init(usableFrame: CGRect(origin: origin, size: CGSize(width: width, height: height)),
                                            anchorX: anchor, anchorOffset: 584), metrics: metrics, window: window))
    }

    func testExactTierBoundariesInAlreadyUsableNativePoints() throws {
        for (height, tier, body) in [(CGFloat(930), CockpitHeightTier.full, CGFloat(890)),
                                     (929.999, .compact, 640), (680, .compact, 640),
                                     (679.999, .collapsed, 601)] {
            let result = try fit(height: height)
            XCTAssertEqual(result.tier, tier)
            XCTAssertEqual(result.unscaledBodyHeight, body)
            XCTAssertEqual(result.scale, 1)
        }
        // A study viewport with a 26 pt menu exclusion maps to native usable points once.
        XCTAssertEqual(try fit(height: 956 - 26).tier, .full)
        XCTAssertEqual(try fit(height: 706 - 26).tier, .compact)
    }

    func testUserClosureShrinksBodyAndKeepsVisibleTopAtSixPoints() throws {
        let open = try fit(height: 1000)
        let closed = try fit(height: 1000, window: .init(userClosed: true))
        XCTAssertEqual(closed.tier, .collapsed)
        XCTAssertEqual(closed.profile, .full)
        XCTAssertFalse(closed.forcedClosed)
        XCTAssertEqual(open.contentFrame.height - closed.contentFrame.height, 207)
        XCTAssertEqual(open.contentFrame.maxY, closed.contentFrame.maxY)
        XCTAssertEqual(1000 - closed.contentFrame.maxY, 6)
        XCTAssertEqual(closed.occupiedFrame.maxY, closed.contentFrame.maxY)
        XCTAssertEqual(closed.contentFrame.minY - closed.occupiedFrame.minY, 34)
    }

    func testCompactClosureUsesItsOwnInjectedHeight() throws {
        let result = try fit(height: 800, window: .init(userClosed: true))
        XCTAssertEqual(result.profile, .compact)
        XCTAssertEqual(result.unscaledBodyHeight, 601)
        XCTAssertEqual(result.scale, 1)
        // A future pinned profile can change closed geometry without changing the fitter.
        let alternative = CockpitMetrics(contentWidth: 620, silhouetteWidth: 636,
                                          closedFullHeight: 700, closedCompactHeight: 610)
        let changed = try XCTUnwrap(CockpitLayout.fit(.init(usableFrame: CGRect(x: 0, y: 0, width: 1200, height: 800),
                                                          anchorX: 800, anchorOffset: 584),
                                                     metrics: alternative, window: .init(userClosed: true)))
        XCTAssertEqual(changed.unscaledBodyHeight, 610)
    }

    func testShortScreensScaleWholeBodyAndReserveAndInvertInput() throws {
        for height in [CGFloat(600), 520] {
            let origin = CGPoint(x: -1500, y: 900)
            let result = try fit(height: height, origin: origin, anchor: -600)
            XCTAssertTrue(result.forcedClosed)
            XCTAssertEqual(result.tier, .collapsed)
            XCTAssertEqual(result.scale, (height - 6) / 635, accuracy: 1e-10)
            XCTAssertEqual(origin.y + height - result.contentFrame.maxY, 6, accuracy: 1e-10)
            XCTAssertEqual(result.contentFrame.width / 620, result.scale, accuracy: 1e-10)
            XCTAssertEqual(result.contentFrame.height / 601, result.scale, accuracy: 1e-10)
            XCTAssertEqual(result.contentFrame.minY - result.occupiedFrame.minY, 34 * result.scale, accuracy: 1e-10)
            XCTAssertEqual(result.occupiedFrame.minY, origin.y, accuracy: 1e-10)
            for p in [CGPoint.zero, CGPoint(x: 310, y: 200), CGPoint(x: 620, y: 635)] {
                let back = result.localPoint(from: result.screenPoint(from: p))
                XCTAssertEqual(back.x, p.x, accuracy: 1e-9)
                XCTAssertEqual(back.y, p.y, accuracy: 1e-9)
            }
        }
    }

    func testForcedCollapseThatAlreadyFitsDoesNotShrink() throws {
        let result = try fit(height: 660)
        XCTAssertTrue(result.forcedClosed)
        XCTAssertEqual(result.scale, 1)
        XCTAssertEqual(result.contentFrame.maxY, 654)
    }

    func testBothHorizontalEdgesContainOverhangAndKeepAnchorWhenPossible() throws {
        let middle = try fit(height: 1000)
        XCTAssertEqual(middle.contentFrame.minX + 584, 800)
        for anchor in [CGFloat(-10000), 10000] {
            let result = try fit(height: 1000, width: 900, origin: CGPoint(x: -900, y: -400), anchor: anchor)
            XCTAssertGreaterThanOrEqual(result.occupiedFrame.minX, -900)
            XCTAssertLessThanOrEqual(result.occupiedFrame.maxX, 0)
            XCTAssertEqual(600 - result.contentFrame.maxY, 6)
        }
        let narrow = try fit(height: 520, width: 400)
        XCTAssertTrue(narrow.forcedClosed)
        XCTAssertEqual(narrow.scale, 400 / 636, accuracy: 1e-10)
        XCTAssertEqual(narrow.occupiedFrame.width, 400, accuracy: 1e-10)
    }

    func testContainmentAcrossDisplayOriginsSizesAndPreferences() throws {
        for origin in [CGPoint.zero, CGPoint(x: -1920, y: -1080), CGPoint(x: 0, y: 1080)] {
            for width in [CGFloat(320), 636, 1440] {
                for height in [CGFloat(100), 520, 600, 641, 679, 680, 929, 930, 1200] {
                    for userClosed in [false, true] {
                        // A width-only failure while open is unavailable; it does not alter the height tiers.
                        if width < metrics.silhouetteWidth && height >= 680 && !userClosed { continue }
                        let result = try fit(height: height, width: width, origin: origin,
                                             window: .init(userClosed: userClosed))
                        let area = CGRect(origin: origin, size: CGSize(width: width, height: height))
                        XCTAssertGreaterThan(result.scale, 0)
                        XCTAssertLessThanOrEqual(result.scale, 1)
                        XCTAssertGreaterThanOrEqual(result.occupiedFrame.minX + 1e-8, area.minX)
                        XCTAssertGreaterThanOrEqual(result.occupiedFrame.minY + 1e-8, area.minY)
                        XCTAssertLessThanOrEqual(result.occupiedFrame.maxX, area.maxX + 1e-8)
                        XCTAssertEqual(result.occupiedFrame.maxY, area.maxY - 6, accuracy: 1e-8)
                    }
                }
            }
        }
    }

    func testBackingDensityDoesNotChangeLogicalPlacementOrHitCoordinates() throws {
        let result = try fit(height: 520)
        let logical = CGPoint(x: 250.25, y: 500.5)
        for density in [CGFloat(1), 2] {
            let screen = result.screenPoint(from: logical)
            let pixels = CGPoint(x: screen.x * density, y: screen.y * density)
            let back = result.localPoint(from: CGPoint(x: pixels.x / density, y: pixels.y / density))
            XCTAssertEqual(back.x, logical.x, accuracy: 1e-9)
            XCTAssertEqual(back.y, logical.y, accuracy: 1e-9)
        }
    }

    func testNoUsableAreaAndInvalidAnchorsAreUnavailable() {
        for area in [CGRect.zero, .null, .infinite, CGRect(x: 0, y: 0, width: 900, height: 6),
                     CGRect(x: 0, y: 0, width: 900, height: CGFloat.nan)] {
            XCTAssertNil(CockpitLayout.fit(.init(usableFrame: area, anchorX: 0, anchorOffset: 0),
                                           metrics: metrics, window: .init()))
        }
        for offset in [CGFloat(-1), 621, .infinity, .nan] {
            XCTAssertNil(CockpitLayout.fit(.init(usableFrame: CGRect(x: 0, y: 0, width: 900, height: 1000),
                                                anchorX: 0, anchorOffset: offset), metrics: metrics, window: .init()))
        }
        XCTAssertNil(CockpitLayout.fit(.init(usableFrame: CGRect(x: 0, y: 0, width: 400, height: 1000),
                                            anchorX: 200, anchorOffset: 310), metrics: metrics, window: .init()))
    }
}
