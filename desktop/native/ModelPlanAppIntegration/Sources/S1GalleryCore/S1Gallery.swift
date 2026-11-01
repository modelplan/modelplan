// SPDX-License-Identifier: MIT
import AppKit
import CoreGraphics
import CoreText
import CryptoKit
import Foundation
import ModelPlanSettings
@_spi(DockResourceChecks) import ModelPlanDock
import ModelPlanDockResources
@_spi(DockResourceChecks) import ModelPlanAppIntegration

private struct S1Manifest: Decodable {
    struct Clip: Decodable { let x: Double, y: Double, width: Double, height: Double }
    struct Capture: Decodable { let file, scenario: String; let size: Int; let edge: String; let count: Int; let theme, state, sha256: String; let clip: Clip }
    let schemaVersion: Int
    let prototypeSourceCommit: String
    let captures: [Capture]
}

@MainActor private final class S1SyntheticProvider: DockContentProvider {
    let inputs: [DockInstrumentInput]
    init(count: Int, now: Date) {
        let fixtures: [(String, String, String, Double, Double?, Double?)] = [
            ("codex", "ChatGPT", "openai", 89, 76, 198),
            ("claude", "Claude", "claude", 9, 42, 120),
            ("zhipu", "GLM", "zhipu", 72, nil, 48),
            ("cursor", "Cursor", "cursor", 14, nil, nil),
            ("ocgo", "OC Go", "opencode", 54, nil, nil),
            ("copilot", "Copilot", "copilot", 61, nil, nil),
            ("kimi", "Kimi", "kimi", 81, 65, 75)
        ]
        inputs = fixtures.prefix(count).map { id, name, vendor, primary, secondary, minutes in
            var windows = [DockQuotaWindowInput(id: "primary", period: .fiveHour, label: "5h", remainingPercent: primary,
                resetsAt: minutes.map { now.addingTimeInterval($0 * 60) }, durationSeconds: 5 * 3600)]
            if let secondary { windows.append(.init(id: "weekly", period: .week, label: "Weekly", remainingPercent: secondary, resetsAt: nil, durationSeconds: nil)) }
            var input = DockInstrumentInput(id: id, name: name, windows: windows)
            input.vendorResourceKey = vendor; input.dataState = .fresh
            if id == "codex" || id == "claude" {
                input.working = .init(subscriptionID: id, bindingVerified: true, fresh: true, observedOutput: true)
            }
            return input
        }
    }
    func makeContent(_ context: DockContentContext) -> DockContent { .init(snapshot: .init(inputs: inputs)) }
}

