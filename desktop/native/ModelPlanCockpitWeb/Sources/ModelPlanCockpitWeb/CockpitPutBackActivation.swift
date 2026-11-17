// SPDX-License-Identifier: MIT
import Foundation

/// Walkthrough 11-17 (build b2b50b34, regression from #977): a put back can drop the app from regular to accessory (spec
/// item 4), and macOS deactivates the app for that flip, on the spot or with a resign a moment later. The put back is
/// the user's own press, so an app that was active then stays active. Otherwise the page is told `key: false`, and the
/// next press on it (its Close) only activates the app and is dropped by the page's and the bridge's key gate.
///
/// macrevd-1033-1: the recovery answers only that flip. It is armed only when the put back's presence change actually
/// left the regular policy (Settings still open keeps the app regular: nothing is armed), it acts at most once, and it
/// is retired by any sign of the user switching away (a press in another app, the Command key held for Cmd-Tab) and
/// after a short window, so a deliberate switch is never fought.
struct CockpitPutBackActivation: Equatable {
  /// Covers the flip's own resign, which can arrive after the latch (the host's policy hold is 250 ms).
  static let windowMilliseconds: UInt64 = 500
  private(set) var armedUntil: UInt64?

  /// At the latch. `wasActive`: the app was active before the presence change. `leftRegular`: the presence change
  /// moved the app from regular to accessory. Without both there is nothing of ours to recover from.
  mutating func arm(wasActive: Bool, leftRegular: Bool, now: UInt64) {
    armedUntil = wasActive && leftRegular ? now &+ Self.windowMilliseconds : nil
  }
  /// Whether to activate the app again now (the flip deactivated it). Acting retires the arm: the flip is answered once.
  /// `presentable`: the attached cockpit is still shown and not closing.
  mutating func reactivates(isActive: Bool, presentable: Bool, now: UInt64) -> Bool {
    guard let until = armedUntil else { return false }
    guard now <= until, presentable else { armedUntil = nil; return false }
    guard !isActive else { return false }
    armedUntil = nil
    return true
  }
  /// The user is switching away (or the cockpit went): no recovery after this.
  mutating func retire() { armedUntil = nil }
}
