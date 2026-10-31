// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanWire

public enum CockpitBridgeError: Error {
  case invalidContext, unavailable, limit, invalidMessage, staleContext
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
public struct CockpitAppearance: Sendable {
  public enum Theme: String, Sendable { case day, night }
  public enum Locale: String, Sendable {
    case en
    case zhCN = "zh-CN"
  }
  public enum Profile: String, Sendable { case full, compact }
  public let theme: Theme, locale: Locale, profile: Profile
  public init(theme: Theme, locale: Locale, profile: Profile) {
    self.theme = theme
    self.locale = locale
    self.profile = profile
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
  case chooseSetup, openSettings
  case openHistory(String)
}
public enum CockpitReceipt: Equatable {
  case ready, rendered, cleared
  case action(CockpitIntent)
}
public struct CockpitMessageSource {
  public let mainFrame: Bool, origin: String
  public init(mainFrame: Bool, origin: String) {
    self.mainFrame = mainFrame
    self.origin = origin
  }
}

// All allowed page replies are flat. Reject nesting/duplicate keys before
// JSONSerialization can collapse duplicates. The outbound display remains typed.
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
      } else {
        guard i < a.count, a[i] == 49 else { throw CockpitBridgeError.invalidMessage }
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
  private var authoritative = true
  private var loaded = false, hostSequence: UInt64 = 0, pageSequence: UInt64 = 0
  private var visibility = CockpitVisibility(visible: false, occluded: true, key: false)
  private var retiredSessions = Set<UUID>(), retiredEpochs = Set<String>(),
    historyTools = Set<String>(), actionRequests = Set<UUID>()
  private struct Pending {
    let kind: String
    let tools: Set<String>
  }
  private var pending: [UUID: Pending] = [:]
  public init(context: CockpitEngineContext, pageID: UUID = UUID()) {
    self.context = context
    self.pageID = pageID
  }
  public var queryTicket: CockpitQueryTicket? {
    ready && !blocked && !disposed
      ? CockpitQueryTicket(pageID: pageID, context: context, viewRevision: viewRevision) : nil
  }
  private func envelope(
    _ type: String, extra: [String: Any] = [:], receipt: String? = nil, tools: Set<String> = []
  ) throws -> String {
    guard !disposed, hostSequence < UInt64.max, pending.count < 32 else {
      throw CockpitBridgeError.unavailable
    }
    hostSequence += 1
    let id = UUID()
    var body: [String: Any] = [
      "version": 1, "pageId": pageID.uuidString, "requestId": id.uuidString,
      "sessionId": context.sessionID.uuidString, "storeEpoch": context.storeEpoch,
      "generation": String(context.generation), "viewRevision": String(viewRevision),
      "sequence": String(hostSequence), "type": type,
    ]
    for (k, v) in extra { body[k] = v }
    let data = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
    guard data.count <= 1_048_576 else { throw CockpitBridgeError.limit }
    if let receipt { pending[id] = Pending(kind: receipt, tools: tools) }
    return String(decoding: data, as: UTF8.self)
  }
  public func load(_ appearance: CockpitAppearance) throws -> String {
    guard !loaded else { throw CockpitBridgeError.unavailable }
    loaded = true
    return try envelope(
      "load",
      extra: [
        "appearance": [
          "theme": appearance.theme.rawValue, "locale": appearance.locale.rawValue,
          "profile": appearance.profile.rawValue,
        ]
      ], receipt: "ready")
  }
  public func display(_ data: WireCockpitData, ticket: CockpitQueryTicket) throws -> String {
    guard ticket == queryTicket else { throw CockpitBridgeError.staleContext }
    let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(data))
    let tools = Set(data.projection.rows.filter { $0.kind == .tool && !$0.invalid }.map { $0.id })
    return try envelope("display", extra: ["data": object], receipt: "rendered", tools: tools)
  }
  public func setVisibility(_ value: CockpitVisibility) throws -> String {
    guard ready, !blocked else { throw CockpitBridgeError.unavailable }
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
    historyTools.removeAll()
    pending.removeAll()
    actionRequests.removeAll()
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
    guard m["version"] as? Int == 1, let page = m["pageId"] as? String,
      UUID(uuidString: page) == pageID, let request = m["requestId"] as? String,
      let id = UUID(uuidString: request), let session = m["sessionId"] as? String,
      UUID(uuidString: session) == context.sessionID,
      m["storeEpoch"] as? String == context.storeEpoch, uint(m["generation"]) == context.generation,
      uint(m["viewRevision"]) == viewRevision, let sequence = uint(m["sequence"]),
      sequence > pageSequence, let type = m["type"] as? String
    else { throw CockpitBridgeError.invalidMessage }
    if type == "action" {
      let action = m["action"] as? String
      let history = action == "openHistory"
      guard Set(m.keys) == base.union(history ? ["action", "tool"] : ["action"]), ready, !blocked,
        visibility.active, actionRequests.count < 1024, !actionRequests.contains(id)
      else { throw CockpitBridgeError.invalidMessage }
      let intent: CockpitIntent
      switch action {
      case "chooseSetup": intent = .chooseSetup
      case "openSettings": intent = .openSettings
      case "openHistory":
        guard let tool = m["tool"] as? String, historyTools.contains(tool) else {
          throw CockpitBridgeError.invalidMessage
        }
        intent = .openHistory(tool)
      default: throw CockpitBridgeError.invalidMessage
      }
      actionRequests.insert(id)
      pageSequence = sequence
      return .action(intent)
    }
    guard Set(m.keys) == base, let expected = pending[id], expected.kind == type else {
      throw CockpitBridgeError.invalidMessage
    }
    pending[id] = nil
    pageSequence = sequence
    switch type {
    case "ready":
      ready = true
      blocked = false
      return .ready
    case "cleared":
      blocked = !authoritative
      return .cleared
    case "rendered":
      historyTools = expected.tools
      return .rendered
    default: throw CockpitBridgeError.invalidMessage
    }
  }
}
