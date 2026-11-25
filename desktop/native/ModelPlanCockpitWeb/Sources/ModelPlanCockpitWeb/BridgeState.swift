// SPDX-License-Identifier: MIT
import Foundation
import OSLog
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
/// CKP-SHELL-40 (owner D205): v1 is night-only. The cockpit renders the night look whatever the macOS
/// appearance or the saved theme; the day paths in the page and in this module stay intact behind this one
/// switch. v1.1 turns the day cockpit back on by setting `dayCockpit` (default off) at launch.
public enum CockpitDayPolicy {
  private static let lock = NSLock()
  private static var enabled = false
  /// Off in v1. Tests flip it and restore it; nothing else writes it.
  public static var dayCockpit: Bool {
    get { lock.lock(); defer { lock.unlock() }; return enabled }
    set { lock.lock(); defer { lock.unlock() }; enabled = newValue }
  }
  /// The theme the cockpit may show for a requested one.
  public static func resolve(_ requested: CockpitAppearance.Theme) -> CockpitAppearance.Theme {
    dayCockpit ? requested : .night
  }
  /// The same pin for the field page's own theme enum.
  public static func resolveField(dark: Bool) -> Bool { dayCockpit ? dark : true }
}
public struct CockpitAppearance: Equatable, Sendable {
  public enum Theme: String, Sendable { case day, night }
  public enum Locale: String, Sendable {
    case en
    case zhCN = "zh-CN"
  }
  /// D444 (owner, 2026-11-25): one cockpit layout; the short (640) version is retired.
  public enum Profile: String, Sendable { case full }
  public let theme: Theme, locale: Locale, profile: Profile
  public let reduceMotion: Bool, reduceTransparency: Bool, shutterClosed: Bool, detached: Bool
  public let redBelow: Int
  /// Settings "Project names": off withholds project labels from every cockpit surface.
  public let showProjectNames: Bool
  /// Settings "Percentage mode" = used (SET-9-10): the engine table shows used, text and bars.
  public let showUsedPercent: Bool
  /// Settings "Show all models" (D135): the fader deck lifts the own-plans filter and the 12-fader cap.
  public let showAllModels: Bool
  /// Settings "Cockpit size": native window geometry only, never sent to the page.
  public let size: CockpitSize
  /// D244 (owner 2026-11-13): the saved subscription order from Settings › Subscriptions, shared with the
  /// widget. Members it names come first in this order; the rest follow in the engine's order. Empty = default.
  public let memberOrder: [String]
  /// Subscription visibility from Settings; session data remains available to the tape.
  public let hiddenMembers: [String]
  public init(theme: Theme, locale: Locale, profile: Profile, reduceMotion: Bool = false, reduceTransparency: Bool = false, shutterClosed: Bool = false, detached: Bool = false, redBelow: Int? = nil, showProjectNames: Bool = true, showUsedPercent: Bool = false, showAllModels: Bool = false, size: CockpitSize = .standard, memberOrder: [String] = [], hiddenMembers: [String] = []) {
    self.showProjectNames = showProjectNames; self.showUsedPercent = showUsedPercent; self.showAllModels = showAllModels; self.size = size
    var seen = Set<String>()
    self.memberOrder = Array(memberOrder.filter { $0 != "all" && CockpitMemberScopes.isValidKey($0) && seen.insert($0).inserted }.prefix(256))
    seen.removeAll()
    self.hiddenMembers = Array(hiddenMembers.filter { $0 != "all" && CockpitMemberScopes.isValidKey($0) && seen.insert($0).inserted }.prefix(256))
    if let redBelow, [10, 15, 20, 25, 30, 40].contains(redBelow) {
      self.redBelow = redBelow
    } else {
      self.redBelow = 25
      Logger(subsystem: "org.modelplan.community", category: "cockpit").warning("Missing or invalid cockpit alert threshold; using default")
    }
    self.reduceMotion = reduceMotion; self.reduceTransparency = reduceTransparency; self.shutterClosed = shutterClosed; self.detached = detached
    self.theme = theme
    self.locale = locale
    self.profile = profile
  }
}
/// CKP-SHELL-50 (WP-09): the one time range every range-dependent figure follows (usage, ≈cost, speed, share,
/// ranking). The app owns it and keeps it across restarts; the menu bar, the title bar and the big-screen keys only
/// show it and ask to change it. Quota, resets, alerts and sessions are "now" and never follow it. A fresh profile
/// starts at 7d, the range the design's totals are drawn in (V1-FINAL §8.1 "7天 ≈$383 788M").
public enum CockpitRange: String, CaseIterable, Equatable, Sendable {
  case today, sevenDays = "7d", thirtyDays = "30d"
  public static let initial: CockpitRange = .sevenDays
  /// T cycles Today → 7d → 30d → Today.
  public var next: CockpitRange {
    switch self { case .today: return .sevenDays; case .sevenDays: return .thirtyDays; case .thirtyDays: return .today }
  }
}
public struct CockpitShellState: Equatable, Sendable {
  public enum Profile: String, Sendable { case open, closed }
  /// D444: one layout, so the wire's `tier` is always `tall` (the key stays for the page's exact-key check).
  public enum Tier: String, Sendable { case tall }
  public let profile: Profile
  public let tier: Tier
  public let scope: String
  /// CKP-SHELL-50: the app's range, sent with the shell so the page has it before its first render.
  public let range: CockpitRange
  /// A native member read is in flight; the Overview refresh waits for it.
  public let refreshing: Bool
  public let attached: Bool, forcedClosed: Bool
  public init(closed: Bool, attached: Bool, forcedClosed: Bool, tier: Tier, scope: String = "all", range: CockpitRange = .initial, refreshing: Bool = false) {
    self.tier = tier; self.scope = scope; self.range = range; self.refreshing = refreshing
    self.profile = closed || forcedClosed ? .closed : .open
    self.attached = attached; self.forcedClosed = forcedClosed
  }
  var fields: [String: Any] {
    ["profile": profile.rawValue, "attached": attached, "forcedClosed": forcedClosed, "tier": tier.rawValue, "scope": scope, "range": range.rawValue, "refreshing": refreshing]
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
  case chooseSetup, openSettings, openSettingsSubscriptions, close, detach, putBack, shutterToggle, openField
  case openHistory(String)
  /// D63: open the enlarged field focused on the rocket with this published display name (resolved by the host).
  case openFieldAt(String)
  case scopeSelect(String)
  /// CKP-SHELL-50: the page asks the app for this range (big-screen key or T). The app decides and echoes it in the shell.
  case rangeSelect(CockpitRange)
  /// Owner D277 (CKP-ENG-27): read this shown member again, or every member for `all`. The host resolves the key
  /// against its own members and asks the engine through the widget's per-member refresh.
  case refreshMember(String)
  /// G3-56: the caution identities the owner has acknowledged by pressing the lamp. The coordinator keeps them.
  case cautionAck([String])
  /// D136: the favourite (long-press pinned) model ids, most recent first. The coordinator keeps them across restarts.
  case pinnedModels([String])
  case openWebsite(CockpitWebsiteLink)
  /// Plugin columns (macrevc-844-1): the plugins the page runs now; the host samples exactly these. Accepted while the
  /// page is hidden too (it reports [] when it stops showing them).
  case pluginsRunning([String])
  /// A plugin edit made on the page (right-click Remove or the + menu), as `CockpitPluginWire.canonical` JSON.
  case pluginsEdit(Data)
  /// D376: the page's right-click Remove on a plugin key; the app confirms and turns that plugin off.
  case pluginClose(String)
}
/// A typed public page, never a URL from the page: native builds the address from these fields.
public struct CockpitWebsiteLink: Equatable, Sendable {
  public enum Page: String, Sendable { case plans, effort, methodology }
  public let page: Page, value: String
  public init?(page: String?, value: String?) {
    guard let page = page.flatMap(Page.init(rawValue:)), let value, (1...64).contains(value.utf8.count),
      value.utf8.allSatisfy({ (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || [45, 46, 95].contains($0) })
    else { return nil }
    self.page = page; self.value = value
  }
  public var url: URL {
    var parts = URLComponents(); parts.scheme = "https"; parts.host = "modelplan.ai"; parts.path = "/" + page.rawValue
    switch page {
    case .plans: parts.queryItems = [.init(name: "seller", value: value)]
    case .effort: parts.queryItems = [.init(name: "model", value: value)]
    case .methodology: parts.fragment = value
    }
    return parts.url!
  }
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

// Replies have scalar fields plus two bounded flat string arrays: the three-string `capabilities` of `ready` and the
// `ids` (at most CockpitCautionIdentities.maxCount) of `cautionAck`, `pinnedModels` and `pluginsRunning`. The one
// nested value is the `plugins` body of `pluginsEdit` (macrevc-844-1), scanned with its own bounds. No other key may
// carry an array or an object. Reject duplicate keys at every level before JSONSerialization can collapse them.
enum FlatReply {
  static let nestedDepth = 4, nestedKeys = 64, nestedItems = 32, nestedBytes = 65_536
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
    // The `plugins` body: objects, arrays and scalars, at most `nestedDepth` containers deep, `nestedKeys` unique keys per
    // object, `nestedItems` items per array and `nestedBytes` bytes. CockpitPluginWire.canonical then checks its shape.
    var nestedStart = 0
    func scalar() throws {
      let literal: (String) -> Bool = { word in
        let w = Array(word.utf8)
        guard i + w.count <= a.count, Array(a[i..<(i + w.count)]) == w else { return false }
        i += w.count; return true
      }
      if literal("true") || literal("false") || literal("null") { return }
      let start = i
      while i < a.count, a[i] == 45 || a[i] == 43 || a[i] == 46 || a[i] == 69 || a[i] == 101 || (48...57).contains(a[i]) { i += 1 }
      guard i > start, i - start <= 32 else { throw CockpitBridgeError.invalidMessage }
    }
    func nested(_ depth: Int) throws {
      guard depth <= nestedDepth, i - nestedStart <= nestedBytes else { throw CockpitBridgeError.limit }
      white()
      guard i < a.count else { throw CockpitBridgeError.invalidMessage }
      if a[i] == 34 { _ = try string(); return }
      guard a[i] == 123 || a[i] == 91 else { try scalar(); return }
      let object = a[i] == 123, close: UInt8 = object ? 125 : 93
      i += 1; white()
      if i < a.count, a[i] == close { i += 1; return }
      var names = Set<String>(), count = 0
      while true {
        count += 1
        guard count <= (object ? nestedKeys : nestedItems) else { throw CockpitBridgeError.limit }
        if object {
          white()
          let name = try string()
          guard names.insert(name).inserted else { throw CockpitBridgeError.invalidMessage }
          white()
          guard i < a.count, a[i] == 58 else { throw CockpitBridgeError.invalidMessage }
          i += 1
        }
        try nested(depth + 1)
        white()
        guard i < a.count else { throw CockpitBridgeError.invalidMessage }
        let end = a[i]; i += 1
        if end == close { break }
        guard end == 44 else { throw CockpitBridgeError.invalidMessage }
      }
      guard i - nestedStart <= nestedBytes else { throw CockpitBridgeError.limit }
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
      } else if key == "plugins", i < a.count, a[i] == 123 {
        let start = i
        nestedStart = i
        try nested(1)
        guard i - start <= nestedBytes else { throw CockpitBridgeError.limit }
      } else if key == "capabilities" || key == "ids", i < a.count, a[i] == 91 {
        // Flat arrays of strings only: the ready capabilities and the cautionAck identities (G3-56).
        let limit = key == "ids" ? CockpitCautionIdentities.maxCount : 3
        i += 1; white()
        var count = 0
        while i < a.count, a[i] != 93 {
          guard count < limit else { throw CockpitBridgeError.limit }
          _ = try string(); count += 1; white()
          guard i < a.count else { throw CockpitBridgeError.invalidMessage }
          if a[i] == 93 { break }
          guard a[i] == 44 else { throw CockpitBridgeError.invalidMessage }
          i += 1; white()
          guard i < a.count, a[i] != 93 else { throw CockpitBridgeError.invalidMessage }
        }
        guard i < a.count, a[i] == 93 else { throw CockpitBridgeError.invalidMessage }
        i += 1
      } else if key == "plugins", i < a.count, a[i] == 123 {
        // Plugin columns: the page's `pluginsEdit` body is the one nested value. Skip it as a balanced object (strings
        // read with escapes); CockpitPluginPreferences.fromPage then checks its exact shape.
        let start = i
        var depth = 0
        repeat {
          guard i < a.count, i - start <= 65_536 else { throw CockpitBridgeError.limit }
          switch a[i] {
          case 34: _ = try string(); continue
          case 123, 91: depth += 1
          case 125, 93: depth -= 1
          default: break
          }
          i += 1
        } while depth > 0
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

/// The page sends opaque caution identities (a member reference, a window id and a severity). Bounded and printable only.
public enum CockpitCautionIdentities {
  public static let maxCount = 64, maxBytes = 200
  public static func valid(_ ids: [String]) -> Bool {
    ids.count <= maxCount && ids.allSatisfy { !$0.isEmpty && $0.utf8.count <= maxBytes && $0.utf8.allSatisfy { $0 >= 32 && $0 != 127 } }
  }
  /// G3-135: only an identity led by a verified subscription reference (16 hex) names the same account after a restart.
  /// A fallback member's identity is kept in memory for the session and never written to disk.
  public static func durable(_ ids: [String]) -> [String] {
    ids.filter { id in
      guard let data = id.data(using: .utf8), let array = (try? JSONSerialization.jsonObject(with: data)) as? [Any], let first = array.first as? String else { return false }
      return first.utf8.count == 16 && first.utf8.allSatisfy { ($0 >= 48 && $0 <= 57) || ($0 >= 97 && $0 <= 102) }
    }
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
  /// G3-56: set before `load`; the page restores its acknowledged cautions from it.
  public var ackedCautions: [String] = []
  /// D136: favourite model ids restored from the app's own file; sent on load.
  public var pinnedModels: [String] = []
  /// Plugin columns: the host sent its plugin state (`plugins`); only then may it push readings or accept the page's
  /// plugin actions. The page keeps its negotiation across a clear, so this does too.
  public private(set) var pluginsSent = false
  private var loaded = false, hostSequence: UInt64 = 0, pageSequence: UInt64 = 0
  private var visibility = CockpitVisibility(visible: false, occluded: true, key: false)
  private var retiredSessions = Set<UUID>(), retiredEpochs = Set<String>(),
    historyTools = Set<String>()
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
  /// Recovery contract (step 2): the host's correlated health probe for this page. main.ts `state(pageId)` answers
  /// only for its own page; a replaced one answers "mismatch", which is never taken as liveness. The page id is a UUID,
  /// so it is safe inside the script's string literal. The controller adopts it in step 2b; until then it probes
  /// without the id, as before.
  public var probeScript: String {
    "const c=window.modelPlanCockpit;return c&&typeof c.state==='function'?String(c.state('\(pageID.uuidString)')):'missing'"
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
    var extra: [String: Any] = [
      "appearance": [
        "theme": appearance.theme.rawValue, "locale": appearance.locale.rawValue,
        "reduceMotion": appearance.reduceMotion, "reduceTransparency": appearance.reduceTransparency,
        "showProjectNames": appearance.showProjectNames,
      ],
      "shell": shell.fields, "redBelow": appearance.redBelow, "showUsedPercent": appearance.showUsedPercent, "showAllModels": appearance.showAllModels,
    ]
    // G3-56: sent only when there is something to restore, so a page that has none sees the unchanged contract.
    if CockpitCautionIdentities.valid(ackedCautions), !ackedCautions.isEmpty { extra["ackedCautions"] = ackedCautions }
    if CockpitCautionIdentities.valid(pinnedModels), Set(pinnedModels).count == pinnedModels.count, !pinnedModels.isEmpty { extra["pinnedModels"] = pinnedModels }
    // D244: likewise the saved member order; absent means the engine's default order.
    if !appearance.memberOrder.isEmpty { extra["memberOrder"] = appearance.memberOrder }
    if !appearance.hiddenMembers.isEmpty { extra["hiddenMembers"] = appearance.hiddenMembers }
    return try envelope("load", extra: extra, receipt: "ready")
  }
  public func setAppearance(_ appearance: CockpitAppearance, deadlineEligible: Bool = false) throws -> String {
    guard ready, !blocked, supportsAppearance else { throw CockpitBridgeError.unavailable }
    let correlated = deadlineEligible && visibility.visible && !visibility.occluded
    var extra: [String: Any] = [
      "theme": appearance.theme.rawValue, "locale": appearance.locale.rawValue,
      "reduceMotion": appearance.reduceMotion, "reduceTransparency": appearance.reduceTransparency,
      "showProjectNames": appearance.showProjectNames, "redBelow": appearance.redBelow, "showUsedPercent": appearance.showUsedPercent, "showAllModels": appearance.showAllModels,
    ]
    // D244: absent means the default order, so a reset in Settings reaches an open page too.
    if !appearance.memberOrder.isEmpty { extra["memberOrder"] = appearance.memberOrder }
    if !appearance.hiddenMembers.isEmpty { extra["hiddenMembers"] = appearance.hiddenMembers }
    return try envelope("appearance", extra: extra, appearanceDeadline: correlated)
  }
  public func setShell(_ shell: CockpitShellState) throws -> String {
    guard ready, !blocked, supportsAppearance else { throw CockpitBridgeError.unavailable }
    guard CockpitMemberScopes.isValidKey(shell.scope), scopeMembers.isEmpty || scopeMembers.contains(shell.scope) else { throw CockpitBridgeError.invalidMessage }
    return try envelope("shell", extra: shell.fields)
  }
  /// CKP-SHELL-33 (D178/D186/D188): lights (or puts out) every base bell with the amber nozzle glow during a rack
  /// put-back or a key detach. No receipt: the page only paints it.
  public func setIgnition(_ on: Bool) throws -> String {
    guard ready, !blocked, supportsAppearance else { throw CockpitBridgeError.unavailable }
    return try envelope("ignition", extra: ["on": on])
  }
  /// WP-22 (macrevb-1062-3): the enlarged field's selection, a public model id (the page's identity bound: 1-128
  /// characters, no control characters) or nil when it was cleared there. No receipt: the page only shows it.
  public func setSelection(_ model: String?) throws -> String {
    guard ready, !blocked, supportsAppearance else { throw CockpitBridgeError.unavailable }
    guard model.map(Self.isPublicModelID) ?? true else { throw CockpitBridgeError.invalidMessage }
    return try envelope("select", extra: ["model": model.map { $0 as Any } ?? NSNull()])
  }
  /// Owner 11-19 (#1062): the enlarged field closed (any close path); the page ignores the porthole click that bounces
  /// off it. No receipt.
  public func fieldClosed() throws -> String {
    guard ready, !blocked, supportsAppearance else { throw CockpitBridgeError.unavailable }
    return try envelope("fieldClosed")
  }
  static func isPublicModelID(_ id: String) -> Bool {
    !id.isEmpty && id.utf16.count <= 128 && !id.unicodeScalars.contains { $0.value < 0x20 || $0.value == 0x7f }
  }
  public func display(_ data: WireCockpitData, ticket: CockpitQueryTicket) throws -> String {
    guard ticket == queryTicket else { throw CockpitBridgeError.staleContext }
    // A newer display retires all prior unacknowledged display receipts.
    pending = pending.filter { $0.value.kind != "rendered" }
    let (object, dropped) = try Self.finiteObject(data)
    lastNonFinitePaths = dropped
    let tools = Set(data.projection.rows.filter { $0.kind == .tool && !$0.invalid }.map { $0.id })
    return try envelope("display", extra: ["data": object], receipt: "rendered", tools: tools, members: CockpitMemberScopes.keys(data))
  }
  /// G3-86: JSON has no NaN or infinity, so one such number made the whole display unencodable. It is sent
  /// as null (the page shows that value as unavailable); the controller logs the field paths, never the values.
  public private(set) var lastNonFinitePaths: [String] = []
  private static let nonFiniteMarker = "\u{0}modelplan.nonfinite.7f1c2a"
  static func finiteObject(_ data: WireCockpitData) throws -> (Any, [String]) {
    let encoder = JSONEncoder()
    encoder.nonConformingFloatEncodingStrategy = .convertToString(
      positiveInfinity: nonFiniteMarker, negativeInfinity: nonFiniteMarker, nan: nonFiniteMarker)
    var dropped: [String] = []
    let object = replacingNonFinite(try JSONSerialization.jsonObject(with: encoder.encode(data)), path: "data", dropped: &dropped)
    return (object, dropped)
  }
  private static func replacingNonFinite(_ value: Any, path: String, dropped: inout [String]) -> Any {
    if let text = value as? String, text == nonFiniteMarker { dropped.append(path); return NSNull() }
    if let object = value as? [String: Any] {
      var out: [String: Any] = [:]
      for (key, child) in object { out[key] = replacingNonFinite(child, path: path + "." + key, dropped: &dropped) }
      return out
    }
    if let array = value as? [Any] {
      return array.enumerated().map { replacingNonFinite($0.element, path: path + "[\($0.offset)]", dropped: &dropped) }
    }
    return value
  }
  /// G3-86: a display the delivery queue refused never reaches the page, so no receipt is awaited for it.
  /// The page keeps the last display it rendered until the refresh that replaces this one.
  func abandonDisplay(_ id: UUID) {
    guard pending[id]?.kind == "rendered" else { return }
    pending[id] = nil
    if earlyDeadline?.requestID == id { earlyDeadline = nil }
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
  /// Plugin columns: the saved plugin choices (CockpitPluginPreferences.bridgeJSON), checked by the page's own rules.
  public func setPlugins(_ json: Data) throws -> String {
    guard ready, !blocked, supportsAppearance else { throw CockpitBridgeError.unavailable }
    guard let canonical = CockpitPluginWire.canonical(json: json),
      let body = try? JSONSerialization.jsonObject(with: canonical) else { throw CockpitBridgeError.invalidMessage }
    let raw = try envelope("plugins", extra: ["plugins": body])
    pluginsSent = true
    return raw
  }
  /// Plugin columns: one reading for a running plugin. Only after `plugins`, and only to a visible, unoccluded page.
  public func pluginData(id: String, data: [String: Any]) throws -> String {
    guard ready, !blocked, pluginsSent, visibility.visible, !visibility.occluded else { throw CockpitBridgeError.unavailable }
    guard CockpitPluginWire.validID(id), JSONSerialization.isValidJSONObject(data) else { throw CockpitBridgeError.invalidMessage }
    return try envelope("pluginData", extra: ["id": id, "data": data])
  }
  /// Plugin columns: open this plugin's big screen (the widget card's action, #1096). Only after `plugins`; the page
  /// refuses it for a plugin that is not enabled. No receipt: presentation only.
  public func openPluginScreen(id: String) throws -> String {
    guard ready, !blocked, pluginsSent else { throw CockpitBridgeError.unavailable }
    guard CockpitPluginWire.validID(id) else { throw CockpitBridgeError.invalidMessage }
    return try envelope("pluginScreen", extra: ["id": id])
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
      // Strict page sequence rejects replays without a lifetime action cap.
      if let earlyDisplay, sequence <= earlyDisplay.sequence { throw CockpitBridgeError.invalidMessage }
      let action = m["action"] as? String
      let history = action == "openHistory", scope = action == "scopeSelect" || action == "rangeSelect" || action == "refreshMember", website = action == "openWebsite", ack = action == "cautionAck" || action == "pinnedModels"
      let focusedField = action == "openField" && m["key"] != nil
      let running = action == "pluginsRunning", pluginEdit = action == "pluginsEdit", pluginClose = action == "pluginClose"
      let extra:Set<String> = history ? ["action","tool"] : scope || focusedField ? ["action","key"] : website ? ["action","page","value"] : ack || running ? ["action","ids"] : pluginEdit ? ["action","plugins"] : pluginClose ? ["action","id"] : ["action"]
      // Plugin actions exist only for a host that sent `plugins`. A page stops its plugins when it hides, so
      // `pluginsRunning` is accepted without focus; every other action needs the active page.
      guard Set(m.keys) == base.union(extra), ready, !blocked,
        running ? pluginsSent : visibility.active, !pluginEdit || pluginsSent, !pluginClose || pluginsSent
      else { throw CockpitBridgeError.invalidMessage }
      let intent: CockpitIntent
      switch action {
      case "chooseSetup": intent = .chooseSetup
      case "openSettings": intent = .openSettings
      // CKP-SHELL-39: the empty engine screen's one button; it opens the Subscriptions pane and carries nothing.
      case "openSettingsSubscriptions": intent = .openSettingsSubscriptions
      case "scopeSelect":
        guard let key=m["key"] as? String, scopeMembers.contains(key),
          earlyDisplay.map({ pending[$0.requestID]?.members.contains(key) == true }) ?? true else { throw CockpitBridgeError.invalidMessage }
        intent = .scopeSelect(key)
      case "rangeSelect":
        guard let key = m["key"] as? String, let range = CockpitRange(rawValue: key) else { throw CockpitBridgeError.invalidMessage }
        intent = .rangeSelect(range)
      case "refreshMember":
        guard let key=m["key"] as? String, scopeMembers.contains(key),
          earlyDisplay.map({ pending[$0.requestID]?.members.contains(key) == true }) ?? true else { throw CockpitBridgeError.invalidMessage }
        intent = .refreshMember(key)
      case "openWebsite":
        guard let link = CockpitWebsiteLink(page: m["page"] as? String, value: m["value"] as? String) else { throw CockpitBridgeError.invalidMessage }
        intent = .openWebsite(link)
      case "cautionAck":
        guard let ids = m["ids"] as? [String], CockpitCautionIdentities.valid(ids) else { throw CockpitBridgeError.invalidMessage }
        intent = .cautionAck(ids)
      case "pinnedModels":
        guard let ids = m["ids"] as? [String], CockpitCautionIdentities.valid(ids), Set(ids).count == ids.count else { throw CockpitBridgeError.invalidMessage }
        intent = .pinnedModels(ids)
      case "pluginsRunning":
        // D124 (macrevb-1104-4): a stop is always taken; a start only from a shown page, so a report that was posted before
        // a hide and arrives after it cannot start sampling.
        guard let ids = m["ids"] as? [String], CockpitPluginWire.validRunning(ids),
          ids.isEmpty || (visibility.visible && !visibility.occluded) else { throw CockpitBridgeError.invalidMessage }
        intent = .pluginsRunning(ids)
      case "pluginsEdit":
        guard let body = m["plugins"], let canonical = CockpitPluginWire.canonical(body) else { throw CockpitBridgeError.invalidMessage }
        intent = .pluginsEdit(canonical)
      case "pluginClose":
        guard let id = m["id"] as? String, CockpitPluginWire.validID(id) else { throw CockpitBridgeError.invalidMessage }
        intent = .pluginClose(id)
      case "close": intent = .close
      case "detach": intent = .detach
      case "putBack": intent = .putBack
      case "shutterToggle": intent = .shutterToggle
      case "openField":
        if focusedField {
          guard let key = m["key"] as? String, (1...64).contains(key.count),
            !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw CockpitBridgeError.invalidMessage }
          intent = .openFieldAt(key)
        } else { intent = .openField }
      case "openHistory":
        guard let tool = m["tool"] as? String, historyTools.contains(tool),
          earlyDisplay.map({ pending[$0.requestID]?.tools.contains(tool) == true }) ?? true else {
          throw CockpitBridgeError.invalidMessage
        }
        intent = .openHistory(tool)
      default: throw CockpitBridgeError.invalidMessage
      }
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
