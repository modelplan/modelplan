// SPDX-License-Identifier: MIT
import XCTest
import ModelPlanDock
import ModelPlanOfficialDock

final class V08QuotaBandTests: XCTestCase {
    func testV09VendorIdentityDoesNotChangeQuotaStatus() throws {
        let bands: [(Double, DockQuotaStatus)] = [
            (0, .critical), (25, .critical), (26, .warning),
            (40, .warning), (41, .warning), (50, .warning), (51, .normal), (100, .normal)
        ]
        for vendor in ["cursor", "copilot", "opencode", "qwen"] {
            for (remaining, expected) in bands {
                let window = DockQuotaWindowInput(id: "synthetic", period: .fiveHour, label: "5h", remainingPercent: remaining, resetsAt: nil, durationSeconds: nil)
                var input = DockInstrumentInput(id: "synthetic", name: "Synthetic", windows: [window])
                input.dataState = .fresh
                input.vendorResourceKey = vendor
                let reading = try DockInstrumentProjection.evaluate(input, now: Date(timeIntervalSince1970: 0), redBelow: 25)
                XCTAssertEqual(reading.status, expected, "\(vendor) at \(remaining)%")
                XCTAssertEqual(reading.outer?.status, expected)
            }
        }
    }
    func testV09StatusInksAreNotBrandOrVendorIdentityColours() throws {
        let coordinates = T2EdgeCoordinates(edge: .right, width: 300, height: 400, menuBarExclusion: 26)
        let geometry = try T2Geometry.make(subscriptions: [.init(id: "synthetic")], input: T2GeometryInput(coordinates: coordinates))
        let skin = try T2DockSkin.make(geometry: geometry, rows: [], showsPercentages: true)
        let identityRGB: [[Double]] = [
            [223, 96, 76], [238, 242, 246], [192, 140, 255], [181, 214, 90], [255, 106, 0]
        ]
        for name in ["normal", "warning", "critical"] {
            let ink = try XCTUnwrap(skin.palette[name])
            for rgb in identityRGB {
                let same = zip([ink.r, ink.g, ink.b], rgb).allSatisfy { pair in abs(pair.0 - pair.1 / 255) < 0.000001 }
                XCTAssertFalse(same, "Status role \(name) must not use a brand or vendor colour")
            }
        }
    }
    func testV08ProductionSkinUsesReviewedNightStatusColours() throws {
        let coordinates = T2EdgeCoordinates(edge: .right, width: 300, height: 400, menuBarExclusion: 26)
        let geometry = try T2Geometry.make(subscriptions: [.init(id: "synthetic")], input: T2GeometryInput(coordinates: coordinates))
        let skin = try T2DockSkin.make(geometry: geometry, rows: [], showsPercentages: true)
        for (name, channels) in [("normal", [90.0, 217, 186]), ("warning", [234.0, 193, 123]), ("critical", [239.0, 68, 68])] {
            let ink = try XCTUnwrap(skin.palette[name])
            XCTAssertEqual(ink.r, channels[0] / 255, accuracy: 0.000001)
            XCTAssertEqual(ink.g, channels[1] / 255, accuracy: 0.000001)
            XCTAssertEqual(ink.b, channels[2] / 255, accuracy: 0.000001)
            XCTAssertEqual(ink.a, 1, accuracy: 0.000001)
        }
    }
    func testV08RemainingQuotaBandsAtBothThresholds() throws {
        let cases: [(Double, DockQuotaStatus, DockQuotaStatus)] = [
            (100, .normal, .normal), (51, .normal, .normal),
            (50, .warning, .warning), (41, .warning, .warning),
            (40, .warning, .warning), (26, .warning, .warning),
            (25, .critical, .warning), (10, .critical, .critical), (0, .critical, .critical)
        ]
        for (remaining, threshold25, threshold10) in cases {
            let window = DockQuotaWindowInput(id: "synthetic", period: .fiveHour, label: "5h", remainingPercent: remaining, resetsAt: nil, durationSeconds: nil)
            var input = DockInstrumentInput(id: "synthetic", name: "Synthetic", windows: [window])
            input.dataState = .fresh
            for (threshold, expected) in [(25.0, threshold25), (10.0, threshold10)] {
                let reading = try DockInstrumentProjection.evaluate(input, now: Date(timeIntervalSince1970: 0), redBelow: threshold)
                XCTAssertEqual(reading.status, expected, "remaining=\(remaining), threshold=\(threshold)")
                XCTAssertEqual(reading.outer?.status, expected)
            }
        }
    }
}
