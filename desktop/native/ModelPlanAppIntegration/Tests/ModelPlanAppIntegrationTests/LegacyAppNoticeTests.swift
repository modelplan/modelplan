// SPDX-License-Identifier: MIT
import XCTest
import ModelPlanSettings
@testable import ModelPlanAppIntegration

/// D57: the renamed app asks the person to quit and delete a pre-rename app that is still running.
@MainActor final class LegacyAppNoticeTests: XCTestCase {
    func testLooksUpOnlyThePreRenameBundleIdentifier() {
        var asked: [String] = []
        let names = LegacyAppNotice.runningLegacyNames { identifier in asked.append(identifier); return ["Old"] }
        XCTAssertEqual(asked, ["org.modelplan.community.swift.scaffold"])
        XCTAssertEqual(names, ["Old"])
    }
    func testNoRunningLegacyAppMeansNoNotice() {
        XCTAssertTrue(LegacyAppNotice.runningLegacyNames { _ in [] }.isEmpty)
        LegacyAppNotice.presentIfNeeded(language: .english, running: [])  // returns without any window
    }
    func testMessageNamesTheRunningAppAndTheLoginItemInBothLanguages() {
        let english = LegacyAppNotice.message(legacyName: "Old Name", language: .english)
        XCTAssertTrue(english.body.contains("“Old Name”"))
        XCTAssertTrue(english.body.contains("Login Items"))
        XCTAssertTrue(english.body.contains("settings and history are kept"))
        let chinese = LegacyAppNotice.message(legacyName: "Old Name", language: .chinese)
        XCTAssertTrue(chinese.body.contains("“Old Name”"))
        XCTAssertTrue(chinese.body.contains("登录项"))
        let unnamed = LegacyAppNotice.message(legacyName: "  ", language: .english)
        XCTAssertTrue(unnamed.body.hasPrefix("An older ModelPlan app"))
    }
}
