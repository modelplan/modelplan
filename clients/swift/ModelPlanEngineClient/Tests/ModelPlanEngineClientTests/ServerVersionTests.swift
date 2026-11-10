// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanEngineClient

final class ServerVersionTests: XCTestCase {
    func testVersionFloorFailsClosedAndComparesAllComponents() {
        for value in ["0.5.52", "0.5.53", "0.6.0", "1.0.0", "0.5.52+build.1"] {
            XCTAssertTrue(meetsMinimumServerVersion(value, minimum: "0.5.52"), value)
        }
        for value in ["", "0.5.49", "0.5.51", "0.4.999", "0.5", "0.5.52-dev", "0.5.52+", "0.5.52+a..b", "0.5.52+.", "0.5.52+a.", "00.5.52", "0.5.18446744073709551616", "unknown"] {
            XCTAssertFalse(meetsMinimumServerVersion(value, minimum: "0.5.52"), value)
        }
        XCTAssertFalse(meetsMinimumServerVersion("1.0.0", minimum: "invalid"))
    }

    /// A release-candidate helper (codex/cli-pin.json at v0.5.58-rc.1) reports its prerelease
    /// serverVersion; rejecting it stopped the engine at initialize and the app never got rows.
    func testCandidateAboveTheFloorIsAccepted() {
        for value in ["0.5.58-rc.1", "0.5.53-rc.1", "0.5.58-rc.1+build.7", "0.6.0-alpha", "0.5.52-0.3.7"] {
            XCTAssertTrue(meetsMinimumServerVersion(value, minimum: "0.5.52"), value)
        }
        for value in ["0.5.52-rc.1", "0.5.51-rc.9", "0.5.58-", "0.5.58-rc..1", "0.5.58-rc.01", "0.5.58-rc_1", "0.5.58-rc.1+"] {
            XCTAssertFalse(meetsMinimumServerVersion(value, minimum: "0.5.52"), value)
        }
    }

    func testPrereleasePrecedenceFollowsSemanticVersioning() {
        let ordered = ["1.0.0-alpha", "1.0.0-alpha.1", "1.0.0-alpha.beta", "1.0.0-beta", "1.0.0-beta.2", "1.0.0-beta.11", "1.0.0-rc.1", "1.0.0"]
        for (index, lower) in ordered.enumerated() {
            for higher in ordered[index...] {
                XCTAssertTrue(meetsMinimumServerVersion(higher, minimum: lower), "\(higher) >= \(lower)")
            }
            for higher in ordered[(index + 1)...] {
                XCTAssertFalse(meetsMinimumServerVersion(lower, minimum: higher), "\(lower) < \(higher)")
            }
        }
    }
}
