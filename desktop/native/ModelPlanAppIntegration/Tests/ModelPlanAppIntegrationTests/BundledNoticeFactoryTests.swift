// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@testable import ModelPlanSettings
@testable import ModelPlanAppIntegration

@MainActor final class BundledNoticeFactoryTests: XCTestCase {
    private final class Clipboard: SettingsDiagnosticClipboard {
        var text: String?
        func writeDiagnostics(_ text: String) -> Bool { self.text = text; return true }
    }
    private func bundle() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("bundled-notices-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let app = root.appendingPathComponent("Synthetic.app"), resources = app.appendingPathComponent("Contents/Resources")
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        let info: [String: Any] = ["CFBundleShortVersionString": "1.2.3+synthetic-build", "CFBundleVersion": "1"]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: app.appendingPathComponent("Contents/Info.plist"))
        try Data("MIT SYNTHETIC NOTICE".utf8).write(to: resources.appendingPathComponent("LICENSE.txt"))
        try Data("CLI DEPENDENCY SYNTHETIC NOTICE".utf8).write(to: resources.appendingPathComponent("CLI-THIRD-PARTY-NOTICES.md"))
        return app
    }
    private func context(_ bundle: URL) -> SettingsPageContext {
        CommunityApplicationFactory.makeSettingsContext(bundle: bundle, availability: .unverified,
            operatingSystem: .init(majorVersion: 15, minorVersion: 0, patchVersion: 0))
    }
    private func text(_ context: SettingsPageContext) throws -> (SettingsLicenseView, NSTextView) {
        _ = NSApplication.shared
        let view = SettingsLicenseView(frame: .zero)
        view.apply(context.licenseNotices, language: .english)
        let text = try XCTUnwrap(view.documentView as? NSTextView)
        XCTAssertFalse(text.isEditable); XCTAssertTrue(text.isSelectable)
        XCTAssertFalse(text.isAutomaticLinkDetectionEnabled); XCTAssertNil(view.window)
        return (view, text)
    }
    func testActualFactoryPopulatesTheRealSelectableLicenseViewWithoutClipboardLeakage() throws {
        let app = try bundle(), value = context(app)
        XCTAssertEqual(value.licenseNotices.count, 2)
        let (_, view) = try text(value)
        XCTAssertTrue(view.string.contains("MIT SYNTHETIC NOTICE"))
        XCTAssertTrue(view.string.contains("CLI DEPENDENCY SYNTHETIC NOTICE"))
        let clipboard = Clipboard()
        XCTAssertTrue(SettingsDiagnosticCopy.copy(value.about, to: clipboard))
        let copied = try XCTUnwrap(clipboard.text)
        XCTAssertTrue(copied.contains("app=1.2.3")); XCTAssertTrue(copied.contains("macOS=15.0.0"))
        for excluded in ["SYNTHETIC NOTICE", "synthetic-build", app.path] { XCTAssertFalse(copied.contains(excluded)) }
    }
    func testMissingRequiredNoticeShowsOneHumanRecoveryInsteadOfPartialLegalText() throws {
        let app = try bundle()
        try FileManager.default.removeItem(at: app.appendingPathComponent("Contents/Resources/CLI-THIRD-PARTY-NOTICES.md"))
        let value = context(app); XCTAssertTrue(value.licenseNotices.isEmpty)
        let (_, view) = try text(value)
        XCTAssertTrue(view.string.contains("Reinstall ModelPlan"))
        XCTAssertFalse(view.string.contains("MIT SYNTHETIC NOTICE"))
    }
    func testEscapingSymlinkOversizeAndMalformedNoticeDoNotEnterTheView() throws {
        for kind in ["symlink", "oversize", "malformed"] {
            let app = try bundle(), file = app.appendingPathComponent("Contents/Resources/CLI-THIRD-PARTY-NOTICES.md")
            try FileManager.default.removeItem(at: file)
            switch kind {
            case "symlink":
                let outside = app.deletingLastPathComponent().appendingPathComponent("outside.txt")
                try Data("OUTSIDE SENTINEL".utf8).write(to: outside)
                try FileManager.default.createSymbolicLink(at: file, withDestinationURL: outside)
            case "oversize": try Data(repeating: 65, count: 1_048_577).write(to: file)
            default: try Data([0xff, 0xfe]).write(to: file)
            }
            let value = context(app); XCTAssertTrue(value.licenseNotices.isEmpty)
            let (_, view) = try text(value)
            XCTAssertFalse(view.string.contains("OUTSIDE SENTINEL"))
        }
    }
    func testReservedVisualNoticeIsLabelledSeparatelyFromTheOpenSourceGrant() throws {
        let app = try bundle()
        try Data("RESERVED VISUAL NOTICE".utf8).write(to: app.appendingPathComponent("Contents/Resources/VISUAL-LICENSE.md"))
        let value = context(app)
        XCTAssertEqual(value.licenseNotices.count, 3)
        let visual = try XCTUnwrap(value.licenseNotices.last)
        XCTAssertEqual(visual.component, "Official visuals")
        XCTAssertEqual(visual.license, "ModelPlan Official Visuals License 1.0")
        XCTAssertNotEqual(visual.license, "MIT")
        let (_, view) = try text(value)
        XCTAssertTrue(view.string.contains("RESERVED VISUAL NOTICE"))
    }

}
