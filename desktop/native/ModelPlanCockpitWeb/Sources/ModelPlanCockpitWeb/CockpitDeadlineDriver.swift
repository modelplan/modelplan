// SPDX-License-Identifier: MIT
import Foundation

/// One native-owned deadline; all callbacks are fenced by the current schedule.
enum CockpitDeadlineReason: String, Equatable {
  case deadline, show, wake, unlock, clockChange
}

@MainActor final class CockpitDeadlineDriver {
  typealias Arm = (UInt64, @escaping @MainActor () -> Void) -> () -> Void
  private let now: () -> UInt64, arm: Arm, onExhausted: () -> Void, tick: (CockpitDeadlineReason) -> Void
  private var cancel: (() -> Void)?
  private var serial: UInt64 = 0
  private var visible = false, retired = false
  private var lastDeliveredDeadline: UInt64?, lastObservedClock: UInt64?
  private var immediateAdvances = 0
  static let maximumImmediateAdvances = 64
  private static let maxDelay: UInt64 = 86_400_000
  var isVisible: Bool { visible && !retired }

  init(now: @escaping () -> UInt64, arm: @escaping Arm, onExhausted: @escaping () -> Void,
       tick: @escaping (CockpitDeadlineReason) -> Void) {
    self.now = now; self.arm = arm; self.onExhausted = onExhausted; self.tick = tick
  }
  private func cancelTimer() {
    serial &+= 1; cancel?(); cancel = nil
  }
  /// A privacy/context generation barrier retires timer, watermark and clock epoch.
  func invalidate() {
    cancelTimer(); lastDeliveredDeadline = nil; lastObservedClock = nil; immediateAdvances = 0
  }
  private func sampleClock(externalEvent: Bool = false) -> UInt64 {
    let current = now()
    // Only a host-observed show/wake/unlock/clock event may open a new epoch
    // on backwards time. Page reports alone cannot reset the watermark.
    if externalEvent, let previous = lastObservedClock, current < previous {
      lastDeliveredDeadline = nil; lastObservedClock = current
    } else { lastObservedClock = max(lastObservedClock ?? current, current) }
    return current
  }
  func show() {
    guard !retired, !visible else { return }
    visible = true; cancelTimer(); _ = sampleClock(externalEvent: true); tick(.show)
  }
  func hide() {
    visible = false; cancelTimer(); immediateAdvances = 0
  }
  func retire() {
    retired = true; hide()
  }
  func notify(_ reason: CockpitDeadlineReason) {
    guard visible, !retired, reason != .deadline, reason != .show else { return }
    cancelTimer(); immediateAdvances = 0; _ = sampleClock(externalEvent: true); tick(reason)
  }
  func accept(deadline: UInt64?) {
    cancelTimer()
    guard visible, !retired else { return }
    guard let deadline else { immediateAdvances = 0; return }
    let current = sampleClock()
    // Reports advance within a generation: a distinct later deadline may have
    // passed in transit, but equal/older reports must not form a tight loop.
    if let lastDeliveredDeadline, deadline <= lastDeliveredDeadline { return }
    if deadline <= current {
      guard immediateAdvances < Self.maximumImmediateAdvances else {
        retire(); onExhausted(); return
      }
    } else { immediateAdvances = 0 }
    schedule(deadline)
  }
  private func schedule(_ deadline: UInt64) {
    guard visible, !retired else { return }
    let current = sampleClock(), delay = min(Self.maxDelay, deadline > current ? deadline - current : 0)
    let wasImmediatelyDue = deadline <= current, token = serial
    cancel = arm(delay) { [weak self] in
      guard let self, self.visible, !self.retired, self.serial == token else { return }
      self.cancel = nil; self.serial &+= 1
      if self.sampleClock() < deadline { self.schedule(deadline); return }
      if wasImmediatelyDue { self.immediateAdvances += 1 } else { self.immediateAdvances = 0 }
      self.lastDeliveredDeadline = deadline; self.tick(.deadline)
    }
  }
}

/// Visibility must be accepted by the page before the corresponding show tick.
struct CockpitVisibilityFence {
  private var serial: UInt64 = 0
  private var targetVisible = false, confirmed = false
  mutating func begin(visible: Bool) -> UInt64 {
    serial &+= 1; targetVisible = visible; confirmed = false; return serial
  }
  var isConfirmedVisible: Bool { targetVisible && confirmed }
  func isCurrent(_ token: UInt64) -> Bool { token == serial }
  func isPending(_ token: UInt64) -> Bool { isCurrent(token) && !confirmed }
  mutating func confirm(_ token: UInt64) -> Bool {
    guard isPending(token) else { return false }
    confirmed = true; return targetVisible
  }
  mutating func invalidate() { serial &+= 1; targetVisible = false; confirmed = false }
}

/// Missing rendered acknowledgements fail after a bounded wait; replaced waits
/// cannot report failure for a newer trigger or page.
@MainActor final class CockpitDeadlineReceiptWatchdog {
  private let arm: CockpitDeadlineDriver.Arm, timedOut: (UUID) -> Void
  private var cancellation: (() -> Void)?, generation: UInt64 = 0
  private(set) var currentID: UUID?
  init(arm: @escaping CockpitDeadlineDriver.Arm, timedOut: @escaping (UUID) -> Void) {
    self.arm = arm; self.timedOut = timedOut
  }
  func wait(for id: UUID) {
    cancel(); currentID = id
    let token = generation
    cancellation = arm(2_000) { [weak self] in
      guard let self, self.generation == token, self.currentID == id else { return }
      self.currentID = nil; self.cancellation = nil; self.generation &+= 1
      self.timedOut(id)
    }
  }
  func cancel() {
    generation &+= 1; cancellation?(); cancellation = nil; currentID = nil
  }
}

/// An appearance repaint may derive deadlines only after the current display
/// receipt is admitted. Keep the latest appearance in the owner while deferred.
struct CockpitAppearanceGate {
  private(set) var isDeferred = false
  private(set) var version: UInt64 = 0
  mutating func request(visible: Bool, displayPending: Bool) -> Bool {
    version &+= 1; isDeferred = true
    return visible && !displayPending
  }
  func retry(visible: Bool, displayPending: Bool) -> Bool {
    isDeferred && visible && !displayPending
  }
  @discardableResult mutating func acknowledge(_ token: UInt64) -> Bool {
    guard token == version, isDeferred else { return false }
    isDeferred = false; return true
  }
  mutating func deferUntilVisible() { version &+= 1; isDeferred = true }
  mutating func invalidate() { version &+= 1; isDeferred = false }
}
