// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanCore
import ModelPlanShell
import ModelPlanSettings
@testable import ModelPlanCommunityHost
@testable import ModelPlanAppIntegration

@MainActor final class CommunityMenuBarTests: XCTestCase {
    private actor NoEffects: CLITransport, ConsentJSONTransport {
        func execute(_ command: CLICommand) async throws -> CommandResult { XCTFail("No reader/helper in menu-bar checks"); throw TransportError.launchFailed }
        func readConsentJSON() async throws -> CommandResult { XCTFail("No consent inspection in construction"); throw TransportError.launchFailed }
        func grantConsentJSON(_ data: Data) async throws -> CommandResult { XCTFail("No grants in menu-bar checks"); throw TransportError.launchFailed }
    }
    private func delegate() -> CommunityDelegate {
        let fake = NoEffects()
        let port = CommunityCLIConsentPort(transport: fake, apiAvailable: false)
        let backend = CommunityConnectionBackend(port: port, desktop: .init(readOnly: fake, normal: fake))
        return CommunityApplicationFactory.makeDelegate(surfaces: NeutralSurfaceProvider(), consentBackend: backend, transport: fake) { _ in
            XCTFail("Construction must not create Settings or runtime"); throw SettingsConnectionFailure.unavailable
        }
    }
    func testActualFactoryWiresExistingTemplateAndIconOnlyEmptyStateWithoutAStatusItem() throws {
        let host = delegate(), button = NSButton()
        button.contentTintColor = .red
        host.updateMenuBar(snapshot: nil, diagnostics: .init(), now: Date(), button: button)
        XCTAssertNil(host.status); XCTAssertNil(button.window)
        XCTAssertEqual(button.title, ""); XCTAssertEqual(button.imagePosition, .imageOnly)
        XCTAssertTrue(try XCTUnwrap(button.image).isTemplate)
        XCTAssertNil(button.contentTintColor)
        XCTAssertTrue(host.menuBarReadingItem.title.contains("Settings"))
        XCTAssertFalse(host.menuBarReadingItem.isEnabled)
        let image = try XCTUnwrap(CommunityMenuBarResources.templateImage())
        XCTAssertTrue(image.isTemplate)
        let bundled = try XCTUnwrap(Bundle(url: CommunityMenuBarResources.buildBundleURL)?.url(forResource: "tray", withExtension: "png", subdirectory: "Resources"))
        var repo = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 { repo.deleteLastPathComponent() }
        XCTAssertEqual(try Data(contentsOf: bundled), try Data(contentsOf: repo.appendingPathComponent("desktop/src-tauri/icons/tray.png")))
    }
    func testPackagedResourceLookupDoesNotDependOnTheBuildCheckout() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("menu-bar-bundle-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = root.appendingPathComponent("Synthetic.app")
        let resources = app.appendingPathComponent("Contents/Resources")
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        XCTAssertNil(CommunityMenuBarResources.templateImage(appURL: app))
        try FileManager.default.copyItem(at: CommunityMenuBarResources.buildBundleURL,
            to: resources.appendingPathComponent(CommunityMenuBarResources.bundleName))
        XCTAssertTrue(try XCTUnwrap(CommunityMenuBarResources.templateImage(appURL: app)).isTemplate)
    }
    private var now: Date { try! WireInstant("2026-10-29T00:00:30Z").date }
    private func account(_ source: String, _ values: [Double]) -> [String: Any] {
        ["source": source, "observedAt": "2026-10-29T00:00:00Z", "windows": values.enumerated().map { index, value in
            ["kind": index == 0 ? "five_hour" : "weekly", "remainingPercent": value, "resetsAt": "2026-10-29T02:00:00Z"] as [String: Any]
        }]
    }
    private func joined(_ accounts: [[String: Any]], expiry: String = "2026-10-29T00:10:00Z") throws -> JoinedSnapshot {
        // Deliberate behavior mutations of the shared real-CLI capture, not a second positive wire fixture set.
        var object = try GeneratedAppCLIFixtures.object("fresh-desktop.json")
        object["generatedAt"] = "2026-10-29T00:00:00Z"; object["validUntil"] = expiry
        object["accounts"] = accounts; object["sources"] = []
        let personal = try FeedDecoder.personal(JSONSerialization.data(withJSONObject: object))
        var ledger = ExpiryLedger()
        return .make(personal: personal, presentation: .evaluate(personal, now: now, ledger: &ledger), publication: nil)
    }
    private var ready: StoreDiagnostics { var value = StoreDiagnostics(); value.personal = nil; return value }
    func testActualFactoryChoosesLowestWindowAcrossCurrentAccountsAndNamesItInTheMenu() throws {
        let host = delegate(), button = NSButton()
        let snapshot = try joined([account("codex", [80, 40]), account("native:gemini", [23])])
        host.updateMenuBar(snapshot: snapshot, diagnostics: ready, now: now, button: button)
        XCTAssertEqual(button.title, "23%")
        XCTAssertEqual(button.imagePosition, .imageLeading)
        XCTAssertTrue(host.menuBarReadingItem.title.contains("Gemini"))
        XCTAssertTrue(host.menuBarReadingItem.title.contains("23%"))
        XCTAssertEqual(host.menuBarPresentation.title, "23%")
        XCTAssertNil(host.status); XCTAssertNil(button.window)
    }
    func testNoColourAtAnyLevelAndZeroIsARealReading() throws {
        let host = delegate(), button = NSButton()
        for value in [0.0, 12, 80, 100] {
            button.contentTintColor = .red
            button.attributedTitle = NSAttributedString(string: "old", attributes: [.foregroundColor: NSColor.red])
            host.updateMenuBar(snapshot: try joined([account("codex", [value])]), diagnostics: ready, now: now, button: button)
            XCTAssertEqual(button.title, "\(Int(value))%")
            XCTAssertNil(button.contentTintColor)
            XCTAssertTrue(try XCTUnwrap(button.image).isTemplate)
            if button.attributedTitle.length > 0 {
                XCTAssertNotEqual(button.attributedTitle.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor, .red)
            }
        }
    }
    func testUnusableReadingsCannotWinTheMinimumAndNoReadingIsIconOnly() throws {
        var stale = account("codex", [1]); stale["stale"] = true
        var future = account("native:gemini", [2]); future["observedAt"] = "2027-01-01T00:00:00Z"
        var unknown = account("native:kiro", [3]); unknown.removeValue(forKey: "observedAt")
        var reason = account("native:kimi", [4])
        var windows = try XCTUnwrap(reason["windows"] as? [[String: Any]])
        windows[0]["unknownReason"] = "synthetic-unavailable"; reason["windows"] = windows
        let host = delegate(), button = NSButton()
        host.updateMenuBar(snapshot: try joined([stale, future, unknown, reason, account("native:grok", [50])]), diagnostics: ready, now: now, button: button)
        XCTAssertEqual(button.title, "50%")
        XCTAssertTrue(host.menuBarReadingItem.title.contains("Grok"))
        for snapshot in [try joined([stale, future, unknown, reason]), try joined([account("codex", [10])], expiry: "2026-10-29T00:00:00Z")] {
            host.updateMenuBar(snapshot: snapshot, diagnostics: ready, now: now, button: button)
            XCTAssertEqual(button.title, ""); XCTAssertEqual(button.imagePosition, .imageOnly)
            XCTAssertFalse(button.title.contains("--")); XCTAssertFalse(button.title.contains("?"))
            XCTAssertTrue(host.menuBarReadingItem.title.contains("Settings"))
        }
    }
    func testUnavailableReadClearsPreviouslyRenderedValueAndSource() throws {
        let host = delegate(), button = NSButton(), snapshot = try joined([account("codex", [13])])
        host.updateMenuBar(snapshot: snapshot, diagnostics: ready, now: now, button: button)
        XCTAssertEqual(button.title, "13%")
        var failed = ready; failed.personal = "personal-read-unavailable"
        host.updateMenuBar(snapshot: snapshot, diagnostics: failed, now: now, button: button)
        XCTAssertEqual(button.title, ""); XCTAssertEqual(button.imagePosition, .imageOnly)
        XCTAssertFalse(host.menuBarReadingItem.title.contains("Codex"))
        XCTAssertFalse(host.menuBarReadingItem.title.contains("13%"))
    }
    func testMinimumUsesOriginalNumbersBeforeRoundingAndKeepsFirstTieStable() throws {
        let presenter = CommunityMenuBarProjector()
        let rounded = presenter.make(snapshot: try joined([account("codex", [0.49]), account("native:gemini", [0.4])]), diagnostics: ready, now: now)
        XCTAssertEqual(rounded.title, "0%")
        XCTAssertTrue(rounded.detail.contains("Gemini"))
        let tied = presenter.make(snapshot: try joined([account("codex", [23]), account("native:gemini", [23])]), diagnostics: ready, now: now)
        XCTAssertEqual(tied.title, "23%")
        XCTAssertTrue(tied.detail.contains("Codex"))
    }

    func testGeneratedCurrentFreshCaptureRemainsIconOnlyWithoutInventingValues() throws {
        let personal = try FeedDecoder.personal(GeneratedAppCLIFixtures.data("fresh-desktop.json"))
        let at = personal.generatedAt.date.addingTimeInterval(1)
        var ledger = ExpiryLedger()
        let snapshot = JoinedSnapshot.make(personal: personal, presentation: .evaluate(personal, now: at, ledger: &ledger), publication: nil)
        let host = delegate(), button = NSButton()
        host.updateMenuBar(snapshot: snapshot, diagnostics: ready, now: at, button: button)
        XCTAssertEqual(button.title, ""); XCTAssertEqual(button.imagePosition, .imageOnly)
        XCTAssertTrue(try XCTUnwrap(button.image).isTemplate)
        XCTAssertTrue(host.menuBarReadingItem.title.contains("Settings"))
    }

}
