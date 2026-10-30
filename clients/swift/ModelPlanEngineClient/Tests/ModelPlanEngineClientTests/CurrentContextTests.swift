// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanWire
@testable import ModelPlanEngineClient

extension RealBinaryTests {
    func testRealSynchronousCurrentContextRequiresClearAndMatchesEveryField() async throws {
        let binary = try binary(); let home = try home(); let probe = EventProbe()
        try cli(binary, home: home, arguments: ["consent", "init", "--json"])
        let seed = try state(home)
        let client = ProcessEngineClient(configuration: configuration(binary, home: home), initialFloor: seed, consumer: probe)
        let api: any EngineClient = client
        addTeardownBlock { await probe.resumeClear(); await client.stop() }
        XCTAssertFalse(api.isCurrent(EngineDeliveryContext(sessionID: "", floor: seed, revision: 0)), "a cached initial floor is not accepted authority")
        await probe.suspendNextClear()
        let start = Task { try await client.start() }
        try await eventually { await probe.clearIsPaused() }
        let candidateValue = await client.context
        let candidate = try XCTUnwrap(candidateValue)
        XCTAssertFalse(api.isCurrent(candidate), "the authoritative handshake still owes a clear acknowledgement")
        await probe.resumeClear()
        let accepted = try await start.value
        XCTAssertTrue(api.isCurrent(accepted)) // No await: the protocol requirement is synchronous.
        let changed = [
            EngineDeliveryContext(sessionID: accepted.sessionID + "-old", floor: accepted.floor, revision: accepted.revision),
            EngineDeliveryContext(sessionID: accepted.sessionID, floor: EngineConsentFloor(storeEpoch: accepted.floor.storeEpoch + "-other", generation: accepted.floor.generation), revision: accepted.revision),
            EngineDeliveryContext(sessionID: accepted.sessionID, floor: EngineConsentFloor(storeEpoch: accepted.floor.storeEpoch, generation: accepted.floor.generation + 1), revision: accepted.revision),
            EngineDeliveryContext(sessionID: accepted.sessionID, floor: accepted.floor, revision: accepted.revision + 1)
        ]
        for value in changed { XCTAssertFalse(api.isCurrent(value)) }
        let matches = await withTaskGroup(of: Bool.self, returning: Bool.self) { group in
            for _ in 0..<32 {
                group.addTask {
                    for _ in 0..<1_000 {
                        if !api.isCurrent(accepted) || changed.contains(where: { api.isCurrent($0) }) { return false }
                    }
                    return true
                }
            }
            for await result in group { if !result { return false } }
            return true
        }
        XCTAssertTrue(matches, "concurrent readers must compare the complete accepted value")

        // Readers race a real stop, then check after the actor acknowledges it.
        let withdrawn = await withTaskGroup(of: Bool.self, returning: Bool.self) { group in
            for _ in 0..<16 {
                group.addTask {
                    for _ in 0..<1_000 { _ = api.isCurrent(accepted) }
                    await api.stop()
                    for _ in 0..<1_000 { if api.isCurrent(accepted) { return false } }
                    return true
                }
            }
            for await result in group { if !result { return false } }
            return true
        }
        XCTAssertTrue(withdrawn)
    }

    func testRealCurrentContextStaysFalseAcrossProtocolFaultAndRestartBarrier() async throws {
        let binary = try binary(); let home = try home(); let probe = EventProbe()
        try cli(binary, home: home, arguments: ["consent", "init", "--json"])
        let client = ProcessEngineClient(configuration: configuration(binary, home: home), consumer: probe)
        addTeardownBlock { await probe.resumeClear(); await client.stop() }
        let original = try await client.start()
        XCTAssertTrue(client.isCurrent(original))
        await probe.suspendNextClear()
        let childID = await client.child?.id
        // Feed the normal decoder a malformed frame while the real process is alive.
        await client.receive(try XCTUnwrap(childID), bytes: Data("not-json".utf8))
        XCTAssertFalse(client.isCurrent(original))
        try await eventually { await probe.clearIsPaused() }
        try await eventually({ await client.handshaken }, timeout: 8)
        let nextValue = await client.context
        let next = try XCTUnwrap(nextValue)
        XCTAssertNotEqual(next.sessionID, original.sessionID)
        XCTAssertEqual(next.floor, original.floor, "a restart can keep the floor but must retire the session/revision")
        XCTAssertFalse(client.isCurrent(original))
        XCTAssertFalse(client.isCurrent(next), "a fresh handshake cannot bypass the blocked clear consumer")
        await probe.resumeClear()
        try await eventually { client.isCurrent(next) }
        XCTAssertFalse(client.isCurrent(original))
        await probe.suspendNextClear()
        let stopping = Task { await client.stop() }
        try await eventually { await probe.clearIsPaused() }
        XCTAssertFalse(client.isCurrent(next), "stop withdraws authority before the UI acknowledges its clear")
        await probe.resumeClear()
        await stopping.value
        XCTAssertFalse(client.isCurrent(next))
    }
}
