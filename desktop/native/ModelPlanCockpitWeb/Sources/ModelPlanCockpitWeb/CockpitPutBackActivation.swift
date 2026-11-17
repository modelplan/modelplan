// SPDX-License-Identifier: MIT
import Foundation

/// Walkthrough 11-17 (build b2b50b34, regression from #977): a put back drops the app from regular to accessory (spec
/// item 4), and macOS deactivates the app for that flip, on the spot or a moment later. The put back is the user's own
/// press (the put-back key, the context menu, a drag released in the catch zone), so an app that was active then stays
/// active. Otherwise the page is told `key: false`, and the next press on it (its Close) only activates the app and is
/// dropped by the page's and the bridge's key gate.
///
/// The window is short and one resign is answered once, so a deliberate switch to another app right after the put back
/// is not fought for long.
struct CockpitPutBackActivation: Equatable {
  /// Covers the flip's own resign, which can arrive after the latch (the host's policy hold is 250 ms).
  static let windowMilliseconds: UInt64 = 500
  private(set) var armedUntil: UInt64?

  /// At the latch, with the app's active state from before the presence change. An app that was not active is left so.
  mutating func arm(wasActive: Bool, now: UInt64) {
    armedUntil = wasActive ? now &+ Self.windowMilliseconds : nil
  }
  /// Whether to activate the app again now. `presentable`: the attached cockpit is still shown and not closing.
  /// `consume` ends the arm once it acts (the flip's resign is answered once).
  mutating func reactivates(isActive: Bool, presentable: Bool, now: UInt64, consume: Bool) -> Bool {
    guard let until = armedUntil else { return false }
    guard now <= until, presentable else { armedUntil = nil; return false }
    guard !isActive else { return false }
    if consume { armedUntil = nil }
    return true
  }
  mutating func cancel() { armedUntil = nil }
}
