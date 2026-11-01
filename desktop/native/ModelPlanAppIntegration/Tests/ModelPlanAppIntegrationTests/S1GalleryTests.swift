// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import S1GalleryCore

@MainActor final class S1GalleryTests: XCTestCase {
    func testProduceOffscreenGallery() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let golden = env["MODELPLAN_S1_GOLDEN_DIR"], let output = env["MODELPLAN_S1_GALLERY_DIR"] else {
            throw XCTSkip("Set MODELPLAN_S1_GOLDEN_DIR and MODELPLAN_S1_GALLERY_DIR to run the synthetic gallery")
        }
        try await S1Gallery.run(goldenPath: golden, outputPath: output)
    }
}
