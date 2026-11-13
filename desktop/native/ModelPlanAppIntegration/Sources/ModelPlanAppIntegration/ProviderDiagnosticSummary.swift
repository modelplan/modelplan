// SPDX-License-Identifier: MIT
import Foundation

enum ProviderDiagnosticCondition: Int, Sendable {
    case normal = 0, loading = 1, stale = 2, refreshUnavailable = 3, failed = 4, permission = 5
}
struct ProviderDiagnosticFact: Sendable {
    let providerID: String
    let name: String
    let condition: ProviderDiagnosticCondition
}
enum ProviderDiagnosticSummary {
    static func lines(_ facts: [ProviderDiagnosticFact], english: Bool) -> [String] {
        var best: [String: ProviderDiagnosticFact] = [:]
        var order: [String] = []
        for fact in facts where !fact.providerID.isEmpty && !fact.name.isEmpty && fact.condition.rawValue >= ProviderDiagnosticCondition.stale.rawValue {
            if best[fact.providerID] == nil { order.append(fact.providerID) }
            if best[fact.providerID].map({ $0.condition.rawValue < fact.condition.rawValue }) ?? true { best[fact.providerID] = fact }
        }
        return order.compactMap { id in
            guard let fact = best[id] else { return nil }
            let text: String
            switch fact.condition {
            case .stale: text = english ? "Reading stale · Details…" : "读数已过期 · 查看…"
            case .refreshUnavailable: text = english ? "Refresh unavailable · Details…" : "刷新暂不可用 · 查看…"
            case .failed: text = english ? "Couldn't read · Details…" : "读取失败 · 查看…"
            case .permission: text = english ? "Permission needed · Details…" : "需要读取权限 · 查看…"
            case .normal, .loading: return nil
            }
            return fact.name + (english ? ": " : "：") + text
        }
    }
}
