// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanWire
@testable import ModelPlanEngineClient

private actor MemberDeliveryProbe: EngineClientEventConsumer {
    var results: [EngineResponse] = []
    func consume(_ event: EngineClientEvent) async { if case .response(_, let value) = event { results.append(value) } }
    func received() -> [EngineResponse] { results }
}
private extension ProcessEngineClient {
    func injectRefreshResponse(member: Bool, data: WireJSONValue) throws {
        let id = WireRequestID.string(member ? "member" : "legacy")
        let key = requestKey(id)
        let delivery = EngineDeliveryContext(sessionID: "synthetic", floor: .init(storeEpoch: "synthetic", generation: 1), revision: 1)
        revision = 1
        var entry = ClientPending(id: id, method: "refresh/request", purpose: .request, grant: nil, continuation: nil)
        entry.memberRefresh = member; pending[key] = entry
        let envelope = try WireEnvelope(sessionId: "synthetic", storeEpoch: "synthetic", consentGeneration: 1, data: data)
        try response(entry, key: key, envelope: envelope, context: delivery, bytes: 100)
    }
}
final class MemberRefreshDeliveryTests: XCTestCase {
    func testMemberObjectAndLegacyArrayUseDistinctOrderedResponses() async throws {
        let probe = MemberDeliveryProbe()
        let client = ProcessEngineClient(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic"), applicationVersion: "test", allowedEnvironment: [:]), consumer: probe)
        try await client.injectRefreshResponse(member: true, data: .object(["outcome": .string("started")]))
        try await client.injectRefreshResponse(member: false, data: .array([]))
        for _ in 0..<100 { if await probe.received().count == 2 { break }; try await Task.sleep(for: .milliseconds(10)) }
        let results = await probe.received()
        XCTAssertEqual(results.count, 2)
        if case .memberRefresh(let reply) = results.first { XCTAssertEqual(reply.envelope.data.outcome, .started) }
        else { XCTFail("Member object must remain a member response") }
        if case .refresh(let reply) = results.last { XCTAssertTrue(reply.envelope.data.isEmpty) }
        else { XCTFail("Legacy array must remain a legacy response") }
    }
}
