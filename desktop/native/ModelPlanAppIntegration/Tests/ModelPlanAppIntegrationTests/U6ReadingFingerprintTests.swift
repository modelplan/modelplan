// SPDX-License-Identifier: MIT
#if MODELPLAN_U6_DRIVE
import Foundation
import XCTest
import ModelPlanWire
@testable import ModelPlanAppIntegration

final class U6ReadingFingerprintTests: XCTestCase {
    func testPythonVectorAndChangedReading() throws {
        let data=Data("""
        [{"route":"runtime_rpc","plan":{"id":"copilot_pro"},"beta":false,"valueState":"current","windows":[
          {"id":"premium","role":"primary","label":{"en":"Synthetic","zh":"Synthetic"},
           "limitKey":"premium_requests","poolKey":"copilot","resetMode":"fixed","remainingPercent":75.25,
           "resetsAt":"2099-01-01T00:00:00Z","current":true}]}]
        """.utf8)
        let accounts=try JSONDecoder().decode([RowsAccount].self,from:data)
        XCTAssertEqual(try U6ReadingFingerprint.sha256(accounts),"92c7f08d9a030f3b6d3409c7698da1b5d0454f773983308d20c7908eb3841a4e")
        let changed=Data(String(decoding:data,as:UTF8.self).replacingOccurrences(of:"75.25",with:"75").utf8)
        XCTAssertNotEqual(try U6ReadingFingerprint.sha256(JSONDecoder().decode([RowsAccount].self,from:changed)),
                          try U6ReadingFingerprint.sha256(accounts))
        XCTAssertThrowsError(try U6ReadingFingerprint.sha256(accounts+accounts))
        XCTAssertThrowsError(try U6ReadingFingerprint.sha256([]))
    }
}
#endif
