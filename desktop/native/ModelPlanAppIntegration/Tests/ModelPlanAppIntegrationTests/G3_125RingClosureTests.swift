// SPDX-License-Identifier: MIT
import CoreGraphics
import Foundation
import XCTest
import ModelPlanDock

/// G3-125 / Pulse v1.12.4 `Sources/Pulse/Panel/UsageRingView.swift`:
/// Pulse trims a Circle and strokes it with round caps. At radius 20 and width 2.6,
/// the missing 1% segment is shorter than the caps, so a 99% ring is visually closed;
/// 100% is an explicitly closed circle, never an open arc with coincident butt caps.
@MainActor final class G3_125RingClosureTests: XCTestCase {
    private let bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
    private let centre = CGPoint(x: 50, y: 50)
    private let radius: CGFloat = 20
    private let lineWidth: CGFloat = 2.6
    private let scale = 3
    private let sampleCount = 720

    private func image(remainingPercent: Double) throws -> CGImage {
        var input = DockInstrumentInput(id: "quota", name: "Synthetic quota", windows: [
            .init(id: "window", period: .fiveHour, label: "5h", remainingPercent: remainingPercent,
                  resetsAt: nil, durationSeconds: nil)
        ])
        input.dataState = .fresh
        let reading = try DockInstrumentProjection.evaluate(input, now: Date(timeIntervalSinceReferenceDate: 800_000_000))

        let station: [String: Any] = [
            "subscriptionID": "quota", "centre": [centre.x, centre.y], "diameter": 54,
            "readout": [[0, 0], [1, 1]], "eventRect": [[0, 0], [1, 1]], "glyphRect": [[49, 49], [2, 2]],
            "layers": [], "glyphs": [:],
            "outer": ["radius": radius, "width": lineWidth, "minimumVisibleFraction": 0, "opacity": 1],
            "inner": ["radius": 14, "width": 1.2, "minimumVisibleFraction": 0, "opacity": 1],
            "clock": ["radius": 9, "dotRadius": 1, "backWidth": 1, "positions": 12],
            "notchWidth": 0, "caseInnerRadius": 4, "singleWindowCaseInnerRadius": 4,
            "showsReadout": false, "fallbackVendorName": false
        ]
        func ink(_ r: Double, _ g: Double, _ b: Double) -> [String: Double] {
            ["r": r, "g": g, "b": b, "a": 1]
        }
        let json: [String: Any] = [
            "schemaVersion": 1, "bounds": [[bounds.minX, bounds.minY], [bounds.width, bounds.height]],
            "bodyPolygon": [], "fixedLayers": [], "stations": [station],
            "palette": [
                "case": ink(0, 0, 0), "track": ink(0.25, 0.25, 0.25), "normal": ink(0, 1, 0),
                "warning": ink(1, 1, 0), "critical": ink(1, 0, 0), "unknown": ink(0.5, 0.5, 0.5),
                "notch": ink(0, 0, 0), "text": ink(1, 1, 1), "alias": ink(1, 1, 1)
            ],
            "text": ["size": 10, "weight": 400], "aliasText": ["size": 10, "weight": 400]
        ]
        let skin = try JSONDecoder().decode(DockInstrumentSkin.self, from: JSONSerialization.data(withJSONObject: json))
        let resources = try DockArtworkStore(root: FileManager.default.temporaryDirectory, manifest: .init(files: [:]))
        return try DockInstrumentRenderer(resources: resources)
            .render(skin: skin, readings: ["quota": reading], scale: scale).image
    }

    private func colouredSamples(in image: CGImage) throws -> Int {
        let data = try XCTUnwrap(image.dataProvider?.data as Data?)
        let bytes = [UInt8](data)
        var coloured = 0
        for sample in 0..<sampleCount {
            let angle = Double(sample) * 2 * .pi / Double(sampleCount)
            let x = Int((centre.x + cos(angle) * radius) * CGFloat(scale))
            let y = Int((bounds.height - (centre.y + sin(angle) * radius)) * CGFloat(scale))
            let offset = y * image.bytesPerRow + x * 4
            XCTAssertLessThan(offset + 3, bytes.count)
            // Normal quota is deliberately pure green; the track and case are achromatic.
            if Int(bytes[offset + 1]) > Int(bytes[offset]) + 60,
               Int(bytes[offset + 1]) > Int(bytes[offset + 2]) + 60 {
                coloured += 1
            }
        }
        return coloured
    }

    func testNinetyNineAndOneHundredPercentRingsCloseLikePulseRoundCaps() throws {
        let samples99 = try colouredSamples(in: image(remainingPercent: 99))
        let samples100 = try colouredSamples(in: image(remainingPercent: 100))
        let samples95 = try colouredSamples(in: image(remainingPercent: 95))

        XCTAssertGreaterThanOrEqual(samples99, sampleCount - 3,
            "Pulse's round caps cover the 1% remainder when its arc length is less than the 2.6pt stroke: \(samples99)/\(sampleCount)")
        XCTAssertGreaterThanOrEqual(samples100, sampleCount - 3,
            "100% uses a closed circle, with no seam at twelve o'clock: \(samples100)/\(sampleCount)")
        XCTAssertLessThan(samples95, sampleCount - 8,
            "the control still shows a real gap once the remainder exceeds the round-cap overlap: \(samples95)/\(sampleCount)")
    }
}
