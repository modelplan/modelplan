// SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0
import XCTest
import ImageIO
@testable import ModelPlanOfficialDock

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
}
