// SPDX-License-Identifier: MIT
import AppKit
import CryptoKit
import ImageIO
import XCTest
@_spi(DockResourceChecks) import ModelPlanDock

/// G3-98: during a ring-click refresh the number never counts; it fades out, stays hidden until the
/// result lands (or fails, or 3 s pass), then fades in with the value then admitted.
@MainActor final class DockRingReadoutFadeTests: XCTestCase {
    private func reading(_ percent: Double) throws -> DockInstrumentReading {
        var input = DockInstrumentInput(id: "synthetic", name: "Synthetic", windows: [
            DockQuotaWindowInput(id: "w", period: .fiveHour, label: "5h", remainingPercent: percent, resetsAt: nil, durationSeconds: nil)])
        input.dataState = .fresh; input.selectedWindowID = "w"
        return try DockInstrumentProjection.evaluate(input, now: Date())
    }
    private func makeView(_ folderOut: inout URL?) throws -> (DockInstrumentView, DockInstrumentSkin, DockInstrumentRenderer) {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("dock-raster-drag-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let context = try XCTUnwrap(CGContext(data: nil, width: 128, height: 128,
            bitsPerComponent: 8, bytesPerRow: 512, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(NSColor.gray.cgColor)
        context.fillEllipse(in: CGRect(x: 16, y: 16, width: 96, height: 96))
        let image = try XCTUnwrap(context.makeImage())
        let url = folder.appendingPathComponent("synthetic-body.png")
        let writer = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(writer, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(writer))
        let data = try Data(contentsOf: url)
        let store = try DockArtworkStore(root: folder, manifest: .init(files: ["body": .init(
            path: url.lastPathComponent, sha256: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(), bytes: data.count)]))
        let json: [String: Any] = ["schemaVersion": 1, "bounds": [[0, 0], [64, 64]],
            "bodyPolygon": [], "fixedLayers": [["resource": "body", "rect": [[0, 0], [64, 64]]]],
            "palette": [:], "text": ["size": 10, "weight": 400], "aliasText": ["size": 10, "weight": 400],
            "stations": [["subscriptionID": "synthetic", "centre": [32, 32], "diameter": 8,
                "readout": [[28, 40], [8, 4]], "aliasRect": [[20, 46], [24, 4]],
                "eventRect": [[40, 30], [4, 4]], "glyphRect": [[28, 28], [8, 8]],
                "layers": [], "glyphs": [:], "outer": ["radius": 4, "width": 1, "minimumVisibleFraction": 0, "opacity": 1],
                "inner": ["radius": 2, "width": 1, "minimumVisibleFraction": 0, "opacity": 1],
                "clock": ["radius": 5, "dotRadius": 0.5, "backWidth": 1, "positions": 10],
                "notchWidth": 1, "caseInnerRadius": 1]]]
        let skin = try JSONDecoder().decode(DockInstrumentSkin.self, from: JSONSerialization.data(withJSONObject: json))
        let renderer = DockInstrumentRenderer(resources: store)
        folderOut = folder
        let view = DockInstrumentView(frame: .zero)
        return (view, skin, renderer)
    }
    private func waitFrames(_ view: DockInstrumentView, until done: () -> Bool, seconds: Double) async throws {
        var waited = 0.0
        while !done(), waited < seconds { try await Task.sleep(for: .milliseconds(25)); waited += 0.025 }
    }
    func testNumberHidesUntilResultThenShowsNewValueAndFailureAndTimeoutKeepOld() async throws {
        var folder: URL?
        let (view, skin, renderer) = try makeView(&folder)
        defer { if let folder { try? FileManager.default.removeItem(at: folder) } }
        let old = try reading(60), new = try reading(40)
        XCTAssertEqual(old.readout, "60%")
        try view.applyOfficial(skin: skin, rows: [old], renderer: renderer, scale: 1, locale: "en")

        // Result lands: hidden past the 0.6 s sweep, then the NEW value fades in.
        XCTAssertTrue(view.playRefreshSweep("synthetic", reduceMotion: false))
        try await Task.sleep(for: .milliseconds(900))
        var frames = view.refreshSweepReadoutFramesForChecks
        XCTAssertEqual(frames.first?.alpha, 1)
        XCTAssertEqual(frames.last?.alpha, 0, "the number stays hidden while the refresh runs, beyond the sweep")
        XCTAssertTrue(view.refreshSweepAnimatingForChecks)
        try view.applyOfficial(skin: skin, rows: [new], renderer: renderer, scale: 1, locale: "en")
        try await waitFrames(view, until: { !view.refreshSweepAnimatingForChecks }, seconds: 2)
        frames = view.refreshSweepReadoutFramesForChecks
        XCTAssertEqual(frames.last?.alpha, 1, "the number fades back in once the result landed")
        XCTAssertEqual(frames.last?.text, "40%", "and shows the new value")
        XCTAssertTrue(frames.allSatisfy { $0.text == "60%" || $0.text == "40%" }, "no intermediate value is ever shown")
        let firstHidden = try XCTUnwrap(frames.firstIndex { $0.alpha == 0 })
        XCTAssertTrue(frames[..<firstHidden].allSatisfy { $0.text == "60%" }, "the old value only fades out")
        XCTAssertTrue(frames[firstHidden...].allSatisfy { $0.alpha == 0 || $0.text == "40%" || $0.text == "60%" })

        // Failure: released early, the OLD value fades back in.
        XCTAssertTrue(view.playRefreshSweep("synthetic", reduceMotion: false))
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(view.refreshSweepReadoutFramesForChecks.last?.alpha, 0)
        view.resolveRefreshReadout("synthetic")
        try await waitFrames(view, until: { !view.refreshSweepAnimatingForChecks }, seconds: 2)
        XCTAssertEqual(view.refreshSweepReadoutFramesForChecks.last?.alpha, 1)
        XCTAssertEqual(view.refreshSweepReadoutFramesForChecks.last?.text, "40%", "a failed refresh restores the old value")

        // Timeout: no result for 3 s, the old value returns.
        XCTAssertTrue(view.playRefreshSweep("synthetic", reduceMotion: false))
        try await Task.sleep(for: .milliseconds(2700))
        XCTAssertEqual(view.refreshSweepReadoutFramesForChecks.last?.alpha, 0, "still hidden before the cap")
        try await waitFrames(view, until: { !view.refreshSweepAnimatingForChecks }, seconds: 2)
        XCTAssertEqual(view.refreshSweepReadoutFramesForChecks.last?.alpha, 1)
        XCTAssertEqual(view.refreshSweepReadoutFramesForChecks.last?.text, "40%", "the timeout shows the old value")

        // Reduce Motion: no fade, no frames, instant swap.
        XCTAssertTrue(view.playRefreshSweep("synthetic", reduceMotion: true))
        XCTAssertTrue(view.refreshSweepReadoutFramesForChecks.isEmpty)
        XCTAssertFalse(view.refreshSweepAnimatingForChecks)
        view.dispose()
    }
}
