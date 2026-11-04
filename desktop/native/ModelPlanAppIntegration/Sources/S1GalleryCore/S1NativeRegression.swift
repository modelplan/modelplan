// SPDX-License-Identifier: MIT
import AppKit
import CoreGraphics
import CryptoKit
import Foundation
import ModelPlanSettings
import ModelPlanPrimitives
import ModelPlanOfficialDock
@_spi(DockResourceChecks) import ModelPlanDock
@_spi(DockResourceChecks) import ModelPlanAppIntegration

/// Re-renders the owner-accepted synthetic scenes through the production factory.
@MainActor public enum S1NativeRegression {
    private struct Fixture: Decodable {
        struct Capture: Decodable {
            let file, scenario: String; let size: Int; let edge: String; let count: Int; let theme, state, sha256: String
            let clip: S1Manifest.Clip; let skinBounds: [Double]; let registeredStationCount: Int
            var galleryCapture: S1Manifest.Capture { .init(file: file, scenario: scenario, size: size, edge: edge, count: count, theme: theme, state: state, sha256: sha256, clip: clip) }
        }
        struct Flame: Decodable { let file, sha256: String }
        struct Empty: Decodable { let file, sha256: String; let skinBounds: [Double] }
        let schemaVersion: Int; let sourceCommit, prototypeSourceCommit: String
        let captures: [Capture]; let flamePoses: [Flame]; let emptyCases: [Empty]
    }
    public enum Failure: Error, CustomStringConvertible {
        case fixture(String), appearance(String), geometry(String), pixels(String)
        public var description: String { switch self {
            case .fixture(let v): return "fixture: " + v
            case .appearance(let v): return "appearance: " + v
            case .geometry(let v): return "geometry: " + v
            case .pixels(let v): return "pixels: " + v
        }}
    }
    private static func hash(_ b: Data) -> String { SHA256.hash(data: b).map { String(format: "%02x", $0) }.joined() }
    private static func verified(_ name: String, hash expected: String, root: URL) throws -> Data {
        guard name.range(of: #"^[A-Za-z0-9._-]+\.png$"#, options: .regularExpression) != nil, expected.count == 64 else { throw Failure.fixture("invalid name") }
        let b = try Data(contentsOf: root.appendingPathComponent(name)); guard hash(b) == expected else { throw Failure.fixture(name + " hash") }; return b
    }
    /// Compare every premultiplied sRGB channel. 3/255 mean allows minor OS
    /// rasterization noise; 32/255 for every 16px tile prevents a missing
    /// small control, mark or local material feature from hiding in background.
    private static func compare(_ reference: Data, _ actual: Data, name: String) throws -> (Double, Double) {
        guard let a = NSBitmapImageRep(data: reference)?.cgImage, let b = NSBitmapImageRep(data: actual)?.cgImage,
              a.width == b.width, a.height == b.height, a.width > 0, a.height > 0,
              a.width * a.height <= 8_000_000 else { throw Failure.pixels(name + " dimensions") }
        let w = a.width, h = a.height
        func rgba(_ image: CGImage) throws -> [UInt8] {
            var data = [UInt8](repeating: 0, count: w * h * 4)
            try data.withUnsafeMutableBytes { bytes in
                guard let c = CGContext(data: bytes.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue) else { throw Failure.pixels(name + " bitmap") }
                c.setBlendMode(.copy); c.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            }
            return data
        }
        let x = try rgba(a), y = try rgba(b), columns = (w + 15) / 16, rows = (h + 15) / 16
        var total = 0.0, tiles = [Double](repeating: 0, count: columns * rows), counts = [Int](repeating: 0, count: columns * rows)
        for py in 0..<h { for px in 0..<w {
            let pixel = (py * w + px) * 4, tile = (py / 16) * columns + px / 16
            for channel in 0..<4 { let delta = abs(Int(x[pixel + channel]) - Int(y[pixel + channel])); total += Double(delta); tiles[tile] += Double(delta) }
            counts[tile] += 4
        }}
        let mean = total / Double(w * h * 4), worst = zip(tiles, counts).map { $0 / Double(max(1, $1)) }.max() ?? 0
        guard mean <= 3, worst <= 32 else { throw Failure.pixels("\(name): mean \(mean), worst 16px tile \(worst)") }
        return (mean, worst)
    }
    /// Captures only a synthetic detached default-size empty Dock; never opens a window.
    private static func renderEmpty() async throws -> (Data, [Double]) {
        let now = ISO8601DateFormatter().date(from: "2026-10-20T14:05:00Z")!
        let display = DockDisplayArea(id: "s1-synthetic", frame: .init(x: 0, y: 0, width: 1470, height: 956), visibleFrame: .init(x: 0, y: 0, width: 1470, height: 930))
        let environment = DockEdgeEnvironment(displays: [display], layouts: [], primaryDisplayID: "s1-synthetic")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("s1-empty-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try SettingsStore(url: root.appendingPathComponent("settings.json"))
        try await store.update { $0.dockEdge = .right; $0.size = .medium; $0.dockDisplayID = "s1-synthetic"; $0.dockAlongFraction = 0.5; $0.language = .chinese; $0.autoHide = false }
        let host = ProductionDockFactory.community(createsNativePanels: false, nativeEnvironment: { environment }, currentDate: { now })
        defer { host.close() }; host.captureBackingScaleForChecks = 2; host.dockView.zaiMarkEnabled = true
        host.setDockContentProvider(S1SyntheticProvider(count: 0, now: now))
        let coordinator = SettingsApplicationCoordinator(store: store) { host.apply($0) }; await coordinator.reload(); host.setPresentationAllowed(true)
        guard host.lastAppearanceError == nil, let image = host.dockView.presentedImageForChecks,
              let skin = host.dockView.presentedSkinForChecks, skin.stations.count == 1,
              skin.stations[0].placeholderLabel == "?", skin.stations[0].overflowCount == nil,
              skin.stations[0].placeholderStyle != nil, host.dockView.emptyStationRectForChecks != nil,
              let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { throw Failure.appearance("empty station") }
        return (png, [skin.bounds.minX, skin.bounds.minY, skin.bounds.width, skin.bounds.height].map(Double.init))
    }
    /// Explicit, non-overwriting baseline capture; invoked only by the S1 evidence tool.
    public static func captureEmpty(outputPath: String) async throws {
        _ = NSApplication.shared
        let output = URL(fileURLWithPath: outputPath, isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: false)
        let (image, bounds) = try await renderEmpty()
        try image.write(to: output.appendingPathComponent("native-empty-44-right.png"), options: .withoutOverwriting)
        let data = try JSONSerialization.data(withJSONObject: ["file":"native-empty-44-right.png", "sha256":hash(image), "skinBounds":bounds], options: [.prettyPrinted,.sortedKeys])
        try data.write(to: output.appendingPathComponent("empty.json"), options: .withoutOverwriting)
        print("PASS synthetic empty capture sha256=\(hash(image))")
    }
    public static func run(baselinePath: String) async throws {
        _ = NSApplication.shared
        let root = URL(fileURLWithPath: baselinePath, isDirectory: true)
        let fixtureBytes = try Data(contentsOf: root.appendingPathComponent("fixtures.json"))
        guard hash(fixtureBytes) == "d95ac84ccfca2465cb3d7e635fbb290e59894b7c7106503cfa0ebdc0987da67d" else { throw Failure.fixture("manifest hash") }
        let fixture = try JSONDecoder().decode(Fixture.self, from: fixtureBytes)
        guard fixture.schemaVersion == 1, fixture.sourceCommit == "fc87088f2c3e67d9ab0aefc2f9f90d6c315b6657",
              fixture.prototypeSourceCommit == "69f1b639201f0b9cedd1ad9f109d26423e67e75f",
              fixture.captures.count == 36, fixture.flamePoses.count == 27, fixture.emptyCases.count == 1,
              Set(fixture.captures.map(\.file)).count == 36, Set(fixture.flamePoses.map(\.file)).count == 27 else { throw Failure.fixture("inventory") }
        let expectedScenes = Set(["right", "bottom"].flatMap { edge in [1, 4, 7].flatMap { count in [36, 44, 52].flatMap { size in ["dark", "light"].map { "\(edge)-\(count)-\(size)-\($0)" } } } })
        guard Set(fixture.captures.map { "\($0.edge)-\($0.count)-\($0.size)-\($0.theme)" }) == expectedScenes else { throw Failure.fixture("scene matrix") }
        let now = ISO8601DateFormatter().date(from: "2026-10-20T14:05:00Z")!
        let display = DockDisplayArea(id: "s1-synthetic", frame: .init(x: 0, y: 0, width: 1470, height: 956), visibleFrame: .init(x: 0, y: 0, width: 1470, height: 930))
        let environment = DockEdgeEnvironment(displays: [display], layouts: [], primaryDisplayID: "s1-synthetic")
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("s1-regression-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        var worstMean = 0.0, worstTile = 0.0
        for (index, item) in fixture.captures.enumerated() {
            let reference = try verified(item.file, hash: item.sha256, root: root)
            let store = try SettingsStore(url: tmp.appendingPathComponent("static-\(index).json"))
            try await store.update { $0.dockEdge = item.edge == "bottom" ? .bottom : .right; $0.size = item.size == 36 ? .small : item.size == 52 ? .large : .medium; $0.dockDisplayID = "s1-synthetic"; $0.dockAlongFraction = 0.5; $0.language = .chinese }
            let host = ProductionDockFactory.community(createsNativePanels: false, nativeEnvironment: { environment }, currentDate: { now })
            defer { host.close() }; host.captureBackingScaleForChecks = 2; host.dockView.zaiMarkEnabled = true
            let provider = S1SyntheticProvider(count: item.count, now: now); host.setDockContentProvider(provider)
            let coordinator = SettingsApplicationCoordinator(store: store) { host.apply($0) }; await coordinator.reload()
            guard host.lastAppearanceError == nil, let image = host.dockView.presentedImageForChecks,
                  let skin = host.dockView.presentedSkinForChecks else { throw Failure.appearance(item.file) }
            let ids = Array(["codex", "claude", "zhipu", "cursor", "ocgo", "copilot", "kimi"].prefix(item.count))
            guard skin.stations.compactMap(\.subscriptionID) == ids, skin.stations.count == item.registeredStationCount,
                  item.skinBounds.count == 4 else { throw Failure.geometry(item.file + " station identities") }
            let actualBounds = [skin.bounds.minX, skin.bounds.minY, skin.bounds.width, skin.bounds.height].map(Double.init)
            guard zip(actualBounds, item.skinBounds).allSatisfy({ abs($0 - $1) <= 0.01 }),
                  host.registeredConsoleButtonForChecks != nil else { throw Failure.geometry(item.file + " bounds/control") }
            let report = try S1PixelReport.make(reference: reference, image: image, skin: skin, capture: item.galleryCapture, singleWindowIDs: [])
            let (mean, tile) = try compare(reference, report.native, name: item.file)
            worstMean = max(worstMean, mean); worstTile = max(worstTile, tile)
            print("PASS \(item.file) mean=\(mean) worstTile=\(tile)")
        }
        let empty = fixture.emptyCases[0]
        let emptyReference = try verified(empty.file, hash: empty.sha256, root: root)
        let (emptyImage, emptyBounds) = try await renderEmpty()
        guard empty.skinBounds.count == 4, zip(emptyBounds, empty.skinBounds).allSatisfy({ abs($0 - $1) <= 0.01 }) else { throw Failure.geometry("empty station bounds") }
        let (emptyMean, emptyTile) = try compare(emptyReference, emptyImage, name: empty.file)
        worstMean = max(worstMean, emptyMean); worstTile = max(worstTile, emptyTile)
        print("PASS \(empty.file) mean=\(emptyMean) worstTile=\(emptyTile)")
        let poses = Dictionary(uniqueKeysWithValues: fixture.flamePoses.map { ($0.file, $0.sha256) })
        for (state, status) in [("normal", DockQuotaStatus.normal), ("warning", .warning), ("critical", .critical)] {
            let store = try SettingsStore(url: tmp.appendingPathComponent("flame-\(state).json"))
            try await store.update { $0.dockEdge = .right; $0.size = .large; $0.dockDisplayID = "s1-synthetic"; $0.autoHide = false; $0.motion = .system; $0.showPercentages = false }
            let host = ProductionDockFactory.community(createsNativePanels: false, nativeEnvironment: { environment }, currentDate: { now })
            defer { host.close() }; host.captureBackingScaleForChecks = 2; host.setDockContentProvider(S1FlameComparisonProvider())
            let coordinator = SettingsApplicationCoordinator(store: store) { host.apply($0) }; await coordinator.reload(); host.setPresentationAllowed(true)
            host.installWorkingEffectsForChecks(pool: EffectResourcePool(), provider: try T2FlameFrameProvider.bundled(), systemReduceMotion: { false })
            host.setComparisonStatusForChecks(id: "claude", status: status)
            try host.setWorkingSignals([.init(subscriptionID: "claude", bindingVerified: true, fresh: true, observedOutput: true)])
            guard host.lastAppearanceError == nil, host.activeWorkingEffectIDs.contains("claude"), host.rotatingWorkingEffectIDs.contains("claude"),
                  let reading = host.dockView.presentedReadingsForChecks["claude"], reading.status == status,
                  reading.outer?.fraction == 0.75, reading.inner == nil, reading.vendorResourceKey == "claude", reading.jetEligible,
                  let skin = host.dockView.presentedSkinForChecks, let station = skin.stations.first(where: { $0.subscriptionID == "claude" }),
                  abs(station.diameter - 52) <= 0.001, let layer = host.dockView.layer else { throw Failure.appearance("flame " + state) }
            for pose in 0..<9 {
                let name = "native-working-\(state)-pose\(pose).png"; guard let digest = poses[name] else { throw Failure.fixture(name) }
                let reference = try verified(name, hash: digest, root: root)
                host.seekWorkingEffectsForChecks(Double(pose) / 9 + 0.00001)
                let w = Int(ceil(host.dockView.bounds.width * 2)), h = Int(ceil(host.dockView.bounds.height * 2))
                guard let c = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw Failure.pixels(name + " context") }
                c.translateBy(x: 0, y: CGFloat(h)); c.scaleBy(x: 2, y: -2); host.dockView.displayIfNeeded(); layer.render(in: c)
                let rect = CGRect(x: ((station.centre.x - 26 - skin.bounds.minX) * 2).rounded(), y: ((station.centre.y - 26 - skin.bounds.minY) * 2).rounded(), width: 104, height: 104)
                guard let image = c.makeImage()?.cropping(to: rect), image.width == 104, image.height == 104,
                      let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { throw Failure.pixels(name + " render") }
                let (mean, tile) = try compare(reference, png, name: name)
                worstMean = max(worstMean, mean); worstTile = max(worstTile, tile)
                print("PASS \(name) mean=\(mean) worstTile=\(tile)")
            }
        }
        print("PASS 36 accepted Dock captures, 1 empty station and 27 flame poses; worst mean=\(worstMean)/255, worst tile=\(worstTile)/255")
    }
}
