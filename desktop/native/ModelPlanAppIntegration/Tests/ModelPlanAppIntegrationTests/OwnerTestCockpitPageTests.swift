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
    /// The production page factory (`CockpitConsoleOwner.makePage`, which every menu and Dock route reaches through
    /// the coordinator) on the packaged shapes, then the real WKWebView page from the canonical official build.
    @MainActor func testOwnerTestPackageLoadsTheRealCockpitPageAndReleaseShapeRefusesIt() async throws {
        guard let path = ProcessInfo.processInfo.environment["MODELPLAN_U11_TEST_CLI"],
              FileManager.default.isExecutableFile(atPath: path) else { throw XCTSkip("The real synthetic-test CLI is not available") }
        let official = Self.repoRoot().appendingPathComponent("desktop/cockpit/.tmp/official")
        guard FileManager.default.fileExists(atPath: official.appendingPathComponent("bundle-manifest.json").path) else {
            throw XCTSkip("Build the canonical official cockpit first")
        }
        for ownerTest in [true, false] {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("owner-test-page-" + UUID().uuidString)
                .resolvingSymlinksInPath()
            defer { try? FileManager.default.removeItem(at: root) }
            let app = try Self.ownerTestShapedApp(at: root, helper: URL(fileURLWithPath: path), ownerTest: ownerTest, official: official)
            let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: root.appendingPathComponent("support"), preferredLanguages: ["en"])
            let owner = CockpitConsoleOwner(bundle: app, settingsStore: settings)
            let context = try CockpitEngineContext(sessionID: UUID(), storeEpoch: "synthetic-owner-test", generation: 1)
            let helper = app.appendingPathComponent("Contents/Helpers/modelplan")
            guard ownerTest else {
                XCTAssertThrowsError(try owner.makePage(context: context, executable: helper),
                                     "a release-shaped unverified bundle must not get a cockpit page")
                continue
            }
            let page = try owner.makePage(context: context, executable: helper)
            page.open()
            var state = "none"
            let deadline = ContinuousClock.now + .seconds(30)
            while ContinuousClock.now < deadline {
                if let web = page.verificationWebView {
                    let result: Any? = try? await web.evaluateJavaScript(
                        "document.querySelector('#cockpit.ck')&&window.modelPlanCockpit?window.modelPlanCockpit.state():'none'")
                    if let value = result as? String, value != "none" { state = value; break }
                }
                try await Task.sleep(for: .milliseconds(50))
            }
            XCTAssertNotEqual(state, "none", "the official page must load from Resources/Cockpit and mount the cockpit")
            page.discard()
        }
    }

    /// G3-42: where the time goes from a click to a ready page, on the production factory and the real
    /// WKWebView. Hosted-runner numbers are rough; compare stages and runs, never absolute targets.
    @MainActor func testG3_42OpenStageTimings() async throws {
        let official = Self.repoRoot().appendingPathComponent("desktop/cockpit/.tmp/official")
        guard let path = ProcessInfo.processInfo.environment["MODELPLAN_U11_TEST_CLI"],
              FileManager.default.isExecutableFile(atPath: path),
              FileManager.default.fileExists(atPath: official.appendingPathComponent("bundle-manifest.json").path) else {
            throw XCTSkip("The real page needs the canonical official cockpit and the synthetic-test CLI")
        }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("g3-42-" + UUID().uuidString).resolvingSymlinksInPath()
        defer { try? FileManager.default.removeItem(at: root) }
        let app = try Self.ownerTestShapedApp(at: root, helper: URL(fileURLWithPath: path), ownerTest: true, official: official)
        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: root.appendingPathComponent("support"), preferredLanguages: ["en"])
        let owner = CockpitConsoleOwner(bundle: app, settingsStore: settings)
        let helper = app.appendingPathComponent("Contents/Helpers/modelplan")
        func ms(_ start: ContinuousClock.Instant) -> Int {
            let (seconds, attoseconds) = (ContinuousClock.now - start).components
            return Int(seconds) * 1000 + Int(attoseconds / 1_000_000_000_000_000)
        }
        for run in 1...4 {
            let context = try CockpitEngineContext(sessionID: UUID(), storeEpoch: "synthetic-owner-test", generation: 1)
            let click = ContinuousClock.now
            let page = try owner.makePage(context: context, executable: helper)
            let factory = ms(click)
            var ready: Int?
            page.onReady = { if ready == nil { ready = ms(click) } }
            page.open()
            let opened = ms(click)
            let deadline = ContinuousClock.now + .seconds(30)
            while ready == nil, ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(2)) }
            let resources = (try? await page.verificationWebView?.evaluateJavaScript("performance.getEntriesByType('resource').length")) as? Int
            print("G3-42-TIMING run=\(run) factoryMs=\(factory) openMs=\(opened) pageReadyMs=\(ready.map(String.init) ?? "timeout") resources=\(resources ?? -1)")
            XCTAssertNotNil(ready)
            page.discard()
        }
    }
    #endif
}