@MainActor private enum S1PixelReport {
    struct Result {
        let native: Data
        let diff: Data
        let similarity: Double
        let maskedPixels: Int
        let ink: [String: Bool]
    }
    static func make(reference: Data, image: CGImage, skin: DockInstrumentSkin, capture: S1Manifest.Capture) throws -> Result {
        guard let golden = NSBitmapImageRep(data: reference),
              image.width == Int(ceil(skin.bounds.width * 2)), image.height == Int(ceil(skin.bounds.height * 2)),
              let actual = NSBitmapImageRep(cgImage: image).copy() as? NSBitmapImageRep else { throw CocoaError(.fileReadCorruptFile) }
        let width = golden.pixelsWide, height = golden.pixelsHigh
        guard width > 0, height > 0, width * height <= 8_000_000 else { throw CocoaError(.fileReadTooLarge) }
        func bitmap() throws -> NSBitmapImageRep {
            guard let value = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bitmapFormat: .alphaNonpremultiplied,
                bytesPerRow: width * 4, bitsPerPixel: 32) else { throw CocoaError(.fileReadCorruptFile) }
            return value
        }
        let composed = try bitmap(), difference = try bitmap()
        guard let pixels = composed.bitmapData, let diffs = difference.bitmapData else { throw CocoaError(.fileReadCorruptFile) }
        let resources = try DockArtworkStore(root: DockThirdPartyResources.rootURL(), manifest: JSONDecoder().decode(DockResourceManifest.self, from: DockThirdPartyResources.manifestData(allowBetaMarks: false)))
        let font = try resources.font("font-jetbrains-mono", size: skin.text.size, weight: skin.text.weight)
        var masks = [(String, CGRect)]()
        for station in skin.stations {
            guard let id = station.subscriptionID, let value = ["claude": "9%", "cursor": "14%"][id] else { continue }
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: value, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font]))
            var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
            let advance = CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
            let glyph = CTLineGetImageBounds(line, nil)
            let baseline = station.readout.midY + (ascent - descent) / 2
            masks.append((id, CGRect(x: station.readout.midX - CGFloat(advance)/2 + glyph.minX,
                                      y: baseline - glyph.maxY, width: glyph.width, height: glyph.height)))
        }
        func background(_ x: Double, _ y: Double) -> (Double, Double, Double) {
            if capture.theme == "light" { return (237, 241, 245) }
            let cx = 1470.0 * 0.22, cy = 956.0 * 1.08
            let rx = max(cx, 1470-cx) * sqrt(2), ry = max(cy, abs(956-cy)) * sqrt(2)
            let distance = hypot((x-cx)/rx, (y-cy)/ry)
            let stops: [(Double, (Double, Double, Double))] = [(0,(77,90,94)),(0.26,(38,54,62)),(0.50,(24,38,58)),(0.78,(15,22,38))]
            guard distance < 0.78 else { return stops.last!.1 }
            let n = max(1, stops.firstIndex(where: { distance <= $0.0 }) ?? 3)
            let a = stops[n-1], b = stops[n], t = max(0, min(1, (distance-a.0)/(b.0-a.0)))
            return (a.1.0+(b.1.0-a.1.0)*t,a.1.1+(b.1.1-a.1.1)*t,a.1.2+(b.1.2-a.1.2)*t)
        }
        var errorSum = 0.0, samples = 0, masked = 0, ink = ["claude":false, "cursor":false]
        for y in 0..<height { for x in 0..<width {
            let gx = capture.clip.x + (Double(x)+0.5)/2, gy = capture.clip.y + (Double(y)+0.5)/2
            let nx = Int(floor((gx-Double(skin.bounds.minX))*2)), ny = Int(floor((gy-Double(skin.bounds.minY))*2))
            let bg = background(gx, gy)
            var rgb = [bg.0, bg.1, bg.2]
            if nx >= 0, ny >= 0, nx < image.width, ny < image.height, let color = actual.colorAt(x: nx, y: ny)?.usingColorSpace(.sRGB) {
                let alpha = Double(color.alphaComponent)
                rgb = [Double(color.redComponent)*255*alpha+bg.0*(1-alpha),Double(color.greenComponent)*255*alpha+bg.1*(1-alpha),Double(color.blueComponent)*255*alpha+bg.2*(1-alpha)]
            }
            guard let expected = golden.colorAt(x:x,y:y)?.usingColorSpace(.sRGB) else { throw CocoaError(.fileReadCorruptFile) }
            let expectedRGB = [Double(expected.redComponent)*255, Double(expected.greenComponent)*255, Double(expected.blueComponent)*255]
            let offset = y * composed.bytesPerRow + x * 4, point = CGPoint(x:gx,y:gy)
            let matching = masks.filter { $0.1.contains(point) }
            if !matching.isEmpty {
                masked += 1
                for (id, _) in matching where rgb[0] >= 200 && rgb[1] <= 100 && rgb[2] <= 100 { ink[id] = true }
            }
            for channel in 0..<3 {
                let value = UInt8(max(0,min(255,Int(rgb[channel].rounded()))))
                pixels[offset+channel] = value
                let delta = abs(rgb[channel]-expectedRGB[channel])
                diffs[offset+channel] = matching.isEmpty ? UInt8(max(0,min(255,Int(delta.rounded())))) : 0
                if matching.isEmpty { errorSum += delta; samples += 1 }
            }
            pixels[offset+3] = 255; diffs[offset+3] = 255
        }}
        guard samples > 0, let nativePNG = composed.representation(using: .png, properties: [:]),
              let diffPNG = difference.representation(using: .png, properties: [:]) else { throw CocoaError(.fileReadCorruptFile) }
        return Result(native: nativePNG, diff: diffPNG, similarity: 1 - errorSum / Double(samples) / 255,
                      maskedPixels: masked, ink: ink.filter { key, _ in masks.contains { $0.0 == key } })
    }
}

