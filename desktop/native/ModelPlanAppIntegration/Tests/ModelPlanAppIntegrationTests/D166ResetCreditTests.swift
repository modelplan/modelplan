// SPDX-License-Identifier: MIT
import Foundation
import XCTest
import ModelPlanDock
import ModelPlanWire
@testable import ModelPlanAppIntegration

/// D166: public Codex reset credits and direct resets reach the widget. A forecast is an amber ring with its
/// expected window, a confirmation a green dot with its time for three hours; the balance is the local reading.
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
        XCTAssertEqual(notice.tone, .amber); XCTAssertEqual(notice.shape, .hollow)
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

    /// The confirmed dot is green for three hours after the confirmation, inside a 24-hour hard cap.
    func testConfirmedDotLifetime() throws {
        let confirmed = at("2026-11-12T10:20:00Z")
        var signal = DockSubscriptionSignal(id: "member"); signal.dataState = .fresh
        var reset = DockResetSignal(id: "event", status: .confirmed, confirmedAt: confirmed, expiresAt: confirmed.addingTimeInterval(24 * 3600))
        reset.kind = .resetCredit; signal.reset = reset
        let notice = try XCTUnwrap(DockNoticeProjection.selected(for: signal, at: confirmed.addingTimeInterval(60)))
        XCTAssertEqual(notice.tone, .green); XCTAssertEqual(notice.shape, .solid)
        XCTAssertNotNil(DockNoticeProjection.selected(for: signal, at: confirmed.addingTimeInterval(3 * 3600 - 1)))
        XCTAssertNil(DockNoticeProjection.selected(for: signal, at: confirmed.addingTimeInterval(3 * 3600)))
        signal.reset?.confirmedDotUntil = confirmed.addingTimeInterval(40 * 3600)
        XCTAssertNil(DockNoticeProjection.selected(for: signal, at: confirmed.addingTimeInterval(24 * 3600)), "hard cap")
        let event = EngineResetEvent(id: "event", rowID: "codex", provider: "openai", status: "confirmed",
            publishedAt: confirmed.addingTimeInterval(-3600), expiresAt: confirmed.addingTimeInterval(24 * 3600), planIDs: nil,
            confirms: "event", kind: "reset_credit", confirmedAt: confirmed, confirmedAtBasis: "published")
        XCTAssertEqual(EngineResetEventWording(english: true, calendar: shanghai).title(event, now: confirmed), "Confirmed · 18:20")
    }
}
