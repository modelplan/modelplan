// SPDX-License-Identifier: MIT
import Foundation
import Darwin

@main struct S4JourneyMain {
    @MainActor static func main() async {
        guard CommandLine.arguments.count == 2 else { fatalError("capture path required") }
        do { try await S4QuotaJourney.roles(capture:URL(fileURLWithPath:CommandLine.arguments[1])) }
        catch { print("S4 journey FAIL: \(error)");exit(1) }
        print("S4 normal-entry roles journey PASS (no windows/input/engine child)")
    }
}
