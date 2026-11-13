// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanCore
import ModelPlanShell
import ModelPlanAssembly
import ModelPlanInstruments
import ModelPlanSelection
@testable import ModelPlanCommunityHost

private actor ScopeFeed: CLITransport {
    let personal: Data, publication: Data
    private var count = 0
    init() throws {
        let formatter = ISO8601DateFormatter(), now = Date()
        personal = try JSONSerialization.data(withJSONObject: [
            "schemaVersion":1,"kind":"modelplan.personal-snapshot",
            "generatedAt":formatter.string(from:now.addingTimeInterval(-1)),
            "validUntil":formatter.string(from:now.addingTimeInterval(300)),
            "publication":["publicationId":"scope-fixture"],
            "subscriptions":[["subscriptionRef":"synthetic-subscription","sources":["codex"]]]])
        publication = Data(#"{"schemaVersion":1,"publicationId":"scope-fixture","selectionRevision":"r","units":{"ability":"websiteAbility","cost":"usdPerReferenceTask","time":"taskTimeCrossModel"},"models":[{"id":"global","developerId":"dev","lineageId":"global-line","lineageStatus":"current","defaultSelected":true,"harnessIds":{"other":["global"]}},{"id":"tool","developerId":"dev","lineageId":"tool-line","lineageStatus":"current","defaultSelected":false,"harnessIds":{"codex":["native-tool"]}}],"lineups":[]}"#.utf8)
    }
    func execute(_ command: CLICommand) async throws -> CommandResult {
        count += 1
        return CommandResult(exitCode:0,stdout:command == .desktop ? personal : publication)
    }
    func requests() -> Int { count }
}
@MainActor private class ScopeSurfaceBase: NSObject {
    let view = NSView(frame:.zero)
    var instrumentLanguage: InstrumentLanguage = .english
    var selectedModelID: String? = "tool"
    var isPresented = true
    let preferredContentSize = CGSize(width:440,height:210)
    var requestFreshSelection: (() -> Void)?
    var contentSizeChanged: (() -> Void)?
    func render(snapshot: JoinedSnapshot?, diagnostics: StoreDiagnostics) {}
    func render(selection: AssembledModelSelection, publishedAt: Date?, now: Date) {}
    func resumePresentation() {}
    func suspendPresentation() {}
    func closePresentation() {}
}
@MainActor private final class LegacyScopeSurface: ScopeSurfaceBase, CommunityInstrumentSurface {}
@MainActor private final class RequestedScopeSurface: ScopeSurfaceBase, CommunityInstrumentSurface {
    var requestedInstrumentScope: InstrumentScope = .subscription("synthetic-subscription")
}
@MainActor final class InstrumentScopeRuntimeTests: XCTestCase {
    private func ready(_ runtime: CommunityRuntime) async throws {
        runtime.store.start()
        let end = ContinuousClock.now.advanced(by:.seconds(2))
        while !runtime.store.idle && ContinuousClock.now < end { try await Task.sleep(nanoseconds:1_000_000) }
        XCTAssertTrue(runtime.store.idle)
    }
    func testExistingSurfaceDefaultsToPublicAllWithoutRequiringNewScopeStorage() async throws {
        let feed = try ScopeFeed(), runtime = CommunityRuntime(transport:feed)
        try await ready(runtime); defer { runtime.store.suspend() }
        let surface: any CommunityInstrumentSurface = LegacyScopeSurface()
        let result = runtime.selection(for:surface)
        XCTAssertEqual(result.shared.scope,.all)
        XCTAssertEqual(result.shared.orderedIDs,["global"])
        XCTAssertEqual(result.language,.english)
    }
    func testSubscriptionIntentAndSubsequentUnknownScopeUseTheSameCurrentFeed() async throws {
        let feed = try ScopeFeed(), runtime = CommunityRuntime(transport:feed)
        try await ready(runtime); defer { runtime.store.suspend() }
        let surface = RequestedScopeSurface()
        let initialRequests = await feed.requests()
        let selected = runtime.selection(for:surface)
        XCTAssertEqual(selected.shared.scope,.subscription("synthetic-subscription"))
        XCTAssertEqual(selected.shared.orderedIDs,["tool"])
        XCTAssertEqual(selected.instruments?.selectedModelID,"tool")
        XCTAssertEqual(selected.modelAvailabilityNotes["tool"],"Available in this tool")
        surface.requestedInstrumentScope = .subscription("unknown-subscription")
        let unknown = runtime.selection(for:surface)
        XCTAssertEqual(unknown.shared.scope,.subscription("unknown-subscription"))
        XCTAssertEqual(unknown.shared.orderedIDs,["global"])
        XCTAssertNil(unknown.instruments?.selectedModelID)
        XCTAssertEqual(unknown.selectionNotice,"Public defaults")
        surface.requestedInstrumentScope = .all
        XCTAssertEqual(runtime.selection(for:surface).shared.orderedIDs,["global"])
        let finalRequests = await feed.requests()
        XCTAssertEqual(initialRequests,finalRequests,"scope intent must not acquire or refresh another feed")
    }
}
