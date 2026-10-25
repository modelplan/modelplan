// SPDX-License-Identifier: MIT
import Foundation
@testable import ModelPlanInstruments

// Synthetic contract examples, independent of accounts and production scoring/calibration.
enum Fixtures {
    static let now = ISO8601DateFormatter().date(from: "2026-10-20T21:05:00Z")!
    static func instant(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
    static func calendar(_ zone: String = "America/Los_Angeles") -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }
    static func metric(_ value: Double?, _ basis: String = "synthetic") -> PublishedMetric { .init(value, basis: basis) }
    static let efforts: [InstrumentEffort] = [
        .init(key: "low", label: "Low", ability: metric(40), cost: metric(1), time: metric(60)),
        .init(key: "medium", label: "Med", ability: metric(50), cost: metric(2), time: metric(80)),
        .init(key: "high", label: "High", ability: metric(60), cost: metric(3), time: metric(100)),
        .init(key: "max", label: "Max", ability: metric(75), cost: metric(8.4), time: metric(150)),
    ]
    static func model(current: EffortConfiguration? = .init("high"), rec: String = "medium", tier: InstrumentFastTier? = nil,
                      efforts: [InstrumentEffort] = efforts, id: String = "model", older: Bool = false) -> InstrumentModel {
        .init(id: id, name: id, efforts: efforts, recommended: rec, current: current, fastTier: tier, olderVersion: older)
    }
    static func quota(_ id: String, _ period: QuotaPeriod, _ remaining: Double?, scope: String? = nil) -> InstrumentQuota {
        .init(id: id, period: period, scope: scope, remaining: remaining, resetsAt: now.addingTimeInterval(3600), durationMinutes: 300)
    }
    static func column(_ id: String, caution: QuotaLevel = .unknown, tokens: Double? = 0) -> EngineColumn {
        .init(id: id, quotas: .init(windows: [], now: now), todayTokens: tokens, todayGenerationTPS: nil, caution: caution)
    }
    static func session(_ id: String, running: Bool = true, rate: Double? = 58, project: String = "Example",
                        lastAt: Date = now, endedAt: Date? = nil, sub: String? = "a") -> InstrumentSession {
        .init(id: id, subscriptionID: sub, tool: "Claude Code", model: "model", effort: "high", projectID: "p", projectName: project,
              startedAt: now.addingTimeInterval(-600), endedAt: endedAt, lastAt: lastAt, running: running,
              rate: .init(value: rate, lastAt: lastAt, samples: 5, validSession60s: true))
    }
}
