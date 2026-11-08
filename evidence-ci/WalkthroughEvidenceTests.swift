// SPDX-License-Identifier: MIT
// Evidence only (G3-40, G3-41): not part of any product PR. Copied into the test target by the evidence
// workflow on a GitHub-hosted Mac, with synthetic data and the real public CLI as the bundled helper.
#if MODELPLAN_TEST_ONLY_SPI
import AppKit
import CryptoKit
import XCTest
import ModelPlanCockpitWeb
@testable import ModelPlanAppIntegration

@MainActor final class WalkthroughEvidenceTests: XCTestCase {
    func testCaptureIconClicksWithWidget() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let cli = env["MODELPLAN_U11_TEST_CLI"], let out = env["MODELPLAN_EVIDENCE_DIR"] else { throw XCTSkip("evidence run only") }
        var repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while !FileManager.default.fileExists(atPath: repo.appendingPathComponent("desktop/cockpit/build.mjs").path) { repo.deleteLastPathComponent() }
        let official = repo.appendingPathComponent("desktop/cockpit/.tmp/official")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("walk-" + UUID().uuidString).resolvingSymlinksInPath()
        let fm = FileManager.default
        let app = root.appendingPathComponent("ModelPlan Community.app"), contents = app.appendingPathComponent("Contents")
        for dir in ["MacOS", "Helpers", "Resources"] { try fm.createDirectory(at: contents.appendingPathComponent(dir), withIntermediateDirectories: true) }
        let helper = contents.appendingPathComponent("Helpers/modelplan")
        try fm.copyItem(at: URL(fileURLWithPath: cli), to: helper)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: helper.path)
        let digest = SHA256.hash(data: try Data(contentsOf: helper)).map { String(format: "%02x", $0) }.joined()
        try Data((digest + "\n").utf8).write(to: contents.appendingPathComponent("Resources/modelplan.sha256"))
        try fm.copyItem(at: official, to: contents.appendingPathComponent("Resources/Cockpit"))
        try Data(#"{"edition": "official", "stage": "owner-test"}"#.utf8).write(to: contents.appendingPathComponent("Resources/build-edition.json"))
        let info: [String: Any] = ["CFBundleIdentifier": "org.modelplan.community.swift.scaffold", "CFBundleExecutable": "ModelPlanCommunity",
            "CFBundlePackageType": "APPL", "ModelPlanCockpitEntryEnabled": true, "ModelPlanPublicSource": String(repeating: "a", count: 40),
            "ModelPlanBundledHelperSHA256": digest, CommunityConsentBundleIdentity.ownerTestKey: true]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: contents.appendingPathComponent("Info.plist"))
        let home = root.appendingPathComponent("home"); try fm.createDirectory(at: home, withIntermediateDirectories: true)
        let env2 = ["HOME": home.path, "TMPDIR": home.path, "PATH": "/usr/bin:/bin", "LANG": "C"]
        let seed = Process(); seed.executableURL = helper; seed.arguments = ["consent", "init", "--json"]; seed.environment = env2
        seed.standardOutput = FileHandle.nullDevice; seed.standardError = FileHandle.nullDevice; seed.standardInput = FileHandle.nullDevice
        try seed.run(); seed.waitUntilExit()
        let settings = try EngineRowsEntry.makeSettingsStore(applicationSupport: root.appendingPathComponent("support"), preferredLanguages: ["en"])
        _ = try await settings.update { $0.showDock = true; $0.autoHide = false }
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.regular)
        var page: CockpitWindowController?
        // The test process's status item is never laid out in the hosted runner's menu bar (its frame stays at
        // y = -23), so the page gets a synthetic placement under where the icon would be. Placement is not
        // what this evidence shows; the click path, the toggle and the widget are.
        CommunityCockpitApplicationFactory.verificationPage = { controller in
            page = controller
            if let screen = NSScreen.main {
                let usable = screen.visibleFrame
                controller.verificationPlacement = (usable: usable, anchor: CGRect(x: usable.minX + 300, y: usable.maxY, width: 22, height: 22))
            }
        }
        defer { CommunityCockpitApplicationFactory.verificationPage = nil }
        let entry = EngineRowsEntry.make(configuration: .init(executableURL: helper, applicationVersion: "walkthrough-evidence",
            allowedEnvironment: ["HOME": home.path, "TMPDIR": home.path, "PATH": "/usr/bin:/bin", "LANG": "C"], offline: true, readOnly: true),
            settingsStore: settings, createsNativePanels: true, bundleURL: app, cockpitEntryEnabled: true)
        await entry.prepare()
        await entry.composition.start()
        entry.allowDockPresentation()
        entry.installStatusItem(); entry.renderMenu()
        let button = try XCTUnwrap(entry.statusButtonForTesting)
        func shot(_ name: String) throws {
            let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            p.arguments = ["-x", URL(fileURLWithPath: out).appendingPathComponent(name + ".png").path]
            try p.run(); p.waitUntilExit()
        }
        func click() throws {
            for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                let event = try XCTUnwrap(NSEvent.mouseEvent(with: type, location: .zero, modifierFlags: [], timestamp: 0,
                    windowNumber: button.window?.windowNumber ?? 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
                _ = entry.handleStatusClick(event)
            }
        }
        func state(_ label: String) {
            let w = page?.window
            print("WALK \(label) paused=\(entry.lifecyclePaused) connection=\(entry.composition.store.snapshot.connection) page=\(page != nil) visible=\(w?.isVisible ?? false) alpha=\(w?.alphaValue ?? -1) frame=\(w?.frame ?? .zero) anchor=\(entry.cockpitAnchor ?? .zero) widget=\(String(describing: entry.composition.dock.edgePresentation?.paintedFrame))")
        }
        for _ in 0..<200 {
            if case .ready = entry.composition.store.snapshot.connection, let a = entry.cockpitAnchor, a.minY > 0 { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        try await Task.sleep(for: .seconds(4)); state("closed"); try shot("1-closed")
        try click(); try await Task.sleep(for: .seconds(6)); state("first"); try shot("2-after-first-click")
        try click(); try await Task.sleep(for: .seconds(2)); state("second"); try shot("3-after-second-click")
        await entry.composition.stop()
        entry.removeStatusItem(); entry.composition.dock.close()
    }
}
#endif
