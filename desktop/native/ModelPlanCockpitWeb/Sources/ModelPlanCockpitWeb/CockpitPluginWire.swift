// SPDX-License-Identifier: MIT
import Foundation

/// Plugin columns over the bridge (D121/D124, D293; desktop/cockpit/src/plugin-state.ts `parsePluginState`). The host's
/// `plugins` body and the page's `pluginsEdit` body share one shape; both directions pass through `canonical`, so the
/// host never sends a state the page refuses and never forwards an edit the page could not have made. This module does
/// not know the catalogue (ModelPlanSettings owns it); ranges against the catalogue are applied there.
public enum CockpitPluginWire {
  public static let maximumEntries = 32, maximumPinned = 2, maximumSettingKeys = 8, maximumSettingValue = 86_400
  /// The page reports at most this many running plugins (bridge.ts `pluginsRunning`).
  public static let maximumRunning = 16
  /// plugin-registry.ts PLUGIN_ID: `^[a-z][a-z0-9-]{0,31}$`.
  public static func validID(_ id: String) -> Bool {
    let bytes = Array(id.utf8)
    guard let first = bytes.first, bytes.count <= 32, (97...122).contains(first) else { return false }
    return bytes.allSatisfy { (97...122).contains($0) || (48...57).contains($0) || $0 == 45 }
  }
  /// plugin-state.ts SETTING_KEY: `^[a-zA-Z][a-zA-Z0-9]{0,31}$`.
  static func validSettingKey(_ key: String) -> Bool {
    let bytes = Array(key.utf8)
    let letter: (UInt8) -> Bool = { (97...122).contains($0) || (65...90).contains($0) }
    guard let first = bytes.first, bytes.count <= 32, letter(first) else { return false }
    return bytes.allSatisfy { letter($0) || (48...57).contains($0) }
  }
  /// A JSON boolean as JSONSerialization returns it (an NSNumber that is a CFBoolean, never 0 or 1).
  static func bool(_ value: Any?) -> Bool? {
    guard let number = value as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() else { return nil }
    return number.boolValue
  }
  /// A JSON integer in 0...86400 (never a boolean, never a fraction).
  static func setting(_ value: Any?) -> Int? {
    guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
    let double = number.doubleValue
    guard double.isFinite, double == double.rounded(), double >= 0, double <= Double(maximumSettingValue) else { return nil }
    return Int(double)
  }
  public static func validRunning(_ ids: [String]) -> Bool {
    ids.count <= maximumRunning && Set(ids).count == ids.count && ids.allSatisfy(validID)
  }
  /// The sorted-key JSON of a valid plugin state, or nil for any other shape.
  public static func canonical(_ object: Any) -> Data? {
    guard let body = object as? [String: Any], Set(body.keys) == ["version", "entries", "settings"],
      let version = body["version"] as? NSNumber, CFGetTypeID(version) != CFBooleanGetTypeID(), version.doubleValue == 1,
      let entries = body["entries"] as? [Any], entries.count <= maximumEntries,
      let settings = body["settings"] as? [String: Any], settings.count <= maximumEntries else { return nil }
    var ids = Set<String>(), pinned = 0
    var outEntries: [[String: Any]] = []
    for item in entries {
      guard let entry = item as? [String: Any], Set(entry.keys) == ["id", "enabled", "pinned"],
        let id = entry["id"] as? String, validID(id), ids.insert(id).inserted,
        let on = bool(entry["enabled"]), let pin = bool(entry["pinned"]) else { return nil }
      if pin { pinned += 1; guard on, pinned <= maximumPinned else { return nil } }
      outEntries.append(["id": id, "enabled": on, "pinned": pin])
    }
    var outSettings: [String: [String: Int]] = [:]
    for (id, raw) in settings {
      guard validID(id), let values = raw as? [String: Any], values.count <= maximumSettingKeys else { return nil }
      var copy: [String: Int] = [:]
      for (key, value) in values {
        guard validSettingKey(key), let number = setting(value) else { return nil }
        copy[key] = number
      }
      outSettings[id] = copy
    }
    return try? JSONSerialization.data(withJSONObject: ["version": 1, "entries": outEntries, "settings": outSettings], options: [.sortedKeys])
  }
  /// `canonical` for JSON bytes (the host's `CockpitPluginPreferences.bridgeJSON`).
  public static func canonical(json: Data) -> Data? {
    guard json.count <= 65_536, let object = try? JSONSerialization.jsonObject(with: json) else { return nil }
    return canonical(object)
  }
}
