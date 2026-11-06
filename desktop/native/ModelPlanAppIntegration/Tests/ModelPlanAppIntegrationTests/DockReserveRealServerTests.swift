// SPDX-License-Identifier: MIT
#if MODELPLAN_DOCK_REAL_RUNTIME_JOURNEY
import AppKit
import ModelPlanDock
import ModelPlanSettings
import XCTest
@testable import ModelPlanAppIntegration

@MainActor private final class ReserveJourneyScheduler: DockEdgeScheduling {
    func arm(at deadline: TimeInterval, _ action: @escaping @MainActor () -> Void) {}
    func cancel() {}
}

@MainActor final class DockReserveRealServerTests: XCTestCase {
    func testV05RealServerShowsTheUnknownUnitReserveInBothLanguages() async throws {
        let path = try XCTUnwrap(ProcessInfo.processInfo.environment["MODELPLAN_DOCK_TEST_CLI"])
        let executable = URL(fileURLWithPath: path)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("reserve-reading-" + UUID().uuidString)
        let cache = root.appendingPathComponent("Library/Caches/modelplan/observed")
        for directory in [cache, root.appendingPathComponent(".codex")] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        addTeardownBlock { try FileManager.default.removeItem(at: root) }
        let environment = ["HOME": root.path, "TMPDIR": root.path, "PATH": "/usr/bin:/bin", "LANG": "C"]

        func command(_ arguments: [String], input: [String: Any]? = nil) async throws -> [String: Any] {
            let process = Process(), output = Pipe(), stdin = input.map { _ in Pipe() }
            process.executableURL = executable
            process.arguments = arguments
            process.environment = environment
            process.standardOutput = output
            process.standardError = FileHandle.nullDevice
            process.standardInput = stdin ?? FileHandle.nullDevice
            try process.run()
            if let stdin, let input {
                try stdin.fileHandleForWriting.write(contentsOf: JSONSerialization.data(withJSONObject: input))
                try stdin.fileHandleForWriting.close()
            }
            let deadline = ContinuousClock.now + .seconds(5)
            while process.isRunning && ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(10)) }
            if process.isRunning { process.terminate(); throw CocoaError(.fileReadUnknown) }
            XCTAssertEqual(process.terminationStatus, 0)
            return try XCTUnwrap(JSONSerialization.jsonObject(with: output.fileHandleForReading.readDataToEndOfFile()) as? [String: Any])
        }
        _ = try await command(["consent", "init", "--json"])
        let before = try await command(["consent", "--json"])
        let epoch = try XCTUnwrap(before["storeEpoch"] as? String)
        let scope = "codex.runtime_usage"
        _ = try await command(["consent", "grant", "--json"], input: [
            "requestId": UUID().uuidString.lowercased(), "expectStoreEpoch": epoch,
            "expectGeneration": try XCTUnwrap(before["generation"] as? Int),
            "consentTextVersion": try XCTUnwrap(before["consentTextVersion"] as? Int),
            "allow": [scope], "deny": [String]()
        ])
        let after = try await command(["consent", "--json"])
        let generation = try XCTUnwrap(after["generation"] as? Int)
        let rawBalance = 19_613.9573653333, ref = "aaaaaaaaaaaaaaaa"
        let formatter = ISO8601DateFormatter()
        let reset = formatter.string(from: Date().addingTimeInterval(7_200))
        func writeReading(age: TimeInterval) throws {
            let observed = formatter.string(from: Date().addingTimeInterval(-age))
            let snapshot: [String: Any] = [
                "schemaVersion": 1, "status": "ok", "plan": "plus", "subscriptionRef": ref, "observedAt": observed,
                "admission": ["storeEpoch": epoch, "generation": generation, "scope": scope],
                "windows": [["kind": "weekly", "windowMinutes": 10_080, "usedPercent": 25,
                             "observedAt": observed, "resetsAt": reset, "resetMode": "rolling"]],
                "usageRead": true, "usageCredits": ["balance": rawBalance, "observedAt": observed]
            ]
            try JSONSerialization.data(withJSONObject: snapshot)
                .write(to: cache.appendingPathComponent("codex-account.json"), options: .atomic)
        }
        try writeReading(age: 20)
        let quota = try await command(["quota", "--json", "--offline"])
        let accounts = try XCTUnwrap(quota["accounts"] as? [[String: Any]])
        let balance = try XCTUnwrap(accounts.first { $0["source"] as? String == "codex" }?["credits"] as? [String: Any])
        XCTAssertEqual(balance["balance"] as? Double, rawBalance)
        XCTAssertNil(balance["unit"])

        let frame = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let screen = DockDisplayArea(id: "synthetic", frame: frame, visibleFrame: frame)
        var elapsed = 0.0, pointer = CGPoint(x: 720, y: 450)
        let app = EngineRowsEntry.make(configuration: .init(executableURL: executable, applicationVersion: "synthetic-reserve",
            allowedEnvironment: environment, offline: true, readOnly: true),
            settingsStore: try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"]),
            createsNativePanels: false, bundleURL: root.appendingPathComponent("Synthetic.app"),
            dockEnvironment: { .init(displays: [screen], layouts: [], primaryDisplayID: screen.id, pointer: pointer) },
            deadlineElapsed: { elapsed }, deadlineScheduling: ReserveJourneyScheduler(), activateSettings: {})
        addTeardownBlock { @MainActor in await app.composition.stop() }
        await app.prepare()
        app.allowDockPresentation()
        let delivery = try await app.composition.client.start()
        let dock = app.composition.dock, view = dock.dockView

        func textFields(_ root: NSView) -> [NSTextField] {
            (root as? NSTextField).map { [$0] } ?? root.subviews.flatMap(textFields)
        }
        func assertCard(retained: Bool) async throws {
            _ = try await app.composition.client.subscribeRows(timeout: .seconds(5))
            XCTAssertEqual(app.composition.store.snapshot.delivery, delivery)
            let member = try XCTUnwrap(app.composition.accountMembers.members.first { $0.id == ref })
            XCTAssertEqual(member.account.valueState, retained ? .retained : .current)
            XCTAssertEqual(member.account.credits?.balance, rawBalance)
            XCTAssertEqual(member.account.credits?.unit, "other")
            let placement = try XCTUnwrap(dock.edgePresentation?.placement)
            let nozzle = try XCTUnwrap(view.interactionAnchor(ref))
            pointer = CGPoint(x: placement.frame.minX + nozzle.midX - view.bounds.minX,
                              y: placement.frame.maxY - nozzle.midY + view.bounds.minY)
            let events = try XCTUnwrap(view.nozzleEventDelegate)
            events.hoverNozzle(nil)
            events.hoverNozzle(ref)
            elapsed += 0.251
            try XCTUnwrap(dock.interactionControllerForChecks).refresh()

            for (language, label, retainedCopy) in [(SettingsLanguage.english, "Reserve", "Last known reading"),
                                                    (.chinese, "储备", "上次读数")] {
                _ = try await app.settingsHost.application.editor.commit(SettingsB21Edit.language(language))
                let card = try XCTUnwrap(dock.detachedCardForChecks)
                let fields = textFields(card)
                let title = try XCTUnwrap(fields.first { $0.accessibilityIdentifier() == "dock.card.text.row.credits.label" })
                let number = try XCTUnwrap(fields.first { $0.accessibilityIdentifier() == "dock.card.text.row.credits.value" })
                XCTAssertEqual(title.stringValue, label)
                XCTAssertEqual(number.stringValue, "19,614")
                let ink = (number.stringValue as NSString).size(withAttributes: [.font: try XCTUnwrap(number.font)])
                let valueRect = card.convert(number.bounds, from: number)
                XCTAssertTrue(card.bounds.contains(valueRect))
                XCTAssertGreaterThanOrEqual(valueRect.width, floor(ink.width))
                XCTAssertLessThanOrEqual(card.convert(title.bounds, from: title).maxX, valueRect.minX)
                let details = fields.filter { $0.accessibilityIdentifier() == "dock.card.text.row.credits.detail" }
                XCTAssertEqual(details.map(\.stringValue), retained ? [retainedCopy] : [])
                if let path = ProcessInfo.processInfo.environment["MODELPLAN_V05_CAPTURE_DIR"] {
                    let languageID = language == .english ? "en" : "zh"
                    let state = retained ? "retained" : "current"
                    let bitmap = try XCTUnwrap(card.bitmapImageRepForCachingDisplay(in: card.bounds))
                    card.cacheDisplay(in: card.bounds, to: bitmap)
                    let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                    try png.write(to: URL(fileURLWithPath: path).appendingPathComponent("\(state)-\(languageID).png"))
                }
            }
        }

        try await assertCard(retained: false)
        try writeReading(age: 3 * 3600 + 30)
        try await assertCard(retained: true)
        XCTAssertNil(dock.nativePanel)
    }
}
#endif
