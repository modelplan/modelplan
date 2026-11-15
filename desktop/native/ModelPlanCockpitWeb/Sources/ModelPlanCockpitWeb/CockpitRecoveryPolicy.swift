// SPDX-License-Identifier: MIT
import Foundation

// Recovery contract (G3-96, G3-116; research/cockpit-recovery-root-design-1114.md section 2). The root defect was
// failure classification: a late receipt, a refused message and a dead WebContent process all ended the page the same
// way, and the rebuilt page met the same slow condition again (the flicker, then "unavailable", then the widget "?").
// The pure parts of the contract live here, with no AppKit, WebKit or timers, so their boundaries are tested exactly:
// - page responsiveness (`CockpitPageHealth`): only WebContent termination, or 30 active seconds plus two unanswered
//   probes, makes a page dead; any answer from the page proves it alive;
// - rebuild budget (`CockpitRebuildBudget`): two rebuilds per rolling 10 minutes (after 1 s, then 4 s), then a 60 s
//   cooldown and an automatic probe; only sustained verified health resets it, never another click;
// - classification (`CockpitWindowFailure.recovery`, `CockpitRecoveryPolicy`): what a failure, a refusal or a probe
//   reply means for the page.

/// Schedules `fire` after a delay in milliseconds and returns its cancellation. The production arm is a main-actor
/// task; tests inject a fake one and fire callbacks themselves, so no test sleeps.
public typealias CockpitArm = @MainActor (UInt64, @escaping @MainActor () -> Void) -> () -> Void

public enum CockpitScheduling {
  /// The production arm: a main-actor task. A cancelled or late callback never fires.
  @MainActor public static func task(_ delay: UInt64, _ fire: @escaping @MainActor () -> Void) -> () -> Void {
    let task = Task { @MainActor in
      do { try await Task.sleep(for: .milliseconds(Int64(min(delay, UInt64(Int64.max))))) } catch { return }
      guard !Task.isCancelled else { return }
      fire()
    }
    return { task.cancel() }
  }
  /// A `Duration` in whole milliseconds, never negative.
  public static func milliseconds(_ duration: Duration) -> UInt64 {
    let parts = duration.components
    guard parts.seconds >= 0 else { return 0 }
    return UInt64(parts.seconds) &* 1_000 &+ UInt64(max(0, parts.attoseconds) / 1_000_000_000_000_000)
  }
}

/// Liveness is measured on this clock, never on wall time. It counts the time the Mac is awake since boot, so a
/// system sleep never counts against a page. Wall time stays for data deadlines only (`CockpitDeadlineDriver`).
public enum CockpitMonotonicClock {
  public static func nowMs() -> UInt64 {
    let value = ProcessInfo.processInfo.systemUptime * 1_000
    guard value.isFinite, value > 0 else { return 0 }
    return UInt64(value.rounded(.down))
  }
}

/// Page responsiveness, apart from data validity and the engine connection. A schema rejection, a JavaScript
/// exception or a late receipt all prove that the page answered; none of them can establish its death.
public struct CockpitPageHealth: Equatable, Sendable {
  public enum Verdict: Equatable, Sendable {
    /// Nothing is waiting for the page, or it answered since.
    case responsive
    /// Something has waited past its receipt window; the page is being probed.
    case waiting
    /// 30 active seconds without any answer and at least two unanswered probes: rebuild the page.
    case unresponsive
  }
  /// After this long without a receipt the reading shows as delayed and probing starts.
  public static let delayedAfterMs: UInt64 = 2_000
  /// A probe that has not answered after this long counts as unanswered; the next probe follows at once.
  public static let probeTimeoutMs: UInt64 = 5_000
  public static let unresponsiveAfterMs: UInt64 = 30_000
  public static let unansweredProbesRequired = 2

  /// Monotonic time at which the current wait started; nil while nothing waits.
  public private(set) var waitingSince: UInt64?
  public private(set) var unansweredProbes = 0
  /// Hidden (not shown, minimised, covered, app hidden): nothing is accounted.
  public private(set) var paused = true
  public init() {}

  public var isWaiting: Bool { waitingSince != nil }
  public func waited(at now: UInt64) -> UInt64 {
    guard let since = waitingSince, now >= since else { return 0 }
    return now - since
  }
  /// Something waited past its receipt window. Starts the wait unless one already runs; true when it started.
  @discardableResult public mutating func expect(at now: UInt64) -> Bool {
    guard !paused, waitingSince == nil else { return false }
    waitingSince = now; unansweredProbes = 0
    return true
  }
  /// Any answer from the current page (a receipt, a completed call, a probe reply) proves it alive.
  public mutating func answered() { waitingSince = nil; unansweredProbes = 0 }
  public mutating func probeUnanswered() {
    guard waitingSince != nil else { return }
    unansweredProbes += 1
  }
  /// The user cannot see the page: the wait is dropped and nothing counts until it is shown again.
  public mutating func pause() { paused = true; waitingSince = nil; unansweredProbes = 0 }
  /// Shown again after being hidden: a fresh grace period. A page that stays shown keeps its wait.
  public mutating func resume() {
    guard paused else { return }
    paused = false; waitingSince = nil; unansweredProbes = 0
  }
  /// The Mac woke or the screen unlocked: whatever waited across the sleep starts over.
  public mutating func grantGrace() { waitingSince = nil; unansweredProbes = 0 }
  public func verdict(at now: UInt64) -> Verdict {
    guard waitingSince != nil else { return .responsive }
    return waited(at: now) >= Self.unresponsiveAfterMs && unansweredProbes >= Self.unansweredProbesRequired
      ? .unresponsive : .waiting
  }
}

