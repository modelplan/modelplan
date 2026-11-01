// SPDX-License-Identifier: MIT
import XCTest
import CoreText
@_spi(DockResourceChecks) import ModelPlanDock
@testable @_spi(DockResourceChecks) import ModelPlanDockResources

@MainActor final class DockResourcesTests: XCTestCase {
    private func manifest(_ beta: Bool) throws -> DockResourceManifest {
        try JSONDecoder().decode(DockResourceManifest.self, from: DockThirdPartyResources.manifestData(allowBetaMarks: beta))
    }
    func testOriginalMarkAndFontBytesPassCanonicalValidation() async throws {
        let manifest = try manifest(true)
        let store = try DockArtworkStore(root: DockThirdPartyResources.rootURL(), manifest: manifest)
        XCTAssertEqual(manifest.files.keys.filter { $0.hasPrefix("logo-") }.count, 7)
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
    func testSVGStyleAllowsOnlySingleLocalSolidFill() throws {
        let prefix = #"<svg viewBox="0 0 10 10"><defs><style>"#
        let suffix = #"</style></defs><path class="mark" d="M0 0h10v10z"/></svg>"#
        XCTAssertNoThrow(try DockStaticSVG.size(Data((prefix + ".mark { fill: #edecec; }" + suffix).utf8)))
        for css in ["@import url(https://example.invalid/x);", ".mark { fill: url(https://example.invalid/x); }", ".mark { fill: #fff; stroke: #000; }", ".mark { fill: #fff; } .other { fill: #000; }"] {
            XCTAssertThrowsError(try DockStaticSVG.size(Data((prefix + css + suffix).utf8)))
        }
    }
    func testDefaultPolicyExcludesBetaOnlyZMark() async throws {
        XCTAssertNil(try manifest(false).files["logo-zai-white"])
        XCTAssertNotNil(try manifest(true).files["logo-zai-white"])
        let store = try DockArtworkStore(root: DockThirdPartyResources.rootURL(), manifest: manifest(false))
        XCTAssertThrowsError(try store.checkedURL("logo-zai-white"))
    }
}