/// Report-only, opt-in synthetic evidence. It does not mark visual acceptance.
@MainActor public enum S1Gallery {
    private static func envPublishedOutput(defaultOutput: URL) -> URL {
        guard let path = ProcessInfo.processInfo.environment["MODELPLAN_S1_PUBLISHED_DIR"], !path.isEmpty else { return defaultOutput }
        return URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
    }
    public static func run(goldenPath: String, outputPath: String) async throws {
        _ = NSApplication.shared
        let fm = FileManager.default, golden = URL(fileURLWithPath: goldenPath, isDirectory: true)
        let output = URL(fileURLWithPath: outputPath, isDirectory: true)
        let manifest = try JSONDecoder().decode(S1Manifest.self, from: Data(contentsOf: golden.appendingPathComponent("manifest.json")))
        guard manifest.schemaVersion == 1,
              manifest.prototypeSourceCommit == "69f1b639201f0b9cedd1ad9f109d26423e67e75f",
              manifest.captures.count == 52 else { throw CocoaError(.fileReadCorruptFile) }
        try fm.createDirectory(at: output, withIntermediateDirectories: true)
        for name in ["index.html", "metrics.json", "README.md"] where fm.fileExists(atPath: output.appendingPathComponent(name).path) {
            throw CocoaError(.fileWriteFileExists)
        }
        guard let oraclePath = ProcessInfo.processInfo.environment["MODELPLAN_S1_ORACLE_FILE"], !oraclePath.isEmpty else {
            throw CocoaError(.fileNoSuchFile)
        }
        let oracleURL = URL(fileURLWithPath: oraclePath).standardizedFileURL
        // The HTML uses this project-relative handoff link; verify it resolves
        // to exactly the input whose bytes and hashes are checked below.
        // Reports may be generated in owned scratch and published only after
        // completion. Validate links against the intended final directory.
        let publishedOutput = envPublishedOutput(defaultOutput: output)
        let linkedGolden = publishedOutput.appendingPathComponent("../../handoffs/20261101-dock-golden", isDirectory: true).standardizedFileURL.resolvingSymlinksInPath()
        guard linkedGolden == golden.standardizedFileURL.resolvingSymlinksInPath() else { throw CocoaError(.fileReadInvalidFileName) }
        let oracleBytes = try Data(contentsOf: oracleURL)
        guard SHA256.hash(data: oracleBytes).map({ String(format: "%02x", $0) }).joined() == "746709f8d11eab84e94896537696f35531e644e7be8d35a7eda055f15a4268bb" else { throw CocoaError(.fileReadCorruptFile) }
        guard let oracleRoot = try JSONSerialization.jsonObject(with: oracleBytes) as? [String: Any],
              let oracleCases = oracleRoot["cases"] as? [[String: Any]] else { throw CocoaError(.fileReadCorruptFile) }
        let now = ISO8601DateFormatter().date(from: "2026-10-20T14:05:00Z")!
        let display = DockDisplayArea(id: "s1-synthetic", frame: .init(x: 0, y: 0, width: 1470, height: 956), visibleFrame: .init(x: 0, y: 0, width: 1470, height: 930))
        let environment = DockEdgeEnvironment(displays: [display], layouts: [], primaryDisplayID: "s1-synthetic")
        let temp = fm.temporaryDirectory.appendingPathComponent("s1-gallery-settings-" + UUID().uuidString)
        try fm.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: temp) }
        var written = [URL](), records = [[String: Any]](), html = "<!doctype html><meta charset=\"utf-8\"><title>S1 Dock gallery</title><h1>S1 Dock report (not visual acceptance)</h1><table><tr><th>Scenario</th><th>Reference</th><th>Native</th><th>Metric / status</th></tr>"
        for (index, capture) in manifest.captures.enumerated() {
            guard capture.file.range(of: #"^[A-Za-z0-9._-]+\.png$"#, options: .regularExpression) != nil else { throw CocoaError(.fileReadInvalidFileName) }
            let source = golden.appendingPathComponent(capture.file), bytes = try Data(contentsOf: source)
            let hash = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
            guard hash == capture.sha256 else { throw CocoaError(.fileReadCorruptFile) }
            let refName = "../../handoffs/20261101-dock-golden/" + capture.file
            let nativeName = String(format: "native-%02d.png", index)
            var record: [String: Any] = ["reference": capture.file, "scenario": capture.scenario, "state": capture.state,
                "edge": capture.edge, "size": capture.size, "count": capture.count, "theme": capture.theme]
            var status = "not-run: button state is not exposed by the production appearance", nativeCell = "not run"
            if capture.scenario == "dock" {
                let store = try SettingsStore(url: temp.appendingPathComponent("settings-\(index).json"))
                try await store.update {
                    $0.dockEdge = capture.edge == "bottom" ? .bottom : .right
                    $0.size = capture.size == 36 ? .small : capture.size == 52 ? .large : .medium
                    $0.dockDisplayID = "s1-synthetic"; $0.dockAlongFraction = 0.5; $0.language = .chinese
                }
                let host = ProductionDockFactory.community(createsNativePanels: false, nativeEnvironment: { environment }, currentDate: { now })
                host.captureBackingScaleForChecks = 2
                host.setDockContentProvider(S1SyntheticProvider(count: capture.count, now: now))
                let coordinator = SettingsApplicationCoordinator(store: store) { host.apply($0) }
                await coordinator.reload()
                if let error = host.lastAppearanceError {
                    status = "appearance-error: \(String(describing: error))"
                } else if let image = host.dockView.presentedImageForChecks, let skin = host.dockView.presentedSkinForChecks,
                          let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) {
                    let ids = skin.stations.compactMap(\.subscriptionID)
                    let expectedIDs = Array(["codex", "claude", "zhipu", "cursor", "ocgo", "copilot", "kimi"].prefix(capture.count))
                    let countOK = ids == expectedIDs
                    record["registeredStationCount"] = ids.count; record["membershipAssertion"] = countOK ? "pass" : "fail"
                    record["contentAssertion"] = "not-run: reset-event presentation is not connected to the synthetic provider"
                    record["skinBounds"] = [skin.bounds.minX, skin.bounds.minY, skin.bounds.width, skin.bounds.height]
                    let oracle = oracleCases.first { ($0["edge"] as? String) == capture.edge && ($0["D"] as? Int) == capture.size && ($0["count"] as? Int) == capture.count && !($0["aliases"] as? Bool ?? false) }
                    var geometryError = Double.infinity
                    if let outline = oracle?["outline"] as? [[Double]], outline.count == skin.bodyPolygon.count,
                       let stations = oracle?["stations"] as? [[String: Any]], stations.count == skin.stations.count,
                       let button = oracle?["button"] as? [Double], button.count == 2,
                       let actualButton = host.registeredConsoleButtonForChecks {
                        var delta = outline.allSatisfy { $0.count == 2 } ? 0.0 : Double.infinity
                        for (actual, expected) in zip(skin.bodyPolygon, outline) where expected.count == 2 {
                            delta = max(delta, abs(Double(actual.x)-expected[0]), abs(Double(actual.y)-expected[1]))
                        }
                        for (actual, expected) in zip(skin.stations, stations) {
                            guard let x = expected["x"] as? Double, let y = expected["y"] as? Double else { delta = .infinity; break }
                            delta = max(delta, abs(Double(actual.centre.x)-x), abs(Double(actual.centre.y)-y))
                        }
                        delta = max(delta, abs(Double(actualButton.midX + skin.bounds.minX)-button[0]), abs(Double(actualButton.midY + skin.bounds.minY)-button[1]))
                        geometryError = delta
                    }
                    let geometryOK = geometryError.isFinite && geometryError <= 0.001
                    record["geometryAssertion"] = geometryOK ? "pass" : "fail"
                    record["geometryMaxErrorPoints"] = geometryError.isFinite ? geometryError : NSNull()
                    do {
                        let result = try S1PixelReport.make(reference: bytes, image: image, skin: skin, capture: capture)
                        let diffName = String(format: "diff-%02d.png", index)
                        try result.native.write(to: output.appendingPathComponent(nativeName), options: .withoutOverwriting)
                        try result.diff.write(to: output.appendingPathComponent(diffName), options: .withoutOverwriting)
                        written.append(output.appendingPathComponent(nativeName)); written.append(output.appendingPathComponent(diffName))
                        nativeCell = "<img width=\"260\" src=\"\(nativeName)\"><br><img width=\"260\" src=\"\(diffName)\">"
                        record["nativeFile"] = nativeName; record["diffFile"] = diffName
                        record["metric"] = result.similarity; record["metricKind"] = "1 - mean absolute RGB error / 255"
                        record["maskedPercentageGlyphPixels"] = result.maskedPixels; record["inkAssertions"] = result.ink
                        let requiredInk = Set(expectedIDs.filter { $0 == "claude" || $0 == "cursor" })
                        let inkOK = Set(result.ink.keys) == requiredInk && result.ink.values.allSatisfy { $0 } && (requiredInk.isEmpty || result.maskedPixels > 0)
                        status = countOK && geometryOK && inkOK && result.similarity >= 0.97 ? "partial: metric, membership and geometry pass; reset-event content and owner review pending" : "fail: metric, geometry, ink or membership assertion"
                    } catch {
                        try png.write(to: output.appendingPathComponent(nativeName), options: .withoutOverwriting)
                        written.append(output.appendingPathComponent(nativeName))
                        nativeCell = "<img width=\"260\" src=\"\(nativeName)\">"
                        status = "not-run: 2x composition failed: \(String(describing: error))"
                    }
                } else { status = "not-run: production host returned no official raster" }
                host.close()
            }
            record["status"] = status; if record["metric"] == nil { record["metric"] = NSNull() }; records.append(record)
            let metricText = (record["metric"] as? Double).map { String(format: "%.6f", $0) } ?? "not run"
            html += "<tr><td>\(capture.file)</td><td><img width=\"260\" src=\"\(refName)\"></td><td>\(nativeCell)</td><td>\(status)<br>RGB similarity: \(metricText)</td></tr>"
        }
        html += "</table><p>Null metrics are not passes. Metrics exclude only percentage glyph ink, and require geometry and owner review. Button states remain unsupported.</p>"
        try Data(html.utf8).write(to: output.appendingPathComponent("index.html"), options: .withoutOverwriting)
        let result: [String: Any] = ["schemaVersion":1,"prototypeSourceCommit":manifest.prototypeSourceCommit,"results":records]
        try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent("metrics.json"), options: .withoutOverwriting)
        written.append(output.appendingPathComponent("index.html")); written.append(output.appendingPathComponent("metrics.json"))
        let files = written.sorted { $0.lastPathComponent < $1.lastPathComponent }
        var readme = "# S1 synthetic offscreen gallery\n\nReport only; null metrics, reset-event content and unsupported button states are not passes. Reference PNGs are linked in place from the sibling handoff, not copied. Pixel metrics are mean RGB similarity with only coloured percentage glyph boxes excluded. Chromium/CoreGraphics rasterization, synthetic CSS wallpaper, the unconnected reset-event state, and absent synthetic jet animation are platform or implementation differences. README itself is excluded from this list.\n\n| File | Bytes | SHA-256 |\n|---|---:|---|\n"
        for file in files {
            let data = try Data(contentsOf: file), digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            readme += "| \(file.lastPathComponent) | \(data.count) | \(digest) |\n"
        }
        try Data(readme.utf8).write(to: output.appendingPathComponent("README.md"), options: .withoutOverwriting)
    }
}
