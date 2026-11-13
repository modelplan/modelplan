// SPDX-License-Identifier: MIT
import AppKit
import CryptoKit
import ImageIO
import XCTest
@_spi(DockResourceChecks) import ModelPlanDock

/// G3-98: during a ring-click refresh the number never counts; it fades out, stays hidden until the
/// result lands (or fails, or 3 s pass), then fades in with the value then admitted.
@MainActor final class DockRingReadoutFadeTests: XCTestCase {
    private func reading(_ percent: Double, id: String = "synthetic") throws -> DockInstrumentReading {
        var input = DockInstrumentInput(id: id, name: "Synthetic " + id, windows: [
            DockQuotaWindowInput(id: "w", period: .fiveHour, label: "5h", remainingPercent: percent, resetsAt: nil, durationSeconds: nil)])
        input.dataState = .fresh; input.selectedWindowID = "w"
        return try DockInstrumentProjection.evaluate(input, now: Date())
    }
    private func makeView(_ folderOut: inout URL?, ids: [String] = ["synthetic"]) throws -> (DockInstrumentView, DockInstrumentSkin, DockInstrumentRenderer) {
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
        // One 64-point station per member, side by side.
        func station(_ id: String, _ dx: Int) -> [String: Any] {
            ["subscriptionID": id, "centre": [32 + dx, 32], "diameter": 8,
                "readout": [[28 + dx, 40], [8, 4]], "aliasRect": [[20 + dx, 46], [24, 4]],
                "eventRect": [[40 + dx, 30], [4, 4]], "glyphRect": [[28 + dx, 28], [8, 8]],
                "layers": [], "glyphs": [:], "outer": ["radius": 4, "width": 1, "minimumVisibleFraction": 0, "opacity": 1],
                "inner": ["radius": 2, "width": 1, "minimumVisibleFraction": 0, "opacity": 1],
                "clock": ["radius": 5, "dotRadius": 0.5, "backWidth": 1, "positions": 10],
                "notchWidth": 1, "caseInnerRadius": 1]
        }
        let width = 64 * ids.count
        let json: [String: Any] = ["schemaVersion": 1, "bounds": [[0, 0], [width, 64]],
            "bodyPolygon": [], "fixedLayers": [["resource": "body", "rect": [[0, 0], [width, 64]]]],
            "palette": [:], "text": ["size": 10, "weight": 400], "aliasText": ["size": 10, "weight": 400],
            "stations": ids.enumerated().map { station($0.element, 64 * $0.offset) }]
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
        // The first frame is drawn on a later main-actor turn, so its alpha is only known to be in range.
        XCTAssertTrue((0...1).contains(try XCTUnwrap(frames.first?.alpha)))
        XCTAssertEqual(frames.first?.text, "60%")
        XCTAssertTrue(zip(frames, frames.dropFirst()).allSatisfy { $1.alpha <= $0.alpha }, "the number only fades out before the result")
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

        // Fast result: it lands while the old number is still fading out. The visible text never swaps;
        // the old value finishes fading out, then the new value fades in.
        let fast = try reading(25)
        XCTAssertTrue(view.playRefreshSweep("synthetic", reduceMotion: false))
        try await Task.sleep(for: .milliseconds(40))
        try view.applyOfficial(skin: skin, rows: [fast], renderer: renderer, scale: 1, locale: "en")
        try await waitFrames(view, until: { !view.refreshSweepAnimatingForChecks }, seconds: 2)
        frames = view.refreshSweepReadoutFramesForChecks
        // Alpha falls to its lowest frame at the end of the fade-out and rises after it; the text may only
        // change at that lowest frame, never while the old number is still visible on the way down.
        let lowest = try XCTUnwrap(frames.indices.min { frames[$0].alpha < frames[$1].alpha })
        XCTAssertTrue(frames[..<lowest].allSatisfy { $0.text == "40%" }, "the old text stays until the fade-out ends")
        XCTAssertTrue(frames[(lowest + 1)...].allSatisfy { $0.text == "25%" }, "only the new value fades back in")
        XCTAssertEqual(frames.last?.alpha, 1)
        XCTAssertEqual(frames.last?.text, "25%")

        // Reduce Motion: no fade, no frames, instant swap.
        XCTAssertTrue(view.playRefreshSweep("synthetic", reduceMotion: true))
        XCTAssertTrue(view.refreshSweepReadoutFramesForChecks.isEmpty)
        XCTAssertFalse(view.refreshSweepAnimatingForChecks)
        view.dispose()
    }

    /// macrevd: a repeated click on a waiting ring and a click on another ring never release a number early.
    func testRepeatedAndOtherRingClicksKeepAWaitingNumberHidden() async throws {
        var folder: URL?
        let (view, skin, renderer) = try makeView(&folder, ids: ["a", "b"])
        defer { if let folder { try? FileManager.default.removeItem(at: folder) } }
        try view.applyOfficial(skin: skin, rows: [reading(60, id: "a"), reading(70, id: "b")], renderer: renderer, scale: 1, locale: "en")
        func frames(_ id: String) -> [(id: String, alpha: Double, text: String)] { view.refreshSweepReadoutFramesForChecks.filter { $0.id == id } }

        XCTAssertTrue(view.playRefreshSweep("a", reduceMotion: false))
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(frames("a").last?.alpha, 0)
        // Repeated click on A while its refresh still runs: A stays hidden (no fade back in, no restart).
        XCTAssertTrue(view.playRefreshSweep("a", reduceMotion: false))
        try await Task.sleep(for: .milliseconds(400))
        XCTAssertFalse(frames("a").isEmpty)
        XCTAssertTrue(frames("a").allSatisfy { $0.alpha == 0 }, "a repeated click keeps the waiting number hidden")

        // Click B while A still waits: A stays hidden, B fades out on its own clock.
        let aBefore = frames("a").count
        XCTAssertTrue(view.playRefreshSweep("b", reduceMotion: false))
        try await Task.sleep(for: .milliseconds(400))
        XCTAssertTrue(frames("a").dropFirst(aBefore).allSatisfy { $0.alpha == 0 }, "another ring's refresh never reveals A")
        XCTAssertGreaterThan(frames("a").count, aBefore, "A keeps being held while B sweeps")
        XCTAssertEqual(frames("b").last?.alpha, 0)

        // A's result lands: only A comes back, with its new value; B still waits.
        try view.applyOfficial(skin: skin, rows: [reading(45, id: "a"), reading(70, id: "b")], renderer: renderer, scale: 1, locale: "en")
        try await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(frames("a").last?.alpha, 1)
        XCTAssertEqual(frames("a").last?.text, "45%")
        XCTAssertEqual(frames("b").last?.alpha, 0, "B stays hidden until its own result")
        XCTAssertTrue(view.refreshSweepAnimatingForChecks)

        // B fails: its old number returns.
        view.resolveRefreshReadout("b")
        try await waitFrames(view, until: { !view.refreshSweepAnimatingForChecks }, seconds: 2)
        XCTAssertEqual(frames("b").last?.alpha, 1)
        XCTAssertEqual(frames("b").last?.text, "70%")
        view.dispose()
    }
}
