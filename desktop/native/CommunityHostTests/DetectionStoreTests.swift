// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanCore

private actor DetectionTestTransport: CLITransport {
    let failDetection: Bool
    private var commands: [CLICommand] = []
    private var active = 0
    private var maximumActive = 0
    init(failDetection: Bool = false) { self.failDetection = failDetection }
    func execute(_ command: CLICommand) async throws -> CommandResult {
        commands.append(command); active += 1; maximumActive = max(maximumActive, active)
        defer { active -= 1 }
        try await Task.sleep(nanoseconds: command == .detect ? 20_000_000 : 1_000_000)
        if command == .detect {
            return CommandResult(exitCode: failDetection ? 1 : 0,
                stdout: Data(#"{"schemaVersion":1,"tools":[{"providerId":"synthetic","status":"unknown","detected":false}]}"#.utf8))
        }
        if command == .desktop {
            return CommandResult(exitCode: 0, stdout: Data(#"{"schemaVersion":1,"kind":"modelplan.personal-snapshot","generatedAt":"2026-10-28T00:00:00Z","validUntil":"2030-01-01T00:00:00Z","publication":{"publicationId":"synthetic"},"accounts":[]}"#.utf8))
        }
        return CommandResult(exitCode: 0, stdout: Data(#"{"schemaVersion":1,"publicationId":"synthetic","units":{"ability":"websiteAbility","cost":"usdPerReferenceTask","time":"taskTimeCrossModel"},"models":[],"lineups":[]}"#.utf8))
    }
    func observed() -> ([CLICommand], Int) { (commands, maximumActive) }
}
@MainActor private final class DetectionTestTime: RefreshTimeSource {
    var wall = Date(timeIntervalSince1970: 1_793_145_600)
    var elapsed: TimeInterval = 0
}
private actor HeldDetectionTransport: CLITransport {
    private let ordinary = DetectionTestTransport()
    private var firstGate: CheckedContinuation<Void, Never>?
    private var started: CheckedContinuation<Void, Never>?
    private var detectionCount = 0, active = 0, maximumActive = 0
    func execute(_ command: CLICommand) async throws -> CommandResult {
        active += 1; maximumActive = max(maximumActive, active)
        defer { active -= 1 }
        guard command == .detect else { return try await ordinary.execute(command) }
        detectionCount += 1
        let first = detectionCount == 1
        if first {
            await withCheckedContinuation { gate in
                firstGate = gate; started?.resume(); started = nil
            }
        }
        let id = first ? "old" : "new"
        return CommandResult(exitCode: 0, stdout: Data("{\"schemaVersion\":1,\"tools\":[{\"providerId\":\"\(id)\",\"status\":\"unknown\"}]}".utf8))
    }
    func waitForFirstDetection() async {
        if firstGate != nil { return }
        await withCheckedContinuation { started = $0 }
    }
    func releaseFirstDetection() { firstGate?.resume(); firstGate = nil }
    func observed() -> (Int, Int) { (detectionCount, maximumActive) }
}
@MainActor final class DetectionStoreTests: XCTestCase {
    func testExplicitResumeRequestQueuesBehindCancelledDetectionGeneration() async throws {
        for requestsAfterResume in [false, true] {
            let transport = HeldDetectionTransport()
            let store = SnapshotStore(transport: transport, time: DetectionTestTime(), automaticTimers: false)
            store.start(); try await settle(store)
            store.requestDetection(); await transport.waitForFirstDetection()
            store.suspend(); store.resume()
            if requestsAfterResume { store.requestDetection(); store.requestDetection() }
            await transport.releaseFirstDetection(); try await settle(store)
            let (count, maximum) = await transport.observed()
            XCTAssertEqual(maximum, 1)
            XCTAssertEqual(count, requestsAfterResume ? 2 : 1)
            XCTAssertEqual(store.detectionReport?.tools.first?.providerId, requestsAfterResume ? "new" : nil)
            await store.stopAndWait()
        }
    }
    func testDefaultLifecycleAndRefreshDoNotRequestDetection() async throws {
        let transport = DetectionTestTransport()
        let store = SnapshotStore(transport: transport, time: DetectionTestTime(), automaticTimers: false)
        store.start(); try await settle(store)
        store.refresh(); try await settle(store)
        await store.stopAndWait()
        store.resume(); try await settle(store)
        let (commands, _) = await transport.observed()
        XCTAssertFalse(commands.contains(.detect))
        XCTAssertNil(store.detectionReport)
        await store.stopAndWait()
    }
    func testExplicitDetectionIsSerializedDeduplicatedAndRetiredOnSuspend() async throws {
        let transport = DetectionTestTransport()
        let store = SnapshotStore(transport: transport, time: DetectionTestTime(), automaticTimers: false)
        store.start(); try await settle(store)
        store.requestDetection(); store.requestDetection(); store.refresh()
        try await settle(store)
        let (commands, maximum) = await transport.observed()
        XCTAssertEqual(commands.filter { $0 == .detect }.count, 1)
        XCTAssertEqual(maximum, 1)
        XCTAssertEqual(CLICommand.detect.arguments, ["detect", "--json"])
        XCTAssertEqual(store.detectionReport?.tools.first?.status, "unknown")
        XCTAssertNil(store.diagnostics.detection)
        XCTAssertNotNil(store.diagnostics.detectionReadAt)
        await store.stopAndWait()
        XCTAssertNil(store.detectionReport)
        XCTAssertNil(store.diagnostics.detectionReadAt)
    }
    func testFailedDetectionDoesNotInvalidatePersonalOrPublicationFeeds() async throws {
        let transport = DetectionTestTransport(failDetection: true)
        let store = SnapshotStore(transport: transport, time: DetectionTestTime(), automaticTimers: false)
        store.start(); try await settle(store)
        XCTAssertNil(store.diagnostics.personal); XCTAssertNil(store.diagnostics.publication)
        store.requestDetection(); try await settle(store)
        XCTAssertNil(store.detectionReport)
        XCTAssertEqual(store.diagnostics.detection, "detection-read-unavailable")
        XCTAssertNil(store.diagnostics.personal); XCTAssertNil(store.diagnostics.publication)
        await store.stopAndWait()
    }
    private func settle(_ store: SnapshotStore) async throws {
        for _ in 0..<500 {
            if store.idle { return }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTFail("Synthetic store did not settle within its bounded test budget")
    }
}
