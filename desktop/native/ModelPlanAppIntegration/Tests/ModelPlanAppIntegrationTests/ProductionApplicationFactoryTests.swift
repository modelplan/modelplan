// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanCore
import ModelPlanCommunityHost
import ModelPlanAppIntegration

@MainActor final class ProductionApplicationFactoryTests: XCTestCase {
    private final class Companion: CommunityCompanionSurface {
        var showConsole: (() -> Void)?, showSettings: (() -> Void)?
        func render(snapshot: JoinedSnapshot?, diagnostics: StoreDiagnostics) {}
        func setPresentationAllowed(_ allowed: Bool) {}
        func close() {}
    }
    func testNormalEntryFactoryRetainsItsRequiredCompanionWithoutLaunching() {
        let companion = Companion()
        let delegate = CommunityApplicationFactory.makeDelegate(surfaces: CommunityInstrumentSurfaceProvider(), companion: companion) { _ in
            XCTFail("Construction must not open Settings")
            throw TransportError.launchFailed
        }
        // Inspect the actual delegate returned by the production factory, not a parallel fixture.
        let stored = Mirror(reflecting: delegate).children.first { $0.label == "companion" }?.value
        let unwrapped = stored.flatMap { Mirror(reflecting: $0).children.first?.value }
        XCTAssertTrue((unwrapped as AnyObject?) === companion, "Removing companion forwarding must fail this wiring check")
    }
}
