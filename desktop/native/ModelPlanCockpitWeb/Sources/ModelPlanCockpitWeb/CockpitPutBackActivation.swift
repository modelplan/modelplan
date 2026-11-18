// SPDX-License-Identifier: MIT
import Foundation

/// Walkthrough 11-17 (build b2b50b34, regression from #977): a put back can drop the app from regular to accessory (spec
/// item 4), and macOS deactivates the app for that flip, on the spot or with a resign a moment later. The put back is
/// the user's own press, so an app that was active then stays active. Otherwise the page is told `key: false`, and the
/// next press on it (its Close) only activates the app and is dropped by the page's and the bridge's key gate.
///
/// Recovery state machine (macrevd-1033-1, macrev2-1033-1). States: idle, or armed until a deadline; beside them the
/// `userSwitching` fact, the user's switch intent seen since the put back began.
/// - `beginPutBack` (the put-back key, the menu, a strip drag starting): clears `userSwitching`. Nothing is armed.
/// - `userSwitchesAway` (Command down, a press in another app; delivered synchronously from the monitors): sets
///   `userSwitching` and retires any arm. It wins over the policy glitch because it is direct evidence of the user's
///   intent, while the glitch's resign looks the same as the switch it would otherwise be mistaken for.
/// - `arm` (the latch): armed only if the app was active, the presence change really left regular, Command is not
///   held now and no switch was seen since the put back began. Otherwise idle.
/// - `reactivates` (the latch's own check, then the next resign): fires once when armed, inside the window, presentable
///   and inactive, and goes idle. Past the deadline or not presentable (closing, discarded, detached): idle.
/// - `retire` (discard, close): idle.
struct CockpitPutBackActivation: Equatable {
  /// Covers the flip's own resign, which can arrive after the latch (the host's policy hold is 250 ms).
  static let windowMilliseconds: UInt64 = 500
  private(set) var armedUntil: UInt64?
  private(set) var userSwitching = false
  /// G3-129: whether the arm was for a detach (the flip to regular) rather than a put back's latch.
  private(set) var armedDetached = false

  /// A put back starts: switch intent from before it does not count.
  mutating func beginPutBack() { userSwitching = false }
  /// The user is switching away (Command down, a press in another app). Holds until the next put back begins.
  mutating func userSwitchesAway() { userSwitching = true; armedUntil = nil }
  /// At the latch. `wasActive`: the app was active before the presence change. `leftRegular`: the presence change
  /// moved the app from regular to accessory. `commandHeld`: Command is down now (a Cmd-Tab in progress).
  /// G3-129: a user detach arms the same way (`detached`), with `leftRegular` meaning its flip changed the policy.
  mutating func arm(wasActive: Bool, leftRegular: Bool, commandHeld: Bool, now: UInt64, detached: Bool = false) {
    armedUntil = wasActive && leftRegular && !commandHeld && !userSwitching ? now &+ Self.windowMilliseconds : nil
    armedDetached = detached
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
  /// The cockpit went (discard, close): no recovery after this.
  mutating func retire() { armedUntil = nil }
}
