// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanWire

public enum CockpitBridgeError: Error {
  case invalidContext, unavailable, limit, invalidMessage, staleContext, unsupportedPageContract
}
public struct CockpitEngineContext: Equatable, Sendable {
  public let sessionID: UUID, storeEpoch: String, generation: UInt64
  public init(sessionID: UUID, storeEpoch: String, generation: UInt64) throws {
    guard !storeEpoch.isEmpty, storeEpoch.utf16.count <= 128,
      !storeEpoch.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 }),
      !["legacy", "unavailable"].contains(storeEpoch)
    else { throw CockpitBridgeError.invalidContext }
    self.sessionID = sessionID
    self.storeEpoch = storeEpoch
    self.generation = generation
  }
}
public struct CockpitQueryTicket: Equatable, Sendable {
  public let pageID: UUID
  public let context: CockpitEngineContext
  public let viewRevision: UInt64
}
public struct CockpitAppearance: Equatable, Sendable {
  public enum Theme: String, Sendable { case day, night }
  public enum Locale: String, Sendable {
    case en
    case zhCN = "zh-CN"
  }
  public enum Profile: String, Sendable { case full, compact }
  public let theme: Theme, locale: Locale, profile: Profile
  public let reduceMotion: Bool, reduceTransparency: Bool, shutterClosed: Bool, detached: Bool
  public init(theme: Theme, locale: Locale, profile: Profile, reduceMotion: Bool = false, reduceTransparency: Bool = false, shutterClosed: Bool = false, detached: Bool = false) {
    self.reduceMotion = reduceMotion; self.reduceTransparency = reduceTransparency; self.shutterClosed = shutterClosed; self.detached = detached
    self.theme = theme
    self.locale = locale
    self.profile = profile
  }
}
public struct CockpitShellState: Equatable, Sendable {
  public enum Profile: String, Sendable { case open, closed }
  public enum Tier: String, Sendable { case tall, compact }
  public let profile: Profile
  public let tier: Tier
  public let scope: String
  public let attached: Bool, forcedClosed: Bool
  public init(closed: Bool, attached: Bool, forcedClosed: Bool, tier: Tier, scope: String = "all") {
    self.tier = tier; self.scope = scope
    self.profile = closed || forcedClosed ? .closed : .open
    self.attached = attached; self.forcedClosed = forcedClosed
  }
  var fields: [String: Any] {
    ["profile": profile.rawValue, "attached": attached, "forcedClosed": forcedClosed, "tier": tier.rawValue, "scope": scope]
  }
}
public struct CockpitVisibility: Equatable, Sendable {
  public let visible: Bool, occluded: Bool, key: Bool
  public init(visible: Bool, occluded: Bool, key: Bool) {
    self.visible = visible
    self.occluded = occluded
    self.key = key
  }
  var active: Bool { visible && !occluded && key }
}
public enum CockpitIntent: Equatable, Sendable {
  case chooseSetup, openSettings, close, detach, putBack, shutterToggle
  case openHistory(String)
  case scopeSelect(String)
}
public enum CockpitReceipt: Equatable {
  case ready, rendered, cleared
  case nextDeadline(UInt64?)
  case deadlinePending(UUID)
  case action(CockpitIntent)
}
public struct CockpitMessageSource {
  public let mainFrame: Bool, origin: String
  public init(mainFrame: Bool, origin: String) {
    self.mainFrame = mainFrame
    self.origin = origin
  }
}

