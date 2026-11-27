// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanDock
import ModelPlanSettings
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanWire
@testable import ModelPlanAppIntegration

/// WP-15 synthetic engine rows from the checked-in capture: one row per card state, built only from wire fields the
/// producer emits. Shared by the headless state table below and the GUI-leg ring and hover checks.
enum WP15Rows {
    enum Member: String, CaseIterable {
        /// Fresh and tight: 5h 9 % forecast to run out in 40 m (reset in 2 h), weekly 42 %, today 6.8M and 2 running, 1 reset card.
        case tight
        /// A kept reading 30 minutes old (weekly 63 %, resets in 5d5h) after a refresh that did not land.
        case keptRecent
        /// The same kept reading three hours old.
        case keptOld
        /// A kept 5h reading whose window reset an hour ago.
        case keptReset
        /// macrevb-1051-1: a kept 5h reading taken 10 minutes before its window ended, but the producer states no reset time.
        case keptNoReset
        /// macrevb-1051-2: tight like `tight`, but its one reset card expired an hour ago.
        case tightExpiredReserve
        /// Enabled but unreadable: not signed in, no reading at all.
        case unread
        /// The first read is still running.
        case loading
        var ref: String {
            switch self {
            case .tight: return "1111111111111111"
            case .keptRecent: return "2222222222222222"
            case .keptOld: return "3333333333333333"
            case .keptReset: return "4444444444444444"
            case .unread: return "5555555555555555"
            case .loading: return "6666666666666666"
            case .keptNoReset: return "7777777777777777"
            case .tightExpiredReserve: return "8888888888888888"
            }
        }
        var name: String {
            switch self {
            case .tight: return "Tight"
            case .keptRecent: return "Kept recent"
            case .keptOld: return "Kept old"
            case .keptReset: return "Kept reset"
            case .unread: return "Unread"
            case .loading: return "Loading"
            case .keptNoReset: return "Kept no reset"
            case .tightExpiredReserve: return "Tight expired"
            }
        }
    }
    static let session = "session:18000:main:main", weekly = "weekly:604800:main:main"

