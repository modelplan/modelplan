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
  /// Match the stable Settings identity for each dock account. Colliding unbound accounts have session-only
  /// numbered keys and cannot be hidden persistently.
  private static func memberID(_ row: RowsRow, _ account: RowsAccount) -> String {
    account.subscriptionRef ?? row.id + "#" + account.route.rawValue
  }
  static func hasHiddenMembers(_ data: WireCockpitData, hiddenMembers: Set<String>) -> Bool {
    data.projection.rows.filter { $0.surfaces.contains(.dock) }.contains { row in
      row.accounts.contains { hiddenMembers.contains(memberID(row, $0)) }
    }
  }
  /// The runnable published model ids, in publication order.
  static func runnable(_ data: WireCockpitData, hiddenMembers: Set<String> = []) -> [String] {
    guard let details = data.details, let published = details.publishedModels, !published.isEmpty else { return [] }
    var lists: [(models: Set<String>?, developer: String?)] = []
    for row in data.projection.rows where row.surfaces.contains(.dock) {
      for account in row.accounts where !hiddenMembers.contains(memberID(row, account)) {
        let reported = account.subscriptionRef.flatMap { ref in details.subscriptions.first { $0.subscriptionRef == ref }?.reportedModels }
        let list = reported.flatMap { $0.isEmpty ? nil : Set($0) } ?? planModels(details.planModels, tool: row.id, plan: account.plan.id)
        lists.append((list, toolDevelopers[row.id]))
      }
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
