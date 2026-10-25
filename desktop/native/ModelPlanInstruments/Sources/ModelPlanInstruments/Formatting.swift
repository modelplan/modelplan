// SPDX-License-Identifier: MIT
import Foundation

public enum InstrumentLanguage: Sendable { case chinese, english }

/// Explicit language and clock inputs: no system locale, time zone or wall clock reads.
public struct InstrumentFormat: Sendable {
    public let language: InstrumentLanguage
    public init(_ language: InstrumentLanguage) { self.language = language }

    public func duration(minutes: Double?) -> String {
        guard let minutes = known(minutes), minutes < Double(Int.max / 2) else { return "--" }
        let m = Int(minutes.rounded())
        if m < 60 { return "\(m)m" }
        if m < 1440 { return String(format: "%dh%02d", m / 60, m % 60) }
        return "\(m / 1440)d\((m % 1440) / 60)h"
    }

    public func future(_ date: Date?, now: Date, compact: Bool = false) -> String {
        guard let date else { return "--" }
        let minutes = max(0, date.timeIntervalSince(now) / 60)
        guard minutes.isFinite, minutes < Double(Int.max / 2) else { return "--" }
        if compact { return duration(minutes: minutes) }
        let m = Int(minutes.rounded()), d = m / 1440, h = (m % 1440) / 60, rest = m % 60
        var parts: [String] = []
        if d > 0 { parts.append(language == .chinese ? "\(d) 天" : "\(d)d") }
        if h > 0 { parts.append(language == .chinese ? "\(h) 小时" : "\(h)h") }
        if rest > 0 || parts.isEmpty { parts.append(language == .chinese ? "\(rest) 分" : "\(rest)m") }
        let text = parts.joined(separator: " ")
        return language == .chinese ? text + "后" : "in " + text
    }

    public func reset(_ date: Date?, now: Date) -> String {
        guard date != nil else { return "--" }
        let time = future(date, now: now)
        return language == .chinese ? time + "重置" : "resets " + time
    }

    public func expiry(_ date: Date?, now: Date) -> String {
        guard date != nil else { return "--" }
        let time = future(date, now: now)
        return language == .chinese ? time + "到期" : "expire " + time
    }

    public func age(_ date: Date?, now: Date) -> String {
        guard let date, date <= now else { return "--" }
        let text = duration(minutes: now.timeIntervalSince(date) / 60)
        return language == .chinese ? text + "前" : text + " ago"
    }

    public func resets(count: Int?, nearestExpiry: Date?, now: Date) -> String {
        guard let count, count >= 0 else { return "--" }
        let label = language == .chinese ? "重置 \(count) 次" : "\(count) " + (count == 1 ? "reset" : "resets")
        return nearestExpiry.map { label + " · " + expiry($0, now: now) } ?? label
    }

    public func costMultiple(_ value: Double?) -> String? {
        guard let value = known(value) else { return nil }
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.usesGroupingSeparator = false
        formatter.usesSignificantDigits = true
        formatter.minimumSignificantDigits = 1
        formatter.maximumSignificantDigits = 2
        return formatter.string(from: NSNumber(value: value)).map { "×" + $0 }
    }

    public func percent(_ value: Double?) -> String {
        guard let value = percentage(value) else { return "--" }
        return String(format: "%.0f%%", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    public func rowName(_ row: QuotaRow) -> String {
        switch (row, language) {
        case (.fiveHours, .chinese): return "5小时"
        case (.fiveHours, .english): return "5h"
        case (.weekly, .chinese): return "每周"
        case (.weekly, .english): return "Weekly"
        case (.other, .chinese): return "其他"
        case (.other, .english): return "Other"
        }
    }

    public func period(_ period: QuotaPeriod) -> String {
        switch (period, language) {
        case (.fiveHours, _): return "5h"
        case (.daily, .chinese): return "日"
        case (.daily, .english): return "day"
        case (.weekly, .chinese): return "周"
        case (.weekly, .english): return "wk"
        case (.monthly, .chinese): return "月"
        case (.monthly, .english): return "mo"
        case (.other(let label), _): return label
        }
    }
}

func known(_ value: Double?) -> Double? {
    guard let value, value.isFinite, value >= 0 else { return nil }
    return value
}

func percentage(_ value: Double?) -> Double? {
    guard let value = known(value), value <= 100 else { return nil }
    return value
}

func ratio(_ value: Double?, _ reference: Double?) -> Double? {
    guard let value = known(value), let reference = known(reference), reference > 0 else { return nil }
    return known(value / reference)
}

func strictSum(_ values: [Double?]) -> Double? {
    guard !values.isEmpty, values.allSatisfy({ known($0) != nil }) else { return nil }
    return known(values.reduce(0) { $0 + ($1 ?? 0) })
}
