// SPDX-License-Identifier: MIT
import XCTest
@testable import ModelPlanField

final class FieldResourcePolicyTests: XCTestCase {
    func testSnapshotRequestBoundsAccountForBackingDensityBeforeAllocation() {
        for scale in [CGFloat(1), 2] {
            for size in [CGSize(width:800,height:500), CGSize(width:500,height:1500)] {
                let width = FieldResourcePolicy.snapshotWidth(width:size.width, height:size.height, backingScale:scale)!
                XCTAssertLessThanOrEqual(CGFloat(width) * scale, 2048)
                XCTAssertLessThanOrEqual(CGFloat(width) * scale * size.height / size.width, 2048)
            }
        }
        XCTAssertNil(FieldResourcePolicy.snapshotWidth(width:1,height:4096,backingScale:2))
        XCTAssertNil(FieldResourcePolicy.snapshotWidth(width:0,height:500,backingScale:2))
    }
    func testOnlyBoundMainEntryCanNavigateAndDownloadsPopupsOrRemoteCannot() throws {
        let generation = UUID()
        let entry = try XCTUnwrap(URL(string:"modelplan-field://bundle/index.html?generation=" + generation.uuidString))
        XCTAssertTrue(FieldResourcePolicy.permitsNavigation(entry, generation:generation, mainFrame:true, download:false))
        XCTAssertFalse(FieldResourcePolicy.permitsNavigation(entry, generation:generation, mainFrame:false, download:false))
        XCTAssertFalse(FieldResourcePolicy.permitsNavigation(entry, generation:generation, mainFrame:true, download:true))
        for text in ["https://example.com", "file:///index.html", "modelplan-field://bundle/index.html",
                     "modelplan-field://bundle/index.html?generation=" + UUID().uuidString,
                     "modelplan-field://bundle:90/index.html?generation=" + generation.uuidString,
                     entry.absoluteString + "&extra=1"] {
            XCTAssertFalse(FieldResourcePolicy.permitsNavigation(try XCTUnwrap(URL(string:text)),
                generation:generation, mainFrame:true, download:false))
        }
    }
    func testCanonicalResourceRootRejectsTraversalAndSymlinkEscape() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let root = base.appendingPathComponent("resources")
        try FileManager.default.createDirectory(at:root, withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:base) }
        let outside = base.appendingPathComponent("outside.js")
        try Data("outside".utf8).write(to:outside)
        try FileManager.default.createSymbolicLink(at:root.appendingPathComponent("escape.js"), withDestinationURL:outside)
        let local = URL(string:"modelplan-field://bundle/index.html")!
        XCTAssertEqual(FieldResourcePolicy.file(for:local, root:root, bridge:nil), root.appendingPathComponent("index.html"))
        for value in ["modelplan-field://bundle/../outside.js", "modelplan-field://bundle/%2e%2e/outside.js",
                      "modelplan-field://bundle/escape.js", "file:///outside.js", "https://example.com/script.js"] {
            XCTAssertNil(FieldResourcePolicy.file(for:URL(string:value)!, root:root, bridge:nil))
        }
        let bridge = base.appendingPathComponent("bridge.mjs")
        XCTAssertEqual(FieldResourcePolicy.file(for:URL(string:"modelplan-field://bundle/field-bridge.mjs")!, root:root, bridge:bridge), bridge)
    }
}
