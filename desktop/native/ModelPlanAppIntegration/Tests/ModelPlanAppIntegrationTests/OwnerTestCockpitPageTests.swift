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
        // D60: the cockpit is drawn at 85 % by default; page points map onto the window by the layout scale.
        let content = try XCTUnwrap(window.contentView), height = content.bounds.height, k = page.verificationLayout?.scale ?? 1
        XCTAssertTrue(content.hitTest(content.convert(CGPoint(x: rects["brandX"]! * k, y: height - rects["brandY"]! * k), to: content.superview)) === region,
                      "a press on the free strip reaches the drag region")
        XCTAssertFalse(content.hitTest(content.convert(CGPoint(x: rects["shutterX"]! * k, y: height - rects["shutterY"]! * k), to: content.superview)) === region,
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

    /// G3-53 / CKP-PORT-09 on the real page and panel: a real click on the porthole shutter closes and reopens it
    /// at both heights, and the page draws the closed cap. Owner Build 12: "开关窗也没效果".
    @MainActor func testG3_53ShutterClickClosesAndReopensTheRealCockpit() async throws {
        let official = Self.repoRoot().appendingPathComponent("desktop/cockpit/.tmp/official")
        guard let path = ProcessInfo.processInfo.environment["MODELPLAN_U11_TEST_CLI"],
              FileManager.default.isExecutableFile(atPath: path),
              FileManager.default.fileExists(atPath: official.appendingPathComponent("bundle-manifest.json").path) else {
            throw XCTSkip("The real page needs the canonical official cockpit and the synthetic-test CLI")
        }
        for (name, usable, tier, closedRoot) in [("short", CGRect(x: 0, y: 0, width: 1440, height: 680), CockpitShellState.Tier.compact, CGFloat(609)),
                                                  ("full", CGRect(x: 0, y: 0, width: 1680, height: 1026), .tall, 691)] {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("g3-53-" + UUID().uuidString).resolvingSymlinksInPath()
            defer { try? FileManager.default.removeItem(at: root) }
            let app = try Self.ownerTestShapedApp(at: root, helper: URL(fileURLWithPath: path), ownerTest: true, official: official)
            let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: root.appendingPathComponent("support"), preferredLanguages: ["en"])
            let owner = CockpitConsoleOwner(bundle: app, settingsStore: settings)
            let context = try CockpitEngineContext(sessionID: UUID(), storeEpoch: "synthetic-owner-test", generation: 1)
            let page = try owner.makePage(context: context, executable: app.appendingPathComponent("Contents/Helpers/modelplan"))
            defer { page.discard() }
            page.verificationPlacement = (usable: usable, anchor: CGRect(x: usable.maxX - 340, y: usable.maxY, width: 28, height: 24))
            NSApp.activate(ignoringOtherApps: true)
            page.open()
            let window = try XCTUnwrap(page.window), web = try XCTUnwrap(page.verificationWebView)
            window.makeKeyAndOrderFront(nil)
            func pageValue(_ script: String) async -> [String: Any]? { (try? await web.evaluateJavaScript(script)) as? [String: Any] }
            let probe = "(()=>{const s=document.querySelector('[data-shutter]'),c=document.querySelector('.ck');if(!s||!c||!document.documentElement.dataset.profile)return null;const r=s.getBoundingClientRect();return {x:r.x+r.width/2,y:r.y+r.height/2,disabled:s.disabled,pressed:s.getAttribute('aria-pressed'),active:document.getElementById('cockpit').dataset.active,root:c.getBoundingClientRect().height}})()"
            var state: [String: Any]?
            var deadline = ContinuousClock.now + .seconds(30)
            while ContinuousClock.now < deadline {
                state = await pageValue(probe)
                if state?["active"] as? String == "true" { break }
                try await Task.sleep(for: .milliseconds(50))
            }
            let before = try XCTUnwrap(state, "\(name): the page must be painted")
            // A real click needs what the owner has: an active app with the cockpit as key window. Hosted CI runners
            // cannot activate an app; there the page stays inactive by design, so this runs on the GUI Mac only.
            guard NSApp.isActive, window.isKeyWindow else {
                throw XCTSkip("G3-53 needs an active app and key cockpit window (GUI Mac); this runner has app active \(NSApp.isActive), key \(window.isKeyWindow)")
            }
            XCTAssertEqual(page.verificationShellState?.tier, tier, name)
            XCTAssertEqual(before["active"] as? String, "true", "\(name): the shown, key cockpit is active (window key \(window.isKeyWindow), app active \(NSApp.isActive))")
            XCTAssertEqual(before["disabled"] as? Bool, false, "\(name): the shutter is enabled")
            let scale = page.verificationLayout?.scale ?? 1
            var target = before
            func click() throws {
                let content = try XCTUnwrap(window.contentView), h = content.bounds.height
                let p = content.convert(CGPoint(x: (target["x"] as! Double) * scale, y: h - (target["y"] as! Double) * scale), to: nil)
                for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                    window.sendEvent(try XCTUnwrap(NSEvent.mouseEvent(with: type, location: p, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                        windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: type == .leftMouseDown ? 1 : 0)))
                }
            }
            for (closed, expectedRoot) in [(true, closedRoot), (false, tier == .tall ? 877 : 627)] {
                try click()
                deadline = ContinuousClock.now + .seconds(10)
                while ContinuousClock.now < deadline, (page.verificationShellState?.profile == .closed) != closed { try await Task.sleep(for: .milliseconds(50)) }
                XCTAssertEqual(page.verificationShellState?.profile, closed ? .closed : .open, "\(name): the click reaches the native shell")
                XCTAssertEqual(page.verificationRootHeight, expectedRoot, name)
                deadline = ContinuousClock.now + .seconds(10)
                var drawn: [String: Any]?
                while ContinuousClock.now < deadline {
                    drawn = await pageValue(probe)
                    if drawn?["pressed"] as? String == String(closed) { break }
                    try await Task.sleep(for: .milliseconds(50))
                }
                XCTAssertEqual(drawn?["pressed"] as? String, String(closed), "\(name): the page shows the shutter \(closed ? "closed" : "open")")
                XCTAssertEqual(drawn?["root"] as? Double ?? 0, Double(expectedRoot), accuracy: 0.5, "\(name): the page root follows")
                if let drawn { target = drawn }
            }
        }
    }

    /// CKP-SHELL-07 / owner D51, C-02, C-03 on the real page and panel: an Air shows the full cockpit with its flame
    /// reserve, scaled as one page (WebKit page zoom, not a bitmap), with the strip and shutter still hit where drawn.
    /// Covers 1470x956 with the Dock at the bottom, the lowest full scale (75 %) and a live switch to 80 %.
    @MainActor func testD51ScaledFullCockpitKeepsCrispTextAndHitTargets() async throws {
        let official = Self.repoRoot().appendingPathComponent("desktop/cockpit/.tmp/official")
        guard let path = ProcessInfo.processInfo.environment["MODELPLAN_U11_TEST_CLI"],
              FileManager.default.isExecutableFile(atPath: path),
              FileManager.default.fileExists(atPath: official.appendingPathComponent("bundle-manifest.json").path) else {
            throw XCTSkip("The real page needs the canonical official cockpit and the synthetic-test CLI")
        }
        let cases: [(String, CGRect, CockpitSize?, CGFloat)] = [
            ("1470x956, Dock at the bottom (default 85 %)", CGRect(x: 0, y: 70, width: 1470, height: 849), nil, 0.85),
            ("lowest full scale", CGRect(x: 0, y: 0, width: 1440, height: 690), nil, 684 / 911),
            ("80 % chosen live", CGRect(x: 0, y: 0, width: 1680, height: 1026), .percent80, 0.8),
        ]
        for (name, usable, live, expected) in cases {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("d51-" + UUID().uuidString).resolvingSymlinksInPath()
            defer { try? FileManager.default.removeItem(at: root) }
            let app = try Self.ownerTestShapedApp(at: root, helper: URL(fileURLWithPath: path), ownerTest: true, official: official)
            let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: root.appendingPathComponent("support"), preferredLanguages: ["en"])
            let owner = CockpitConsoleOwner(bundle: app, settingsStore: settings)
            let context = try CockpitEngineContext(sessionID: UUID(), storeEpoch: "synthetic-owner-test", generation: 1)
            let page = try owner.makePage(context: context, executable: app.appendingPathComponent("Contents/Helpers/modelplan"))
            defer { page.discard() }
            page.verificationPlacement = (usable: usable, anchor: CGRect(x: usable.maxX - 340, y: usable.maxY, width: 28, height: 24))
            page.open()
            let window = try XCTUnwrap(page.window), region = try XCTUnwrap(page.verificationDragRegion), web = try XCTUnwrap(page.verificationWebView)
            if let live { page.updateAppearance(.init(theme: .night, locale: .en, profile: .full, size: live)) }
            var box: [String: Double]?
            let deadline = ContinuousClock.now + .seconds(30)
            while box == nil, ContinuousClock.now < deadline {
                let script = "(()=>{const b=document.querySelector('.ck-head .ck-brand'),s=document.querySelector('[data-shutter]'),c=document.querySelector('.ck');if(!b||!s||!c||!document.documentElement.dataset.profile)return null;const r=b.getBoundingClientRect(),t=s.getBoundingClientRect();return {brandX:r.x+r.width/2,brandY:r.y+r.height/2,shutterX:t.x+t.width/2,shutterY:t.y+t.height/2,width:innerWidth,height:innerHeight,root:c.getBoundingClientRect().height,rootBottom:c.getBoundingClientRect().bottom}})()"
                box = (try? await web.evaluateJavaScript(script)) as? [String: Double]
                if box == nil { try await Task.sleep(for: .milliseconds(50)) }
            }
            let painted = try XCTUnwrap(box, "\(name): the page must be painted")
            let layout = try XCTUnwrap(page.verificationLayout), scale = layout.scale
            XCTAssertEqual(scale, expected, accuracy: 1e-6, name)
            XCTAssertEqual(page.verificationShellState?.tier, .tall, "\(name): the full cockpit, never the short one")
            XCTAssertEqual(painted["root"]!, 877, accuracy: 0.5, "\(name): the full root")
            // The whole canvas, root plus the flame reserve, is laid out at 636 CSS px and fits the window.
            XCTAssertEqual(painted["width"]!, 636, accuracy: 1, name)
            XCTAssertEqual(painted["height"]!, 911, accuracy: 1, name)
            XCTAssertEqual(painted["height"]! - painted["rootBottom"]!, 34, accuracy: 1, "\(name): the flame reserve is inside the window")
            // The window server places borderless panels on whole points.
            XCTAssertEqual(window.frame.width, 636 * scale, accuracy: 1, name)
            XCTAssertEqual(window.frame.height, 911 * scale, accuracy: 1, name)
            // Placement on the requested screen (the hosted runner's real display is smaller, so the window
            // server may move the panel; its size is what the test can hold it to).
            XCTAssertEqual(layout.frame.maxY, usable.maxY - 6, accuracy: 1e-6, name)
            XCTAssertGreaterThanOrEqual(layout.frame.minY, usable.minY - 1e-6, name)
            // Crisp: WebKit draws the page at the final size; no view scales a bitmap of it.
            XCTAssertEqual(web.pageZoom, scale, accuracy: 1e-6, name)
            let content = try XCTUnwrap(window.contentView)
            XCTAssertEqual(content.bounds.size.width, window.frame.width, accuracy: 1, name)
            XCTAssertEqual(web.frame.size.width, window.frame.width, accuracy: 1, name)
            // Hit targets: page points map by the scale onto the window, and land where they are drawn.
            let height = content.bounds.height
            func hit(_ x: Double, _ y: Double) -> NSView? {
                content.hitTest(content.convert(CGPoint(x: x * scale, y: height - y * scale), to: content.superview))
            }
            XCTAssertTrue(hit(painted["brandX"]!, painted["brandY"]!) === region, "\(name): a press on the free strip reaches the drag region")
            let shutter = hit(painted["shutterX"]!, painted["shutterY"]!)
            XCTAssertFalse(shutter === region, "\(name): the shutter keeps its own input")
            XCTAssertTrue(shutter?.isDescendant(of: web) == true, "\(name): the shutter press reaches the page")
        }
    }
    #endif
}
