// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanWire
@testable import ModelPlanEngineClient

private actor RefreshPreparationProbe {
    var id: WireRequestID?
    var alreadyQueued = false
    func record(_ value: WireRequestID, queued: Bool) { id=value;alreadyQueued=queued }
    func result() -> (WireRequestID?,Bool) { (id,alreadyQueued) }
}
extension ProcessEngineClient {
    func hasPreparedRefresh(_ id: WireRequestID) -> Bool { pending[requestKey(id)] != nil }
}
extension RealBinaryTests {
    func testRefreshPreparedIDIsTheSentIDAndPrecedesEnqueue() async throws {
        let binary=try binary(),home=try home(),events=EventProbe(),prepared=RefreshPreparationProbe()
        try cli(binary,home:home,arguments:["consent","init","--json"])
        let client=ProcessEngineClient(configuration:configuration(binary,home:home),consumer:events)
        addTeardownBlock { await client.stop() }
        _=try await client.start()
        let completion=try await client.refresh(try .init(),timeout:nil,prepared: { id in
            let queued=await client.hasPreparedRefresh(id)
            await prepared.record(id,queued:queued)
        })
        let observed=await prepared.result()
        XCTAssertEqual(observed.0,completion.requestID)
        XCTAssertFalse(observed.1,"the evidence callback must complete before enqueue or write")
    }
}