/// How many times a dead page is rebuilt. Two attempts per rolling 10 minutes, after 1 s and then 4 s; past that, a
/// 60 s cooldown followed by an automatic probe (one more rebuild), again and again while the cockpit is wanted.
/// The budget is reset only by sustained verified health (two minutes of rendering since the last rebuild), never
/// by another click or open.
public struct CockpitRebuildBudget: Equatable, Sendable {
  public static let windowMs: UInt64 = 600_000
  public static let delaysMs: [UInt64] = [1_000, 4_000]
  public static let cooldownMs: UInt64 = 60_000
  public static let sustainedHealthMs: UInt64 = 120_000
  public enum Decision: Equatable, Sendable {
    /// Rebuild after `afterMs`; `attempt` counts within the rolling window (1 or 2).
    case rebuild(afterMs: UInt64, attempt: Int)
    /// The budget is spent: after the cooldown one probe rebuild runs.
    case cooldown(probeAfterMs: UInt64)
  }
  /// Monotonic times of the rebuilds inside the rolling window.
  public private(set) var attempts: [UInt64] = []
  /// Monotonic time of the first verified render since the last failure.
  public private(set) var healthySince: UInt64?
  public init() {}
  public var exhausted: Bool { attempts.count >= Self.delaysMs.count }
  public mutating func pageFailed(at now: UInt64) -> Decision {
    if let since = healthySince, now >= since, now - since >= Self.sustainedHealthMs { attempts.removeAll() }
    healthySince = nil
    attempts.removeAll { $0 > now || now - $0 >= Self.windowMs }
    guard attempts.count < Self.delaysMs.count else { return .cooldown(probeAfterMs: Self.cooldownMs) }
    let delay = Self.delaysMs[attempts.count]
    attempts.append(now)
    return .rebuild(afterMs: delay, attempt: attempts.count)
  }
  /// The page showed data. Health counts from the first such render after a failure.
  public mutating func rendered(at now: UInt64) {
    if healthySince == nil { healthySince = now }
  }
}

public extension CockpitWindowFailure {
  /// What a failure that ended a page asks of the host.
  enum Recovery: String, Equatable, Sendable {
    /// The page is dead (its process ended, it stopped answering, its page API is gone): rebuild within the budget.
    case rebuild
    /// The page was disposed to keep a privacy barrier (a clear that was refused or not acknowledged): build a
    /// fresh page at once, with no notice and without spending the budget.
    case privacy
    /// The bundle is damaged or the page speaks another contract: a rebuild cannot help. Say so and admit the
    /// bundle afresh at the next open.
    case repair
  }
  var recovery: Recovery {
    switch self {
    case .clearDeadline, .clearRejected: return .privacy
    case .bundleResource, .unsupportedPageContract: return .repair
    case .pageAPIUnavailable, .messageRejected, .javascriptFailed, .navigationFailed, .provisionalNavigationFailed,
         .contentTerminated, .localEncoding, .unresponsive: return .rebuild
    }
  }
}

public enum CockpitRecoveryPolicy {
  /// What a refused host message means. The page answered, so a refusal alone never makes it dead.
  public enum Rejection: Equatable, Sendable {
    /// The page refused this update and kept what it showed. Keep the page; the next update may pass.
    case kept
    /// The page refused its load, or unloaded itself while refusing (bridge.ts unloads on a view exception): the
    /// page API is gone and the page is rebuilt.
    case pageGone
    /// A privacy clear was refused: the page may still hold private views, so it is disposed.
    case privacy
  }
  /// bridge.ts reject codes after which the page has unloaded itself (`unload()` in the catch, or a page that has
  /// ended). Every other code leaves the page as it was.
  public static let selfUnloadingCodes: Set<String> = [
    "load.view", "appearance.view", "shell.view", "display.render", "tick.view", "clear.retired", "recv.source",
  ]
  public static func rejection(code: String, clear: Bool, bootstrap: Bool) -> Rejection {
    if clear { return .privacy }
    if bootstrap || selfUnloadingCodes.contains(code) { return .pageGone }
    return .kept
  }
  public enum ProbeOutcome: Equatable, Sendable {
    /// The page's bridge answered: it is alive.
    case answered
    /// No usable answer yet (the call failed, or the bridge is not installed while the page still loads).
    case unanswered
    /// The page had loaded, and its bridge is gone: it unloaded itself.
    case pageGone
  }
  /// The probe reads the page bridge's state (`window.modelPlanCockpit.state()`), or "missing" without a bridge.
  public static func probeOutcome(_ reply: String?, pageReady: Bool) -> ProbeOutcome {
    guard let reply else { return .unanswered }
    switch reply {
    case "missing", "unloaded": return pageReady ? .pageGone : .unanswered
    case "loading", "ready", "hidden", "cleared": return .answered
    default: return .unanswered
    }
  }
}

/// A pending callback from a `CockpitArm`; `cancel()` drops it. Spelt like `Task.cancel()` so call sites read the same.
struct CockpitTimerHandle {
  let cancel: () -> Void
}
