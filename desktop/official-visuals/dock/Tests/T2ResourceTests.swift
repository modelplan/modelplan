// SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0
import XCTest
import ImageIO
@testable import ModelPlanOfficialDock

final class T2ResourceTests: XCTestCase {
    func testAcceptedOriginalLayersAreBundledHashVerifiedAndDecodable() throws {
        let records = try T2BundledArtwork.records()
        XCTAssertEqual(records.count, 21)
        XCTAssertEqual(records.keys.filter { $0.hasSuffix(".webp") }.count, 16)
        XCTAssertEqual(records.keys.filter { $0.hasSuffix(".png") }.count, 5)
        for (name, record) in records {
            let data = try T2BundledArtwork.data(name)
            XCTAssertEqual(data.count, record.bytes)
            let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
            let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
            XCTAssertGreaterThan(image.width, 0); XCTAssertGreaterThan(image.height, 0)
        }
    }
    func testUnknownResourceCannotBecomeAnUnverifiedPath() {
        XCTAssertThrowsError(try T2BundledArtwork.data("../unregistered.png"))
        XCTAssertThrowsError(try T2BundledArtwork.data("missing.png"))
    }
}
