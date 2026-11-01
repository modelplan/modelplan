// SPDX-License-Identifier: MIT
import Foundation
import XCTest
@testable import S1GalleryCore
import ModelPlanDock

@MainActor final class S1GalleryTests: XCTestCase {
    func testGoldenSelectedWeeklyClockUsesReportedReset() throws {
        let now = Date(timeIntervalSince1970: 1_792_506_300)
        let input = try XCTUnwrap(S1SyntheticProvider(count: 1, now: now).inputs.first)
        let reading = try DockInstrumentProjection.evaluate(input, now: now)
        XCTAssertEqual(reading.readout, "76%")
        XCTAssertEqual(try XCTUnwrap(reading.timeLeftFraction), 7410.0 / 10080.0, accuracy: 1e-9)
        XCTAssertEqual(reading.litTimePoints(positions: 37), 28)
    }

    func testProduceOffscreenGallery() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let golden = env["MODELPLAN_S1_GOLDEN_DIR"], let output = env["MODELPLAN_S1_GALLERY_DIR"] else {
            throw XCTSkip("Set MODELPLAN_S1_GOLDEN_DIR and MODELPLAN_S1_GALLERY_DIR to run the synthetic gallery")
        }
        try await S1Gallery.run(goldenPath: golden, outputPath: output)
    }
}
