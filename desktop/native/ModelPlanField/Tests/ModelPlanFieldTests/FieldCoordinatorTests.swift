// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanField

@MainActor private final class FakeTransport: FieldTransport {
    var started = 0, released = 0, snapshots = 0
    var generation: UUID?
    var commands: [FieldCommand] = []
    var receive: ((Data) -> Void)?, failed: ((FieldReleaseReason) -> Void)?
    func start(generation: UUID, receive: @escaping (Data) -> Void, failed: @escaping (FieldReleaseReason) -> Void) {
        self.generation = generation; self.receive = receive; self.failed = failed; started += 1
    }
    func send(_ command: FieldCommand) { commands.append(command) }
    func snapshot(completion: @escaping (Data?) -> Void) { snapshots += 1 }
    func invalidate() { released += 1 }
    func emit(_ type: FieldEventKind, request: UUID? = nil) throws {
        receive?(try JSONEncoder().encode(message(type, generation!, request: request)))
    }
}
final class FieldCoordinatorTests: XCTestCase {
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
