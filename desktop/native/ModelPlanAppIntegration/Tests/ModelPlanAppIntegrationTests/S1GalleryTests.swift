// SPDX-License-Identifier: MIT
import Foundation
import XCTest
@testable import S1GalleryCore
import ModelPlanDock

@MainActor final class S1GalleryTests: XCTestCase {
    func testGoldenSelectedWeeklyClockUsesReportedReset() throws {
        let now = Date(timeIntervalSince1970: 1_792_506_300)
        let input = try XCTUnwrap(S1SyntheticProvider(count: 1, now: now).inputs.first)
        let reading = try DockInstrumentProjection.evaluate(input, now: now)
        XCTAssertEqual(reading.readout, "76%")
        XCTAssertEqual(try XCTUnwrap(reading.timeLeftFraction), 7410.0 / 10080.0, accuracy: 1e-9)
        XCTAssertEqual(reading.litTimePoints(positions: 37), 28)
    }

    func testGoldenNoticesKeepCardsAndForecastDistinctFromPublicReset() {
        let now = Date(timeIntervalSince1970: 1_792_506_300)
        let provider = S1SyntheticProvider(count: 4, now: now)
        let content = provider.makeContent(.init(snapshot: nil, diagnostics: .init(), now: now))
        let notices = Dictionary(uniqueKeysWithValues: content.signals.compactMap { signal in
            DockNoticeProjection.selected(for: signal, at: now).map { (signal.id, $0) }
        })
        XCTAssertEqual(Set(notices.keys), Set(["codex", "claude"]))
        XCTAssertEqual(notices["codex"]?.key.kind, .cardsExpiring)
        XCTAssertEqual(notices["claude"]?.key.kind, .forecast)
        XCTAssertTrue(notices.values.allSatisfy { $0.tone == .amber && $0.shape == .solid })
    }

    func testProduceOffscreenGallery() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let golden = env["MODELPLAN_S1_GOLDEN_DIR"], let output = env["MODELPLAN_S1_GALLERY_DIR"] else {
            throw XCTSkip("Set MODELPLAN_S1_GOLDEN_DIR and MODELPLAN_S1_GALLERY_DIR to run the synthetic gallery")
        }
        try await S1Gallery.run(goldenPath: golden, outputPath: output)
        let root = URL(fileURLWithPath: output, isDirectory: true)
        let html = try String(contentsOf: root.appendingPathComponent("index.html"), encoding: .utf8)
        let expression = try NSRegularExpression(pattern: #"(?:src|href)="([^"]+)""#)
        let text = html as NSString
        let matches = expression.matches(in: html, range: NSRange(location: 0, length: text.length))
        XCTAssertFalse(matches.isEmpty)
        for match in matches {
            let path = text.substring(with: match.range(at: 1))
            XCTAssertFalse(path.hasPrefix("/")); XCTAssertFalse(path.split(separator: "/").contains(".."))
            XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent(path).path), path)
        }
    }
}
