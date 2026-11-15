// SPDX-License-Identifier: MIT
#if MODELPLAN_DOCK_REAL_RUNTIME_JOURNEY
import AppKit
import ModelPlanSettings
@_spi(DockResourceChecks) import ModelPlanDock
import XCTest
@testable import ModelPlanAppIntegration

@MainActor private final class QuotaWindowsClock: DockEdgeScheduling {
    func arm(at deadline: TimeInterval, _ action: @escaping @MainActor () -> Void) {}
    func cancel() {}
}

@MainActor final class DockQuotaWindowsRealServerTests: XCTestCase {
    func testR11R15RealServerKeepsScopedQuotaOffTheRing() async throws {
        let executable = URL(fileURLWithPath: try XCTUnwrap(ProcessInfo.processInfo.environment["MODELPLAN_DOCK_TEST_CLI"]))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("quota-windows-" + UUID().uuidString)
        let cache = root.appendingPathComponent("Library/Caches/modelplan/observed")
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent(".codex"), withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: root) }
        let environment = ["HOME": root.path, "TMPDIR": root.path, "PATH": "/usr/bin:/bin", "LANG": "C"]

        func consent(_ arguments: [String], input: [String: Any]? = nil) async throws -> [String: Any] {
            let process = Process(), output = Pipe()
            process.executableURL = executable
            process.arguments = ["consent"] + arguments + ["--json"]
            process.environment = environment
            process.standardError = FileHandle.nullDevice
            process.standardOutput = output
            let stdin = input.map { _ in Pipe() }
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

        _ = try await consent(["init"])
        let before = try await consent([])
        let epoch = try XCTUnwrap(before["storeEpoch"] as? String)
        let scope = "codex.runtime_usage"
        _ = try await consent(["grant"], input: [
            "requestId": UUID().uuidString.lowercased(), "expectStoreEpoch": epoch,
            "expectGeneration": try XCTUnwrap(before["generation"] as? Int),
            "consentTextVersion": try XCTUnwrap(before["consentTextVersion"] as? Int),
            "allow": [scope], "deny": [String]()
        ])
        let after = try await consent([])
        let now = Date(), formatter = ISO8601DateFormatter()
        let observed = formatter.string(from: now.addingTimeInterval(-20))
        let reset = formatter.string(from: now.addingTimeInterval(7200))
        let ref = "aaaaaaaaaaaaaaaa"
        func window(_ kind: String, minutes: Int, remaining: Int, limit: String = "main") -> [String: Any] {
            ["kind": kind, "windowMinutes": minutes, "usedPercent": 100 - remaining,
             "observedAt": observed, "resetsAt": reset, "resetMode": "rolling", "limit": limit]
        }
        let fixture: [String: Any] = [
            "schemaVersion": 1, "status": "ok", "observedAt": observed, "plan": "plus", "subscriptionRef": ref,
            "admission": ["storeEpoch": epoch, "generation": try XCTUnwrap(after["generation"] as? Int), "scope": scope],
            "windows": [window("five_hour", minutes: 300, remaining: 63),
                        window("weekly", minutes: 10080, remaining: 24),
                        window("monthly", minutes: 43200, remaining: 12),
                        window("weekly", minutes: 10080, remaining: 1, limit: "code_review")]
        ]
        try JSONSerialization.data(withJSONObject: fixture).write(to: cache.appendingPathComponent("codex-account.json"))

        let screen = DockDisplayArea(id: "synthetic", frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 880))
        var pointer = CGPoint(x: 700, y: 450), elapsed = 0.0
        let app = EngineRowsEntry.make(configuration: .init(executableURL: executable, applicationVersion: "synthetic-quota-windows",
            allowedEnvironment: environment, offline: true, readOnly: true),
            settingsStore: try EngineRowsEntry.makeSettingsStore(applicationSupport: root, preferredLanguages: ["en"]),
            createsNativePanels: false, bundleURL: root.appendingPathComponent("Synthetic.app"),
            dockEnvironment: { .init(displays: [screen], layouts: [], primaryDisplayID: screen.id, pointer: pointer) },
            deadlineElapsed: { elapsed }, deadlineScheduling: QuotaWindowsClock(), activateSettings: {})
        addTeardownBlock { @MainActor in await app.composition.stop() }
        await app.prepare()
        app.allowDockPresentation()
        let delivery = try await app.composition.client.start()
        _ = try await app.composition.client.subscribeRows(timeout: .seconds(5))
        XCTAssertEqual(app.composition.store.snapshot.delivery, delivery)
        let rows = try XCTUnwrap(app.composition.store.snapshot.rows?.projection.rows)
        let member = try XCTUnwrap(rows.first { $0.id == "codex" }?.accounts.first { $0.subscriptionRef == ref })
        XCTAssertEqual(Set(member.windows.compactMap(\.remainingPercent)), [63, 24, 12, 1])
        let monthly = try XCTUnwrap(member.windows.first { $0.role == .monthly && $0.limitKey == "main" })
        let scoped = try XCTUnwrap(member.windows.first { $0.limitKey == "code_review" })
        let dock = app.composition.dock, view = dock.dockView
        let reading = try XCTUnwrap(view.presentedReadingsForChecks[ref])
        XCTAssertEqual(reading.selectedWindowID, monthly.id)
        XCTAssertEqual(reading.readout, "12%", "The real plan-wide monthly quota is tighter than either general ring")
        XCTAssertEqual(reading.outer?.fraction, 0.63)
        XCTAssertEqual(reading.inner?.fraction, 0.24)

        let placement = try XCTUnwrap(dock.edgePresentation?.placement)
        let anchor = try XCTUnwrap(view.interactionAnchor(ref))
        pointer = CGPoint(x: placement.frame.minX + anchor.midX - view.bounds.minX,
                          y: placement.frame.maxY - anchor.midY + view.bounds.minY)
        let events = try XCTUnwrap(view.nozzleEventDelegate)
        events.hoverNozzle(ref)
        elapsed += 0.251
        dock.interactionControllerForChecks?.refresh()
        let card = try XCTUnwrap(dock.detachedCardForChecks)
        func text(_ id: String, in view: NSView) -> String? {
            if let field = view as? NSTextField, field.accessibilityIdentifier() == "dock.card.text." + id { return field.stringValue }
            return view.subviews.lazy.compactMap { text(id, in: $0) }.first
        }
        XCTAssertEqual(text("row.quota:" + scoped.id + ".value", in: card), "1%", "The scoped quota is visible in the hover card")
        XCTAssertNil(dock.nativePanel)
    }
}
#endif
