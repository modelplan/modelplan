// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanDock
import ModelPlanWire
@testable import ModelPlanAppIntegration

/// D466 (calendar and time system, section 1, 2 and 5): one dot meaning on the widget, one news clock for every native
/// surface, a banked reset that only adds to the Reserve, and the card's "接下来" block.
final class D466CalendarWidgetTests: XCTestCase {
    private let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()
    private func at(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }

    // MARK: dot vocabulary

    private func signal(_ reset: DockResetSignal?) -> DockSubscriptionSignal {
        var s = DockSubscriptionSignal(id: "member"); s.dataState = .fresh; s.reset = reset
        return s
    }

    /// Only reset news draws a dot: hollow blue announced, solid blue confirmed. A forecast, a reserve about to expire and
    /// credits in use (the old amber and white dots) draw nothing.
    func testOnlyBlueResetNewsDrawsADot() {
        let now = at("2026-11-26T20:00:00Z")
        var s = signal(nil)
        s.forecast = .init(windowID: "5h", validUntil: now.addingTimeInterval(600))
        s.cards = [.init(id: "card", expiresAt: now.addingTimeInterval(3600))]
        s.drawingCredits = true; s.creditsKnown = true; s.exhaustedQuotaObserved = true; s.alert = .critical
        XCTAssertTrue(DockNoticeProjection.candidates(for: s, at: now).isEmpty, "amber and white dots are gone")

        s.reset = DockResetSignal(id: "e", status: .announced, announcedAt: now.addingTimeInterval(-60))
        var notice = DockNoticeProjection.selected(for: s, at: now)
        XCTAssertEqual(notice?.tone, .blue); XCTAssertEqual(notice?.shape, .hollow)
        XCTAssertEqual(DockNoticeProjection.candidates(for: s, at: now).count, 1)

        s.reset = DockResetSignal(id: "e", status: .confirmed, confirmedAt: now.addingTimeInterval(-60))
        notice = DockNoticeProjection.selected(for: s, at: now)
        XCTAssertEqual(notice?.tone, .blue); XCTAssertEqual(notice?.shape, .solid)
    }

    /// The menu-bar and sliver dots follow the same projection and clear on the first look.
    func testPointerSurfacesClearOnFirstLook() throws {
        let now = at("2026-11-26T20:00:00Z")
        var state = DockAttentionState()
        let s = signal(DockResetSignal(id: "e", status: .confirmed, confirmedAt: now.addingTimeInterval(-60)))
        var projection = try state.project([s], stationBySubscription: ["member": "one"], at: now)
        XCTAssertNotNil(projection.menuNotice); XCTAssertEqual(projection.dots.count, 1)
        try state.acknowledgeDockOpen([s], at: now)
        projection = try state.project([s], stationBySubscription: ["member": "one"], at: now)
        XCTAssertNil(projection.menuNotice); XCTAssertTrue(projection.dots.isEmpty)
    }

    // MARK: news clock (fake clock)

    private let key = DockNewsClock.key(eventID: "banked-1", status: "confirmed")

    func testNewsClockRetiresThirtyMinutesAfterTheFirstLook() {
        let confirmed = at("2026-11-26T08:29:00Z")
        var clock = DockNewsClock()
        XCTAssertTrue(clock.isLive(key, anchor: confirmed, at: confirmed), "never drawn: live")
        clock.tick(shown: [key], present: true, at: confirmed.addingTimeInterval(60))
        XCTAssertTrue(clock.isLive(key, anchor: confirmed, at: confirmed.addingTimeInterval(600)), "not looked at: stays")
        let looked = confirmed.addingTimeInterval(900)
        clock.look([key], at: looked)
        XCTAssertTrue(clock.hasBeenLooked(key))
        XCTAssertTrue(clock.isLive(key, anchor: confirmed, at: looked.addingTimeInterval(30 * 60 - 1)))
        XCTAssertFalse(clock.isLive(key, anchor: confirmed, at: looked.addingTimeInterval(30 * 60)), "30 min after the first look")
        clock.look([key], at: looked.addingTimeInterval(20 * 60))
        XCTAssertFalse(clock.isLive(key, anchor: confirmed, at: looked.addingTimeInterval(30 * 60)), "a second look does not extend it")
    }

