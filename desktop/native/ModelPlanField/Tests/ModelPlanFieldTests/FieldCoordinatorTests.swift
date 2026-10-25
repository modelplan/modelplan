// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanField

@MainActor private final class FakeTransport: FieldTransport, FieldSnapshotCancellation {
    var started = 0, released = 0, snapshots = 0, activeSnapshots = 0, peakSnapshots = 0
    var completions: [(Data?) -> Void] = []
    var cancelRequests = 0
    var generation: UUID?
    var commands: [FieldCommand] = []
    var onSend: ((FieldCommand) -> Void)?
    var receive: ((Data) -> Void)?, failed: ((FieldReleaseReason) -> Void)?
    func start(generation: UUID, receive: @escaping (Data) -> Void, failed: @escaping (FieldReleaseReason) -> Void) {
        self.generation = generation; self.receive = receive; self.failed = failed; started += 1
    }
    func send(_ command: FieldCommand) { commands.append(command); onSend?(command) }
    func snapshot(completion: @escaping (Data?) -> Void) {
        snapshots += 1; activeSnapshots += 1; peakSnapshots = max(peakSnapshots, activeSnapshots)
        completions.append(completion)
    }
    func completeSnapshot(_ data: Data? = nil) {
        activeSnapshots -= 1; completions.removeFirst()(data)
    }
    func cancelSnapshot() { cancelRequests += 1 }
    func invalidate() { cancelSnapshot(); released += 1 }
    func emit(_ type: FieldEventKind, request: UUID? = nil, key: FieldCaptureKey? = nil) throws {
        receive?(try JSONEncoder().encode(message(type, generation!, request: request, key: key)))
    }
}
final class FieldCoordinatorTests: XCTestCase {
    @MainActor func testConfigurationUpdateCannotStartAnotherSnapshotBeforeOldCompletion() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = try FieldStillCache(directory: directory), transport = FakeTransport()
        var clock = at(0)
        let coordinator = FieldCoordinator(configuration: try fixture(), cache: cache, enlargementEnabled: true,
            now: { clock }, makeTransport: { transport })
        coordinator.enlarge()
        clock = at(1); try transport.emit(.ready)
        clock = at(2); try transport.emit(.settled, request: transport.commands.last!.requestId)
        let first = transport.commands.last!.captureKey!
        try transport.emit(.captureResult, request: first.requestId, key: first)
        XCTAssertEqual(transport.activeSnapshots, 1)
        clock = at(2.1); coordinator.update(try fixture("public-r2"))
        clock = at(2.2); try transport.emit(.settled, request: transport.commands.last!.requestId)
        XCTAssertEqual(transport.commands.filter { $0.type == .capture }.count, 1,
                       "A logical configuration change must not admit another physical capture")
        if let next = transport.commands.last?.captureKey, next != first {
            try transport.emit(.captureResult, request: next.requestId, key: next)
        }
        XCTAssertEqual(transport.snapshots, 1)
        XCTAssertEqual(transport.peakSnapshots, 1)
        XCTAssertGreaterThan(transport.cancelRequests, 0)
        transport.completeSnapshot()
        XCTAssertEqual(transport.commands.filter { $0.type == .capture }.count, 2)
        XCTAssertEqual(transport.commands.last?.captureKey?.projectionRevision, "public-r2")
        XCTAssertNotNil(coordinator.state.generation)
        coordinator.close()
    }
    @MainActor func testSlowPreparationRetainsAdmissionAcrossUpdatesHideAndInstanceRetry() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = try FieldStillCache(directory: directory), transport = FakeTransport()
        let png = try FieldPNG.encode(sampleImage())
        let gate = DelayedFieldStage(value: try FieldPNG.prepare(png))
        var clock = at(0)
        let coordinator = FieldCoordinator(configuration: try fixture(), cache: cache, enlargementEnabled: true,
            now: { clock }, makeTransport: { transport })
        var preparations = 0
        coordinator.prepareImage = { _ in preparations += 1; return Task { await gate.run() } }
        coordinator.enlarge(); clock = at(1); try transport.emit(.ready)
        clock = at(2); try transport.emit(.settled, request: transport.commands.last!.requestId)
        let first = transport.commands.last!.captureKey!
        try transport.emit(.captureResult, request: first.requestId, key: first)
        let duplicate = transport.completions[0]
        transport.completeSnapshot(png)
        await gate.waitForStart()
        duplicate(png)
        XCTAssertEqual(preparations, 1)
        clock = at(2.1); coordinator.update(try fixture("public-r2"))
        try transport.emit(.settled, request: transport.commands.last!.requestId)
        coordinator.setVisibility(.occluded)
        try transport.emit(.settled, request: transport.commands.last!.requestId)
        coordinator.setVisibility(.visible)
        try transport.emit(.settled, request: transport.commands.last!.requestId)
        coordinator.close()
        clock = at(2.2); coordinator.enlarge(); try transport.emit(.ready)
        try transport.emit(.settled, request: transport.commands.last!.requestId)
        XCTAssertEqual(transport.commands.filter { $0.type == .capture }.count, 1)
        let active = await gate.active
        XCTAssertEqual(active, 1, "Cancelled ImageIO must retain admission until its non-preemptible work exits")
        let resumed = expectation(description: "Latest capture admitted after old preparation exits")
        transport.onSend = { if $0.type == .capture { resumed.fulfill() } }
        await gate.finish()
        await fulfillment(of: [resumed], timeout: 2)
        let cancelled = await gate.cancelledOnExit
        XCTAssertTrue(cancelled)
        XCTAssertEqual(transport.commands.filter { $0.type == .capture }.count, 2)
        let latest = transport.commands.last!.captureKey!
        XCTAssertEqual(latest.projectionRevision, "public-r2")
        XCTAssertNotEqual(latest.generation, first.generation)
        try transport.emit(.captureResult, request: latest.requestId, key: latest)
        XCTAssertEqual(transport.snapshots, 2)
        XCTAssertEqual(transport.peakSnapshots, 1)
        coordinator.close(); transport.completeSnapshot()
    }
    @MainActor func testHiddenOldSnapshotMustRetireBeforeNewInstanceCapture() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = try FieldStillCache(directory: directory)
        var clock = at(0), transports: [FakeTransport] = [], preparations = 0
        let coordinator = FieldCoordinator(configuration: try fixture(), cache: cache, enlargementEnabled: true,
            now: { clock }, makeTransport: { let value = FakeTransport(); transports.append(value); return value })
        coordinator.prepareImage = { _ in preparations += 1; return Task { nil } }
        coordinator.enlarge(); let old = transports[0]
        clock = at(1); try old.emit(.ready)
        clock = at(2); try old.emit(.settled, request: old.commands.last!.requestId)
        let key = old.commands.last!.captureKey!
        try old.emit(.captureResult, request: key.requestId, key: key)
        coordinator.setVisibility(.collapsed)
        XCTAssertEqual(old.released, 1)
        XCTAssertGreaterThan(old.cancelRequests, 0)
        coordinator.setVisibility(.visible); coordinator.enlarge(); let current = transports[1]
        try current.emit(.ready)
        try current.emit(.settled, request: current.commands.last!.requestId)
        XCTAssertFalse(current.commands.contains { $0.type == .capture })
        old.completeSnapshot(Data([1, 2, 3]))
        XCTAssertEqual(preparations, 0)
        let next = current.commands.last!.captureKey!
        try current.emit(.captureResult, request: next.requestId, key: next)
        XCTAssertEqual(old.activeSnapshots + current.activeSnapshots, 1)
        coordinator.close(); current.completeSnapshot()
    }
    @MainActor func testOptionalGateKeepsTransportUnallocated() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = try FieldStillCache(directory: directory)
        var allocations = 0
        let coordinator = FieldCoordinator(configuration: try fixture(), cache: cache) { allocations += 1; return FakeTransport() }
        coordinator.enlarge(); coordinator.update(try fixture("public-r2"))
        XCTAssertEqual(allocations, 0)
        XCTAssertNil(coordinator.state.generation)
    }
    @MainActor func testClearCacheInvalidatesCaptureGenerationBeforeAwaitingIO() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = try FieldStillCache(directory: directory), transport = FakeTransport()
        let coordinator = FieldCoordinator(configuration: try fixture(), cache: cache, enlargementEnabled: true, makeTransport: { transport })
        coordinator.enlarge()
        try await coordinator.clearCache()
        XCTAssertNil(coordinator.state.generation)
        XCTAssertEqual(transport.released, 1)
        try transport.emit(.ready)
        XCTAssertNil(coordinator.state.generation)
    }
    @MainActor func testCloseReleasesSynchronouslyAndStaleTransportFailureCannotCloseRetry() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = try FieldStillCache(directory: directory)
        var clock = at(0), transports: [FakeTransport] = []
        let coordinator = FieldCoordinator(configuration: try fixture(), cache: cache, enlargementEnabled: true,
            now: { clock }, makeTransport: { let value = FakeTransport(); transports.append(value); return value })
        coordinator.enlarge()
        let first = transports[0]
        clock = at(1); try first.emit(.ready)
        XCTAssertEqual(first.commands[0].type, .configure)
        coordinator.close()
        XCTAssertEqual(first.released, 1)
        XCTAssertNil(coordinator.state.generation)
        clock = at(2); coordinator.enlarge()
        let current = coordinator.state.generation
        first.failed?(.webProcessTerminated)
        XCTAssertEqual(coordinator.state.generation, current)
        coordinator.close(.termination)
        XCTAssertEqual(transports[1].released, 1)
    }
}
