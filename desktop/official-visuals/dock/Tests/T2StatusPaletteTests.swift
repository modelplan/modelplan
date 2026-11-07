// SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0
import CoreGraphics
import XCTest
@testable import ModelPlanOfficialDock

/// COL-2.1-01/02/03, 12 and 17: the skin the production Dock draws from carries the registry's
/// status inks, and no ink in it is close to the brand reds (the ignition is approved bitmap art).
final class T2StatusPaletteTests: XCTestCase {
    private func palette() throws -> [String: (r: Double, g: Double, b: Double)] {
        let geometry = try T2Geometry.make(subscriptions: [.init(id: "member-a")], input: .init(coordinates: .init(edge: .right, width: 1470, height: 956, menuBarExclusion: 26), diameter: 44))
        return try T2DockSkin.make(geometry: geometry, rows: [], showsPercentages: true).palette
            .mapValues { (r: $0.r * 255, g: $0.g * 255, b: $0.b * 255) }
    }

    func testStatusInksAreTheRegistryValues() throws {
        let inks = try palette()
        for (key, want) in [("normal", (90.0, 217.0, 186.0)), ("warning", (234.0, 193.0, 123.0)), ("critical", (239.0, 68.0, 68.0))] {
            let ink = try XCTUnwrap(inks[key], key)
            XCTAssertEqual(ink.r, want.0, accuracy: 0.001, key)
            XCTAssertEqual(ink.g, want.1, accuracy: 0.001, key)
            XCTAssertEqual(ink.b, want.2, accuracy: 0.001, key)
        }
    }

    func testNoInkIsCloseToTheBrandReds() throws {
        for (key, ink) in try palette() {
            for brand in [(223.0, 96.0, 76.0), (187.0, 52.0, 44.0)] {
                let distance = max(abs(ink.r - brand.0), abs(ink.g - brand.1), abs(ink.b - brand.2))
                XCTAssertGreaterThan(distance, 20, "\(key) is too close to brand red")
            }
        }
    }
}
