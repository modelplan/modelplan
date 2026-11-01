// SPDX-License-Identifier: MIT
import Foundation
import S1GalleryCore

@main struct S1GalleryCommand {
    @MainActor static func main() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let golden = env["MODELPLAN_S1_GOLDEN_DIR"], let output = env["MODELPLAN_S1_GALLERY_DIR"] else {
            throw CocoaError(.fileNoSuchFile)
        }
        try await S1Gallery.run(goldenPath: golden, outputPath: output)
    }
}
