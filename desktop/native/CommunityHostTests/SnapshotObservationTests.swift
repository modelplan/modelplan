// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanCore

@MainActor private final class ObservationClock: RefreshTimeSource {
    var value = Date(timeIntervalSince1970:1_700_000_000)
    var step: TimeInterval = 0
    var reads = 0
    var elapsed: TimeInterval = 0
    var wall: Date { reads += 1; let result = value; value.addTimeInterval(step); return result }
}
private actor ObservationFeed: CLITransport {
    private var calls = 0
    func execute(_ command: CLICommand) async throws -> CommandResult {
        calls += 1
        let personal = #"{"schemaVersion":1,"kind":"modelplan.personal-snapshot","generatedAt":"2023-11-14T22:13:20+00:00","validUntil":"2023-11-14T22:13:50+00:00","publication":{"publicationId":"observation-fixture"},"accounts":[],"subscriptions":[]}"#
        let publication = #"{"schemaVersion":1,"publicationId":"observation-fixture","units":{"ability":"websiteAbility","cost":"usdPerReferenceTask","time":"taskTimeCrossModel"},"models":[],"lineups":[]}"#
        return CommandResult(exitCode:0,stdout:Data((command == .desktop ? personal : publication).utf8))
    }
    func count() -> Int { calls }
}
@MainActor final class SnapshotObservationTests: XCTestCase {
    private func ready(_ store: SnapshotStore) async throws {
        store.start()
        let end = ContinuousClock.now.advanced(by:.seconds(2))
        while !store.idle && ContinuousClock.now < end { try await Task.sleep(nanoseconds:1_000_000) }
        XCTAssertTrue(store.idle)
    }
    func testObservationUsesOneClockSampleForSnapshotFeedsAndOriginalWireIdentity() async throws {
        let feed = ObservationFeed(), clock = ObservationClock()
        let store = SnapshotStore(transport:feed,time:clock,automaticTimers:false)
        try await ready(store); defer { store.suspend() }
        let before = clock.reads, expected = clock.value
        clock.step = 60 // A second clock read would cross the validity deadline.
        let observed = store.observation()
        XCTAssertEqual(clock.reads-before,1)
        XCTAssertEqual(observed.observedAt,expected)
        XCTAssertTrue(observed.snapshot?.presentation.actionable == true)
        XCTAssertTrue(observed.selectionFeeds.personalUsable)
        XCTAssertEqual(observed.snapshot?.personal.generatedAt.raw,"2023-11-14T22:13:20+00:00")
        XCTAssertEqual(observed.selectionFeeds.personal?.validUntil?.raw,"2023-11-14T22:13:50+00:00")
        XCTAssertEqual(observed.snapshot?.publication?.publicationId,observed.selectionFeeds.publication?.publicationId)
    }
    func testNewCaptureRetiresExpiryWithoutMutatingPriorCaptureOrRevivingOnClockRollback() async throws {
        let feed = ObservationFeed(), clock = ObservationClock()
        let store = SnapshotStore(transport:feed,time:clock,automaticTimers:false)
        try await ready(store); defer { store.suspend() }
        let earlier = store.observation()
        clock.value.addTimeInterval(31)
        let expired = store.observation()
        XCTAssertTrue(earlier.selectionFeeds.personalUsable)
        XCTAssertFalse(expired.selectionFeeds.personalUsable)
        XCTAssertFalse(expired.snapshot?.presentation.actionable ?? true)
        clock.value.addTimeInterval(-31)
        XCTAssertFalse(store.observation().selectionFeeds.personalUsable)
        XCTAssertEqual(earlier.snapshot?.personal.validUntil?.raw,expired.snapshot?.personal.validUntil?.raw)
    }
    func testUnloadedAndSuspendedCapturesDoNotAcquireOrEraseThePublicCatalogue() async throws {
        let feed = ObservationFeed(), clock = ObservationClock()
        let store = SnapshotStore(transport:feed,time:clock,automaticTimers:false)
        let unloaded = store.observation()
        XCTAssertNil(unloaded.snapshot); XCTAssertNil(unloaded.selectionFeeds.personal)
        let noRequests = await feed.count(); XCTAssertEqual(noRequests,0)
        try await ready(store)
        let before = await feed.count()
        store.suspend()
        let observed = store.observation()
        XCTAssertFalse(observed.selectionFeeds.personalUsable)
        XCTAssertEqual(observed.selectionFeeds.publication?.publicationId,"observation-fixture")
        XCTAssertEqual(observed.snapshot?.presentation.unavailableReason,"suspended")
        let after = await feed.count(); XCTAssertEqual(before,after)
    }
}
