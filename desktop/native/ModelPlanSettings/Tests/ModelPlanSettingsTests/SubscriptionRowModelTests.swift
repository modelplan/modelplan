// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanWire
@testable import ModelPlanSettings

/// D87 slice 5: one row per subscription, merging the engine's consent facts, row state, cause code and visibility.
final class SubscriptionRowModelTests: XCTestCase {
    private func tool(_ id: String, detected: Bool = true, block: ScopeToolBlock? = nil, keychain: Bool = false, readable: Bool = true) -> FirstRunTool {
        FirstRunTool(tool: id, scopes: detected && readable ? [id + ".local_history"] : [], routes: [], block: block, promptsKeychain: keychain, detected: detected)
    }
    private func sub(_ id: String, vendor: String, plan: String = "", source: SubscriptionSourceState = .fresh, cause: String? = nil) -> SettingsSubscription {
        SettingsSubscription(id: id, name: .init(id.capitalized, id.capitalized), plan: plan, vendor: vendor, source: source, causeCode: cause)
    }
    private func build(_ subs: [SettingsSubscription], order: [String], hidden: Set<String> = [], tools: [FirstRunTool],
                       facts: [String: ToolRowFacts] = [:], reading: Set<String> = [], keys: Bool = false) -> SubscriptionRowModel {
        SubscriptionRowModel.build(subscriptions: subs, orderedIDs: order, hiddenIDs: hidden, tools: tools, facts: facts,
                                   isReading: { reading.contains($0) }, keyEntryAvailable: keys,
                                   name: { SettingsText($0.capitalized, $0.capitalized) })
    }

    func testOneRowPerSubscriptionInTheSharedOrderWithHiddenOnesKeepingTheirSlot() {
        let model = build([sub("claude", vendor: "claude", plan: "Max"), sub("codex", vendor: "codex"), sub("kiro", vendor: "kiro")],
                          order: ["codex", "claude", "kiro"], hidden: ["claude"], tools: [])
        XCTAssertEqual(model.added.map(\.id), ["codex", "claude", "kiro"])
        XCTAssertEqual(model.added.map(\.visible), [true, false, true], "visibility is display only")
        XCTAssertEqual(model.added.map(\.canMoveUp), [false, true, true])
        XCTAssertEqual(model.added.map(\.canMoveDown), [true, true, false], "first row cannot go up, last cannot go down")
        XCTAssertEqual(model.added[1].plan, "Max")
        XCTAssertEqual(model.added[0].status, SettingsText("Reading works", "读取正常"))
        XCTAssertFalse(model.added[0].needsAttention)
    }

    func testStatusLineCarriesOneFixActionFromTheSharedTable() throws {
        let model = build([sub("claude", vendor: "claude", source: .unavailable, cause: "keychain_unset"),
                           sub("codex", vendor: "codex", source: .unavailable, cause: "not_found"),
                           sub("zai", vendor: "zai", source: .unavailable, cause: "key_missing"),
                           sub("kiro", vendor: "kiro", source: .unavailable, cause: "not_found"),
                           sub("opencodego", vendor: "opencodego", source: .unavailable, cause: "key_missing")],
                          order: ["claude", "codex", "zai", "kiro", "opencodego"], tools: [], keys: true)
        let targets = model.added.map { $0.fix?.target }
        XCTAssertEqual(targets, [.allowKeychain, .installTool, .addKey, .installTool, .addKey])
        XCTAssertEqual(model.added[1].fix?.action.english, "Open install page", "a hint and the install page, not a path chooser")
        XCTAssertEqual(model.added[1].status.chinese, "安装 Codex CLI，或确认 Codex 在命令行里能运行")
        XCTAssertEqual(model.added[3].fix?.action.english, "Install kiro-cli")
        XCTAssertTrue(model.added.allSatisfy(\.needsAttention))
        // Without the key area the GLM row falls back to opening ZCode.
        let plain = build([sub("zai", vendor: "zai", source: .unavailable, cause: "key_missing")], order: ["zai"], tools: [], keys: false)
        XCTAssertEqual(plain.added[0].fix?.target, .openTool)
    }

    func testEngineRowStateFillsInWhenTheSubscriptionHasNoCause() {
        let facts = ["claude": ToolRowFacts(consent: .allowed, state: .needsKeychain, code: "ok")]
        let model = build([sub("claude", vendor: "claude", source: .unavailable)], order: ["claude"], tools: [], facts: facts)
        XCTAssertEqual(model.added[0].fix?.target, .allowKeychain)
        XCTAssertEqual(model.added[0].consent, .allowed)
        XCTAssertEqual(model.added[0].state, .needsKeychain)
    }

    func testDetectedNotAddedAndNotInstalledSections() {
        let tools = [tool("claude"), tool("codex"), tool("cursor"), tool("grok", block: .notSignedIn, readable: false), tool("gemini", detected: false)]
        let model = build([sub("claude", vendor: "claude")], order: ["claude"], tools: tools, reading: ["codex"])
        XCTAssertEqual(model.detected.map(\.id), ["cursor", "grok"], "a tool already added or already read is not offered again")
        XCTAssertEqual(model.added.map(\.id), ["claude", "codex"], "a tool that reads by default but has no row yet is listed as added")
        XCTAssertEqual(model.added[1].status, SettingsText("Reading…", "正在读取…"))
        XCTAssertTrue(model.added[1].isPending); XCTAssertFalse(model.added[1].canMoveUp); XCTAssertFalse(model.added[1].canMoveDown)
        XCTAssertEqual(model.detected.map(\.canAdd), [true, false], "a signed-out tool cannot be added yet")
        XCTAssertEqual(model.detected[1].fix?.target, .openTool)
        XCTAssertEqual(model.notInstalled.map(\.id), ["gemini"])
        XCTAssertNil(model.notInstalled[0].fix)
        XCTAssertEqual(model.row(forTool: "Claude")?.section, .added)
        XCTAssertEqual(model.row(forTool: "gemini")?.section, .notInstalled)
        XCTAssertNil(model.row(forTool: "nothing"))
    }

    func testFirstRunPrerequisiteLineUsesTheSameTable() {
        func line(_ t: FirstRunTool, _ facts: ToolRowFacts? = nil) -> (SettingsText, Bool) {
            let r = SubscriptionRowModel.prerequisite(tool: t, name: t.tool.capitalized, facts: facts); return (r.text, r.needsAttention)
        }
        XCTAssertEqual(line(tool("codex")).0.english, "Ready: nothing else is needed.")
        XCTAssertEqual(line(tool("claude", keychain: true)).0.english, "A Keychain prompt will appear once; choose Always Allow.")
        XCTAssertFalse(line(tool("claude", keychain: true)).1)
        let missing = line(tool("kiro"), ToolRowFacts(consent: .unset, state: .needsAction, code: "tool_not_found"))
        XCTAssertEqual(missing.0.english, "kiro-cli was not found"); XCTAssertTrue(missing.1)
        let codex = line(tool("codex"), ToolRowFacts(consent: .unset, state: .needsAction, code: "not_found"))
        XCTAssertEqual(codex.0.english, "Install the Codex CLI, or make sure Codex runs from a terminal")
        // Consent and timing codes are first run's own question, not a prerequisite.
        XCTAssertEqual(line(tool("codex"), ToolRowFacts(consent: .unset, state: .needsConsent, code: "consent_required")).0.english, "Ready: nothing else is needed.")
        XCTAssertEqual(line(tool("grok", block: .notSignedIn, readable: false)).0.english, "Not signed in to Grok. Sign in first.")
    }
}
