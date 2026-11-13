// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanCockpitShell

final class CockpitWindowStateTests: XCTestCase {
    func testSliderCommitsAreIdempotent() {
        var window = CockpitWindowState()
        XCTAssertFalse(window.isClosed(forcedClosed: false))
        XCTAssertTrue(window.switchEnabled(forcedClosed: false))
        XCTAssertTrue(window.setClosed(true, forcedClosed: false))
        XCTAssertTrue(window.userClosed)
        XCTAssertFalse(window.setClosed(true, forcedClosed: false))
        XCTAssertTrue(window.toggle(forcedClosed: false))
        XCTAssertFalse(window.userClosed)
    }

    func testForcedClosureDisablesSliderAndPreservesOpenPreferenceOnReturn() {
        var window = CockpitWindowState()
        XCTAssertTrue(window.isClosed(forcedClosed: true))
        XCTAssertFalse(window.switchEnabled(forcedClosed: true))
        XCTAssertFalse(window.toggle(forcedClosed: true))
        XCTAssertFalse(window.setClosed(true, forcedClosed: true))
        XCTAssertFalse(window.userClosed)
        XCTAssertFalse(window.isClosed(forcedClosed: false))
    }

    func testUserClosedPreferenceSurvivesSmallDisplayAndRestore() {
        var window = CockpitWindowState(userClosed: true)
        XCTAssertFalse(window.setClosed(false, forcedClosed: true))
        XCTAssertTrue(window.userClosed)
        XCTAssertTrue(window.isClosed(forcedClosed: false))
        XCTAssertTrue(window.setClosed(false, forcedClosed: false))
    }
}
