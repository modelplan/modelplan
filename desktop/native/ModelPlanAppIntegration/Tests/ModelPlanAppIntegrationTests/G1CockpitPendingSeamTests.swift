// SPDX-License-Identifier: MIT
import XCTest

/// These named cases record missing normal-entry prerequisites. They do not
/// assert requirement coverage and must not be added to allowedSkips.
final class G1CockpitPendingSeamTests: XCTestCase {
    func testG1_CKP_ENTRY_04() throws {
        throw XCTSkip("SEAM-NEEDED: normal-composition synthetic client and day-controlled selectedScope observation")
    }
    func testG1_CKP_ENTRY_05() throws {
        throw XCTSkip("SEAM-NEEDED: normal-composition synthetic client and observable opening/notice acknowledgement")
    }
}