    func testNewsClockCountsPresentHoursOnly() throws {
        let confirmed = at("2026-11-26T08:00:00Z")
        var clock = DockNewsClock()
        var now = confirmed
        clock.tick(shown: [key], present: true, at: now)
        // Ten minutes of refreshes while present, repeated: 3 h.
        for _ in 0..<18 { now = now.addingTimeInterval(600); clock.tick(shown: [key], present: true, at: now) }
        XCTAssertEqual(try XCTUnwrap(clock.entries[key]).presentSeconds, 3 * 3600, accuracy: 0.001)
        XCTAssertFalse(clock.isLive(key, anchor: confirmed, at: now), "3 present hours")
    }

    func testNewsClockSkipsLockedAndSleptTime() throws {
        let confirmed = at("2026-11-26T08:00:00Z")
        var clock = DockNewsClock()
        clock.tick(shown: [key], present: true, at: confirmed)
        // Locked for two hours: not counted.
        clock.tick(shown: [key], present: false, at: confirmed.addingTimeInterval(7200))
        XCTAssertEqual(try XCTUnwrap(clock.entries[key]).presentSeconds, 0, accuracy: 0.001)
        // A long gap with no refresh (sleep) counts at most one refresh interval.
        clock.tick(shown: [key], present: true, at: confirmed.addingTimeInterval(7260))
        clock.tick(shown: [key], present: true, at: confirmed.addingTimeInterval(7260 + 5 * 3600))
        XCTAssertEqual(try XCTUnwrap(clock.entries[key]).presentSeconds, DockNewsClock.maxCountedGap, accuracy: 0.001)
        XCTAssertTrue(clock.isLive(key, anchor: confirmed, at: confirmed.addingTimeInterval(7260 + 5 * 3600)))
    }

    func testNewsClockHardCapIsTwentyFourHoursAfterTheAnchor() {
        let confirmed = at("2026-11-26T08:00:00Z")
        var clock = DockNewsClock()
        clock.tick(shown: [key], present: true, at: confirmed)
        XCTAssertTrue(clock.isLive(key, anchor: confirmed, at: confirmed.addingTimeInterval(24 * 3600 - 1)))
        XCTAssertFalse(clock.isLive(key, anchor: confirmed, at: confirmed.addingTimeInterval(24 * 3600)))
    }

