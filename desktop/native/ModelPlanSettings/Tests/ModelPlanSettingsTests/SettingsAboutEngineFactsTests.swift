// SPDX-License-Identifier: MIT
import XCTest
import ModelPlanWire
@testable import ModelPlanSettings

/// G3-67: the copied diagnostics describe the running engine, not the defaults, and carry fixed names only.
@MainActor final class SettingsAboutEngineFactsTests: XCTestCase {
    func testEngineFactsFillCliReadersAndErrors() {
        var about = SettingsAbout(appVersion: "0.1.0")
        about.macOSVersion = "26.6.0"
        about.applyEngineFacts(cliVersion: "0.5.55", allowedTools: ["claude", "codex", "kiro", "zai", "not-a-tool"],
                               reasonCodes: [.ok, .keychainUnset, .keychainDenied, .runtimeMissing, .staleReading, .updateRequired])
        XCTAssertEqual(about.diagnosticText,
                       "app=0.1.0\ncli=0.5.55\nmacOS=26.6.0\nreaders=claude,codex,kiro,zai\nerrors=permissionDenied,readerUnavailable,stale,unsupported")
    }
    func testNoAcceptedSessionReportsTheCliAsUnavailableAndKeepsNothingStale() {
        var about = SettingsAbout(appVersion: "0.1.0")
        about.applyEngineFacts(cliVersion: "0.5.55", allowedTools: ["codex"], reasonCodes: [.keychainUnset])
        about.applyEngineFacts(cliVersion: nil, allowedTools: [], reasonCodes: [])
        XCTAssertTrue(about.diagnosticText.contains("readers=\n"))
        XCTAssertTrue(about.diagnosticText.hasSuffix("errors=cliUnavailable"))
    }
    func testCopiedTextNeverCarriesFreeText() {
        var about = SettingsAbout(appVersion: "0.1.0")
        about.applyEngineFacts(cliVersion: "/Users/someone/0.5.55", allowedTools: ["/Users/someone", "codex"], reasonCodes: [.ok])
        XCTAssertTrue(about.diagnosticText.contains("cli=unknown"))
        XCTAssertTrue(about.diagnosticText.contains("readers=codex\n"))
        XCTAssertFalse(about.diagnosticText.contains("someone"))
    }
}