    static func snapshot(_ members: [Member], base: Date) throws -> WireRowsSnapshot {
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: capture)) as? [String: Any])
        var projection = try XCTUnwrap(root["projection"] as? [String: Any])
        let template = try XCTUnwrap((projection["rows"] as? [[String: Any]])?.first)
        let accountTemplate = try XCTUnwrap((template["accounts"] as? [[String: Any]])?.first)
        let windowTemplate = try XCTUnwrap((accountTemplate["windows"] as? [[String: Any]])?.first)
        let stamp = { (d: Date) in ISO8601DateFormatter().string(from: d) }
        let refresh: [String: Any] = ["action": "refresh", "text": ["en": "Refresh when permitted", "zh": "在允许时刷新"], "availableAt": NSNull(), "disabledReason": NSNull()]
        func window(_ id: String, remaining: Double?, resets: Date?, observed: Date?, current: Bool) -> [String: Any] {
            var w = windowTemplate
            let weekly = id == Self.weekly
            w["id"] = id; w["role"] = weekly ? "weekly" : "session"; w["durationSeconds"] = weekly ? 604_800 : 18_000
            w["label"] = weekly ? ["en": "Weekly", "zh": "每周"] : ["en": "Session", "zh": "会话"]
            w["limitKey"] = "main"; w["poolKey"] = "main"; w.removeValue(forKey: "modelScope"); w["current"] = current
            if let remaining { w["remainingPercent"] = remaining } else { w.removeValue(forKey: "remainingPercent") }
            if let resets { w["resetsAt"] = stamp(resets); w["validUntil"] = stamp(resets) }
            else { w.removeValue(forKey: "resetsAt"); w.removeValue(forKey: "validUntil") }
            if let observed { w["observedAt"] = stamp(observed) } else { w.removeValue(forKey: "observedAt") }
            return w
        }
        var forecasts: [[String: Any]] = []
        func makeRow(_ order: Int, _ member: Member) -> [String: Any] {
            var row = template, account = accountTemplate
            row["id"] = member.rawValue.lowercased(); row["order"] = order + 1; row["vendorKey"] = "openai"
            row["name"] = ["en": member.name, "zh": member.name]; row["consent"] = "allowed"; row["surfaces"] = ["dock", "menu", "settings"]
            account["subscriptionRef"] = member.ref; account["accountLocator"] = member.ref; account["route"] = "runtime_rpc"
            account["lastFailure"] = NSNull(); account["plan"] = ["id": "pro", "name": ["en": "Pro", "zh": "Pro"]]
            for key in ["activity", "resetCards", "credits", "today"] { account.removeValue(forKey: key) }
            switch member {
            case .tight, .tightExpiredReserve:
                let observed = base.addingTimeInterval(-120)
                row["state"] = "fresh"; row["expiresAt"] = "2099-01-01T00:00:00Z"
                account["valueState"] = "current"; account["freshUntil"] = "2099-01-01T00:00:00Z"; account["observedAt"] = stamp(observed)
                account["windows"] = [window(Self.session, remaining: 9, resets: base.addingTimeInterval(7200), observed: observed, current: true),
                                      window(Self.weekly, remaining: 42, resets: base.addingTimeInterval(2 * 86_400 + 10 * 3600), observed: observed, current: true)]
                account["today"] = ["observedOutputTokens": 6_800_000, "runningSessions": 2, "bindingBasis": "source-wide-current-binding"]
                let cardAge: TimeInterval = member == .tightExpiredReserve ? -3600 : 30 * 3600
                let card = stamp(base.addingTimeInterval(cardAge))
                account["resetCards"] = ["state": "complete", "count": 1, "earliestExpiresAt": card,
                                         "items": [["id": String(repeating: "a", count: 64), "expiresAt": card]], "truncated": false,
                                         "sources": [["source": "codex-account", "observedAt": stamp(observed)]]]
                forecasts.append(["source": member.rawValue.lowercased(), "subscriptionRef": member.ref, "windowId": Self.session,
                                  "runsOutAt": stamp(base.addingTimeInterval(40 * 60)), "pace": "tight", "basis": "recent-rate",
                                  "observedAt": stamp(observed)])
            case .keptRecent, .keptOld, .keptReset, .keptNoReset:
                let keptAge: TimeInterval
                switch member {
                case .keptNoReset: keptAge = -10 * 60
                case .keptRecent: keptAge = -30 * 60
                case .keptOld: keptAge = -3 * 3600
                default: keptAge = -6 * 3600
                }
                let observed = base.addingTimeInterval(keptAge)
                row["state"] = "stale"; row["nextStep"] = refresh; row["expiresAt"] = NSNull(); row["stateAfterExpiry"] = NSNull()
                row["reason"] = ["code": "stale_reading", "text": ["en": "A retained reading is shown", "zh": "正在显示保留的旧读数"]]
                account["valueState"] = "retained"; account["observedAt"] = stamp(observed)
                if member == .keptNoReset {
                    account["freshUntil"] = NSNull()
                    account["windows"] = [window(Self.session, remaining: 30, resets: nil, observed: observed, current: false)]
                } else if member == .keptReset {
                    let reset = base.addingTimeInterval(-3600)
                    account["freshUntil"] = stamp(reset)
                    account["windows"] = [window(Self.session, remaining: 30, resets: reset, observed: observed, current: false)]
                } else {
                    let reset = base.addingTimeInterval(5 * 86_400 + 5 * 3600)
                    account["freshUntil"] = stamp(reset)
                    account["windows"] = [window(Self.weekly, remaining: 63, resets: reset, observed: observed, current: false)]
                    account["credits"] = ["balance": 3148, "unit": "credits"]
                }
            case .unread, .loading:
                row["state"] = member == .unread ? "failed" : "pending"
                let unread: [String: Any] = ["code": "not_signed_in", "text": ["en": "Not signed in", "zh": "未登录"]]
                let pending: [String: Any] = ["code": "not_read_yet", "text": ["en": "Not read yet", "zh": "尚未读取"]]
                row["reason"] = member == .unread ? unread : pending
                row["expiresAt"] = NSNull(); row["stateAfterExpiry"] = NSNull()
                account["valueState"] = "none"; account.removeValue(forKey: "observedAt"); account["freshUntil"] = NSNull()
                account["windows"] = [window(Self.session, remaining: nil, resets: nil, observed: nil, current: false)]
            }
            row["accounts"] = [account]
            return row
        }
        var rows: [[String: Any]] = []
        for (order, member) in members.enumerated() { rows.append(makeRow(order, member)) }
        projection["rows"] = rows
        projection["resetEvents"] = []
        projection["forecasts"] = forecasts
        root["projection"] = projection
        return try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: root))
    }
}