// Replies have scalar fields plus one bounded three-string capabilities array.
// Reject nesting/duplicate keys before JSONSerialization can collapse them.
enum FlatReply {
  static func parse(_ raw: String) throws -> [String: Any] {
    guard let bytes = raw.data(using: .utf8), bytes.count <= 1_048_576 else {
      throw CockpitBridgeError.limit
    }
    let a = Array(bytes)
    var i = 0
    var keys = Set<String>()
    func white() { while i < a.count && [9, 10, 13, 32].contains(a[i]) { i += 1 } }
    func string() throws -> String {
      let start = i
      guard i < a.count, a[i] == 34 else { throw CockpitBridgeError.invalidMessage }
      i += 1
      while i < a.count {
        let c = a[i]
        i += 1
        if c == 92 {
          guard i < a.count else { throw CockpitBridgeError.invalidMessage }
          i += 1
          continue
        }
        if c == 34 {
          let value = try JSONDecoder().decode(String.self, from: Data(a[start..<i]))
          guard value.utf16.count <= 65536 else { throw CockpitBridgeError.limit }
          return value
        }
      }
      throw CockpitBridgeError.invalidMessage
    }
    white()
    guard i < a.count, a[i] == 123 else { throw CockpitBridgeError.invalidMessage }
    i += 1
    while true {
      white()
      let key = try string()
      guard keys.insert(key).inserted, keys.count <= 64 else {
        throw CockpitBridgeError.invalidMessage
      }
      white()
      guard i < a.count, a[i] == 58 else { throw CockpitBridgeError.invalidMessage }
      i += 1
      white()
      if i < a.count, a[i] == 34 {
        _ = try string()
      } else if key == "capabilities", i < a.count, a[i] == 91 {
        i += 1; white()
        var count = 0
        while i < a.count, a[i] != 93 {
          guard count < 3 else { throw CockpitBridgeError.limit }
          _ = try string(); count += 1; white()
          guard i < a.count else { throw CockpitBridgeError.invalidMessage }
          if a[i] == 93 { break }
          guard a[i] == 44 else { throw CockpitBridgeError.invalidMessage }
          i += 1; white()
          guard i < a.count, a[i] != 93 else { throw CockpitBridgeError.invalidMessage }
        }
        guard i < a.count, a[i] == 93 else { throw CockpitBridgeError.invalidMessage }
        i += 1
      } else if key == "deadlineUnixMs", i + 4 <= a.count, Array(a[i..<(i + 4)]) == Array("null".utf8) {
        i += 4
      } else {
        guard i < a.count, (key == "version" && a[i] == 50) || (key == "appearanceVersion" && (a[i] == 49 || a[i] == 50)) else {
          throw CockpitBridgeError.invalidMessage
        }
        i += 1
      }
      white()
      guard i < a.count else { throw CockpitBridgeError.invalidMessage }
      let end = a[i]
      i += 1
      if end == 125 { break }
      guard end == 44 else { throw CockpitBridgeError.invalidMessage }
    }
    white()
    guard i == a.count, let object = try JSONSerialization.jsonObject(with: bytes) as? [String: Any]
    else { throw CockpitBridgeError.invalidMessage }
    return object
  }
}

