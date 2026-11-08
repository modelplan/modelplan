// SPDX-License-Identifier: MIT
import AppKit
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

    /// CKP-SHELL-25 / owner review 11-08 on the real page and panel: the cockpit window is clear around the hull. The
    /// panel and the web view paint no backing, and the web view's own rendering of the window is transparent at
    /// the corners outside the hull silhouette (the owner saw an opaque #1e1e1e slab).
    @MainActor func testCockpitWindowIsClearOutsideTheHull() async throws {
        let official = Self.repoRoot().appendingPathComponent("desktop/cockpit/.tmp/official")
        guard let path = ProcessInfo.processInfo.environment["MODELPLAN_U11_TEST_CLI"],
              FileManager.default.isExecutableFile(atPath: path),
              FileManager.default.fileExists(atPath: official.appendingPathComponent("bundle-manifest.json").path) else {
            throw XCTSkip("The real page needs the canonical official cockpit and the synthetic-test CLI")
        }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("clear-" + UUID().uuidString).resolvingSymlinksInPath()
        defer { try? FileManager.default.removeItem(at: root) }
        let app = try Self.ownerTestShapedApp(at: root, helper: URL(fileURLWithPath: path), ownerTest: true, official: official)
        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: root.appendingPathComponent("support"), preferredLanguages: ["en"])
        let owner = CockpitConsoleOwner(bundle: app, settingsStore: settings)
        let context = try CockpitEngineContext(sessionID: UUID(), storeEpoch: "synthetic-owner-test", generation: 1)
        let page = try owner.makePage(context: context, executable: app.appendingPathComponent("Contents/Helpers/modelplan"))
        defer { page.discard() }
        page.verificationPlacement = (usable: CGRect(x: 0, y: 0, width: 1680, height: 1026), anchor: CGRect(x: 1100, y: 1026, width: 28, height: 24))
        page.open()
        let window = try XCTUnwrap(page.window), web = try XCTUnwrap(page.verificationWebView)
        let deadline = ContinuousClock.now + .seconds(30)
        var painted = false
        while !painted, ContinuousClock.now < deadline {
            painted = ((try? await web.evaluateJavaScript("!!document.documentElement.dataset.profile")) as? Bool) == true
            if !painted { try await Task.sleep(for: .milliseconds(50)) }
        }
        XCTAssertTrue(painted, "the page must be painted")
        XCTAssertFalse(window.isOpaque, "the panel is not opaque")
        XCTAssertEqual(window.backgroundColor?.alphaComponent ?? 1, 0, "the panel background is clear")
        XCTAssertFalse(window.hasShadow, "no window shadow around the hull, as in the study")
        XCTAssertEqual(web.value(forKey: "drawsBackground") as? Bool, false, "the web view paints no backing")
        XCTAssertEqual(web.underPageBackgroundColor.alphaComponent, 0, "nothing under the page")
        // The web view's own rendering of the window: corners and the reserve beside the bells are transparent.
        let image = try await web.takeSnapshot(configuration: nil)
        let rep = try XCTUnwrap(image.representations.compactMap { $0 as? NSBitmapImageRep }.first
            ?? image.cgImage(forProposedRect: nil, context: nil, hints: nil).map { NSBitmapImageRep(cgImage: $0) })
        let w = rep.pixelsWide, h = rep.pixelsHigh
        for (x, y) in [(1, 1), (w - 2, 1), (1, h - 2), (w - 2, h - 2)] {
            XCTAssertEqual(rep.colorAt(x: x, y: y)?.alphaComponent ?? 1, 0, accuracy: 0.01, "alpha at \(x),\(y) of \(w)x\(h)")
        }
    }

    /// G3-43 / CKP-SHELL-02, -04 on the real page and panel: the drag region covers the strip the page really
    /// painted, leaves the shutter alone, and dragging it detaches and moves the same cockpit.
    @MainActor func testG3_43TitleStripDragDetachesAndMovesTheRealCockpit() async throws {
        let official = Self.repoRoot().appendingPathComponent("desktop/cockpit/.tmp/official")
        guard let path = ProcessInfo.processInfo.environment["MODELPLAN_U11_TEST_CLI"],
              FileManager.default.isExecutableFile(atPath: path),
              FileManager.default.fileExists(atPath: official.appendingPathComponent("bundle-manifest.json").path) else {
            throw XCTSkip("The real page needs the canonical official cockpit and the synthetic-test CLI")
        }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("g3-43-" + UUID().uuidString).resolvingSymlinksInPath()
        defer { try? FileManager.default.removeItem(at: root) }
        let app = try Self.ownerTestShapedApp(at: root, helper: URL(fileURLWithPath: path), ownerTest: true, official: official)
        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: root.appendingPathComponent("support"), preferredLanguages: ["en"])
        let owner = CockpitConsoleOwner(bundle: app, settingsStore: settings)
        let context = try CockpitEngineContext(sessionID: UUID(), storeEpoch: "synthetic-owner-test", generation: 1)
        let page = try owner.makePage(context: context, executable: app.appendingPathComponent("Contents/Helpers/modelplan"))
        defer { page.discard() }
        page.verificationPlacement = (usable: CGRect(x: 0, y: 0, width: 1440, height: 876), anchor: CGRect(x: 1100, y: 876, width: 28, height: 24))
        page.open()
        let window = try XCTUnwrap(page.window), region = try XCTUnwrap(page.verificationDragRegion), web = try XCTUnwrap(page.verificationWebView)
        var box: [String: Double]?
        let deadline = ContinuousClock.now + .seconds(30)
        while box == nil, ContinuousClock.now < deadline {
            let script = "(()=>{const b=document.querySelector('.ck-head .ck-brand'),s=document.querySelector('[data-shutter]');if(!b||!s||!document.documentElement.dataset.profile)return null;const r=b.getBoundingClientRect(),t=s.getBoundingClientRect();return {brandX:r.x+r.width/2,brandY:r.y+r.height/2,shutterX:t.x+t.width/2,shutterY:t.y+t.height/2}})()"
            box = (try? await web.evaluateJavaScript(script)) as? [String: Double]
            if box == nil { try await Task.sleep(for: .milliseconds(50)) }
        }
        let rects = try XCTUnwrap(box, "the strip must be painted")
        let content = try XCTUnwrap(window.contentView), height = content.bounds.height
        XCTAssertTrue(content.hitTest(content.convert(CGPoint(x: rects["brandX"]!, y: height - rects["brandY"]!), to: content.superview)) === region,
                      "a press on the free strip reaches the drag region")
        XCTAssertFalse(content.hitTest(content.convert(CGPoint(x: rects["shutterX"]!, y: height - rects["shutterY"]!), to: content.superview)) === region,
                       "the shutter keeps its own input")
        XCTAssertEqual(page.verificationShellState?.attached, true)
        let start = window.frame
        func mouse(_ type: NSEvent.EventType, _ point: CGPoint) throws -> NSEvent {
            try XCTUnwrap(NSEvent.mouseEvent(with: type, location: point, modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber,
                                             context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
        }
        let press = region.convert(CGPoint(x: region.bounds.midX, y: region.bounds.midY), to: nil)
        region.mouseDown(with: try mouse(.leftMouseDown, press))
        region.mouseDragged(with: try mouse(.leftMouseDragged, CGPoint(x: press.x - 200, y: press.y - 60)))
        region.mouseUp(with: try mouse(.leftMouseUp, CGPoint(x: press.x - 200, y: press.y - 60)))
        XCTAssertEqual(page.verificationShellState?.attached, false, "the drag detaches the cockpit")
        XCTAssertLessThan(window.frame.minX, start.minX, "and moves it")
        XCTAssertEqual(window.frame.size, start.size, "the same cockpit, not a resized one")
    }
    #endif
}
