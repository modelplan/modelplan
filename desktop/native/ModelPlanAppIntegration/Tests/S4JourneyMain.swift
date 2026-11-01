// SPDX-License-Identifier: MIT
import Foundation
import Darwin

@main struct S4JourneyMain {
    @MainActor static func main() async {
        guard CommandLine.arguments.count == 2 else { fatalError("capture path required") }
        do {
            let capture=URL(fileURLWithPath:CommandLine.arguments[1])
            try await S4QuotaJourney.roles(capture:capture)
            try await S4QuotaJourney.members(capture:capture)
            try await S4QuotaJourney.unknownFacts(capture:capture)
            try await S4QuotaJourney.collisions(capture:capture)
            try await S4QuotaJourney.language(capture:capture)
        }
        catch { print("S4 journey FAIL: \(error)");exit(1) }
        print("S4 normal-entry roles and members journey PASS (no windows/input/engine child)")
    }
}
