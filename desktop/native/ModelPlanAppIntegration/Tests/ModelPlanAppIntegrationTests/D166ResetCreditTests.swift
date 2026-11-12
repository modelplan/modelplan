// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanDock
import ModelPlanWire
import ModelPlanSettings
@testable import ModelPlanAppIntegration

/// D166: public Codex reset credits and direct resets reach the widget. A forecast is a hollow ring with its
/// expected window, a confirmation a solid dot with its time for three hours (colours per `DockNotice.resetPalette`);
/// the balance is the local reading.
final class D166ResetCreditTests: XCTestCase {
    private let shanghai: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }()
    private func at(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }

    /// The event exactly as CLI v0.5.59+ projects the live 2026-11-11 publication record (date-precision
    /// schedule, no confirmation time), decoded by the production decoder.
    private func liveShapedRows(_ overrides: [String: Any] = [:]) throws -> WireRowsSnapshot {
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: capture)) as? [String: Any])
        var projection = try XCTUnwrap(root["projection"] as? [String: Any])
        var event: [String: Any] = ["version": 1, "id": "banked-2120410480204525936-1-1", "provider": "openai", "rowId": "codex",
            "status": "announced", "kind": "reset_credit", "publishedAt": "2026-11-11T06:57:08Z", "expiresAt": "2026-11-13T08:00:00Z",
            "schedule": ["precision": "date", "from": "2026-11-12T08:00:00Z", "through": "2026-11-13T08:00:00Z"],
            "source": ["kind": "publication", "publicationId": "0123456789abcdef01234567", "links": [
                ["type": "aihot", "url": "https://aihot.news/codex-reset"],
                ["type": "original", "url": "https://x.com/thsottiaux/status/2120410480204525936"]]]]
        for (key, value) in overrides { event[key] = value is NSNull ? nil : value }
        projection["resetEvents"] = [event]
        root["projection"] = projection
        return try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: root))
    }
    private func decoded(_ rows: WireRowsSnapshot) throws -> EngineResetEvent {
        guard case .available(let events) = EngineRowsEventDecoder.decode(rows) else { XCTFail("events absent"); throw CocoaError(.coderInvalidValue) }
        XCTAssertEqual(events.count, 1, "the live-shaped event must decode")
        return try XCTUnwrap(events.first)
    }

    func testLiveShapedResetCreditForecast() throws {
        let event = try decoded(liveShapedRows())
        XCTAssertTrue(event.isResetCredit)
        XCTAssertEqual(event.status, "announced")
        XCTAssertNil(event.confirmedAt)
        XCTAssertEqual(event.schedulePrecision, "date")
        let zh = EngineResetEventWording(english: false, calendar: shanghai), en = EngineResetEventWording(english: true, calendar: shanghai)
        let before = at("2026-11-11T20:00:00Z")
        XCTAssertEqual(zh.label(event), "↺ 额外重置")
        XCTAssertEqual(en.label(event), "↺ Extra resets")
        XCTAssertEqual(zh.title(event, now: before), "预计 11月12日–11月13日 之间")
        XCTAssertEqual(en.title(event, now: before), "Expected between Nov 12 and Nov 13")
        XCTAssertEqual(zh.detail(rose: false), "余量以本机读数为准")
        XCTAssertEqual(zh.title(event, now: at("2026-11-13T08:00:00Z")), "等待确认")
        XCTAssertEqual(en.title(event, now: at("2026-11-13T08:00:00Z")), "Awaiting confirmation")
        for text in [zh.label(event), zh.title(event, now: before), en.label(event), en.title(event, now: before)] {
            XCTAssertFalse(text.contains("重置卡") || text.lowercased().contains("reset card"), "LBL-2.2-11: \(text)")
        }

        var signal = DockSubscriptionSignal(id: "member"); signal.dataState = .fresh
        var reset = DockResetSignal(id: event.id, status: .announced, announcedAt: event.publishedAt,
                                    scheduledThrough: event.expiresAt, expiresAt: event.expiresAt)
        reset.kind = .resetCredit; signal.reset = reset
        let notice = try XCTUnwrap(DockNoticeProjection.selected(for: signal, at: before))
        XCTAssertEqual(notice.tone, DockNotice.resetAnnouncedTone); XCTAssertEqual(notice.shape, .hollow)
        XCTAssertNil(DockNoticeProjection.selected(for: signal, at: event.expiresAt))
    }

    func testConfirmedResetCreditAndDirectReset() throws {
        let confirmedAt = "2026-11-12T10:20:00Z"
        let base: [String: Any] = ["status": "confirmed", "confirms": "banked-2120410480204525936-1-1", "schedule": NSNull(),
                                   "confirmedAt": confirmedAt, "confirmedAtBasis": "observed", "expiresAt": "2026-11-13T10:20:00Z"]
        let credit = try decoded(liveShapedRows(base))
        XCTAssertEqual(credit.confirmedAt, at(confirmedAt))
        XCTAssertEqual(credit.confirmedAtBasis, "observed")
        let zh = EngineResetEventWording(english: false, calendar: shanghai), en = EngineResetEventWording(english: true, calendar: shanghai)
        let now = at("2026-11-12T11:00:00Z")
        XCTAssertEqual(zh.title(credit, now: now), "已确认 · 18:20")
        XCTAssertEqual(en.title(credit, now: now), "Confirmed · 18:20")
        XCTAssertEqual(zh.notification(credit, rose: false).title, "Codex 额外重置已确认")
        XCTAssertEqual(zh.notification(credit, rose: false).body, "余量以本机读数为准。")

        var direct = base; direct["kind"] = "direct_reset"; direct["confirmedAtBasis"] = "firstSeen"
        let reset = try decoded(liveShapedRows(direct))
        XCTAssertFalse(reset.isResetCredit)
        XCTAssertEqual(zh.label(reset), "↺ 额度重置")
        XCTAssertEqual(zh.title(reset, now: now), "已确认 · 18:20 前", "a first-seen time is only an upper bound")
        XCTAssertEqual(en.title(reset, now: now), "Confirmed by 18:20")
        XCTAssertEqual(en.notification(reset, rose: true).title, "Codex limit reset confirmed")
        XCTAssertEqual(zh.notification(reset, rose: true).body, "已生效：本机读数已回升。")
        XCTAssertEqual(zh.detail(rose: true), "本机读数已回升 · 余量以本机读数为准")

        // Older producers: no kind is a direct reset; no confirmation time falls back to publishedAt.
        var legacy = base; legacy["kind"] = NSNull(); legacy["confirmedAt"] = NSNull(); legacy["confirmedAtBasis"] = NSNull()
        let old = try decoded(liveShapedRows(legacy))
        XCTAssertFalse(old.isResetCredit); XCTAssertNil(old.confirmedAt)
        XCTAssertEqual(zh.title(old, now: at("2026-11-12T11:00:00Z")), "已确认 · 11月11日 14:57")
    }

    /// The confirmed dot shows for three hours after the confirmation, inside a 24-hour hard cap.
    func testConfirmedDotLifetime() throws {
        let confirmed = at("2026-11-12T10:20:00Z")
        var signal = DockSubscriptionSignal(id: "member"); signal.dataState = .fresh
        var reset = DockResetSignal(id: "event", status: .confirmed, confirmedAt: confirmed, expiresAt: confirmed.addingTimeInterval(24 * 3600))
        reset.kind = .resetCredit; signal.reset = reset
        let notice = try XCTUnwrap(DockNoticeProjection.selected(for: signal, at: confirmed.addingTimeInterval(60)))
        XCTAssertEqual(notice.tone, DockNotice.resetConfirmedTone); XCTAssertEqual(notice.shape, .solid)
        XCTAssertNotNil(DockNoticeProjection.selected(for: signal, at: confirmed.addingTimeInterval(3 * 3600 - 1)))
        XCTAssertNil(DockNoticeProjection.selected(for: signal, at: confirmed.addingTimeInterval(3 * 3600)))
        signal.reset?.confirmedDotUntil = confirmed.addingTimeInterval(40 * 3600)
        XCTAssertNil(DockNoticeProjection.selected(for: signal, at: confirmed.addingTimeInterval(24 * 3600)), "hard cap")
        let event = EngineResetEvent(id: "event", rowID: "codex", provider: "openai", status: "confirmed",
            publishedAt: confirmed.addingTimeInterval(-3600), expiresAt: confirmed.addingTimeInterval(24 * 3600), planIDs: nil,
            confirms: "event", kind: "reset_credit", confirmedAt: confirmed, confirmedAtBasis: "published")
        XCTAssertEqual(EngineResetEventWording(english: true, calendar: shanghai).title(event, now: confirmed), "Confirmed · 18:20")
    }

    /// macrev2-862-3: a routine refresh of a window that began before the confirmation is not a restart;
    /// only a current window that began after it is. Reset credits never claim one.
    func testRestartedReadingNeedsAWindowThatBeganAfterTheConfirmation() throws {
        let confirmed = at("2026-11-12T10:00:00Z")
        func account(observed: Date, resets: Date, duration: Int64 = 18000) throws -> RowsAccount {
            let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
                .appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
            let root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: capture)) as? [String: Any])
            let projection = try XCTUnwrap(root["projection"] as? [String: Any])
            var raw = try XCTUnwrap(((projection["rows"] as? [[String: Any]])?.first?["accounts"] as? [[String: Any]])?.first)
            var window = try XCTUnwrap((raw["windows"] as? [[String: Any]])?.first)
            let iso = ISO8601DateFormatter()
            window.removeValue(forKey: "modelScope"); window["current"] = true; window["durationSeconds"] = duration
            window["observedAt"] = iso.string(from: observed); window["resetsAt"] = iso.string(from: resets)
            raw["valueState"] = "current"; raw["windows"] = [window]
            return try WireDecoder.decode(RowsAccount.self, from: JSONSerialization.data(withJSONObject: raw))
        }
        let direct = EngineResetEvent(id: "e", rowID: "codex", provider: "openai", status: "confirmed", publishedAt: confirmed.addingTimeInterval(-3600),
            expiresAt: confirmed.addingTimeInterval(86400), planIDs: nil, confirms: "e", kind: "direct_reset", confirmedAt: confirmed, confirmedAtBasis: "published")
        let credit = EngineResetEvent(id: "e", rowID: "codex", provider: "openai", status: "confirmed", publishedAt: confirmed.addingTimeInterval(-3600),
            expiresAt: confirmed.addingTimeInterval(86400), planIDs: nil, confirms: "e", kind: "reset_credit", confirmedAt: confirmed, confirmedAtBasis: "published")
        // 10:01 refresh of the window that ends at 14:00 (began 09:00): unchanged quota, no claim.
        let routine = try account(observed: confirmed.addingTimeInterval(60), resets: confirmed.addingTimeInterval(4 * 3600))
        XCTAssertFalse(direct.restartedReading(in: routine), "a routine refresh is not a restart")
        // A window that began at 10:01, read at 10:02: a restart.
        let restarted = try account(observed: confirmed.addingTimeInterval(120), resets: confirmed.addingTimeInterval(60 + 18000))
        XCTAssertTrue(direct.restartedReading(in: restarted))
        XCTAssertFalse(credit.restartedReading(in: restarted), "extra resets wait for the user to redeem them")
        let zh = EngineResetEventWording(english: false, calendar: shanghai)
        XCTAssertEqual(zh.notification(direct, rose: direct.restartedReading(in: routine)).body, "余量以本机读数为准。")
    }

    /// macrev2-862-2 / -5: a reset credit through the normal entry: forecast card and ring with no notification,
    /// "awaiting confirmation" after the window on the existing deadline path, then confirmed in place once.
    @MainActor func testNormalEntryResetCreditForecastAwaitingAndConfirmation() async throws {
        let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../../schema/app-cli/proposals/fixtures/app-journey-plan-scoped.json").standardizedFileURL
        let document = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: fixture)) as? [String: Any])
        var data = try XCTUnwrap((document["result"] as? [String: Any])?["data"] as? [String: Any])
        var projection = try XCTUnwrap(data["projection"] as? [String: Any])
        var events = try XCTUnwrap(projection["resetEvents"] as? [[String: Any]])
        let iso = ISO8601DateFormatter(), start = Date()
        var clock = start
        let through = start.addingTimeInterval(3600)
        events[0]["kind"] = "reset_credit"
        events[0]["publishedAt"] = iso.string(from: start.addingTimeInterval(-7200))
        events[0]["schedule"] = ["precision": "window", "from": iso.string(from: start.addingTimeInterval(-3600)), "through": iso.string(from: through)]
        events[0]["expiresAt"] = iso.string(from: through.addingTimeInterval(86400))
        projection["resetEvents"] = events; S4QuotaJourney.restoreDockSurface(&projection); data["projection"] = projection
        let forecast = try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: data))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("d166-862-credit-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try SettingsStore(url: directory.appendingPathComponent("settings.json"))
        try await store.update { $0.language = .english; $0.notifications.optedIn = true; $0.notifications.kinds = [.official] }
        let entry = EngineRowsEntry.make(configuration: .init(executableURL: URL(fileURLWithPath: "/synthetic/never-launched"),
            applicationVersion: "d166-862", allowedEnvironment: [:], offline: true, readOnly: true),
            settingsStore: store, createsNativePanels: false, cockpitEntryEnabled: true,
            makeClient: { _, store in S4RowsClient(store: store, rows: forecast) },
            isolatedResetNotificationLedger: directory.appendingPathComponent("ledger-862.json"), activateSettings: {})
        entry.composition.currentDate = { clock }
        var titles: [String] = []
        entry.composition.setResetNotificationDelivery { _, title in titles.append(title) }
        await entry.prepare(); await entry.composition.start()
        defer { entry.composition.dock.close() }
        let member = "0123456789abcdef", id = try XCTUnwrap(events[0]["id"] as? String)
        func notice() throws -> DockCardRow? {
            entry.composition.dock.refreshDockContent()
            return try entry.composition.dock.cardContent(for: member)?.rows.first { $0.id.hasPrefix("reset-event:" + id) }
        }
        var row = try XCTUnwrap(notice())
        XCTAssertEqual(row.label, "↺ Extra resets")
        XCTAssertTrue(row.value.hasPrefix("Expected between"), row.value)
        XCTAssertEqual(entry.composition.resetSignals.first { $0.id == member }?.reset?.status, .announced)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(titles, [], "a forecast never notifies")

        clock = through.addingTimeInterval(60)
        row = try XCTUnwrap(notice(), "the forecast stays after its window, awaiting confirmation")
        XCTAssertEqual(row.value, "Awaiting confirmation")
        XCTAssertNotNil(DockNoticeProjection.selected(for: try XCTUnwrap(entry.composition.resetSignals.first { $0.id == member }), at: clock),
                        "the ring stays while it awaits confirmation")
        XCTAssertEqual(titles, [])

        let confirmedAt = clock.addingTimeInterval(-30)
        events[0]["status"] = "confirmed"; events[0]["confirms"] = id; events[0].removeValue(forKey: "schedule")
        events[0]["confirmedAt"] = iso.string(from: confirmedAt); events[0]["confirmedAtBasis"] = "observed"
        events[0]["expiresAt"] = iso.string(from: confirmedAt.addingTimeInterval(86400))
        projection["resetEvents"] = events; data["projection"] = projection
        let confirmed = try WireDecoder.decode(WireRowsSnapshot.self, from: JSONSerialization.data(withJSONObject: data))
        let client = try XCTUnwrap(entry.composition.client as? S4RowsClient)
        try await client.replaceRows(confirmed)
        for _ in 0..<100 where titles.isEmpty { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(titles, ["Codex extra resets confirmed"])
        row = try XCTUnwrap(notice())
        XCTAssertTrue(row.value.hasPrefix("Confirmed · "), row.value)
        XCTAssertEqual(row.detail, "Your balance is the local reading")
        let signal = try XCTUnwrap(entry.composition.resetSignals.first { $0.id == member })
        XCTAssertEqual(DockNoticeProjection.selected(for: signal, at: clock)?.tone, DockNotice.resetConfirmedTone)
        XCTAssertNil(DockNoticeProjection.selected(for: signal, at: confirmedAt.addingTimeInterval(3 * 3600)), "the dot ends three hours after confirmation")
        try await client.replaceRows(confirmed); try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(titles.count, 1, "one notification per confirmation")
        await entry.composition.stop()
    }
}
