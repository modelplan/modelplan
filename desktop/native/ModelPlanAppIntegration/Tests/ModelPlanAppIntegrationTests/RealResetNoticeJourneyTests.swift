// SPDX-License-Identifier: MIT
import AppKit
import CryptoKit
import XCTest
import ModelPlanEngineClient
import ModelPlanSettings
@_spi(DockResourceChecks) import ModelPlanDock
@testable import ModelPlanAppIntegration

/// Exercises the ordinary app-server and production Dock with an isolated, synthetic home.
@MainActor final class RealResetNoticeJourneyTests: XCTestCase {
    private enum FixtureError: Error { case noBinary, malformedImage, timeout }
    private func json(_ object: Any) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes])
    }
    private func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    private func write(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
    private func publish(home: URL, phase: String, clock: Date) throws {
        let format = ISO8601DateFormatter(), dummy = String(repeating: "a", count: 64)
        let published = clock.addingTimeInterval(phase == "expired" ? -72 * 3600 : -120)
        let deadline = clock.addingTimeInterval(phase == "expired" ? -3600 : 3600)
        var records: [[String: Any]] = [["id": "synthetic-reset", "provider": "openai", "eventType": "direct_reset_announced",
            "status": "upstream-announced", "publishedAt": format.string(from: published),
            "schedule": ["precision": "deadline", "from": format.string(from: deadline), "through": format.string(from: deadline)]]]
        if phase == "confirmed" {
            records.append(["id": "synthetic-confirmation", "provider": "openai", "eventType": "direct_reset_reported_complete",
                            "status": "upstream-confirmed", "publishedAt": format.string(from: clock.addingTimeInterval(-30)), "confirms": "synthetic-reset"])
        }
        let component = try json(["schemaVersion": 1, "kind": "client", "dependencies": ["models": dummy, "registry": dummy, "rules": dummy, "calendar": dummy],
            "data": ["units": ["ability": "websiteAbility", "cost": "usdPerReferenceTask", "time": "taskTimeCrossModel"],
                     "models": [], "lineups": [], "resets": records, "windows": []]])
        let componentHash = hash(component)
        var references: [String: Any] = [:]
        for name in ["methods", "registry", "models", "plans", "rules", "news", "calendar"] {
            references[name] = ["schemaVersion": 1, "hash": dummy, "bytes": 2]
        }
        references["client"] = ["schemaVersion": 1, "hash": componentHash, "bytes": component.count]
        let methods = try String(decoding: json(["index": "unified-v03-estimator-0.1.0-internal", "recommendation": "balanced-coding-absolute-v4"]), as: UTF8.self)
        let components = try String(decoding: json(references), as: UTF8.self)
        let core = "{\"schemaVersion\":1,\"comparisonVersion\":\"synthetic\",\"methods\":\(methods),\"components\":\(components)}"
        let id = String(hash(Data(core.utf8)).prefix(24))
        let manifest = Data((String(core.dropLast()) + ",\"publicationId\":\"\(id)\",\"publishedAt\":\"\(format.string(from: published))\"}").utf8)
        let cache = home.appendingPathComponent("Library/Caches/modelplan", isDirectory: true)
        try write(component, to: cache.appendingPathComponent("objects/\(componentHash).json"))
        try write(manifest, to: cache.appendingPathComponent("releases/\(id)/manifest.json"))
        try write(json(["publicationId": id, "manifestHash": hash(manifest), "component": "client", "componentHash": componentHash]), to: cache.appendingPathComponent("state.json"))
    }
    private func seedLocalReading(home: URL, clock: Date) throws {
        let format = ISO8601DateFormatter(), observed = clock.addingTimeInterval(-90)
        let reset = Int(clock.addingTimeInterval(7200).timeIntervalSince1970)
        let line: [String: Any] = ["timestamp": format.string(from: observed), "type": "event_msg", "payload": ["type": "token_count",
            "rate_limits": ["limit_id": "codex", "plan_type": "plus", "primary": ["used_percent": 25, "window_minutes": 300, "resets_at": reset]]]]
        var data = try json(line); data.append(0x0a)
        try write(data, to: home.appendingPathComponent(".codex/sessions/2026/11/04/rollout-2026-11-04T00-00-00-synthetic.jsonl"))
    }
    private func eventually(_ predicate: @MainActor () -> Bool) async throws {
        for _ in 0..<200 { if predicate() { return }; try await Task.sleep(for: .milliseconds(50)) }
        throw FixtureError.timeout
    }
    private func pixels(_ image: CGImage, rect: CGRect) throws -> Data {
        guard let crop = image.cropping(to: rect.integral), let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: crop.width, height: crop.height, bitsPerComponent: 8,
                                      bytesPerRow: crop.width * 4, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw FixtureError.malformedImage }
        context.draw(crop, in: CGRect(x: 0, y: 0, width: crop.width, height: crop.height))
        guard let bytes = context.data else { throw FixtureError.malformedImage }
        return Data(bytes: bytes, count: crop.width * crop.height * 4)
    }
    func testRealAppServerResetNoticesReachProductionDockAndClear() async throws {
        guard let binary = ProcessInfo.processInfo.environment["MODELPLAN_ENGINE_TEST_BINARY"] else {
            throw XCTSkip("Real engine binary is required for this end-to-end test")
        }
        _ = NSApplication.shared
        let home = FileManager.default.temporaryDirectory.appendingPathComponent("reset-e2e-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }
        let clock = Date()
        try seedLocalReading(home: home, clock: clock); try publish(home: home, phase: "announced", clock: clock)
        let store = try SettingsStore(url: home.appendingPathComponent("settings.json"))
        try await store.update { $0.language = .english; $0.showDock = true; $0.autoHide = false; $0.showPercentages = true }
        let environment = ["HOME": home.path, "TMPDIR": home.path, "PATH": "/usr/bin:/bin", "LANG": "C"]
        let app = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: binary), applicationVersion: "synthetic-e2e", allowedEnvironment: environment, offline: true),
                                       settingsStore: store, createsNativePanels: false)
        await app.prepare(); app.allowDockPresentation(); await app.composition.start()
        do {
            let dock = app.composition.dock
            try await eventually { dock.dockView.presentedNoticesForChecks.values.contains { $0.key.kind == .resetAnnounced && $0.shape == .hollow && $0.tone == .blue } }
            let notice = try XCTUnwrap(dock.dockView.presentedNoticesForChecks.values.first { $0.key.kind == .resetAnnounced })
            let skin = try XCTUnwrap(dock.dockView.presentedSkinForChecks)
            let station = try XCTUnwrap(skin.stations.first { $0.subscriptionID == notice.key.subscriptionID })
            XCTAssertGreaterThan(station.eventRect.midX, station.readout.midX, "notice appears after the percentage")
            let image = try XCTUnwrap(dock.dockView.presentedImageForChecks)
            let scale = CGFloat(image.width) / skin.bounds.width
            let pixelRect = station.eventRect.offsetBy(dx: -skin.bounds.minX, dy: -skin.bounds.minY).applying(CGAffineTransform(scaleX: scale, y: scale))
            let announcedPixels = try pixels(image, rect: pixelRect)
            let sliver = try dock.prepareSliver(size: CGSize(width: 4, height: 80))
            XCTAssertTrue(sliver.noticeMarks.contains { $0.notice.key == notice.key && $0.notice.shape == .hollow && $0.notice.tone == .blue })
            try publish(home: home, phase: "confirmed", clock: clock)
            try await eventually { dock.dockView.presentedNoticesForChecks.values.contains { $0.key.kind == .resetConfirmed && $0.shape == .solid && $0.tone == .blue } }
            let confirmedImage = try XCTUnwrap(dock.dockView.presentedImageForChecks)
            let confirmedPixels = try pixels(confirmedImage, rect: pixelRect)
            XCTAssertNotEqual(announcedPixels, confirmedPixels, "confirmed dot must render differently from hollow announcement")
            let confirmedSliver = try dock.prepareSliver(size: CGSize(width: 4, height: 80))
            XCTAssertTrue(confirmedSliver.noticeMarks.contains { $0.notice.key.kind == .resetConfirmed && $0.notice.shape == .solid && $0.notice.tone == .blue })
            try publish(home: home, phase: "expired", clock: clock)
            try await eventually { dock.dockView.presentedNoticesForChecks.isEmpty && app.composition.resetSignals.allSatisfy { $0.reset == nil } }
            let expiredImage = try XCTUnwrap(dock.dockView.presentedImageForChecks)
            XCTAssertNotEqual(announcedPixels, try pixels(expiredImage, rect: pixelRect), "expired dot must leave the rendered surface")
            XCTAssertNotEqual(confirmedPixels, try pixels(expiredImage, rect: pixelRect), "expired confirmation must leave the rendered surface")
            let emptySliver = try dock.prepareSliver(size: CGSize(width: 4, height: 80))
            XCTAssertTrue(emptySliver.noticeMarks.isEmpty)
            XCTAssertNil(dock.nativePanel)
            await app.composition.stop()
        } catch {
            await app.composition.stop()
            throw error
        }
    }
}
