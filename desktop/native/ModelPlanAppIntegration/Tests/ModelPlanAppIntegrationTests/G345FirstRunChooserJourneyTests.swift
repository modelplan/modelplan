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
    let store: EngineStore, facts: WireConsentFacts?, rows: WireRowsSnapshot
    let context = EngineDeliveryContext(sessionID: "g345", floor: .init(storeEpoch: "g345", generation: 1), revision: 1)
    var grants: [WireConsentGrantParams] = []
    /// What the engine shows once a tool is allowed: the rows then include that tool (nil: rows never change).
    let rowsAfterAllow: WireRowsSnapshot?
    init(store: EngineStore, facts: WireConsentFacts?, rows: WireRowsSnapshot, rowsAfterAllow: WireRowsSnapshot? = nil) {
        self.store = store; self.facts = facts; self.rows = rows; self.rowsAfterAllow = rowsAfterAllow
    }
    func start() async throws -> EngineDeliveryContext {
        await store.consume(.connection(.ready(context))); await store.consume(.context(context))
        if let facts { await store.consume(.consentChanged(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch, consentGeneration: 1, data: facts), delivery: context))) }
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
        grants.append(request)
        if let more = rowsAfterAllow, !request.allow.isEmpty {
            await store.consume(.rowsChanged(.init(envelope: try .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch, consentGeneration: 1, data: more), delivery: context), invalidRowCount: 0))
        }
        return .init(requestID: .string(request.requestId))
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
    private func facts(keychain: Set<String> = ["claude.account_usage.saved_login"], denied: Set<String> = [], detectedOnly: Set<String>? = nil, browserOnlyTool: Bool = false) throws -> WireConsentFacts {
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
        ] + (browserOnlyTool ? [("kimi.account_usage.browser_session", "kimi", "browser_session", false, true)] : [])
        object["scopes"] = paths.map { id, tool, route, defaultCheck, detected -> [String: Any] in
            var scope = base
            scope["scope"] = id; scope["tool"] = tool; scope["route"] = route; scope["state"] = denied.contains(tool) ? "denied" : "unset"
            scope["detected"] = detectedOnly.map { $0.contains(tool) } ?? detected; scope["retired"] = false; scope["defaultCheck"] = defaultCheck; scope["cleanupPending"] = false
            scope.removeValue(forKey: "disabledReason")
            if keychain.contains(id) { scope["keychain"] = "unset" } else { scope.removeValue(forKey: "keychain") }
            return scope
        }
        return try WireDecoder.decode(WireConsentFacts.self, from: JSONSerialization.data(withJSONObject: object))
    }
    /// `codexReads`: the engine also has a Codex row it reads (consent implicit). G3-67: Settings ticks a
    /// default-on tool only when the engine's own row says it reads it.
    private func rows(codexReads: Bool = false) throws -> WireRowsSnapshot {
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
            + (codexReads ? [row("codex", "Codex", state: "fresh", code: "ok", surfaces: ["menu", "settings"])] : [])
        json["projection"] = projection
        return try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: json))
    }
    /// FR-9-11 / D61: Codex has a current 5h window with 63% left and a weekly one with 41% left; Claude Code is signed out.
    private func readingRows() throws -> WireRowsSnapshot {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: captures().appendingPathComponent("WireRowsSnapshot.json"))) as? [String: Any])
        var projection = try XCTUnwrap(json["projection"] as? [String: Any])
        var codex = try XCTUnwrap((projection["rows"] as? [[String: Any]])?.first)
        var account = try XCTUnwrap((codex["accounts"] as? [[String: Any]])?.first)
        let window = try XCTUnwrap((account["windows"] as? [[String: Any]])?.first)
        func make(_ id: String, _ role: String, _ left: Double) -> [String: Any] {
            var value = window
            value["id"] = id; value["role"] = role; value["remainingPercent"] = left; value["current"] = true
            value.removeValue(forKey: "modelScope"); value["validUntil"] = "2099-01-01T00:00:00Z"
            return value
        }
        account["windows"] = [make("codex-5h", "session", 63.2), make("codex-week", "weekly", 41.4)]
        account["valueState"] = "current"; account["freshUntil"] = "2099-01-01T00:00:00Z"
        codex["id"] = "codex"; codex["vendorKey"] = "codex"; codex["name"] = ["en": "Codex", "zh": "Codex"]
        codex["state"] = "fresh"; codex["consent"] = "implicit"; codex["surfaces"] = ["dock", "menu", "settings"]
        codex["reason"] = ["code": "ok", "text": ["en": "ok", "zh": "ok"]]
        codex["expiresAt"] = "2099-01-01T00:00:00Z"; codex.removeValue(forKey: "stateAfterExpiry"); codex.removeValue(forKey: "nextStep")
        codex["accounts"] = [account]
        projection["rows"] = [codex]
        json["projection"] = projection
        return try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: json))
    }
    /// Dock rows only: Codex reads; with `cursor` the Cursor row appears too.
    private func dockRows(cursor: Bool) throws -> WireRowsSnapshot {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: captures().appendingPathComponent("WireRowsSnapshot.json"))) as? [String: Any])
        var projection = try XCTUnwrap(json["projection"] as? [String: Any])
        let template = try XCTUnwrap((projection["rows"] as? [[String: Any]])?.first)
        func row(_ id: String) -> [String: Any] {
            var value = template
            value["id"] = id; value["vendorKey"] = id; value["name"] = ["en": id, "zh": id]
            value["state"] = "fresh"; value["consent"] = "implicit"; value["surfaces"] = ["dock", "menu", "settings"]
            value["reason"] = ["code": "ok", "text": ["en": "ok", "zh": "ok"]]
            value["expiresAt"] = "2099-01-01T00:00:00Z"; value.removeValue(forKey: "stateAfterExpiry"); value.removeValue(forKey: "nextStep")
            return value
        }
        projection["rows"] = cursor ? [row("codex"), row("cursor")] : [row("codex")]
        json["projection"] = projection
        return try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: json))
    }
    private func launch(locale: String, keychain: Set<String> = ["claude.account_usage.saved_login"], deniedAtFirstRun: Set<String> = [], dock: Bool = false, detectedOnly: Set<String>? = nil, browserOnlyTool: Bool = false, loadFacts: Bool = true, codexReads: Bool = false, readings: Bool = false) async throws -> (EngineDockMenuApplication, G345Engine) {
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("g345-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: profile) }
        let store = try EngineRowsEntry.makeSettingsStore(applicationSupport: profile, preferredLanguages: [locale])
        let consent: WireConsentFacts? = try loadFacts ? facts(keychain: keychain, denied: deniedAtFirstRun, detectedOnly: detectedOnly, browserOnlyTool: browserOnlyTool) : nil
        let snapshot = dock ? try dockRows(cursor: false) : readings ? try readingRows() : try rows(codexReads: codexReads)
        let after = dock ? try dockRows(cursor: true) : nil
        final class Holder: @unchecked Sendable { var engine: G345Engine? }
        let holder = Holder()
        let app = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/modelplan"), applicationVersion: "synthetic", allowedEnvironment: [:]),
            settingsStore: store, createsNativePanels: false, dockEnvironment: normalEntryTestEnvironment,
            makeClient: { _, target in let value = G345Engine(store: target, facts: consent, rows: snapshot, rowsAfterAllow: after); holder.engine = value; return value }, activateSettings: {})
        await app.prepare(); await app.composition.start()
        let controller = app.scopeConsentEntry.controller
        if loadFacts {
            for _ in 0..<500 where controller.facts == nil || controller.rowsSummary == nil { try await Task.sleep(for: .milliseconds(10)) }
            XCTAssertNotNil(controller.facts)
        }
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

    /// Build 13 owner review (ledger: none): ZCode showed the letters "ZC" and Kiro a white block. A filled tile mark
    /// keeps its own colours instead of being tinted to one colour, and ZCode shows the Zhipu mark it already has.
    func testFirstRunShowsRealMarksForZCodeAndKiro() async throws {
        for tool in ["zai", "kiro"] {
            let mark = try XCTUnwrap(ScopeConsentMarks.image(for: tool), tool)
            XCTAssertFalse(mark.isTemplate, "\(tool): a coloured tile is drawn as the file is")
            let cg = try XCTUnwrap(mark.cgImage(forProposedRect: nil, context: nil, hints: nil), tool)
            let rep = NSBitmapImageRep(cgImage: cg)
            var coloured = 0, dark = 0, light = 0
            for y in stride(from: 0, to: rep.pixelsHigh, by: 2) { for x in stride(from: 0, to: rep.pixelsWide, by: 2) {
                guard let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB), c.alphaComponent > 0.5 else { continue }
                let high = max(c.redComponent, c.greenComponent, c.blueComponent), low = min(c.redComponent, c.greenComponent, c.blueComponent)
                if high - low > 0.2 { coloured += 1 }
                if high < 0.2 { dark += 1 }
                if low > 0.8 { light += 1 }
            } }
            // The marks are filled tiles with a white glyph: Zhipu's tile is near-black (never chromatic), Kiro's is purple.
            // So assert the tile and the glyph as two populations; a plain block or a missing glyph fails.
            XCTAssertGreaterThan(light, 20, "\(tool): the white glyph is drawn")
            XCTAssertGreaterThan(tool == "zai" ? dark : coloured, 20, "\(tool): the tile keeps its own colour, not a plain block")
        }
        XCTAssertTrue(try XCTUnwrap(ScopeConsentMarks.image(for: "cursor")).isTemplate, "one-colour marks still follow the label colour")
        let (app, _) = try await launch(locale: "en-US")
        let window = try await firstRun(app)
        let zai = try find("scope.mark.zai", in: window, as: NSImageView.self)
        XCTAssertNotNil(zai.image, "ZCode shows a mark, not the letters ZC")
        XCTAssertNil(zai.contentTintColor, "and keeps its own colours")
        XCTAssertFalse(views(try find("scope.firstRun.row.zai", in: window, as: NSView.self)).compactMap { ($0 as? NSTextField)?.stringValue }.contains("ZC"))
    }

    /// Build 13 owner review (ledger: none): Settings listed every reading path of every tool, so Codex appeared
    /// twice, each with three buttons and a leftover status line. It follows the first-run list instead: one row per
    /// tool with its mark, what is read and why a tool is not read; paths and saved permissions are behind a disclosure.
    func testSettingsListsOneRowPerToolLikeTheFirstRunList() async throws {
        let (app, _) = try await launch(locale: "en-US", codexReads: true)
        let settings = app.scopeConsentEntry.view
        settings.apply(language: .english) // Settings applies the editor language when it is presented; this view is driven directly
        let controller = app.scopeConsentEntry.controller
        func ids(prefix: String) -> [String] { views(settings).compactMap { $0 as? NSButton }.map { $0.accessibilityIdentifier() }.filter { $0.hasPrefix(prefix) } }
        XCTAssertEqual(ids(prefix: "scope.settings.tool."), ["scope.settings.tool.claude", "scope.settings.tool.codex", "scope.settings.tool.cursor", "scope.settings.tool.zai", "scope.settings.tool.gemini"],
                       "every tool first run lists, Codex included, then the supported tool this Mac does not have")
        XCTAssertEqual(ids(prefix: "scope.revoke.") + ids(prefix: "scope.forget.") + ids(prefix: "scope.allow."), [], "no per-path buttons until the paths are shown")
        for tool in ["claude", "codex", "cursor", "zai"] {
            XCTAssertNotNil(views(settings).first { $0.accessibilityIdentifier() == "scope.mark." + tool }, "\(tool) has its mark")
        }
        let box = try XCTUnwrap(views(settings).first { $0.accessibilityIdentifier() == "scope.settings.tool.codex" } as? NSButton)
        XCTAssertEqual(box.state, .on, "a default-on tool the engine reads shows on")
        XCTAssertTrue(try XCTUnwrap(views(settings).first { $0.accessibilityIdentifier() == "scope.settings.status.zai" } as? NSTextField).stringValue.contains("nothing is read"))
        // G3-59: a supported tool that is not installed is listed with the reason and cannot be switched on.
        let gemini = try XCTUnwrap(views(settings).first { $0.accessibilityIdentifier() == "scope.settings.tool.gemini" } as? NSButton)
        XCTAssertEqual(gemini.state, .off); XCTAssertFalse(gemini.isEnabled)
        XCTAssertTrue(try XCTUnwrap(views(settings).first { $0.accessibilityIdentifier() == "scope.settings.status.gemini" } as? NSTextField).stringValue.hasPrefix("Not installed"))
        XCTAssertTrue(views(try XCTUnwrap(views(settings).first { $0.accessibilityIdentifier() == "scope.settings.row.gemini" })).compactMap { ($0 as? NSTextField)?.stringValue }.contains("Not detected on this Mac"))
        XCTAssertNotNil(views(settings).first { $0.accessibilityIdentifier() == "scope.mark.gemini" }, "an undetected tool has its mark too")
        // Turning a tool off is one confirmed choice for all of its paths.
        XCTAssertNotNil(controller.requestToolChoice("codex", on: false)) // what the box sends when pressed
        guard case .confirmation(let confirmation) = controller.phase else { return XCTFail("a tool toggle asks for confirmation") }
        XCTAssertEqual(confirmation.intent.denyIDs, ["codex.local_history", "codex.runtime_usage"])
        XCTAssertEqual(views(settings).compactMap { ($0 as? NSTextField)?.stringValue }.filter { $0 == "Codex" }.count, 2, "the row's name and the confirmation's one line: the confirmation names the tool once")
        controller.cancelConfirmation()
        // The paths and their saved-permission buttons are still reachable.
        XCTAssertNotNil(views(settings).first { $0.accessibilityIdentifier() == "scope.details.toggle" })
        settings.setPathDetailsExpanded(true)
        XCTAssertFalse(ids(prefix: "scope.revoke.").isEmpty, "the disclosure shows the paths")
    }

    /// G3-59 (owner build 14b): a tool that is installed but was not selected in first run can be enabled later in
    /// Settings, with no relaunch, and then appears in the Dock. Cursor was left unticked (its paths are refused);
    /// the engine shows the Cursor row once an allow reaches it.
    func testToolLeftOutOfFirstRunCanBeEnabledInSettingsAndAppearsInTheDock() async throws {
        let (app, engine) = try await launch(locale: "en-US", deniedAtFirstRun: ["cursor"], dock: true)
        let settings = app.scopeConsentEntry.view, controller = app.scopeConsentEntry.controller
        XCTAssertEqual(app.composition.provider.dockContent.dockRows.map(\.id), ["codex"], "the Dock shows only what is read")
        let box = try XCTUnwrap(views(settings).first { $0.accessibilityIdentifier() == "scope.settings.tool.cursor" } as? NSButton)
        XCTAssertEqual(box.state, .off, "the unticked tool is listed, off")
        XCTAssertTrue(box.isEnabled, "and can be switched on")
        XCTAssertNotNil(controller.requestToolChoice("cursor", on: true)) // what the box sends when pressed; the view is not in a window here
        guard case .confirmation(let confirmation) = controller.phase else { return XCTFail("switching a tool on asks to confirm") }
        XCTAssertEqual(confirmation.intent.allowIDs, ["cursor.account_usage.saved_login", "cursor.local_history"])
        await controller.confirm(confirmation.id)
        let grants = await engine.recorded()
        XCTAssertEqual(grants.count, 1)
        XCTAssertEqual(grants.first?.allow, ["cursor.account_usage.saved_login", "cursor.local_history"])
        for _ in 0..<300 where app.composition.provider.dockContent.dockRows.count < 2 { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(app.composition.provider.dockContent.dockRows.map(\.id), ["codex", "cursor"], "the tool appears in the Dock without a relaunch")
    }

    func testFirstRunListsDetectedToolsAndDoneSendsTheChoices() async throws {
        let (app, engine) = try await launch(locale: "en-US")
        let window = try await firstRun(app)
        let boxes = views(try XCTUnwrap(window.contentView)).compactMap { $0 as? NSButton }.filter { $0.accessibilityIdentifier().hasPrefix("scope.firstRun.tool.") }
        XCTAssertEqual(boxes.map { $0.accessibilityIdentifier() }, ["scope.firstRun.tool.claude", "scope.firstRun.tool.codex", "scope.firstRun.tool.cursor", "scope.firstRun.tool.zai"],
                       "every detected tool once, in the engine's order; undetected Gemini is not listed")
        for tool in ["claude", "codex", "cursor", "zai"] {
            XCTAssertFalse(try find("scope.firstRun.row." + tool, in: window, as: NSView.self).isHiddenOrHasHiddenAncestor)
            guard tool != "zai" else { continue }
            // FR-9-11: a tool with no system prompt says it is detected and read without asking; a Keychain login says macOS asks once.
            let reads = try text("scope.firstRun.reads." + tool, in: window)
            XCTAssertEqual(reads, tool == "claude" ? FirstRunCopy.keychainLine.english : FirstRunCopy.detected.english)
        }
        XCTAssertNil(views(try XCTUnwrap(window.contentView)).first { $0.accessibilityIdentifier() == "scope.firstRun.reads.zai" },
                     "a login that is not read does not describe a read")
        XCTAssertTrue(try text("scope.firstRun.reads.claude", in: window).contains("Keychain"), "Claude Code says macOS may ask for the Keychain")
        XCTAssertEqual(try text("scope.firstRun.reads.codex", in: window), FirstRunCopy.detected.english)
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
        XCTAssertEqual(try text("scope.firstRun.import", in: window).contains("设置 › 数据与隐私"), true, "the merged small print points to Data & Privacy")
        XCTAssertEqual(try text("scope.firstRun.reads.codex", in: window), "本机已检测到 · 无需授权")
        XCTAssertEqual(try text("scope.firstRun.status.claude", in: window), "未登录 Claude Code。登录后会自动读取。")
        XCTAssertTrue(try text("scope.firstRun.reads.claude", in: window).contains("钥匙串"))
        // Settings > Data & Privacy states the same reason on the tool's paths (G3-38 A).
        app.scopeConsentEntry.view.setPathDetailsExpanded(true) // the per-path rows sit behind a disclosure
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
        XCTAssertEqual(try text("scope.firstRun.reads.cursor", in: window), FirstRunCopy.keychainLine.english)
        XCTAssertEqual(try text("scope.firstRun.reads.codex", in: window), FirstRunCopy.detected.english)
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

    /// A detected tool with only browser-session paths is never read here, so its row gives a plain
    /// reason and no "Reads ..." line, beside a disabled, unticked box.
    func testToolWithOnlyBrowserSessionPathsSaysItCannotBeReadInsteadOfReads() async throws {
        for (locale, reason) in [("en-US", "can't read this tool's sign-in"), ("zh-CN", "暂不支持读取这个工具")] {
            let (app, _) = try await launch(locale: locale, browserOnlyTool: true)
            let window = try await firstRun(app)
            let box = try find("scope.firstRun.tool.kimi", in: window, as: NSButton.self)
            XCTAssertFalse(box.isEnabled); XCTAssertEqual(box.state, .off)
            XCTAssertTrue(try text("scope.firstRun.status.kimi", in: window).contains(reason), locale)
            XCTAssertNil(views(try XCTUnwrap(window.contentView)).first { $0.accessibilityIdentifier() == "scope.firstRun.reads.kimi" }, "no read line for a tool that is not read")
            XCTAssertTrue(try find("firstRun.done", in: window, as: NSButton.self).isEnabled, "an unreadable tool does not block Done")
            window.close()
        }
    }

    /// While the tools are still being found the chooser has its own heading, and the subscriptions
    /// summary is not shown beside it.
    func testChooserHasItsOwnHeadingAndNoSubscriptionsSummaryWhileLoading() async throws {
        for (locale, heading) in [("en-US", "TOOLS MODELPLAN READS"), ("zh-CN", "读取这些工具的额度")] {
            let (app, _) = try await launch(locale: locale, loadFacts: false)
            XCTAssertNil(app.scopeConsentEntry.controller.facts)
            let window = try await firstRun(app)
            XCTAssertEqual(try text("scope.firstRun.heading", in: window), heading)
            // First run v1: the reader's start is said on the page (the local presence check lists rows meanwhile).
            XCTAssertNotNil(try? find("scope.firstRun.engine", in: window, as: NSTextField.self), "the reader is still starting")
            XCTAssertTrue(try find("firstRun.subscriptions", in: window, as: NSView.self).isHiddenOrHasHiddenAncestor, "no subscriptions summary while loading")
            XCTAssertFalse(views(try XCTUnwrap(window.contentView)).compactMap { ($0 as? NSTextField)?.stringValue }.contains { $0 == "Subscriptions" || $0 == "订阅" })
            window.close()
        }
    }

    private func frame(_ id: String, in window: NSWindow) throws -> CGRect {
        let view = try find(id, in: window, as: NSView.self)
        return view.convert(view.bounds, to: nil)
    }

    /// FR-9-11 (owner-approved mock): dark window; the privacy promise in large type with the FR-9-03 line and
    /// "Learn more ›" under it; the tool cards as the main element; one merged small print; the footer in one row.
    func testFR_9_11_PageOrderCopyAndDarkWindow() async throws {
        let copy: [(String, String, String)] = [("en-US", "Learn more ›", "TOOLS MODELPLAN READS"), ("zh-CN", "了解详情 ›", "读取这些工具的额度")]
        for (locale, learn, heading) in copy {
            let (app, _) = try await launch(locale: locale)
            let window = try await firstRun(app)
            XCTAssertEqual(window.appearance?.name, .darkAqua, "the first-run window is dark")
            let title = try find("firstRun.title", in: window, as: NSTextField.self), privacy = try find("firstRun.privacy", in: window, as: NSTextField.self)
            XCTAssertGreaterThanOrEqual(privacy.font?.pointSize ?? 0, 24, "the privacy promise is the large type")
            XCTAssertLessThanOrEqual(title.font?.pointSize ?? 99, 14, "\"Set up ModelPlan\" is a small line above it")
            XCTAssertEqual(try find("firstRun.learnMore", in: window, as: NSButton.self).title, learn)
            XCTAssertEqual(try text("scope.firstRun.heading", in: window), heading)
            // Top to bottom (window coordinates grow upwards).
            let order = ["firstRun.title", "firstRun.privacy", "firstRun.publicRecommendation", "firstRun.learnMore", "scope.firstRun.heading",
                         "scope.firstRun.row.codex", "scope.firstRun.import", "firstRun.login"]
            let middles = try order.map { try frame($0, in: window).midY }
            XCTAssertEqual(middles, middles.sorted(by: >), "page order: \(order)")
            // The footer is one row: the login choice on the left, Done on the right.
            let login = try frame("firstRun.login", in: window), done = try frame("firstRun.done", in: window)
            XCTAssertLessThan(login.maxX, done.minX)
            XCTAssertLessThan(abs(login.midY - done.midY), 40, "login and Done share the footer row")
            // The three former small-print paragraphs are one; the session-file sentence lives in Data & Privacy.
            XCTAssertEqual(try text("scope.firstRun.import", in: window), FirstRunCopy.smallPrint.value(locale.hasPrefix("zh") ? .chinese : .english))
            let all = views(try XCTUnwrap(window.contentView)).compactMap { ($0 as? NSTextField)?.stringValue }
            XCTAssertFalse(all.contains { $0.contains("Local session files") || $0.contains("读取本地会话文件") })
            XCTAssertFalse(all.contains { $0.hasPrefix("Choose which tools") || $0.hasPrefix("选择要读取的工具") })
            // The window is as tall as the page: nothing is cut off and no empty band is left below the footer.
            window.contentView?.layoutSubtreeIfNeeded()
            let footer = try frame("firstRun.done", in: window), content = window.contentLayoutRect
            XCTAssertLessThan(footer.minY - content.minY, 80, "no empty band below the footer (\(locale))")
            window.close()
        }
    }

    /// FR-9-11 / D61: the card shows the read quota values, in the reader's language, with the status colour.
    func testFR_9_11_CardShowsTheReadQuotaValues() async throws {
        for (locale, five, week) in [("en-US", "5h  63% left", "Weekly  41% left"), ("zh-CN", "5小时  剩 63%", "每周  剩 41%")] {
            let (app, _) = try await launch(locale: locale, readings: true)
            for _ in 0..<300 where app.scopeConsentEntry.controller.firstRunReadings(forTool: "codex").isEmpty { try await Task.sleep(for: .milliseconds(10)) }
            XCTAssertEqual(app.scopeConsentEntry.controller.firstRunReadings(forTool: "codex"), [.init(kind: .fiveHour, percent: 63), .init(kind: .weekly, percent: 41)])
            let window = try await firstRun(app)
            XCTAssertEqual(try text("scope.firstRun.reading.codex.fiveHour", in: window), five)
            XCTAssertEqual(try text("scope.firstRun.reading.codex.weekly", in: window), week)
            let card = try frame("scope.firstRun.row.codex", in: window), value = try frame("scope.firstRun.reading.codex.fiveHour", in: window)
            XCTAssertGreaterThan(value.minX, card.midX, "the values sit at the right of the card")
            XCTAssertNil(views(try XCTUnwrap(window.contentView)).first { $0.accessibilityIdentifier() == "scope.firstRun.reading.claude.fiveHour" }, "a tool with no reading shows no value")
            window.close()
        }
    }

    /// FR-9-11: "Learn more ›" opens Settings on Data & Privacy, and the first-run page stays open.
    func testFR_9_11_LearnMoreOpensSettingsOnDataAndPrivacy() async throws {
        let (app, _) = try await launch(locale: "en-US")
        let window = try await firstRun(app)
        let before = Set(NSApplication.shared.windows.map(ObjectIdentifier.init))
        try find("firstRun.learnMore", in: window, as: NSButton.self).performClick(nil)
        var settings: SettingsWindowController?
        for _ in 0..<300 where settings == nil {
            try await Task.sleep(for: .milliseconds(10))
            settings = NSApplication.shared.windows.first { !before.contains(ObjectIdentifier($0)) && $0.isVisible }?.windowController as? SettingsWindowController
        }
        let opened = try XCTUnwrap(settings, "Settings opened")
        addTeardownBlock { @MainActor in opened.window?.close() }
        XCTAssertEqual(opened.selectedPaneID, "privacy")
        XCTAssertTrue(window.isVisible, "the first-run page stays open")
    }
}
