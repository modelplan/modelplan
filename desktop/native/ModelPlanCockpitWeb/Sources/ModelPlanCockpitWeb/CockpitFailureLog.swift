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
