// SPDX-License-Identifier: MIT
import XCTest
import CoreText
import CryptoKit
@_spi(DockResourceChecks) import ModelPlanDock
@testable @_spi(DockResourceChecks) import ModelPlanDockResources

@MainActor final class DockResourcesTests: XCTestCase {
    private func manifest(_ beta: Bool) throws -> DockResourceManifest {
        try JSONDecoder().decode(DockResourceManifest.self, from: DockThirdPartyResources.manifestData(zaiMarkEnabled: beta))
    }
    /// DOCK-3.2-04: every mark reads at 3:1 or better against the nozzle's dark centre.
    func testEveryMarkReadsAtThreeToOneOnTheDarkCentre() throws {
        func linear(_ value: Double) -> Double { value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4) }
        func luminance(_ r: Double, _ g: Double, _ b: Double) -> Double { 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b) }
        let centre = luminance(5.0 / 255, 6.0 / 255, 8.0 / 255)
        let value = try manifest(false), store = try DockArtworkStore(root: DockThirdPartyResources.rootURL(), manifest: value)
        let marks = value.files.keys.filter { $0.hasPrefix("logo-") }.sorted()
        XCTAssertGreaterThan(marks.count, 10)
        for id in marks {
            let image = try store.image(id, maximumPixelSize: 96)
            let context = try XCTUnwrap(CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            let bytes = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
            var total = 0.0, count = 0.0
            for at in stride(from: 0, to: image.width * image.height * 4, by: 4) where bytes[at + 3] > 200 {
                let alpha = Double(bytes[at + 3])
                total += luminance(Double(bytes[at]) / alpha, Double(bytes[at + 1]) / alpha, Double(bytes[at + 2]) / alpha); count += 1
            }
            XCTAssertGreaterThan(count, 0, id)
            XCTAssertGreaterThanOrEqual((total / max(count, 1) + 0.05) / (centre + 0.05), 3, id)
        }
    }

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
            try Data("{}".utf8).write(to: resourceRoot.appendingPathComponent("manifest.json"))
            let bundle = try XCTUnwrap(Bundle(url: bundleURL))
            XCTAssertEqual(try DockThirdPartyResources.rootURL(in: bundle).standardizedFileURL.resolvingSymlinksInPath(), resourceRoot.standardizedFileURL.resolvingSymlinksInPath())
        }
    }
    func testOriginalMarkAndFontBytesPassCanonicalValidation() async throws {
        let manifest = try manifest(true)
        let store = try DockArtworkStore(root: DockThirdPartyResources.rootURL(), manifest: manifest)
        XCTAssertEqual(manifest.files.keys.filter { $0.hasPrefix("logo-") }.count, 19)
        for key in manifest.files.keys { _ = try store.checkedURL(key) }
        for key in manifest.files.keys where key.hasPrefix("logo-") {
            let image = try store.image(key, maximumPixelSize: 64)
            XCTAssertGreaterThan(image.width, 0); XCTAssertGreaterThan(image.height, 0)
        }
        for key in ["font-jetbrains-mono", "font-dm-sans"] {
            let font = try store.font(key, size: 11, weight: 400)
            XCTAssertFalse((CTFontCopyPostScriptName(font) as String).isEmpty)
            XCTAssertEqual(CTFontGetSize(font), 11)
        }
    }
    func testEveryVendorMarkFillsTheSameVisibleDockBox() throws {
        let root = try DockThirdPartyResources.rootURL(), manifest = try manifest(true)
        let markFiles = try FileManager.default.contentsOfDirectory(at: root.appendingPathComponent("Marks"), includingPropertiesForKeys: nil)
            .filter { $0.pathExtension.lowercased() == "svg" }.map(\.lastPathComponent)
        let records = manifest.files.filter { $0.value.path.hasPrefix("Marks/") && $0.value.path.hasSuffix(".svg") }
        XCTAssertEqual(Set(markFiles), Set(records.values.map { URL(fileURLWithPath: $0.path).lastPathComponent }))
        let store = try DockArtworkStore(root: root, manifest: manifest)
        let target = 28
        for id in records.keys.sorted() {
            let image = try store.fittedGlyph(id, targetPixelSize: target)
            let context = try XCTUnwrap(CGContext(data: nil, width: target, height: target, bitsPerComponent: 8, bytesPerRow: target * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue))
            context.clear(CGRect(x: 0, y: 0, width: target, height: target)); context.interpolationQuality = .none
            let factor = min(CGFloat(target) / CGFloat(image.width), CGFloat(target) / CGFloat(image.height))
            let width = CGFloat(image.width) * factor, height = CGFloat(image.height) * factor
            context.draw(image, in: CGRect(x: (CGFloat(target)-width)/2, y: (CGFloat(target)-height)/2, width: width, height: height))
            let bytes = try XCTUnwrap(context.data?.assumingMemoryBound(to: UInt8.self))
            var minX = target, minY = target, maxX = -1, maxY = -1
            for y in 0..<target { for x in 0..<target where bytes[(y * target + x) * 4 + 3] > 0 {
                minX = min(minX, x); minY = min(minY, y); maxX = max(maxX, x); maxY = max(maxY, y)
            }}
            XCTAssertGreaterThanOrEqual(maxX, minX, id); XCTAssertGreaterThanOrEqual(maxY, minY, id)
            let visibleExtent = max(maxX-minX+1, maxY-minY+1)
            XCTAssertEqual(Double(visibleExtent), Double(target), accuracy: Double(target)*0.06, "Visible extent for \(id)")
        }
    }
    func testVisibleFitKeepsAnAsymmetricOffCenterGlyph() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let data = Data(##"<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><rect x="0" y="0" width="20" height="10" fill="#ffffff"/></svg>"##.utf8)
        try data.write(to: root.appendingPathComponent("sample.svg"))
        let sha = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let store = try DockArtworkStore(root: root, manifest: .init(files: ["sample": .init(path: "sample.svg", sha256: sha, bytes: data.count)]))
        let image = try store.fittedGlyph("sample", targetPixelSize: 28)
        XCTAssertEqual(Double(image.width), 28, accuracy: 2); XCTAssertEqual(Double(image.height), 14, accuracy: 2)
    }
    func testSVGStyleAllowsOnlySingleLocalSolidFill() throws {
        let prefix = #"<svg viewBox="0 0 10 10"><defs><style>"#
        let suffix = #"</style></defs><path class="mark" d="M0 0h10v10z"/></svg>"#
        XCTAssertNoThrow(try DockStaticSVG.size(Data((prefix + ".mark { fill: #edecec; }" + suffix).utf8)))
        for css in ["@import url(https://example.invalid/x);", ".mark { fill: url(https://example.invalid/x); }", ".mark { fill: #fff; stroke: #000; }", ".mark { fill: #fff; } .other { fill: #000; }"] {
            XCTAssertThrowsError(try DockStaticSVG.size(Data((prefix + css + suffix).utf8)))
        }
    }
    func testVariableMonoUsesExplicitRegularWeight() throws {
        let store = try DockArtworkStore(root: DockThirdPartyResources.rootURL(), manifest: manifest(false))
        let font = try store.font("font-jetbrains-mono", size: 11, weight: 400)
        let graphics = CTFontCopyGraphicsFont(font, nil)
        let axes = try XCTUnwrap(graphics.variationAxes as? [[CFString: Any]])
        XCTAssertEqual(axes.count, 1)
        let axisName = try XCTUnwrap(axes.first?[CGFont.variationAxisName] as? String)
        let values = try XCTUnwrap(graphics.variations as? [String: NSNumber])
        XCTAssertEqual(try XCTUnwrap(values[axisName]).doubleValue, 400, accuracy: 0.001)
    }

    func testDefaultPolicyExcludesBetaOnlyZMark() async throws {
        XCTAssertNil(try manifest(false).files["logo-zai-white"])
        XCTAssertNotNil(try manifest(true).files["logo-zai-white"])
        let store = try DockArtworkStore(root: DockThirdPartyResources.rootURL(), manifest: manifest(false))
        XCTAssertThrowsError(try store.checkedURL("logo-zai-white"))
    }
}
