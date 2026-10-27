// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanCore
import ModelPlanShell
@testable import ModelPlanCommunityHost

private actor PreviewFixtureTransport: CLITransport {
    let fails: Bool
    private var calls: [CLICommand] = []
    init(fails: Bool = false) { self.fails = fails }
    func execute(_ command: CLICommand) async throws -> CommandResult {
        calls.append(command)
        guard !fails else { throw TransportError.launchFailed }
        guard command == .desktop else { return .init(exitCode: 1, stdout: Data()) }
        let now = Date(), format = ISO8601DateFormatter()
        let payload: [String: Any] = ["schemaVersion": 1, "kind": "modelplan.personal-snapshot",
            "generatedAt": format.string(from: now.addingTimeInterval(-1)),
            "validUntil": format.string(from: now.addingTimeInterval(300)),
            "subscriptions": [["subscriptionRef": "preview:sample", "sources": ["fixture"]]],
            "accounts": [["source": "fixture", "plan": "Example only",
                "subscription": ["subscriptionRef": "preview:sample", "status": "verified"],
                "windows": [["kind": "five_hour", "remainingPercent": 42,
                    "observedAt": format.string(from: now.addingTimeInterval(-1))]]]]]
        return .init(exitCode: 0, stdout: try JSONSerialization.data(withJSONObject: payload))
    }
    func commands() -> [CLICommand] { calls }
}

@MainActor final class PreviewTransportTests: XCTestCase {
    func testExplicitPreviewFeedReachesTheExistingRuntimeStore() async throws {
        let transport = PreviewFixtureTransport()
        let host = CommunityDelegate(surfaces: NeutralSurfaceProvider(), transport: transport,
                                     statusItemTitle: "Preview data")
        let runtime = host.makeRuntime(), loaded = expectation(description: "preview feed loaded")
        let store = runtime.store
        store.onChange = { [weak store] in
            if store?.view()?.personal.subscriptions?.first?.subscriptionRef == "preview:sample" {
                store?.onChange = nil; loaded.fulfill()
            }
        }
        store.start()
        await fulfillment(of: [loaded], timeout: 2)
        let snapshot = try XCTUnwrap(store.view())
        XCTAssertEqual(snapshot.personal.accounts?.first?.plan, "Example only")
        XCTAssertEqual(snapshot.presentation.quotas.first?.remaining, 42)
        XCTAssertNil(store.diagnostics.personal)
        await store.stopAndWait()
        let commands = await transport.commands()
        XCTAssertTrue(commands.contains(.desktop))
    }

    func testUnavailableExplicitFeedDoesNotInventMembershipOrFallBackToAnotherFeed() async {
        let transport = PreviewFixtureTransport(fails: true)
        let host = CommunityDelegate(surfaces: NeutralSurfaceProvider(), transport: transport)
        let store = host.makeRuntime().store, unavailable = expectation(description: "preview failure delivered")
        store.onChange = { [weak store] in
            if store?.diagnostics.personal == "personal-read-unavailable" {
                store?.onChange = nil; unavailable.fulfill()
            }
        }
        store.start()
        await fulfillment(of: [unavailable], timeout: 2)
        XCTAssertNil(store.view())
        XCTAssertEqual(store.diagnostics.personal, "personal-read-unavailable")
        await store.stopAndWait()
        let commands = await transport.commands()
        XCTAssertTrue(commands.contains(.desktop))
    }
}