/// An engine that serves the WP-15 rows and counts the card's "重新读取" refresh requests.
actor WP15Engine: EngineClient {
    nonisolated func isCurrent(_ context: EngineDeliveryContext) -> Bool { true }
    let store: EngineStore, rows: WireRowsSnapshot
    let context = EngineDeliveryContext(sessionID: "wp15", floor: .init(storeEpoch: "wp15", generation: 1), revision: 1)
    private(set) var refreshes = 0
    init(store: EngineStore, rows: WireRowsSnapshot) { self.store = store; self.rows = rows }
    func start() async throws -> EngineDeliveryContext {
        await store.consume(.connection(.ready(context))); await store.consume(.context(context))
        let reply = try EngineReply(envelope: .init(sessionId: context.sessionID, storeEpoch: context.floor.storeEpoch,
            consentGeneration: 1, data: rows), delivery: context)
        await store.consume(.rowsChanged(reply, invalidRowCount: rows.projection.invalidRowCount))
        return context
    }
    func retry() async throws -> EngineDeliveryContext { try await start() }
    func stop() async {}
    func subscribeRows(timeout: Duration?) async throws -> EngineRequestCompletion { .init(requestID: .string("wp15-rows")) }
    func consent(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func grant(_ request: WireConsentGrantParams, userAction: EngineUserAction?, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func refresh(_ request: WireRefreshRequestParams, timeout: Duration?) async throws -> EngineRequestCompletion {
        refreshes += 1; throw EngineClientError.unsupportedCapability
    }
    func history(_ request: WireHistoryQueryParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func cockpit(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func publication(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func pluginInstall(_ request: WirePluginInstallParams, timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
    func diagnostics(timeout: Duration?) async throws -> EngineRequestCompletion { throw EngineClientError.unsupportedCapability }
}

/// WP-15 (V1-FINAL §1, §2, §12; D290 item 9): the widget ring's readout and the widget card for each state, through the
/// normal entry (real store, real provider, the host's proof check, the real card projection). Headless: no window.
/// Requirements: DOCK-3.3-09 (amended), DOCK-3.8-05/08/09 (amended), DOCK-3.2-50, DOCK-3.8-50, -51, -52, -53.
/// Reference: Pulse (qunqin24/Pulse v1.12.4) for the ring and the hover card; CodexBar `UsageMenuCardView` /
/// `UsageFormatter` for the card rows. Failing first on main: main shows "--" for every kept reading, a source and age in
/// the header, "-- · -- t/s" for an empty today, and no footer sentence.
@MainActor final class WP15WidgetCardStateTests: XCTestCase {
    private let base = Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970))

    private func launch(_ members: [WP15Rows.Member], language: SettingsLanguage = .english) async throws -> (EngineDockMenuApplication, WP15Engine?) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("wp15-card-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let settings = try await expandedWidgetSettingsStore(applicationSupport: root, preferredLanguages: ["en"])
        _ = try await settings.update { $0.language = language }
        let rows = try WP15Rows.snapshot(members, base: base)
        let wall = base
        var engine: WP15Engine?
        let app = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/not-launched"),
            applicationVersion: "synthetic", allowedEnvironment: [:]), settingsStore: settings, createsNativePanels: false,
            dockEnvironment: normalEntryTestEnvironment, deadlineNow: { wall },
            makeClient: { _, store in let value = WP15Engine(store: store, rows: rows); engine = value; return value },
            activateSettings: {})
        addTeardownBlock { @MainActor in app.composition.dock.close(); await app.composition.stop() }
        await app.prepare(); app.allowDockPresentation(); await app.composition.start()
        return (app, engine)
    }
    private func reading(_ app: EngineDockMenuApplication, _ member: WP15Rows.Member) throws -> DockInstrumentReading {
        let input = try XCTUnwrap(app.composition.presentedContent.snapshot.inputs.first { $0.id == member.ref }, "\(member) has a ring")
        return try DockInstrumentProjection.evaluate(input, now: base, redBelow: 25)
    }
    private func card(_ app: EngineDockMenuApplication, _ member: WP15Rows.Member) throws -> DockCardContent {
        try XCTUnwrap(app.composition.dock.cardContent(for: member.ref, at: base), "\(member) has a card")
    }

    /// DOCK-3.2-50 / DOCK-3.3-09 (amended): a kept reading stays on the ring, normal for an hour, then dim; "--" after its reset.
    func testRingKeepsAStaleReadingNormalForAnHourThenDimAndDashesAfterItsReset() async throws {
        let (app, _) = try await launch([.tight, .keptRecent, .keptOld, .keptReset])
        let recent = try reading(app, .keptRecent)
        XCTAssertEqual(recent.readout, "63%"); XCTAssertEqual(recent.status, .normal); XCTAssertFalse(recent.readoutDimmed)
        XCTAssertEqual(recent.dataState, .stale)
        let old = try reading(app, .keptOld)
        XCTAssertEqual(old.readout, "63%", "an old reading keeps its number"); XCTAssertEqual(old.status, .unknown); XCTAssertTrue(old.readoutDimmed)
        XCTAssertEqual(old.outer?.fraction ?? 0, 0.63, accuracy: 1e-9)
        let reset = try reading(app, .keptReset)
        XCTAssertEqual(reset.readout, "--", "a kept reading shows -- only once its window has reset")
        let tight = try reading(app, .tight)
        XCTAssertEqual(tight.readout, "9%"); XCTAssertEqual(tight.status, .critical)
        // V1-FINAL §12: kept readings never light a notice.
        let signals = app.composition.presentedContent.signals
        XCTAssertTrue(signals.filter { [WP15Rows.Member.keptRecent.ref, WP15Rows.Member.keptOld.ref].contains($0.id) }
            .allSatisfy { DockNoticeProjection.candidates(for: $0, at: base).isEmpty })
    }

    /// Master spec S2 / C30 (D474): the status menu's one alert line is the worst quota alert in the SHORT form, with
    /// the reset time; a normal subscription adds none.
    func testMenuAlertLineIsTheWorstShortSentence() async throws {
        for language in [SettingsLanguage.english, .chinese] {
            let (app, _) = try await launch([.tight, .keptRecent], language: language)
            let line = MenuAlertLine.text(app.composition.presentedContent, redBelow: 25, now: base, language: language)
            let expected = AlertSentence.quota(subscription: .init("Tight", "Tight"), window: language == .english ? .init("5h", "5h") : .init("5小时", "5小时"),
                                               remaining: 9, runOutMinutes: 40, resetMinutes: 120).short.value(language)
            XCTAssertEqual(line, expected)
            XCTAssertEqual(line, language == .english ? "Tight 5h 9% · est. 40m · resets 2h00" : "Tight 5小时 9% · 预估40m · 2h00后重置")
            let (calm, _) = try await launch([.keptRecent], language: language)
            XCTAssertNil(MenuAlertLine.text(calm.composition.presentedContent, redBelow: 25, now: base, language: language), "a kept reading never alerts")
        }
    }

    /// DOCK-3.8-50, -51, -52 (board-3 "快用完，而且有储备"), English and Chinese.
    func testTightCardHasAgeHeaderRunOutRowTodayHalvesBrightReserveAndTheAlertSentence() async throws {
        for language in [SettingsLanguage.english, .chinese] {
            let (app, _) = try await launch([.tight], language: language)
            let en = language == .english
            let content = try card(app, .tight)
            XCTAssertEqual(content.name, "Tight"); XCTAssertEqual(content.plan, "Pro")
            XCTAssertEqual(content.sourceAndAge, en ? "Updated 2 min ago" : "2 分钟前更新", "the header is only the age")
            XCTAssertEqual(content.stateLabel, "")
            let five = try XCTUnwrap(content.rows.first { $0.id == "quota:" + WP15Rows.session })
            XCTAssertEqual(five.value, "9%"); XCTAssertEqual(five.detail, en ? "out ~40m" : "约40m用完")
            XCTAssertTrue(five.emphasised, "the tightest row is lit"); XCTAssertEqual(five.tone, .critical)
            let week = try XCTUnwrap(content.rows.first { $0.id == "quota:" + WP15Rows.weekly })
            XCTAssertEqual(week.value, "42%"); XCTAssertEqual(week.detail, en ? "resets in 2d10h" : "2d10h 后重置"); XCTAssertFalse(week.emphasised)
            let today = try XCTUnwrap(content.rows.first { $0.id == "today" })
            XCTAssertEqual(today.label, en ? "Today" : "今日")
            XCTAssertEqual(today.value, "6.8M", "no ≈$ until WP-06"); XCTAssertEqual(today.detail, en ? "● 2 running" : "● 2 个在跑")
            let reserve = try XCTUnwrap(content.rows.first { $0.id == "reserve" })
            XCTAssertTrue(reserve.emphasised, "a usable reset brightens the reserve line under an alert")
            let order = content.rows.map(\.id)
            XCTAssertLessThan(try XCTUnwrap(order.firstIndex(of: "today")), try XCTUnwrap(order.firstIndex(of: "reserve")), "quota, today, reserve")
            // Master spec C2 (D474): the footer sentence is back in amber, red and used-up states; the 接下来 block sits above it.
            XCTAssertEqual(try XCTUnwrap(content.rows.first { $0.id == "next.0" }).value, en ? "Next" : "接下来")
            XCTAssertLessThan(try XCTUnwrap(order.firstIndex(of: "next.0")), order.count - 1, "接下来 above the footer")
            let footer = try XCTUnwrap(content.rows.last, "the alert sentence closes the card")
            XCTAssertEqual(footer.kind, .alert); XCTAssertEqual(footer.tone, .critical)
            let expected = AlertSentence.quota(subscription: .init("Tight", "Tight"), window: en ? .init("5h", "5h") : .init("5小时", "5小时"),
                                               remaining: 9, runOutMinutes: 40, resetMinutes: 120).text.value(language)
            XCTAssertEqual(footer.value, expected, "the footer is WP-11's one sentence")
            XCTAssertEqual(footer.value, en ? "Tight 5h 9% · est. out in 40m · resets in 2h00" : "Tight 5小时 9% · 预估 40m 用完 · 2h00 后重置")
            XCTAssertEqual(content.actionLabel, "")
            XCTAssertNoThrow(try content.validate())
        }
    }

    /// DOCK-3.8-50 / V1-FINAL §12 (board-3 "读数旧了"): values as normal, the age on the right, a quiet cause, no badge, no alert.
    func testKeptCardsShowTheirNumbersAndAgeWithoutBadgeOrAlert() async throws {
        let (app, _) = try await launch([.keptRecent, .keptOld, .keptReset], language: .chinese)
        let recent = try card(app, .keptRecent)
        XCTAssertEqual(recent.sourceAndAge, "30 分钟前更新"); XCTAssertEqual(recent.stateLabel, "")
        let week = try XCTUnwrap(recent.rows.first { $0.id == "quota:" + WP15Rows.weekly })
        XCTAssertEqual(week.value, "63%"); XCTAssertEqual(week.tone, .normal); XCTAssertEqual(week.detail, "5d5h 后重置")
        XCTAssertFalse(recent.rows.contains { $0.kind == .alert }, "a kept reading never alerts")
        XCTAssertEqual(recent.rows.first { $0.id == "kept-cause" }?.kind, .footnote)
        XCTAssertNil(recent.rows.first { $0.id == "today" }, "no today half: no today row, never -- · -- t/s")
        XCTAssertEqual(recent.actionLabel, "")
        let old = try card(app, .keptOld)
        XCTAssertEqual(old.sourceAndAge, "3 小时前更新", "x 小时前更新 after the first hour")
        let oldWeek = try XCTUnwrap(old.rows.first { $0.id == "quota:" + WP15Rows.weekly })
        XCTAssertEqual(oldWeek.value, "63%"); XCTAssertEqual(oldWeek.tone, .unknown, "dimmed")
        let reset = try card(app, .keptReset)
        XCTAssertEqual(reset.rows.first { $0.id == "quota:" + WP15Rows.session }?.value, "--")
        XCTAssertEqual(reset.rows.first { $0.id == "quota:" + WP15Rows.session }?.detail, "", "no reset text for a passed reset")
    }

    /// DOCK-3.2-50 + DOCK-3.8-53 (board-3 "读不到"): the ring keeps a dim "--"; the card says the cause, the one step and
    /// offers "重新读取", which asks the engine for one foreground refresh.
    func testUnreadableRingKeepsDashAndCardOffersCauseStepAndReadAgain() async throws {
        let (app, engine) = try await launch([.unread], language: .chinese)
        let ring = try reading(app, .unread)
        XCTAssertEqual(ring.readout, "--"); XCTAssertEqual(ring.status, .unknown)
        let content = try card(app, .unread)
        XCTAssertEqual(content.rows.first { $0.id == "cause" }?.value, "未登录")
        XCTAssertEqual(content.rows.first { $0.id == "cause" }?.kind, .event)
        XCTAssertEqual(content.rows.first { $0.id == "cause-step" }?.value, "打开 Unread 并登录")
        XCTAssertEqual(content.actionLabel, "重新读取")
        XCTAssertEqual(content.sourceAndAge, "未读取"); XCTAssertEqual(content.stateLabel, "")
        XCTAssertFalse(content.rows.contains { $0.kind == .alert })
        let requested = try XCTUnwrap(app.composition.dock.cardActionRequested, "the card action is wired")
        requested(WP15Rows.Member.unread.ref)
        var count = 0
        for _ in 0..<300 {
            count = await engine?.refreshes ?? 0
            if count > 0 { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(count, 1, "重新读取 is one foreground refresh")
    }

    /// DOCK-3.8-53 (board-3 "正在读"): only the row names and empty bars; no number, no "--", no today or reserve.
    func testLoadingCardIsRowNamesAndPlaceholderBlocksOnly() async throws {
        let (app, _) = try await launch([.loading])
        let content = try card(app, .loading)
        XCTAssertEqual(content.sourceAndAge, "Reading…")
        let rows = content.rows.filter { $0.kind == .quota || $0.kind == .extraQuota }
        XCTAssertFalse(rows.isEmpty)
        XCTAssertTrue(rows.allSatisfy { $0.value.isEmpty && $0.detail.isEmpty && $0.fillFraction == nil && !$0.label.isEmpty })
        XCTAssertEqual(content.rows.count, rows.count, "nothing but the window rows")
        XCTAssertEqual(content.actionLabel, "")
    }

    /// macrevb-1051-1: a kept reading needs a producer-stated reset; without one it must not be shown from a guessed end
    /// (reading time plus 5 h would show it for ~5 h after a real reset the producer never told us about).
    func testKeptReadingWithoutAProducerResetIsNotKept() async throws {
        let (app, _) = try await launch([.keptNoReset])
        let ring = try reading(app, .keptNoReset)
        XCTAssertNotEqual(ring.readout, "30%", "no guessed end: the old number is not carried")
        let session = try XCTUnwrap(try card(app, .keptNoReset).rows.first { $0.id == "quota:" + WP15Rows.session })
        XCTAssertNotEqual(session.value, "30%")
    }

    /// macrevb-1051-2: under an alert, a positive but expired reserve is labelled expired and is not the lit action.
    func testExpiredReserveIsNotBrightenedUnderAnAlert() async throws {
        let (app, _) = try await launch([.tight, .tightExpiredReserve])
        XCTAssertEqual(try card(app, .tight).rows.first { $0.id == "reserve" }?.emphasised, true, "a usable reset is lit")
        let content = try card(app, .tightExpiredReserve)
        XCTAssertTrue(content.rows.contains { $0.kind == .alert }, "master spec C2: the alert still shows")
        let reserve = try XCTUnwrap(content.rows.first { $0.id == "reserve" })
        XCTAssertTrue(reserve.detail.contains("expired"), reserve.detail)
        XCTAssertFalse(reserve.emphasised, "an expired reset is not the action to take")
    }
}
