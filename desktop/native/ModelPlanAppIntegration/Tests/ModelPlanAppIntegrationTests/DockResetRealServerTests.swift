// SPDX-License-Identifier: MIT
#if MODELPLAN_DOCK_REAL_STRIP_JOURNEY
import AppKit
import CryptoKit
import Foundation
import XCTest
@_spi(DockResourceChecks) import ModelPlanDock
import ModelPlanSettings
@_spi(DockResourceChecks) @testable import ModelPlanAppIntegration

@MainActor private final class ResetCockpitProbe: EngineRowsConsoleSurface {
    private(set) var shown = false
    func show() { shown = true }
    func hide() {}
    func render() {}
}

@MainActor final class DockResetRealServerTests: XCTestCase {
    func testD21RealServerPublishesTheFullResetNoticeLifecycle() async throws {
        try await exercise(native: false)
    }

    func testV14NormalEntryPaintsFivePointResetInkInBothPercentageModes() async throws {
        try await exercise(native: false, measureFace: true)
    }

    #if MODELPLAN_DOCK_NATIVE_JOURNEY
    func testD21NativeOrderInAcknowledgesTheResetNotice() async throws {
        try await exercise(native: true)
    }

    func testD21PhysicalRevealAndNativeStatusNotice() async throws {
        try await exercise(native: true, physical: true)
    }
    #endif

