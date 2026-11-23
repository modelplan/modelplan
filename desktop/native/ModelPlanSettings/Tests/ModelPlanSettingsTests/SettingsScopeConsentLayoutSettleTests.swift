// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanEngineClient
import ModelPlanWire
@testable import ModelPlanSettings

/// The #1137/#1152 merge-queue crash: a wrapping label whose `preferredMaxLayoutWidth` follows a fractional
/// bounds width can oscillate against the D371 rows' width-equal constraints until AppKit raises its
/// layout-loop exception. The width is floored to whole points and applied at most once per label per pass,
/// so a second layout pass at the same width must change nothing.
@MainActor final class SettingsScopeConsentLayoutSettleTests: XCTestCase {
    private func controller() throws -> ScopeConsentController {
        let commands = EngineClientScopeConsentCommands(client: ScopeConsentTestClient(), ready: { true }, makeGrant: { intent in
            try .init(requestId: intent.requestID, expectStoreEpoch: "synthetic", expectGeneration: 1, consentTextVersion: 17, allow: intent.allowIDs, deny: intent.denyIDs)
        })
        let value = ScopeConsentController(commands: commands)
        value.receiveAcceptedFacts(try ScopeConsentFixtures.facts())
        return value
    }
    private func subs() -> [SettingsSubscription] {
        [SettingsSubscription(id: "a", name: .init("Codex", "Codex"), plan: "Pro 100", vendor: "openai", source: .fresh),
         SettingsSubscription(id: "u", name: .init("ZCode / GLM", "ZCode / GLM"), vendor: "glm", source: .fresh, isUnstable: true),
         SettingsSubscription(id: "b", name: .init("Kiro", "Kiri with a long note that wraps at narrow widths", "Kiri with a long note that wraps at narrow widths"), vendor: "kiro", source: .fresh)]
    }
    /// Every text field's frame and preferred width, and the view's own fitting size: anything a second layout
    /// pass could still change shows up here.
    private func fingerprint(_ root: NSView) -> [String] {
        var out = [String(format: "fit %.3f %.3f", root.fittingSize.width, root.fittingSize.height)]
        func walk(_ view: NSView) {
            if let field = view as? NSTextField {
                out.append(String(format: "%@ %.3f %.3f %.3f %.3f m%.3f", view.accessibilityIdentifier() ?? String(field.stringValue.prefix(12)), field.frame.minX, field.frame.minY, field.frame.width, field.frame.height, field.preferredMaxLayoutWidth))
            }
            for sub in view.subviews { walk(sub) }
        }
        walk(root)
        return out
    }

    func testLayoutSettlesAcrossWidths() throws {
        let view = SettingsScopeConsentView(controller: try controller(), language: .chinese, compactTools: true)
        view.setSubscriptionRows(SubscriptionRowsContext(subscriptions: subs(), orderedIDs: ["a", "u", "b"], hiddenIDs: [], canSave: true))
        for width in [CGFloat(760), 640, 521.7, 521.3, 760, 380] {
            view.frame = NSRect(x: 0, y: 0, width: width, height: 1400)
            view.needsLayout = true
            view.layoutSubtreeIfNeeded()
            let settled = fingerprint(view)
            view.needsLayout = true
            view.layoutSubtreeIfNeeded()
            XCTAssertEqual(fingerprint(view), settled, "a second layout pass at width \(width) changes nothing")
        }
    }
}
