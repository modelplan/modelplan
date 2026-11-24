// SPDX-License-Identifier: MIT
import ModelPlanWire

/// WP-22 (D298): the launch field's "Mine" = the published models the connected tools can run (the component adds anything
/// already on the field). The same rule as the cockpit page's subscriptions (src/plan-models.ts memberModelList, D86/D98),
/// over the same members (src/members.ts: rows the widget shows, every account): the models the tool reports for the
/// account, else the published plan's model list, else the models of the tool's developer. Only public model ids leave.
enum CockpitFieldFleet {
  /// D86: published plan ids carry the tool's vendor prefix (openai-plus, claude-max-5x); a harness reports only "plus".
  static let planPrefixes: [String: String] = ["codex": "openai", "claude": "claude"]
  /// src/session-binding.ts toolDevelopers.
  static let toolDevelopers: [String: String] = [
    "codex": "openai", "claude": "anthropic", "gemini": "google", "grok": "xai", "kimi": "kimi", "zai": "zhipuai",
    "minimax": "minimax", "qwen": "alibaba",
  ]
  /// Match the cockpit's verified identities and numbered fallback identities over dock rows.
  private static func members(_ data: WireCockpitData) -> [(String, RowsRow, RowsAccount)] {
    let verified = Set(data.subscriptions.map(\.subscriptionRef))
    let rows = data.projection.rows.filter { $0.surfaces.contains(.dock) }
    var counts: [String: Int] = [:]
    for row in rows { for account in row.accounts {
      if let ref = account.subscriptionRef, verified.contains(ref) { continue }
      counts[row.id + "#" + account.route.rawValue, default: 0] += 1
    }}
    var positions: [String: Int] = [:], seen = Set<String>()
    var result: [(String, RowsRow, RowsAccount)] = []
    for row in rows { for account in row.accounts {
      if let ref = account.subscriptionRef, verified.contains(ref) {
        if seen.insert(ref).inserted { result.append((ref, row, account)) }
        continue
      }
      let base = row.id + "#" + account.route.rawValue
      positions[base, default: 0] += 1
      let key = counts[base, default: 0] > 1 ? base + "#" + String(positions[base]!) : base
      result.append((key, row, account))
    }}
    return result
  }
  static func hasHiddenMembers(_ data: WireCockpitData, hiddenMembers: Set<String>) -> Bool {
    members(data).contains { hiddenMembers.contains($0.0) }
  }
  /// The runnable published model ids, in publication order.
  static func runnable(_ data: WireCockpitData, hiddenMembers: Set<String> = []) -> [String] {
    guard let details = data.details, let published = details.publishedModels, !published.isEmpty else { return [] }
    var lists: [(models: Set<String>?, developer: String?)] = []
    for (key, row, account) in members(data) where !hiddenMembers.contains(key) {
        let reported = account.subscriptionRef.flatMap { ref in details.subscriptions.first { $0.subscriptionRef == ref }?.reportedModels }
        let list = reported.flatMap { $0.isEmpty ? nil : Set($0) } ?? planModels(details.planModels, tool: row.id, plan: account.plan.id)
        lists.append((list, toolDevelopers[row.id]))
    }
    return published.filter { model in
      lists.contains { $0.models.map { $0.contains(model.id) } ?? ($0.developer != nil && $0.developer == model.developerId) }
    }.map(\.id)
  }
  /// src/plan-models.ts memberPlanModels: nil when the plan cannot be pinned to published plans. A harness plan that
  /// covers several published tiers gets only the models every one of them lists.
  static func planModels(_ lists: [WireCockpitPlanModels]?, tool: String, plan: String) -> Set<String>? {
    guard let lists, !lists.isEmpty, !plan.isEmpty, plan != "unknown" else { return nil }
    let id = plan.lowercased(), prefix = planPrefixes[tool]
    let matched = lists.filter { p in
      p.planId == id || prefix.map { p.planId == "\($0)-\(id)" || p.planId.hasPrefix("\($0)-\(id)-") } == true
    }
    guard let first = matched.first else { return nil }
    return Set(first.modelIds.filter { m in matched.allSatisfy { $0.modelIds.contains(m) } })
  }
}
