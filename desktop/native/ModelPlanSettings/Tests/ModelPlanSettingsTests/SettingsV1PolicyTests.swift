// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@testable import ModelPlanSettings

@MainActor private final class V1RowTarget: NSObject {
    @objc func selected(_ sender: Any?) {}
}

final class SettingsV1PolicyTests: XCTestCase {
    @MainActor func testNormalEntryNumberThresholdAndLanguagePersist() async throws {
        var context = SettingsPageContext(); context.configureV1NormalEntry()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("settings-v1-controls-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try SettingsStore(foundationAt: root, product: .community)
        let editor = SettingsEditor(store: store, context: context)
        await editor.reload()
        let rows = try SettingsCatalogue.rows(preferences: try XCTUnwrap(editor.snapshot).preferences, context: context)
        for key in [SettingKey.showPercentages, .redBelow, .language] {
            XCTAssertEqual(try XCTUnwrap(rows.first { $0.key == key }).availability, .available, "\(key) must be editable in normal entry")
        }
        try await editor.commit(SettingsB20Edit.showPercentages(false))
        try await editor.commit(SettingsB20Edit.redBelow(16))
        try await editor.commit(SettingsB21Edit.language(.chinese))
        let reopened = try SettingsStore(foundationAt: root, product: .community)
        let preferences = await reopened.snapshot().preferences
        XCTAssertFalse(preferences.showPercentages)
        XCTAssertEqual(preferences.redBelow, 16)
        XCTAssertEqual(preferences.language, .chinese)
    }
    func testV1HidesRefreshHistoryUntilAProducerSuppliesIt() throws {
        var context = SettingsPageContext(); context.configureV1NormalEntry()
        let missing = try SettingsCatalogue.rows(preferences: .init(), context: context, paneID: "diagnostics")
        XCTAssertFalse(missing.contains { $0.key == .refreshHistory })
        context.refreshHistory = []
        let connected = try SettingsCatalogue.rows(preferences: .init(), context: context, paneID: "diagnostics")
        XCTAssertEqual(connected.first { $0.key == .refreshHistory }?.value, .text("--"))
    }
    func testV1HidesUnsupportedAppearanceAndIgnitionChoices() throws {
        var context = SettingsPageContext(); context.v1NormalEntry = true
        let defaults = SettingsPreferences()
        let rows = try SettingsCatalogue.rows(preferences: defaults, context: context)
        XCTAssertFalse(rows.contains { $0.key == .theme })
        XCTAssertFalse(rows.contains { $0.key == .opening })
        XCTAssertFalse(rows.contains { $0.key == .countdown })
        XCTAssertEqual(defaults.percentageMode, .remaining)
        guard case .choice(let selected, let options) = try XCTUnwrap(rows.first { $0.key == .percentageMode }).value else {
            return XCTFail("Percentage choice must stay available")
        }
        XCTAssertEqual(selected, "remaining"); XCTAssertTrue(options.contains("used"))
        var old = defaults; old.theme = .day; old.opening = .hold
        var environment = SettingsEnvironment(); environment.v1NormalEntry = true
        environment.macOSMajor = 15; environment.entranceAccepted = true
        let effective = EffectiveSettings(old, environment: environment)
        XCTAssertTrue(effective.darkAppearance, "V1 is night only even for a retained day preference")
        XCTAssertEqual(effective.opening, .quick, "V1 opens quickly even with a retained hold preference")
        XCTAssertNil(effective.ignitionSeconds)
    }
    func testV1SystemFallbackRowsFollowTheObservedService() throws {
        var context = SettingsPageContext(); context.configureV1NormalEntry()
        func keys() throws -> Set<SettingKey> { Set(try SettingsCatalogue.rows(preferences: .init(), context: context).map(\.key)) }
        XCTAssertTrue(try keys().isDisjoint(with: [.loginSystemSettings, .notificationSystemSettings]), "nothing is wrong until the host has asked")
        context.loginServiceObserved = true; context.notificationServiceObserved = true
        context.capabilities.login = .requiresApproval; context.notificationAuthorization = .denied
        XCTAssertTrue(try keys().isSuperset(of: [.loginSystemSettings, .notificationSystemSettings]))
        context.capabilities.login = .enabled; context.notificationAuthorization = .authorized
        XCTAssertTrue(try keys().isDisjoint(with: [.loginSystemSettings, .notificationSystemSettings]))
    }
    func testV1NoEffectControlsAreDisabledWithVisibleReasons() throws {
        var context = SettingsPageContext(); context.configureV1NormalEntry()
        let rows = try SettingsCatalogue.rows(preferences: .init(), context: context)
        XCTAssertFalse(rows.contains { $0.key == .automaticUpdates || $0.key == .updateStatus })
        let keys: [SettingKey] = [.login, .menuDisplay, .openShortcut, .dockShortcut,
            .resetHints, .magnification, .sliverAlert, .percentagePin, .order,
            .visible, .alias, .notificationConsent, .reset, .official,
            .projectNames, .fullscreen,
            .websiteLink, .methodologyLink, .privacyLink, .repositoryLink, .feedback, .clearAppCache]
        for key in keys {
            let row = try XCTUnwrap(rows.first { $0.key == key }, "Missing visible key: \(key)")
            XCTAssertEqual(row.availability, .serviceUnavailable, "A no-effect control must not remain enabled: \(key)")
            XCTAssertTrue(row.subtitle.english.contains("Unavailable"), "Provide an English visible reason: \(key)")
            XCTAssertTrue(row.subtitle.chinese.contains("不可用"), "Provide a Chinese visible reason: \(key)")
        }
        for key in [SettingKey.size, .dockEdge, .dockDisplay, .dockPosition, .percentageMode, .showPercentages, .redBelow, .language] {
            XCTAssertEqual(try XCTUnwrap(rows.first { $0.key == key }).availability, .available)
        }
    }

    @MainActor func testDisabledControlsShowReasonAndDoNotClaimShortcutWorks() async throws {
        var context = SettingsPageContext(); context.configureV1NormalEntry()
        let preferences = SettingsPreferences(), snapshot = SettingsSnapshot(revision: 0, preferences: preferences)
        let rows = try SettingsCatalogue.rows(preferences: preferences, context: context)
        let target = V1RowTarget()
        func apply(_ key: SettingKey, hasHost: Bool) throws -> SettingsNativeRow {
            let row = SettingsNativeRow(key: key)
            row.apply(try XCTUnwrap(rows.first { $0.key == key }), language: .english, saving: false,
                input: nil, reduced: false, onChoice: #selector(V1RowTarget.selected(_:)), target: target,
                snapshot: snapshot, context: context, holdAvailable: false, hasHost: hasHost,
                onEdit: { _, _ in }, onSurfaceAction: { _, _ in }, onDraftCleared: { _ in })
            return row
        }
        let shortcut = try apply(.openShortcut, hasHost: false)
        XCTAssertFalse(try XCTUnwrap(shortcut.shortcut).isEnabled)
        let reason = try XCTUnwrap(context.unavailableControls[.openShortcut]).value(.english)
        XCTAssertFalse(shortcut.subtitle.isHiddenOrHasHiddenAncestor, "The disabled reason must be visible")
        XCTAssertEqual(shortcut.subtitle.stringValue, reason)
        XCTAssertTrue(reason.contains("Unavailable")); XCTAssertFalse(reason.contains("works in app"))
        let rightSideText = shortcut.controls.arrangedSubviews.compactMap { $0 as? NSTextField }
            .filter { !$0.isHiddenOrHasHiddenAncestor }.map(\.stringValue)
        XCTAssertFalse(rightSideText.contains(reason), "The visible reason must not be duplicated below the control")
        let feedback = try apply(.feedback, hasHost: true)
        XCTAssertFalse(try XCTUnwrap(feedback.surfaceAction).isEnabled, "A host alone cannot enable an unavailable action")
        let diagnostics = try apply(.diagnostics, hasHost: false)
        XCTAssertTrue(try XCTUnwrap(diagnostics.surfaceAction).isEnabled, "Existing local diagnostics remain available")
    }

    func testUnavailableFirstRunPreviewHasVisibleReason() {
        XCTAssertEqual(SettingsWords.firstRunPreviewTitle(language: .english, unavailable: true), "First run… (unavailable until setup is connected)")
        XCTAssertEqual(SettingsWords.firstRunPreviewTitle(language: .chinese, unavailable: true), "首次运行…（设置接通前不可用）")
        XCTAssertEqual(SettingsWords.firstRunPreviewTitle(language: .english, unavailable: false), "First run…")
    }

    @MainActor func testFreshV1ShortcutsAreUnassignedAndCannotTrigger() async throws {
        let preferences = SettingsPreferences()
        XCTAssertNoThrow(try preferences.validate())
        XCTAssertFalse(preferences.openShortcut.isValid, "The cockpit shortcut starts unassigned")
        XCTAssertFalse(preferences.dockShortcut.isValid, "The Dock shortcut starts unassigned")
        XCTAssertNil(ShortcutPolicy().action(for: preferences.openShortcut, preferences: preferences, global: false))
        XCTAssertNil(ShortcutPolicy().action(for: preferences.dockShortcut, preferences: preferences, global: false))
        XCTAssertEqual(SettingsShortcutControl.label(preferences.openShortcut, language: .english), "Not assigned")
        XCTAssertEqual(SettingsShortcutControl.label(preferences.openShortcut, language: .chinese), "未设置")
        let rows = try SettingsCatalogue.rows(preferences: preferences, context: .init())
        XCTAssertEqual(try XCTUnwrap(rows.first { $0.key == .openShortcut }).value, .text("--"))
        XCTAssertEqual(try XCTUnwrap(rows.first { $0.key == .dockShortcut }).value, .text("--"))
    }

}
