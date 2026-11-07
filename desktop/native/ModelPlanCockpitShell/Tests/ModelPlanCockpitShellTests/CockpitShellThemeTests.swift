// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanPrimitives
@testable import ModelPlanCockpitShell

/// THM-2.4-08: the shell paints named theme colours, and those are the page's `--metal-2`.
@MainActor final class CockpitShellThemeTests: XCTestCase {
    private var sources: URL { // .../desktop/native/ModelPlanCockpitShell
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }
    private func backdropPixel(dark: Bool) throws -> [UInt8] {
        let skin = NeutralCockpitShellSkin()
        let state = CockpitSurfaceState(profile: .full, closed: false, appearance: .init(dark: dark, scale: 1))
        let image = try skin.backdrop(for: state, layout: skin.layout(for: state), matchingStill: nil)
        // The drawable carries a transparent margin beyond the root, so sample its middle.
        let centre = try XCTUnwrap(image.cropping(to: CGRect(x: image.width / 2, y: image.height / 2, width: 1, height: 1)))
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = try XCTUnwrap(CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(centre, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return Array(pixel.prefix(3))
    }

    func testBackdropPaintsTheThemeTokenInBothThemes() throws {
        XCTAssertEqual(try backdropPixel(dark: true), [0x1c, 0x1d, 0x1f])
        XCTAssertEqual(try backdropPixel(dark: false), [0xb7, 0xbc, 0xc1])
    }

    func testNativeTokensStayInStepWithTheCockpitTheme() throws {
        let theme = sources.deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("cockpit/prototype/prototype-theme.css")
        let text = try String(contentsOf: theme, encoding: .utf8)
        XCTAssertTrue(text.contains("--metal-2:#1c1d1f"))
        XCTAssertTrue(text.contains("--metal-2:#b7bcc1"))
    }

    func testShellSourcesHaveNoInlineColourLiterals() throws {
        let root = sources.appendingPathComponent("Sources")
        let files = try XCTUnwrap(FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil))
        var scanned = 0
        for case let file as URL in files where file.pathExtension == "swift" {
            let text = try String(contentsOf: file, encoding: .utf8)
            scanned += 1
            for banned in ["NSColor(calibratedWhite", "NSColor(white", "NSColor(srgbRed", "NSColor(red", "NSColor(calibratedRed"] {
                XCTAssertFalse(text.contains(banned), "\(file.lastPathComponent) hard-codes \(banned)")
            }
        }
        XCTAssertGreaterThan(scanned, 0)
    }
}
