// SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0
import XCTest
import ImageIO
@testable import ModelPlanOfficialDock
import CoreGraphics
import ModelPlanDock

final class T2ResourceTests: XCTestCase {
    func testResourceLookupSupportsFlatAndNestedBundleLayouts() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("resource-layout-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        for nested in [false, true] {
            let bundleURL = root.appendingPathComponent(nested ? "nested.bundle" : "flat.bundle")
            let resourceBase = bundleURL.appendingPathComponent("Contents/Resources")
            let resourceRoot = nested ? resourceBase.appendingPathComponent("Resources") : resourceBase
            try FileManager.default.createDirectory(at: resourceRoot, withIntermediateDirectories: true)
            let info = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\"><plist version=\"1.0\"><dict><key>CFBundleIdentifier</key><string>test.synthetic.resource-layout</string><key>CFBundlePackageType</key><string>BNDL</string></dict></plist>"
            try Data(info.utf8).write(to: bundleURL.appendingPathComponent("Contents/Info.plist"))
            try Data("{}".utf8).write(to: resourceRoot.appendingPathComponent("artwork.json"))
            let bundle = try XCTUnwrap(Bundle(url: bundleURL))
            XCTAssertEqual(try T2BundledArtwork.rootURL(in: bundle).standardizedFileURL.resolvingSymlinksInPath(), resourceRoot.standardizedFileURL.resolvingSymlinksInPath())
        }
    }
    func testAcceptedOriginalLayersAreBundledHashVerifiedAndDecodable() throws {
        let records = try T2BundledArtwork.records()
        XCTAssertEqual(records.count, 21)
        XCTAssertEqual(records.keys.filter { $0.hasSuffix(".webp") }.count, 16)
        XCTAssertEqual(records.keys.filter { $0.hasSuffix(".png") }.count, 5)
        for (name, record) in records {
            let data = try T2BundledArtwork.data(name)
            XCTAssertEqual(data.count, record.bytes)
            let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
            let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
            XCTAssertGreaterThan(image.width, 0); XCTAssertGreaterThan(image.height, 0)
        }
    }
    func testUnknownResourceCannotBecomeAnUnverifiedPath() {
        XCTAssertThrowsError(try T2BundledArtwork.data("../unregistered.png"))
        XCTAssertThrowsError(try T2BundledArtwork.data("missing.png"))
    }

    /// Repository directories above this test file: Tests, dock, official-visuals, desktop.
    private func up(_ levels: Int) -> URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<levels { url.deleteLastPathComponent() }
        return url
    }

    /// DOCK-3.1-24: the ignition is the approved A5 art, unrecoloured and unfiltered. The skin names only the five
    /// registered files, carries only the two registered shadow opacities, the cap is the night cap at every
    /// size and for light and dark wallpaper alike, and the bundled bytes equal the canonical exports.
    func testIgnitionArtIsUnrecolouredAndNightCapOnly() throws {
        let records = try T2BundledArtwork.records()
        let canonical = up(3).appendingPathComponent("runtime/ignition-a5")
        for diameter in [CGFloat(36), 44, 52] {
            let geometry = try T2Geometry.make(subscriptions: [.init(id: "member-a")], input: .init(coordinates: .init(edge: .right, width: 1470, height: 956, menuBarExclusion: 26), diameter: diameter))
            let skin = try T2DockSkin.make(geometry: geometry, rows: [], showsPercentages: true)
            XCTAssertEqual(skin.fixedLayers.map(\.resource), ["a5-outer-contact-shadow-56x56@3x.png", "a5-cap-night-idle-44x44@3x.png", "a5-inner-contact-shadow-52x52@3x.png", "a5-recessed-guard-52x52@3x.png"])
            XCTAssertEqual(skin.fixedLayers.map(\.opacity), [0.30, nil, 0.33, nil], "no layer carries any other opacity")
            for layer in skin.fixedLayers {
                XCTAssertNotNil(records[layer.resource], "\(layer.resource) is registered")
                XCTAssertFalse(layer.resource.contains("day"), "the cap is the night cap on light wallpaper too")
            }
        }
        XCTAssertEqual(records.keys.filter { $0.hasPrefix("a5-cap") }.sorted(), ["a5-cap-night-idle-44x44@3x.png", "a5-cap-night-pressed-44x44@3x.png"])
        for name in records.keys.filter({ $0.hasPrefix("a5-") }) {
            let original = try Data(contentsOf: canonical.appendingPathComponent(name))
            XCTAssertEqual(try T2BundledArtwork.data(name), original, "\(name) is byte-identical to runtime/ignition-a5")
        }
    }

    private struct MarkManifest: Decodable { struct File: Decodable { let path: String }; let files: [String: File] }

    /// The colours (as saturation 0...1) of every hex literal in a vendor mark's SVG.
    private func saturations(ofMark key: String) throws -> (colours: [CGFloat], text: String) {
        let resources = up(4).appendingPathComponent("third-party/dock-resources/Resources")
        let manifest = try JSONDecoder().decode(MarkManifest.self, from: Data(contentsOf: resources.appendingPathComponent("manifest.json")))
        let path = try XCTUnwrap(manifest.files[key]?.path, key)
        let text = try String(contentsOf: resources.appendingPathComponent(path), encoding: .utf8)
        let matches = try NSRegularExpression(pattern: "#([0-9a-fA-F]{6})\\b").matches(in: text, range: NSRange(text.startIndex..., in: text))
        let colours = matches.map { match -> CGFloat in
            let hex = UInt32((text as NSString).substring(with: match.range(at: 1)), radix: 16)!
            let r = CGFloat((hex >> 16) & 0xff), g = CGFloat((hex >> 8) & 0xff), b = CGFloat(hex & 0xff)
            let high = max(r, g, b), low = min(r, g, b)
            return high == 0 ? 0 : (high - low) / high
        }
        return (colours, text)
    }

    /// DOCK-3.2-08: Google (Gemini), Alibaba/Qwen and MiniMax keep their brand colour; Cursor, Copilot and
    /// OpenCode stay monochrome. The skin maps each vendor to its own mark.
    func testColourMarksForGoogleQwenMiniMax() throws {
        for key in ["logo-gemini", "logo-qwen", "logo-minimax"] {
            let mark = try saturations(ofMark: key)
            XCTAssertGreaterThan(mark.colours.max() ?? 0, 0.25, "\(key) carries a brand colour")
        }
        for key in ["logo-cursor", "logo-copilot", "logo-opencode"] {
            let mark = try saturations(ofMark: key)
            XCTAssertLessThan(mark.colours.max() ?? 0, 0.1, "\(key) stays monochrome")
        }
        let geometry = try T2Geometry.make(subscriptions: [.init(id: "member-a")], input: .init(coordinates: .init(edge: .right, width: 1470, height: 956, menuBarExclusion: 26), diameter: 44))
        let glyphs = try XCTUnwrap(T2DockSkin.make(geometry: geometry, rows: [], showsPercentages: true).stations.first).glyphs
        XCTAssertEqual(glyphs["gemini"], "logo-gemini"); XCTAssertEqual(glyphs["qwen"], "logo-qwen"); XCTAssertEqual(glyphs["minimax"], "logo-minimax")
    }
}