    private func exercise(native: Bool, physical: Bool = false, measureFace: Bool = false) async throws {
        let executable = URL(fileURLWithPath: try XCTUnwrap(ProcessInfo.processInfo.environment["MODELPLAN_DOCK_TEST_CLI"]))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("d21-real-reset-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root.appendingPathComponent(".codex"), withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: root) }
        let env = ["HOME": root.path, "TMPDIR": root.path, "PATH": "/usr/bin:/bin", "LANG": "C"]
        func json(_ value: Any) throws -> Data {
            try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .withoutEscapingSlashes])
        }
        func command(_ arguments: [String], input: [String: Any]? = nil) async throws -> [String: Any] {
            let process = Process(), output = Pipe()
            process.executableURL = executable; process.arguments = arguments; process.environment = env
            process.standardOutput = output; process.standardError = FileHandle.nullDevice
            let stdin = input.map { _ in Pipe() }
            process.standardInput = stdin ?? FileHandle.nullDevice
            try process.run()
            if let input, let stdin {
                try stdin.fileHandleForWriting.write(contentsOf: json(input))
                try stdin.fileHandleForWriting.close()
            }
            let deadline = ContinuousClock.now + .seconds(5)
            while process.isRunning, ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(10)) }
            if process.isRunning { process.terminate(); throw CocoaError(.fileReadUnknown) }
            XCTAssertEqual(process.terminationStatus, 0, arguments.joined(separator: " "))
            return try XCTUnwrap(JSONSerialization.jsonObject(with: output.fileHandleForReading.readDataToEndOfFile()) as? [String: Any])
        }
        _ = try await command(["consent", "init", "--json"])
        let beforeGrant = try await command(["consent", "--json"])
        let scope = "codex.runtime_usage"
        let epoch = try XCTUnwrap(beforeGrant["storeEpoch"] as? String)
        _ = try await command(["consent", "grant", "--json"], input: [
            "requestId": UUID().uuidString.lowercased(), "expectStoreEpoch": epoch,
            "expectGeneration": try XCTUnwrap(beforeGrant["generation"] as? Int),
            "consentTextVersion": try XCTUnwrap(beforeGrant["consentTextVersion"] as? Int),
            "allow": [scope], "deny": [String]()
        ])
        let consent = try await command(["consent", "--json"])
        let generation = try XCTUnwrap(consent["generation"] as? Int)
        let cache = root.appendingPathComponent("Library/Caches/modelplan")
        func write(_ bytes: Data, to relative: String) throws {
            let url = cache.appendingPathComponent(relative)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try bytes.write(to: url, options: .atomic)
        }
        func hash(_ bytes: Data) -> String { SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined() }
        let now = Date(), iso = ISO8601DateFormatter()
        func at(_ offset: Double) -> String { iso.string(from: now.addingTimeInterval(offset)) }
        let reset = at(7_200), observed = at(-120), published = at(-60)
        func writeReading(used: Int, observed: String, reset: String) throws {
            let window: [String: Any] = ["kind": "five_hour", "usedPercent": used, "windowMinutes": 300,
                "resetsAt": reset, "observedAt": observed, "resetMode": "rolling"]
            try write(json(["schemaVersion": 1, "status": "ok", "observedAt": observed, "plan": "plus",
                            "subscriptionRef": "aaaaaaaaaaaaaaaa", "windows": [window],
                            "admission": ["storeEpoch": epoch, "generation": generation, "scope": scope]]),
                      to: "observed/codex-account.json")
        }
        try writeReading(used: 70, observed: observed, reset: reset)
        let eventID = "synthetic-d21-announcement"
        let url = "https://status.openai.com/incidents/synthetic-d21"
        let announced: [String: Any] = ["id": eventID, "provider": "openai", "eventType": "direct_reset_announced",
            "status": "upstream-announced", "publishedAt": published, "url": url,
            "schedule": ["precision": "deadline", "from": reset, "through": reset, "label": "before the deadline"]]
        let confirmed: [String: Any] = ["id": "synthetic-d21-confirmation", "provider": "openai",
            "eventType": "direct_reset_reported_complete", "status": "upstream-confirmed", "publishedAt": at(-30),
            "confirms": eventID, "url": url]
        // Match the synthetic verified-cache format from cli/cmd/modelplan/app_server_reset_binary_test.go.
        func publish(_ events: [[String: Any]]) throws {
            let dummy = String(repeating: "a", count: 64)
            let data: [String: Any] = ["units": ["ability": "websiteAbility", "cost": "usdPerReferenceTask", "time": "taskTimeCrossModel"],
                "models": [], "lineups": [], "resets": events, "windows": []]
            let dependencies = Dictionary(uniqueKeysWithValues: ["models", "registry", "rules", "calendar"].map { ($0, dummy) })
            let bytes = try json(["schemaVersion": 1, "kind": "client", "dependencies": dependencies, "data": data])
            let component = hash(bytes)
            var refs = Dictionary(uniqueKeysWithValues: ["methods", "registry", "models", "plans", "rules", "news", "calendar"].map {
                ($0, ["schemaVersion": 1, "hash": dummy, "bytes": 2] as [String: Any])
            })
            refs["client"] = ["schemaVersion": 1, "hash": component, "bytes": bytes.count]
            let methods = #"{"index":"unified-v03-estimator-0.1.0-internal","recommendation":"balanced-coding-absolute-v4"}"#
            let components = String(decoding: try json(refs), as: UTF8.self)
            let core = #"{"schemaVersion":1,"comparisonVersion":"synthetic","methods":"# + methods + #","components":"# + components + "}"
            let publicationID = String(hash(Data(core.utf8)).prefix(24))
            let manifest = Data((core.dropLast() + #","publicationId":""# + publicationID + #"","publishedAt":""# + published + #""}"#).utf8)
            try write(bytes, to: "objects/" + component + ".json")
            try write(manifest, to: "releases/" + publicationID + "/manifest.json")
            try write(json(["publicationId": publicationID, "manifestHash": hash(manifest),
                            "component": "client", "componentHash": component]), to: "state.json")
        }
        try publish([announced])

        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        _ = try await store.update {
            $0.autoHide = true; $0.motion = .on
            $0.notifications.optedIn = true
            $0.notifications.kinds = [.official]
            if physical { $0.onboarding.next() }
            if measureFace { $0.size = .large }
        }
        let dockEnvironment: (@MainActor () -> DockEdgeEnvironment)?
        if physical {
            _ = NSApplication.shared
            dockEnvironment = nil
        } else if native {
            _ = NSApplication.shared
            let screen = try XCTUnwrap(NSScreen.main)
            let display = DockDisplayArea(id: "synthetic", frame: screen.frame, visibleFrame: screen.visibleFrame)
            let pointer = CGPoint(x: display.visibleFrame.midX, y: display.visibleFrame.midY)
            dockEnvironment = { .init(displays: [display], layouts: [], primaryDisplayID: display.id, pointer: pointer) }
        } else {
            dockEnvironment = normalEntryTestEnvironment
        }
        var wall = now
        let cockpit = ResetCockpitProbe()
        #if MODELPLAN_DOCK_NATIVE_JOURNEY
        if physical { EngineRowsEntry.nativeJourneyProfile = root }
        #endif
        let app = EngineRowsEntry.make(configuration: .init(executableURL: executable, applicationVersion: "synthetic-d21",
            allowedEnvironment: env, offline: true, readOnly: true), settingsStore: store, createsNativePanels: native,
            bundleURL: root.appendingPathComponent("Synthetic.app"), cockpitEntryEnabled: true,
            dockEnvironment: dockEnvironment, deadlineNow: { wall }, makeConsole: { _ in cockpit },
            isolatedResetNotificationLedger: root.appendingPathComponent("test-notifications.json"), activateSettings: {})
        if measureFace { app.composition.dock.captureBackingScaleForChecks = 2 }
        var delivered: [String] = []
        app.composition.setResetNotificationDelivery { event, title in
            XCTAssertEqual(title, "Official extra reset")
            delivered.append(event)
        }
        func announce(_ message: String) {
            if physical { FileHandle.standardOutput.write(Data(("D-21: " + message + "\n").utf8)) }
        }
        func wait(_ description: String, timeout: Duration = .seconds(4), until predicate: () -> Bool) async throws {
            let end = ContinuousClock.now + timeout
            while !predicate(), ContinuousClock.now < end { try await Task.sleep(for: .milliseconds(10)) }
            XCTAssertTrue(predicate(), description)
        }
        if physical {
            #if MODELPLAN_DOCK_NATIVE_JOURNEY
            let application = NSApplication.shared
            let menu = application.mainMenu, appearance = application.appearance, policy = application.activationPolicy()
            addTeardownBlock { @MainActor in
                await app.stopNativeDockJourney()
                EngineRowsEntry.nativeJourneyProfile = nil
                application.mainMenu = menu
                application.appearance = appearance
                application.setActivationPolicy(policy)
            }
            announce("Keep the pointer clear of the widget. Capture the first announced status icon and collapsed strip.")
            app.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification, object: application))
            try await wait("The real status item and fresh delivery must be present", timeout: .seconds(12)) {
                app.nativeJourneyStatusVisible && !app.lifecyclePaused
            }
            #endif
        } else {
            addTeardownBlock { @MainActor in await app.composition.stop() }
            await app.prepare()
            app.allowDockPresentation()
        }
        XCTAssertNil(app.loginServiceAdapter)
        XCTAssertNil(app.notificationAuthorizationService)
        let delivery = try await app.composition.client.start()

        func waitForEvent(_ id: String, _ status: String) async throws {
            try await wait("The real server must publish the " + status + " event") {
                guard case .available(let events) = app.composition.rowEvents else { return false }
                return events.contains { $0.id == id && $0.status == status }
            }
        }
        func subscribe() async throws {
            _ = try await app.composition.client.subscribeRows(timeout: .seconds(4))
            XCTAssertEqual(app.composition.store.snapshot.delivery, delivery)
        }
        let dock = app.composition.dock
        let member = "aaaaaaaaaaaaaaaa"
        func strip() throws -> DockSliverView {
            #if MODELPLAN_DOCK_NATIVE_JOURNEY
            if native {
                let panel = try XCTUnwrap(dock.nativePanel)
                XCTAssertTrue(panel.isVisible)
                return try XCTUnwrap(panel.contentView as? DockSliverView)
            }
            #endif
            return try dock.prepareSliver(size: XCTUnwrap(dock.edgePresentation?.placement?.sliverFrame.size))
        }
        func face() -> DockNotice? { dock.dockView.presentedNoticesForChecks[member] }

        func measureBlueInk(_ kind: DockNoticeKind) async throws {
            let editor = app.settingsHost.application.editor
            for percentages in [true, false] {
                if editor.snapshot?.preferences.showPercentages != percentages {
                    _ = try await editor.commit(SettingsB20Edit.showPercentages(percentages))
                }
                let view = dock.dockView
                XCTAssertEqual(face()?.key.kind, kind)
                let skin = try XCTUnwrap(view.presentedSkinForChecks)
                let station = try XCTUnwrap(skin.stations.first { $0.subscriptionID == member })
                XCTAssertEqual(station.diameter, 52, accuracy: 0.001)
                let image = try XCTUnwrap(view.presentedImageForChecks)
                let region = station.eventRect.offsetBy(dx: -skin.bounds.minX, dy: -skin.bounds.minY)
                    .applying(.init(scaleX: 2, y: 2)).integral
                let bitmap = NSBitmapImageRep(cgImage: try XCTUnwrap(image.cropping(to: region)))
                var blue: [CGPoint] = []
                for y in 0..<bitmap.pixelsHigh {
                    for x in 0..<bitmap.pixelsWide {
                        guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                        // Include only the strong reset blue ink, excluding white/amber and the neutral backing.
                        if color.blueComponent > 0.92 && color.greenComponent > 0.75 &&
                            (0.54...0.69).contains(color.redComponent) && color.alphaComponent > 0.8 {
                            blue.append(CGPoint(x: x, y: y))
                        }
                    }
                }
                let minX = try XCTUnwrap(blue.map(\.x).min()), maxX = try XCTUnwrap(blue.map(\.x).max())
                let minY = try XCTUnwrap(blue.map(\.y).min()), maxY = try XCTUnwrap(blue.map(\.y).max())
                let width = maxX - minX + 1, height = maxY - minY + 1
                print("V-14 \(kind) percentages=\(percentages) blue backing pixels \(width)×\(height)")
                XCTAssertGreaterThanOrEqual(max(width, height), 8)
                XCTAssertLessThanOrEqual(max(width, height), 11, "Five logical points with up to one backing pixel of sampling tolerance")
            }
            _ = try await editor.commit(SettingsB20Edit.showPercentages(true))
        }

        try await waitForEvent(eventID, "announced")
        let row = try XCTUnwrap(app.composition.store.snapshot.rows?.projection.rows.first { $0.id == "codex" })
        XCTAssertEqual(row.accounts.first?.windows.first?.remainingPercent, 30)
        XCTAssertEqual(row.accounts.first?.windows.first?.current, true)
        XCTAssertEqual(row.state, .fresh, "A current cached runtime reading must be admitted to the Dock. Producer reason: " + String(describing: row.reason.code))
        guard row.state == .fresh else { return }
        if physical {
            try await wait("The native strip must collapse", timeout: .seconds(12)) { dock.edgePresentation?.state == .sliver }
            XCTAssertNotNil(app.noticeIndicator.window)
            XCTAssertFalse(app.noticeIndicator.isHiddenOrHasHiddenAncestor)
        }
        let initial = try strip()
        let mark = try XCTUnwrap(initial.noticeMarks.first)
        if !measureFace {
            XCTAssertEqual(mark.unit, 44.0 / 52.0, accuracy: 0.001, "The medium strip uses the nominal four-point reset dot")
        }
        let announcement = mark.notice
        func raster(_ strip: DockSliverView) throws -> Data {
            let image = try XCTUnwrap(strip.bitmapImageRepForCachingDisplay(in: strip.bounds))
            strip.cacheDisplay(in: strip.bounds, to: image)
            return try XCTUnwrap(image.representation(using: .png, properties: [:]))
        }
        let announcedPixels = try raster(initial)
        XCTAssertEqual(announcement.key.kind, .resetAnnounced)
        XCTAssertEqual(announcement.tone, .blue)
        XCTAssertEqual(announcement.shape, .hollow)
        XCTAssertEqual(face(), announcement)
        XCTAssertEqual(app.noticeIndicator.notice, announcement)
        let quota = initial.quotaSegmentColorRolesForChecks
        XCTAssertEqual(quota.first?.remainingPercent, 30)
        XCTAssertEqual(quota.first?.quotaRole, .warning, "The fixture must have quota paint before acknowledging the notice")
        try await wait("Announced notice is delivered once") { delivered == [eventID] }
        if measureFace { try await measureBlueInk(.resetAnnounced) }

        if physical {
            announce("Capture the actual status item and hollow blue strip mark now.")
            try await Task.sleep(for: .seconds(5))
            announce("Move into the wake zone to reveal once. Capture the visible face marker and cleared menu indicator.")
            try await wait("The physical pointer must reveal the native panel", timeout: .seconds(30)) {
                dock.edgePresentation?.state == .expanded && dock.nativePanel?.isVisible == true
            }
        } else {
            XCTAssertTrue(initial.accessibilityPerformPress())
        }
        XCTAssertEqual(dock.edgePresentation?.state, .expanded)
        #if MODELPLAN_DOCK_NATIVE_JOURNEY
        if native {
            let panel = try XCTUnwrap(dock.nativePanel)
            XCTAssertTrue(panel.isVisible)
            XCTAssertTrue(dock.dockView.window === panel)
        }
        #endif
        // A detached surface cannot order in a panel. The native variant
        // relies entirely on automatic acknowledgement from visible order-in.
        if !native { dock.acknowledgeDockReveal() }
        XCTAssertEqual(face(), announcement)
        XCTAssertNil(app.noticeIndicator.notice)
        announce("Move away and capture the re-collapsed strip. The quota segment remains.")
        try await wait("Return to the strip", timeout: physical ? .seconds(25) : .seconds(4)) { dock.edgePresentation?.state == .sliver }
        XCTAssertTrue(try strip().noticeMarks.isEmpty)
        XCTAssertEqual(try strip().quotaSegmentColorRolesForChecks, quota)
        let acknowledgedPixels = try raster(strip())
        XCTAssertNotEqual(announcedPixels, acknowledgedPixels, "Clearing the reset dot must change the drawn strip")

        try publish([announced, confirmed])
        try await subscribe()
        try await waitForEvent(eventID, "confirmed")
        let confirmation = try XCTUnwrap(face())
        XCTAssertEqual(confirmation.key.kind, .resetConfirmed)
        XCTAssertEqual(confirmation.tone, .blue)
        XCTAssertEqual(confirmation.shape, .solid)
        XCTAssertEqual(try strip().noticeMarks.first?.notice, confirmation)
        XCTAssertEqual(app.noticeIndicator.notice, confirmation)
        XCTAssertNotEqual(try raster(strip()), acknowledgedPixels, "The confirmed mark must restore painted pixels")
        XCTAssertEqual(try strip().quotaSegmentColorRolesForChecks, quota)
        announce("Capture the confirmed solid mark and status indicator before the restarted reading arrives.")
        if physical { try await Task.sleep(for: .seconds(5)) }
        XCTAssertEqual(delivered, [eventID], "Confirmation must not deliver the same event a second time")
        if measureFace { try await measureBlueInk(.resetConfirmed) }

        try writeReading(used: 30, observed: at(-10), reset: at(10_800))
        try await subscribe()
        XCTAssertEqual(dock.dockView.presentedReadingsForChecks[member]?.remainingPercent, 70)
        XCTAssertNil(try strip().quotaSegmentColorRolesForChecks.first?.quotaRole, "The improved reading clears quota paint")
        XCTAssertNil(face())
        XCTAssertNil(app.noticeIndicator.notice)
        XCTAssertTrue(try strip().noticeMarks.isEmpty)
        announce("Capture the restarted reading with both the reset dot and recovered quota alert cleared.")
        if physical { try await Task.sleep(for: .seconds(5)) }

        let expiryID = "synthetic-d21-expiry"
        let expiry = at(60)
        var expiring = announced
        expiring["id"] = expiryID
        expiring["schedule"] = ["precision": "deadline", "from": expiry, "through": expiry, "label": "before the deadline"]
        try publish([expiring])
        try await subscribe()
        try await waitForEvent(expiryID, "announced")
        try await wait("A distinct event receives its own delivery") { delivered == [eventID, expiryID] }
        let expiringNotice = try XCTUnwrap(face())
        XCTAssertEqual(app.noticeIndicator.notice, expiringNotice)
        app.showConsole()
        XCTAssertTrue(cockpit.shown)
        XCTAssertNil(app.noticeIndicator.notice)
        XCTAssertEqual(try strip().noticeMarks.first?.notice, expiringNotice)
        announce("Capture the still-present strip mark after the isolated cockpit acknowledgement.")
        if physical { try await Task.sleep(for: .seconds(4)) }
        wall = now.addingTimeInterval(61)
        dock.refreshDockContent()
        XCTAssertNil(face())
        XCTAssertTrue(try strip().noticeMarks.isEmpty)
        XCTAssertEqual(delivered, [eventID, expiryID], "Expiry must not publish another notification")
        announce("Capture the strip after expiry.")
        if physical { try await Task.sleep(for: .seconds(4)) }
    }
}
#endif