public final class CockpitBridgeState {
  public let pageID: UUID
  public private(set) var context: CockpitEngineContext
  public private(set) var viewRevision: UInt64 = 0
  public private(set) var blocked = true, disposed = false, ready = false
  public static let requiredCapabilities: Set<String> = ["appearanceUpdates", "shellState", "shellActions"]
  public private(set) var readyCapabilities: Set<String> = []
  public private(set) var appearanceVersion: Int?
  public var supportsAppearance: Bool { ready && readyCapabilities == Self.requiredCapabilities && appearanceVersion == 2 }
  private var authoritative = true
  private var loaded = false, hostSequence: UInt64 = 0, pageSequence: UInt64 = 0
  private var visibility = CockpitVisibility(visible: false, occluded: true, key: false)
  private var retiredSessions = Set<UUID>(), retiredEpochs = Set<String>(),
    historyTools = Set<String>(), actionRequests = Set<UUID>()
  private struct Pending {
    let kind: String
    let sequence: UInt64
    let tools: Set<String>
    let members: Set<String>
  }
  private var pending: [UUID: Pending] = [:]
  private var scopeMembers = Set<String>()
  struct BufferedDeadline { let value: UInt64? }
  private struct EarlyDeadline {
    let requestID: UUID, sequence: UInt64, floorSequence: UInt64, ticket: CockpitQueryTicket
    let value: UInt64?
  }
  private var latestDisplayRequest: UUID?, deadlineReportRequest: UUID?, appearanceAwaitingAck: UUID?
  private var earlyDeadline: EarlyDeadline?, bufferedDeadline: BufferedDeadline?
  private var deadlineBasisSequence: UInt64 = 0
  private static let maximumUnixMs: UInt64 = 8_640_000_000_000_000
  public init(context: CockpitEngineContext, pageID: UUID = UUID()) {
    self.context = context
    self.pageID = pageID
  }
  public var queryTicket: CockpitQueryTicket? {
    ready && !blocked && !disposed
      ? CockpitQueryTicket(pageID: pageID, context: context, viewRevision: viewRevision) : nil
  }
  private func envelope(
    _ type: String, extra: [String: Any] = [:], receipt: String? = nil, tools: Set<String> = [], members: Set<String> = [], deadlineReport: Bool = false, appearanceDeadline: Bool = false
  ) throws -> String {
    guard !disposed, hostSequence < UInt64.max, pending.count < 32 else {
      throw CockpitBridgeError.unavailable
    }
    hostSequence += 1
    let id = UUID()
    var body: [String: Any] = [
      "version": 2, "pageId": pageID.uuidString, "requestId": id.uuidString,
      "sessionId": context.sessionID.uuidString, "storeEpoch": context.storeEpoch,
      "generation": String(context.generation), "viewRevision": String(viewRevision),
      "sequence": String(hostSequence), "type": type,
    ]
    for (k, v) in extra { body[k] = v }
    let data = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
    guard data.count <= 1_048_576 else { throw CockpitBridgeError.limit }
    if let receipt { pending[id] = Pending(kind: receipt, sequence: hostSequence, tools: tools, members: members) }
    if type == "display" { latestDisplayRequest = id; cancelDeadlineReports(); deadlineBasisSequence = hostSequence }
    if deadlineReport { cancelDeadlineReports(); deadlineReportRequest = id; deadlineBasisSequence = hostSequence }
    if appearanceDeadline { cancelDeadlineReports(); appearanceAwaitingAck = id; deadlineBasisSequence = hostSequence }
    return String(decoding: data, as: UTF8.self)
  }
  public func load(_ appearance: CockpitAppearance, shell: CockpitShellState) throws -> String {
    guard !loaded else { throw CockpitBridgeError.unavailable }
    guard CockpitMemberScopes.isValidKey(shell.scope) else { throw CockpitBridgeError.invalidMessage }
    loaded = true
    return try envelope(
      "load",
      extra: [
        "appearance": [
          "theme": appearance.theme.rawValue, "locale": appearance.locale.rawValue,
          "reduceMotion": appearance.reduceMotion, "reduceTransparency": appearance.reduceTransparency,
        ],
        "shell": shell.fields,
      ], receipt: "ready")
  }
  public func setAppearance(_ appearance: CockpitAppearance, deadlineEligible: Bool = false) throws -> String {
    guard ready, !blocked, supportsAppearance else { throw CockpitBridgeError.unavailable }
    let correlated = deadlineEligible && visibility.visible && !visibility.occluded
    return try envelope("appearance", extra: [
      "theme": appearance.theme.rawValue, "locale": appearance.locale.rawValue,
      "reduceMotion": appearance.reduceMotion, "reduceTransparency": appearance.reduceTransparency,
    ], appearanceDeadline: correlated)
  }
  public func setShell(_ shell: CockpitShellState) throws -> String {
    guard ready, !blocked, supportsAppearance else { throw CockpitBridgeError.unavailable }
    guard CockpitMemberScopes.isValidKey(shell.scope), scopeMembers.isEmpty || scopeMembers.contains(shell.scope) else { throw CockpitBridgeError.invalidMessage }
    return try envelope("shell", extra: shell.fields)
  }
  public func display(_ data: WireCockpitData, ticket: CockpitQueryTicket) throws -> String {
    guard ticket == queryTicket else { throw CockpitBridgeError.staleContext }
    // A newer display retires all prior unacknowledged display receipts.
    pending = pending.filter { $0.value.kind != "rendered" }
    let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(data))
    let tools = Set(data.projection.rows.filter { $0.kind == .tool && !$0.invalid }.map { $0.id })
    return try envelope("display", extra: ["data": object], receipt: "rendered", tools: tools, members: CockpitMemberScopes.keys(data))
  }
  func cancelDeadlineReports() {
    deadlineReportRequest = nil; appearanceAwaitingAck = nil; earlyDeadline = nil; bufferedDeadline = nil
  }
  var currentDisplayRequest: UUID? { latestDisplayRequest }
  var hasPendingDisplay: Bool {
    guard let id = latestDisplayRequest else { return false }
    return pending[id]?.kind == "rendered"
  }
  func awaitsDisplayReceipt(_ id: UUID) -> Bool {
    !disposed && !blocked && visibility.visible && !visibility.occluded &&
      latestDisplayRequest == id && pending[id]?.kind == "rendered"
  }
  var currentDeadlineTrigger: UUID? { deadlineReportRequest }
  var currentAppearanceTrigger: UUID? { appearanceAwaitingAck }
  func isCurrentAppearance(_ id: UUID) -> Bool { appearanceAwaitingAck == id && !disposed && !blocked }
  @discardableResult func acknowledgeAppearance(_ id: UUID) -> Bool {
    guard isCurrentAppearance(id), visibility.visible, !visibility.occluded else { return false }
    appearanceAwaitingAck = nil
    if let early = earlyDeadline {
      // Appearance has no Web rendered receipt: its early report reserves its
      // page sequence on arrival, so a later valid action may advance it.
      guard early.requestID == id, early.ticket == queryTicket, early.sequence <= pageSequence else {
        cancelDeadlineReports(); return false
      }
      bufferedDeadline = BufferedDeadline(value: early.value)
      earlyDeadline = nil; deadlineReportRequest = nil
    } else { deadlineReportRequest = id }
    return true
  }
  func isCurrentDisplay(_ id: UUID) -> Bool { latestDisplayRequest == id && !disposed && !blocked }
  func isCurrentDeadlineTrigger(_ id: UUID) -> Bool { deadlineReportRequest == id && !disposed && !blocked }
  func awaitsDeadlineReceipt(_ id: UUID) -> Bool {
    !disposed && !blocked && visibility.visible && !visibility.occluded &&
      (deadlineReportRequest == id || appearanceAwaitingAck == id ||
       (latestDisplayRequest == id && pending[id]?.kind == "rendered" && pending[id]?.sequence == deadlineBasisSequence) ||
       (earlyDeadline?.requestID == id && (latestDisplayRequest == id || appearanceAwaitingAck == id)))
  }
  func takeBufferedDeadline() -> BufferedDeadline? {
    defer { bufferedDeadline = nil }
    return bufferedDeadline
  }
  func tick(nowUnixMs: UInt64, reason: CockpitDeadlineReason) throws -> String {
    guard ready, !blocked, !disposed, visibility.visible, !visibility.occluded,
      nowUnixMs <= Self.maximumUnixMs else { throw CockpitBridgeError.unavailable }
    return try envelope("tick", extra: ["nowUnixMs": String(nowUnixMs), "reason": reason.rawValue], deadlineReport: true)
  }
  public func setVisibility(_ value: CockpitVisibility) throws -> String {
    guard ready, !blocked else { throw CockpitBridgeError.unavailable }
    if !value.visible || value.occluded { cancelDeadlineReports() }
    visibility = value
    return try envelope(
      "visibility", extra: ["visible": value.visible, "occluded": value.occluded, "key": value.key])
  }
  public func clear(adopting next: CockpitEngineContext? = nil) throws -> String {
    guard loaded, viewRevision < UInt64.max else { throw CockpitBridgeError.unavailable }
    let nextFloorKnown = next != nil
    let next = next ?? context
    guard !retiredSessions.contains(next.sessionID), !retiredEpochs.contains(next.storeEpoch),
      next.storeEpoch != context.storeEpoch || next.generation >= context.generation
    else { throw CockpitBridgeError.staleContext }
    if next.sessionID != context.sessionID { retiredSessions.insert(context.sessionID) }
    if next.storeEpoch != context.storeEpoch { retiredEpochs.insert(context.storeEpoch) }
    guard retiredSessions.count <= 128, retiredEpochs.count <= 128 else {
      throw CockpitBridgeError.limit
    }
    authoritative = nextFloorKnown
    context = next
    viewRevision += 1
    blocked = true
    historyTools.removeAll()
    scopeMembers.removeAll()
    latestDisplayRequest = nil; cancelDeadlineReports()
    pending.removeAll()
    return try envelope("clear", receipt: "cleared")
  }
  public func unload() -> String? {
    let message = try? envelope("unload")
    dispose()
    return message
  }
  public func dispose() {
    disposed = true
    blocked = true
    ready = false
    readyCapabilities.removeAll(); appearanceVersion = nil
    historyTools.removeAll()
    scopeMembers.removeAll()
    pending.removeAll()
    actionRequests.removeAll()
    latestDisplayRequest = nil; cancelDeadlineReports()
    retiredEpochs.removeAll()
    retiredSessions.removeAll()
  }
  private func uint(_ value: Any?) -> UInt64? {
    guard let s = value as? String, !s.isEmpty, s == "0" || s.first != "0", let n = UInt64(s),
      String(n) == s
    else { return nil }
    return n
  }
  public func accept(_ raw: String, source: CockpitMessageSource) throws -> CockpitReceipt {
    guard !disposed, source.mainFrame, source.origin == "modelplan-cockpit://bundle" else {
      throw CockpitBridgeError.invalidMessage
    }
    let m = try FlatReply.parse(raw)
    let base: Set<String> = [
      "version", "pageId", "requestId", "sessionId", "storeEpoch", "generation", "viewRevision",
      "sequence", "type",
    ]
    guard m["version"] as? Int == 2, let page = m["pageId"] as? String,
      UUID(uuidString: page) == pageID, let request = m["requestId"] as? String,
      let id = UUID(uuidString: request), let session = m["sessionId"] as? String,
      UUID(uuidString: session) == context.sessionID,
      m["storeEpoch"] as? String == context.storeEpoch, uint(m["generation"]) == context.generation,
      uint(m["viewRevision"]) == viewRevision, let sequence = uint(m["sequence"]),
      let type = m["type"] as? String
    else { throw CockpitBridgeError.invalidMessage }
    // The page emits rendered before its deadline report, but transport may
    // deliver the report and a later action first. Admit only the matching,
    // still-current rendered receipt in the proven gap; never roll back the
    // monotonic page sequence or accept an older context.
    let earlyDisplay = earlyDeadline.flatMap { early -> EarlyDeadline? in
      guard early.requestID == latestDisplayRequest, early.ticket == queryTicket,
        pending[early.requestID]?.kind == "rendered",
        pending[early.requestID]?.sequence == deadlineBasisSequence else { return nil }
      return early
    }
    let lateRendered = type == "rendered" && earlyDisplay?.requestID == id &&
      sequence > (earlyDisplay?.floorSequence ?? UInt64.max) && sequence < (earlyDisplay?.sequence ?? 0)
    if type == "rendered", earlyDisplay?.requestID == id, !lateRendered { throw CockpitBridgeError.invalidMessage }
    guard sequence > pageSequence || lateRendered else { throw CockpitBridgeError.invalidMessage }
    if type == "nextDeadline" {
      guard Set(m.keys) == base.union(["deadlineUnixMs"]), ready, !blocked,
        visibility.visible, !visibility.occluded else { throw CockpitBridgeError.invalidMessage }
      let deadline: UInt64?
      if m["deadlineUnixMs"] is NSNull { deadline = nil }
      else {
        guard let value = uint(m["deadlineUnixMs"]), value <= Self.maximumUnixMs else {
          throw CockpitBridgeError.invalidMessage
        }
        deadline = value
      }
      if deadlineReportRequest == id {
        deadlineReportRequest = nil; pageSequence = sequence
        return .nextDeadline(deadline)
      }
      let isCurrentDisplayReceipt = id == latestDisplayRequest && pending[id]?.kind == "rendered" && pending[id]?.sequence == deadlineBasisSequence
      guard earlyDeadline == nil, (isCurrentDisplayReceipt || appearanceAwaitingAck == id),
        let ticket = queryTicket else { throw CockpitBridgeError.invalidMessage }
      earlyDeadline = EarlyDeadline(requestID: id, sequence: sequence, floorSequence: pageSequence, ticket: ticket, value: deadline)
      if appearanceAwaitingAck == id { pageSequence = sequence }
      return .deadlinePending(id)
    }
    if type == "action" {
      if let earlyDisplay, sequence <= earlyDisplay.sequence { throw CockpitBridgeError.invalidMessage }
      let action = m["action"] as? String
      let history = action == "openHistory", scope = action == "scopeSelect"
      let extra:Set<String> = history ? ["action","tool"] : scope ? ["action","key"] : ["action"]
      guard Set(m.keys) == base.union(extra), ready, !blocked,
        visibility.active, actionRequests.count < 1024, !actionRequests.contains(id)
      else { throw CockpitBridgeError.invalidMessage }
      let intent: CockpitIntent
      switch action {
      case "chooseSetup": intent = .chooseSetup
      case "openSettings": intent = .openSettings
      case "scopeSelect":
        guard let key=m["key"] as? String, scopeMembers.contains(key),
          earlyDisplay.map({ pending[$0.requestID]?.members.contains(key) == true }) ?? true else { throw CockpitBridgeError.invalidMessage }
        intent = .scopeSelect(key)
      case "close": intent = .close
      case "detach": intent = .detach
      case "putBack": intent = .putBack
      case "shutterToggle": intent = .shutterToggle
      case "openHistory":
        guard let tool = m["tool"] as? String, historyTools.contains(tool),
          earlyDisplay.map({ pending[$0.requestID]?.tools.contains(tool) == true }) ?? true else {
          throw CockpitBridgeError.invalidMessage
        }
        intent = .openHistory(tool)
      default: throw CockpitBridgeError.invalidMessage
      }
      actionRequests.insert(id)
      pageSequence = sequence
      return .action(intent)
    }
    if type == "ready" {
      guard Set(m.keys) == base.union(["appearanceVersion", "capabilities"]),
        m["appearanceVersion"] as? Int == 2, let capabilities = m["capabilities"] as? [String],
        capabilities.count == 3, Set(capabilities) == Self.requiredCapabilities else {
        throw CockpitBridgeError.unsupportedPageContract
      }
    }
    guard Set(m.keys) == (type == "ready" ? base.union(["appearanceVersion", "capabilities"]) : base),
      let expected = pending[id], expected.kind == type else {
      throw CockpitBridgeError.invalidMessage
    }
    pending[id] = nil
    pageSequence = max(pageSequence, sequence)
    switch type {
    case "ready":
      readyCapabilities = Self.requiredCapabilities
      appearanceVersion = 2
      ready = true
      blocked = false
      return .ready
    case "cleared":
      blocked = !authoritative
      return .cleared
    case "rendered":
      if id == latestDisplayRequest && expected.sequence == deadlineBasisSequence && visibility.visible && !visibility.occluded {
        if let early = earlyDeadline, early.requestID == id, early.ticket == queryTicket,
          early.sequence > early.floorSequence {
          pageSequence = max(pageSequence, early.sequence)
          bufferedDeadline = BufferedDeadline(value: early.value)
          earlyDeadline = nil; deadlineReportRequest = nil
        } else { deadlineReportRequest = id }
      }
      historyTools = expected.tools
      scopeMembers = expected.members
      return .rendered
    default: throw CockpitBridgeError.invalidMessage
    }
  }
}
