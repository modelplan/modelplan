// SPDX-License-Identifier: MIT
import AppKit
import Foundation
import XCTest
import ModelPlanEngineClient
@testable import ModelPlanSettings
@testable import ModelPlanAppIntegration

@MainActor private final class NotFoundLoginService: PulseLoginService {
    var state: PulseLoginState
    let isNotFound: Bool
    init(state: PulseLoginState, notFound: Bool) { self.state = state; isNotFound = notFound }
    func register() throws {}
    func unregister() throws {}
}

/// G3-69 / SET-9-33 through the normal entry: a login item macOS reports as `.notFound` says the app is
/// not in Applications and offers "Show how" in the real Settings > General row. Read-only observed state.
@MainActor final class G369LoginNotInApplicationsJourneyTests: XCTestCase {
    private func makeApp(_ profile: URL, service: NotFoundLoginService) throws -> EngineDockMenuApplication {
        let config = EngineClientConfiguration(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic",
                                               allowedEnvironment: [:], offline: true, readOnly: true)
        let app = EngineRowsEntry.make(configuration: config,
            settingsStore: try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en-US"]),
            createsNativePanels: false, dockEnvironment: normalEntryTestEnvironment, activateSettings: {})
        app.loginServiceAdapter = CommunityLoginServiceAdapter(item: .init(isAppBundle: true, service: service))
        return app
    }
    private func flatten(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(flatten) }
    private func loginRow(_ app: EngineDockMenuApplication) async throws -> SettingsNativeRow {
        let before = Set(NSApplication.shared.windows.map(ObjectIdentifier.init))
        await app.settingsHost.present(paneID: "general", origin: .userInitiated)
        let window = try XCTUnwrap(NSApplication.shared.windows.first { !before.contains(ObjectIdentifier($0)) && $0.isVisible })
        addTeardownBlock { @MainActor in window.close() }
        let root = try XCTUnwrap(window.contentView)
        return try XCTUnwrap(flatten(root).compactMap { $0 as? SettingsNativeRow }.first { $0.key == .login }, "open-at-login row missing")
    }
    private func texts(_ row: SettingsNativeRow) -> [String] {
        flatten(row).compactMap { ($0 as? NSTextField)?.stringValue }
    }
    func testNotFoundLoginItemSaysNotInApplicationsAndShowsHowInBothLanguages() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g3-69-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let app = try makeApp(profile, service: NotFoundLoginService(state: .unavailable, notFound: true))
        await app.prepare()
        let editor = app.settingsHost.application.editor
        XCTAssertTrue(editor.context.capabilities.loginNotInApplications)
        let row = try await loginRow(app)
        for (language, chinese) in [(SettingsLanguage.english, false), (.chinese, true)] {
            _ = try await editor.commit(SettingsB21Edit.language(language))
            try await Task.sleep(for: .milliseconds(200))
            let notice = SettingsNativeRow.loginStatus(.unavailable, notInApplications: true, language: language)
            let steps = SettingsNativeRow.loginHowTo(language: language)
            XCTAssertTrue(notice.contains(chinese ? "应用程序" : "Applications folder"), notice)
            XCTAssertTrue(texts(row).contains(notice), "row must show the not-in-Applications copy: \(texts(row))")
            XCTAssertFalse(row.loginHowButton.isHidden)
            XCTAssertEqual(row.loginHowButton.title, chinese ? "显示操作步骤" : "Show how")
            XCTAssertTrue(row.loginHowLabel.isHidden, "steps stay collapsed until asked")
            row.loginHowButton.performClick(nil)
            XCTAssertFalse(row.loginHowLabel.isHidden, "Show how reveals the steps")
            XCTAssertEqual(row.loginHowLabel.stringValue, steps)
            row.loginHowButton.performClick(nil)
            XCTAssertTrue(row.loginHowLabel.isHidden, "a second click hides the steps again")
        }
        await app.composition.stop()
    }
    func testEnabledLoginItemShowsNoNotInApplicationsCopy() async throws {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g3-69-ok-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: profile) }
        let app = try makeApp(profile, service: NotFoundLoginService(state: .on, notFound: false))
        await app.prepare()
        let editor = app.settingsHost.application.editor
        XCTAssertFalse(editor.context.capabilities.loginNotInApplications)
        let row = try await loginRow(app)
        for language in [SettingsLanguage.english, .chinese] {
            _ = try await editor.commit(SettingsB21Edit.language(language))
            try await Task.sleep(for: .milliseconds(200))
            let notice = SettingsNativeRow.loginStatus(.unavailable, notInApplications: true, language: language)
            XCTAssertFalse(texts(row).contains(notice))
            XCTAssertTrue(row.loginHowButton.isHidden, "no Show how control when the app is in Applications")
            XCTAssertTrue(row.loginHowLabel.isHidden)
        }
        await app.composition.stop()
    }
}
