// SPDX-License-Identifier: MIT
#if MODELPLAN_TEST_ONLY_SPI || MODELPLAN_U6_DRIVE
  import Foundation

  public enum StatusMenuAction: String, Codable, Sendable { case refresh, settings, console, quit }
  public enum StatusMenuError: Error {
    case invalidRequest, outsideOwnedMenu, unsupported, notFound, ambiguous, disabled, limit,
      arrivalTimeout
  }
  public struct StatusMenuActionRequest: Codable, Sendable {
    public let profile: String, runID: String, epoch: String
    public let subjectPID: Int32, requestID: UUID, action: StatusMenuAction
    public let notBefore: Double, expiresAt: Double
    public init(
      profile: String = "synthetic", runID: String, epoch: String, subjectPID: Int32,
      requestID: UUID, action: StatusMenuAction, notBefore: Double, expiresAt: Double
    ) {
      self.profile = profile
      self.runID = runID
      self.epoch = epoch
      self.subjectPID = subjectPID
      self.requestID = requestID
      self.action = action
      self.notBefore = notBefore
      self.expiresAt = expiresAt
    }
    public func validate(now: Double) throws {
      func identity(_ value: String) -> Bool {
        !value.isEmpty && value.utf16.count <= 128
          && !value.unicodeScalars.contains { $0.value < 32 || $0.value == 127 }
      }
      guard profile == "synthetic", identity(runID), identity(epoch), subjectPID > 0, now.isFinite,
        notBefore.isFinite, expiresAt.isFinite,
        expiresAt > notBefore, expiresAt - notBefore <= 1200, notBefore <= now, now < expiresAt
      else { throw StatusMenuError.invalidRequest }
    }
  }
  public struct StatusMenuArrivalReceipt: Sendable {
    public let request: StatusMenuActionRequest, timestamp: Double, uptimeSeconds: Double
    public var event: String { "status-menu-action-arrived" }
    /// Feed these fields through the existing native observation writer; no title,
    /// reading text, selector name, URL, argv or other-app data is exported.
    public var fields: [String: Any] {
      [
        "subjectPID": request.subjectPID, "requestID": request.requestID.uuidString,
        "actionID": request.action.rawValue, "source": "NSMenu.didSendAction",
        "scope": "owned-status-menu", "nativeUptimeSeconds": uptimeSeconds,
      ]
    }
    public var object: [String: Any] {
      [
        "event": event, "runID": request.runID, "epoch": request.epoch, "timestamp": timestamp,
        "checks": fields,
      ]
    }
    public static func matches(
      _ object: [String: Any], request: StatusMenuActionRequest, afterUptime: Double,
      nowUptime: Double
    ) -> Bool {
      let fields = object["checks"] as? [String: Any] ?? object
      guard object["event"] as? String == "status-menu-action-arrived",
        object["runID"] as? String == request.runID, object["epoch"] as? String == request.epoch,
        let pid = fields["subjectPID"] as? Int32, pid == request.subjectPID,
        let id = fields["requestID"] as? String, UUID(uuidString: id) == request.requestID,
        fields["actionID"] as? String == request.action.rawValue,
        fields["source"] as? String == "NSMenu.didSendAction",
        fields["scope"] as? String == "owned-status-menu",
        let uptime = fields["nativeUptimeSeconds"] as? Double, uptime.isFinite,
        afterUptime.isFinite, nowUptime.isFinite, afterUptime <= uptime, uptime <= nowUptime,
        let timestamp = object["timestamp"] as? Double, timestamp.isFinite,
        request.notBefore <= timestamp, timestamp < request.expiresAt
      else { return false }
      return true
    }
  }
#endif
