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

    /// macrev2-803-2: the producer's vendor keys are not tool ids (codex -> openai, zai -> glm, opencodego -> opencode).
    /// An added subscription is matched to its tool's facts and never offered again as a detected or pending row.
    func testRealVendorKeysMapToTheirToolIDs() {
        let producer = { (id: String, vendor: String, row: String) in
            SettingsSubscription(id: id, name: .init(id, id), vendor: vendor, source: .unavailable, tool: row)
        }
        let facts = ["codex": ToolRowFacts(consent: .allowed, state: .needsAction, code: "not_found"),
                     "zai": ToolRowFacts(consent: .allowed, state: .needsAction, code: "key_missing")]
        let tools = [tool("codex"), tool("zai"), tool("opencodego")]
        for subs in [[producer("codex-1", "openai", "codex"), producer("zai-1", "glm", "zai"), producer("go-1", "opencode", "opencodego")],
                     // No row id given: the vendor key alone still resolves through the producer's fixed table.
                     [producer("codex-1", "openai", ""), producer("zai-1", "glm", ""), producer("go-1", "opencode", "")]] {
            let model = build(subs, order: ["codex-1", "zai-1", "go-1"], tools: tools, facts: facts, reading: ["codex", "zai", "opencodego"], keys: true)
            XCTAssertEqual(model.added.map(\.id), ["codex-1", "zai-1", "go-1"], "no second pending row for an added tool")
            XCTAssertEqual(model.added.map(\.tool), ["codex", "zai", "opencodego"])
            XCTAssertTrue(model.detected.isEmpty)
            XCTAssertEqual(model.added[0].fix?.target, ReaderCauseTable.rowEntry(code: "not_found", tool: "codex")?.target, "codex facts are found by tool id")
            XCTAssertEqual(model.added[1].fix?.target, .addKey, "zai facts are found by tool id")
            XCTAssertEqual(model.row(forTool: "openai")?.id, "codex-1")
            XCTAssertEqual(model.row(forTool: "zai")?.id, "zai-1")
        }
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

/// The Settings rows keep their own fix table; the card table (`ReaderCauseTable.entry`) stays guidance-only.
final class RowFixTableTests: XCTestCase {
    func testRowsKeepWiredFixesWhileTheCardTableStaysGuidanceOnly() throws {
        XCTAssertEqual(ReaderCauseTable.rowEntry(code: "runtime_missing")?.target, .installNode)
        XCTAssertEqual(ReaderCauseTable.rowEntry(code: "timeout")?.target, .retry)
        XCTAssertEqual(ReaderCauseTable.rowEntry(code: "keychain_unset")?.target, .allowKeychain)
        XCTAssertEqual(ReaderCauseTable.rowEntry(code: "key_missing", tool: "zai", keyEntryAvailable: true)?.target, .addKey)
        XCTAssertEqual(ReaderCauseTable.rowEntry(code: "key_missing", tool: "zai")?.target, .openTool)
        XCTAssertNil(ReaderCauseTable.rowEntry(code: "surprise"))
        XCTAssertEqual(try XCTUnwrap(ReaderCauseTable.entry(code: "runtime_missing")).target, .guidance)
    }
}
