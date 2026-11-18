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
        XCTAssertEqual(model.added[1].status.chinese, "找不到 Codex 命令")
        XCTAssertEqual(model.added[3].fix?.action.english, "Install kiro-cli")
        XCTAssertTrue(model.added.allSatisfy(\.needsAttention))
        // Without the key area the GLM row falls back to opening ZCode.
        let plain = build([sub("zai", vendor: "zai", source: .unavailable, cause: "key_missing")], order: ["zai"], tools: [], keys: false)
        XCTAssertEqual(plain.added[0].fix?.target, .openTool)
    }

    /// WP-16 / SET-9-51: the Subscriptions page has the three sections (added, detected, supported-not-installed),
    /// and an unreadable cause is the card's sentence from ReaderCauseTable (region_refused is worded identically in both tables).
    func testWP16ThreeSectionsAndSharedCauseSentence() {
        let model = build([sub("claude", vendor: "claude", source: .unavailable, cause: "region_refused")],
                          order: ["claude"], tools: [tool("cursor"), tool("kiro", detected: false)])
        XCTAssertEqual(model.added.map(\.id), ["claude"])
        XCTAssertEqual(model.detected.map(\.id), ["cursor"])
        XCTAssertEqual(model.notInstalled.map(\.id), ["kiro"])
        XCTAssertEqual(model.added[0].status, ReaderCauseTable.entry(code: "region_refused", tool: "claude")?.reason)
    }

    /// WP-16 / SET-9-51: for every cause the card knows, the Settings row text is the card's sentence (one table entry per cause).
    func testWP16RowReasonEqualsCardReasonForEveryCause() throws {
        let codes = ["not_found", "runtime_missing", "timeout", "rpc_error", "closed", "not_signed_in", "login_expired",
                     "keychain_unset", "keychain_denied", "key_missing", "region_refused", "no_plan", "usage_not_reported", "consent_required"]
        for tool in ["claude", "codex", "zai", "opencodego", "kiro"] {
            for keys in [false, true] {
                for code in codes {
                    let card = try XCTUnwrap(ReaderCauseTable.entry(code: code, tool: tool, toolName: tool.capitalized), code)
                    let row = try XCTUnwrap(ReaderCauseTable.rowEntry(code: code, tool: tool, toolName: tool.capitalized, keyEntryAvailable: keys), code)
                    XCTAssertEqual(row.reason, card.reason, "\(tool) \(code) keys=\(keys)")
                }
            }
        }
    }

    /// WP-16 / SET-9-52, SET-9-53: size options in the owner's order, red line 25 by default, show-all-models off.
    func testWP16CockpitSizeOrderAndRedLineDefault() throws {
        XCTAssertEqual(SettingsCockpitSize.allCases.map(\.rawValue), ["automatic", "100", "90", "85", "80"])
        let p = try JSONDecoder().decode(SettingsPreferences.self, from: Data("{}".utf8))
        XCTAssertEqual(p.redBelow, 25); XCTAssertEqual(p.effectiveRedBelow, 25)
        XCTAssertFalse(p.showAllModels); XCTAssertEqual(p.cockpitSize, .automatic)
    }

    func testEngineRowStateFillsInWhenTheSubscriptionHasNoCause() {
        let facts = ["claude": ToolRowFacts(consent: .allowed, state: .needsKeychain, code: "ok")]
        let model = build([sub("claude", vendor: "claude", source: .unavailable)], order: ["claude"], tools: [], facts: facts)
        XCTAssertEqual(model.added[0].fix?.target, .allowKeychain)
        XCTAssertEqual(model.added[0].consent, .allowed)
        XCTAssertEqual(model.added[0].state, .needsKeychain)
    }

    /// SET-9-34 (DESIGN 95a7e3b8): a stale subscription shows its stale status, not a tool-level cause or state of the tool.
    /// Fails on the previous model, which let the stale row inherit the tool's key_missing / needs-keychain facts.
    func testStaleSubscriptionKeepsItsStaleStatusInsteadOfAToolLevelCause() {
        let facts = ["zai": ToolRowFacts(consent: .allowed, state: .needsKeychain, code: "key_missing")]
        let model = build([sub("zai", vendor: "zai", source: .stale)], order: ["zai"], tools: [], facts: facts, keys: true)
        XCTAssertEqual(model.added[0].status, SettingsText("The last reading is old", "上次读数已过期"))
        XCTAssertNil(model.added[0].fix)
        XCTAssertFalse(model.added[0].needsAttention)
        // Its own cause still wins over staleness.
        let own = build([sub("zai", vendor: "zai", source: .stale, cause: "timeout")], order: ["zai"], tools: [], facts: facts, keys: true)
        XCTAssertEqual(own.added[0].fix?.target, .retry)
    }

    /// SET-9-41 (DESIGN 95a7e3b8): a third-party relay cause still offers Add key on a key-only provider's row.
    func testRelayCauseOffersAddKeyWhenTheKeyEntryExists() {
        let withKeys = build([sub("zai", vendor: "zai", source: .unavailable, cause: "region_refused")], order: ["zai"], tools: [], keys: true)
        XCTAssertEqual(withKeys.added[0].fix?.target, .addKey)
        XCTAssertEqual(withKeys.added[0].status.english, "This address is a third-party relay, so its quota can't be read")
        let without = build([sub("zai", vendor: "zai", source: .unavailable, cause: "region_refused")], order: ["zai"], tools: [], keys: false)
        XCTAssertEqual(without.added[0].fix?.target, .explain, "no key area: the plain explanation stays")
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
        XCTAssertEqual(missing.0.english, "Can't find the Kiro command"); XCTAssertTrue(missing.1)
        let codex = line(tool("codex"), ToolRowFacts(consent: .unset, state: .needsAction, code: "not_found"))
        XCTAssertEqual(codex.0.english, "Can't find the Codex command")
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

    func testEveryFixedReaderFailureHasAReasonAndFix() throws {
        let codes = ["file_missing", "file_unreadable", "parse_error", "schema_changed", "http_401", "http_403",
                     "http_429", "http_5xx", "network", "timeout", "runtime_missing", "unsupported_login",
                     "not_signed_in", "not_found", "rpc_error", "closed", "no_key", "region_refused",
                     "codex_custom_provider", "team_unsupported", "no_plan", "other"]

        for code in codes {
            let fix = try XCTUnwrap(ReaderCauseTable.rowEntry(code: code, tool: "codex", toolName: "Codex"), code)
            XCTAssertFalse(fix.reason.english.isEmpty, code)
            XCTAssertFalse(fix.reason.chinese.isEmpty, code)
            XCTAssertFalse(fix.action.english.isEmpty, code)
            XCTAssertFalse(fix.action.chinese.isEmpty, code)
        }
        let runtime = try XCTUnwrap(ReaderCauseTable.rowEntry(code: "runtime_missing", tool: "codex"))
        XCTAssertFalse(runtime.reason.chinese.contains("Node.js"))
        XCTAssertFalse(runtime.action.chinese.contains("Node.js"))
    }
}
