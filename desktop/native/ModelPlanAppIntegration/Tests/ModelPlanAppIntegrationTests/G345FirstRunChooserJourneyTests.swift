// SPDX-License-Identifier: MIT
import AppKit
import XCTest
import ModelPlanSettings
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanWire
@testable import ModelPlanAppIntegration

/// Synthetic engine only: it reports the detected tools and their rows, and records grants.
/// Nothing on the machine is read.
private actor G345Engine: EngineClient {
    nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool { true }
    let store: EngineStore, facts: WireConsentFacts, rows: WireRowsSnapshot
    let context = EngineDeliveryContext(sessionID: "g345", floor: .init(storeEpoch: "g345", generation: 1), revision: 1)
    var grants: [WireConsentGrantParams] = []
    init(store: EngineStore, facts: WireConsentFacts, rows: WireRowsSnapshot) { self.store = store; self.facts = facts; self.rows = rows }
    func start() async throws -> EngineDeliveryContext {
        await store.consume(.connection(.ready(context))); await store.consume(.context(context))
        await store.consume(.consentChanged(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch, consentGeneration: 1, data: facts), delivery: context)))
        return context
    }
    func recorded() -> [WireConsentGrantParams] { grants }
    func retry() async throws -> EngineDeliveryContext { try await start() }
    func stop() async {}
    func subscribeRows(timeout: Duration?) async throws -> EngineRequestCompletion {
        await store.consume(.rowsChanged(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch, consentGeneration: 1, data: rows), delivery: context), invalidRowCount: 0))
        return .init(requestID: .string("g345-rows"))
    }
    func consent(timeout: Duration?) async throws -> EngineRequestCompletion { .init(requestID: .string("g345-facts")) }
    func grant(_ request: WireConsentGrantParams, userAction: EngineUserAction?, timeout: Duration?) async throws -> EngineRequestCompletion {
        grants.append(request); return .init(requestID: .string(request.requestId))
    }
    func refresh(_ request: WireRefreshRequestParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func history(_ request: WireHistoryQueryParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func cockpit(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func publication(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func pluginInstall(_ request: WirePluginInstallParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func diagnostics(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
}

/// G3-45 (owner 2026-11-08): the first run lists every detected tool with a checkbox, what is read,
/// whether macOS may ask for the Keychain, and why a tool cannot be read (G3-38: Claude Code signed
/// out; D52: ZCode with an account login). Done sends the choices once as the consent grant.
/// Driven through the real first-run entry (restoreFirstRunIfNeeded on the normal launch path).
@MainActor final class G345FirstRunChooserJourneyTests: XCTestCase {
    private func captures() -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../../../schema/app-cli/captures", isDirectory: true).standardizedFileURL
    }
    /// Claude Code (local history, saved login), Codex (local history, runtime), Cursor (local history,
    /// saved login, browser session), ZCode (saved key) are detected; Gemini is not.
    private func facts(keychain: Set<String> = ["claude.account_usage.saved_login"], detectedOnly: Set<String>? = nil) throws -> WireConsentFacts {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: captures().appendingPathComponent("WireConsentFacts.json"))) as? [String: Any])
        let base = try XCTUnwrap((object["scopes"] as? [[String: Any]])?.first)
        let paths: [(String, String, String, Bool, Bool)] = [
            ("claude.local_history", "claude", "local_log", true, true),
            ("claude.account_usage.saved_login", "claude", "saved_login_api", true, true),
            ("codex.local_history", "codex", "local_log", true, true),
            ("codex.runtime_usage", "codex", "runtime_rpc", true, true),
            ("cursor.local_history", "cursor", "local_log", true, true),
            ("cursor.account_usage.saved_login", "cursor", "saved_login_api", false, true),
            ("cursor.account_usage.browser_session", "cursor", "browser_session", false, true),
            ("zai.account_usage.api_key", "zai", "api_key_api", true, true),
            ("gemini.local_history", "gemini", "local_log", true, false),
        ]
        object["scopes"] = paths.map { id, tool, route, defaultCheck, detected -> [String: Any] in
            var scope = base
            scope["scope"] = id; scope["tool"] = tool; scope["route"] = route; scope["state"] = "unset"
            scope["detected"] = detectedOnly.map { $0.contains(tool) } ?? detected; scope["retired"] = false; scope["defaultCheck"] = defaultCheck; scope["cleanupPending"] = false
            scope.removeValue(forKey: "disabledReason")
            if keychain.contains(id) { scope["keychain"] = "unset" } else { scope.removeValue(forKey: "keychain") }
            return scope
        }
        return try WireDecoder.decode(WireConsentFacts.self, from: JSONSerialization.data(withJSONObject: object))
    }
    private func rows() throws -> WireRowsSnapshot {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: captures().appendingPathComponent("WireRowsSnapshot.json"))) as? [String: Any])
        var projection = try XCTUnwrap(json["projection"] as? [String: Any])
        let template = try XCTUnwrap((projection["rows"] as? [[String: Any]])?.first)
        func row(_ id: String, _ name: String, state: String, code: String, surfaces: [String]) -> [String: Any] {
            var value = template
            value["id"] = id; value["vendorKey"] = id; value["name"] = ["en": name, "zh": name]
            value["state"] = state; value["consent"] = "implicit"; value["surfaces"] = surfaces; value["accounts"] = [[String: Any]]()
            value["reason"] = ["code": code, "text": ["en": "engine text", "zh": "engine text"]]
            value["expiresAt"] = "2099-01-01T00:00:00Z"; value.removeValue(forKey: "stateAfterExpiry"); value.removeValue(forKey: "nextStep")
            return value
        }
        projection["rows"] = [row("claude", "Claude Code", state: "needs_action", code: "not_signed_in", surfaces: ["menu", "settings"]),
                              row("zai", "ZCode / GLM", state: "needs_action", code: "unsupported_login", surfaces: ["menu", "settings"])]
        json["projection"] = projection
        return try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: json))
    }
    private func launch(locale: String, keychain: Set<String> = ["claude.account_usage.saved_login"], detectedOnly: Set<String>? = nil) async throws -> (EngineDockMenuApplication, G345Engine) {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g345-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: profile) }
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: [locale])
        let consent = try facts(keychain: keychain, detectedOnly: detectedOnly), snapshot = try rows()
        final class Holder: @unchecked Sendable { var engine: G345Engine? }
        let holder = Holder()
        let app = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic", allowedEnvironment: [:]),
            settingsStore: store, createsNativePanels: false, dockEnvironment: normalEntryTestEnvironment,
            makeClient: { _, target in let value = G345Engine(store: target, facts: consent, rows: snapshot); holder.engine = value; return value }, activateSettings: {})
        await app.prepare(); await app.composition.start()
        let controller = app.scopeConsentEntry.controller
        for _ in 0..<500 where controller.facts == nil || controller.rowsSummary == nil { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertNotNil(controller.facts)
        addTeardownBlock { @MainActor in await app.composition.stop(); app.composition.dock.close() }
        return (app, try XCTUnwrap(holder.engine))
    }
    private func views(_ root: NSView) -> [NSView] { [root] + root.subviews.flatMap(views) }
    private func firstRun(_ app: EngineDockMenuApplication) async throws -> NSWindow {
        let before = Set(NSApplication.shared.windows.map(ObjectIdentifier.init))
        await app.restoreFirstRunIfNeeded()
        let window = try XCTUnwrap(NSApplication.shared.windows.first { !before.contains(ObjectIdentifier($0)) && $0.isVisible })
        addTeardownBlock { @MainActor in window.close() }
        window.contentView?.layoutSubtreeIfNeeded()
        return window
    }
    private func find<T: NSView>(_ id: String, in window: NSWindow, as type: T.Type) throws -> T {
        try XCTUnwrap(views(try XCTUnwrap(window.contentView)).first { $0.accessibilityIdentifier() == id } as? T, "Missing \(id)")
    }
    private func text(_ id: String, in window: NSWindow) throws -> String { try find(id, in: window, as: NSTextField.self).stringValue }

    func testFirstRunListsDetectedToolsAndDoneSendsTheChoices() async throws {
        let (app, engine) = try await launch(locale: "en-US")
        let window = try await firstRun(app)
        let boxes = views(try XCTUnwrap(window.contentView)).compactMap { $0 as? NSButton }.filter { $0.accessibilityIdentifier().hasPrefix("scope.firstRun.tool.") }
        XCTAssertEqual(boxes.map { $0.accessibilityIdentifier() }, ["scope.firstRun.tool.claude", "scope.firstRun.tool.codex", "scope.firstRun.tool.cursor", "scope.firstRun.tool.zai"],
                       "every detected tool once, in the engine's order; undetected Gemini is not listed")
        for tool in ["claude", "codex", "cursor", "zai"] {
            XCTAssertFalse(try find("scope.firstRun.row." + tool, in: window, as: NSView.self).isHiddenOrHasHiddenAncestor)
            XCTAssertTrue(views(try find("scope.firstRun.row." + tool, in: window, as: NSView.self)).compactMap { ($0 as? NSTextField)?.stringValue }.contains("Detected on this Mac"))
            guard tool != "zai" else { continue }
            let reads = try text("scope.firstRun.reads." + tool, in: window)
            XCTAssertTrue(reads.hasPrefix("Reads") || reads.hasPrefix("Asks"), reads)
        }
        XCTAssertNil(views(try XCTUnwrap(window.contentView)).first { $0.accessibilityIdentifier() == "scope.firstRun.reads.zai" },
                     "a login that is not read does not describe a read")
        XCTAssertTrue(try text("scope.firstRun.reads.claude", in: window).contains("Keychain"), "Claude Code says macOS may ask for the Keychain")
        XCTAssertTrue(try text("scope.firstRun.reads.codex", in: window).contains("No Keychain prompt"))
        XCTAssertEqual(try text("scope.firstRun.status.claude", in: window), "Not signed in to Claude Code. ModelPlan reads it after you sign in.", "G3-38: signed-out Claude Code says so, in the one shared sentence")
        XCTAssertTrue(try text("scope.firstRun.status.zai", in: window).contains("nothing is read"), "D52: ZCode with an account login is listed, not read")
        let byTool = Dictionary(uniqueKeysWithValues: boxes.map { ($0.accessibilityIdentifier().replacingOccurrences(of: "scope.firstRun.tool.", with: ""), $0) })
        XCTAssertEqual(byTool["codex"]?.state, .on); XCTAssertEqual(byTool["cursor"]?.state, .on)
        XCTAssertEqual(byTool["claude"]?.state, .off); XCTAssertEqual(byTool["zai"]?.state, .off)
        XCTAssertEqual(byTool["claude"]?.isEnabled, false); XCTAssertEqual(byTool["zai"]?.isEnabled, false)
        XCTAssertTrue(try find("firstRun.subscriptions", in: window, as: NSView.self).isHiddenOrHasHiddenAncestor, "the tool list replaces the summary line")
        XCTAssertFalse(views(try XCTUnwrap(window.contentView)).contains { $0.accessibilityIdentifier().contains("browser_session") }, "browser sessions ask at first need")
        // Wrapped lines show in full inside the page column.
        for field in views(try XCTUnwrap(window.contentView)).compactMap({ $0 as? NSTextField }) where field.accessibilityIdentifier().hasPrefix("scope.firstRun.") && !field.isHiddenOrHasHiddenAncestor {
            let needed = try XCTUnwrap(field.cell).cellSize(forBounds: NSRect(x: 0, y: 0, width: field.bounds.width, height: .greatestFiniteMagnitude))
            XCTAssertLessThanOrEqual(needed.height, field.bounds.height + 1, "\(field.accessibilityIdentifier()) is cut off")
            XCTAssertLessThanOrEqual(field.convert(field.bounds, to: nil).maxX, window.contentLayoutRect.maxX, "\(field.accessibilityIdentifier()) spills out")
        }
        let none = await engine.recorded()
        XCTAssertTrue(none.isEmpty, "showing the page sends nothing")

        try XCTUnwrap(byTool["codex"]).performClick(nil)
        for _ in 0..<100 where (try? find("scope.firstRun.tool.codex", in: window, as: NSButton.self))?.state != .off { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(try find("scope.firstRun.tool.codex", in: window, as: NSButton.self).state, .off)
        let afterUncheck = await engine.recorded()
        XCTAssertTrue(afterUncheck.isEmpty, "a checkbox alone sends nothing")

        try find("firstRun.done", in: window, as: NSButton.self).performClick(nil)
        var saved = await app.foundationStore.snapshot()
        for _ in 0..<300 where !saved.preferences.onboarding.completed { try await Task.sleep(for: .milliseconds(10)); saved = await app.foundationStore.snapshot() }
        XCTAssertTrue(saved.preferences.onboarding.completed)
        let grants = await engine.recorded()
        XCTAssertEqual(grants.count, 1, "Done is the one first-run consent")
        XCTAssertEqual(grants.first?.allow, ["cursor.account_usage.saved_login", "cursor.local_history"])
        XCTAssertEqual(grants.first?.deny, ["codex.local_history", "codex.runtime_usage"], "an unchecked tool is refused, so it is not read after Done")
        XCTAssertTrue(grants.first?.keychain?.isEmpty != false, "a signed-out Claude Code starts no Keychain read")
        for id in ["claude.local_history", "claude.account_usage.saved_login", "zai.account_usage.api_key", "cursor.account_usage.browser_session", "gemini.local_history"] {
            XCTAssertFalse((grants.first?.allow ?? []).contains(id) || (grants.first?.deny ?? []).contains(id), "\(id) is left as it was")
        }
    }

    func testChinesePageAndSettingsSayWhyAToolIsNotRead() async throws {
        let (app, _) = try await launch(locale: "zh-CN")
        let window = try await firstRun(app)
        XCTAssertEqual(try text("scope.firstRun.notice", in: window).contains("设置 › 数据与隐私"), true)
        XCTAssertTrue(views(try find("scope.firstRun.row.codex", in: window, as: NSView.self)).compactMap { ($0 as? NSTextField)?.stringValue }.contains("本机已检测到"))
        XCTAssertEqual(try text("scope.firstRun.status.claude", in: window), "未登录 Claude Code。登录后会自动读取。")
        XCTAssertTrue(try text("scope.firstRun.reads.claude", in: window).contains("钥匙串"))
        // Settings > Data & Privacy states the same reason on the tool's paths (G3-38 A).
        let settings = views(app.scopeConsentEntry.view)
        let status = try XCTUnwrap(settings.first { $0.accessibilityIdentifier() == "scope.status.claude.account_usage.saved_login" } as? NSTextField)
        XCTAssertEqual(status.stringValue, "未登录 Claude Code。登录后会自动读取。", "Settings and first run use the same sentence")
        let line = try text("scope.firstRun.status.claude", in: window).replacingOccurrences(of: "Claude Code", with: "")
        XCTAssertNil(line.range(of: "[A-Za-z]", options: .regularExpression), "no English inside the Chinese line besides the tool name: \(line)")
    }

    /// D61 (3): at least one tool must be ticked; Done stays disabled until one is.
    func testDoneNeedsAtLeastOneTickedTool() async throws {
        let (app, engine) = try await launch(locale: "en-US")
        let window = try await firstRun(app)
        let done = try find("firstRun.done", in: window, as: NSButton.self)
        XCTAssertTrue(done.isEnabled, "readable tools start ticked, so Done starts enabled")
        XCTAssertNil(views(try XCTUnwrap(window.contentView)).first { $0.accessibilityIdentifier() == "scope.firstRun.pickOne" && !$0.isHiddenOrHasHiddenAncestor })
        for tool in ["codex", "cursor"] {
            try find("scope.firstRun.tool." + tool, in: window, as: NSButton.self).performClick(nil)
            for _ in 0..<100 where (try? find("scope.firstRun.tool." + tool, in: window, as: NSButton.self))?.state != .off { try await Task.sleep(for: .milliseconds(10)) }
        }
        XCTAssertFalse(try find("firstRun.done", in: window, as: NSButton.self).isEnabled, "nothing ticked: Done is disabled")
        XCTAssertTrue(try text("scope.firstRun.pickOne", in: window).contains("at least one"))
        try find("firstRun.done", in: window, as: NSButton.self).performClick(nil)
        try await Task.sleep(for: .milliseconds(100))
        let none = await engine.recorded()
        XCTAssertTrue(none.isEmpty, "a disabled Done sends nothing")
        let notDone = await app.foundationStore.snapshot()
        XCTAssertFalse(notDone.preferences.onboarding.completed)
        try find("scope.firstRun.tool.cursor", in: window, as: NSButton.self).performClick(nil)
        for _ in 0..<100 where !((try? find("firstRun.done", in: window, as: NSButton.self))?.isEnabled ?? false) { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertTrue(try find("firstRun.done", in: window, as: NSButton.self).isEnabled, "one tick enables Done again")
    }

    /// D61 (2): whether a tool can show a macOS Keychain prompt comes from its read path's access
    /// class (the engine's Keychain-capable scopes), not from the vendor. Here a synthetic Cursor
    /// sign-in is Keychain-capable: its line says so and its Keychain read is asked only on Done.
    func testKeychainAccessClassNotVendorDecidesTheKeychainRead() async throws {
        let (app, engine) = try await launch(locale: "en-US", keychain: ["cursor.account_usage.saved_login"])
        let window = try await firstRun(app)
        XCTAssertTrue(try text("scope.firstRun.reads.cursor", in: window).contains("macOS may ask once for Keychain access"))
        XCTAssertTrue(try text("scope.firstRun.reads.codex", in: window).contains("No Keychain prompt"))
        let before = await engine.recorded()
        XCTAssertTrue(before.isEmpty, "nothing that can prompt is asked before Done")
        try find("firstRun.done", in: window, as: NSButton.self).performClick(nil)
        var grants: [WireConsentGrantParams] = []
        for _ in 0..<300 where grants.isEmpty { try await Task.sleep(for: .milliseconds(10)); grants = await engine.recorded() }
        XCTAssertEqual(grants.count, 1)
        XCTAssertEqual(grants.first?.keychain?["cursor.account_usage.saved_login"], .allow, "a ticked Keychain-capable path gets its Keychain read on Done")
        XCTAssertEqual(grants.first?.keychain?.count, 1, "plain paths never carry a Keychain read")
    }

    /// D61 (2): an unticked Keychain-capable tool is refused and gets no Keychain read.
    func testUntickedKeychainToolGetsNoKeychainRead() async throws {
        let (app, engine) = try await launch(locale: "en-US", keychain: ["cursor.account_usage.saved_login"])
        let window = try await firstRun(app)
        try find("scope.firstRun.tool.cursor", in: window, as: NSButton.self).performClick(nil)
        for _ in 0..<100 where (try? find("scope.firstRun.tool.cursor", in: window, as: NSButton.self))?.state != .off { try await Task.sleep(for: .milliseconds(10)) }
        try find("firstRun.done", in: window, as: NSButton.self).performClick(nil)
        var grants: [WireConsentGrantParams] = []
        for _ in 0..<300 where grants.isEmpty { try await Task.sleep(for: .milliseconds(10)); grants = await engine.recorded() }
        XCTAssertEqual(grants.first?.deny, ["cursor.account_usage.saved_login", "cursor.local_history"])
        XCTAssertTrue(grants.first?.keychain?.isEmpty != false)
    }

    /// D61 (3) exception: when no listed tool can be read (here a signed-out Claude Code and a ZCode
    /// account login), nothing can be ticked, so Done stays enabled; pressing it finishes the first run
    /// and sends no grant. The page cannot get stuck.
    func testDoneStaysEnabledWhenNoDetectedToolIsReadable() async throws {
        let (app, engine) = try await launch(locale: "en-US", detectedOnly: ["claude", "zai"])
        let window = try await firstRun(app)
        for tool in ["claude", "zai"] {
            let box = try find("scope.firstRun.tool." + tool, in: window, as: NSButton.self)
            XCTAssertFalse(box.isEnabled, "\(tool) cannot be read, so its checkbox is disabled")
            XCTAssertEqual(box.state, .off)
        }
        XCTAssertTrue(app.scopeConsentEntry.controller.firstRunChoiceSatisfied)
        let done = try find("firstRun.done", in: window, as: NSButton.self)
        XCTAssertTrue(done.isEnabled, "nothing is readable, so Done must not wait for a tick")
        XCTAssertNil(views(try XCTUnwrap(window.contentView)).first { $0.accessibilityIdentifier() == "scope.firstRun.pickOne" && !$0.isHiddenOrHasHiddenAncestor })
        done.performClick(nil)
        var saved = await app.foundationStore.snapshot()
        for _ in 0..<300 where !saved.preferences.onboarding.completed { try await Task.sleep(for: .milliseconds(10)); saved = await app.foundationStore.snapshot() }
        XCTAssertTrue(saved.preferences.onboarding.completed, "Done finishes the first run")
        let grants = await engine.recorded()
        XCTAssertTrue(grants.isEmpty, "no readable tool: Done sends no grant")
    }

    /// G3-38: a not_signed_in row (needs_action, next step action none) is shown in Settings and the
    /// menu, but it has no Dock row, no reset or forecast signal (the menu badge), and no diagnostics
    /// or next-step item in the status menu.
    func testNotSignedInRowRaisesNoBadgeOrMenuAction() async throws {
        let (app, _) = try await launch(locale: "en-US")
        let provider = app.composition.provider
        for _ in 0..<300 where !provider.dockContent.menuRows.contains(where: { $0.id == "claude" }) { try await Task.sleep(for: .milliseconds(10)) }
        let content = provider.dockContent
        XCTAssertTrue(content.menuRows.contains { $0.id == "claude" }, "the menu still names the tool")
        XCTAssertFalse(content.dockRows.contains { $0.id == "claude" || $0.id == "zai" }, "a signed-out tool has no Dock row")
        XCTAssertTrue(app.composition.resetSignals.isEmpty, "nothing that could raise the menu badge")
        if let menu = app.liveStatusMenu {
            let titles = menu.items.map(\.title)
            XCTAssertFalse(titles.contains { $0.contains("Details…") || $0.contains("Allow reading") || $0.contains("Permission needed") }, "no next-step or diagnostics item: \(titles)")
        }
    }

    /// Ledger: none / Scenarios: I-03 / Requirements: FR-9-03 (owner D71, 2026-11-08).
    /// Under the privacy line the first-run page says recommendations use ModelPlan's published model
    /// data and the user's usage stays on this Mac. Driven through the normal first-run entry.
    func testFirstRunStatesThatRecommendationsNeverUploadUsage() async throws {
        let (en, _) = try await launch(locale: "en-US")
        let enWindow = try await firstRun(en)
        XCTAssertEqual(try text("firstRun.recommendations", in: enWindow), "Recommendations use ModelPlan's published model data; your usage never leaves this Mac.")
        let (zh, _) = try await launch(locale: "zh-CN")
        let zhWindow = try await firstRun(zh)
        XCTAssertEqual(try text("firstRun.recommendations", in: zhWindow), "推荐用的是 ModelPlan 公开发布的模型数据，不会上传你的使用记录。")
        let privacy = try find("firstRun.privacy", in: zhWindow, as: NSTextField.self), line = try find("firstRun.recommendations", in: zhWindow, as: NSTextField.self)
        XCTAssertFalse(line.isHiddenOrHasHiddenAncestor)
        XCTAssertGreaterThan(privacy.convert(privacy.bounds, to: nil).minY, line.convert(line.bounds, to: nil).maxY - 0.5, "the line sits under the privacy line")
    }
}
