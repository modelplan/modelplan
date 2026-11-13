// SPDX-License-Identifier: MIT
import Foundation
import Darwin
@main struct U8ConsentJourneyMain {
    @MainActor static func main() async {
        guard CommandLine.arguments.count == 2 else { exit(2) }
        do {
            try await U8ConsentJourney.run(capture:URL(fileURLWithPath:CommandLine.arguments[1]))
            try await U8ConsentJourney.menu()
        }
        catch { print("U8 consent journey FAIL: \(error)");exit(1) }
        print("U8 normal-entry consent journey PASS (synthetic, no windows/input/engine child)")
    }
}