    func testNewsClockIsCodableAndAStoreSurvivesARestart() throws {
        let confirmed = at("2026-11-26T08:00:00Z")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("news-clock-" + UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = DockNewsClockStore(url: url)
        store.tick(shown: [key], present: true, at: confirmed)
        store.look([key], at: confirmed.addingTimeInterval(120))
        let reopened = DockNewsClockStore(url: url)
        XCTAssertTrue(reopened.clock.hasBeenLooked(key), "the first look is persisted")
        XCTAssertFalse(reopened.isLive(key, anchor: confirmed, at: confirmed.addingTimeInterval(120 + 30 * 60)))
    }

    /// The retired clock removes the dot (the card block and alert row read the same `newsLive`).
    func testRetiredClockRemovesTheDot() {
        let now = at("2026-11-26T20:00:00Z")
        var reset = DockResetSignal(id: "banked-1", status: .confirmed, confirmedAt: now.addingTimeInterval(-60))
        reset.kind = .resetCredit
        XCTAssertEqual(reset.newsKey, key)
        XCTAssertNotNil(DockNoticeProjection.selected(for: signal(reset), at: now))
        reset.newsLive = false
        XCTAssertNil(DockNoticeProjection.selected(for: signal(reset), at: now))
    }

    // MARK: a banked reset is not a window reset

    func testBankedResetNeverWaitsForAWindowRestart() {
        let now = at("2026-11-26T20:00:00Z")
        var banked = DockResetSignal(id: "banked-1", status: .confirmed, confirmedAt: now.addingTimeInterval(-60))
        banked.kind = .resetCredit
        banked.restartedReading = true
        XCTAssertFalse(banked.readingRetiresDot, "a reading is no evidence for a banked reset")
        XCTAssertNotNil(DockNoticeProjection.selected(for: signal(banked), at: now), "only the news clock retires it")
        var direct = banked; direct.kind = .directReset
        XCTAssertTrue(direct.readingRetiresDot)
        XCTAssertNil(DockNoticeProjection.selected(for: signal(direct), at: now), "a direct limit reset is cleared by a restarted window")
    }

    func testBankedConfirmationWordsAddToTheReserve() throws {
        let event = EngineResetEvent(id: "banked-1", rowID: "codex", provider: "openai", status: "confirmed",
            publishedAt: at("2026-11-26T08:00:00Z"), expiresAt: at("2026-11-27T08:29:00Z"), planIDs: nil, confirms: "banked-1",
            kind: "reset_credit", confirmedAt: at("2026-11-26T00:29:00Z"), confirmedAtBasis: "firstSeen")
        let now = at("2026-11-26T09:11:00Z")
        let zh = EngineResetEventWording(english: false, calendar: utc), en = EngineResetEventWording(english: true, calendar: utc)
        XCTAssertEqual(zh.title(event, now: now), "已确认 · 今天 00:29", "an absolute time, never \"09:11 前\"")
        XCTAssertEqual(en.title(event, now: now), "Confirmed · Today 00:29")
        XCTAssertEqual(zh.bankedConfirmedDetail(event, now: now), "今天 00:29 发放，你多了 1 次重置，已在储备里")
        XCTAssertEqual(en.bankedConfirmedDetail(event, now: now), "Issued today 00:29: +1 reset, now in Reserve")
        XCTAssertFalse(event.restartedReading(in: try restartedAccount(after: event)), "a banked reset is never a window reset")
    }

    private func restartedAccount(after event: EngineResetEvent) throws -> RowsAccount {
        let capture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../../schema/app-cli/captures/WireRowsSnapshot.json").standardizedFileURL
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: capture)) as? [String: Any])
        let projection = try XCTUnwrap(root["projection"] as? [String: Any])
        var raw = try XCTUnwrap(((projection["rows"] as? [[String: Any]])?.first?["accounts"] as? [[String: Any]])?.first)
        var window = try XCTUnwrap((raw["windows"] as? [[String: Any]])?.first)
        let confirmed = event.confirmedAt ?? event.publishedAt, iso = ISO8601DateFormatter()
        window.removeValue(forKey: "modelScope"); window["current"] = true; window["durationSeconds"] = 18000
        window["observedAt"] = iso.string(from: confirmed.addingTimeInterval(120))
        window["resetsAt"] = iso.string(from: confirmed.addingTimeInterval(60 + 18000))
        raw["valueState"] = "current"; raw["windows"] = [window]
        return try WireDecoder.decode(RowsAccount.self, from: JSONSerialization.data(withJSONObject: raw))
    }

    // MARK: the card's 接下来 block

    func testNextBlockInWordsOffPeakNow() {
        let now = at("2026-11-26T20:00:00Z")
        let facts = [DockNextFact(kind: .fiveHourReset, at: at("2026-11-26T21:04:00Z")),
                     DockNextFact(kind: .weeklyReset, at: at("2026-12-02T05:42:00Z"))]
        let peaks = [DockPeakWindow(from: at("2026-11-26T22:00:00Z"), to: at("2026-11-27T02:00:00Z"))]
        let zh = DockNextBlock.rows(facts: facts, peaks: peaks, hasPeakRules: true, now: now, english: false, calendar: utc).map(\.value)
        XCTAssertEqual(zh, ["接下来 · 现在闲时", "21:04 5 小时额度重置", "22:00–02:00 高峰"])
        let en = DockNextBlock.rows(facts: facts, peaks: peaks, hasPeakRules: true, now: now, english: true, calendar: utc).map(\.value)
        XCTAssertEqual(en, ["Next · Off-peak now", "21:04 5-hour reset", "22:00–02:00 Peak"])
    }

    func testNextBlockInPeakAndRunOutAndTomorrow() {
        let now = at("2026-11-26T23:00:00Z")
        let facts = [DockNextFact(kind: .runOut, at: at("2026-11-27T01:30:00Z")),
                     DockNextFact(kind: .fiveHourReset, at: at("2026-11-27T05:00:00Z"))]
        let peaks = [DockPeakWindow(from: at("2026-11-26T22:00:00Z"), to: at("2026-11-27T02:00:00Z"))]
        let zh = DockNextBlock.rows(facts: facts, peaks: peaks, hasPeakRules: true, now: now, english: false, calendar: utc).map(\.value)
        XCTAssertEqual(zh, ["接下来 · 高峰中 · 02:00 结束", "明天 01:30 预计用完", "明天 05:00 5 小时额度重置"])
    }

    func testNextBlockWithNothingIn24HoursListsTheNextTwoAfter() {
        let now = at("2026-11-26T20:00:00Z")
        let facts = [DockNextFact(kind: .weeklyReset, at: at("2026-12-02T05:42:00Z")),
                     DockNextFact(kind: .monthlyReset, at: at("2026-12-20T00:00:00Z")),
                     DockNextFact(kind: .fiveHourReset, at: at("2026-11-28T05:00:00Z"))]
        let zh = DockNextBlock.rows(facts: facts, peaks: [], hasPeakRules: false, now: now, english: false, calendar: utc).map(\.value)
        XCTAssertEqual(zh, ["接下来", "24 小时内没有重置，也没有高峰", "之后 周六 05:00 5 小时额度重置", "之后 周三 05:42 每周额度重置"])
        let en = DockNextBlock.rows(facts: facts, peaks: [], hasPeakRules: false, now: now, english: true, calendar: utc).map(\.value)
        XCTAssertEqual(en, ["Next", "Nothing in the next 24 h", "Later Sat 05:00 5-hour reset", "Later Wed 05:42 weekly reset"])
    }

    func testNextBlockIsEmptyWhenNothingIsKnown() {
        XCTAssertTrue(DockNextBlock.rows(facts: [], peaks: [], hasPeakRules: false, now: at("2026-11-26T20:00:00Z"), english: true, calendar: utc).isEmpty)
    }

    /// The card row reads the same windows, reset times and run-out forecast as the quota rows above it.
    func testCardRowBuildsTheBlockFromItsWindows() throws {
        let now = at("2026-11-26T20:00:00Z")
        var input = DockInstrumentInput(id: "member", name: "Codex", windows: [
            .init(id: "five", period: .fiveHour, label: "5h", remainingPercent: 40, resetsAt: at("2026-11-26T21:04:00Z"), durationSeconds: 18000),
            .init(id: "week", period: .week, label: "Weekly", remainingPercent: 60, resetsAt: at("2026-12-02T05:42:00Z"), durationSeconds: 604800)])
        input.dataState = .fresh
        var row = DockContentRow(input: input, reason: "", nextStep: "", runOutTimes: ["week": at("2026-11-26T23:30:00Z")])
        row.peaks = [DockPeakWindow(from: at("2026-11-26T22:00:00Z"), to: at("2026-11-27T02:00:00Z"))]
        row.hasPeakRules = true
        let values = row.cardNextRows(at: now, english: false, calendar: utc).map(\.value)
        XCTAssertEqual(values, ["接下来 · 现在闲时", "21:04 5 小时额度重置", "22:00–02:00 高峰", "23:30 预计用完"])
        XCTAssertTrue(row.cardNextRows(at: now, english: false, calendar: utc).allSatisfy { $0.kind == .event })
    }
}
