// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanEngineClient
import ModelPlanWire
@testable import ModelPlanSettings

@MainActor final class SettingsScopeConsentLayoutSettleTests: XCTestCase {
    private func controller() throws -> ScopeConsentController {
        let commands = EngineClientScopeConsentCommands(client: ScopeConsentTestClient(), ready: { true }, makeGrant: { intent in
            try .init(requestId: intent.requestID, expectStoreEpoch: "synthetic", expectGeneration: 1, consentTextVersion: 17, allow: intent.allowIDs, deny: intent.denyIDs)
        })
        let value = ScopeConsentController(commands: commands)
        value.receiveAcceptedFacts(try ScopeConsentFixtures.facts())
        return value
    }

    func testPermissionsNoteWrapsAfterWindowLayout() async throws {
        _ = NSApplication.shared
        let view = SettingsScopeConsentView(controller: try controller(), language: .english, compactTools: true)
        let subscription = SettingsSubscription(id: "a", name: .init("Codex", "Codex"), plan: "Pro 100", vendor: "openai", source: .fresh)
        view.setSubscriptionRows(SubscriptionRowsContext(subscriptions: [subscription], orderedIDs: ["a"], hiddenIDs: [], canSave: true))
        let row = try XCTUnwrap(view.arrangedSubviews.first { $0.accessibilityIdentifier() == "scope.row.permissions" } as? NSStackView)
        let copy = try XCTUnwrap(row.arrangedSubviews.first as? NSStackView)
        let note = try XCTUnwrap(copy.arrangedSubviews.last as? NSTextField)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
                              styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let root = try XCTUnwrap(window.contentView)
        view.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: root.topAnchor),
            view.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: root.trailingAnchor),
        ])

        var wideHeight: CGFloat?
        for width in [CGFloat(900), 480.75, 480.25, 900] {
            let previousWidth = note.preferredMaxLayoutWidth
            window.setContentSize(NSSize(width: width, height: 600))
            root.layoutSubtreeIfNeeded()
            XCTAssertEqual(note.preferredMaxLayoutWidth, previousWidth, "Window layout must not change the preferred width")

            await withCheckedContinuation { continuation in
                DispatchQueue.main.async { continuation.resume() }
            }
            root.layoutSubtreeIfNeeded()
            XCTAssertGreaterThan(note.bounds.width, 0)
            XCTAssertEqual(note.preferredMaxLayoutWidth, floor(note.bounds.width))
            if width == 900 {
                if let wideHeight { XCTAssertEqual(note.bounds.height, wideHeight) }
                else { wideHeight = note.bounds.height }
            } else {
                XCTAssertGreaterThan(note.bounds.height, try XCTUnwrap(wideHeight))
            }
        }
    }
}
