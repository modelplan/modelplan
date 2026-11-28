// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanWire

/// CKP-SHELL-50: where the app keeps the range, so it outlives every restart. A user preference, not private data:
/// a consent or store change does not remove it.
@MainActor public protocol CockpitRangeMemory: AnyObject {
  func load() -> CockpitRange?
  func save(_ value: CockpitRange)
}

/// CKP-SHELL-50 / MENU-52: the one range of the app. The menu bar, the cockpit title bar and the big-screen keys only
/// show it and ask to change it; every page gets it before it loads. Restored from memory at creation, so the first
/// menu and the first render already show the remembered range.
@MainActor public final class CockpitRangeState {
  public private(set) var value: CockpitRange
  private let memory: (any CockpitRangeMemory)?
  private var observers: [(id: UUID, notify: (CockpitRange) -> Void)] = []
  public init(memory: (any CockpitRangeMemory)? = nil) {
    self.memory = memory
    value = memory?.load() ?? .initial
  }
  /// A request from any surface. The same value is not saved or announced again.
  public func select(_ next: CockpitRange) {
    guard next != value else { return }
    value = next
    memory?.save(next)
    for observer in observers { observer.notify(next) }
  }
  /// T on the cockpit: Today → 7d → 30d → Today.
  public func cycle() { select(value.next) }
  @discardableResult public func observe(_ notify: @escaping (CockpitRange) -> Void) -> UUID {
    let id = UUID(); observers.append((id, notify)); return id
  }
  public func removeObserver(_ id: UUID) { observers.removeAll { $0.id == id } }
}

/// MENU-50: the range's token total across every subscription, from the last cockpit reply. Until WP-02 sends one
/// total per range, today is the observed output tokens of today and 7d / 30d are the history output sums; a range the
/// reply has no figure for is nil (the menu then leaves the figure out rather than print 0 or "--").
public enum CockpitRangeTotals {
  public static func outputTokens(_ data: WireCockpitData?, range: CockpitRange) -> Int64? {
    guard let data else { return nil }
    let values: [Int64]
    switch range {
    case .today:
      values = (data.details?.subscriptions ?? []).flatMap { $0.today.map(\.observedOutputTokens) }
    case .sevenDays:
      values = (data.history?.subscriptions ?? []).flatMap { $0.sources.map(\.recent7d.outputTokens) }
    case .thirtyDays:
      values = (data.history?.subscriptions ?? []).flatMap { $0.sources.map(\.recent30d.outputTokens) }
    }
    guard !values.isEmpty, values.allSatisfy({ $0 >= 0 }) else { return nil }
    var sum: Int64 = 0
    for value in values {
      let (next, overflow) = sum.addingReportingOverflow(value)
      if overflow { return nil }
      sum = next
    }
    return sum
  }
}

/// Master spec §2.1 / §2.5 (D464, D474): one measure everywhere, total tokens (priced + unpriced) and ≈$ from the wire's
/// `history.cost.daily` buckets, the same sums as the cockpit page (`src/prototype-cost.ts` `costView`). A day is the
/// local calendar day of the bucket's `at`; 7d / 30d include today. No priced tokens means no ≈$ (never $0).
public enum CockpitCostTotals {
  public struct Sum: Equatable, Sendable {
    public var tokens: Int64 = 0, pricedTokens: Int64 = 0, usd: Double = 0
    /// nil without any priced usage (no public price: tokens only).
    public var estimatedUSD: Double? { pricedTokens > 0 ? usd : nil }
  }
  static func usable(_ data: WireCockpitData?) -> WireCockpitCost? {
    guard let history = data?.history, history.coverage == "local-history", let cost = history.cost,
          cost.basis == "api-list-price", cost.currency == "USD" else { return nil }
    return cost
  }
  static func dayKey(_ date: Date, calendar: Calendar) -> String {
    let c = calendar.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
  }
  static func firstDay(_ range: CockpitRange, now: Date, calendar: Calendar) -> String {
    let back: Int
    switch range { case .today: back = 0; case .sevenDays: back = 6; case .thirtyDays: back = 29 }
    let start = calendar.date(byAdding: .day, value: -back, to: calendar.startOfDay(for: now)) ?? now
    return dayKey(start, calendar: calendar)
  }
  /// The range across every source, or nil when the reply carries no usable cost section.
  public static func total(_ data: WireCockpitData?, range: CockpitRange, now: Date, calendar: Calendar = .current) -> Sum? {
    sum(data, range: range, now: now, calendar: calendar, sources: nil)
  }
  /// One verified subscription's range, through the sources its history binds (the producer's current binding).
  public static func subscription(_ data: WireCockpitData?, ref: String, range: CockpitRange, now: Date, calendar: Calendar = .current) -> Sum? {
    guard let subscription = data?.history?.subscriptions.first(where: { $0.subscriptionRef == ref }) else { return nil }
    return sum(data, range: range, now: now, calendar: calendar, sources: Set(subscription.sources.map(\.source)))
  }
  static func sum(_ data: WireCockpitData?, range: CockpitRange, now: Date, calendar: Calendar, sources: Set<String>?) -> Sum? {
    guard let cost = usable(data) else { return nil }
    let today = dayKey(now, calendar: calendar), from = firstDay(range, now: now, calendar: calendar)
    var out = Sum()
    for bucket in cost.daily where bucket.at >= from && bucket.at <= today && (sources?.contains(bucket.source) ?? true) {
      guard bucket.pricedTokens >= 0, bucket.unpricedTokens >= 0, bucket.estimatedUsd.isFinite, bucket.estimatedUsd >= 0 else { continue }
      let (t1, o1) = out.tokens.addingReportingOverflow(bucket.pricedTokens)
      let (t2, o2) = t1.addingReportingOverflow(bucket.unpricedTokens)
      let (p, o3) = out.pricedTokens.addingReportingOverflow(bucket.pricedTokens)
      guard !o1, !o2, !o3 else { return nil }
      out.tokens = t2; out.pricedTokens = p; out.usd += bucket.estimatedUsd
    }
    return out
  }
  /// V1-FINAL §0 "≈$64": below $100 two significant digits, from $100 whole dollars, from $1000 "≈$1.2k"
  /// (`estCostText` on the page). A figure that rounds to nothing says "<$0.01".
  public static func text(_ usd: Double) -> String? {
    guard usd.isFinite, usd >= 0 else { return nil }
    func significant(_ v: Double, _ digits: Int) -> String {
      let s = String(format: "%.\(digits)g", locale: Locale(identifier: "en_US_POSIX"), v)
      return s.contains("e") ? String(format: "%.0f", locale: Locale(identifier: "en_US_POSIX"), v) : s
    }
    if usd == 0 { return "≈$0" }
    if usd < 0.01 { return "<$0.01" }
    if usd < 100 { return "≈$" + significant(usd, 2) }
    if usd < 999.5 { return "≈$" + String(Int(usd.rounded())) }
    let k = usd / 1000
    if k < 999.5 { return "≈$" + significant(k, k < 100 ? 2 : 3) + "k" }
    return "≈$" + significant(k / 1000, 2) + "M"
  }
}
