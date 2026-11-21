// SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0
import Foundation
import ModelPlanEntrance
@testable import ModelPlanOfficialRocket
import XCTest
#if canImport(RealityKit)
import RealityKit
#endif

final class OfficialRocketTests: XCTestCase {
    func testPackVerifiesAndCarriesTheSharedGeometry() throws {
        let source = try OfficialRocket.source()
        XCTAssertNotEqual(source, RocketModelSource.communityDefault)
        let g = source.geometry
        XCTAssertEqual(g.glassVertices.count, 121)
        XCTAssertEqual(g.windowAnchorY, 12.835, accuracy: 1e-9)
        XCTAssertEqual(g.height, 14.2)
        XCTAssertEqual(g.skirtRadius, 1.2)
        let maxY = try XCTUnwrap(g.glassVertices.map(\.y).max()), maxX = try XCTUnwrap(g.glassVertices.map { abs($0.x) }.max())
        XCTAssertEqual(maxY, 13.27, accuracy: 0.01)
        XCTAssertEqual(maxX, 0.648, accuracy: 0.01)
        XCTAssertNotEqual(source.modelURL(for: .night), source.modelURL(for: .day))
    }

    func testAlteredBytesAreRefused() throws {
        let url = try OfficialRocket.verified("rocket-geometry.json")
        XCTAssertThrowsError(try OfficialRocket.verify(url, expected: String(repeating: "0", count: 64), name: "x")) {
            XCTAssertEqual($0 as? OfficialRocket.PackError, .altered("x"))
        }
        XCTAssertThrowsError(try OfficialRocket.verified("unregistered.usdz"))
    }

    /// D111.4 with the real glass and the real c01 outline: the end pose reaches the 80 % window overlap.
    func testD111EndPoseOverlapsTheRealCanopyWindowByAtLeast80Percent() throws {
        struct Fixture: Decodable { let points: [[Double]] }
        let url = try XCTUnwrap(Bundle.module.url(forResource: "c01-aperture-890", withExtension: "json"))
        let aperture = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url)).points.map { EntrancePoint($0[0], $0[1]) }
        let bounds = EntranceRect.bounds(aperture)
        let input = LiftOffInput(viewport: .init(width: 1470, height: 956), handoffDiameter: 496,
                                 tailPoint: .init(bounds.centre.x, 900), apertureRect: bounds)
        let rail = StoryboardRail(input: .init(liftOff: input, aperture: aperture, targetNoseY: 176), geometry: try OfficialRocket.source().geometry)
        print("official end IoU \(rail.endIoU) at elevation \(rail.endElevationDegrees)")
        XCTAssertGreaterThanOrEqual(rail.endIoU, StoryboardRail.minWindowIoU)
    }

    #if canImport(RealityKit)
    /// Both finishes load in RealityKit as the same model: every named part and anchor the entrance uses is
    /// present, at the official dimensions (14.2 m tall, 2.4 m skirt).
    @MainActor
    func testBothFinishesLoadInRealityKitWithTheEntranceAnchors() async throws {
        guard #available(macOS 15.0, *) else { throw XCTSkip("the native entrance needs macOS 15") }
        let source = try OfficialRocket.source()
        for theme in EntranceTheme.allCases {
            let url = try XCTUnwrap(source.modelURL(for: theme))
            let entity = try Entity.load(contentsOf: url)
            for name in ["anchor_window", "anchor_top", "anchor_base", "curved_canopy_glass", "engine_0", "T2_continuous_aft_face", "capsule_nose"] {
                XCTAssertNotNil(entity.findEntity(named: name), "\(theme): missing \(name)")
            }
            let top = try XCTUnwrap(entity.findEntity(named: "anchor_top")).position(relativeTo: nil)
            XCTAssertEqual(top.y, 14.2, accuracy: 0.01, "\(theme) height")
            let window = try XCTUnwrap(entity.findEntity(named: "anchor_window")).position(relativeTo: nil)
            XCTAssertEqual(window.y, 12.835, accuracy: 0.01, "\(theme) window anchor")
            let bounds = entity.visualBounds(relativeTo: nil)
            XCTAssertLessThanOrEqual(bounds.extents.x, 2.45, "\(theme) skirt")
            XCTAssertGreaterThanOrEqual(bounds.extents.x, 2.35, "\(theme) skirt")
            XCTAssertEqual(bounds.max.y, 14.2, accuracy: 0.05, "\(theme) top")
        }
    }
    #endif
}
