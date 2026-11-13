// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanEngineClient
import os

/// Which engine-side path left the cockpit unavailable.
public enum CockpitUnavailableReason: Equatable, Sendable {
  case noClient, noDelivery, invalidContext, contextRejected, featureFailure
  case pageCreation(String), query(String)
  public var path: String {
    switch self {
    case .noClient: return "open.noClient"
    case .noDelivery: return "open.noDelivery"
    case .invalidContext: return "open.invalidContext"
    case .contextRejected: return "adopt.contextRejected"
    case .featureFailure: return "feature.cockpit"
    case .pageCreation(let error): return "open.pageCreation." + error
    case .query(let error): return "query." + error
    }
  }
}

/// One line per cockpit failure, for the unified log and for stderr, which a test run keeps as
/// app.log. Callers pass code paths and counters only, never engine data or an error's text.
public enum CockpitFailureLog {
  /// Milliseconds since this process started, or -1 when the system will not say. Lets a failure line show how early in
  /// the launch it happened.
  public static var msSinceLaunch: Int {
    var info = kinfo_proc(), size = MemoryLayout<kinfo_proc>.stride
    var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
    guard sysctl(&mib, 4, &info, &size, nil, 0) == 0 else { return -1 }
    let start = info.kp_proc.p_un.__p_starttime
    return max(0, Int((Date().timeIntervalSince1970 - (Double(start.tv_sec) + Double(start.tv_usec) / 1e6)) * 1000))
  }
  private static let logger = Logger(subsystem: "org.modelplan.community", category: "cockpit")
  // A pipe whose reader has gone must not raise SIGPIPE for the sake of a log line.
  private static let stderrPrepared: Void = { _ = fcntl(STDERR_FILENO, F_SETNOSIGPIPE, 1) }()
  #if MODELPLAN_TEST_ONLY_SPI
  @MainActor public static var verificationLine: ((String) -> Void)?
  #endif
  @MainActor public static func record(_ line: String) {
    #if MODELPLAN_TEST_ONLY_SPI
    verificationLine?(line)
    #endif
    logger.error("\(line, privacy: .public)")
    _ = stderrPrepared
    // Not FileHandle.write, which raises an exception when stderr is closed. A failed write is ignored.
    ("modelplan-cockpit " + line + "\n").withCString { _ = write(STDERR_FILENO, $0, strlen($0)) }
  }
  /// The case name of an error: an associated value can carry account or path text.
  public static func errorName(_ error: Error) -> String {
    if case EngineClientError.rpc(let code, _) = error { return "rpc.\(code)" }
    let mirror = Mirror(reflecting: error)
    guard mirror.displayStyle == .enum else { return String(describing: type(of: error)) }
    return mirror.children.first?.label ?? String(describing: error)
  }
}

/// CKP-SHELL-20 (G3-42): one line per prewarm and open stage, in the unified log and on stderr (app.log in a
/// test run), so a packaged build shows that the hidden page was made and how long a click took to show
/// data. Stage names, counts and milliseconds only: never engine data, paths or an error's text.
public enum CockpitTimingLog {
  private static let logger = Logger(subsystem: "org.modelplan.community", category: "cockpit")
  private static let stderrPrepared: Void = { _ = fcntl(STDERR_FILENO, F_SETNOSIGPIPE, 1) }()
  /// The menu bar click (or other open request) the next open stages are measured from.
  @MainActor private static var clickAt: TimeInterval?
  #if MODELPLAN_TEST_ONLY_SPI
  @MainActor public static var verificationLine: ((String) -> Void)?
  #endif
  static var now: TimeInterval { ProcessInfo.processInfo.systemUptime }
  static func ms(since start: TimeInterval) -> Int { max(0, Int((now - start) * 1_000)) }
  /// Called where the app receives the open request, before any await, so a stage's time includes the hop.
  @MainActor public static func markClick() { clickAt = now }
  /// Milliseconds since the last open request, or -1 when there was none.
  @MainActor static func sinceClick() -> Int { clickAt.map { ms(since: $0) } ?? -1 }
  @MainActor public static func record(_ line: String) {
    #if MODELPLAN_TEST_ONLY_SPI
    verificationLine?(line)
    #endif
    logger.notice("timing \(line, privacy: .public)")
    _ = stderrPrepared
    ("modelplan-cockpit timing " + line + "\n").withCString { _ = write(STDERR_FILENO, $0, strlen($0)) }
  }
}
