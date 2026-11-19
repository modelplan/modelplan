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
