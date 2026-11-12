// SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0
import CoreGraphics
import XCTest
@testable import ModelPlanOfficialDock
import ModelPlanDock

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

    /// D65 (owner): a window that is used up is painted red on purpose, as a status signal, so these inks may sit
    /// near the brand reds. Nothing else may; add a key here only for an ink that carries a status.
    static let statusInks: Set<String> = ["usedUpTrack", "usedUpFace", "usedUpMark"]

    private func nearBrandRed(_ palette: [String: (r: Double, g: Double, b: Double)], allowing status: Set<String>) -> [String] {
        palette.compactMap { key, ink in
            guard !status.contains(key) else { return nil }
            return [(223.0, 96.0, 76.0), (187.0, 52.0, 44.0)].contains { brand in
                max(abs(ink.r - brand.0), abs(ink.g - brand.1), abs(ink.b - brand.2)) <= 20
            } ? key : nil
        }.sorted()
    }

    func testRuleCatchesANonStatusInkNearTheBrandReds() {
        let probe: [String: (r: Double, g: Double, b: Double)] = [
            "decor": (225, 98, 78), "usedUpFace": (223, 96, 76), "calm": (90, 217, 186)]
        XCTAssertEqual(nearBrandRed(probe, allowing: Self.statusInks), ["decor"], "only the listed status inks may be red")
        XCTAssertEqual(nearBrandRed(probe, allowing: []), ["decor", "usedUpFace"])
    }

    func testNoInkExceptTheListedStatusInksIsCloseToTheBrandReds() throws {
        let inks = try palette()
        XCTAssertTrue(Self.statusInks.isSubset(of: Set(inks.keys)), "every listed status ink exists in the skin")
        XCTAssertEqual(nearBrandRed(inks, allowing: Self.statusInks), [], "an ink is too close to the brand reds")
    }

    /// COL-2.1-08 / COL-2.1-09: white means a real reading, blue #9FD2FF means announced (not yet in effect).
    /// A real reading is never inked with the notice blue, and the notice blue is the registry value.
    func testPaletteWhiteMeansRealAndBlueMeansAnnounced() throws {
        let geometry = try T2Geometry.make(subscriptions: [.init(id: "member-a")], input: .init(coordinates: .init(edge: .right, width: 1470, height: 956, menuBarExclusion: 26), diameter: 44))
        let skin = try T2DockSkin.make(geometry: geometry, rows: [], showsPercentages: true)
        let inks = try palette()
        XCTAssertEqual(skin.readoutPalette?["normal"], "lcdWhite", "a real reading above the amber band is white")
        let white = try XCTUnwrap(inks["lcdWhite"]), text = try XCTUnwrap(inks["text"])
        XCTAssertEqual(white.r, 233, accuracy: 0.001); XCTAssertEqual(white.g, 237, accuracy: 0.001); XCTAssertEqual(white.b, 240, accuracy: 0.001)
        XCTAssertEqual(text.r, 255, accuracy: 0.001); XCTAssertEqual(text.g, 255, accuracy: 0.001); XCTAssertEqual(text.b, 255, accuracy: 0.001)
        for key in (skin.readoutPalette ?? [:]).values {
            XCTAssertFalse(key.hasPrefix("notice"), "no real-reading ink may be a notice ink: \(key)")
        }
        let blue = try XCTUnwrap(inks["noticeBlue"])
        XCTAssertEqual(blue.r, 159, accuracy: 0.001, "#9FD2FF"); XCTAssertEqual(blue.g, 210, accuracy: 0.001); XCTAssertEqual(blue.b, 255, accuracy: 0.001)
        XCTAssertNotEqual(blue.b, white.b, "announced blue is not the real-reading white")
        for status in ["normal", "warning", "critical", "unknown"] {
            let ink = try XCTUnwrap(inks[status])
            XCTAssertGreaterThan(max(abs(ink.r - blue.r), abs(ink.g - blue.g), abs(ink.b - blue.b)), 20, "\(status) must not read as the announced blue")
        }
    }
}
