// SPDX-License-Identifier: MIT
import Darwin
import Foundation
import S1GalleryCore

@main struct S1GalleryCommand {
    @MainActor static func main() async {
        do {
            let env = ProcessInfo.processInfo.environment
            if let baseline = env["MODELPLAN_S1_REGRESSION_BASELINES"], !baseline.isEmpty {
                try await S1NativeRegression.run(baselinePath: baseline)
                return
            }
            guard let golden = env["MODELPLAN_S1_GOLDEN_DIR"], let output = env["MODELPLAN_S1_GALLERY_DIR"] else {
                throw CocoaError(.fileNoSuchFile)
            }
            try await S1Gallery.run(goldenPath: golden, outputPath: output)
        } catch {
            FileHandle.standardError.write(Data("S1 check failed: \(error)\n".utf8))
            Darwin.exit(1)
        }
    }
}
