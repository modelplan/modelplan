// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import CryptoKit
import WebKit
import ModelPlanCockpitWeb
@testable import ModelPlanAppIntegration

/// Owner D39/D-E (#611 Q1/Q2): an owner test package must actually load the cockpit page, not only enable the menu item.
/// The bundle is shaped exactly as `package-neutral.sh --owner-test` writes it: unverified consent identity, real CLI
/// as the bundled helper with both pins, the canonical official page in Resources/Cockpit, the entry flag and the
/// owner-test marker. The release shape is the same bundle without the marker; its page must be refused.
extension CommunityCockpitEntryTests {
    private static func repoRoot() -> URL {
        var repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 where !FileManager.default.fileExists(atPath: repo.appendingPathComponent("desktop/cockpit/build.mjs").path) {
            repo.deleteLastPathComponent()
        }
        return repo
    }

    private static func ownerTestShapedApp(at root: URL, helper: URL, ownerTest: Bool, official: URL) throws -> URL {
        let app = root.appendingPathComponent("ModelPlan Community.app"), contents = app.appendingPathComponent("Contents")
        let fm = FileManager.default
        for dir in ["MacOS", "Helpers", "Resources"] {
            try fm.createDirectory(at: contents.appendingPathComponent(dir), withIntermediateDirectories: true)
        }
        let bundled = contents.appendingPathComponent("Helpers/modelplan")
        try fm.copyItem(at: helper, to: bundled)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: bundled.path)
        let digest = SHA256.hash(data: try Data(contentsOf: bundled)).map { String(format: "%02x", $0) }.joined()
        try Data((digest + "\n").utf8).write(to: contents.appendingPathComponent("Resources/modelplan.sha256"))
        try fm.copyItem(at: official, to: contents.appendingPathComponent("Resources/Cockpit"))
        try Data(#"{"edition": "official", "stage": "owner-test"}"#.utf8).write(to: contents.appendingPathComponent("Resources/build-edition.json"))
        var info: [String: Any] = ["CFBundleIdentifier": "org.modelplan.community.swift.scaffold", "CFBundleExecutable": "ModelPlanCommunity",
                                   "CFBundlePackageType": "APPL", "ModelPlanCockpitEntryEnabled": true,
                                   "ModelPlanPublicSource": String(repeating: "a", count: 40), "ModelPlanBundledHelperSHA256": digest]
        if ownerTest { info[CommunityConsentBundleIdentity.ownerTestKey] = true }
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: contents.appendingPathComponent("Info.plist"))
        return app
    }

    /// Identity gate only: no CLI, no window. Runs in every leg.
    func testOwnerTestIdentityAdmitsOnlyTheMarkedPinnedBundle() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("owner-test-identity-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let helper = root.appendingPathComponent("helper"), page = root.appendingPathComponent("page")
        try FileManager.default.createDirectory(at: page, withIntermediateDirectories: true)
        try Data("synthetic helper".utf8).write(to: helper)
        try Data("synthetic page".utf8).write(to: page.appendingPathComponent("index.html"))
        for ownerTest in [true, false] {
            let app = try Self.ownerTestShapedApp(at: root.appendingPathComponent(String(ownerTest)), helper: helper, ownerTest: ownerTest, official: page)
            XCTAssertEqual(CommunityConsentBundleIdentity.matchesOwnerTest(bundle: app), ownerTest)
            XCTAssertFalse(CommunityConsentBundleIdentity.matches(bundle: app), "an owner test build stays unverified for consent")
            guard ownerTest else { continue }
            // A tampered helper, a closed entry or a missing pin each refuse the page.
            let plist = app.appendingPathComponent("Contents/Info.plist")
            let original = try Data(contentsOf: plist)
            var info = try XCTUnwrap(PropertyListSerialization.propertyList(from: original, format: nil) as? [String: Any])
            info["ModelPlanCockpitEntryEnabled"] = false
            try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: plist)
            XCTAssertFalse(CommunityConsentBundleIdentity.matchesOwnerTest(bundle: app))
            try original.write(to: plist)
            let bundled = app.appendingPathComponent("Contents/Helpers/modelplan")
            let bytes = try Data(contentsOf: bundled)
            try Data("tampered".utf8).write(to: bundled)
            XCTAssertFalse(CommunityConsentBundleIdentity.matchesOwnerTest(bundle: app))
            try bytes.write(to: bundled)
            try FileManager.default.removeItem(at: app.appendingPathComponent("Contents/Resources/modelplan.sha256"))
            XCTAssertFalse(CommunityConsentBundleIdentity.matchesOwnerTest(bundle: app))
        }
    }

    #if MODELPLAN_TEST_ONLY_SPI
    /// Full normal entry: real app-server, real page factory, real WKWebView page from the canonical official build.
    @MainActor func testOwnerTestPackageLoadsTheRealCockpitPageAndReleaseShapeRefusesIt() async throws {
        guard let path = ProcessInfo.processInfo.environment["MODELPLAN_U11_TEST_CLI"],
              FileManager.default.isExecutableFile(atPath: path) else { throw XCTSkip("The real synthetic-test CLI is not available") }
        let official = Self.repoRoot().appendingPathComponent("desktop/cockpit/.tmp/official")
        guard FileManager.default.fileExists(atPath: official.appendingPathComponent("bundle-manifest.json").path) else {
            throw XCTSkip("Build the canonical official cockpit first")
        }
        for ownerTest in [true, false] {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("owner-test-page-" + UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: root) }
            let home = root.appendingPathComponent("home")
            try FileManager.default.createDirectory(at: home.appendingPathComponent("Library/Caches/modelplan/observed"), withIntermediateDirectories: true)
            let app = try Self.ownerTestShapedApp(at: root, helper: URL(fileURLWithPath: path), ownerTest: ownerTest, official: official)
            let helper = app.appendingPathComponent("Contents/Helpers/modelplan")
            let environment = ["HOME": home.path, "TMPDIR": home.path, "PATH": "/usr/bin:/bin", "LANG": "C"]
            var pages: [CockpitWindowController] = []
            let previous = CommunityCockpitApplicationFactory.verificationPage
            CommunityCockpitApplicationFactory.verificationPage = { pages.append($0) }
            defer { CommunityCockpitApplicationFactory.verificationPage = previous }
            let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: home, preferredLanguages: ["en"])
            // No cockpitEntryEnabled override: the packaged Info.plist decides, as in the shipped app.
            let entry = EngineRowsEntry.make(configuration: .init(executableURL: helper, applicationVersion: "synthetic-owner-test",
                allowedEnvironment: environment, offline: true, readOnly: true), settingsStore: settings,
                createsNativePanels: false, bundleURL: app)
            await entry.prepare()
            await entry.composition.start()
            entry.showConsole()
            if ownerTest {
                var state = "none"
                let deadline = ContinuousClock.now + .seconds(30)
                while ContinuousClock.now < deadline {
                    if let web = pages.first?.verificationWebView {
                        let result: Any? = try? await web.evaluateJavaScript(
                            "document.querySelector('#cockpit.ck')&&window.modelPlanCockpit?window.modelPlanCockpit.state():'none'")
                        if let value = result as? String { state = value; if state != "none" { break } }
                    }
                    try await Task.sleep(for: .milliseconds(50))
                }
                XCTAssertEqual(pages.count, 1, "the owner test package must construct the real cockpit page")
                XCTAssertNotEqual(state, "none", "the official page must load and mount the cockpit")
            } else {
                try await Task.sleep(for: .seconds(3))
                XCTAssertTrue(pages.isEmpty, "a release-shaped unverified bundle must not load the cockpit page")
            }
            await entry.composition.stop()
            for page in pages { page.discard() }
        }
    }
    #endif
}
