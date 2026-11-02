// SPDX-License-Identifier: MIT
import AppKit
import XCTest
@testable import ModelPlanSettings

/// Hosted-only: constructs an offscreen AppKit window; never run on the no-GUI local lane.
@MainActor final class FirstRunAdaptiveLayoutTests: XCTestCase {
    private func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }

    func testFirstRunWidthsScrollAndScopeFocusInBothLanguages() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("first-run-layout-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let store = try SettingsStore(url: root.appendingPathComponent("settings.json"))
        let editor = SettingsEditor(store: store)
        let entry = ScopeConsentEntry(client: ScopeConsentTestClient(), ready: { true }, language: .english)
        entry.acceptedFacts(try ScopeConsentFixtures.facts())
        let controller = SettingsFirstRunController(editor: editor, scopeConsentEntry: entry)
        await controller.prepare()
        let window = try XCTUnwrap(controller.window)
        let rootView = try XCTUnwrap(window.contentView)
        let scroll = try XCTUnwrap(descendants(rootView).first { $0.accessibilityIdentifier() == "firstRun.scroll" } as? NSScrollView)
        let stack = try XCTUnwrap(descendants(rootView).first { $0.accessibilityIdentifier() == "firstRun.content" } as? NSStackView)
        for language in [SettingsLanguage.english, .chinese] {
            _ = try await store.update { $0.language = language }; await editor.reload()
            for size in [NSSize(width: 480, height: 360), NSSize(width: 980, height: 720), NSSize(width: 1400, height: 900)] {
                window.setContentSize(size); rootView.layoutSubtreeIfNeeded()
                XCTAssertFalse(scroll.hasHorizontalScroller)
                XCTAssertLessThanOrEqual(stack.frame.width, scroll.contentView.bounds.width - 2 * FirstRunLayoutMetrics.horizontalInset + 1)
                XCTAssertLessThanOrEqual(stack.frame.width, FirstRunLayoutMetrics.preferredWidth + 1)
                XCTAssertGreaterThanOrEqual(try XCTUnwrap(scroll.documentView).frame.height + 1, stack.frame.maxY)
                let title = try XCTUnwrap(descendants(stack).first { $0.accessibilityIdentifier() == "firstRun.title" } as? NSTextField)
                XCTAssertEqual(title.stringValue, language == .english ? "Set up ModelPlan" : "设置 ModelPlan")
                XCTAssertTrue(title.cell?.wraps == true)
                rootView.layoutSubtreeIfNeeded()
                let currentScope = try XCTUnwrap(descendants(stack).first { $0.accessibilityIdentifier() == "settings.scopeConsent" } as? NSStackView)
                for button in currentScope.arrangedSubviews.compactMap({ $0 as? NSButton }) {
                    XCTAssertLessThanOrEqual(button.frame.width, currentScope.bounds.width + 1)
                    let required = button.cell?.cellSize(forBounds: NSRect(x: 0, y: 0, width: max(1, button.frame.width), height: 10_000)).height ?? 0
                    XCTAssertGreaterThanOrEqual(button.frame.height + 1, required, "Localized scope action must not be vertically clipped")
                }
            }
            let scope = try XCTUnwrap(descendants(stack).first { $0.accessibilityIdentifier() == "settings.scopeConsent" } as? NSStackView)
            let buttons = scope.arrangedSubviews.compactMap { $0 as? NSButton }
            XCTAssertFalse(buttons.isEmpty)
            for (first, second) in zip(buttons, buttons.dropFirst()) { XCTAssertTrue(first.nextKeyView === second) }
            XCTAssertTrue(buttons.last?.nextKeyView === controller.loginButton)
        }
        controller.suspend(); controller.close()
    }
}
