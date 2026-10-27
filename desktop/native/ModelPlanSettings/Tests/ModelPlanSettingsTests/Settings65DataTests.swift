// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanSettings

final class Settings65DataTests: XCTestCase {
    func testConfirmedEightPaneTableAndKnownHomesStayDataDriven() {
        XCTAssertFalse(Settings65Homes.paneCountPending)
        XCTAssertEqual(SettingsStructure.task65.panes.map(\.id), ["general","dock","cockpit","appearance","subscriptions","notifications","privacy","about"])
        XCTAssertEqual(SettingsStructure.task65.panes.count, 8)
        XCTAssertEqual(SettingsStructure.task65.panes.last?.id, "about")
        XCTAssertEqual(Settings65Homes.dock.map(\.id), ["display","numbers","location","sequence"])
        XCTAssertTrue(Settings65Homes.dock[0].keys.contains(.size)); XCTAssertTrue(Settings65Homes.dock[2].keys.contains(.dockEdge))
        XCTAssertEqual(Settings65Homes.cockpit.keys, [.opening,.countdown])
        XCTAssertFalse(Settings65Homes.general.keys.contains(.opening)); XCTAssertFalse(Settings65Homes.appearance.keys.contains(.size))
    }
    func testCurrentTableHasEachKeyOnceAndDefaultCatalogueUsesConfirmedHomes() throws {
        XCTAssertNoThrow(try SettingsStructure(panes: SettingsStructure.task65.panes))
        let p = SettingsPreferences(), rows = try SettingsCatalogue.rows(preferences: p, context: .init())
        XCTAssertEqual(Set(rows.map(\.key)), Set(SettingKey.allCases))
        XCTAssertEqual(rows.count, SettingKey.allCases.count)
        let size = try XCTUnwrap(rows.first { $0.key == .size }); XCTAssertEqual(size.paneID, "dock"); XCTAssertEqual(size.groupID, "display")
        let opening = try XCTUnwrap(rows.first { $0.key == .opening }); XCTAssertEqual(opening.paneID, "cockpit")
        let login = try XCTUnwrap(rows.first { $0.key == .login }); XCTAssertEqual(login.paneID, "general")
        let diagnostics = try XCTUnwrap(rows.first { $0.key == .diagnostics }); XCTAssertEqual(diagnostics.paneID, "about")
        XCTAssertEqual(rows.first?.key, .login)
    }
    func testFiveDiagramInputsHaveFiniteAnimationAndStaticReducedMotionWithoutGeometryChanges() throws {
        var p = SettingsPreferences(); p.showPercentages = false; p.dockEdge = .bottom; p.subscriptionSettings["b"] = .init(percentagePin: .week)
        let inputs = SettingsDiagrams.inputs(p, orderedIDs: ["a","b"], lastChangedSubscriptionID: "b")
        XCTAssertEqual(inputs.count, 5); XCTAssertEqual(inputs[0], .edge(.bottom)); XCTAssertEqual(inputs[1], .percentages(shown: false, eventDot: true))
        XCTAssertEqual(inputs.last, .quotaWindow(subscriptionID: "b", pin: .week))
        XCTAssertEqual(SettingsDiagrams.inputs(p, orderedIDs: [], lastChangedSubscriptionID: "missing").last, .quotaWindow(subscriptionID: nil, pin: .auto))
        XCTAssertEqual(SettingsDiagramPolicy(reduceMotion: false).duration, 0.4)
        XCTAssertFalse(SettingsDiagramPolicy(reduceMotion: false).loops); XCTAssertFalse(SettingsDiagramPolicy(reduceMotion: false).changesControlGeometry)
        XCTAssertEqual(SettingsDiagramPolicy.sizeRatio, [36,44,52]); XCTAssertTrue(SettingsDiagramPolicy.clockwiseFromTwelve)
        var playback = SettingsDiagramPlayback(); try playback.trigger(at: 1, reduceMotion: false)
        XCTAssertEqual(try playback.progress(at: 1), 0); XCTAssertEqual(try playback.progress(at: 1.2), 0.5, accuracy: 1e-9)
        XCTAssertEqual(try playback.progress(at: 1.4), 1); XCTAssertEqual(try playback.progress(at: 100), 1)
        try playback.trigger(at: 101, reduceMotion: true); XCTAssertNil(playback.endsAt); XCTAssertEqual(try playback.progress(at: 101), 1)
        try playback.trigger(at: 102, reduceMotion: false); playback.reduceMotionNow(); XCTAssertEqual(try playback.progress(at: 102.1), 1)
        XCTAssertThrowsError(try playback.trigger(at: .nan, reduceMotion: false))
    }
    func testDiagnosticsOnlyContainVersionsOSReaderIDsAndErrorCodesNeverConsentAsEnabled() {
        var p = SettingsPreferences(); p.readerConsent.gemini = true
        var about = SettingsAbout(appVersion: "1.2.3", cliVersion: "0.5.38")
        about.macOSVersion = "14.0"; about.enabledReaders = [.codex]; about.recentErrorCodes = [.readerUnavailable,.permissionDenied]
        XCTAssertEqual(about.diagnosticText, "app=1.2.3\ncli=0.5.38\nmacOS=14.0\nreaders=codex\nerrors=readerUnavailable,permissionDenied")
        XCTAssertFalse(about.diagnosticText.contains("gemini"))
        about.macOSVersion = "/Users/private"; XCTAssertTrue(about.diagnosticText.contains("macOS=unknown"))
        about.recentErrorCodes = Array(repeating: .stale, count: 20)
        XCTAssertEqual(about.diagnosticText.components(separatedBy: "stale").count-1, 8)
    }
}
