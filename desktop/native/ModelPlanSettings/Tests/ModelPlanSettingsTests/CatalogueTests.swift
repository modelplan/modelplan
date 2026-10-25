// SPDX-License-Identifier: MIT
import Foundation
import XCTest
@testable import ModelPlanSettings

final class CatalogueTests: XCTestCase {
    private func context() -> SettingsPageContext {
        var c = SettingsPageContext()
        c.subscriptions = [
            .init(id: "one", name: .init("Provider", "厂家"), plan: "Basic", vendor: "vendor", modelNames: ["Model Alpha"], toolNames: ["Tool A"], source: .fresh),
            .init(id: "two", name: .init("Provider", "厂家"), plan: "Plus", vendor: "vendor", modelNames: ["Model Beta"], source: .stale),
        ]
        return c
    }
    func testF15AllEightPanesHaveUniqueRowsAndBilingualSubtitles() throws {
        let rows = try SettingsCatalogue.rows(preferences: .init(), context: context())
        XCTAssertEqual(Set(rows.map(\.key)), Set(SettingKey.allCases))
        XCTAssertEqual(rows.count, SettingKey.allCases.count)
        XCTAssertEqual(Set(rows.map(\.pane)), Set(SettingsPane.allCases))
        for row in rows {
            for text in [row.title.english, row.title.chinese, row.subtitle.english, row.subtitle.chinese] {
                XCTAssertFalse(text.isEmpty); XCTAssertFalse(text.contains("\n"))
            }
        }
        for pane in SettingsPane.allCases {
            let page = try SettingsCatalogue.rows(preferences: .init(), context: context(), pane: pane)
            XCTAssertFalse(page.isEmpty); XCTAssertTrue(page.allSatisfy { $0.pane == pane })
        }
    }
    func testSearchIsBilingualAndFiltersSubscriptionsByAliasPlanModelAndTool() throws {
        var p = SettingsPreferences(); p.subscriptions.hiddenIDs = ["two"]
        p.subscriptionSettings["two"] = .init(alias: "工作")
        let c = context()
        for language in SettingsLanguage.allCases {
            p.language = language
            for query in ["THEME", "主题", "ＴＨＥＭＥ"] {
                XCTAssertTrue(try SettingsCatalogue.rows(preferences: p, context: c, query: query).contains { $0.key == .theme })
            }
            for query in ["工作", "Plus", "Model Beta"] {
                let found = try SettingsCatalogue.rows(preferences: p, context: c, query: query)
                XCTAssertEqual(found.count, 5)
                for row in found {
                    guard case .subscriptions(let values) = row.value else { return XCTFail("Expected subscription data") }
                    XCTAssertEqual(values.map(\.id), ["two"])
                }
            }
            let tools = try SettingsCatalogue.rows(preferences: p, context: c, query: "Tool A")
            XCTAssertEqual(tools.count, 5)
            let source = try XCTUnwrap(SettingsCatalogue.rows(preferences: p, context: c).first { $0.key == .source })
            guard case .subscriptions(let values) = source.value else { return XCTFail() }
            XCTAssertEqual(values.map(\.value), ["fresh", "stale"])
            XCTAssertEqual(values.map(\.plan), ["Basic", "Plus"])
        }
        XCTAssertTrue(try SettingsCatalogue.rows(preferences: p, context: c, query: "does-not-match").isEmpty)
        XCTAssertEqual(try SettingsCatalogue.rows(preferences: p, context: c, query: "   ").count, SettingKey.allCases.count)
    }
    func testUnavailableActionsHaveNoMutationAndLoginUsesObservedServiceState() throws {
        var c = context(); c.capabilities.login = .requiresApproval
        var rows = try SettingsCatalogue.rows(preferences: .init(), context: c)
        func row(_ key: SettingKey) throws -> SettingsRow { try XCTUnwrap(rows.first { $0.key == key }) }
        XCTAssertEqual(try row(.login).value, .text("requiresApproval"))
        XCTAssertEqual(try row(.captureHiding).availability, .unsupportedCaptureHiding)
        XCTAssertEqual(try row(.clearCLI).availability, .cliOwned); XCTAssertEqual(try row(.clearCLI).value, .action(nil))
        XCTAssertEqual(try row(.retention).value, .text("sessions=35d; dailyTotals=371d; owner=CLI"))
        XCTAssertEqual(try row(.clearAppCache).availability, .cacheUnavailable)
        XCTAssertNil(c.capabilities.clearRequest)
        c.capabilities.appCacheClearAvailable = true; c.capabilities.login = .unavailable
        rows = try SettingsCatalogue.rows(preferences: .init(), context: c)
        XCTAssertEqual(try row(.clearAppCache).value, .action(.clearAppCache))
        XCTAssertEqual(try row(.login).availability, .serviceUnavailable)
        XCTAssertNil(c.capabilities.loginRequest(enabled: true))
        c.capabilities.login = .notRegistered
        XCTAssertEqual(c.capabilities.loginRequest(enabled: true), .setLoginEnabled(true))
        XCTAssertEqual(c.capabilities.login, .notRegistered) // Intent is not a reported success.
    }
    func testDiagnosticsNeverIncludePersonalInputsOrRawErrors() throws {
        var c = context(), p = SettingsPreferences()
        p.subscriptionSettings["one"] = .init(alias: "private-project")
        c.about = .init(appVersion: "/Users/private/account@example.com", cliVersion: "error: secret", cliState: .denied, architecture: .intelUntested)
        let text = c.about.diagnosticText
        XCTAssertEqual(text, "app=unknown\ncli=unknown\ncliState=denied\narchitecture=intelUntested")
        c.about.appVersion = "secretToken"; XCTAssertEqual(c.about.version, "unknown")
        c.about.appVersion = "0.5.38-beta.1"; XCTAssertEqual(c.about.version, "0.5.38-beta.1")
        c.about.appVersion = "/Users/private/account@example.com"
        let rows = try SettingsCatalogue.rows(preferences: p, context: c, pane: .about)
        XCTAssertEqual(rows.first { $0.key == .diagnostics }?.value, .text(text))
        XCTAssertEqual(rows.first { $0.key == .feedback }?.value, .link(SettingsAbout.feedbackURL))
        XCTAssertEqual(rows.first { $0.key == .architecture }?.value, .text(SettingsAbout.intelNote.chinese))
    }
    func testBundledNoticesAndPerSubscriptionChoiceData() throws {
        var c = context()
        let notice = SettingsLicenseNotice(component: "Synthetic component", license: "MIT", text: "Synthetic notice")
        c.licenseNotices = [notice]
        let rows = try SettingsCatalogue.rows(preferences: .init(), context: c)
        XCTAssertEqual(rows.first { $0.key == .licenses }?.value, .notices([notice]))
        guard case .subscriptions(let pins) = rows.first(where: { $0.key == .percentagePin })?.value else { return XCTFail() }
        XCTAssertTrue(pins.allSatisfy { $0.options == ["auto", "5h", "week"] })
        guard case .subscriptions(let visibility) = rows.first(where: { $0.key == .visible })?.value else { return XCTFail() }
        XCTAssertTrue(visibility.allSatisfy { $0.options == ["true", "false"] })
    }
    func testDuplicateIDsAreRejectedButDuplicateVendorsAreAllowed() throws {
        var c = context()
        XCTAssertNoThrow(try SettingsCatalogue.rows(preferences: .init(), context: c))
        c.subscriptions.append(c.subscriptions[0])
        XCTAssertThrowsError(try SettingsCatalogue.rows(preferences: .init(), context: c))
        c.subscriptions = []; XCTAssertEqual(try SettingsCatalogue.rows(preferences: .init(), context: c).count, SettingKey.allCases.count)
    }
}
