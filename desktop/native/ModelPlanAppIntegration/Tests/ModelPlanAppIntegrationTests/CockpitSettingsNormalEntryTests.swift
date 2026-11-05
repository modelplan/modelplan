// SPDX-License-Identifier: MIT
#if MODELPLAN_TEST_ONLY_SPI
import CryptoKit
import XCTest
import ModelPlanSettings
import ModelPlanEngineClient
@testable import ModelPlanCockpitWeb
@testable import ModelPlanAppIntegration

@MainActor final class CockpitSettingsNormalEntryTests: XCTestCase {
    func testS11CommittedThresholdsReachNormalFactoryLoadAndAppearance() async throws {
        for (stored, expected) in [(40 as Int?, 40), (16, 25), (nil, 25)] {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("cockpit-settings-" + UUID().uuidString)
            let assets = root.appendingPathComponent("bundle")
            try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: root) }
            func hash(_ bytes: Data) -> String { SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined() }
            let html = Data("<html>synthetic</html>".utf8)
            try html.write(to: assets.appendingPathComponent("index.html"))
            let manifest = try JSONSerialization.data(withJSONObject: [
                "schemaVersion": 1, "edition": "community", "interfaceOnly": true, "files": ["index.html": hash(html)],
            ])
            try manifest.write(to: assets.appendingPathComponent("bundle-manifest.json"))
            let bundle = try VerifiedCockpitBundle(root: assets, manifestSHA256: hash(manifest))
            let profile = root.appendingPathComponent("profile")
            let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: ["en"])
            _ = try await store.update { preferences in
                preferences.theme = .night
                preferences.motion = .on
                preferences.transparency = .on
                if let stored { preferences.redBelow = stored }
            }
            let profileFile = profile.appendingPathComponent("ModelPlan/settings.json")
            let savedBytes = try Data(contentsOf: profileFile)
            var fanout: CockpitStoreFanout?
            var page: CockpitWindowController?
            var sent: [String] = []
            let previous = CommunityCockpitApplicationFactory.verificationPage
            CommunityCockpitApplicationFactory.verificationPage = { actual in
                page = actual
                actual.verificationNoWindowShell = .init(closed: false, attached: true, forcedClosed: false, tier: .tall)
                actual.verificationNoWindowDelivery = { raw, complete in sent.append(raw); complete(.accepted) }
                actual.onFailure = { failure in XCTFail("Factory page failure: \(failure)") }
            }
            defer { CommunityCockpitApplicationFactory.verificationPage = previous; page?.discard() }
            let app = CommunityCockpitApplicationFactory.makeForChecks(configuration: .init(
                executableURL: root.appendingPathComponent("not-launched"), applicationVersion: "synthetic", allowedEnvironment: [:]),
                settingsStore: store, bundleURL: root, verifiedBundleForChecks: bundle) { config, consumer in
                    fanout = consumer as? CockpitStoreFanout
                    return ProcessEngineClient(configuration: config, consumer: consumer)
                }
            defer { app.composition.dock.close() }
            await app.prepare()
            let context = EngineDeliveryContext(sessionID: UUID().uuidString, floor: .init(storeEpoch: "synthetic", generation: 1), revision: 1)
            try await XCTUnwrap(fanout).consume(.context(context))
            app.showConsole()
            let deadline = ContinuousClock.now + .seconds(5)
            while sent.isEmpty && ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(10)) }
            let actual = try XCTUnwrap(page)
            func object(_ raw: String) throws -> [String: Any] {
                try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
            }
            let initial = try object(XCTUnwrap(sent.first))
            XCTAssertEqual(initial["type"] as? String, "load")
            XCTAssertEqual(initial["redBelow"] as? Int, expected)
            let initialAppearance = try XCTUnwrap(initial["appearance"] as? [String: Any])
            XCTAssertEqual(initialAppearance["reduceMotion"] as? Bool, true)
            XCTAssertEqual(initialAppearance["reduceTransparency"] as? Bool, true)
            XCTAssertEqual(try Data(contentsOf: profileFile), savedBytes)
            let persisted = await store.snapshot()
            XCTAssertEqual(persisted.preferences.redBelow, stored ?? 25)

            var ready = initial
            for key in ["data", "appearance", "shell", "redBelow", "nowUnixMs", "reason"] { ready[key] = nil }
            ready["type"] = "ready"
            ready["sequence"] = "1"
            ready["appearanceVersion"] = 2
            ready["capabilities"] = ["appearanceUpdates", "shellState", "shellActions"]
            let readyBytes = try JSONSerialization.data(withJSONObject: ready)
            actual.verificationReceive(String(decoding: readyBytes, as: UTF8.self), source: .init(mainFrame: true, origin: "modelplan-cockpit://bundle"))
            try actual.verificationConfirmVisible()
            let editor = app.settingsHost.application.editor
            for threshold in [10, 15, 20, 25, 30, 40] {
                let before = sent.count
                _ = try await editor.commit(SettingsB20Edit.redBelow(threshold))
                let updates = try sent.dropFirst(before).map(object).filter { $0["type"] as? String == "appearance" }
                XCTAssertEqual(updates.last?["redBelow"] as? Int, threshold, "Committed threshold \(threshold)")
                let saved = await store.snapshot()
                XCTAssertEqual(saved.preferences.redBelow, threshold)
            }
            XCTAssertNil(actual.window)
            XCTAssertNil(actual.verificationWebView)
        }
    }
}
#endif
